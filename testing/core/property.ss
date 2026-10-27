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
;; Scan at most fuel children, pulling only inside the bounded loop body. Selection
;; returns a smaller false node; EOF alone witnesses exhausted immediate children.
(def (scan specification property best fuel attempts steps finish current observe)
  (let/cc reduce
    (using (children (iter ((sample-children best))) :- Iterator)
      (for/fold (used 0) (_ (in-range fuel))
        (let ()
          (unless (current) (finish (vector 'stale best (+ attempts used) steps #f)))
          (def child (children.next!))
          (when (eq? child #!eof)
            (unless (current) (finish (vector 'stale best (+ attempts used) steps #f)))
            (finish (vector 'failed best (+ attempts used) steps #t)))
          (unless (sample? child) (error "shrinker must produce samples"))
          (observe child)
          (def count (+ attempts used 1))
          (def value (sample-value child))
          (unless (current) (finish (vector 'stale best count steps #f)))
          (def eligible (and (accepts? specification value)
            (< (weight specification value) (weight specification (sample-value best)))))
          (unless (current) (finish (vector 'stale best count steps #f)))
          (def outcome (if eligible (boolean-result (property value) "property must return a boolean") #t))
          (unless (current) (finish (vector 'stale best count steps #f)))
          (unless outcome (reduce (vector child (- fuel used 1) count (1+ steps))))
          (1+ used))))
    (finish (vector 'failed best (+ attempts fuel) steps #f))))
;; Restart only from an admitted smaller false node. Zero fuel invokes neither
;; a shrink callback nor an iterator; host callback termination remains a premise.
(def (shrink-failure specification property root budget current observe)
  (let/cc finish
    (let loop ((best root) (fuel budget) (attempts 0) (steps 0))
      (unless (current) (finish (vector 'stale best attempts steps #f)))
      (when (zero? fuel) (finish (vector 'failed best attempts steps #f)))
      (apply loop (vector->list (scan specification property best fuel attempts steps finish current observe))))))
;; One execution owns its observers. A replay guard is transient: old stamps
;; stay checked throughout rerun but are not accumulated into a closure chain.
(def (execute generator property specification seed cases size budget classify guard)
  (def trial 0) (def original #f) (def root #f) (def sources [])
  (def seen (make-hash-table-eq))
  ;; Capture observer callbacks by identity in an invocation-local registry.
  (def (observe tree)
    (def source (sample-current tree))
    (unless (hash-key? seen source) (hash-put! seen source #t) (set! sources (cons source sources))))
  ;; One observation boundary protects all callbacks, trials and shrink proposals.
  (def (current) (and (guard) (current? specification generator sources)))
  ;; Reports are ordinary records, independent of any descriptor/object namespace.
  (def (result status witness attempts steps minimal? (cause #f))
    (make-report status generator property specification seed cases size budget trial original
      (and witness (sample-value witness)) attempts steps minimal? cause witness sources classify))
  (with-catch
    (lambda (cause)
      (def status (if (or (stale-generation? cause) (not (current))) 'stale (classify cause)))
      (unless (memq status '(error exhausted unsupported stale)) (error "invalid error classification" status))
      (result status root 0 0 #f cause))
    (lambda ()
      (def random (random-at seed))
      (let/cc finish
        (for (_ (in-range cases))
          (unless (current) (finish (result 'stale #f 0 0 #f)))
          (set! trial (1+ trial)) (set! original #f) (set! root #f)
          (set! root (generate generator random size))
          (observe root)
          (set! original (sample-value root))
          (unless (current) (finish (result 'stale root 0 0 #f)))
          (unless (accepts? specification original)
            (error "generator produced a value outside its descriptor" original))
          (unless (current) (finish (result 'stale root 0 0 #f)))
          (def outcome (boolean-result (property original) "property must return a boolean"))
          (unless (current) (finish (result 'stale root 0 0 #f)))
          (unless outcome
            (let (shrunk (shrink-failure specification property root budget current observe))
              (finish (result (vector-ref shrunk 0) (vector-ref shrunk 1)
                (vector-ref shrunk 2) (vector-ref shrunk 3) (vector-ref shrunk 4))))))
        (result 'passed #f 0 0 #f)))))
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
