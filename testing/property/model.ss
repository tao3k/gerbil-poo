;;; Generic finite model traces. Domains supply admission and normalization.
(export make-model model? make-system system? valid-trace? repair-trace shrink-trace trace-generator draw-trace check-trace
        trace-report? trace-report-matched? trace-report-phase trace-report-index
        trace-report-has-command? trace-report-command trace-report-expected trace-report-actual)
(import :std/error :std/iter (only-in ./generator data-list-shrinks with-sources)
        (prefix-in (only-in ./generator make-generator make-sample sample-sequence sample-children sample-value) core.))
;; Private model records hold ordinary callbacks, not POO descriptors. Trace
;; laws require pure model transitions. The shared source boundary also refuses
;; declared revisions between actions without retaining wrappers or run checks.
(defstruct reference (initial enabled advance observe accept normalize) final: #t)
;; Each fixture supplies owned state and its actual transition/observation functions.
(defstruct fixture (initial step observe) final: #t)
;; Presence is separate from payload so false remains a valid command.
(defstruct trace-report (matched? phase index has-command? command expected actual) final: #t)

;; Public recognizers retain ordinary Gerbil record identity.
(def model? reference?)
;; An actual fixture remains private to its scoped caller.
(def system? fixture?)

;; The model's normalization and membership are explicit domain responsibilities.
(def (make-model (initial : :procedure) (enabled : :procedure) (advance : :procedure)
                 (observe : :procedure) (accept : :procedure) (normalize : :procedure))
  (make-reference initial enabled advance observe accept normalize))
;; The fixture constructor owns no setup/cleanup policy; its caller supplies scope.
(def (make-system initial (step : :procedure) (observe : :procedure))
  (make-fixture initial step observe))
;; Model predicates cannot confuse arbitrary truthy values with authorization.
(def (judgment value message)
  (unless (boolean? value) (error message value)) value)
;; One shared fold advances retained commands. Selection returns two values,
;; separating keep/omit from a command payload which may itself be false. Each
;; caller action shares the active source/check scope; refusal skips the next one.
;; Admitters check shape first; this one copy freezes the command spine BEFORE
;; initialization or selection can edit caller-owned pairs. Payloads stay shared.
(def (fold-trace model commands select)
  (def owned (list-copy commands))
  (foldl (lambda (raw progress)
    (let-values (((keep? command) (select (car progress) raw)))
      (if keep?
        (let-values (((next _reply) (with-sources [] ((reference-advance model) (car progress) command))))
          (cons next (cons command (cdr progress)))) progress)))
    (cons (with-sources [] ((reference-initial model))) []) owned))
;; Retain the exact normalized commands admitted by every model prefix. A false
;; result rejects the whole trace; an empty prepared list is a successful trace.
(def (prepare-trace model commands)
  (let/cc invalid
    (unless (list? commands) (invalid #f))
    (reverse (cdr (fold-trace model commands (lambda (state raw)
      (unless (judgment (with-sources [] ((reference-accept model) raw)) "command predicate must return a boolean") (invalid #f))
      (def command (with-sources [] ((reference-normalize model) raw)))
      (unless (judgment (with-sources [] ((reference-enabled model) state command)) "trace precondition must return a boolean") (invalid #f))
      (values #t command)))))))
;; Boolean admission is only a projection of the same preparation protocol.
(def (valid-trace? model commands) (and (prepare-trace model commands) #t))
;; Finite spine admission precedes initialization. Dependency retirement uses
;; the same fold and never treats an improper tail as a completed prefix.
(def (repair-trace (model :~ model?) (commands :~ list?))
  (reverse (cdr (fold-trace model commands (lambda (state raw)
    (if (judgment (with-sources [] ((reference-accept model) raw)) "command predicate must return a boolean")
      (let (command (with-sources [] ((reference-normalize model) raw)))
        (values (judgment (with-sources [] ((reference-enabled model) state command)) "trace precondition must return a boolean") command))
      (values #f #f)))))))
;; Share the collection neighborhood: aligned blocks precede parameter shrinks.
;; Repair each proposal once in model order; no draw, fixture or handle renaming
;; participates. The shared sequence policy enforces finite parameter lists
;; before any candidate is repaired; callback causes keep their identity.
;; The runner alone decides domain admission, strict descent, falsity and budgets.
(def (shrink-trace (model :~ model?) commands (shrink : :procedure))
  (map (cut repair-trace model <>) (data-list-shrinks commands shrink 0)))
;; Exact natural limits exclude the iterator's valid reverse/fractional ranges.
;; This predicate is a contract on configuration, not on generated commands.
(def (trace-limit? value) (and (exact-integer? value) (>= value 0)))
;; Gerbil contracts admit the entire configuration before model initialization.
;; Two-value drawing and the existing state fold retain their order and causes;
;; zero cap still initializes once but invokes no draw/command callback.
(def (draw-trace (model :~ model?) (draw : :procedure)
                 (steps :~ trace-limit?) (random : :procedure) (size :~ trace-limit?))
  (let/cc done
    (def progress (for/fold (progress (cons (with-sources [] ((reference-initial model))) [])) (_ (in-range (min steps size)))
      (let-values (((continue? raw) (with-sources [] (draw (car progress) random size))))
        (unless (judgment continue? "draw continuation must return a boolean") (done (reverse (cdr progress))))
        (unless (judgment (with-sources [] ((reference-accept model) raw)) "command predicate must return a boolean")
          (error "generated command is outside its domain"))
        (let (command (with-sources [] ((reference-normalize model) raw)))
          (unless (judgment (with-sources [] ((reference-enabled model) (car progress) command)) "trace precondition must return a boolean")
            (error "disabled generated command" command))
          (let-values (((next _reply) (with-sources [] ((reference-advance model) (car progress) command))))
            (cons next (cons command (cdr progress))))))))
    (reverse (cdr progress))))
;; One command exposes a lazy coordinate sequence after admitting and owning its
;; finite result spine. The outer generator rebuilds descendants from each repaired
;; trace, so parameter samples have no independent recursive children here.
(def (trace-command command shrink)
  (core.make-sample command (lambda ()
    (using (candidates (with-sources [] (shrink command)) :~ list?)
      (def owned (list-copy candidates))
      (in-coroutine (lambda (yield)
        (for (candidate owned)
          (yield (core.make-sample candidate (lambda () []))))))))))
;; Share sequence structural/coordinate order, without repairing an unused root
;; or constructing every repaired candidate before the first budgeted pull.
(def (trace-neighborhood model commands shrink)
  (def root (core.sample-sequence (map (cut trace-command <> shrink) commands)))
  (in-coroutine (lambda (yield)
    (for (candidate ((core.sample-children root)))
      (yield (repair-trace model (core.sample-value candidate)))))))

;; The ordinary generator owns lazy iteration, provenance and restart from each
;; confirmed repaired value. The runner's existing proposal budget stops demand;
;; draw limits and callback contracts precede initialization. Standard generator
;; options pass unchanged to their existing owner, including current?/sources.
(def (trace-generator model draw shrink steps . options)
  (using ((model :~ model?) (draw : :procedure) (shrink : :procedure) (steps :~ trace-limit?))
    (apply core.make-generator (lambda (random size) (draw-trace model draw steps random size))
      (lambda (commands) (trace-neighborhood model commands shrink)) options)))

;; Scope and first-difference execution are generic. The same? callback receives
;; phase/expected/actual, permitting typed domains to normalize at that boundary.
(def (check-trace model commands (with-system : :procedure)
                  same?: (same? (lambda (_phase left right) (equal? left right))))
  (def prepared (prepare-trace model commands))
  (unless prepared (error "invalid command trace"))
  ;; The comparison fold exits before any later step or unnecessary observation.
  ;; Source checks surround each observer separately, including argument evaluation;
  ;; a revised reference cannot trigger the following actual observer or step.
  (def (run actual)
    (unless (system? actual) (error "system required"))
    (let/cc different
      (def (compare phase index present? command expected found)
        (unless (judgment (with-sources [] (same? phase expected found)) "trace equality must return a boolean")
          (different (make-trace-report #f phase index present? command expected found))))
      (def reference (with-sources [] ((reference-initial model))))
      (def initial (fixture-initial actual))
      (let* ((expected (with-sources [] ((reference-observe model) reference)))
             (found (with-sources [] ((fixture-observe actual) initial))))
        (compare 'initial 0 #f #f expected found))
      (for/fold (states (cons reference initial)) ((command prepared) (index (in-range (length prepared))))
        (let*-values (((next expected) (with-sources [] ((reference-advance model) (car states) command)))
                      ((updated found) (with-sources [] ((fixture-step actual) (cdr states) command))))
          (compare 'result index #t command expected found)
          (let* ((expected-state (with-sources [] ((reference-observe model) next)))
                 (found-state (with-sources [] ((fixture-observe actual) updated))))
            (compare 'state index #t command expected-state found-state))
          (cons next updated)))
      (make-trace-report #t 'complete (length prepared) #f #f #f #f)))
  (def active? #t) (def entered? #f) (def result #f)
  (try
    (let (returned (with-sources [] (with-system (lambda (actual)
      (unless (and active? (not entered?)) (error "trace fixture callback is not active or was reused"))
      (set! entered? #t) (set! result (run actual)) result))))
      (unless (and entered? result (eq? returned result)) (error "trace fixture did not return its observation")) result)
    (finally (set! active? #f))))
