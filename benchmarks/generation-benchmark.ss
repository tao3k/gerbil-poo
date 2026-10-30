;;; Matched callback/tree strategies with AB/BA and identical-strategy controls.
(export main)
(import :std/iter ../object ../mop ../type ../number ../testing/type
        (prefix-in :clan/poo/testing/property/generator core.)
        (prefix-in :clan/poo/testing/property property.)
        (only-in ./closure-measure measure measure-pair))

;; This finite injective product admits both value-only and provenance shrinking.
;; Fixed draws give both strategies identical values and shrink frontiers/seeds.
(def Descriptor (Tuple UInt UInt))
;; Preparation is included by the workflow action and measured separately too.
;; Both strategies perform the same receiver derivation; only tree ownership differs.
(def (prepare strategy)
  (def children (map (lambda (n)
    (make-generator UInt (lambda (_random _size) n) core.integer-shrinks identity)) '(9 5)))
  (def sampler (product-generator Descriptor children vector->list list->vector))
  (.cc sampler generation: (if (eq? strategy 'callbacks) #f (.get sampler generation))))
;; One independent mathematical oracle is shared by both full check actions.
(def (property value) (< (+ (vector-ref value 0) (vector-ref value 1)) 3))
;; Counters, status and exact witness are checked inside each measured workflow.
(def (run sampler)
  (def report (check-property Descriptor property sampler: sampler cases: 1 seed: 41 shrink-budget: 96))
  (unless (and (eq? (.get report status) 'failed)
    (equal? (.get report counterexample) '#(0 3)) (.get report minimal?)
    (= (.get report attempts) 10) (= (.get report steps) 3)) (error "generator strategy oracle" report)) #t)
;; One matched workload covers preparation, reused drawing and complete shrinking.
(def (action phase strategy)
  (case phase
    ((prepare) (lambda () (object? (prepare strategy))))
    ((draw)
     (let (sampler (generator-core (prepare strategy)))
       (lambda () (equal? (core.sample-value (core.generate sampler (core.random-at 41) 8)) '#(9 5)))))
    ((workflow) (lambda () (run (prepare strategy))))
    (else (error "unknown generator benchmark phase" phase))))
;; The existing process-statistics helper owns CPU, wall, GC, counts and allocation.
;; Explicit post-GC preparation and the first call are charged, not silently warmed.
(def (capture thunk repetitions regime)
  (def (sample operation count)
    (defvalues (ok metrics) (measure operation count))
    (unless ok (error "generation benchmark oracle refused")) metrics)
  (def preparation (and (eq? regime 'post-gc) (sample (lambda () (##gc) #t) 1)))
  (def first (and preparation (sample thunk 1)))
  (vector (sample thunk repetitions) first preparation))
;; Report only after the complete pair, preserving the measured inter-sample gap.
(def (report phase regime order samples)
  (displayln "GENERATOR-PAIR " phase " " regime " " order " " samples))
;; This standard SRFI-27 probe charges checkpoint preparation inside every batch.
;; Both alternatives create fresh sources and draw the same deterministic value.
(def (seed-action strategy repetitions)
  (def (seeded)
    (def source (make-random-source))
    (random-source-pseudo-randomize! source 0 4199442117) source)
  (def expected ((random-source-make-integers (seeded)) 4294967087))
  (lambda ()
    (def checkpoint (and (eq? strategy 'restore) (random-source-state-ref (seeded))))
    (for/fold (ok #t) (_ (in-range repetitions))
      (let (source (if checkpoint
        (let (source (make-random-source)) (random-source-state-set! source checkpoint) source)
        (seeded)))
        (and (= ((random-source-make-integers source) 4294967087) expected) ok)))))
;; Reversed and identical pairs distinguish seed expansion from GC/history noise.
(def (seed-study repetitions pairs)
  (for (regime '(natural post-gc))
    (def reseed (seed-action 'reseed repetitions)) (def restore (seed-action 'restore repetitions))
    (for (pair (in-range pairs))
      (for (order (list (if (even? pair) '(reseed restore) '(restore reseed))
                       '(reseed reseed) '(restore restore)))
        (measure-pair order
          (lambda (strategy) (capture (if (eq? strategy 'reseed) reseed restore) 1 regime))
          (lambda (samples) (displayln "GENERATOR-SEED-PAIR " regime " " order " " samples)))))))
;; Independent immutable-field algebra control. Keep this local so the linked
;; benchmark entry imports no TestSuite module. It uses only public generators;
;; it is neither a production fallback nor an exact historical private binary.
(def (retained-product-control fields)
  ;; Capture each full field tree as the hidden value of a nonshrinking root.
  (def (root field)
    (core.make-tree-generator (lambda (random size)
      (let (tree (core.generate field random size))
        (core.make-sample tree (lambda () []) sources: (core.sample-sources tree))))))
  (def roots (foldr (lambda (field tail)
    (core.generator-bind (root field) (lambda (tree)
      (core.generator-map tail (lambda (trees) (cons tree trees)))))) (core.generator-unit []) fields))
  (core.make-tree-generator (lambda (random size)
    (let (tree (core.generate roots random size))
      (core.sample-sequence (core.sample-value tree) min-length: (length fields)
        sources: (core.sample-sources tree))))))

;; A public retained-tree algebra is the immutable-field control, not an exact
;; historical-revision benchmark. Both strategies include their own preparation.
(def (product-study repetitions pairs)
  ;; Full receipt equality prevents an apparently faster strategy skipping work.
  (def (receipt report)
    (list (property.report-status report) (property.report-original report)
      (property.report-counterexample report) (property.report-attempts report)
      (property.report-steps report) (property.report-minimal? report)))
  (def domain (property.make-specification list? (cut apply + <>)))
  ;; The same falsity predicate is used by construction, shrink and both replays.
  (def (property row) (< (apply + row) 3))
  (for (width '(16 64))
    ;; Standard integer fields carry no mutable producer metadata. Branch-source
    ;; admission is covered by the separate negative/retirement regression cases.
    (def (prepare strategy)
      ((if (eq? strategy 'checked) core.generator-sequence retained-product-control)
        (map (lambda (_) (core.generator-integer 0 16)) (iota width))))
    ;; The complete check retains a fixed seed, domain and proposal quota.
    (def (check sampler)
      (property.check-property sampler property domain seed: 41 cases: 1 shrink-budget: 8))
    (def expected (receipt (check (prepare 'composed))))
    ;; Admission is symmetric and precedes all reported comparisons.
    (unless (and (eq? (car expected) 'failed) (equal? expected (receipt (check (prepare 'checked)))))
      (error "product strategy oracle"))
    (for* ((phase '(prepare draw workflow)) (regime '(natural post-gc)))
      ;; Phase boundaries include strategy preparation only where declared.
      (def (action strategy)
        (case phase
          ((prepare) (lambda () (core.generator? (prepare strategy))))
          ((draw) (let (sampler (prepare strategy)) (lambda ()
            (equal? (core.sample-value (core.generate sampler (core.random-at 41) 20)) (cadr expected)))))
          ((workflow) (lambda ()
            (let (result (check (prepare strategy)))
              (and (equal? (receipt result) expected)
                (not (property.replay-counterexample result))
                (equal? (receipt (property.replay-property result)) expected)))))))
      (def checked (action 'checked)) (def composed (action 'composed))
      (for (pair (in-range pairs))
        (for (order (list (if (even? pair) '(composed checked) '(checked composed))
                         '(composed composed) '(checked checked)))
          (measure-pair order
            (lambda (strategy) (capture (if (eq? strategy 'checked) checked composed) repetitions regime))
            (lambda (samples) (displayln "GENERATOR-PRODUCT-PAIR " width " " phase " " regime " " order " " samples))))))))

;; Full entries include library/module startup; the measured actions contain all
;; strategy-specific preparation. Reversed and identical pairs expose ordering noise.
(def (main (repetitions-text "20") (pairs-text "4"))
  (def repetitions (string->number repetitions-text)) (def pairs (string->number pairs-text))
  (unless (and (exact-integer? repetitions) (> repetitions 0) (exact-integer? pairs) (> pairs 0))
    (error "positive benchmark counts required"))
  (for* ((phase '(prepare draw workflow)) (regime '(natural post-gc)))
    (def callbacks (action phase 'callbacks)) (def tree (action phase 'tree))
    ;; Admit both complete oracles before collecting comparative timing evidence.
    (unless (and (run (prepare 'callbacks)) (run (prepare 'tree))) (error "strategy admission"))
    (for (pair (in-range pairs))
      (for (order (list (if (even? pair) '(callbacks tree) '(tree callbacks))
                       '(callbacks callbacks) '(tree tree)))
        (measure-pair order
          (lambda (strategy) (capture (if (eq? strategy 'callbacks) callbacks tree) repetitions regime))
          (lambda (samples) (report phase regime order samples))))))
  (product-study repetitions pairs)
  (seed-study repetitions pairs)
  (displayln "GENERATOR-PAIRED-OK"))
