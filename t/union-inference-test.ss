;;; Joint flat Union coverage through the original finite declaration protocol.
(export union-inference-test)
(import :std/test :std/error ../object ../mop ../type ../type-relation ../prototype-types ../method-declaration
        (prefix-in ../examples/polymorphic-services service.))
;; Only this bounded source gains public joint coverage; its descriptor survives.
(def interval '(IntegerRange min: 0 max: 10))
;; Deliberately unsorted nested alternatives jointly cover the source exactly.
(def alternatives '(Union (IntegerRange min: 7 max: 10)
                           (Union (Enum 5 6) (IntegerRange min: 0 max: 4))))
;; Ordinary and callback observations share the same fully bound parameters.
(def observations (list (list [] (list interval) (list interval `(Function (,interval) (,interval))))))
;; Typed refusals remain separate from a complete negative inclusion judgment.
(def (refusal kind) (lambda (cause) (and (type-refusal? cause) (eq? (type-refusal-kind cause) kind))))
;; No declaration builder is allowed to observe an incomplete/nonunique solution.
(def (forbidden _) (error "Union declaration built before complete inference"))
;; Coverage, ordered validation and whole publication are checked independently.
(def union-inference-test
  (test-suite "Joint range and literal coverage in ordered flat Union"
    (test-case "several branches cover a range without one covering it alone"
      (check (subtype-expression? interval alternatives) => #t)
      (check (subtype-expression? interval '(Union (IntegerRange min: 0 max: 4) (Enum 5 5 7) (IntegerRange min: 8 max: 10))) => #f)
      (check (subtype-expression? interval '(Union (IntegerRange min: 5 max: 1) (Enum 5) (IntegerRange min: 0 max: 4) (IntegerRange min: 6 max: 10))) => #t)
      (check (subtype-expression? '(IntegerRange min: 2 max: 1) '(Union)) => #t)
      (check (subtype-expression? interval '(Union)) => #f)
      (check (subtype-expression? '(IntegerRange min: 0) '(Union Integer)) => #f)
      (def huge (expt 2 2048))
      (check (subtype-expression? (list 'IntegerRange min: (- huge) max: huge)
        '(Union (IntegerRange min: 1) (Enum 0) (IntegerRange max: -1)) 2000) => #t))
    (test-case "finite literal sources retain exact mixed scalar membership"
      (check (subtype-expression? '(Enum 0 1 2 #f ready other)
        '(Union (Enum #f ready) (IntegerRange min: 0 max: 1) (Exactly 2) Symbol)) => #t)
      (check (subtype-expression? '(Enum 0 1 2 #f absent)
        '(Union (Enum #f ready) (IntegerRange min: 0 max: 2))) => #f)
      (check (subtype-expression? '(Exactly 5) alternatives) => #t)
      (check (subtype-expression? '(Enum #!key #!rest scale:) '(Union Keyword (Enum #!key #!rest))) => #f)
      (check-exception (subtype-expression? '(Enum) '(Union (Enum 1.0))) (refusal 'unsupported)))
    (test-case "independent descriptor witnesses detect holes overlap and empty branches"
      (for-each (lambda (source)
        (for-each (lambda (target)
          (check-equal? (subtype-expression? source target)
            (andmap (lambda (value)
              (or (not (element? (expression-type source) value))
                  (element? (expression-type target) value))) '(-3 -2 -1 0 1 2 3))))
          '((Union) (Union (IntegerRange min: -2 max: 0) (Enum 1 2))
            (Union (Enum 2 -2) (IntegerRange min: -1 max: 1))
            (Union (Enum -2 0 2) (Enum -1)) (Union (Enum 0 0) (IntegerRange min: 2 max: 1))
            (Union Bool (Union (Enum -2 -1) (IntegerRange min: 0 max: 2))))))
        '((IntegerRange min: -2 max: 2) (IntegerRange min: -1 max: 1)
          (IntegerRange min: 0 max: 0) (IntegerRange min: 1 max: -1))))
    (test-case "descriptor order and committed failure remain unchanged"
      (check-equal? (normalize-type alternatives (type-work 2000)) alternatives)
      (def descriptor (expression-type alternatives))
      (check-equal? (.get descriptor sexp) alternatives)
      (for-each (lambda (value) (check (eq? (validate descriptor value) value) => #t)) '(0 4 5 6 7 10))
      (check-exception (validate descriptor 11) TypeError?)
      (check (subtype-expression? alternatives alternatives) => #t)
      (check (subtype-expression? alternatives '(Union (Union (Enum 5 6) (IntegerRange min: 0 max: 4)) (IntegerRange min: 7 max: 10))) => #f)
      (check (subtype-expression? interval `(Union ,interval (Function (UInt) (UInt)))) => #f)
      (check (subtype-expression? '(Enum) `(Union ,interval (Function (UInt) (UInt)))) => #f)
      (def cause (list 'selected-error)) (def fallback-calls 0)
      (def selected (.cc Type. .element?: exact-integer? .validate: (lambda (_) (raise cause))))
      (def fallback (.cc (expression-type interval) .validate: (lambda (value) (set! fallback-calls (1+ fallback-calls)) value)))
      (check-exception (validate (Union selected fallback) 5) (lambda (caught) (eq? caught cause)))
      (check-equal? fallback-calls 0))
    (test-case "container values and callback variance share coverage but keys do not"
      (check (subtype-expression? `(Pair ,interval (Function (,interval) (,alternatives)))
        `(Pair ,alternatives (Function (,alternatives) (,interval)))) => #t)
      (check (subtype-expression? `(Map ,interval <- UInt) `(Map ,alternatives <- UInt)) => #t)
      (check (subtype-expression? `(Map UInt <- ,interval) `(Map UInt <- ,alternatives)) => #f)
      (def callback (validate (expression-type `(Function (,alternatives) (,interval))) identity))
      (check-equal? (callback 6) 6) (check-exception (callback 11) TypeError?)
      (check-exception ((validate (expression-type `(Function (,alternatives) (,interval))) (lambda (_) 11)) 6) TypeError?))
    (test-case "prefix inference publishes through original qualifiers and evidence"
      (def report (service.infer-range-service (list interval) (list 'Integer 'UInt interval) observations
        schema: service.UnionServiceType))
      (check-equal? (.get report status) 'unique)
      (check-equal? (.get report solutions) (list (list interval)))
      (def instance (.get report instance)) (def context (.o approved: #t)) (def consumed 0)
      (defvalues (answer callback owner) (service.invoke-signature-service (.get instance prototype) 4 1 scale: 2))
      (check-equal? answer 10) (check-equal? (callback 10) 10)
      (check-exception (callback 11) TypeError?) (check (begin (declared-snapshot owner) #t) => #t)
      (defvalues (evidence next failure)
        ((service.catalog-service-action instance 4 context (lambda (_) (set! consumed (1+ consumed))) 5) context))
      (check-equal? failure #f) (check-equal? consumed 1)
      (check (eq? next context) => #t) (check (eq? (.get evidence context) context) => #t)
      (check-exception ((service.catalog-service-action instance 8 context (lambda (_) (set! consumed 99)) 5) context) TypeError?)
      (check-equal? consumed 1))
    (test-case "ambiguity exhaustion and failed bounds cannot reach builders"
      (def partial (specialize-prototype-type service.UnionServiceType (list interval)))
      (check-equal? (.get (infer-declared-calls partial '(Integer UInt) observations forbidden) status) 'no-solution)
      (check-equal? (.get (infer-declared-calls partial (list interval alternatives) observations forbidden) status) 'ambiguous)
      (check-exception (infer-declared-calls partial (list interval) observations forbidden 20) (refusal 'exhausted))
      (check-exception (subtype-expression? interval (cons 'Union (make-list 100 '(Enum 0))) 50) (refusal 'exhausted))
      (check-equal? (.get (service.infer-range-service (list interval) (list interval) observations
        schema: service.UnionServiceType) status) 'unique))))
