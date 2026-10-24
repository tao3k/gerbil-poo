;;; Real host calls exercise descriptor admission, defaults and recursive wrappers.
(export function-signature-test)
(import :std/test :std/error ../object ../mop ../type ../number)

;; Check protocol errors explicitly so arithmetic/host failures cannot pass controls.
(def (type-error? cause) (TypeError? cause))

;; Cover ordered structural dispatch rather than testing procedure? recognition only.
(def function-signature-test
  (test-suite "Function optional, keyword, rest and ordered signatures"
    (test-case "legacy serialization and fixed invocation stay compatible"
      (check-equal? (car (.get (Function [Integer] [Integer]) sexp)) 'Function)
      (check-equal? (map cadr (cdr (.get (Function [Integer] [Integer]) sexp))) '(Integer Integer))
      (check-equal? ((validate (Fun Integer <- Integer) 1+) 2) 3))
    (test-case "omitted defaults run once in target and supplied options are checked"
      (let* ((defaults 0) (calls 0)
             (checked (validate (Function [Integer] [Integer] optional: [Integer])
               (lambda (x (y (begin (set! defaults (+ defaults 1)) 4)))
                 (set! calls (+ calls 1)) (+ x y)))))
        (check-equal? (checked 3) 7)
        (check-equal? defaults 1)
        (check-equal? (checked 3 5) 8)
        (check-exception (checked 3 #f) type-error?)
        (check-exception (checked) type-error?)
        (check-exception (checked 1 2 3) type-error?)
        (check-equal? calls 2)))
    (test-case "required and optional keywords preserve defaults and escapes"
      (let* ((calls 0)
             (signature (Function [Integer] [Any] keywords: (list (cons scale: Integer) (cons offset: Integer))
                                                   required-keywords: [scale:]))
             (checked (validate signature (lambda (x scale: scale offset: (offset 2))
               (set! calls (+ calls 1)) (if (keyword? x) (+ scale offset) (* x scale))))))
        (check-equal? (checked 3 scale: 4) 12)
        (check-equal? (checked offset: 3 #!key payload: scale: 7) 10)
        (check-equal? (checked scale: 8 #!rest payload:) 10)
        (check-exception (checked 1) type-error?)
        (check-exception (checked 1 scale: 2 unknown: 4) type-error?)
        (check-exception (checked 1 scale: 2 scale: 3) type-error?)
        (check-exception (apply checked (list 1 scale:)) type-error?)
        (check-exception (checked 1 scale: #f) type-error?)
        (check-equal? calls 3)))
    (test-case "rest values and multiple results are checked in order"
      (let (checked (validate (Function [Integer Integer] [Integer] optional: [Integer] rest: Integer)
                             (lambda (x (y 0) . rest) (values (+ x y) (apply + rest)))))
        (check-equal? (call/values (lambda () (checked 1 2 3 4)) list) '(3 7))
        (check-exception (checked 1 2 #f) type-error?)))
    (test-case "case-lambda dispatch selects first shape and refuses type fallback"
      (let* ((calls 0) (signature (CaseFunction (Function [Integer] [Integer]) (Function [Integer] [Integer Integer])))
             (checked (validate signature (case-lambda ((x) (set! calls (+ calls 1)) x) ((x y) (+ x y))))))
        (check-equal? (checked 2) 2)
        (check-equal? (checked 2 3) 5)
        (check-exception (checked #f) type-error?)
        (check-exception (checked) type-error?)
        (check-equal? calls 1))
      (let (checked (validate (CaseFunction (Function [Integer] [Integer]) (Function [Bool] [Bool])) identity))
        (check-exception (checked #t) type-error?)))
    (test-case "nested optional and keyword functions recursively acquire wrappers"
      (let* ((callback (Function [Integer] [Integer]))
             (signature (Function [(Tuple callback)] [] optional: [(List callback)]
                                  keywords: (list (cons fallback: callback))))
             (checked (validate signature (lambda ((callbacks []) fallback: (fallback identity))
               (vector (if (null? callbacks) fallback (car callbacks)))))))
        (check-equal? ((vector-ref (checked fallback: 1+) 0) 4) 5)
        (check-exception ((vector-ref (checked [(lambda (_) #f)]) 0) 4) type-error?)
        (check-exception ((vector-ref (checked) 0) #f) type-error?)))
    (test-case "body exceptions keep identity and no later clause executes"
      (let* ((cause (Error "body"))
             (checked (validate (CaseFunction (Function [Integer] [] optional: [Integer])
                                              (Function [Integer] [Integer]))
                                (lambda args (raise cause)))))
        (check-exception (checked 1) (lambda (observed) (eq? observed cause)))))
    (test-case "wrong result arity and default errors refuse without retry"
      (let* ((cause (Error "default"))
             (checked (validate (Function [Integer] [] optional: [Integer])
               (lambda ((value (raise cause))) value))))
        (check-exception (checked) (lambda (observed) (eq? observed cause))))
      (check-exception ((validate (Function [Integer Integer] []) (lambda () 1))) type-error?)
      (check-exception ((validate (Function [Integer] []) (lambda () (values 1 2)))) type-error?))
    (test-case "malformed descriptors refuse before wrappers exist"
      (check-exception (Function [] [] keywords: (list (cons x: Integer) (cons x: Bool))) Error?)
      (check-exception (Function [] [] required-keywords: [missing:]) Error?)
      (check-exception (Function [] [] optional: [17]) TypeError?)
      (check-exception (CaseFunction) Error?)
      (check-exception (CaseFunction Integer) Error?))))
