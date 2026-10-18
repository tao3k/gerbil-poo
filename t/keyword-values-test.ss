;;; Value-sensitive raw coverage uses exact protocol Types, never inferred Any.
(export keyword-values-test)
(import :std/test :std/error ../object ../mop ../type-relation ../prototype-types ../method-declaration
        (prefix-in ../examples/polymorphic-services service.))
;; One numeric position and one independently supplied numeric keyword payload.
(def target '(Function (UInt) (UInt) keywords: ((scale: . UInt))))
;; Reuse the complete Any-free source declaration in inference and runtime checks.
(def source service.KeywordValueCallback)
;; Test controlled quota failure independently of body/contract errors.
(def (exhausted? cause) (and (type-refusal? cause) (eq? (type-refusal-kind cause) 'exhausted)))
;; Construct an incompatible endpoint while preserving the earlier valid clauses.
(def bad-source `(CaseFunction ,(cadr source)
  (Function (UInt) ((Enum scale: #!key) Bool (Enum scale: #!key) Integer (Exactly #!rest)))
  ,(cadddr source)))
;; Finite literal admission and full inference/declaration/FUN integration controls.
(def keyword-values-test
  (test-suite "Value-sensitive raw keyword coverage"
    (test-case "exact scalar Types reuse existing validators and preserve literals"
      (check (subtype-expression? '(Exactly scale:) 'Keyword) => #t)
      (check (subtype-expression? '(Enum scale: other:) 'Keyword) => #t)
      ;; Raw origin inclusion must not widen the public ordered Union relation.
      (check (subtype-expression? '(Union UInt) '(Union Integer)) => #f)
      (check (subtype-expression? '(Enum #!key #!rest scale:) '(Union Keyword (Enum #!key #!rest))) => #f)
      (check (subtype-expression? '(Enum #!key other:) '(Enum #!key scale:)) => #f)
      (check (subtype-expression? '(Exactly -1) 'UInt) => #f)
      (check (subtype-expression? '(Exactly 2) 'Integer) => #t)
      (check (subtype-expression? 'Keyword '(Exactly scale:)) => #f)
      (check-equal? (validate (expression-type '(Exactly #!rest)) #!rest) #!rest)
      (check-exception (validate (expression-type '(Enum #!key #!rest)) scale:) TypeError?)
      ;; Literal payloads are not capture/substitution positions.
      (check-equal? (substitute-type '(Enum scale: #!key) '((scale: . Bool)) (type-work 100)) '(Enum scale: #!key)))
    (test-case "Enum snapshots precede the first lazy literal observation"
      (def syntax (list 'Enum scale: #!key))
      (def descriptor (expression-type syntax))
      (set-car! (cdr syntax) other:)
      (check-equal? (validate descriptor scale:) scale:)
      (check-exception (validate descriptor other:) TypeError?)
      (check-equal? (.get descriptor sexp) '(Enum scale: #!key)))
    (test-case "non-minimum five-token endpoint retains Integer payload slots"
      (check (function-covers? source target) => #t)
      (check (subtype-expression? source target) => #t)
      (check (subtype-expression? bad-source target) => #f)
      ;; A later safe clause cannot repair an incompatible earlier raw case.
      (check (subtype-expression? `(CaseFunction ,@(cdr bad-source) ,@(cdr source)) target) => #f)
      (check (subtype-expression? `(CaseFunction (Function (Bool) (UInt)) ,@(cddr source)) target) => #f))
    (test-case "independent direct-wrapper oracle covers values and wire spelling"
      ;; Includes wrong values, another keyword, dangling and duplicate markers.
      ;; No inference/coverage helper is used to decide target acceptance.
      (def alphabet (list 3 #f scale: other: #!key #!rest))
      (def rows (let expand ((n 5))
        (if (zero? n) (list [])
          (let (tails (expand (1- n)))
            (cons [] (apply append (map (lambda (head) (map (cut cons head <>) tails)) alphabet)))))))
      (def checked-target (validate (expression-type target) (lambda (n scale: (_scale 1)) n)))
      (def checked-source (validate (expression-type source) (lambda _ 0)))
      (def accepted-count 0)
      (for-each (lambda (row)
        (def accepted (try (apply checked-target row) #t
          (catch (cause) (if (TypeError? cause) #f (raise cause)))))
        (when accepted (set! accepted-count (1+ accepted-count))
          (check-equal? (apply checked-source row) 0))) rows)
      (check (> accepted-count 10) => #t)
      (check-exception (apply (validate (expression-type bad-source) (lambda _ 0))
        (list scale: 3 #!key 3 #!rest)) TypeError?))
    (test-case "different keyword payload origins remain separate"
      (def two-keys '(Function (UInt) (UInt) keywords: ((scale: . UInt) (enabled: . Bool))))
      (def envelope '(Union Integer Bool (Enum scale: enabled: #!key #!rest)))
      (check (subtype-expression? `(Function (UInt) () rest: ,envelope) two-keys 50000) => #t)
      (check (subtype-expression? '(Function (UInt) () rest: (Union Integer (Enum scale: enabled: #!key #!rest))) two-keys 50000) => #f)
      ;; No guessed keyword universe and no Any introduced to repair missing labels.
      (check (subtype-expression? '(Function (UInt) () rest: (Union Integer (Enum scale: #!key #!rest))) two-keys 50000) => #f))
    (test-case "unbounded stationary envelope can be explicit and Any-free"
      (def envelope '(Union Integer Keyword (Enum #!key #!rest)))
      (check (subtype-expression? `(Function (UInt) () rest: ,envelope)
        '(Function (UInt) (UInt) keywords: ((scale: . UInt)) rest: UInt) 50000) => #t)
      (check (subtype-expression? '(Function (UInt) () rest: Integer) target) => #f))
    (test-case "nested Function payloads retain wrapping and result failures"
      (def callback '(Function (UInt) (UInt)))
      ;; A required callback keyword has only two raw spellings. Both retain
      ;; the Function Type and its checked return value, with no broad Union.
      (def precise `(CaseFunction
        (Function (UInt) ((Exactly callback:) ,callback))
        (Function (UInt) ((Exactly callback:) ,callback (Exactly #!rest)))))
      (def expected `(Function (UInt) () keywords: ((callback: . ,callback)) required-keywords: (callback:)))
      (check (subtype-expression? precise expected) => #t)
      (def checked (validate (expression-type precise) (lambda (_key fn . _rest) (fn 3))))
      (check-equal? (apply checked (list callback: (lambda (n) (1+ n)))) 4)
      (check-equal? (apply checked (list callback: (lambda (n) (1+ n)) #!rest)) 4)
      (check-exception (apply checked (list callback: (lambda (_) #f))) TypeError?)
      ;; Wrapper-bearing Union cannot use flat Union widening.
      (check (subtype-expression? callback `(Union ,callback Bool)) => #f))
    (test-case "complete declarations compose specialization refine and evidence"
      (def report (service.infer-keyword-value-service))
      (check-equal? (.get report status) 'unique)
      (def observed #f)
      (def action (service.catalog-service-action (.get report instance) 7 (.o approved: #t)
        (lambda (subject) (set! observed (.get subject callback)))))
      (defvalues (_ _context failure) (action #f))
      (check-equal? failure #f)
      (check-equal? (observed 7) 8)
      (check-equal? (apply observed (list scale: 2 #!key 7 #!rest)) 9)
      (check-exception (apply observed (list scale: #f #!key 7 #!rest)) TypeError?))
    (test-case "exhaustion and failed inference never enter declaration builder"
      (def schema (prototype-type (.o .parameters: '(Callback)) '(Callback) 'Callback `((Callback ,target))))
      ;; A failed/partial derivation is not a callback candidate or a certificate.
      (def (forbidden _) (error "builder ran"))
      (check-equal? (.get (infer-declared schema (list bad-source) [] forbidden) status) 'no-solution)
      (check-exception (infer-declared schema (list source) [] forbidden 80) exhausted?))))
