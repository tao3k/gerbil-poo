;;; Candidate-dependent catalogs reuse the existing call and declaration protocol.
(export candidate-inference-test)
(import :std/test :std/error ../object ../mop ../prototype-types ../type-relation
        ../method-declaration (prefix-in ../examples/polymorphic-services service.))
;; Preserve typed failures while keeping ordinary builder errors observable.
(def (refusal kind) (lambda (cause) (and (type-refusal? cause) (eq? (type-refusal-kind cause) kind))))
;; A whole candidate may determine the signature kind and every named field.
(def schema (prototype-type (.o .parameters: '(Catalog)) '(Catalog) 'Catalog []))
;; No builder is permitted for incomplete, ambiguous or inconsistent inference.
(def (forbidden _) (error "builder ran before unique complete inference"))
;; Shared observations constrain the same candidate layout, never separate solves.
(def calls '(((api run) (Integer) (UInt)) ((api audit) (UInt) (Bool))))
;; Exact field catalogs contain two required signatures and one non-method field.
(def good '(Object ((api (Object ((run (Function (UInt) (Integer)))
                                 (audit (Function (Bool) (UInt)))) closed))
                    (limit UInt)) closed))
;; Missing sibling support is a negative candidate, not a synthesized method.
(def missing '(Object ((api (Object ((run (Function (UInt) (Integer)))) closed))) closed))
;; Complete end-to-end coverage includes kind, shape, rows, quotas and provenance.
(def candidate-inference-test
  (test-suite "Candidate-dependent signatures and field layouts"
    (test-case "whole signature kinds are selected after candidate substitution"
      (def report (infer-prototype-calls schema '(Integer (Function (UInt) (Integer)))
        '((() (Integer) (UInt)))))
      (check-equal? (.get report status) 'unique)
      (check-equal? (.get report solutions) '(((Function (UInt) (Integer)))))
      (check-equal? (.get report queries) '((Integer Integer) (UInt UInt))))
    (test-case "every sibling uses one candidate layout"
      (def report (infer-prototype-calls schema (list missing good) calls))
      (check-equal? (.get report solutions) (list (list good)))
      (check-equal? (.get (car (.get report alternatives)) expression) good)
      (check-equal? (.get report queries) '((Integer Integer) (UInt UInt) (UInt UInt) (Bool Bool))))
    (test-case "alternative diagnostics retain their own inequalities"
      (def report (infer-declared-calls schema
        '((Function (UInt) (Integer)) (Function (Integer) (Any)))
        '((() (UInt) (Integer))) forbidden))
      (check-equal? (.get report status) 'ambiguous)
      (check-equal? (map (lambda (entry) (.get entry queries)) (.get report alternatives))
        '(((UInt Integer) (UInt Integer)) ((UInt Any) (Integer Integer)))))
    (test-case "cross-candidate sibling matches cannot manufacture a solution"
      (def wrong '(Object ((api (Object ((run (Function (Bool) (Integer)))
                                        (audit (Function (Bool) (UInt)))) closed))) closed))
      (check-equal? (.get (infer-declared-calls schema (list missing wrong) calls forbidden) status) 'no-solution))
    (test-case "row substitutions decide paths and reject non-object or overlapping rows"
      (def row-schema (prototype-type (.o .parameters: '(Tail)) '(Tail)
        '(Object ((version UInt)) (Row Tail)) []))
      (def row '(Object ((run (Function (UInt) (Integer)))) closed))
      (def overlap '(Object ((version UInt) (run (Function (UInt) (Integer)))) closed))
      (def report (infer-prototype-calls row-schema (list 'UInt overlap row) '(((run) (Integer) (UInt)))))
      (check-equal? (.get report solutions) (list (list row)))
      (check-equal? (.get (car (.get report alternatives)) expression)
        '(Object ((version UInt) (run (Function (UInt) (Integer)))) closed)))
    (test-case "prefix specialization preserves literal names and deferred field types"
      (def partial (specialize-prototype-type
        (prototype-type (.o .parameters: '(Value Signature)) '(Value Signature)
          '(Object ((Value Value) (run Signature)) closed) []) '(UInt)))
      (check-equal? (.get (infer-prototype-calls partial '((Function (UInt) (Integer)) Bool)
        '(((run) (Integer) (UInt)))) solutions) '(((Function (UInt) (Integer))))))
    (test-case "rich keyword rest and multiple values use the existing selector"
      (def signature '(Function (UInt Bool) (Integer) optional: (Bool)
        keywords: ((mode: . UInt)) required-keywords: (mode:) rest: Integer))
      (check-equal? (.get (infer-prototype-calls schema (list '(Function (UInt) (Integer)) signature)
        '((() (Integer Bool Integer mode: UInt) (UInt Bool)))) status) 'unique)
      (check-equal? (.get (infer-prototype-calls schema (list signature)
        '((() (Integer Bool mode: UInt) ()))) status) 'no-solution))
    (test-case "ordered case selection never retries a later type-compatible case"
      (def shadowed '(CaseFunction (Function (Bool) (Integer)) (Function (UInt) (Integer))))
      (check-equal? (.get (infer-prototype-calls schema (list shadowed) '((() (Integer) (UInt)))) status) 'no-solution))
    (test-case "empty candidates still validate malformed observations"
      (check-exception (infer-declared-calls schema [] '((() (mode:) #f)) forbidden) (refusal 'malformed))
      (check-exception (infer-declared-calls schema [] '((() (Unknown) #f)) forbidden) (refusal 'unsupported))
      (check-exception (infer-declared-calls schema [] '((() () (Unknown))) forbidden) (refusal 'unsupported)))
    (test-case "a matched prefix cannot bypass exhaustion or recursive admission"
      (check-exception (infer-declared-calls schema (list good missing) calls forbidden 30) (refusal 'exhausted))
      (def nested (prototype-type (.o .parameters: '(T)) '(T) '(Mu X 1 (List T)) []))
      (check-exception (infer-prototype-calls nested '((Mu Y 1 (List Y))) []) (refusal 'unsupported)))
    (test-case "known literal missing paths keep their unsupported boundary"
      (def fixed (prototype-type (.o .parameters: '(T)) '(T) '(Object ((data T)) closed) []))
      (check-exception (infer-prototype-calls fixed '(UInt) '(((missing) () #f))) (refusal 'unsupported)))
    (test-case "whole candidate declaration invokes wrapped callbacks through FUN and evidence"
      (def report (service.infer-catalog-service
        '((Function (Bool) (Integer)) (Function (UInt (Function (UInt) (Integer))) (Integer)))
        '((() (Integer) (UInt (Function (UInt) (Integer)))))
        (lambda (value) (values (abs value) abs))))
      (def seen #f)
      (def action (service.catalog-service-action (.get report instance) -7 (.o approved: #t)
        (lambda (subject) (set! seen (.get subject callback)))))
      (defvalues (_ _context failure) (action #f))
      (check-equal? failure #f)
      (check-equal? (seen -9) 9)
      (check-exception (seen #f) TypeError?))
    (test-case "candidate field layout installs and invokes both qualified generics"
      (def catalog '(Object
        ((.report (Function (UInt (Function (UInt) (Integer))) (Integer)
          optional: (Integer) keywords: ((scale: . UInt)) rest: Integer))
         (.recover (Function (Integer) (UInt)))) closed))
      (def calls '(((.report) (Integer Integer scale: UInt) (UInt (Function (UInt) (Integer))))
                    ((.recover) (UInt) (Integer))))
      (def events [])
      (def report (service.infer-shared-catalog-service (list missing catalog) calls
        (lambda (_value _extra scale: (_scale 1) . _rest) (values 7 abs))
        (lambda (value) (+ value 1)) (lambda (event) (set! events (cons event events)))))
      (check-equal? events [])
      (def action (service.shared-service-action (.get report instance) -4
        (lambda (answer recovered callback)
          (check-equal? answer 7) (check-equal? recovered 8)
          (check-equal? (callback -9) 9)
          (check-exception (callback #f) TypeError?))))
      (defvalues (_answer _recovered _report-owner _recover-owner) (action (.o approved: #t)))
      (check-equal? (reverse events) '(report recover))
      ;; An otherwise unique layout cannot hide a required unobserved method.
      (def extended (list 'Object (append (cadr catalog) '((backup (Function (UInt) (UInt))))) 'closed))
      (check-exception (service.infer-shared-catalog-service (list extended) calls
        (lambda _ (values 7 abs)) values) (refusal 'bounds)))
    (test-case "unique builder failure stays an error and a fresh request may retry"
      (def failed 0)
      (check-exception (infer-declared-calls schema '((Function (UInt) (Integer)))
        '((() (Integer) (UInt))) (lambda (_) (set! failed (1+ failed)) (error "approval failed"))) Error?)
      (check-equal? failed 1)
      (check-equal? (.get (service.infer-catalog-service '((Function (UInt) (Integer)))
        '((() (Integer) (UInt))) abs) status) 'unique))))
