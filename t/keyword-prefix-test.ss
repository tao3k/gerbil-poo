;;; Raw length regions preserve ordered source cases across keyword modes.
(export keyword-prefix-test)
(import :std/test :std/error ../object ../mop ../types/relation ../prototype-types ../method-declaration
        (prefix-in ../examples/polymorphic-services service.))
;; The target has one UInt value and an optional scale keyword.
(def keyword-target '(Function (UInt) (UInt) keywords: ((scale: . UInt))))
;; Every raw spelling has length one through five, including a trailing rest escape.
(def fixed-source '(Function (UInt) (Any) optional: (Any Any Any Any)))
;; The first real case may retain a scalar Type; all longer raw regions use Any.
(def typed-source service.KeywordPrefixCallback)
;; Identify quota errors without confusing them with contract/body failures.
(def (exhausted? cause) (and (type-refusal? cause) (eq? (type-refusal-kind cause) 'exhausted)))
;; Exercise exact raw boundaries, ordered cases and complete publication.
(def keyword-prefix-test
  (test-suite "Fixed and ordered cross-mode keyword coverage"
    (test-case "fixed optional prefix closes the finite raw interval"
      (check (function-covers? fixed-source keyword-target) => #t)
      (check (subtype-expression? fixed-source keyword-target) => #t)
      ;; The raw upper endpoint is observable, not the canonical encoder's length.
      (def target (validate (expression-type keyword-target) (lambda (n scale: (_scale 1)) n)))
      ;; This spelling costs two tokens per position/key plus the trailing marker.
      (def upper (list scale: 2 #!key 7 #!rest))
      (check-equal? (apply target upper) 7)
      ;; A shorter optional prefix misses that valid raw call.
      (def short '(Function (UInt) (Any) optional: (Any Any Any)))
      (check (function-covers? short keyword-target) => #f)
      (check-exception (apply (validate (expression-type short) (lambda _ 0)) upper) TypeError?))
    (test-case "ordered typed direct case and optional raw case both participate"
      (check (function-covers? typed-source keyword-target) => #t)
      (check (subtype-expression? typed-source keyword-target) => #t)
      ;; A genuine Gerbil case-lambda receives the original raw row.
      (def checked (validate (expression-type typed-source)
        (case-lambda ((n) (1+ n)) ((a b . rest) (+ 2 (length rest))))))
      (check-equal? (checked 7) 8)
      (check-equal? (apply checked (list #!rest 7)) 2)
      (check-equal? (apply checked (list scale: 2 7)) 3)
      (check-equal? (apply checked (list scale: 2 #!key 7 #!rest)) 5))
    (test-case "every source raw arity may choose a different fixed case"
      ;; Enumerate all five fixed cases with the established finite Function syntax.
      (def cases `(CaseFunction ,@(map (lambda (n) `(Function (UInt) ,(make-list n 'Any))) '(1 2 3 4 5))))
      (check (subtype-expression? cases keyword-target) => #t)
      (check (function-covers? `(CaseFunction ,@(cdr (cdr cases))) keyword-target) => #f))
    (test-case "unused optional Types do not impose supplied-input obligations"
      (check (subtype-expression? '(Function (UInt) () optional: (Any Any Any Any Any Bool)) keyword-target) => #t)
      (check (function-covers? '(Function (UInt) () optional: (Any Bool Any Any Any)) keyword-target) => #f)
      (check (function-covers? '(Function (UInt) (UInt) optional: (Any Any Any Any)) keyword-target) => #f))
    (test-case "unbounded targets retain a checked stationary raw tail"
      ;; Rest rows beyond all fixed prefixes must still admit protocol tokens.
      (def target '(Function (Integer) (UInt) rest: UInt keywords: ((scale: . UInt))))
      (check (subtype-expression? '(CaseFunction (Function (UInt) (UInt))
        (Function (UInt) (Any Any) rest: Any)) target) => #t)
      (check (function-covers? typed-source target) => #f)
      (check (function-covers? '(Function (UInt) (UInt) rest: UInt) target) => #f))
    (test-case "first-match refusal cannot fall through on Types or results"
      ;; Shape coverage alone does not certify direct-row value variance.
      (check (function-covers? `(CaseFunction (Function (UInt) (Bool)) ,@(cdr typed-source)) keyword-target) => #t)
      (check (subtype-expression? `(CaseFunction (Function (UInt) (Bool)) ,@(cdr typed-source)) keyword-target) => #f)
      (check (subtype-expression? `(CaseFunction (Function (Bool) (Any) optional: (Any Any Any Any))
        ,@(cdr typed-source)) keyword-target) => #f)
      (check (subtype-expression? '(Function (UInt Bool) () rest: Any) keyword-target) => #f))
    (test-case "target decoded cases may share a source raw arity"
      ;; The two decoded arities overlap at raw length two: one direct, one escaped.
      (def target '(CaseFunction (Function (Integer) (UInt) keywords: ((scale: . UInt)))
        (Function (Integer) (UInt UInt) keywords: ((scale: . UInt)))))
      (check (subtype-expression? '(CaseFunction (Function (UInt) (UInt))
        (Function (UInt) (Any Any) optional: (Any Any Any Any Any))) target) => #t)
      (check (subtype-expression? '(Function (UInt) () rest: Any)
        '(CaseFunction (Function (UInt) (UInt) keywords: ((scale: . UInt)))
          (Function (Bool) (UInt UInt) keywords: ((scale: . UInt))))) => #f))
    (test-case "direct-wrapper oracle enumerates spellings rather than arity cells"
      ;; This independent alphabet includes valid escapes, dangling and repeated keys.
      (def alphabet (list 7 scale: #!key #!rest))
      ;; Enumerate all 1365 rows of length at most five, without using coverage helpers.
      (def rows (let expand ((depth 5))
        (if (zero? depth) (list [])
          (let (shorter (expand (1- depth)))
            (append (list []) (apply append (map (lambda (head)
              (map (lambda (tail) (cons head tail)) shorter)) alphabet)))))))
      ;; All positive source descriptors are independently checked by runtime wrappers.
      (def target (validate (expression-type keyword-target) (lambda (n scale: (_scale 1)) n)))
      (for-each (lambda (source)
        ;; Body deliberately tolerates every row; descriptor checks remain observable.
        (def checked (validate (expression-type source) (lambda _ 0)))
        (check (subtype-expression? source keyword-target) => #t)
        (for-each (lambda (row)
          ;; Only TypeError is a target refusal; unexpected exceptions fail the oracle.
          (def accepted (try (apply target row) #t (catch (cause) (if (TypeError? cause) #f (raise cause)))))
          (when accepted (check-equal? (apply checked row) 0))) rows))
        (list fixed-source typed-source)))
    (test-case "prefix inference and whole declarations publish through FUN/evidence"
      ;; The incompatible typed-result candidate must be rejected before publication.
      (def report (service.infer-keyword-prefix-service))
      (check-equal? (.get report status) 'unique)
      ;; Inspect the exact recursively wrapped callback carried by existing evidence.
      (def observed #f)
      (def action (service.catalog-service-action (.get report instance) 7 (.o approved: #t)
        (lambda (subject) (set! observed (.get subject callback)))))
      (defvalues (_ _context failure) (action #f))
      (check-equal? failure #f)
      (check-equal? (observed 7) 8)
      (check-equal? (apply observed (list scale: 2 #!key 7 #!rest)) 5)
      (check-exception (observed #f) TypeError?))
    (test-case "incomplete raw traversal cannot publish a prefix certificate"
      ;; A callback bound requiring a wrong raw prefix has no finite candidate.
      (def schema (prototype-type (.o .parameters: '(Callback)) '(Callback) 'Callback
        `((Callback ,keyword-target))))
      ;; A partial traversal or complete failure must not enter the declaration builder.
      (def (forbidden _) (error "builder ran"))
      (check-equal? (.get (infer-declared schema '((Function (UInt) (UInt) rest: UInt)) [] forbidden) status) 'no-solution)
      (check-exception (infer-declared schema (list typed-source) [] forbidden 40) exhausted?))
    (test-case "nested callback variance uses the same raw-region obligations"
      (check (subtype-expression? `(List ,typed-source) `(List ,keyword-target)) => #t)
      (check (subtype-expression? `(Pair ,typed-source UInt) `(Pair ,keyword-target Integer)) => #t)
      (check (subtype-expression? `(Map UInt <- ,typed-source) `(Map UInt <- ,keyword-target)) => #f))))
