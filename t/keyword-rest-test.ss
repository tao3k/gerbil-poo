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
