;;; Witnessed emptiness in finite inference, declarations and guarded publication.
(export empty-inference-test)
(import :std/test :std/error ../object ../mop ../type ../type-relation ../prototype-types
        (prefix-in ../examples/polymorphic-services service.))
;; Refusal classification must not turn exhaustion/callback errors into false.
(def (refusal kind)
  (lambda (cause) (and (type-refusal? cause) (eq? (type-refusal-kind cause) kind))))
;; Mandatory nested alternatives are all empty; the callback remains a real Type.
(def dead '(Pair (Sum blocked: (Tuple (Enum)) pending: (Union (Enum))) UInt))
;; Compare syntax independently from runtime sample validation and whole publishing.
(def empty-inference-test
  (test-suite "Witnessed finite emptiness without descriptor erasure"
    (test-case "mandatory products and alternatives compose across kinds"
      (for-each (lambda (source)
        (check (subtype-expression? source 'String) => #t)
        (check (subtype-expression? `(Function (UInt) (String))
          `(Function (Integer) (,source))) => #t)
        (check-equal? (normalize-type source (type-work 2000)) source))
        (list '(Enum) '(IntegerRange min: 2 max: 1) '(Tuple UInt (Enum)) dead
              '(Object ((run (Function (UInt) (UInt))) (missing (Enum))) open)
              '(Record ((missing (Tuple (Enum)) required) (run (Function (UInt) (UInt)) optional)) closed)))
      (check (subtype-expression? '(Tuple (Union (Enum) UInt)) 'String) => #f)
      (check (subtype-expression? '(Pair (Sum blocked: (Enum) ready: UInt) UInt) 'String) => #f))
    (test-case "empty collections sentinels and optional fields are inhabited"
      (for-each (lambda (source) (check (subtype-expression? source 'String) => #f))
        '((Tuple) (List (Enum)) (Map (Enum) <- UInt) (Maybe (Enum)) (OrFalse (Enum))
          (Record ((missing (Enum) optional)) closed) (Object () closed)
          (Function ((Enum)) (UInt))))
      (validate (expression-type '(List (Enum))) [])
      (validate (expression-type '(Map (Enum) <- UInt)) (make-hash-table))
      (validate (expression-type '(Maybe (Enum))) (void))
      (validate (expression-type '(OrFalse (Enum))) #f)
      (validate (expression-type '(Record ((missing (Enum) optional)) closed)) (.o)))
    (test-case "descriptor order tags and keys remain invariant even when empty"
      (check (subtype-expression? '(Union) '(Union UInt)) => #f)
      (check (subtype-expression? '(Enum) '(Union UInt (Function (UInt) (UInt)))) => #f)
      (check (subtype-expression? dead '(Union UInt (Function (UInt) (UInt)))) => #f)
      (check (subtype-expression? '(Sum absent: (Enum)) '(Sum other: (Enum))) => #f)
      ;; A positive empty key witness proves zero entries; live keys remain invariant.
      (check (subtype-expression? '(Map UInt <- (Tuple (Enum))) '(Map UInt <- String)) => #t)
      (check (subtype-expression? '(Map UInt <- (Tuple UInt)) '(Map UInt <- String)) => #f)
      (check (subtype-expression? '(Pair UInt UInt) '(Tuple (Enum))) => #f))
    (test-case "runtime validators reject impossible required payloads"
      (for-each (lambda (entry)
        (check-exception (validate (expression-type (car entry)) (cdr entry)) TypeError?))
        (list (cons '(Tuple UInt (Enum)) '(1 2)) (cons dead (cons (cons blocked: '(1)) 2))
          (cons '(Object ((missing (Enum))) open) (.o missing: 1))
          (cons '(Record ((missing (Enum) required)) closed) (.o missing: 1)))))
    (test-case "admission and work failure cannot be hidden by an empty branch"
      (check-exception (subtype-expression? '(Tuple (Enum) Unknown) 'String) (refusal 'unsupported))
      (check-exception (subtype-expression? '(Enum) '(Function (Unknown) (UInt))) (refusal 'unsupported))
      (check-exception (subtype-expression? dead 'String 4) (refusal 'exhausted))
      (check (subtype-expression? dead 'String 2000) => #t))
    (test-case "prefix inference qualified methods refinement and evidence retain wrappers"
      (def events []) (def calls 0)
      (def report (service.infer-empty-callback-service '(UInt) (list 'UInt dead)
        '((() (UInt) #f))
        (lambda (n) (values n (lambda (_) (set! calls (1+ calls)) n)))
        (lambda (event) (set! events (cons event events)))))
      (check-equal? (.get report status) 'unique)
      (check-equal? (.get report solutions) (list (list dead)))
      (check-equal? events [])
      (def context (.o approved: #t)) (def consumed 0) (def callback #f)
      ;; IO consumer observes only admitted refinement/evidence results.
      (def (consume subject)
        (set! consumed (1+ consumed)) (set! callback (.get subject callback)))
      (def action (service.empty-callback-action (.get report instance) 7 context consume))
      (defvalues (evidence next failure) (action context))
      (check-equal? failure #f) (check (eq? next context) => #t)
      (check (eq? (.get evidence context) context) => #t)
      (check-equal? (.get evidence subject answer) 7)
      (check-equal? (reverse events) '(around before after))
      (check-exception (callback (cons (cons blocked: '(1)) 2)) TypeError?)
      (check-equal? calls 0) (check-equal? consumed 1)
      (def failed (service.empty-callback-action (.get report instance) 8 context consume #f))
      (check-exception (failed context) TypeError?)
      (check-equal? consumed 1)
      (defvalues (_retry _retry-context retry-error) (action context))
      (check-equal? retry-error #f) (check-equal? consumed 2)
      (check-equal? (.get (service.infer-empty-callback-service '(UInt) (list 'UInt)
        '((() (UInt) #f)) (lambda (_) (error "unreachable builder"))) status) 'no-solution)
      (check-equal? (.get (service.infer-empty-callback-service '(UInt) (list dead '(Tuple (Enum)))
        '((() (UInt) #f)) (lambda (_) (error "ambiguous builder"))) status) 'ambiguous))))
