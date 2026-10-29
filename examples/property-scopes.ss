;;; Run-local admission through retained generator algebra and seeded replay.
(export scope-test-cases!)
(import :std/test :std/error :std/iter
        (prefix-in :clan/poo/testing/property/generator generator.)
        (prefix-in :clan/poo/testing/property property.))

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
