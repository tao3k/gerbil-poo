;;; Complete call-language partitioning and operational first-match controls.
(export function-coverage-test)
(import :std/test :std/error ../object ../mop ../type-relation ../prototype-types ../method-declaration
        (prefix-in ../examples/polymorphic-services service.) (prefix-in ../function-signature signature.))
;; Distinguish bounded-search refusal from ordinary callback/contract errors.
(def (refusal kind) (lambda (cause) (and (type-refusal? cause) (eq? (type-refusal-kind cause) kind))))
;; Source rest accepts the target's isolated first case and its infinite tail.
(def broad '(Function (UInt) (Integer) rest: Integer))
;; Two ordered clauses include every positive arity; the second is a rest region.
(def split '(CaseFunction (Function (Integer) (UInt)) (Function (Integer) (UInt UInt) rest: UInt)))
;; Coverage and replacement have independent negative and executable controls.
(def function-coverage-test
  (test-suite "Ordered case call-language coverage and replacement"
    (test-case "one rest clause covers a split infinite target language"
      (check (function-covers? broad split) => #t)
      (check (subtype-expression? broad split) => #t)
      (check (function-covers? split broad) => #t)
      (check (subtype-expression? split broad) => #f)
      (def checked (validate (expression-type broad) (lambda args (apply + args))))
      (check-equal? (apply checked (make-list 80 1)) 80)
      (check-exception (checked #f) TypeError?))
    (test-case "optional and disjoint fixed cases admit different representations"
      (def optional '(Function (UInt) (Integer) optional: (Integer)))
      (def fixed '(CaseFunction (Function (Integer) (UInt)) (Function (Integer) (UInt UInt))))
      (check (subtype-expression? optional fixed) => #t)
      (check (function-covers? fixed optional) => #t)
      (check (function-covers? '(Function (UInt) (UInt)) optional) => #f)
      (check (function-covers? '(Function (UInt) (UInt UInt)) optional) => #f))
    (test-case "disjoint cases may reorder but overlapping cases retain commitment"
      (def reordered '(CaseFunction (Function (UInt) (Integer Integer)) (Function (UInt) (Integer))))
      (check (subtype-expression? reordered split) => #f)
      (check (subtype-expression? reordered '(CaseFunction (Function (Integer) (UInt))
        (Function (Integer) (UInt UInt)))) => #t)
      (def shadowed '(CaseFunction (Function (Bool) (Integer) rest: Integer) (Function (UInt) (Integer))))
      (check (function-covers? shadowed broad) => #t)
      (check (subtype-expression? shadowed broad) => #f))
    (test-case "target shadowing does not demand unreachable later clause Types"
      (def target '(CaseFunction (Function (Integer) (UInt) rest: UInt) (Function (Bool) (UInt))))
      (check (subtype-expression? broad target) => #t)
      (def changed '(CaseFunction (Function (Bool) (UInt)) (Function (Integer) (UInt) rest: UInt)))
      (check (subtype-expression? broad changed) => #f))
    (test-case "keyword presence partitions choose different first clauses"
      (def source '(CaseFunction
        (Function (UInt) (Integer) keywords: ((mode: . Integer)) required-keywords: (mode:))
        (Function (UInt) (Integer) keywords: ((mode: . Integer) (extra: . Bool)))))
      (def target '(Function (Integer) (UInt) keywords: ((mode: . UInt))))
      (check (function-covers? source target) => #t)
      (check (subtype-expression? source target) => #t)
      (check (function-covers? (car (cdr source)) target) => #f)
      (def wrong '(CaseFunction
        (Function (Bool) (Integer) keywords: ((mode: . Integer)) required-keywords: (mode:))
        (Function (UInt) (Integer) keywords: ((mode: . Integer)))))
      (check (subtype-expression? wrong target) => #f))
    (test-case "keyword wire modes are an explicit conservative boundary"
      (check (function-covers? '(Function (UInt) (Any) rest: Any)
        '(Function (UInt) (UInt) keywords: ((mode: . UInt)))) => #f)
      (check (function-covers? '(Function (UInt) (UInt) keywords: ((mode: . UInt)))
        '(Function (UInt) (UInt))) => #f))
    (test-case "supplied input positions and keys are contravariant"
      (check (subtype-expression? '(Function (UInt) (UInt) optional: (UInt))
        '(Function (Integer) (Integer) optional: (Integer))) => #f)
      (check (subtype-expression? '(Function (UInt) (Integer) rest: UInt)
        '(Function (Integer) (UInt) rest: Integer)) => #f)
      (check (subtype-expression? '(Function (UInt) (Integer) keywords: ((mode: . UInt)))
        '(Function (Integer) (UInt) keywords: ((mode: . Integer)))) => #f))
    (test-case "multiple values are covariant with exact counts in each region"
      (check (subtype-expression? '(Function (UInt Bool) (Integer) rest: Integer)
        '(CaseFunction (Function (Integer Bool) (UInt)) (Function (Integer Bool) (UInt UInt)))) => #t)
      (check (subtype-expression? '(CaseFunction (Function (UInt Bool) (Integer)) (Function (UInt) (Integer Integer)))
        '(Function (Integer Bool) (UInt) optional: (UInt))) => #f)
      (check (subtype-expression? '(Function () (Integer) rest: Integer)
        '(CaseFunction (Function () (UInt)) (Function () (UInt UInt)))) => #t))
    (test-case "nested callback replacement propagates through existing containers"
      (check (subtype-expression? `(List ,broad) `(List ,split)) => #t)
      (check (subtype-expression? `(Map ,broad <- UInt) `(Map ,split <- UInt)) => #t)
      (check (subtype-expression? `(Map UInt <- ,broad) `(Map UInt <- ,split)) => #f))
    (test-case "independent runtime oracle covers every small arity and keyword order"
      ;; This finite control executes existing validators; the Lean partition
      ;; theorem, rather than these sampled tail lengths, covers unbounded arity.
      (def terms
        '((Function (Bool) (Any) keywords: ((mode: . Any) (extra: . Any)))
          (Function (Bool) (Any) optional: (Any) keywords: ((mode: . Any)))
          (CaseFunction
            (Function (Bool) (Any) keywords: ((mode: . Any)) required-keywords: (mode:))
            (Function (Bool) (Any Any) keywords: ((mode: . Any) (extra: . Any))))
          (Function (Bool) () rest: Any keywords: ((mode: . Any) (extra: . Any)))
          (CaseFunction
            (Function (Bool) (Any) keywords: ((mode: . Any) (extra: . Any)))
            (Function (Bool) (Any Any Any) rest: Any keywords: ((mode: . Any) (extra: . Any))))
          (Function (Bool) (Any) keywords: ((mode: . Any) (extra: . Any)) required-keywords: (mode:))))
      (def rows (apply append (map (lambda (count)
        (map (lambda (keys) (signature.encode-arguments (make-list count #t)
          (map (lambda (key) (cons key #t)) keys) #t))
          '(() (mode:) (extra:) (mode: extra:) (extra: mode:)))) '(0 1 2 3 4 5 6))))
      (def operational (map (lambda (term)
        (def checked (validate (expression-type term) (lambda _ #t)))
        (list term (map (lambda (row)
          (try (apply checked row) #t
            (catch (cause) (if (TypeError? cause) #f (raise cause))))) rows))) terms))
      (for-each (lambda (source) (for-each (lambda (target)
        (def oracle (andmap (lambda (actual expected) (or (not expected) actual)) (cadr source) (cadr target)))
        (check-equal? (function-covers? (car source) (car target)) oracle)
        (check-equal? (subtype-expression? (car source) (car target)) oracle)) operational)) operational))
    (test-case "exhaustion and malformed syntax cannot certify a partial language"
      (check-exception (function-covers? broad split 20) (refusal 'exhausted))
      (check-exception (function-covers? '(CaseFunction) split) (refusal 'malformed))
      (check-exception (function-covers? 'UInt split) (refusal 'bounds)))
    (test-case "coverage exhaustion after an admitted cell returns no prefix certificate"
      (def work 0) (def admitted 0)
      (check-exception (signature.covers-signatures? (function-signatures broad) (function-signatures split)
        (lambda () (set! work (1+ work)) (when (> work 10) (refuse-type 'exhausted "cell quota")))
        (lambda _ (set! admitted (1+ admitted)) #t)) (refusal 'exhausted))
      (check-equal? admitted 1))
    (test-case "prefix inference and unified declarations select the covering callback"
      (def events [])
      (def report (service.infer-covered-service
        '((Function (UInt) (UInt)) (Function (UInt) (Integer) rest: Integer))
        (lambda (n) (values n (lambda args (apply + args))))
        (lambda (event) (set! events (cons event events)))))
      (check-equal? (.get report status) 'unique)
      (check-equal? events [])
      (def observed #f)
      (def action (service.catalog-service-action (.get report instance) 7 (.o approved: #t)
        (lambda (subject) (set! observed (.get subject callback)))))
      (defvalues (_ _context failure) (action #f))
      (check-equal? failure #f)
      (check-equal? (observed 1) 1)
      (check-equal? (observed 1 2) 3)
      (check-exception (observed #f) TypeError?)
      (check-equal? (reverse events) '(around before after)))
    (test-case "inconsistent and incomplete coverage inference never enters builder"
      (def schema (prototype-type (.o .parameters: '(Callback)) '(Callback) 'Callback
        (list (list 'Callback split))))
      (def (forbidden _) (error "builder ran"))
      (check-equal? (.get (infer-declared-calls schema '((Function (UInt) (Integer))) [] forbidden) status) 'no-solution)
      (check-exception (infer-declared-calls schema (list broad split) [] forbidden 40) (refusal 'exhausted)))))
