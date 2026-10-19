;;; Checked finite type syntax, row binders and explicit recursive approximants.
(export scalar-recognizer type-constructor? type-refusal? type-refusal-kind refuse-type bounded-type-data type-work
        type-expression substitute-type guarded-body? copy-type literal-type-value? function-options call-with-function-types map-function-types function-input-types map-sum-types map-type-children canonical-type)
(import :std/error (only-in :std/list/list delete-duplicates/hash map-in-order)
        (only-in :std/list/plist alist->plist) (only-in ./support/base require-value))
;; Only built-in scalar recognizers enter finite derivation. This registry is
;; private; exported lookup never invokes a mutable POO descriptor or user Type.
(def scalar-recognizers
  (list (cons 'Any true) (cons 'Never false) (cons 'Bool boolean?)
        (cons 'Integer exact-integer?) (cons 'UInt (lambda (value) (and (exact-integer? value) (>= value 0))))
        (cons 'Keyword keyword?) (cons 'String string?) (cons 'Symbol symbol?)))
;; Gerbil's presence-preserving association lookup supplies the known predicate;
;; unknown scalar names remain false and cannot manufacture a universal Type.
(def (scalar-recognizer name) (agetq name scalar-recognizers))
;; One constructor vocabulary owns prototype/Mu binder admission. A constructor
;; cannot become a free Type variable merely because a caller uses another phase.
(def (type-constructor? name)
  (or (and (scalar-recognizer name) #t)
      (and (memq name '(Exactly Enum List Maybe OrFalse Tuple Pair Map Sum Union Record
                       Function CaseFunction Object Row Mu)) #t)))
;; Protocol failures remain separate from false judgments and callback exceptions.
(deferror-class TypeRefusal () type-refusal?)
;; Inspect controlled failure without depending on diagnostic formatting.
(def (type-refusal-kind cause) (car (Error-irritants cause)))
;; No failed operation returns a partial descriptor or accepted substitution.
(def (refuse-type kind message . details)
  (raise (TypeRefusal message irritants: (cons kind details))))
;; One request shares this counter across parsing, expansion, search and building.
(def (type-work budget)
  (require-value budget (in-range-inclusive? 1 1048576)
    (lambda () (refuse-type 'malformed "Type work budget must be in 1..1048576" budget)))
  (let (remaining budget)
    (lambda ()
      (when (zero? remaining) (refuse-type 'exhausted "Type work budget exhausted"))
      (set! remaining (- remaining 1)))))
;; Visit pairs before list operations. Physical cycles and deep spines refuse.
(def (bounded-type-data term work)
  (let walk ((value term) (depth 64))
    (work)
    (when (zero? depth) (refuse-type 'exhausted "Type expression depth exhausted"))
    (when (pair? value) (walk (car value) (- depth 1)) (walk (cdr value) (- depth 1)))))
;; Copy finite checked syntax so caller list mutation cannot alter admitted laws.
;; Descriptor objects are compiled later and are not cached across publication.
(def (copy-type term)
  (if (pair? term) (cons (copy-type (car term)) (copy-type (cdr term))) term))

;; Only immutable scalar literals enter the decidable Exactly/Enum algebra.
;; Protocol escapes stay literal metadata, never Type variables or recognizers.
(def (literal-type-value? value)
  (or (boolean? value) (exact-integer? value) (keyword? value) (symbol? value)
      (eq? value #!key) (eq? value #!rest)))

;; Read the existing Function constructor options as literal metadata. Omitted
;; options keep constructor defaults; duplicates and unknown options refuse.
(def (function-options term)
  (let loop ((rest (cdddr term)) (seen []))
    (if (null? rest) seen
      (begin
        (unless (and (pair? rest) (pair? (cdr rest)) (keyword? (car rest))
                     (memq (car rest) '(optional: keywords: required-keywords: rest:))
                     (not (assq (car rest) seen)))
          (refuse-type 'malformed "Invalid or duplicate Function option" rest))
        (loop (cddr rest) (cons (cons (car rest) (cadr rest)) seen))))))
;; Bind the existing Function schema once for each consumer. Gerbil's agetq
;; preserves explicit false and supplies only literal metadata defaults; it does
;; not evaluate optional argument values, validators or a target procedure.
(def (call-with-function-types term consume)
  (def options (function-options term))
  (consume (cadr term) (caddr term) (agetq optional: options [])
    (agetq keywords: options []) (agetq required-keywords: options []) (agetq rest: options #f)))

;; Use the same option order/default omission as the existing Function descriptor.
;; Child Type order, keyword declarations and required-key order remain literal.
;; Retain any nonempty required-key metadata so malformed input cannot disappear.
(def (canonical-function term)
  (call-with-function-types term
    (lambda (outputs inputs optional keywords required rest)
      (append (list 'Function outputs inputs)
        (if (and (null? optional) (null? keywords) (null? required) (not rest)) []
          (list optional: optional keywords: keywords required-keywords: required rest: rest))))))

;; Transform only Type positions. Keyword labels and required-key metadata remain
;; literal, even when their spelling equals a prototype parameter name.
(def (map-function-types term transform)
  (cons* 'Function (map transform (cadr term)) (map transform (caddr term))
    (alist->plist
      (map-in-order (lambda (entry)
        (def name (car entry)) (def value (cdr entry))
        (cons name
          (case name
            ((optional:) (map transform value))
            ((keywords:) (map (lambda (entry) (cons (car entry) (transform (cdr entry)))) value))
            ((rest:) (and value (transform value)))
            (else value))))
        (reverse (function-options term))))))
;; Flatten only contravariant Type positions using the constructor's defaults.
;; Source keyword order is retained; no supplied argument/default is constructed.
(def (function-input-types term)
  (call-with-function-types term
    (lambda (_outputs inputs optional keywords _required rest)
      (append inputs optional (map cdr keywords) (if rest (list rest) [])))))
;; Sum's keyword tags are literal metadata, never binders or Type variables.
;; Preserve declaration order while mapping only the associated payload Types.
(def (map-sum-types term transform)
  (cons 'Sum (let loop ((entries (cdr term)))
    (if (null? entries) []
      (cons (car entries) (cons (transform (cadr entries)) (loop (cddr entries))))))))
;; Traverse admitted Type children without treating literal tags, arrows, row
;; markers or Mu binders/depth as Types. Canonical Map arrows share one shape.
(def (map-type-children term transform (canonical? #f))
  (case (car term)
    ((Exactly Enum) term)
    ((Function) (let (mapped (map-function-types term transform))
                  (if canonical? (canonical-function mapped) mapped)))
    ((Sum) (map-sum-types term transform))
    ((Map)
     (let ((first (transform (cadr term))) (last (transform (cadddr term))))
       (if (eq? (caddr term) '<-) (list 'Map first '<- last) (list 'Map last '<- first))))
    ((Object Record)
     (list (car term) (map (lambda (field) (cons (car field) (cons (transform (cadr field)) (cddr field)))) (cadr term))
       (if (pair? (caddr term)) (list 'Row (transform (cadr (caddr term)))) (caddr term))))
    ((Mu) (list 'Mu (cadr term) (caddr term) (transform (cadddr term))))
    (else (cons (car term) (map transform (cdr term))))))
;; Candidate deduplication canonicalizes syntax without expanding Mu or splicing
;; rows. Complete substitution must still reject newly nested/negative recursion;
;; erasing a candidate's binders before that check would bypass admission.
(def (canonical-type term work)
  (work)
  (if (pair? term) (map-type-children term (cut canonical-type <> work) #t) term))
;; Recursion must cross a data carrier and remain positive. Nested Mu binders and
;; row-tail recursion are unsupported; Function arguments cannot mention self.
(def (guarded-body? term name work)
  (let walk ((value term) (guarded? #f) (positive? #t))
    (work)
    (cond ((eq? value name) (and guarded? positive?))
          ((not (pair? value)) #t)
          (else
           (case (car value)
             ((Mu) #f)
             ((CaseFunction) (andmap (lambda (clause) (walk clause guarded? positive?)) (cdr value)))
             ((Function)
              (and (andmap (lambda (x) (walk x guarded? positive?)) (cadr value))
                   (andmap (lambda (x) (walk x guarded? #f)) (function-input-types value))))
             ((Object Record)
              (and (andmap (lambda (field) (walk (cadr field) #t positive?)) (cadr value))
                   (or (not (pair? (caddr value))) (walk (cadr (caddr value)) #f #f))))
             ((Map) (if (eq? (caddr value) '<-)
                      (and (walk (cadr value) #t positive?) (walk (cadddr value) #f #f))
                      (and (walk (cadr value) #f #f) (walk (cadddr value) #t positive?))))
             ((Sum) (let loop ((entries (cdr value)))
                      (or (null? entries)
                          (and (walk (cadr entries) #t positive?) (loop (cddr entries))))))
             ((List Maybe OrFalse Tuple Pair Union) (andmap (lambda (x) (walk x #t positive?)) (cdr value)))
             (else #t))))))
;; Admit syntax independently of subtype decisions. Field labels are unique
;; symbols, not type variables; row tails are open/closed or (Row expression).
(def (type-expression term variables work)
  (bounded-type-data term work)
  (let check ((value term) (variables variables))
    (work)
    (cond
     ((scalar-recognizer value) value)
     ((memq value variables) value)
     ((and (list? value) (pair? value))
      (case (car value)
        ((Exactly Enum)
         (unless (and (or (eq? (car value) 'Enum) (= (length value) 2))
                      (andmap literal-type-value? (cdr value)))
           (refuse-type 'unsupported "Exactly/Enum needs immutable scalar literals" value)))
        ((List Maybe OrFalse)
         (unless (= (length value) 2) (refuse-type 'malformed "Unary Type needs one argument"))
         (check (cadr value) variables))
        ((Pair)
         (unless (= (length value) 3) (refuse-type 'malformed "Pair Type needs two arguments"))
         (for-each (cut check <> variables) (cdr value)))
        ((Map)
         (unless (and (= (length value) 4) (memq (caddr value) '(<- ->)))
           (refuse-type 'malformed "Map Type needs Value <- Key or Key -> Value"))
         (check (cadr value) variables) (check (cadddr value) variables))
        ((Sum)
         (let loop ((entries (cdr value)) (seen []))
           (unless (null? entries)
             (unless (and (pair? entries) (pair? (cdr entries)) (keyword? (car entries))
                          (not (memq (car entries) seen)))
               (refuse-type 'malformed "Sum Type needs unique keyword payload Types"))
             (check (cadr entries) variables)
             (loop (cddr entries) (cons (car entries) seen)))))
        ((Union Tuple) (for-each (cut check <> variables) (cdr value)))
        ((Function)
         (unless (and (>= (length value) 3) (list? (cadr value)) (list? (caddr value)))
           (refuse-type 'malformed "Function Type needs output/input lists"))
         (for-each (cut check <> variables) (cadr value))
         (for-each (cut check <> variables) (caddr value))
         (call-with-function-types value
           (lambda (_outputs _inputs optional keys required rest)
             (unless (and (list? optional) (list? keys) (list? required)
                          (andmap (lambda (entry) (and (pair? entry) (keyword? (car entry)))) keys)
                          (= (length keys) (length (delete-duplicates/hash (map car keys))))
                          (= (length required) (length (delete-duplicates/hash required)))
                          (andmap (lambda (key) (and (keyword? key) (assq key keys))) required))
               (refuse-type 'malformed "Invalid Function option metadata" value))
             (for-each (cut check <> variables) optional)
             (for-each (lambda (entry) (check (cdr entry) variables)) keys)
             (when rest (check rest variables)))))
        ((CaseFunction)
         (unless (and (pair? (cdr value))
                      (andmap (lambda (clause) (and (list? clause) (pair? clause) (eq? (car clause) 'Function))) (cdr value)))
           (refuse-type 'malformed "CaseFunction needs ordered Function clauses" value))
         (for-each (cut check <> variables) (cdr value)))
        ((Record)
         (unless (and (= (length value) 3) (list? (cadr value)) (memq (caddr value) '(open closed))
                      (andmap (lambda (field) (and (list? field) (= (length field) 3)
                                  (symbol? (car field)) (memq (caddr field) '(required optional)))) (cadr value))
                      (= (length (cadr value)) (length (delete-duplicates/hash (map car (cadr value))))))
           (refuse-type 'malformed "Record Type needs unique named Type/presence fields and open/closed policy"))
         (for-each (lambda (field) (check (cadr field) variables)) (cadr value)))
        ((Object)
         (unless (and (= (length value) 3) (list? (cadr value))
                      (andmap (lambda (field) (and (list? field) (= (length field) 2) (symbol? (car field))))
                              (cadr value)))
           (refuse-type 'malformed "Object Type needs named fields and a row tail"))
         (let fields ((todo (cadr value)) (seen []))
           (unless (null? todo)
             (when (memq (caar todo) seen) (refuse-type 'malformed "Duplicate Object Type field" (caar todo)))
             (check (cadar todo) variables)
             (fields (cdr todo) (cons (caar todo) seen))))
         (let (tail (caddr value))
           (unless ((one-of open closed) tail)
             (unless (and (list? tail) (= (length tail) 2) (eq? (car tail) 'Row))
               (refuse-type 'malformed "Invalid Object row tail" tail))
             (check (cadr tail) variables))))
        ((Mu)
         (unless (and (= (length value) 4) (symbol? (cadr value))
                      (not (type-constructor? (cadr value)))
                      (not (memq (cadr value) variables))
                      (exact-integer? (caddr value)) (<= 0 (caddr value) 16))
           (refuse-type 'malformed "Mu needs a fresh binder and depth in 0..16"))
         (check (cadddr value) (cons (cadr value) variables))
         (unless (guarded-body? (cadddr value) (cadr value) work)
           (refuse-type 'unsupported "Recursive Type must be guarded, positive and unnested")))
        (else (refuse-type 'unsupported "Unsupported Type constructor" value))))
     (else (refuse-type 'unsupported "Unsupported Type expression" value))))
  term)
;; Syntax-directed substitution preserves literal field labels and avoids capture
;; by Mu. Row positions are substituted as Types then kind/disjointness checked.
(def (substitute-type term substitution work)
  (work)
  (cond
   ((symbol? term) (let (binding (assq term substitution)) (if binding (cdr binding) term)))
   ((not (pair? term)) term)
   ((memq (car term) '(Object Record))
    (list (car term)
      (map (lambda (field) (cons (car field) (cons (substitute-type (cadr field) substitution work) (cddr field)))) (cadr term))
      (if (pair? (caddr term)) (list 'Row (substitute-type (cadr (caddr term)) substitution work)) (caddr term))))
   ((memq (car term) '(Exactly Enum)) term)
   ((eq? (car term) 'Sum) (map-sum-types term (cut substitute-type <> substitution work)))
   ((eq? (car term) 'Map)
    (list 'Map (substitute-type (cadr term) substitution work) (caddr term)
      (substitute-type (cadddr term) substitution work)))
   ((eq? (car term) 'Mu)
    (list 'Mu (cadr term) (caddr term)
      (substitute-type (cadddr term) (filter (lambda (binding) (not (eq? (car binding) (cadr term)))) substitution) work)))
   (else (cons (car term)
           (if (eq? (car term) 'Function)
             (cdr (map-function-types term (cut substitute-type <> substitution work)))
             (map (cut substitute-type <> substitution work) (cdr term)))))))
