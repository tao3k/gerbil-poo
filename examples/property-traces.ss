;;; Bounded model drawing uses the generic protocol and standard Gerbil contracts.
(export trace-draw-test-cases!)
(import :std/test :std/error
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
