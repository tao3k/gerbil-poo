;;; Finite structural Type expressions; no nominal-inheritance implication.
(export type-refusal? type-refusal-kind refuse-type bounded-type-data type-work type-expression substitute-type subtype-expression? subtype/checked? expression-type compile-expression normalize-type function-options function-expression copy-type canonical-type)
(import ./type-syntax ./recursive-types ./object
        (only-in ./mop Any Bool Function CaseFunction Type. Object)
        (only-in ./object-contract ObjectContract.)
        (only-in ./number Integer UInt)
        (only-in ./type List Tuple Maybe Pair Map Sum Union))

;; Bottom has no inhabitants. Crossing a finite recursive approximation boundary
;; is ordinary type refusal, not work exhaustion or evidence of global emptiness.
(def Never (.cc Type. sexp: 'Never .element?: (lambda (_) #f)))

;; Expand only explicit guarded Mu and splice explicit Object row substitutions.
;; Disjointness/kind failures invalidate an assignment; exhaustion always escapes.
(def (normalize-type term work)
  (work)
  (cond ((not (pair? term)) term)
        ((eq? (car term) 'Mu) (normalize-type (unfold-type term work) work))
        ((eq? (car term) 'Object)
         (let* ((fields (map (lambda (field) (list (car field) (normalize-type (cadr field) work))) (cadr term)))
                (tail (caddr term)))
           (if (memq tail '(open closed)) (list 'Object fields tail)
             (let (row (normalize-type (cadr tail) work))
               (unless (and (pair? row) (eq? (car row) 'Object))
                 (refuse-type 'bounds "Row substitution requires an Object Type"))
               (when (ormap (lambda (field) (assq (car field) fields)) (cadr row))
                 (refuse-type 'bounds "Row substitution overlaps explicit fields"))
               (list 'Object (append fields (cadr row)) (caddr row))))))
        (else (map-type-children term (cut normalize-type <> work)))))

;; Select a declared Function through explicit Object fields. An unresolved row
;; tail or Type variable cannot invent a named signature before substitution.
;; Callers validate syntax with their own variable set before this shared walk.
(def (function-expression expression path work)
  (bounded-type-data path work)
  (unless (and (list? path) (andmap symbol? path))
    (refuse-type 'malformed "Signature path must contain field names" path))
  (let walk ((term expression) (path path))
    (work)
    (def current (if (and (pair? term) (eq? (car term) 'Mu)) (normalize-type term work) term))
    (if (null? path)
      (begin
        (unless (and (pair? current) (memq (car current) '(Function CaseFunction)))
          (refuse-type 'unsupported "Signature path does not name a concrete Function" path))
        current)
      (let (field (and (pair? current) (eq? (car current) 'Object) (assq (car path) (cadr current))))
        (unless field (refuse-type 'unsupported "Signature path needs explicit Object fields" path))
        (walk (cadr field) (cdr path))))))

;; Decide derivability in the closed algebra: UInt <: Integer <: Any; Bool <: Any;
;; covariant List/Tuple observations; fixed-arity Function inputs contravariant,
;; outputs covariant, with exact multiple-value counts. False means no rule here,
;; not a counterexample to arbitrary predicate inclusion or mutable-slot writes.
(def (subtype-expression? source target (budget 8192))
  (subtype/checked? source target (type-work budget)))

;; Recursive comparisons share their caller's quota, including inference search.
;; This is exported only through the main judgment above; no active-pair success
;; shortcut admits recursive types, CaseFunction shadowing or opaque predicates.
(def (subtype/checked? source target work)
  ;; Substitution can introduce new Mu nesting: recheck the complete ground terms.
  (type-expression source [] work) (type-expression target [] work)
  (compare-types (normalize-type source work) (normalize-type target work) work))

;; Compare normalized finite terms; every required target field must be present.
;; Open source rows promise no undeclared field; closed targets require exact keys.
(def (compare-types source target work)
  (work)
  (cond
   ((equal? source target) #t)
   ((or (eq? target 'Any) (eq? source 'Never)) #t)
   ((and (eq? source 'UInt) (eq? target 'Integer)) #t)
   ((and (pair? source) (pair? target) (eq? (car source) (car target)))
    (case (car source)
      ((List Maybe Tuple Pair)
       (and (= (length source) (length target))
            (andmap (lambda (s t) (compare-types s t work)) (cdr source) (cdr target))))
      ;; Keys are invariant after finite normalization: changing their validator
      ;; could change identity/equality or create a collision. Values are readable.
      ((Map) (and (equal? (cadddr source) (cadddr target))
                  (compare-types (cadr source) (cadr target) work)))
      ;; Equal tag skeletons retain wire order and selected payload identity.
      ((Sum)
       (let loop ((left (cdr source)) (right (cdr target)))
         (work)
         (cond ((null? left) (null? right))
               ((null? right) #f)
               (else (and (eq? (car left) (car right))
                          (compare-types (cadr left) (cadr right) work)
                          (loop (cddr left) (cddr right)))))))
      ;; Union equality was handled above. No widening, sorting, deduplication or
      ;; branchwise covariance may change committed first-match normalization.
      ((Union) #f)
      ((Object)
       (and (or (eq? (caddr target) 'open)
                (and (eq? (caddr source) 'closed)
                     (andmap (lambda (field) (work) (assq (car field) (cadr target))) (cadr source))))
            (andmap (lambda (field)
                      (let (found (assq (car field) (cadr source)))
                        (and found (compare-types (cadr found) (cadr field) work)))) (cadr target))))
      ((Function CaseFunction)
       ;; Same call-language metadata and ordered clause count only. This finite
       ;; rule cannot reorder overlapping cases or infer arbitrary domain coverage.
       (let ()
         ;; Erasing Type positions preserves ordered keys, option presence and
         ;; clause precedence. No implication between unequal shapes is guessed.
         (def (erase-types term)
           (if (eq? (car term) 'Function)
             (let* ((options (function-options term))
                    (option (lambda (name default) (cond ((assq name options) => cdr) (else default)))))
               (list 'Function (map (lambda (_) 'Any) (cadr term)) (map (lambda (_) 'Any) (caddr term))
                 optional: (map (lambda (_) 'Any) (option optional: []))
                 keywords: (map (lambda (entry) (cons (car entry) 'Any)) (option keywords: []))
                 required-keywords: (option required-keywords: [])
                 rest: (and (option rest: #f) 'Any)))
             (cons 'CaseFunction (map erase-types (cdr term)))))
         (and (equal? (erase-types source) (erase-types target))
           (let compare-clause ((s source) (t target))
             (if (eq? (car s) 'CaseFunction)
               (andmap compare-clause (cdr s) (cdr t))
               (and
                 (andmap (lambda (a b) (compare-types a b work)) (cadr s) (cadr t))
                 (andmap (lambda (a b) (compare-types b a work))
                   (function-input-types s) (function-input-types t))))))))
      (else #f)))
   (else #f)))

;; Compile a checked ground expression through existing recursive container and
;; Function validators. Wrapping remains at validate/contract boundaries, so this
;; never proves a host procedure's arity, totality or its result without a call.
(def (expression-type expression (budget 8192))
  (let (work (type-work budget))
    (type-expression expression [] work)
    (compile-expression expression work)))

;; Internal checked compiler shares its caller's work counter. Only finite terms
;; already admitted by type-expression may enter this lower-level operation.
(def (compile-expression expression work)
  (let build ((term (normalize-type expression work)))
    (work)
    (case term
      ((Any) Any) ((Never) Never) ((Bool) Bool) ((Integer) Integer) ((UInt) UInt)
      (else
       (case (car term)
         ((Object)
          (let (fields (object<-alist (map (lambda (field) (cons (car field) (build (cadr field)))) (cadr term))))
            (if (eq? (caddr term) 'closed)
              (.cc ObjectContract. responsibilities: fields)
              (.cc ObjectContract. responsibilities: fields extra-fields: 'delegate constraints: (list Object)))))
         ((Pair) (Pair (build (cadr term)) (build (caddr term))))
         ((Map) (Map (build (cadr term)) <- (build (cadddr term))))
         ((Sum) (apply Sum (cdr (map-sum-types term build))))
         ((Union) (apply Union (map build (cdr term))))
         ((Maybe) (Maybe (build (cadr term))))
         ((List) (List (build (cadr term))))
         ((Tuple) (apply Tuple (map build (cdr term))))
         ((CaseFunction) (apply CaseFunction (map build (cdr term))))
         ((Function)
          (let* ((options (function-options term))
                 (option (lambda (name default) (cond ((assq name options) => cdr) (else default)))))
          (Function (map build (cadr term)) (map build (caddr term))
            optional: (map build (option optional: []))
            keywords: (map (lambda (entry) (cons (car entry) (build (cdr entry)))) (option keywords: []))
            required-keywords: (option required-keywords: [])
            rest: (and (option rest: #f) (build (option rest: #f)))))))))))
