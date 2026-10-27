;;; Independent property execution and replay; only generic generators and stdlib.
(export make-specification specification? check-property replay-property replay-counterexample
        report? report-status report-generator report-property report-specification
        report-seed report-cases report-size report-shrink-budget report-trial report-original
        report-counterexample report-attempts report-steps report-minimal? report-cause)
(import :std/error :std/iter
        (only-in ./generator generator? generate generator-current? sample? sample-value
          sample-children sample-current stale-generation? boolean-result live? random-at))
;; Domain admission, measure and revision ownership remain explicit callbacks.
(defstruct domain (accept measure current) final: #t)
;; Reports retain exact execution configuration and observed source provenance.
(defstruct report (status generator property specification seed cases size shrink-budget
                   trial original counterexample attempts steps minimal? cause witness sources classify) final: #t)
;; Specifications have ordinary Gerbil record identity.
(def specification? domain?)
;; Callback construction uses Gerbil's existing procedure contracts.
(def (make-specification (accept : :procedure) (measure : :procedure)
                        current?: (current (lambda () #t)))
  (using (current : :procedure) (make-domain accept measure current)))
;; Validate measures independently of callback annotations or host numeric coercion.
(def (weight specification value)
  (def result ((domain-measure specification) value))
  (unless (and (exact-integer? result) (>= result 0)) (error "invalid shrink measure" result)) result)
;; Captured observers include every sampled root and every forced shrink branch,
;; including rejected proposals. Unvisited branches retain the selector's own
;; explicit source contract; the kernel cannot inspect arbitrary host closures.
(def (current? specification generator sources)
  (and (live? (domain-current specification)) (generator-current? generator)
       (every live? sources)))
;; Domain rejection is separate from an exception and from a false property.
(def (accepts? specification value)
  (boolean-result ((domain-accept specification) value) "domain predicate must return a boolean"))
;; One invocation owns the latest confirmed witness and consumed proposals.
;; A callback error never installs its in-flight candidate as a false witness.
(defstruct progress (best attempts steps) final: #t)
;; Every domain action has the same source boundary. The hygienic form keeps
;; callback evaluation once, checks EOF too, and leaves exceptions to the owner.
(defrule (with-current current stop body ...)
  (begin
    (unless (current) (stop 'stale #f))
    (begin0 (let () body ...) (unless (current) (stop 'stale #f)))))
;; Admission, descent and falsity are short-circuiting judgments. Each callback
;; runs inside the same revision boundary; a refused candidate is still charged.
(def (smaller-failure? specification property best value current stop)
  (and (with-current current stop (accepts? specification value))
       (< (with-current current stop (weight specification value))
          (with-current current stop (weight specification (sample-value best))))
       (not (with-current current stop
         (boolean-result (property value) "property must return a boolean")))))
;; Pulling owns proposal accounting: charge a returned value before the trailing
;; source check. EOF and an iterator exception have produced no proposal to charge.
(def (next-proposal children state current stop)
  (using (children :- Iterator)
    (with-current current stop
      (let (child (children.next!))
        (unless (eq? child #!eof)
          (progress-attempts-set! state (1+ (progress-attempts state)))) child))))
;; Search the current lazy neighborhood without forcing an unused tail. Confirm
;; only an admitted false candidate; the execution owner handles every exit.
(def (scan specification property state fuel finish current observe)
  (def best (progress-best state))
  (let/cc smaller
    (using (children (iter (with-current current finish ((sample-children best)))) :- Iterator)
      (for (_ (in-range fuel))
        (def child (next-proposal children state current finish))
        (when (eq? child #!eof) (finish 'failed #t))
        (unless (sample? child) (error "shrinker must produce samples"))
        (observe child)
        (when (smaller-failure? specification property best (sample-value child) current finish)
          (progress-best-set! state child)
          (progress-steps-set! state (1+ (progress-steps state)))
          (smaller #t))))
    (finish 'failed #f)))
;; Restart from a confirmed smaller false node; the same owned progress is visible
;; to exception reporting. Zero fuel invokes neither children nor their iterator.
(def (shrink-failure specification property state budget finish current observe)
  (let loop ()
    (unless (current) (finish 'stale #f))
    (def fuel (- budget (progress-attempts state)))
    (when (zero? fuel) (finish 'failed #f))
    (scan specification property state fuel finish current observe)
    (loop)))
;; Source-observer failure during error classification must not replace the
;; original callback exception. Such a report is an error, never valid evidence.
(def (failure-status cause current classify)
  (if (stale-generation? cause) 'stale
    (with-catch (lambda (_) 'error)
      (lambda () (if (current) (classify cause) 'stale)))))
;; One execution owns its observers. A replay guard is transient: old stamps
;; stay checked throughout rerun but are not accumulated into a closure chain.
(def (execute generator property specification seed cases size budget classify guard)
  (def trial 0) (def original #f) (def state (make-progress #f 0 0)) (def sources [])
  (def seen (make-hash-table-eq))
  ;; Capture observer callbacks by identity in an invocation-local registry.
  (def (observe tree)
    (def source (sample-current tree))
    (unless (hash-key? seen source) (hash-put! seen source #t) (set! sources (cons source sources))))
  ;; One observation boundary protects all callbacks, trials and shrink proposals.
  (def (current) (and (guard) (current? specification generator sources)))
  ;; Reports are ordinary records, independent of any descriptor/object namespace.
  (def (result status minimal? (cause #f))
    (def witness (progress-best state))
    (make-report status generator property specification seed cases size budget trial original
      (and witness (sample-value witness)) (progress-attempts state) (progress-steps state)
      minimal? cause witness sources classify))
  (with-catch
    (lambda (cause)
      (def status (failure-status cause current classify))
      (unless (memq status '(error exhausted unsupported stale)) (error "invalid error classification" status))
      (result status #f cause))
    (lambda ()
      (def random (random-at seed))
      (let/cc finish
        ;; The same checked action form serves trials and shrinking; only this
        ;; owner builds reports and classifies failures.
        (def (stop status minimal?) (finish (result status minimal?)))
        (for (_ (in-range cases))
          (with-current current stop
            (set! trial (1+ trial)) (set! original #f) (progress-best-set! state #f)
            (progress-best-set! state (generate generator random size))
            (observe (progress-best state))
            (set! original (sample-value (progress-best state))))
          (unless (with-current current stop (accepts? specification original))
            (error "generator produced a value outside its descriptor" original))
          (unless (with-current current stop
                    (boolean-result (property original) "property must return a boolean"))
            (shrink-failure specification property state budget stop current observe))
          (progress-best-set! state #f))
        (result 'passed #f)))))
;; Public checks require an explicit domain and finite trial/attempt budgets.
;; Error classification may describe a caller's own bounded-generation refusals.
(def (check-property generator (property : :procedure) specification seed: (seed 0)
                     cases: (cases 100) size: (size 20) shrink-budget: (budget 100)
                     classify-error: (classify (lambda (_) 'error)))
  (unless (and (generator? generator) (specification? specification) (procedure? classify)
    (every (lambda (n) (and (exact-integer? n) (>= n 0))) (list seed size budget))
    (exact-integer? cases) (> cases 0)) (error "invalid property testing configuration"))
  (execute generator property specification seed cases size budget classify (lambda () #t)))
;; Seed replay observes the original run's entire visited provenance throughout
;; rerun, while its new report owns only that rerun's observations.
(def (replay-property report)
  (def (current) (current? (report-specification report) (report-generator report) (report-sources report)))
  (unless (current) (error "stale property replay"))
  (execute (report-generator report) (report-property report) (report-specification report)
    (report-seed report) (report-cases report) (report-size report) (report-shrink-budget report)
    (report-classify report) current))
;; Concrete replay draws nothing and forces no selectors/children. Both accepted
;; witness provenance and earlier visited sources retain their original stamps.
(def (replay-counterexample report)
  (unless (eq? (report-status report) 'failed) (error "failed property report required"))
  (def specification (report-specification report)) (def generator (report-generator report))
  (def (current) (current? specification generator (report-sources report)))
  (unless (current) (error "stale property replay"))
  (unless (accepts? specification (report-counterexample report)) (error "invalid property witness"))
  (unless (current) (error "stale property replay"))
  (def outcome ((report-property report) (report-counterexample report)))
  (unless (current) (error "stale property replay"))
  (boolean-result outcome "property must return a boolean"))
