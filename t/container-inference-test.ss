;;; Finite container inference composes actual runtime validators and declarations.
(export container-inference-test)
(import :std/test :std/error ../object ../mop ../prototype-types ../type-relation ../method-declaration
        (only-in ../type Map) (prefix-in ../examples/polymorphic-services service.))
;; Typed refusal categories distinguish syntax, kind, quota and rejected bounds.
(def (refusal kind) (lambda (cause) (and (type-refusal? cause) (eq? (type-refusal-kind cause) kind))))
;; This exact observed signature fixes both residual variables through positive
;; count/output positions and contravariant callback inputs, after Key is bound.
(def routes-type '(Map (Sum active: (Function (UInt) (Integer)) count: UInt) <- UInt))
;; Both input and expected result constrain one shared assignment, not two solves.
(def observations
  (list (list [] (list routes-type)
    (list `(Pair ,routes-type (Union (Function (UInt) (Integer)) Bool))))))
;; Function-bearing route values exercise the existing tagged-object carrier.
(def (routes)
  (hash (1 (.o tag: 'active value: abs)) (2 (.o tag: 'count value: 3))))
;; The protocol tests rules, normalization, failure and complete executable flow.
(def container-inference-test
  (test-suite "Pair Map Sum Union inference and declaration closure"
    (test-case "Pair covariance is positional and observational"
      (check (subtype-expression? '(Pair UInt (Function (UInt) (Integer)))
                                  '(Pair Integer (Function (Integer) (UInt)))) => #t)
      (check (subtype-expression? '(Pair Integer UInt) '(Pair UInt Integer)) => #f))
    (test-case "Map values vary but normalized key syntax remains invariant"
      (check (subtype-expression? '(Map UInt <- UInt) '(Map UInt -> Integer)) => #t)
      (check (subtype-expression? '(Map UInt <- UInt) '(Map UInt <- Integer)) => #f)
      (check (subtype-expression? '(Map UInt <- (Function (UInt) (Integer)))
                                  '(Map Integer <- (Function (Integer) (UInt)))) => #f))
    (test-case "Sum retains exact ordered tag skeleton with covariant payloads"
      (check-equal? (.get (expression-type '(Sum active: UInt count: Integer)) sexp)
                    '(Sum active: UInt count: Integer))
      (check (subtype-expression? '(Sum active: UInt count: (Pair UInt Bool))
                                  '(Sum active: Integer count: (Pair Integer Bool))) => #t)
      (check (subtype-expression? '(Sum active: UInt count: UInt)
                                  '(Sum count: Integer active: Integer)) => #f)
      (check (subtype-expression? '(Sum active: UInt) '(Sum count: UInt)) => #f)
      (check (subtype-expression? '(Sum) '(Sum)) => #t))
    (test-case "Union preserves first-match order duplicates and normalization"
      (check (subtype-expression? '(Union UInt Integer) '(Union Integer UInt)) => #f)
      (check (subtype-expression? '(Union UInt) '(Union Integer)) => #f)
      (check (subtype-expression? '(Union UInt UInt) '(Union UInt)) => #f)
      (check (subtype-expression? '(Union (Map UInt <- UInt)) '(Union (Map UInt -> UInt))) => #t)
      (check-exception (validate (expression-type '(Union)) 1) TypeError?))
    (test-case "literal arrows and Sum labels survive partial specialization"
      (def schema (prototype-type (.o .parameters: '(Self Super)) '(Self Super)
        '(Pair (Map Self <- Super) (Sum Self: Super Super: Self)) []))
      (def partial (specialize-prototype-type schema '(UInt)))
      (check-equal? (.get partial expression) '(Pair (Map UInt <- Super) (Sum Self: Super Super: UInt)))
      (check-equal? (.get (instantiate-prototype partial '(Integer)) expression)
                    '(Pair (Map UInt <- Integer) (Sum Self: Integer Super: UInt))))
    (test-case "constructor names are reserved and malformed kinds refuse"
      (for-each (lambda (term) (check-exception (expression-type term) (refusal 'malformed)))
        '((Pair UInt) (Map UInt UInt) (Map UInt => Integer) (Sum active: UInt active: Integer)
          (Sum active:) (Sum active UInt)))
      (for-each (lambda (name)
        (check-exception (prototype-type (.o .parameters: (list name)) (list name) name [])
          (refusal 'malformed))) '(Pair Map Sum Union))
      (check-exception (expression-type '(Object () (Row (Map UInt <- UInt)))) (refusal 'bounds)))
    (test-case "recursive payloads close while invariant recursive keys refuse"
      (def descriptor (expression-type '(Mu X 1 (Map (Sum end: UInt next: X) <- UInt))))
      (check (element? descriptor (hash (1 (.o tag: 'end value: 2)))) => #t)
      (check-exception (validate descriptor (hash (1 (.o tag: 'next value: 2)))) TypeError?)
      (check-exception (expression-type '(Mu X 2 (Map UInt <- X))) (refusal 'unsupported))
      (check-exception (expression-type '(Mu X 2 (Map X -> UInt))) (refusal 'unsupported)))
    (test-case "candidate aliases normalize before uniqueness classification"
      (check-equal? (canonical-type '(Mu X 1 (Map UInt -> X)) (type-work 8192))
                    '(Mu X 1 (Map X <- UInt)))
      (def schema (prototype-type (.o .parameters: '(Self)) '(Self) 'Self []))
      (def report (infer-prototype schema '((Map UInt <- Integer) (Map Integer -> UInt)) []))
      (check-equal? (.get report status) 'unique)
      (check-equal? (.get report solutions) '(((Map UInt <- Integer)))))
    (test-case "nested Union callback keeps committed first Function wrapper"
      (def checked (validate (expression-type '(Pair (Union (Function (Bool) (Bool))
                                                             (Function (Integer) (Integer))) UInt))
                            (cons values 1)))
      (check-equal? ((car checked) #t) #t)
      (check-exception ((car checked) 1) TypeError?))
    (test-case "Map Function keys and values retain independent wrappers"
      (def raw values) (def source (make-hash-table-eq))
      (hash-put! source raw raw)
      (def checked (validate (expression-type '(Map (Function (UInt) (UInt)) <- (Function (UInt) (UInt)))) source))
      (def key (car (hash-keys checked)))
      (check (eq? key raw) => #f)
      (check-exception (key -1) TypeError?)
      (check-exception ((hash-ref checked key) -1) TypeError?)
      (check (eq? (hash-ref source raw) raw) => #t))
    (test-case "shared inferred catalog executes full qualified declaration"
      (def audit [])
      (def report (service.infer-routing-service '(UInt) '(UInt Integer) observations
                    (lambda (event) (set! audit (cons event audit)))))
      (check-equal? (.get report status) 'unique)
      (check-equal? (.get report solutions) '((UInt Integer)))
      (check-equal? audit [])
      (defvalues (answer owner) (service.route-service (.get report instance prototype) (routes)))
      (check-equal? audit '(routes))
      (check-equal? ((.get (hash-ref (car answer) 1) value) -4) 4)
      (check-exception ((.get (hash-ref (car answer) 1) value) #f) TypeError?)
      (check-exception ((cdr answer) #f) TypeError?)
      (check (begin (declared-snapshot owner) #t) => #t))
    (test-case "FUN refinement evidence binding and IO consume only wrapped roots"
      (def report (service.infer-routing-service '(UInt) '(UInt Integer) observations))
      (def instance (.get report instance)) (def context (.o approved: #t)) (def consumed 0)
      (def action (service.routing-service-action instance (routes) context
                    (lambda (answer)
                      (set! consumed (+ consumed 1))
                      (check-exception ((cdr answer) #f) TypeError?))))
      (defvalues (evidence next refused) (action context))
      (check-equal? refused #f)
      (check-equal? consumed 1)
      (check (eq? (.get evidence context) context) => #t)
      (check (begin (declared-snapshot (.get next owner)) #t) => #t)
      (def denied (service.routing-service-action instance (hash) context (lambda (_) (set! consumed 99))))
      (check-exception (denied context) TypeError?)
      (check-equal? consumed 1))
    (test-case "conflict and exhaustion never run declaration builder and retry succeeds"
      (def builds 0)
      ;; A failed inference cannot publish even a partially compiled generic.
      (def (builder instance) (set! builds (+ builds 1)) (service.routing-declarations instance void))
      (def schema (specialize-prototype-type service.RoutingServiceType '(UInt)))
      (def contradictory
        (append observations (list (list [] (list '(Map UInt <- Integer)) #f))))
      (check-equal? (.get (infer-declared-calls schema '(UInt Integer) contradictory builder) status) 'no-solution)
      (check-equal? builds 0)
      (check-exception (infer-declared-calls schema '(UInt Integer) observations builder 16) (refusal 'exhausted))
      (check-equal? builds 0)
      (check-equal? (.get (infer-declared-calls schema '(UInt Integer) observations builder) status) 'unique)
      (check-equal? builds 1))))
