;;; One effective Function schema from finite inference through publication.
(export function-options-test)
(import :std/test :std/error :std/iter :std/list/list-builder
        (only-in :std/list/list delete-duplicates/hash)
        ../object ../mop ../type-relation ../prototype-types ../method-declaration
        (prefix-in ../examples/polymorphic-services service.))
;; Keep resource refusal separate from a false subtype or a target exception.
(def (refusal kind) (lambda (cause) (and (type-refusal? cause) (eq? (type-refusal-kind cause) kind))))
;; An empty option is literal metadata, not a supplied argument/default value.
(def plain '(Function (UInt) (Integer)))
;; All aliases must retain the first spelling's effective child and shape fields.
(def explicit '(Function (UInt) (Integer) rest: #f required-keywords: () keywords: () optional: ()))
;; A rich callback is also nested under invariant Map keys and ordered Unions.
(def rich '(Function (UInt) (Integer) optional: (Bool) keywords: ((mode: . UInt))
             required-keywords: (mode:) rest: Integer))
;; No declaration callback may run for rejected, ambiguous or exhausted search.
(def (forbidden _) (error "inference must not build this declaration"))
;; Regression covers the complete shared schema, not only an option accessor.
(def function-options-test
  (test-suite "Effective Function option normalization and inference"
    (test-case "omitted and explicit empty metadata form one candidate"
      (def schema (prototype-type (.o .parameters: '(F)) '(F) 'F []))
      (def report (infer-prototype-calls schema (list plain explicit) '((() (Integer) (UInt)))))
      (check-equal? (.get report status) 'unique)
      (check-equal? (.get report solutions) (list (list plain)))
      (check-equal? (canonical-type explicit (type-work 8192)) plain)
      (check-equal? (normalize-type explicit (type-work 8192)) plain)
      (check-equal? (.get (expression-type plain) sexp) (.get (expression-type explicit) sexp)))
    (test-case "every option permutation retains one descriptor and call constraint"
      (def entries '((optional: (Bool)) (keywords: ((mode: . UInt)))
                    (required-keywords: (mode:)) (rest: Integer)))
      ;; Gerbil's declarative Cartesian iteration and list builder enumerate all
      ;; 24 orders. No private permutation engine or alternate parser is needed.
      (def orders (with-list-builder (emit)
        (for* ((a entries) (b entries) (c entries) (d entries))
          (def row (list a b c d))
          (when (= (length (delete-duplicates/hash (map car row))) 4) (emit row)))))
      (check-equal? (length orders) 24)
      (def terms (map (lambda (order) (append '(Function (UInt) (Integer)) (apply append order))) orders))
      (def descriptor (expression-type rich))
      (for-each (lambda (term)
        (check-equal? (canonical-type term (type-work 8192)) rich)
        (check-equal? (normalize-type term (type-work 8192)) rich)
        (check-equal? (.get (expression-type term) sexp) (.get descriptor sexp))) terms)
      (def schema (prototype-type (.o .parameters: '(F)) '(F) 'F []))
      (def report (infer-prototype-calls schema terms '((() (Integer Bool mode: UInt Integer) (UInt)))))
      (check-equal? (.get report solutions) (list (list rich))))
    (test-case "canonicalization commutes with parameter substitution at every child"
      (def schema (prototype-type (.o .parameters: '(Value)) '(Value)
        '(Function ((Map (Function (Value) (Value) rest: #f) <- UInt)) (Value)
           rest: #f keywords: () optional: () required-keywords: ()) []))
      (def instance (instantiate-prototype (specialize-prototype-type schema '(UInt)) []))
      ;; Capture/substitution retains the source spelling for provenance. Only
      ;; semantic comparison and candidate identity use the canonical spelling.
      (check-equal? (.get instance expression)
        '(Function ((Map (Function (UInt) (UInt) rest: #f) <- UInt)) (UInt)
           rest: #f keywords: () optional: () required-keywords: ()))
      (check-equal? (normalize-type (.get instance expression) (type-work 8192))
        '(Function ((Map (Function (UInt) (UInt)) <- UInt)) (UInt)))
      (check-equal? (canonical-type (canonical-type (.get instance expression) (type-work 8192)) (type-work 8192))
        (canonical-type (.get instance expression) (type-work 8192))))
    (test-case "invariant parents compare effective aliases without branch widening"
      (check (subtype-expression? `(Map UInt <- ,plain) `(Map UInt <- ,explicit)) => #t)
      (check (subtype-expression? `(Union ,plain Bool) `(Union ,explicit Bool)) => #t)
      (check (subtype-expression? `(Union ,plain Bool) `(Union Bool ,explicit)) => #f)
      (check (subtype-expression? '(Union (Function (UInt) (UInt)) Bool)
        '(Union (Function (Integer) (UInt)) Bool)) => #f)
      (check (subtype-expression? `(Map UInt <- ,plain)
        '(Map UInt <- (Function (Integer) (Integer)))) => #f))
    (test-case "case and field order are not canonical aliases"
      (def schema (prototype-type (.o .parameters: '(F)) '(F) 'F []))
      (def a '(CaseFunction (Function (UInt) (Integer)) (Function (Bool) (Integer))))
      (def b '(CaseFunction (Function (Bool) (Integer)) (Function (UInt) (Integer))))
      (check-equal? (.get (infer-prototype schema (list a b) []) status) 'ambiguous)
      (check-equal? (.get (infer-prototype schema
        '((Record ((n UInt required) (flag Bool optional)) closed)
          (Record ((flag Bool optional) (n UInt required)) closed)) []) status) 'ambiguous)
      (check-equal? (.get (infer-declared-calls schema
        (list '(Function (UInt) (Integer)) '(Function (UInt) (UInt))) [] forbidden) status) 'ambiguous))
    (test-case "invalid metadata cannot be erased by normalization or empty search"
      (def schema (prototype-type (.o .parameters: '(F)) '(F) 'F []))
      (for-each (lambda (term)
        (check-exception (infer-declared-calls schema (list term) [] forbidden) (refusal 'malformed)))
        '((Function (UInt) (Integer) optional: () optional: ())
          (Function (UInt) (Integer) required-keywords: (missing:))
          (Function (UInt) (Integer) keywords: ((mode: . UInt) (mode: . Bool)))
          (Function (UInt) (Integer) unknown: ())))
      (check-exception (infer-declared-calls schema (list plain explicit) [] forbidden 20) (refusal 'exhausted))
      (check-equal? (.get (infer-prototype schema (list plain explicit) []) status) 'unique))
    (test-case "prefix inference declares once and preserves host defaults through FUN"
      (def events [])
      (def report (service.infer-signature-alias-service (lambda (event) (set! events (cons event events)))))
      (check-equal? (.get report status) 'unique)
      (check-equal? (length (.get report alternatives)) 1)
      (check-equal? events [])
      (def consumed 0) (def callback #f) (def context (.o approved: #t))
      (def action (service.catalog-service-action (.get report instance) 7 context
        (lambda (subject) (set! consumed (1+ consumed)) (set! callback (.get subject callback)))))
      (defvalues (evidence next failure) (action context))
      (check-equal? failure #f) (check (eq? next context) => #t)
      (check (eq? (.get evidence context) context) => #t)
      (check-equal? consumed 1)
      (check-equal? (callback 2) 9)
      (check-equal? (callback 2 3 scale: 2 4 5) 28)
      (check-exception (callback -1) TypeError?)
      (check (and (member 'around events) #t) => #t)
      (check-exception ((service.catalog-service-action (.get report instance) 101 context
        (lambda (_) (set! consumed 99))) context) TypeError?)
      (check-equal? consumed 1))))
