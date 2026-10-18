;;; Finite structural Type expressions; no nominal-inheritance implication.
(export function-covers? function-signatures type-refusal? type-refusal-kind refuse-type bounded-type-data type-work type-expression substitute-type subtype-expression? subtype/checked? expression-type compile-expression normalize-type function-options function-expression function-template copy-type canonical-type)
(import (only-in :std/list/list map-in-order) (prefix-in ./function-signature signature.) ./type-syntax ./recursive-types ./object
        (only-in ./mop Any Bool Function CaseFunction Type. Object Class.)
        (only-in ./object-contract ObjectContract.)
        (only-in ./number Integer UInt)
        (only-in ./type List Tuple Maybe Pair Map Sum Union RecordSlot))

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
(def (function-expression expression path work (missing 'unsupported))
  (bounded-type-data path work)
  (unless (and (list? path) (andmap symbol? path))
    (refuse-type 'malformed "Signature path must contain field names" path))
  (let walk ((term expression) (path path))
    (work)
    (def current (if (and (pair? term) (eq? (car term) 'Mu)) (normalize-type term work) term))
    (if (null? path)
      (begin
        (unless (and (pair? current) (memq (car current) '(Function CaseFunction)))
          (refuse-type missing "Signature path does not name a concrete Function" path))
        current)
      (let (field (and (pair? current) (eq? (car current) 'Object) (assq (car path) (cadr current))))
        (unless field (refuse-type missing "Signature path needs explicit Object fields" path))
        (walk (cadr field) (cdr path))))))

;; Return a known signature template, or #f when substitution can decide the
;; path's kind/layout. Literal names are not variables: capture-free substitution
;; detects only actual Type positions. Fixed absent paths still refuse up front.
;; Candidate projection later uses function-expression with bounds refusal.
(def (function-template expression path variables work)
  (bounded-type-data path work)
  (unless (and (list? path) (andmap symbol? path))
    (refuse-type 'malformed "Signature path must contain field names" path))
  ;; A private false marker detects free Type parameters without unfolding Mu.
  (def (dependent? term)
    (not (equal? term (substitute-type term (map (lambda (name) (cons name #f)) variables) work))))
  (let walk ((term expression) (remaining path))
    (work)
    (cond
      ((memq term variables) #f)
      ((and (pair? term) (eq? (car term) 'Mu))
       (if (dependent? term) #f (walk (normalize-type term work) remaining)))
      ((null? remaining) (function-expression term [] work))
      ((and (pair? term) (eq? (car term) 'Object))
       (let (field (assq (car remaining) (cadr term)))
         (cond (field (walk (cadr field) (cdr remaining)))
               ((pair? (caddr term))
                (if (dependent? (cadr (caddr term))) #f
                  (walk (normalize-type term work) remaining)))
               (else (refuse-type 'unsupported "Signature path needs a declared field" remaining)))))
      (else (refuse-type 'unsupported "Signature path needs Object fields" remaining)))))

;; Decide derivability in the closed algebra: UInt <: Integer <: Any; Bool <: Any;
;; covariant List/Tuple observations; covered Function inputs contravariant,
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
   ((and (pair? source) (pair? target)
         (memq (car source) '(Function CaseFunction)) (memq (car target) '(Function CaseFunction)))
    (function-replaces? source target work))
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
      ;; Conservative observational record relation: exact ordered field names,
      ;; no optional-to-required strengthening, readable field covariance. Open
      ;; source metadata cannot justify a sealed target or mutable writes.
      ((Record)
       (and (or (eq? (caddr target) 'open) (eq? (caddr source) 'closed))
            (= (length (cadr source)) (length (cadr target)))
            (andmap (lambda (s t)
                      (work)
                      (and (eq? (car s) (car t))
                           (or (eq? (caddr s) 'required) (eq? (caddr t) 'optional))
                           (compare-types (cadr s) (cadr t) work)))
                    (cadr source) (cadr target))))
      ((Object)
       (and (or (eq? (caddr target) 'open)
                (and (eq? (caddr source) 'closed)
                     (andmap (lambda (field) (work) (assq (car field) (cadr target))) (cadr source))))
            (andmap (lambda (field)
                      (let (found (assq (car field) (cadr source)))
                        (and found (compare-types (cadr found) (cadr field) work)))) (cadr target))))
      (else #f)))
   (else #f)))

;; Project raw Type positions to the EXISTING shape selector/argument normalizer.
;; These temporary objects are shape views, not new Types or dispatch certificates.
(def (signature-view term)
  (def options (function-options term))
  ;; Constructor defaults are literal metadata, never optional value expressions.
  (def (option name default) (cond ((assq name options) => cdr) (else default)))
  (.o bind-these: #f outputs: (cadr term) inputs: (caddr term)
    optional: (option optional: []) keywords: (option keywords: [])
    required-keywords: (option required-keywords: []) rest: (option rest: #f)))

;; Shared structural views feed inference and coverage through the same existing
;; Function selector/normalizer. They do not construct Types or certificates.
(def (function-signatures term)
  (map-in-order signature-view (if (eq? (car term) 'Function) (list term) (cdr term))))

;; Recognized ground Types exclude outer keyword/escape tokens without calling
;; user recognizers. Containers keep their outer carrier even when their payload
;; is Any; Maybe and Union can expose payloads, so inspect those alternatives.
;; Mu has already undergone the existing finite normalization/admission guard.
(def (keyword-stable-type? term work)
  (work)
  (case term
    ((Any) #f)
    ((Never Bool Integer UInt) #t)
    (else (case (car term)
      ((Maybe) (keyword-stable-type? (cadr term) work))
      ((Union) (andmap (cut keyword-stable-type? <> work) (cdr term)))
      ((List Tuple Pair Map Sum Record Object Function CaseFunction) #t)
      (else #f)))))

;; Keyword sources require stable supplied target carriers as before. For a
;; positional source, a direct minimum row has no keys or escapes and uses normal
;; variance. Other raw spellings require Any only at SUPPLIED source positions:
;; fixed/optional clauses and shadowed later cases retain their actual semantics.
(def (function-wire-related? actual expected arguments source-mode? target-mode? raw-arguments direct? work)
  (work)
  (if source-mode?
    (let (stable #t)
      (signature.normalize-arguments expected arguments target-mode?
        (lambda (formal _placeholder)
          (unless (keyword-stable-type? formal work) (set! stable #f))
          formal))
      stable)
    (or direct?
      (let (universal #t)
        (signature.normalize-arguments actual raw-arguments #f
          (lambda (formal _placeholder)
            (work)
            (unless (eq? formal 'Any) (set! universal #f))
            formal))
        universal))))

;; Decide shape-language inclusion in the bounded finite algebra. This checks
;; all allowed supplied rows, not Type inclusion or arbitrary host procedure arity.
;; Unsupported/malformed syntax and quota exhaustion retain their typed errors.
(def (function-covers? source target (budget 8192))
  (def work (type-work budget))
  (type-expression source [] work) (type-expression target [] work)
  (def left (normalize-type source work)) (def right (normalize-type target work))
  (unless (and (pair? left) (pair? right)
               (memq (car left) '(Function CaseFunction)) (memq (car right) '(Function CaseFunction)))
    (refuse-type 'bounds "Call coverage requires Function signatures"))
  (signature.covers-signatures? (function-signatures left) (function-signatures right) work
    (lambda _ #t) (cut function-wire-related? <> <> <> <> <> <> <> work)))

;; First-match selection determines BOTH sides of every row. Required/optional/
;; rest and provided keyword inputs are contravariant; exact-count outputs are
;; covariant. Shadowed later cases cannot repair an earlier incompatible clause.
(def (function-replaces? source target work)
  (signature.covers-signatures? (function-signatures source) (function-signatures target) work
    (lambda (actual expected arguments source-mode? target-mode? _raw-arguments direct?)
      (work)
      (and (= (length (.get actual outputs)) (length (.get expected outputs)))
           (andmap (lambda (s t) (compare-types s t work)) (.get actual outputs) (.get expected outputs))
        ;; Non-direct raw regions were checked Any at every supplied position.
        ;; Direct regions decode to the original positional row; extract those
        ;; Types without passing the encoder's literal #!rest into comparison.
        (or (and (not source-mode?) target-mode? (not direct?))
          (let* ((accepted #t)
                 (normalized (signature.normalize-arguments expected arguments target-mode?
                   (lambda (formal _placeholder) formal)))
                 (supplied (if direct? (car (signature.decode-arguments normalized target-mode?)) normalized)))
            (signature.normalize-arguments actual supplied source-mode?
              (lambda (formal value)
                (work)
                (unless (compare-types value formal work) (set! accepted #f))
                value))
            accepted))))
    (cut function-wire-related? <> <> <> <> <> <> <> work)))

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
         ;; Reuse Class and its effective Slot protocol, including recursive
         ;; validation and checked initialization. Defaults/hooks are host policy,
         ;; supplied by deriving this descriptor, never executable inference data.
         ((Record)
          (.cc Class. sexp: (copy-type term) sealed: (eq? (caddr term) 'closed)
            slots: (object<-alist (map (lambda (field)
              (cons (car field) (RecordSlot (build (cadr field)) optional: (eq? (caddr field) 'optional))))
              (cadr term)))))
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
