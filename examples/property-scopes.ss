;;; Run-local admission through retained generator algebra and seeded replay.
(export scope-test-cases! nested-scope-test-cases!)
(import :std/test :std/error :std/iter
        (prefix-in :clan/poo/testing/property/generator generator.)
        (prefix-in :clan/poo/testing/property property.)
        (prefix-in :clan/poo/testing/property/replay replay.))

;; Each root advances an application epoch. Ownership can belong to the root
;; or to a subsequently observed child; neither path invents a report owner.
(def (epoch-generator advance capture transform child-source?: (child-source? #f))
  (generator.generator-map (generator.make-tree-generator (lambda (_random _size)
    (advance)
    (if child-source?
      (generator.make-sample 9 (lambda ()
        (list (generator.make-sample 0 (lambda () []) (capture)))))
      (generator.make-sample 9 (lambda () []) (capture))))) transform))

;; Ordinary case registration keeps the same standard suite and runner.
(def (scope-test-cases!)
  (test-case "earlier trials and inspection roots guard nested later construction"
    (for (kind '(pass discard inspect))
      (def epoch 0) (def mapped 0) (def properties 0)
      (def generation (epoch-generator (lambda () (set! epoch (1+ epoch)))
        (lambda () (let (stamp epoch) (lambda () (= stamp epoch))))
        (lambda (value) (set! mapped (1+ mapped)) value)))
      (def domain (property.make-specification exact-integer? abs))
      (if (eq? kind 'inspect)
        (let (result (property.inspect-generator generation domain count: 2))
          (check-eq? (property.inspection-status result) 'stale)
          (check-equal? (length (property.inspection-events result)) 1)
          (check-equal? (property.inspection-draws result) 2)
          (check-eq? (property.inspection-cause result) #f))
        (let (report (property.check-property generation
            (lambda (_) (set! properties (1+ properties)) #t) domain cases: 2
            policy: (property.make-policy precondition: (lambda (_) (not (eq? kind 'discard))) discard-budget: 1)))
          (check-eq? (property.report-status report) 'stale)
          (check-eq? (property.report-cause report) #f)
          (check-equal? (property.report-attempts report) 0)
          (check-equal? properties (if (eq? kind 'pass) 1 0))))
      (check-equal? mapped 1)))
  (test-case "replay refuses a retired shrink owner before a new root mapper"
    (def epoch 0) (def mapped 0)
    (def generation (epoch-generator (lambda () (set! epoch (1+ epoch)))
      (lambda () (let (stamp epoch) (lambda () (= stamp epoch))))
      (lambda (value) (set! mapped (1+ mapped)) value) child-source?: #t))
    (def report (property.check-property generation (lambda (value) (< value 1))
      (property.make-specification exact-integer? abs) cases: 1 shrink-budget: 4))
    (check-equal? (list (property.report-status report) (property.report-counterexample report)
      (property.report-attempts report) mapped) '(failed 9 1 2))
    (def replay (property.replay-property report))
    (check-equal? (list (property.report-status replay) (property.report-attempts replay)
      (property.report-counterexample replay) (property.report-cause replay) mapped) '(stale 0 #f #f 2))
    (check-exception (property.replay-property report) Error?)
    (check-equal? (generator.sample-value
      (generator.generate (generator.generator-unit 42) (generator.random-at 3) 5)) 42))
  (test-case "transient checks compose unwind and stay out of retained tree ownership"
    (def outer #t) (def inner #t) (def mapped 0)
    (def cause (Error "outer generation check")) (def inner-cause (Error "inner generation check"))
    (check-eq? (with-catch identity (lambda ()
      (generator.with-generation-check (lambda () (unless outer (raise cause)))
        (generator.with-generation-check (lambda () (unless inner (raise inner-cause)))
          (generator.generate (generator.generator-map
            (generator.make-generator (lambda (_random _size) (set! outer #f) (set! inner #f) 9) generator.integer-shrinks)
            (lambda (value) (set! mapped (1+ mapped)) value)) (generator.random-at 2) 5))))) cause)
    (check-equal? mapped 0)
    (check-equal? (generator.sample-value
      (generator.generate (generator.generator-unit 3) (generator.random-at 2) 5)) 3)
    (def entered 0)
    (check-exception (generator.with-generation-check #f (set! entered 1)) Error?)
    (check-equal? entered 0)
    (def active #t) (def checks 0)
    (def root (generator.with-generation-check
      (lambda () (set! checks (1+ checks)) (unless active (raise cause)))
      (generator.generate (generator.make-generator (lambda (_random _size) 9) (lambda (_) '(0)))
        (generator.random-at 2) 5)))
    (check-equal? (generator.sample-sources root) [])
    ;; This is a phase snapshot, not another internal definition: capture after
    ;; root construction before testing that later child demand adds no checks.
    (let (completed-checks checks)
      (set! active #f)
      (check-equal? (for/collect (child ((generator.sample-children root))) (generator.sample-value child)) '(0))
      (check-equal? checks completed-checks))
    (def effects 0)
    (def paused (generator.generate (generator.make-generator (lambda (_random _size) 9)
      (lambda (_) (in-coroutine (lambda (yield) (yield 0) (set! effects (1+ effects)) (yield 1)))))
      (generator.random-at 2) 5))
    (set! active #t)
    (check-eq? (with-catch identity (lambda ()
      (generator.with-generation-check (lambda () (unless active (raise cause)))
        (using (cursor (iter ((generator.sample-children paused))) :- Iterator)
          ;; A resumable coroutine captures its caller's dynamic context. Pull
          ;; outside the assertion so later refusal keeps this scope's handler.
          (let (first (cursor.next!))
            (check-equal? (generator.sample-value first) 0)
            (set! active #f)
            (cursor.next!)))))) cause)
    (check-equal? effects 0))
  (test-case "repeated replay keeps a stable observer cost without retaining prior run checkers"
    (def checks 0)
    (def generation (generator.make-generator (lambda (_random _size) 3) generator.integer-shrinks
      current?: (lambda () (set! checks (1+ checks)) #t)))
    (def report (property.check-property generation (lambda (value) (< value 1))
      (property.make-specification exact-integer? abs) cases: 1 shrink-budget: 8))
    (def costs [])
    (for (_ (in-range 12))
      (set! checks 0)
      (set! report (property.replay-property report))
      (set! costs (cons checks costs))
      (check-eq? (property.report-status report) 'failed)
      (check-equal? (property.report-counterexample report) 1))
    (check (> (car costs) 0) => #t)
    (check (every (lambda (cost) (= cost (car costs))) costs) => #t)))

;; Ordinary producer ownership supplies an ancestor without a second runner.
(def (under-owner action current)
  (with-catch identity (lambda ()
    (generator.generate (generator.make-generator (lambda (_random _size) (action))
      (lambda (_) []) current?: current) (generator.random-at 11) 0))))

;; Nested admission uses the same standard suite and public module protocol.
(def (nested-scope-test-cases!)
  (test-case "nested product weights inherit producer sources before the next field"
    (def live #t) (def first 0) (def later 0)
    (def domain (property.make-product-specification
      (list (property.make-specification exact-integer? (lambda (_)
              (set! first (1+ first)) (set! live #f) 1))
            (property.make-specification exact-integer? (lambda (_) (set! later (1+ later)) 1)))))
    (check (generator.stale-generation? (under-owner
      (lambda () (property.specification-weight domain '(1 2))) (lambda () live))) => #t)
    (check-equal? (list first later) '(1 0)))
  (test-case "terminal child reports cannot escape an obsolete ancestor or recurse in their own guard"
    (for (kind '(check inspect))
      (def parent-live #t) (def child-live #t) (def after 0) (def closed 0)
      (def parent (property.make-specification exact-integer? abs current?: (lambda () parent-live)))
      (def child (property.make-specification exact-integer? abs current?: (lambda () child-live)))
      ;; Both scopes become obsolete. The child's local stop must unwind before
      ;; ancestor admission, so no checker can invoke itself through that stop.
      (def (invalidate _)
        (set! parent-live #f) (set! child-live #f) #t)
      (def report (property.check-property (generator.generator-unit 1) (lambda (_)
        (try
          (case kind
            ((check) (property.check-property (generator.generator-unit 1) invalidate child cases: 1))
            ((inspect) (property.inspect-generator (generator.generator-unit 1) child count: 1
              labels: (lambda (value) (invalidate value) []))))
          (set! after (1+ after)) #t
          (finally (set! closed (1+ closed))))) parent cases: 1))
      (check-eq? (property.report-status report) 'stale)
      (check-equal? (list after closed) '(0 1))))
  (test-case "portable stages inherit ancestors before encoding writing or property admission"
    (for (stage '(reconfirm encode decode))
      (def live #t) (def armed #f) (def encodes 0) (def admissions 0) (def properties 0)
      (def domain (property.make-specification (lambda (value)
        (set! admissions (1+ admissions)) (exact-integer? value)) abs))
      ;; The witness remains valid in its own domain; only the enclosing run ends.
      (def (predicate _)
        (set! properties (1+ properties))
        (when (and armed (eq? stage 'reconfirm)) (set! live #f)) #f)
      (def report (property.check-property (generator.generator-unit 1) predicate domain cases: 1 shrink-budget: 0))
      (def codec (replay.make-codec 'scope
        (lambda (value) (set! encodes (1+ encodes))
          (when (eq? stage 'encode) (set! live #f)) value)
        (lambda (value) (set! live #f) value)))
      (def output (open-output-string))
      (set! admissions 0) (set! properties 0) (set! armed #t)
      (def result (under-owner (lambda ()
        (if (eq? stage 'decode)
          (replay.read-counterexample codec
            (open-input-string "#(property-counterexample 1 scope 1)") domain predicate)
          (replay.write-counterexample report codec output))) (lambda () live)))
      (check (generator.stale-generation? result) => #t)
      (check-equal? (get-output-string output) "")
      (check-equal? encodes (if (eq? stage 'encode) 1 0))
      (when (eq? stage 'decode) (check-equal? (list admissions properties) '(0 0)))))
  (test-case "nested codec callback exceptions retain identity even after ancestor revision"
    (def live #t) (def cause (cons 'codec 'cause))
    (def report (property.check-property (generator.generator-unit 1) (lambda (_) #f)
      (property.make-specification exact-integer? abs) cases: 1 shrink-budget: 0))
    (def codec (replay.make-codec 'cause (lambda (_)
      (set! live #f) (raise cause)) identity))
    (def output (open-output-string))
    (check-eq? (under-owner (lambda () (replay.write-counterexample report codec output)) (lambda () live)) cause)
    (check-equal? (get-output-string output) ""))
  (test-case "fresh nested reports preserve outcomes without retaining ancestor guards"
    (def visits 0)
    (def domain (property.make-specification exact-integer? abs))
    ;; Finite nesting checks normal child report publication as well as unwinding.
    (def (nested depth)
      (property.check-property (generator.generator-unit 1) (lambda (_)
        (set! visits (1+ visits))
        (or (zero? depth) (eq? (property.report-status (nested (1- depth))) 'passed))) domain cases: 1))
    (check-eq? (property.report-status (nested 8)) 'passed)
    (check-equal? visits 9)
    (check-equal? (property.specification-weight (property.make-product-specification []) []) 0)
    (check-eq? (property.report-status (nested 0)) 'passed)
    (check-equal? visits 10)))
