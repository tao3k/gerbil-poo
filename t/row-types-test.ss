;;; Structural rows, guarded approximants and complete inferred contract workflows.
(export row-types-test)
(import :std/test :std/error ../object ../mop ../types/relation ../prototype-types
        (prefix-in ../examples/row-services service.))
;; Match controlled failure categories without swallowing unrelated exceptions.
(def (refusal-kind? expected)
  (lambda (cause) (and (type-refusal? cause) (eq? (type-refusal-kind cause) expected))))
;; Cover the protocol, not only successful sample values or isolated lookups.
(def row-types-test
  (test-suite "recursive types and structural row polymorphism"
    (test-case "width depth and Function variance respect open versus closed rows"
      (check (subtype-expression? '(Object ((x UInt) (f (Function (UInt) (Integer)))) closed)
                                  '(Object ((f (Function (Integer) (UInt)))) open)) => #t)
      (check (subtype-expression? '(Object ((x UInt)) open) '(Object ((x Integer)) closed)) => #f)
      (check (subtype-expression? '(Object ((x UInt) (y Bool)) closed) '(Object ((x Integer)) closed)) => #f)
      (check (subtype-expression? '(Object ((y Bool) (x UInt)) closed)
                                  '(Object ((x Integer) (y Bool)) closed)) => #t)
      (check (subtype-expression? '(Object ((x UInt)) open) '(Object ((missing Any)) open)) => #f))
    (test-case "field labels remain literal even when named like a type parameter"
      (let* ((prototype (.o .parameters: '(Self)))
             (schema (prototype-type prototype '(Self) '(Object ((Self Self)) closed) []))
             (instance (instantiate-prototype schema '(UInt))))
        (check-equal? (.get instance expression) '(Object ((Self UInt)) closed))
        (check (element? (.get instance descriptor) (.o Self: 1)) => #t)))
    (test-case "finite row inference rejects wrong kinds and overlapping assignments"
      (let* ((actual `(Object ((handler (Function (UInt) (Integer)))
                              (roots (List ,service.Tree)) (audit UInt)) closed))
             (report (infer-prototype service.ServiceType
                       '((Object ((audit Integer)) closed) (Object ((region Bool)) closed)
                         (Object ((handler Any)) closed) UInt)
                       (list (list actual service.service-expression)) 100000)))
        (check-equal? (.get report status) 'unique)
        (check-equal? (.get report solutions) '(((Object ((audit Integer)) closed))))
        (check-exception (instantiate-prototype service.ServiceType '(UInt)) (refusal-kind? 'bounds))
        (check-exception (instantiate-prototype service.ServiceType '((Object ((handler Any)) closed)))
                         (refusal-kind? 'bounds))))
    (test-case "ambiguous and empty row searches never expose partial instances"
      (let ((ambiguous (infer-prototype service.ServiceType
                         '((Object ((audit Integer)) closed) (Object ((region Bool)) open)) [] 100000))
            (none (infer-prototype service.ServiceType '(UInt) [])))
        (check-equal? (.get ambiguous status) 'ambiguous)
        (check-equal? (.get ambiguous instance) #f)
        (check-equal? (.get none status) 'no-solution)
        (check-equal? (.get none instance) #f)))
    (test-case "recursive shared nodes wrap Function fields before refinement and publication"
      (let* ((instance (instantiate-prototype service.ServiceType '((Object ((audit Integer)) closed)) 100000))
             (raw (service.shared-service)) (calls 0)
             (checked ((service.admit-service instance 10 (lambda (value) (set! calls (+ calls 1)) value)) raw))
             (root (car (.get checked roots)))
             (context (.o revision: 1)) (old (.o revision: 0))
             (evidence (.o bind-these: #f subject: raw descriptor: (.get instance descriptor) context: context)))
        (check-equal? ((.get (car (.get root children)) adjust) -7) 7)
        (check-exception ((.get (car (.get root children)) adjust) #f) TypeError?)
        (check-equal? calls 1)
        (let-values (((value next refusal) (service.publish-service instance raw context evidence old)))
          (check-equal? refusal #f) (check (eq? next raw) => #t) (check (eq? value evidence) => #t))
        (let-values (((value next refusal)
                      (service.publish-service instance raw context (.cc evidence context: (.cc context)) old)))
          (check-equal? value #f) (check (eq? next old) => #t) (check (not (not refusal)) => #t))
        (check-exception ((service.admit-service instance 2 identity) raw) TypeError?)))
    (test-case "recursive cutoff rejects deeper and cyclic values without claiming exhaustion"
      (let* ((one (expression-type '(Mu X 1 (Object ((children (List X))) closed))))
             (leaf (.o children: [])) (deep (.o children: (list leaf)))
             (cycle (.o self: receiver children: (list receiver))))
        (check (element? one leaf) => #t)
        (check-exception (validate one deep) TypeError?)
        (check-exception (validate one cycle) TypeError?)
        (check-exception (validate (expression-type '(Mu X 0 (List X))) []) TypeError?)
        (check (subtype-expression? '(Mu X 1 (List X)) '(Mu X 2 (List X))) => #t)))
    (test-case "invalid nested method results still refuse at the original call boundary"
      (let* ((descriptor (expression-type service.Tree 100000))
             (checked (validate descriptor (.o value: 1 adjust: (lambda (_) -1) children: []))))
        (check-exception ((.get checked adjust) 1) TypeError?)))
    (test-case "guard kind depth syntax and budgets fail distinctly and can retry"
      (check-exception (expression-type '(Mu X 2 X)) (refusal-kind? 'unsupported))
      (check-exception (expression-type '(Mu X 2 (Object ((f (Function () (X)))) closed))) (refusal-kind? 'unsupported))
      (check-exception (expression-type '(Mu X 2 (Function () (X)))) (refusal-kind? 'unsupported))
      (check-exception (expression-type '(Mu X 2 (List (Mu Y 1 (List Y))))) (refusal-kind? 'unsupported))
      (check-exception (expression-type '(Mu X 17 (List X))) (refusal-kind? 'malformed))
      (check-exception (expression-type '(Object ((x UInt) (x Bool)) open)) (refusal-kind? 'malformed))
      (check-exception (expression-type service.Tree 20) (refusal-kind? 'exhausted))
      (check (element? (expression-type service.Tree 100000) (.o value: 1 adjust: abs children: [])) => #t))
    (test-case "substitution cannot smuggle unsupported nested recursive declarations"
      (let* ((prototype (.o .parameters: '(Element)))
             (schema (prototype-type prototype '(Element) '(Mu Outer 2 (List Element)) [])))
        (check-exception (instantiate-prototype schema '((Mu Inner 1 (List Inner))))
                         (refusal-kind? 'unsupported))
        (check-exception (infer-prototype schema '(UInt (Mu Inner 1 (List Inner))) [])
                         (refusal-kind? 'unsupported)))
      (check-exception (expression-type
                         '(Mu X 1 (Object () (Row (Mu Y 1 (Object ((children (List Y))) closed))))))
                       (refusal-kind? 'unsupported)))
    (test-case "open row validation preserves undeclared fields while wrapping declared fields"
      (let* ((descriptor (expression-type '(Object ((run (Function (UInt) (Integer)))) open)))
             (source (.o run: abs extra: #f)) (checked (validate descriptor source)))
        (check-equal? (.get checked extra) #f)
        (check-equal? ((.get checked run) -3) 3)
        (check-exception ((.get checked run) #f) TypeError?)))))
