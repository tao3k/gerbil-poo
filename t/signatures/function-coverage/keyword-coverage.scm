;;; Cross-mode calls retain the original raw row, including keywords and escapes.


;; Distinguish structural refusal/quota errors from callback and contract failures.
(def (refusal kind) (lambda (cause) (and (type-refusal? cause) (eq? (type-refusal-kind cause) kind))))
;; Optional keyword input makes this a genuine keyword-mode descriptor.
(def keyword-source '(Function (UInt) (Integer) keywords: ((scale: . UInt))))
;; Ordinary scalar input excludes keyword/escape tokens at the outer position.
(def positional-target '(Function (Integer) (UInt)))
;; The complete suite checks both directions and independent operational controls.
(def keyword-coverage-test
  (test-suite "Different keyword interpretation modes"
    (test-case "keyword source covers a token-stable positional target unchanged"
      (check (function-covers? keyword-source positional-target) => #t)
      (check (subtype-expression? keyword-source positional-target) => #t)
      (def defaults 0)
      (def checked (validate (expression-type keyword-source)
        (lambda (n scale: (scale (begin (set! defaults (1+ defaults)) 1))) (* (abs n) scale))))
      (check-equal? defaults 0)
      (check-equal? (checked 7) 7)
      (check-equal? defaults 1)
      (check-equal? (checked 7 scale: 2) 14)
      (check-equal? defaults 1))
    (test-case "Any and exposed Maybe/Union payloads cannot hide protocol tokens"
      (for-each (lambda (input)
        (check (function-covers? '(Function (UInt) (Any) keywords: ((mode: . Any)))
          `(Function (UInt) (,input))) => #f)) '(Any (Maybe Any) (Union UInt Any)))
      (def target (validate (expression-type '(Function (UInt) (Any))) (lambda _ 0)))
      (def source (validate (expression-type '(Function (UInt) (Any) keywords: ((mode: . Any)))) (lambda _ 0)))
      (for-each (lambda (token)
        (check-equal? (apply target (list token)) 0)
        (check-exception (apply source (list token)) TypeError?)) (list mode: #!key)))
    (test-case "outer containers hide payload tokens but exposed optionals do not"
      (for-each (lambda (input)
        (check (subtype-expression? '(Function (UInt) (Any) keywords: ((mode: . Any)))
          `(Function (UInt) (,input))) => #t))
        '(Bool UInt Integer (List Any) (Tuple Any) (Pair Any Any) (Map Any <- Any)
          (Sum data: Any) (Object () open) (Record () open) (Function (Any) (Any))
          (CaseFunction (Function (UInt) (UInt))) (Maybe UInt) (Union UInt Bool)))
      (def checked (validate (expression-type '(Function (UInt) ((List Any)) keywords: ((mode: . UInt))))
        (lambda (items mode: (_mode 0)) (length items))))
      (check-equal? (checked (list mode: #!key #!rest)) 3)
      (for-each (lambda (token)
        (for-each (lambda (input)
          (check-exception (validate (expression-type input) token) TypeError?))
          '(UInt Bool (List Any) (Tuple Any) (Pair Any Any) (Map Any <- Any) (Function (UInt) (UInt)))))
        (list mode: #!key #!rest)))
    (test-case "only supplied positions matter and stationary rest Types are checked"
      (check (function-covers? '(Function (UInt) (Integer) rest: Integer keywords: ((mode: . UInt)))
        '(CaseFunction (Function (UInt) (UInt)) (Function (UInt) (UInt UInt) rest: UInt))) => #t)
      (check (function-covers? '(Function (UInt) (Any) rest: Any keywords: ((mode: . UInt)))
        '(Function (UInt) (UInt) optional: (Any))) => #f)
      (check (function-covers? '(Function (UInt) (Any) rest: Any keywords: ((mode: . UInt)))
        '(Function (UInt) (UInt) rest: Any)) => #f)
      (check (function-covers? '(Function (UInt) () keywords: ((mode: . UInt))) '(Function (UInt) ())) => #t))
    (test-case "target and source first-shape selection cannot fall through"
      (def source '(CaseFunction
        (Function (Bool) (Integer) keywords: ((mode: . UInt)))
        (Function (UInt) (Integer) keywords: ((mode: . UInt)))))
      (check (function-covers? source positional-target) => #t)
      (check (subtype-expression? source positional-target) => #f)
      (def target '(CaseFunction (Function (UInt) (Any)) (Function (UInt) (UInt))))
      (check (function-covers? keyword-source target) => #f)
      (check (function-covers? keyword-source '(CaseFunction (Function (UInt) (UInt)) (Function (UInt) (Any)))) => #t))
    (test-case "required keyword clauses reject a plain target unless another shape accepts"
      (def required '(Function (UInt) (Integer) keywords: ((mode: . UInt)) required-keywords: (mode:)))
      (check (function-covers? required positional-target) => #f)
      (check (subtype-expression? `(CaseFunction ,required ,keyword-source) positional-target) => #t))
    (test-case "raw Any rest preserves every keyword order and escape spelling"
      (def source '(Function (UInt) () rest: Any))
      (def target '(Function (UInt) (Any) keywords: ((mode: . Any))))
      (check (function-covers? source target) => #t)
      (check (subtype-expression? source target) => #t)
      (def seen #f)
      (def checked (validate (expression-type source) (lambda args (set! seen args) (length args))))
      (for-each (lambda (row)
        (check-equal? (apply checked row) (length row))
        (check-equal? seen row))
        (list (list 7 mode: 2) (list mode: 2 7) (list #!key mode: mode: 2)
              (list mode: 2 #!rest #!key #!rest mode:))))
    (test-case "raw minimum excludes the optional rest escape token"
      (def optional '(Function (UInt) (UInt) keywords: ((mode: . UInt))))
      (def required '(Function (UInt) (UInt) keywords: ((mode: . UInt)) required-keywords: (mode:)))
      (check (function-covers? '(Function (UInt) (Any) rest: Any) optional) => #t)
      (check (function-covers? '(Function (UInt) (Any Any) rest: Any) optional) => #f)
      (check (function-covers? '(Function (UInt) (Any Any Any) rest: Any) required) => #t)
      (check (function-covers? '(Function (UInt) (Any Any Any Any) rest: Any) required) => #f)
      (check (function-covers? '(Function (UInt) (Any) optional: (UInt) rest: Any) required) => #f)
      (check (function-covers? '(Function (UInt) (Any) rest: UInt) optional) => #f))
    (test-case "raw positional cases follow actual arity and result obligations"
      (def target '(Function (UInt) (UInt) keywords: ((mode: . UInt))))
      ;; The one-argument typed case handles the direct row; later raw arities use Any.
      (check (function-covers? '(CaseFunction (Function (UInt) (UInt)) (Function (UInt) () rest: Any)) target) => #t)
      (check (subtype-expression? '(CaseFunction (Function (Bool) () rest: Any) (Function (UInt) () rest: Any)) target) => #f)
      (check (subtype-expression? '(Function (UInt Bool) () rest: Any) target) => #f))
    (test-case "operational oracle checks unmodified raw calls over a finite token alphabet"
      ;; Enumerate raw rows, not the coverage checker's arity/key partitions.
      ;; This independently exercises dangling keys, keyEscape and restEscape.
      (def alphabet (list 7 mode: #!key #!rest))
      (def rows (let expand ((depth 4))
        (if (zero? depth) (list [])
          (let (shorter (expand (1- depth)))
            (append (list []) (apply append (map (lambda (head)
              (map (lambda (tail) (cons head tail)) shorter)) alphabet)))))))
      (def pairs
        (list (list '(Function (UInt) (Any) keywords: ((mode: . Any))) '(Function (UInt) (UInt)))
              (list '(Function (UInt) () rest: Any) '(Function (UInt) (Any) keywords: ((mode: . Any))))
              (list '(Function (UInt) (Any Any Any) rest: Any)
                    '(Function (UInt) (UInt) keywords: ((mode: . Any)) required-keywords: (mode:)))))
      (for-each (lambda (pair)
        (def source (validate (expression-type (car pair)) (lambda _ 0)))
        (def target (validate (expression-type (cadr pair)) (lambda _ 0)))
        (check (subtype-expression? (car pair) (cadr pair)) => #t)
        (for-each (lambda (row)
          (def accepted (try (apply target row) #t (catch (cause) (if (TypeError? cause) #f (raise cause)))))
          (when accepted (check-equal? (apply source row) 0))) rows)) pairs))
    (test-case "nested Function replacement uses the same cross-mode proof"
      (check (subtype-expression? `(List ,keyword-source) `(List ,positional-target)) => #t)
      (check (subtype-expression? `(Pair ,keyword-source Bool) `(Pair ,positional-target Bool)) => #t)
      (check (subtype-expression? `(Map UInt <- ,keyword-source) `(Map UInt <- ,positional-target)) => #f))
    (test-case "prefix inference publishes a real keyword callback through FUN and evidence"
      (def defaults 0)
      (def report (service.infer-positional-callback-service
        '((Function (UInt) (Integer) keywords: ((scale: . UInt)) required-keywords: (scale:))
          (Function (UInt) (Integer) keywords: ((scale: . UInt))))
        (lambda (n) (values n (lambda (value scale: (scale (begin (set! defaults (1+ defaults)) 1))) (* (abs value) scale))))))
      (check-equal? (.get report status) 'unique)
      (check-equal? defaults 0)
      (def seen #f)
      (def action (service.catalog-service-action (.get report instance) 7 (.o approved: #t)
        (lambda (subject) (set! seen (.get subject callback)))))
      (defvalues (_ _context failure) (action #f))
      (check-equal? failure #f)
      (check-equal? (seen 7) 7)
      (check-equal? defaults 1)
      (check-equal? (seen 7 scale: 2) 14)
      (check-exception (seen #f) TypeError?))
    (test-case "joint inference publishes a raw-row callback with no injected or dropped tokens"
      (def seen #f)
      (def report (service.infer-keyword-callback-service
        '((Function (UInt) (Any Any) rest: Any) (Function (UInt) (Any) rest: Any))
        (lambda (n) (values n (lambda args (set! seen args) (length args))))))
      (check-equal? (.get report status) 'unique)
      (def instance (.get report instance))
      (def action (service.catalog-service-action instance 7 (.o approved: #t)
        (lambda (subject)
          (def callback (.get subject callback))
          (check-equal? (apply callback (list scale: 2 7)) 3)
          (check-equal? seen (list scale: 2 7)))))
      (defvalues (_ _context failure) (action #f))
      (check-equal? failure #f))
    (test-case "failed or exhausted mode inference cannot run declaration builders"
      (def schema (prototype-type (.o .parameters: '(Callback)) '(Callback) 'Callback
        '((Callback (Function (UInt) (Any))))))
      (def (forbidden _) (error "builder ran"))
      (check-equal? (.get (infer-declared schema (list keyword-source) [] forbidden) status) 'no-solution)
      (check-exception (infer-declared schema (list keyword-source) [] forbidden 20) (refusal 'exhausted)))))

;; Return the original suites from this lexical scope.
(values keyword-coverage-test)
