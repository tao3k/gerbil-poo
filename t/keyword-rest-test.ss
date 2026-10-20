;;; Literal precision and correlated infinite raw tails share one finite graph.
(export keyword-rest-test)
(import :std/test :std/error ../object ../mop ../type-relation ../prototype-types ../method-declaration
        (prefix-in ../examples/polymorphic-services service.))
;; Independent procedure wrappers provide the acceptance oracle, not graph states.
(def (accepted? function row)
  (try (apply function row) #t (catch (cause) (if (TypeError? cause) #f (raise cause)))))
;; Quota refusal never becomes an empty-language or cyclic-coverage certificate.
(def (exhausted? cause) (and (type-refusal? cause) (eq? (type-refusal-kind cause) 'exhausted)))
;; The infinite target distinguishes Boolean key payloads from UInt positions.
(def rest-target '(Function (UInt) (UInt) keywords: ((enabled: . Bool)) rest: UInt))
;; A literal-valued first position forces an escape before any ordinary value.
(def literal-target '(Function (UInt) ((Exactly #!rest)) keywords: ((scale: . UInt)) rest: UInt))
;; The entire protocol still requires exact-count covariant results and first selection.
(def keyword-rest-test
  (test-suite "Literal ordinary origins and correlated rest positions"
    (test-case "intrinsic alternatives share raw inclusion without changing public replacement"
      (def raw '(Union Integer Keyword (Enum #!key #!rest)))
      (def source `(Function (UInt) ((Enum scale: #!key #!rest) ,raw) rest: ,raw))
      (def target '(Function (UInt) ((Or Keyword (Exactly #!rest)))
        keywords: ((scale: . UInt)) rest: UInt))
      (check (subtype-expression? source target) => #t)
      (check (subtype-expression? `(List ,source) `(List ,target)) => #t)
      (check (subtype-expression? source
        '(Function (UInt) ((Or Keyword Bool)) keywords: ((scale: . UInt)) rest: UInt)) => #f)
      (for-each (lambda (first)
        (check (subtype-expression? source
          `(Function (UInt) (,first) keywords: ((scale: . UInt)) rest: UInt)) => #f))
        '((Maybe (Or Keyword (Exactly #!rest))) (OrFalse (Or Keyword (Exactly #!rest)))
          (Or Keyword (Function (UInt) (UInt)))))
      ;; Direct ordered alternatives and Map keys keep their original rules.
      (check (subtype-expression? '(Or Keyword (Exactly #!rest))
        '(Union Keyword (Exactly #!rest))) => #f)
      (check (subtype-expression? `(Map UInt <- ,source) `(Map UInt <- ,target)) => #f)
      (check-exception (subtype-expression? source
        '(Function (UInt) ((Or Keyword (Unknown))) keywords: ((scale: . UInt))))
        (lambda (cause) (and (type-refusal? cause) (eq? (type-refusal-kind cause) 'unsupported))))
      (check-exception (subtype-expression? source target 100) exhausted?))
    (test-case "optional token callbacks publish original cases through refinement and evidence"
      (def raw '(Union Integer Keyword Unit (Enum #f #!key #!rest)))
      (def source `(CaseFunction (Function (UInt) ((Union Unit (Exactly #f))))
        (Function (UInt) ((Union Unit (Enum #f scale: #!key #!rest)) ,raw) rest: ,raw)))
      (def target '(Function (UInt) ((OrFalse (Maybe (Or Keyword (Exactly #!rest)))))
        keywords: ((scale: . UInt)) rest: UInt))
      (def calls 0) (def consumed 0) (def observed #f) (def events [])
      ;; Compiler keyword/rest formals independently implement defaults and raw
      ;; escapes. Body counters detect validation failure before user execution.
      (def callback (lambda (value scale: (scale 1) . rest)
        (set! calls (1+ calls))
        (* scale (+ (cond ((void? value) 3) ((eq? value #f) 4)
                          ((keyword? value) 10) (else 20)) (apply + rest)))))
      (def report (service.infer-token-callback-service '(UInt) (list 'Bool source)
        `((() (UInt) (UInt ,target))) (lambda (value) (values value callback))
        (lambda (event) (set! events (cons event events)))))
      (check-equal? (.get report status) 'unique)
      (check-equal? (.get report solutions) (list (list (normalize-type source (type-work 4000)))))
      (check-equal? calls 0)
      (def context (.o approved: #t))
      (def action (service.catalog-service-action (.get report instance) 7 context
        (lambda (subject) (set! consumed (1+ consumed)) (set! observed (.get subject callback)))))
      (defvalues (evidence next failure) (action context))
      (check-equal? failure #f) (check-equal? consumed 1)
      (check (eq? next context) => #t)
      (check (eq? (.get evidence context) context) => #t)
      (check-equal? (reverse events) '(around before after))
      (def wrapped (validate (expression-type target) observed))
      (for-each (lambda (row answer) (check-equal? (apply wrapped row) answer))
        (list (list #f) (list (void)) (list #!key other:) (list #!key #!rest)
          (list scale: 2 #!key other: #!rest 1 2 3)
          (list #!key #!rest scale: 3 #!rest 1 2)) '(4 3 10 20 32 69))
      (check-equal? (apply wrapped (append (list #!key other: #!rest) (make-list 128 1))) 138)
      (let (before calls)
        (for-each (lambda (row) (check (accepted? wrapped row) => #f))
          (list (list #t) (list 7) (list #!key other: scale: #f)
                (list #!key other: #!rest #t) (list #!key)))
        (check-equal? calls before))
      (def rejected (service.catalog-service-action (.get report instance) 7 context
        (lambda (_) (error "refused consumer ran")) 0))
      (check-exception (rejected context) TypeError?)
      (defvalues (_retry-evidence _retry-context retried) (action context))
      (check-equal? retried #f) (check-equal? consumed 2)
      ;; Extensional identity views never canonicalize original branch order.
      (def equivalent `(CaseFunction (Function (UInt) ((Union Unit (Exactly #f))))
        (Function (UInt) ((Union Unit (Enum #f scale: #!key #!rest)) (Union Keyword Integer Unit (Enum #f #!key #!rest)))
          rest: (Union Keyword Integer Unit (Enum #f #!key #!rest)))))
      (check-equal? (.get (service.infer-token-callback-service '(UInt) (list source equivalent)
        [] (lambda (_) (error "ambiguous builder ran"))) status) 'ambiguous))
    (test-case "raw graph origins share positive finite container emptiness"
      (def source '(Function (UInt) () rest: (Union UInt (Enum #!key #!rest))))
      (def finite-source '(Function (UInt) ((Union UInt (Enum #!key #!rest)))
        optional: ((Union UInt (Enum #!key #!rest)) (Union UInt (Enum #!key #!rest)))))
      (for-each (lambda (payload)
        (def target `(Function (UInt) (UInt) keywords: ((retired: . ,payload)) rest: UInt))
        (check (subtype-expression? source target) => #t)
        (check (subtype-expression? `(List ,source) `(List ,target)) => #t)
        (check (subtype-expression? '(Function (UInt) (UInt))
          `(Function (UInt) (,payload) keywords: ((scale: . UInt)))) => #t)
        (check (subtype-expression? finite-source
          `(Function (UInt) (UInt) keywords: ((retired: . ,payload)) rest: ,payload)) => #t)
        (check-equal? (cdr (assq keywords: (function-options (normalize-type target (type-work 2000)))))
          (list (cons retired: payload))))
        '(Never (Pair Never (Function (UInt) (Integer))) (Tuple Never)
          (TypeValuePair) (Or Never (Enum)) (Sum retired: Never)
          (Record ((missing Never required)) closed)))
      ;; Nil, empty maps/vectors and optional sentinels are actual key payloads.
      ;; Their keyword token cannot be hidden from a source that refuses keywords.
      (for-each (lambda (payload)
        (check (subtype-expression? source
          `(Function (UInt) (UInt) keywords: ((retired: . ,payload)) rest: UInt)) => #f))
        '((List Never) (Map Never <- UInt) (Tuple) (Maybe Never) (OrFalse Never)
          (Record ((missing Never optional)) closed) UInt))
      (check (subtype-expression? '(Function (Bool) () rest: (Union UInt (Enum #!key #!rest)))
        '(Function (UInt) (UInt) keywords: ((retired: . (Pair Never UInt))) rest: UInt)) => #f)
      (check (subtype-expression? `(Map UInt <- ,source)
        '(Map UInt <- (Function (UInt) (UInt) keywords: ((retired: . (Pair Never UInt))) rest: UInt))) => #f)
      (check-exception (subtype-expression? source
        '(Function (UInt) (UInt) keywords: ((retired: . (Pair Never (Unknown))))))
        (lambda (cause) (and (type-refusal? cause) (eq? (type-refusal-kind cause) 'unsupported))))
      (check-exception (subtype-expression? source
        '(Function (UInt) (UInt) keywords: ((retired: . (Pair Never UInt))) rest: UInt) 100) exhausted?))
    (test-case "retired keyword publication retains live rest calls wrappers and retries"
      (def source '(Function (UInt) () rest: (Union UInt (Enum #!key #!rest))))
      (def target '(Function (UInt) (UInt)
        keywords: ((retired: . (Pair Never (Function (UInt) (UInt))))) rest: UInt))
      (def calls 0) (def consumed 0) (def observed #f) (def events [])
      ;; Gerbil keyword/rest formals own decoding and defaults independently of
      ;; the coverage graph. Standard apply folds only the supplied numeric data.
      (def callback (lambda (value retired: (_retired #f) . rest)
        (set! calls (1+ calls))
        (apply + value rest)))
      (def report (service.infer-retired-keyword-service '(UInt) (list 'Bool source)
        `((() (UInt) (UInt ,target)))
        (lambda (value) (values value callback))
        (lambda (event) (set! events (cons event events)))))
      (check-equal? (.get report status) 'unique)
      (check-equal? (.get report solutions) (list (list (normalize-type source (type-work 2000)))))
      (check-equal? calls 0)
      (def context (.o approved: #t))
      (def action (service.catalog-service-action (.get report instance) 7 context
        (lambda (subject)
          (set! consumed (1+ consumed)) (set! observed (.get subject callback)))))
      (defvalues (evidence next failure) (action context))
      (check-equal? failure #f) (check-equal? consumed 1)
      (check (eq? next context) => #t)
      (check (eq? (.get evidence context) context) => #t)
      (check-equal? (reverse events) '(around before after))
      (def target-wrapper (validate (expression-type target) observed))
      (for-each (lambda (row answer)
        (check-equal? (apply target-wrapper row) answer))
        (list '(7) (list #!key 7) (list 7 #!rest) (list 7 #!rest 1 2 3)
          (list #!key 7 #!rest 1 2 3)) '(7 7 7 13 13))
      ;; Capture after the successful calls: a local definition is not an
      ;; evaluation-order boundary for the compiled Gerbil body.
      (let (before calls)
        (for-each (lambda (row) (check (accepted? target-wrapper row) => #f))
          (list (list 7 retired: (cons 0 abs)) (list 7 retired: []) (list 7 retired: #f)))
        (check-equal? calls before))
      (check-exception ((service.catalog-service-action (.get report instance) 7 context
        (lambda (_) (set! consumed 99)) 0) context) TypeError?)
      (check-equal? consumed 1)
      (defvalues (_ _next retry) (action context))
      (check-equal? retry #f) (check-equal? consumed 2)
      ;; Different original arity metadata remains genuinely ambiguous.
      (def equivalent '(Function (UInt) ((Union UInt (Enum #!key #!rest)))
        optional: ((Union UInt (Enum #!key #!rest))) rest: (Union UInt (Enum #!key #!rest))))
      (check-equal? (.get (service.infer-retired-keyword-service '(UInt) (list source equivalent)
        `((() (UInt) (UInt ,target))) (lambda (_) (error "ambiguous builder ran"))) status) 'ambiguous))
    (test-case "literal-only positions have no ordinary decoding branch"
      (def target '(Function (UInt) (Keyword) keywords: ((scale: . UInt))))
      (def source '(Function (UInt) ((Enum scale: #!key #!rest) (Union Integer Keyword))
        rest: (Union Integer Keyword (Enum #!key #!rest))))
      (check (subtype-expression? source target) => #t)
      ;; No one-token source case exists, and no accepted one-token target call exists.
      (def wrapper (validate (expression-type target) (lambda _ 0)))
      (check (accepted? wrapper (list other:)) => #f)
      (check (accepted? wrapper (list #!key other:)) => #t)
      (check (accepted? wrapper (list #!rest other:)) => #t)
      ;; Even an incompatible source result is irrelevant in the empty raw region.
      (check (subtype-expression? `(CaseFunction (Function (Bool) (Bool)) ,source) target) => #t))
    (test-case "Exactly and finite Enum data retain the exact escaped payload"
      (for-each (lambda (literal)
        (def target `(Function (UInt) ((Exactly ,literal)) keywords: ((scale: . UInt))))
        (def source `(Function (UInt) ((Enum scale: #!key #!rest) (Union Integer (Exactly ,literal)))
          rest: (Union Integer Keyword (Enum #!key #!rest))))
        (check (subtype-expression? source target) => #t)
        ;; A source missing the payload literal must fail, even though its markers fit.
        (check (subtype-expression? '(Function (UInt) ((Enum scale: #!key #!rest) Integer)
          rest: (Union Integer Keyword (Enum #!key #!rest))) target) => #f))
        (list other: #!key #!rest)))
    (test-case "ordinary restriction preserves numeric arms and excludes only tokens"
      (def target '(Function (UInt) ((Enum 7 #!rest)) keywords: ((scale: . UInt))))
      ;; The direct row needs Exactly 7; treating it as the full Enum would refuse.
      (def source '(CaseFunction (Function (UInt) ((Exactly 7)))
        (Function (UInt) ((Union Integer Keyword (Enum #!key #!rest))
                         (Union Integer Keyword (Enum #!key #!rest)))
          rest: (Union Integer Keyword (Enum #!key #!rest)))))
      (check (subtype-expression? source target) => #t)
      (check (subtype-expression? `(CaseFunction (Function (Bool) ((Exactly 7))) ,@(cddr source)) target) => #f))
    (test-case "infinite Boolean payload never contaminates the first raw slot"
      (check (subtype-expression? service.CorrelatedRestCallback rest-target) => #t)
      (check (subtype-expression? service.LiteralRestCallback literal-target) => #t)
      (check (subtype-expression? '(Function (UInt) ((Union Integer (Enum enabled: #!key #!rest)))
        rest: (Union Integer (Enum enabled: #!key #!rest))) rest-target) => #f)
      ;; Public ordered Union bounds stay invariant throughout inference.
      (check (subtype-expression? '(Union UInt Bool) '(Union Integer Bool)) => #f))
    (test-case "decoded tail still visits late fixed raw cases"
      (def envelope '(Union Integer Bool (Enum enabled: #!key #!rest)))
      ;; Its raw arity lies beyond the shortest decoded representative's upper bound.
      ;; First-match result variance must still reject this late incompatible case.
      (def late `(Function (Bool) ,(make-list 12 envelope)))
      (check (subtype-expression? `(CaseFunction ,late ,service.CorrelatedRestCallback) rest-target 50000) => #f)
      (check (subtype-expression? `(CaseFunction (Function (UInt) ,(make-list 12 envelope))
        ,service.CorrelatedRestCallback) rest-target 50000) => #t))
    (test-case "independent wrappers exhaust raw words including malformed literals"
      (def alphabet (list 7 #t enabled: #!key #!rest))
      (def rows (let expand ((n 5))
        (if (zero? n) (list [])
          (let (tails (expand (1- n)))
            (cons [] (apply append (map (lambda (head) (map (cut cons head <>) tails)) alphabet)))))))
      (def target (validate (expression-type rest-target) (lambda _ 0)))
      (def source (validate (expression-type service.CorrelatedRestCallback) (lambda _ 0)))
      (for-each (lambda (row) (when (accepted? target row) (check-equal? (apply source row) 0))) rows)
      ;; These lengths are far beyond every fixed-prefix counter in the decision.
      (for-each (lambda (size)
        (def values (make-list size 7))
        (for-each (lambda (row)
          (check (accepted? target row) => #t)
          (check-equal? (apply source row) 0))
          (list values (append (list enabled: #t) values)
            (append (list #!key 7 enabled: #f #!rest) values)
            (append values (list enabled: #t #!rest))))) '(16 31 128 257)))
    (test-case "literal rest prefix survives long tails and nested Function results"
      (def target (validate (expression-type literal-target) (lambda _ 0)))
      (def source (validate (expression-type service.LiteralRestCallback) (lambda _ 0)))
      (for-each (lambda (size)
        (def tail (make-list size 7))
        (for-each (lambda (row)
          (check (accepted? target row) => #t)
          (check-equal? (apply source row) 0))
          (list (append (list #!rest #!rest) tail)
                (append (list scale: 3 #!key #!rest #!rest) tail)))) '(0 1 32 129))
      (check (subtype-expression? `(List ,service.CorrelatedRestCallback) `(List ,rest-target)) => #t)
      ;; Replacing Boolean payloads with an incompatible nested callback cannot pass.
      (check (subtype-expression? service.CorrelatedRestCallback
        '(Function (UInt) (UInt) keywords: ((enabled: . (Function (UInt) (UInt)))) rest: UInt)) => #f))
    (test-case "both infinite languages publish through specialization and evidence"
      (for-each (lambda (infer row expected)
        (def report (infer))
        (check-equal? (.get report status) 'unique)
        (def observed #f)
        (def action (service.catalog-service-action (.get report instance) 7 (.o approved: #t)
          (lambda (subject) (set! observed (.get subject callback)))))
        (defvalues (_ _context failure) (action #f))
        (check-equal? failure #f)
        (check-equal? (apply observed row) expected))
        (list service.infer-correlated-rest-service service.infer-literal-rest-service)
        (list (list enabled: #t #!key 7 #!rest 1 2 3) (list #!rest #!rest 1 2 3)) '(8 5)))
    (test-case "completed false and interrupted traversal cannot poison a fresh request"
      (def bad '(Function (UInt) ((Union Integer (Enum enabled: #!key #!rest)))
                  rest: (Union Integer (Enum enabled: #!key #!rest))))
      (for-each (lambda (_)
        (check (subtype-expression? bad rest-target) => #f)
        (check-exception (subtype-expression? service.CorrelatedRestCallback rest-target 100) exhausted?)
        (check (subtype-expression? service.CorrelatedRestCallback rest-target) => #t)
        (check (subtype-expression? service.LiteralRestCallback literal-target) => #t)) '(1 2 3)))
    (test-case "quota failure cannot approve a partial cyclic graph"
      (def schema (prototype-type (.o .parameters: '(Callback)) '(Callback) 'Callback `((Callback ,rest-target))))
      ;; Incomplete closure cannot execute the existing declaration builder.
      (def (forbidden _) (error "builder ran"))
      (check-exception (infer-declared schema (list service.CorrelatedRestCallback) [] forbidden 100) exhausted?))))
