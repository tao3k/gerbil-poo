;;; Bounded rank-one prototype polymorphism and finite-candidate inference.
(export prototype-type specialize-prototype-type instantiate-prototype infer-prototype infer-prototype-calls bound-parameters)
(import (only-in ./support/base require-value) :std/error (only-in :std/list/list delete-duplicates/hash take drop map-in-order)
        ./object ./type-relation (only-in ./mop Type validate)
        (prefix-in ./parameters positional.)
        (prefix-in ./function-signature signature.))

;; A bound descriptor carries its direct source revision. The private immutable
;; record is transport for ordinary metadata, not an arbitrary Type inclusion proof.
(defstruct type-binding (descriptor revision) final: #t)
;; Preserve field identity and descriptor revision for each newly bound parameter.
(def (capture-bindings names descriptors)
  (map (lambda (name descriptor) (cons name (make-type-binding descriptor (object-revision descriptor))))
    names descriptors))

;; Check the current parameter fields and direct descriptor revisions under one
;; quota. These snapshots do not certify transitive callback/Type behavior.
(def (check-bindings prototype bound variables work)
  (bounded-type-data bound work)
  (unless (and (list? bound)
               (andmap (lambda (binding) (and (pair? binding) (symbol? (car binding)) (type-binding? (cdr binding)))) bound)
               (= (length bound) (length (delete-duplicates/hash (map car bound))))
               (not (ormap (lambda (binding) (or (eq? (car binding) '.parameters)
                                                (memq (car binding) variables))) bound)))
    (refuse-type 'malformed "Invalid bound parameter snapshot"))
  (for-each (lambda (binding)
    (def snapshot (cdr binding))
    (def descriptor (type-binding-descriptor snapshot))
    (validate Type descriptor)
    (unless (and (eq? (.ref prototype (car binding)) descriptor)
                 (= (object-revision descriptor) (type-binding-revision snapshot)))
      (refuse-type 'bounds "Bound type parameter changed" (car binding)))) bound)
  bound)

;; Return copied bound names after rechecking the current receiver and Type
;; descriptors. The same check guards residual inference and final publication.
(def (bound-parameters instance (budget 8192))
  (map car (check-bindings (.get instance prototype) (.get instance bound-parameters) [] (type-work budget))))

;; Capture an immutable syntax snapshot before any specialization or computed
;; prototype field executes. Variable names are exactly existing .parameters;
;; bounds are pairs (Self Super), denoting Self <: Super as in the appendix.
(def (prototype-type prototype variables expression bounds (budget 8192))
  (prepare-prototype-type prototype variables expression bounds (type-work budget)))

;; Revalidate and snapshot public schema metadata for every inference/instance.
;; No mutable descriptor record is trusted as an enduring proof certificate.
(def (prepare-prototype-type prototype variables expression bounds work (bound []))
  (bounded-type-data variables work)
  (require-value variables list? (lambda () (refuse-type 'malformed "Type variables must be a list")))
  (check-bindings prototype bound variables work)
  (let ()
    (type-expression `(Tuple ,@variables) variables work)
    (unless (and (andmap symbol? variables)
                 (not (ormap (cut memq <> '(Any Never Bool Integer UInt List Maybe Tuple Function CaseFunction Object Row Mu)) variables))
                 (= (length variables) (length (delete-duplicates/hash variables)))
                 (equal? variables (positional.parameters prototype)))
      (refuse-type 'malformed "Type variables must match unique prototype parameters" variables))
    (type-expression expression variables work)
    (bounded-type-data bounds work)
    (unless (and (list? bounds) (andmap (lambda (bound) (and (list? bound) (= (length bound) 2))) bounds))
      (refuse-type 'malformed "Subtype constraints need two expressions" bounds))
    (for-each (lambda (bound) (for-each (cut type-expression <> variables work) bound)) bounds)
    ;; .o formulas are lazy: force private copies before constructing the schema,
    ;; otherwise a later first observation would copy already-mutated source data.
    (let ((captured-variables (map identity variables))
          (captured-expression (copy-type expression))
          (captured-bounds (map copy-type bounds))
          (captured-bindings (map (lambda (binding) (cons (car binding) (cdr binding))) bound)))
      (.o bind-these: #f prototype: prototype variables: captured-variables
          expression: captured-expression bounds: captured-bounds bound-parameters: captured-bindings))))

;; Bind a ground Type prefix through the existing persistent positional protocol.
;; Remaining expressions/bounds stay explicit residual obligations, not approvals.
;; A complete prefix checks all bounds before cloning; partial bounds are checked
;; by later complete instantiation/inference. Every syntax/copy/build shares work.
(def (specialize-prototype-type schema arguments (budget 8192))
  (def work (type-work budget))
  (def scheme (prepare-prototype-type (.get schema prototype) (.get schema variables)
    (.get schema expression) (.get schema bounds) work (.get schema bound-parameters)))
  (bounded-type-data arguments work)
  (unless (and (list? arguments) (<= (length arguments) (length (.get scheme variables))))
    (refuse-type 'malformed "Type prefix exceeds prototype parameters"))
  (for-each (cut type-expression <> [] work) arguments)
  (def count (length arguments))
  (when (= count (length (.get scheme variables))) (checked-substitution scheme arguments work))
  (def substitution (map cons (take (.get scheme variables) count) (map copy-type arguments)))
  (def expression (substitute-type (.get scheme expression) substitution work))
  (def bounds (map (lambda (bound) (map (cut substitute-type <> substitution work) bound)) (.get scheme bounds)))
  (def bound-values (map (cut compile-expression <> work) arguments))
  (def receiver (apply positional.specialize (.get scheme prototype) bound-values))
  (prepare-prototype-type receiver (drop (.get scheme variables) count) expression bounds work
    (append (.get scheme bound-parameters) (capture-bindings (take (.get scheme variables) count) bound-values))))

;; Validate ordered substitutions and all declared bounds before touching the
;; prototype. Rejection returns no partially specialized receiver or descriptor.
(def (checked-substitution scheme arguments work)
  (bounded-type-data arguments work)
  (unless (and (list? arguments) (= (length arguments) (length (.get scheme variables))))
    (refuse-type 'malformed "Type substitution arity mismatch"))
  (for-each (lambda (term) (type-expression term [] work)) arguments)
  (let (substitution (map cons (.get scheme variables) (map copy-type arguments)))
    (let (ground (substitute-type (.get scheme expression) substitution work))
      (type-expression ground [] work)
      (normalize-type ground work))
    (unless (andmap
             (lambda (bound)
               (subtype/checked?
                 (substitute-type (car bound) substitution work)
                 (substitute-type (cadr bound) substitution work) work))
             (.get scheme bounds))
      (refuse-type 'bounds "Type substitution violates subtype constraint" arguments))
    substitution))

;; Use ordinary persistent positional specialization, with existing Type values
;; in parameter slots. The resulting receiver retains inherited/computed formulas;
;; its signature is the substituted existing Function/container descriptor.
(def (instantiate-prototype scheme arguments (budget 8192))
  (instantiate/checked scheme arguments (type-work budget)))

;; Internal assembly shares the inference quota through compilation and binding.
;; Metadata is an explicit caller-owned schema, not an authenticated proof token.
(def (instantiate/checked scheme arguments work)
  (let* ((scheme (prepare-prototype-type (.get scheme prototype) (.get scheme variables)
                   (.get scheme expression) (.get scheme bounds) work (.get scheme bound-parameters)))
         (substitution (checked-substitution scheme arguments work))
         (expression (substitute-type (.get scheme expression) substitution work))
         (descriptor (compile-expression expression work))
         (bound-values (map (cut compile-expression <> work) arguments))
         (receiver (apply positional.specialize (.get scheme prototype) bound-values))
         (bindings (append (.get scheme bound-parameters) (capture-bindings (.get scheme variables) bound-values))))
    (.o bind-these: #f prototype: receiver descriptor: descriptor
        expression: expression substitution: substitution bound-parameters: bindings)))

;; Exhaustively check a finite caller-supplied ground candidate universe. Queries
;; are (source target) constraints; either side may contain schema variables.
;; The shared budget counts visited assignments AND structural comparisons. Search
;; never chooses the first of several solutions or generalizes observed values.
;; Only a unique complete search instantiates the prototype; callbacks are not
;; executed during candidate enumeration, and an exhausted search raises.
(def (infer-prototype scheme candidates queries (budget 8192))
  (def work (type-work budget))
  (def captured (prepare-prototype-type (.get scheme prototype) (.get scheme variables)
    (.get scheme expression) (.get scheme bounds) work (.get scheme bound-parameters)))
  (infer/checked captured candidates queries work))

;; The same finite solver accepts bounds on BOTH sides of a call constraint.
;; All callers pass one captured schema and one shared quota through construction.
(def (infer/checked scheme candidates queries work)
  (let ()
    (bounded-type-data candidates work)
    (require-value candidates list? (lambda () (refuse-type 'malformed "Type candidates must be a list")))
    (type-expression `(Tuple ,@candidates) [] work)
    (bounded-type-data queries work)
    (unless (and (list? queries) (andmap (lambda (query) (and (list? query) (= (length query) 2))) queries))
      (refuse-type 'malformed "Inference queries need actual/expected pairs"))
    (for-each (lambda (query)
                (type-expression (car query) (.get scheme variables) work)
                (type-expression (cadr query) (.get scheme variables) work)) queries)
    (let ((solutions []) (domain (map copy-type (delete-duplicates/hash candidates))))
      (let search ((variables (.get scheme variables)) (arguments []))
        (work)
        (if (pair? variables)
          (for-each (lambda (candidate) (search (cdr variables) (cons candidate arguments))) domain)
          (let* ((ordered (reverse arguments))
                 (substitution (map cons (.get scheme variables) ordered))
                 (constraints (append (.get scheme bounds) queries)))
            (when (try
                    (let (ground (substitute-type (.get scheme expression) substitution work))
                      (type-expression ground [] work)
                      (normalize-type ground work))
                    (andmap (lambda (bound)
                              (subtype/checked?
                                (substitute-type (car bound) substitution work)
                                (substitute-type (cadr bound) substitution work) work)) constraints)
                    (catch (cause)
                      (if (and (type-refusal? cause) (eq? (type-refusal-kind cause) 'bounds)) #f (raise cause))))
              (set! solutions (cons ordered solutions))))))
      (let* ((ordered (reverse solutions))
             (status (cond ((null? ordered) 'no-solution)
                           ((null? (cdr ordered)) 'unique) (else 'ambiguous)))
             (instance (and (eq? status 'unique) (instantiate/checked scheme (car ordered) work))))
        (.o bind-these: #f status: status solutions: ordered instance: instance)))))

;; Project raw Type positions to the EXISTING shape selector/argument normalizer.
;; These temporary objects are shape views, not new Types or dispatch certificates.
(def (signature-view term)
  (def options (function-options term))
  ;; Constructor defaults are literal metadata, never optional value expressions.
  (def (option name default) (cond ((assq name options) => cdr) (else default)))
  (.o bind-these: #f outputs: (cadr term) inputs: (caddr term)
    optional: (option optional: []) keywords: (option keywords: [])
    required-keywords: (option required-keywords: []) rest: (option rest: #f)))

;; One observation is (field-path supplied-Type-arguments expected-output-Types).
;; #f outputs means no return obligation; () requires zero user values. Reuse the
;; runtime's first structural clause and keyword escapes, without invoking bodies,
;; defaults or Type validators. An input contributes actual <: formal; an expected
;; output contributes formal <: expected, including nested Function variance.
(def (call-constraints scheme observation work)
  (unless (and (list? observation) (= (length observation) 3) (list? (cadr observation))
               (or (not (caddr observation)) (list? (caddr observation))))
    (refuse-type 'malformed "Call observation needs path, arguments and optional outputs" observation))
  (def term (function-expression (.get scheme expression) (car observation) work))
  (def clauses (map signature-view (if (eq? (car term) 'Function) (list term) (cdr term))))
  (def arguments (cadr observation))
  (def selected (signature.select-signature clauses arguments))
  (unless selected (refuse-type 'bounds "No declared case accepts the supplied call shape" observation))
  (def constraints [])
  (signature.normalize-arguments selected arguments
    (ormap (lambda (clause) (pair? (.get clause keywords))) clauses)
    (lambda (formal actual)
      (work)
      (type-expression actual [] work)
      (set! constraints (cons (list (copy-type actual) (copy-type formal)) constraints))
      actual))
  (def expected (caddr observation))
  (when expected
    (unless (= (length expected) (length (.get selected outputs)))
      (refuse-type 'bounds "Expected output count differs from the selected case" observation))
    (for-each (lambda (formal actual)
      (work)
      (type-expression actual [] work)
      (set! constraints (cons (list (copy-type formal) (copy-type actual)) constraints)))
      (.get selected outputs) expected))
  (reverse constraints))

;; Jointly infer one shared assignment from any finite collection of named calls.
;; Capture schema/observations before search; extraction, Cartesian enumeration,
;; subtype checks and successful construction consume the SAME request budget.
;; Unsupported paths/shapes refuse before a builder; inconsistent constraints are
;; no-solution, multiple assignments stay ambiguous, and exhaustion never admits.
(def (infer-prototype-calls scheme candidates observations (budget 8192))
  (def work (type-work budget))
  (def captured (prepare-prototype-type (.get scheme prototype) (.get scheme variables)
    (.get scheme expression) (.get scheme bounds) work (.get scheme bound-parameters)))
  (bounded-type-data observations work)
  (unless (list? observations) (refuse-type 'malformed "Call observations must form a list"))
  (def calls (map copy-type observations))
  (def constraints (apply append (map-in-order (cut call-constraints captured <> work) calls)))
  (def report (infer/checked captured candidates constraints work))
  (.cc report calls: calls queries: constraints))
