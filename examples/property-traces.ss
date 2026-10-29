;;; Bounded model drawing uses the generic protocol and standard Gerbil contracts.
(export trace-draw-test-cases! trace-sequence-test-cases!)
(import :std/test :std/error :std/iter
        (prefix-in :clan/poo/testing/property property.)
        (prefix-in :clan/poo/testing/property/generator generator.)
        (prefix-in :clan/poo/testing/property/model model.))

;; Register ordinary cases in the existing independent kernel suite.
(def (trace-draw-test-cases!)
  (test-case "trace limits reject reverse fractional and unbounded ranges before effects"
    (def starts 0) (def draws 0) (def accepts 0)
    (def reference (model.make-model (lambda () (set! starts (1+ starts)) 0)
      (lambda (_state _command) #t) (lambda (state _command) (values (1+ state) #f))
      identity (lambda (_) (set! accepts (1+ accepts)) #t) identity))
    ;; Every malformed budget is exercised in both dimensions, including NaN.
    (for-each (lambda (bad)
      (for-each (lambda (limits)
        (check-exception (model.draw-trace reference
          (lambda (_state _random _size) (set! draws (1+ draws)) (values #t 'step))
          (car limits) (generator.random-at 1) (cadr limits)) Error?))
        (list (list bad 4) (list 4 bad))))
      (list -1 -5 1/2 2.0 +inf.0 -inf.0 +nan.0 #f 'unbounded))
    (check-equal? (list starts draws accepts) '(0 0 0)))
  (test-case "trace callable and model contracts refuse before initialization"
    (def starts 0)
    (def reference (model.make-model (lambda () (set! starts (1+ starts)) 0)
      (lambda (_state _command) #t) (lambda (state _command) (values state #f)) identity (lambda (_) #t) identity))
    (check-exception (model.draw-trace #f (lambda (_state _random _size) (values #f #f))
      0 (generator.random-at 1) 0) Error?)
    (check-exception (model.draw-trace reference #f 0 (generator.random-at 1) 0) Error?)
    (check-exception (model.draw-trace reference (lambda (_state _random _size) (values #f #f))
      0 #f 0) Error?)
    (check-equal? starts 0))
  (test-case "natural caps preserve state order original size and zero initialization"
    (for-each (lambda (limits)
      (def starts 0) (def calls [])
      (def reference (model.make-model (lambda () (set! starts (1+ starts)) 0)
        (lambda (state command) (= state command))
        (lambda (state _command) (values (1+ state) #f)) identity exact-integer? identity))
      (def trace (model.draw-trace reference (lambda (state _random size)
        (set! calls (cons (list state size) calls)) (values #t state))
        (car limits) (generator.random-at 1) (cadr limits)))
      (check-equal? (length trace) (min (car limits) (cadr limits)))
      (check-equal? trace (iota (length trace)))
      (check-equal? (reverse calls) (map (lambda (state) (list state (cadr limits))) trace))
      (check-equal? starts 1))
      (list '(0 4) '(4 0) '(2 5) '(5 2) (list (expt 2 70) 3))))
  (test-case "early stop false commands and exact callback causes keep their boundaries"
    (def steps 0) (def normalized 0) (def cause (cons 'trace 'cause))
    (def reference (model.make-model (lambda () 0) (lambda (_state _command) #t)
      (lambda (state _command) (set! steps (1+ steps)) (values (1+ state) #f)) identity
      boolean? (lambda (raw) (set! normalized (1+ normalized)) raw)))
    (def trace (model.draw-trace reference (lambda (state _random _size)
      (if (= state 2) (values #f 'not-a-command) (values #t #f)))
      5 (generator.random-at 1) 4))
    (check-equal? trace '(#f #f))
    (check-equal? (list steps normalized) '(2 2))
    (check-eq? (with-catch identity (lambda () (model.draw-trace reference
      (lambda (_state _random _size) (raise cause)) 1 (generator.random-at 1) 1))) cause)
    (def failing (model.make-model (lambda () (raise cause)) (lambda (_state _command) #t)
      (lambda (state _command) (values state #f)) identity boolean? identity))
    (check-eq? (with-catch identity (lambda () (model.draw-trace failing
      (lambda (_state _random _size) (error "zero-cap draw")) 0 (generator.random-at 1) 4))) cause)
    (def disabled (model.make-model (lambda () 0) (lambda (_state _command) #f)
      (lambda (state _command) (set! steps (1+ steps)) (values state #f)) identity boolean? identity))
    (check-exception (model.draw-trace disabled (lambda (_state _random _size) (values #t #f))
      1 (generator.random-at 1) 1) Error?)
    (check-equal? steps 2)
    (check-exception (model.draw-trace reference (lambda (_state _random _size) (values 'maybe #f))
      1 (generator.random-at 1) 1) Error?)))


;; A cyclic spine is a finite malformed graph, not a lazy Iterator. Standard list?
;; detects it without traversing an unbounded sequence or adding a graph registry.
(def (invalid-spines)
  (let (cycle (list 'item))
    (set-cdr! cycle cycle)
    (list #f '#(item) '(item . tail) cycle)))

;; All finite sequence consumers share shape/source admission and exact failures.
(def (trace-sequence-test-cases!)
  (test-case "invalid trace spines refuse before initialization or prefix repair"
    (def starts 0) (def advances 0) (def parameters 0) (def fixtures 0)
    (def reference (model.make-model (lambda () (set! starts (1+ starts)) 0)
      (lambda (_state _command) #t)
      (lambda (state _command) (set! advances (1+ advances)) (values state #f)) identity (lambda (_) #t) identity))
    (for (invalid (invalid-spines))
      (check (model.valid-trace? reference invalid) => #f)
      (check-exception (model.repair-trace reference invalid) Error?)
      (check-exception (model.shrink-trace reference invalid
        (lambda (_) (set! parameters (1+ parameters)) [])) Error?)
      (check-exception (model.check-trace reference invalid
        (lambda (_) (set! fixtures (1+ fixtures)) (error "invalid fixture entry"))) Error?)
      (check-exception (generator.list-deletions invalid 0) Error?)
      (check-exception (generator.data-list-shrinks invalid
        (lambda (_) (set! parameters (1+ parameters)) []) 0) Error?))
    (check-equal? (list starts advances parameters fixtures) '(0 0 0 0)))
  (test-case "invalid parameter spines cannot publish prefixes or start candidate repair"
    (for (invalid (invalid-spines))
      (def starts 0) (def calls 0) (def properties 0)
      (def reference (model.make-model (lambda () (set! starts (1+ starts)) 0)
        (lambda (_state _command) #t) (lambda (state _command) (values state #f)) identity exact-integer? identity))
      ;; The callback terminates; its returned shape is what must be rejected.
      (def (shrink _) (set! calls (1+ calls)) invalid)
      (check-exception (model.shrink-trace reference '(2 4) shrink) Error?)
      (check-equal? (list starts calls) '(0 1))
      (set! calls 0)
      (def producer (generator.make-generator (lambda (_random _size) '(2 4))
        (lambda (items) (generator.data-list-shrinks items shrink 0))))
      (def report (property.check-property producer (lambda (_) (set! properties (1+ properties)) #f)
        (property.make-specification list? length) cases: 1 shrink-budget: 8))
      (check-eq? (property.report-status report) 'error)
      (check-equal? (property.report-attempts report) 0)
      (check-equal? (property.report-counterexample report) '(2 4))
      (check-equal? (list starts calls properties) '(0 1 1))))
  (test-case "parameter source revision and exact callback causes stop the next coordinate"
    (for (throws? '(#f #t))
      (def live #t) (def calls 0) (def cause (cons 'parameter 'cause))
      (def producer (generator.make-generator (lambda (_random _size) '(2 4))
        (lambda (items) (generator.data-list-shrinks items (lambda (_)
          (set! calls (1+ calls)) (set! live #f) (if throws? (raise cause) '(0))) 0))
        current?: (lambda () live)))
      (def report (property.check-property producer (lambda (_) #f)
        (property.make-specification list? length) cases: 1 shrink-budget: 8))
      (check-eq? (property.report-status report) 'stale)
      (check-equal? (list calls (property.report-attempts report) (property.report-steps report)) '(1 0 0))
      (check-equal? (property.report-counterexample report) '(2 4))
      (if throws? (check-eq? (property.report-cause report) cause)
        ;; Run-local refusal exits without fabricating an application exception.
        (check-eq? (property.report-cause report) #f))))
  (test-case "finite policy order and dependency repair retain bounded lazy iterators"
    (def calls [])
    (check-equal? (generator.data-list-shrinks '(4 6) (lambda (value)
      (set! calls (cons value calls)) (if (= value 4) '(0 2) '(0 3))) 1)
      '((6) (4) (0 6) (2 6) (4 0) (4 3)))
    (check-equal? (reverse calls) '(4 6))
    (def reference (model.make-model (lambda () 0) (lambda (_state _command) #t)
      (lambda (state _command) (values state #f)) identity boolean? identity))
    (check-equal? (model.repair-trace reference '(#f omitted #t)) '(#f #t))
    ;; Infinite Iterators remain legal for the general lazy protocol: only the
    ;; finite value-policy boundary is constrained to proper lists.
    (def producer (generator.make-generator (lambda (_random _size) 2)
      (lambda (_) (in-coroutine (lambda (yield) (let loop () (yield 0) (loop)))))))
    (def report (property.check-property producer (lambda (_) #f)
      (property.make-specification exact-integer? abs) cases: 1 shrink-budget: 5))
    (check-eq? (property.report-status report) 'failed)
    (check-equal? (property.report-attempts report) 5)
    (check-equal? (property.report-steps report) 1)
    (check-equal? (property.report-counterexample report) 0)
    (check (property.report-minimal? report) => #f)))
