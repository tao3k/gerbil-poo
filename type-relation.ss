;;; Finite structural Type expressions; no nominal-inheritance implication.
(export type-refusal? type-refusal-kind refuse-type bounded-type-data type-work type-expression substitute-type subtype-expression? subtype/checked? expression-type compile-expression)
(import :std/error (only-in ./mop Any Bool Function)
        (only-in ./number Integer UInt)
        (only-in ./type List Tuple))

;; Typed protocol refusal retains a machine-readable failure category. Consumer
;; callback/validation exceptions propagate unchanged and never become no-solution.
(deferror-class TypeRefusal () type-refusal?)
;; Inspect exhaustion/unsupported/malformed/bounds without matching printed text.
(def (type-refusal-kind cause) (car (Error-irritants cause)))
;; Raise before returning any descriptor, candidate or partially bound receiver.
(def (refuse-type kind message . details)
  (raise (TypeRefusal message irritants: (cons kind details))))

;; Each public request owns one quota. Unsupported syntax and exhaustion raise
;; before a descriptor or substitution is admitted; neither means subtype false.
(def (type-work budget)
  (unless (and (exact-integer? budget) (<= 1 budget 1048576))
    (refuse-type 'malformed "Type work budget must be in 1..1048576" budget))
  (let (remaining budget)
    (lambda ()
      (when (zero? remaining) (refuse-type 'exhausted "Type work budget exhausted"))
      (set! remaining (- remaining 1)))))

;; Preflight arbitrary input spines before list?/length/map; cycles and excessive
;; nesting fail under the same quota without invoking descriptor callbacks.
(def (bounded-type-data term work)
  (let walk ((value term) (depth 64))
    (work)
    (when (zero? depth) (refuse-type 'exhausted "Type expression depth exhausted"))
    (when (pair? value) (walk (car value) (- depth 1)) (walk (cdr value) (- depth 1)))))

;; Bound every pair traversal before list predicates, including malformed/cyclic
;; syntax. Maximum tree depth 64 also bounds host stack use independently of work.
(def (type-expression term variables work)
  (bounded-type-data term work)
  (let check ((value term))
    (work)
    (cond
     ((memq value '(Any Bool Integer UInt)) value)
     ((memq value variables) value)
     ((and (list? value) (pair? value))
      (case (car value)
        ((List) (unless (= (length value) 2) (refuse-type 'malformed "List Type needs one argument"))
                (check (cadr value)))
        ((Tuple) (for-each check (cdr value)))
        ((Function)
         (unless (and (= (length value) 3) (list? (cadr value)) (list? (caddr value)))
           (refuse-type 'malformed "Function Type needs output/input lists"))
         (for-each check (cadr value)) (for-each check (caddr value)))
        (else (refuse-type 'unsupported "Unsupported Type constructor" value))))
     (else (refuse-type 'unsupported "Unsupported Type expression" value))))
  term)

;; Substitute declared variables only. Callers check the complete finite term and
;; ground assignments first; undeclared symbols never turn into implicit Any.
(def (substitute-type term substitution work)
  (work)
  (let (binding (and (symbol? term) (assq term substitution)))
    (cond (binding (cdr binding))
          ((pair? term) (cons (substitute-type (car term) substitution work)
                             (substitute-type (cdr term) substitution work)))
          (else term))))

;; Decide derivability in the closed algebra: UInt <: Integer <: Any; Bool <: Any;
;; covariant List/Tuple observations; fixed-arity Function inputs contravariant,
;; outputs covariant, with exact multiple-value counts. False means no rule here,
;; not a counterexample to arbitrary predicate inclusion or mutable-slot writes.
(def (subtype-expression? source target (budget 8192))
  (let (work (type-work budget))
    (type-expression source [] work) (type-expression target [] work)
    (subtype/checked? source target work)))

;; Recursive comparisons share their caller's quota, including inference search.
;; This is exported only through the main judgment above; no active-pair success
;; shortcut admits recursive types, CaseFunction shadowing or opaque predicates.
(def (subtype/checked? source target work)
  (work)
  (cond
   ((equal? source target) #t)
   ((eq? target 'Any) #t)
   ((and (eq? source 'UInt) (eq? target 'Integer)) #t)
   ((and (pair? source) (pair? target) (eq? (car source) (car target)))
    (case (car source)
      ((List Tuple)
       (and (= (length source) (length target))
            (andmap (lambda (s t) (subtype/checked? s t work)) (cdr source) (cdr target))))
      ((Function)
       (and (= (length (cadr source)) (length (cadr target)))
            (= (length (caddr source)) (length (caddr target)))
            (andmap (lambda (s t) (subtype/checked? s t work)) (cadr source) (cadr target))
            (andmap (lambda (s t) (subtype/checked? t s work)) (caddr source) (caddr target))))
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
  (let build ((term expression))
    (work)
    (case term
      ((Any) Any) ((Bool) Bool) ((Integer) Integer) ((UInt) UInt)
      (else
       (case (car term)
         ((List) (List (build (cadr term))))
         ((Tuple) (apply Tuple (map build (cdr term))))
         ((Function) (Function (map build (cadr term)) (map build (caddr term)))))))))
