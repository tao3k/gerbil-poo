;;; Runnable model-driven collection properties; use the ordinary std/test runner.
(export service-factory-action service-value-generator service-batch-action map-service-action map-service-tests handoff rolling-upgrade optimistic-aba collection-properties-test)
(import (prefix-in :clan/poo/testing/property/generator core.) :std/test :std/error :std/iter (only-in :std/list/list take delete-duplicates/hash)
        (prefix-in :clan/poo/testing/property property.)
        (prefix-in :clan/poo/testing/property/replay replay.)
        ../object ../mop ../type ../number ../testing/type ../support/option
        ./collection-testing)

;; Each example declares its domain prefix and the fault it must discover.
;; The same trace protocol supplies random tails, dependency repair and replay.
(define-type Scenario
  (Record name: [String] commands: [(List Command)]
          fault: [(Enum atomic stale)] phase: [(Enum state result)]))
;; Two staged owners cannot swap independently through a unique index. Removal,
;; re-staging and inverse refusal preserve the complete primary/index correlation.
(def handoff (make-instance Scenario name: "unique-owner handoff"
  fault: 'atomic phase: 'state commands:
  (list #(put 1 10 installed) #(put 2 20 installed)
    #(stage 0 1 20) #(stage 1 2 10)
    #(install 0 index-conflict) #(install 1 index-conflict)
    #(remove 2) #(install 0 installed) #(install 1 conflict)
    #(stage 2 2 10) #(install 2 installed) #(undo 0 index-conflict)
    #(remove 2) #(undo 0 restored) #(undo 2 conflict)
    #(install 2 index-conflict) #(remove 1) #(install 2 installed) #(undo 2 restored))))
;; Receipts survive as logical data across two source revisions, but may be used
;; only under their captured epoch. New receipts recover while old ones refuse.
(def rolling-upgrade (make-instance Scenario name: "rolling service revisions"
  fault: 'stale phase: 'result commands:
  (list #(put 1 10 installed) #(stage 0 1 11) #(stage 1 2 20)
    #(expire) #(read-old) #(refresh) #(install 0 stale-delta) #(install 1 stale-delta)
    #(stage 2 1 11) #(stage 3 2 20) #(install 2 installed)
    #(expire) #(read-old) #(refresh) #(undo 2 stale-delta) #(install 3 stale-delta)
    #(stage 4 1 12) #(stage 5 2 20) #(install 4 installed) #(install 5 installed)
    #(stage 6 3 20) #(install 6 index-conflict) #(remove 2)
    #(install 6 installed) #(undo 6 restored) #(undo 4 restored))))
;; Delta admission compares old values within an epoch: A/B/A permits retry.
;; An unchanged value after source revision still cannot authorize an old receipt.
;; This distinguishes the actual contract from a stronger history/serializability claim.
(def optimistic-aba (make-instance Scenario name: "value ABA versus source epochs"
  fault: 'stale phase: 'result commands:
  (list #(put 1 11 installed) #(stage 0 1 22) #(put 1 33 installed)
    #(install 0 conflict) #(put 1 11 installed) #(install 0 installed) #(undo 0 restored)
    #(stage 1 1 22) #(expire) #(read-old) #(refresh)
    #(install 1 stale-delta) #(undo 0 stale-delta)
    #(stage 2 1 22) #(install 2 installed) #(undo 2 restored))))

;; A fresh real backend belongs to every trial, shrink probe and replay invocation.
;; This ordinary partial application composes with the existing trace/FUN boundary.
(def (property-for selected backend (fault 'none))
  (trace-property selected (cut with-collection-system <> backend: backend fault: fault)))
;; One reusable sampler tests both backends and several independent seeded runs.
;; Every run includes the domain prefix and then explores a state-dependent suffix.
(def (check-scenario scenario)
  (def commands (.get scenario commands))
  (def selected (collection-model commands))
  (def sampler (trace-generator Command selected steps: 64 dependencies: (list scenario)))
  ;; The generator's admitted prefix becomes an explicit per-run coverage contract.
  (def required (map (lambda (tag) (cons tag 4))
    (delete-duplicates/hash (map (cut vector-ref <> 0) commands))))
  (def policy (property.make-policy name: (.get scenario name)
    labels: (lambda (trace) (map (cut vector-ref <> 0) trace)) required: required))
  (for* ((backend '(rationaldict trie)) (seed '(7 41 83)))
    (def action (property-action (.get sampler descriptor) (property-for selected backend)
      identity sampler: sampler))
    (def report (action (.o bind-these: #f seed: seed cases: 4 size: 48 shrink-budget: 96 policy: policy)))
    (check-equal? (list (.get scenario name) backend seed (.get report status) (.get report cause))
      (list (.get scenario name) backend seed 'passed #f))
    (check-equal? (.get report accepted) 4)
    (for (entry required) (check (cdr (assq (car entry) (.get report labels))) => 4))
    (check-equal? (take (.get report original) (length commands)) commands))
  ;; A faulty implementation must yield a smaller VALID false witness. Error or
  ;; stale reports are never accepted as evidence that the fault was discovered.
  (for (backend '(rationaldict trie))
    (def property (property-for selected backend (.get scenario fault)))
    (def report (check-property (.get sampler descriptor) property sampler: sampler
      seed: 41 cases: 1 size: (length commands) shrink-budget: 96))
    (check-equal? (list (.get report status) (.get report cause)) '(failed #f))
    (check (.call sampler .accept? (.get report counterexample)) => #t)
    (check (< (length (.get report counterexample)) (length (.get report original))) => #t)
    (check (replay-counterexample report) => #f)
    ;; The codec stores only command data/logical IDs; fresh fixtures stay scoped.
    (def codec (replay.make-codec (list 'collection 1 (.get scenario name) backend (.get scenario fault)) values values))
    (def port (open-output-string))
    (replay.write-counterexample (.get report execution) codec port)
    (check (replay.read-counterexample codec (open-input-string (get-output-string port))
      (property.make-specification (cut .call sampler .accept? <>) length) property) => #f)
    (check-equal? (.get (replay-property report) counterexample) (.get report counterexample))
    (def diagnostic (check-trace selected (.get report counterexample)
      (cut with-collection-system <> backend: backend fault: (.get scenario fault))))
    (check-equal? (.get diagnostic phase) (.get scenario phase))))

;; Export a regular *-test suite so downstream projects can run this example
;; through gerbil test after the standard qualification build, without a new runner.
(def collection-properties-test
  (test-suite "complex model-driven collection properties"
    (test-case "owned prefixes and state-derived producer identities"
      (def command (vector 'stage 2 1 10))
      (def selected (collection-model (list command)))
      (vector-set! command 1 99)
      (def initial (.call selected initial))
      (def first (some-value (.call selected draw initial (lambda (_) 0) 8)))
      (check-equal? first #(stage 2 1 10))
      (defvalues (next _reply) (.call selected advance initial first))
      ;; Choose the new-stage alternative repeatedly. Tick-derived IDs would
      ;; collide with retained receipt 2 on the second draw of this short prefix.
      (for/fold (state next) (_ (in-range 3))
        (let (command (some-value (.call selected draw state
                       (lambda (bound) (if (= bound 2) 1 0)) 8)))
          (check-equal? (vector-ref command 0) 'stage)
          (check (.call selected enabled? state command) => #t)
          (let-values (((updated _reply) (.call selected advance state command))) updated)))
      (check-exception (collection-model '(#(install 9 installed)))
        (lambda (cause) (and (Error? cause) (equal? (Error-message cause) "invalid collection prefix"))))
      (check-exception (collection-model '(#(stage 0 1 "bad value"))) TypeError?))
    (test-case "interleaved ownership transfer and inverse index conflicts" (check-scenario handoff))
    (test-case "multi-round upgrades with retained stale receipts" (check-scenario rolling-upgrade))
    (test-case "ABA retry differs from cross-epoch receipt reuse" (check-scenario optimistic-aba))))

;; A fixed two-service batch retains both keys and nested Function wrappers. Its
;; value trees use the shared product algebra; Map owns only the declared measure.
;; weigh observes caller-owned revisions, and FUN delivers the complete report.
(def (map-service-tests owner weigh consume)
  (def cell (Record amount: [UInt] handler: [(Function [Integer] [Integer])]))
  (map-service-action (Map (Enum left right) -> cell) cell owner weigh consume))

;; Accept an already declared service directory, so metadata preparation and
;; publication share the same request authority. The Map factory alone owns key
;; admission; its original guard travels with this deterministic two-entry tree.
(def (map-service-action descriptor cell owner weigh consume)
  (def values (service-value-generator cell owner weigh))
  (def maps (map-generator descriptor '(left right) values dependencies: (list owner)))
  (def guard (.@ maps .current?))
  (def generation (core.generator-map
    (core.generator-sequence (list (generator-core values) (generator-core values)))
    (lambda (row) (list->hash-table (map cons '(left right) row) seed: 0))
    current?: guard))
  (def sampler (.cc (from-generator descriptor generation (cut .call maps measure <>)
    dependencies: (list owner maps)) .current?: guard))
  (property-action descriptor (lambda (table) (= ((.@ (hash-ref table 'left) handler) -1) 0))
    consume sampler: sampler))

;; One standard Record producer serves both service collection workflows. It
;; constructs Function wrappers at the existing field boundary exactly once.
(def (service-value-generator cell owner weigh)
  (make-generator cell
    (lambda (_random _size) (make-instance cell amount: 2 handler: abs))
    (lambda (value) (if (zero? (.get value amount)) [] (list (.cc value amount: 0))))
    (lambda (value) (weigh value) (.get value amount)) dependencies: (list owner)))

;; Shared field samplers compose as an ordinary product, so source declaration
;; preparation precedes every draw/pack and the same guard owns FUN and replay.
(def (service-batch-action cell field consume)
  (def descriptor (Tuple cell cell))
  (def sampler (product-generator descriptor (list field field) vector->list list->vector))
  (property-action descriptor (lambda (batch)
    (= ((.@ (vector-ref batch 0) handler) -1) 0)) consume sampler: sampler))

;; A downstream recipe may supply an owned generic tree or decline with #f.
;; The standard typed action owns binding, probing, reports and explicit retries;
;; the recipe must use the core protocol for guarded nested producer pulls.
(def (service-factory-action cell owner factory consume)
  (def field (service-value-generator cell owner void))
  (.putslot! field 'generation ($constant-slot-spec factory))
  (property-action cell (lambda (value) (= ((.@ value handler) -1) 0)) consume sampler: field))
