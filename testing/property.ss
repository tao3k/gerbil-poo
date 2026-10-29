;;; Independent property execution and replay; only generic generators and stdlib.
(export make-specification specification? check-property replay-property replay-counterexample check-counterexample define-property
        report? report-status report-generator report-property report-specification
        report-seed report-cases report-size report-shrink-budget report-trial report-original
        report-counterexample report-attempts report-steps report-minimal? report-cause report-trial-size report-size-limit report-name report-accepted report-discarded report-labels
        make-policy policy? make-product-specification specification-current? report-current? report-diagnostics
        inspect-generator inspection? inspection-status inspection-seed inspection-size inspection-count inspection-depth inspection-budget
        inspection-draws inspection-attempts inspection-events inspection-counts
        inspection-truncated? inspection-cause inspection-current?)
(import :std/error :std/iter (only-in :std/list/list delete-duplicates/hash)
        (only-in ./property/generator generator? generate generator-current? sample? sample-value
          sample-children sample-current rejected? proposal-sources generation-exhausted?
          stale-generation? boolean-result live? random-at))
;; Domain admission, measure and revision ownership remain explicit callbacks.
(defstruct domain (accept measure current) final: #t)
;; Reports retain exact execution configuration and observed source provenance.
(defstruct report (status generator property specification seed cases size trial-size size-limit size-current shrink-budget
                   trial original counterexample attempts steps minimal? cause witness sources classify policy accepted discarded labels) final: #t)
;; Trial policy is independent of descriptors; coverage uses minimum effective counts.
(defstruct trial-policy (name precondition labels required discard-budget) final: #t constructor: :init!)
;; Copy requirements at construction so callers cannot mutate an admitted policy.
(defmethod {:init! trial-policy}
  (lambda (self name precondition labels required discard-budget)
    (unless (and (or (not name) (symbol? name) (string? name))
      (procedure? precondition) (procedure? labels) (list? required)
      (every (lambda (entry) (and (pair? entry) (symbol? (car entry))
        (exact-integer? (cdr entry)) (>= (cdr entry) 0))) required)
      (exact-integer? discard-budget) (>= discard-budget 0)) (error "invalid trial policy"))
    (set! (trial-policy-name self) name)
    (set! (trial-policy-precondition self) precondition)
    (set! (trial-policy-labels self) labels)
    (set! (trial-policy-required self) (map (lambda (entry) (cons (car entry) (cdr entry))) required))
    (set! (trial-policy-discard-budget self) discard-budget)))
;; The public constructor names policy dimensions rather than positional callbacks.
(def (make-policy name: (name #f) precondition: (precondition (lambda (_) #t))
                  labels: (labels (lambda (_) [])) required: (required []) discard-budget: (budget 0))
  (make-trial-policy name precondition labels required budget))
;; Identity recognition stays with the standard record implementation.
(def policy? trial-policy?)
;; Property names are diagnostic identity, never source-currentness authority.
(def (report-name report) (trial-policy-name (report-policy report)))
;; A discarded trial is explicit, Boolean and separate from descriptor refusal.
(def (eligible? policy value)
  (boolean-result ((trial-policy-precondition policy) value) "precondition must return a boolean"))
;; Count one classification at most once per root; diagnostics and checks use
;; separate count tables, so an inspection can never satisfy property coverage.
(def (classify-labels! classify value counts)
  (def labels (classify value))
  (unless (and (list? labels) (every symbol? labels)) (error "labels must be a list of symbols"))
  (for (label (delete-duplicates/hash labels))
    (hash-put! counts label (1+ (hash-ref counts label 0)))))
;; Shrink candidates never contribute effective-trial coverage.
(def (classify-trial! policy value counts)
  (classify-labels! (trial-policy-labels policy) value counts))
;; Threshold failure is an inconclusive coverage report, never a false property.
(def (covered? policy counts)
  (every (lambda (entry) (>= (hash-ref counts (car entry) 0) (cdr entry)))
    (trial-policy-required policy)))
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
;; Replay can preflight a domain before invoking an application decoder.
;; Boolean admission stays with the existing source observer protocol.
(def (specification-current? specification)
  (unless (specification? specification) (error "property specification required"))
  (live? (domain-current specification)))
;; Products share the existing domain/measure/currentness gates; domains are fixed
;; for one check while dependent generator branches retain their own provenance.
(def (make-product-specification specifications)
  (unless (and (list? specifications) (every specification? specifications))
    (error "product specifications required"))
  (def domains (map identity specifications))
  (make-specification
    (lambda (values) (and (list? values) (= (length values) (length domains))
      (andmap (lambda (domain value) (accepts? domain value)) domains values)))
    (lambda (values) (apply + (map weight domains values)))
    current?: (lambda () (every (lambda (domain) (live? (domain-current domain))) domains))))
;; Delayed assertions cannot reuse a formerly passing report after its sources change.
(def (report-current? report)
  (unless (report? report) (error "property report required"))
  (and (live? (report-size-current report))
    (current? (report-specification report) (report-generator report) (report-sources report))))
;; Labels belong to one generated row; preserve a malformed/absent row as data.
(def (argument-bindings names value)
  (def row (if (vector? value) (vector->list value) value))
  (if (and (pair? names) (list? row) (= (length names) (length row))) (map cons names row) value))
;; Pure diagnostics contain no generator/property closures. Original exception
;; identity is retained as data; only a passing report requires fresh admission.
(def (report-diagnostics report bindings: (names []))
  (unless (and (report? report) (list? names) (every symbol? names)
    (= (length names) (length (delete-duplicates/hash names)))) (error "invalid property diagnostics"))
  (def status (report-status report))
  (when (and (eq? status 'passed) (not (report-current? report))) (set! status 'stale))
  (list (cons 'status status) (cons 'property (report-name report))
    (cons 'seed (report-seed report)) (cons 'trial (report-trial report))
    (cons 'trial-size (report-trial-size report)) (cons 'accepted (report-accepted report))
    (cons 'discarded (report-discarded report)) (cons 'labels (report-labels report))
    (cons 'original (argument-bindings names (report-original report)))
    (cons 'counterexample (argument-bindings names (report-counterexample report)))
    (cons 'attempts (report-attempts report)) (cons 'steps (report-steps report))
    (cons 'minimal? (report-minimal? report)) (cons 'cause (report-cause report))))
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
        (observe child)
        (when (and (sample? child)
                   (smaller-failure? specification property best (sample-value child) current finish))
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
      (lambda () (if (current)
        (if (generation-exhausted? cause) 'exhausted (classify cause)) 'stale)))))
;; Both execution owners retain the precise visited leaves, including rejected
;; proposals. Identity deduplication preserves the existing source-check order.
(def (observe-sources tree seen sources)
  (foldl (lambda (source sources)
    (if (hash-key? seen source) sources
      (begin (hash-put! seen source #t) (cons source sources)))) sources (proposal-sources tree)))

;; Inspections are diagnostic data, never property evidence or serialized trees.
;; No sample child factory is retained in their public event sequence.
(defstruct inspection (generator specification seed size count depth budget status draws attempts events counts truncated? cause sources) final: #t)
;; Delayed consumers can refuse diagnostics whose visited sources have changed.
(def (inspection-current? inspection)
  (current? (inspection-specification inspection) (inspection-generator inspection) (inspection-sources inspection)))
;; One finite observer handles sampling (depth/budget zero) and depth-first shrink
;; exploration. Paths are [draw-index child-index ...]; tombstones are charged.
;; Depth and exhausted fuel never force children merely to discover an EOF.
(def (inspect-generator generator specification seed: (seed 0) count: (count 10)
                       size: (size 20) depth: (depth 0) proposal-budget: (budget 0)
                       labels: (labels (lambda (_) [])) classify-error: (classify (lambda (_) 'error)))
  (unless (and (generator? generator) (specification? specification) (procedure? labels) (procedure? classify)
    (every (lambda (n) (and (exact-integer? n) (>= n 0))) (list seed count size depth budget)))
    (error "invalid generator inspection configuration"))
  (def state (make-progress #f 0 0))
  (def sources []) (def seen (make-hash-table-eq))
  (def events []) (def counts (make-hash-table-eq))
  (def draws 0) (def truncated? #f)
  ;; Currentness includes every visited branch, even a refused or pruned child.
  (def (current) (current? specification generator sources))
  ;; Partial diagnostics retain charged work and the original callback exception.
  (def (result status (cause #f))
    (make-inspection generator specification seed size count depth budget status draws (progress-attempts state)
      (reverse events) (hash->list counts) truncated? cause sources))
  ;; Flat events preserve false values distinctly from pruned proposals.
  (def (record! path kind value)
    (set! events (cons (vector path kind value) events)))
  ;; Observation is shared with property execution, rather than a second registry.
  (def (observe tree) (set! sources (observe-sources tree seen sources)))
  (with-catch (lambda (cause)
      (def status (failure-status cause current classify))
      (unless (memq status '(error exhausted unsupported stale)) (error "invalid error classification" status))
      (result status cause))
    (lambda ()
      (let/cc finish
        ;; The same source boundary also owns post-callback and EOF checks.
        (def (stop status _minimal?) (finish (result status)))
        ;; Admission is a finite classification, independent of traversal policy.
        ;; Refused nodes never invoke measures or descendant factories.
        (def (node-diagnosis tree root? parent-weight)
          (cond
            ((rejected? tree) (values 'pruned #f #f))
            (else
              (def value (sample-value tree))
              (if (not (with-current current stop (accepts? specification value)))
                (values 'outside-domain value #f)
                (let (cost (with-current current stop (weight specification value)))
                  (values (cond (root? 'root) ((< cost parent-weight) 'value) (else 'nondecreasing)) value cost))))))
        ;; Child pulls share next-proposal with the real shrinker: returned
        ;; tombstones count, EOF/throws do not, and unused tails remain untouched.
        (def (children! tree path remaining cost)
          (using (children (iter (with-current current stop ((sample-children tree)))) :- Iterator)
            (let next ((index 0))
              (if (= (progress-attempts state) budget) (set! truncated? #t)
                (let (child (next-proposal children state current stop))
                  (unless (eq? child #!eof)
                    (visit child (append path (list index)) (1- remaining) cost #f)
                    (next (1+ index))))))))
        ;; Record the edge before exploring descendants; only decreasing admitted
        ;; values authorize expansion. No search hides behind a refused node.
        (def (visit tree path remaining parent-weight root?)
          (with-current current stop
            (observe tree)
            (unless (current) (stop 'stale #f))
            (let-values (((kind value cost) (node-diagnosis tree root? parent-weight)))
              (record! path kind value)
              (when (eq? kind 'root) (with-current current stop (classify-labels! labels value counts)))
              (when (memq kind '(root value))
                (if (or (zero? remaining) (= (progress-attempts state) budget))
                  (set! truncated? #t)
                  (children! tree path remaining cost))))))
        (def random (random-at seed))
        (for (index (in-range count))
          (with-current current stop
            (set! draws (1+ draws))
            (def tree (generate generator random size))
            (observe tree)
            (visit tree (list index) depth #f #t)))
        (with-current current stop (result 'complete))))))

;; One execution owns its observers. A replay guard is transient: old stamps
;; stay checked throughout rerun but are not accumulated into a closure chain.
(def (execute generator property specification seed cases size size-limit budget classify guard size-current policy)
  (def trial 0) (def original #f) (def state (make-progress #f 0 0)) (def sources [])
  (def trial-size #f)
  (def accepted 0) (def discarded 0) (def counts (make-hash-table-eq))
  ;; Shrink admission preserves preconditions without recording new coverage.
  (def (shrink-property value)
    (or (not (eligible? policy value)) (boolean-result (property value) "property must return a boolean")))
  (def seen (make-hash-table-eq))
  ;; Capture observer callbacks by identity in an invocation-local registry.
  (def (observe tree)
    (set! sources (observe-sources tree seen sources)))
  ;; One observation boundary protects all callbacks, trials and shrink proposals.
  (def (current) (and (guard) (live? size-current) (current? specification generator sources)))
  ;; Reports are ordinary records, independent of any descriptor/object namespace.
  (def (result status minimal? (cause #f))
    (def witness (progress-best state))
    (make-report status generator property specification seed cases size trial-size size-limit size-current budget trial original
      (and witness (sample-value witness)) (progress-attempts state) (progress-steps state)
      minimal? cause witness sources classify policy accepted discarded (hash->list counts)))
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
        (let/cc complete
          (for (_ (in-range (+ cases (trial-policy-discard-budget policy))))
            (with-current current stop
              (set! trial (1+ trial)) (set! original #f) (progress-best-set! state #f)
              (set! trial-size #f)
              (set! trial-size (if (procedure? size) (size trial) size))
              (unless (and (exact-integer? trial-size) (>= trial-size 0))
                (error "size policy must return a natural number" trial-size))
              (when (> trial-size size-limit) (error "size policy exceeded its declared limit" trial-size size-limit))
              (unless (current) (stop 'stale #f))
              (progress-best-set! state (generate generator random trial-size))
              (observe (progress-best state))
              (set! original (sample-value (progress-best state))))
            (unless (with-current current stop (accepts? specification original))
              (error "generator produced a value outside its descriptor" original))
            (cond
              ((not (with-current current stop (eligible? policy original)))
               (set! discarded (1+ discarded))
               (when (> discarded (trial-policy-discard-budget policy)) (stop 'exhausted #f)))
              (else
               (set! accepted (1+ accepted))
               (with-current current stop (classify-trial! policy original counts))
               (unless (with-current current stop
                         (boolean-result (property original) "property must return a boolean"))
                 (shrink-failure specification shrink-property state budget stop current observe))))
            (progress-best-set! state #f)
            (when (= accepted cases) (complete #t))))
        (unless (= accepted cases) (stop 'exhausted #f))
        (unless (covered? policy counts) (stop 'coverage #f))
        (result 'passed #f)))))
;; Public checks require an explicit domain and finite trial/attempt budgets.
;; Error classification may describe a caller's own bounded-generation refusals.
(def (check-property generator (property : :procedure) specification seed: (seed 0)
                     cases: (cases 100) size: (size 20) shrink-budget: (budget 100)
                     size-limit: (size-limit (and (not (procedure? size)) size))
                     size-current?: (size-current (lambda () #t))
                     classify-error: (classify (lambda (_) 'error))
                     policy: (policy (make-policy)) name: (name #f))
  (unless (and (policy? policy) (generator? generator) (specification? specification) (procedure? classify)
    (procedure? size-current) (or (procedure? size) (and (exact-integer? size) (>= size 0)))
    (every (lambda (n) (and (exact-integer? n) (>= n 0))) (list seed budget size-limit))
    (exact-integer? cases) (> cases 0)) (error "invalid property testing configuration"))
  (def named (if name (make-policy name: name
    precondition: (trial-policy-precondition policy) labels: (trial-policy-labels policy)
    required: (trial-policy-required policy) discard-budget: (trial-policy-discard-budget policy)) policy))
  (execute generator property specification seed cases size size-limit budget classify (lambda () #t) size-current named))
;; Named properties remain ordinary callable Gerbil bindings inside :std/test.
;; Generator/specification expressions run once per check; replay owns that run.
(defrule (define-property (name value) generator specification body ...)
  (def (name . options)
    (apply check-property generator (lambda (value) body ...) specification name: 'name options)))
;; Seed replay observes the original run's entire visited provenance throughout
;; rerun, while its new report owns only that rerun's observations.
(def (replay-property report)
  (def (current) (and (live? (report-size-current report))
    (current? (report-specification report) (report-generator report) (report-sources report))))
  (unless (current) (error "stale property replay"))
  (execute (report-generator report) (report-property report) (report-specification report)
    (report-seed report) (report-cases report) (report-size report) (report-size-limit report) (report-shrink-budget report)
    (report-classify report) current (report-size-current report) (report-policy report)))

;; Concrete witnesses are admitted by their captured precondition/domain, not by
;; generation coverage. Each callback shares the existing source boundary.
(def (check-counterexample value (property : :procedure) specification
                          policy: (policy (make-policy)) current?: (guard (lambda () #t)))
  (unless (and (specification? specification) (policy? policy) (procedure? guard))
    (error "invalid counterexample configuration"))
  ;; A callback may revise either the domain or its declared external sources.
  (def (current) (and (live? guard) (specification-current? specification)))
  ;; Concrete replay refuses stale evidence instead of constructing a run report.
  (def (stop _status _minimal) (error "stale property replay"))
  (unless (with-current current stop (eligible? policy value)) (error "invalid property witness"))
  (unless (with-current current stop (accepts? specification value)) (error "invalid property witness"))
  (with-current current stop (boolean-result (property value) "property must return a boolean")))
;; Concrete replay draws nothing and forces no selectors/children. Both accepted
;; witness provenance and earlier visited sources retain their original stamps.
(def (replay-counterexample report)
  (unless (eq? (report-status report) 'failed) (error "failed property report required"))
  (check-counterexample (report-counterexample report) (report-property report)
    (report-specification report) policy: (report-policy report)
    current?: (lambda () (report-current? report))))
