;;; Nonlocal method fragments use ordinary Slot metadata and inherited computation.
(export MethodDeclaration. method-fragment standard-combination simple-combination
        forwarding-combination inner-combination simula-combination
        typed-method-fragment invoke-declared declared-snapshot
        instantiate-declared infer-declared infer-declared-calls instance-signature)
(import :std/iter (only-in :std/list/list foldr) (only-in :std/list/alist aremq) ./object ./mop ./declaration
        (only-in ./reflection reflect-slots)
        (only-in ./prototype-types instantiate-prototype infer-prototype infer-prototype-calls bound-parameters)
        (prefix-in ./parameters positional.)
        (only-in ./type-relation type-work bounded-type-data type-expression normalize-type compile-expression function-expression copy-type refuse-type)
        (prefix-in ./multimethod dispatch.)
        (prefix-in ./method-combination combination.)
        (prefix-in ./declarative-metadata metadata.) (prefix-in ./dispatch-extension extension.))
;; A private marker distinguishes method metadata from arbitrary user Slot fields.
;; Public descriptors remain extensible POO objects; no second declaration AST exists.
(def method-marker (list 'method-fragment))
;; Admit the whole finite group before calling any method body. In particular a
;; mismatched generic combination cannot silently discard another policy's qualifiers.
(def (admit-contributions accept contributions)
  (unless (and (procedure? accept) (list? contributions) (andmap accept contributions))
    (error "invalid method contribution group"))
  contributions)
;; A compiled group retains the exact certified seed, its declaration source and
;; immutable cache owner. It is private transport, not another declaration AST.
(defstruct declared-methods (signature declarations certificate source) final: #t)
;; Return only the existing dispatch certificate for explicit revision/publication.
(def (declared-snapshot group)
  (def source (declared-methods-source group))
  (def certificate (begin (check-signature-source! source) (force (declared-methods-certificate group))))
  ;; A cold promise may execute deferred edit-compilation hooks. Recheck after
  ;; successful forcing before exposing that certificate, including at construction.
  (check-signature-source! source)
  certificate)
;; Invoke the established typed dispatcher. Transfer the complete cache successor
;; only after success; do not mutate the receiver or cache approval/body results.
(def (invoke-declared group arguments)
  (def current (declared-snapshot group))
  (defvalues (result next) (apply extension.invoke current arguments))
  (def successor (begin
    (check-signature-source! (declared-methods-source group))
    (if (eq? next current) group
      (make-declared-methods (declared-methods-signature group)
        (declared-methods-declarations group) (delay next) (declared-methods-source group)))))
  (if (dispatch.function-signature (extension.snapshot next))
    (apply values (append result (list successor)))
    (values result successor)))
;; Read the optional signature without treating a stored false as an absent field.
;; A signature is an existing negative-watch certificate, shared by identity.
(def (method-signature metadata)
  (if (.has? metadata signature)
    (let (signature (.@ metadata signature))
      (unless (extension.certificate? signature) (error "invalid declared generic signature")) signature)
    #f))
;; Assemble inherited declaration data; Gerbil promises publish the COMPLETE
;; candidate once, when demanded. Parent groups remain unforced until the whole
;; inherited source is assembled, before checking the completed candidate.
;; Apply ancestor edits before local edits: a derived replacement wins at its
;; path, while each explicit batch keeps existing contribute/register order.
;; Registration and negative failures propagate with their existing phase/cause;
;; no partially installed certificate escapes and no method body runs at construction.
(def (compile-declared signature local parent)
  (unless (or (null? parent)
              (and (declared-methods? parent) (eq? signature (declared-methods-signature parent))))
    (error "inherited generic signature conflicts"))
  (def declarations (append (if (null? parent) [] (declared-methods-declarations parent)) local))
  (make-declared-methods signature declarations
    (delay (let-values (((certificate failure)
                        (extension.publish signature (map metadata.compile declarations))))
      (when failure (raise failure)) certificate))
    (declared-source signature)))
;; Each compiled Slot combines its local source-ordered block with the SAME
;; final receiver's delayed inherited group. Slot metadata edits recompile normally.
(def (method-slot name metadata)
  (def descriptor (.o (:: @ (instance Slot))
    (method-fragment method-marker)
    (signature (method-signature metadata))
    (contributions (.@ metadata contributions))
    (admit (if (.has? metadata admit) (.@ metadata admit) combination.standard-contribution?))
    (hidden (let (hidden? (if (.has? metadata hidden) (.@ metadata hidden) #f))
      (unless (boolean? hidden?) (error "method visibility must be Boolean")) hidden?))
    (compute (lambda (self inherited)
      (let* ((local (admit-contributions (.@ @ admit) (.@ @ contributions)))
            (parent (try (inherited)
              (catch (NoApplicableMethod? cause)
                (if (and (eq? (NoApplicableMethod-self cause) self) (eq? (NoApplicableMethod-slot cause) name))
                  [] (raise cause))))))
        (if (.@ @ signature)
          (begin
            (unless (eq? (.@ @ admit) metadata.declaration?) (error "typed generic requires method declarations"))
            (for-each (lambda (declaration) (depend-on-object! @ declaration)) local)
            (compile-declared (.@ @ signature) local parent))
          (begin (unless (list? parent) (error "inherited method slot is not a fragment list"))
            (append local parent))))))))
  (depend-on-object! descriptor metadata)
  (admit-contributions (.@ descriptor admit) (.@ descriptor contributions))
  (when (.@ descriptor signature)
    (unless (eq? (.@ descriptor admit) metadata.declaration?) (error "typed generic requires method declarations"))
    (for-each (lambda (declaration) (depend-on-object! descriptor declaration)) (.@ descriptor contributions)))
  descriptor)
;; Recognize only this protocol's method descriptors, never similarly named records.
(def (method-slot? descriptor)
  (and (object? descriptor) (.has? descriptor method-fragment)
       (eq? (.@ descriptor method-fragment) method-marker)))
;; Combine duplicate method names in first-occurrence order. Ordinary slot collisions,
;; mixed policies or conflicting visibility refuse before receiver construction.
;; The fold accumulator has distinct keys: standard aremq therefore removes its
;; only previous entry, preserving all unrelated pairs and their relative order.
(def (merge-method-fragments entries)
  (foldr (lambda (entry rest)
    (def previous (assq (car entry) rest))
    (if (not previous) (cons entry rest)
      (let ((left (cdr entry)) (right (cdr previous)))
        (unless (and (method-slot? left) (method-slot? right)
                     (eq? (.@ left admit) (.@ right admit))
                     (eq? (.@ left hidden) (.@ right hidden))
                     (eq? (.@ left signature) (.@ right signature)))
          (error "conflicting declaration fragments" (car entry)))
        (def metadata (.o
          (contributions (append (.@ left contributions) (.@ right contributions)))
          (admit (begin (unless (eq? (.@ left admit) (.@ right admit)) (error "revised method policies conflict"))
            (.@ left admit)))
          (hidden (begin (unless (eq? (.@ left hidden) (.@ right hidden)) (error "revised method visibility conflicts"))
            (.@ left hidden)))))
        (depend-on-object! metadata left) (depend-on-object! metadata right)
        (when (.@ left signature)
          (.setslot! metadata signature ($computed-slot-spec (lambda (_self _inherited)
            (unless (eq? (.@ left signature) (.@ right signature)) (error "revised generic signatures conflict"))
            (.@ left signature)))))
        (cons (cons (car entry) (method-slot (car entry) metadata))
          (aremq (car entry) rest))))) [] entries))
;; The SAME .declare syntax expands public/private record slots and method groups.
;; Other kinds use inherited expansion; inherited finalization still sees all groups.
(define-type (MethodDeclaration. @ Declaration.)
  (expand-declaration (inherited) (lambda (context form)
    (if (eq? (.@ form kind) 'method)
      (let (metadata (.@ form descriptor))
        [(cons (.@ form name) (method-slot (.@ form name) metadata))])
      ((inherited) context form))))
  (finalize-declarations (inherited) (lambda (context entries)
    ((inherited) context (merge-method-fragments entries)))))
;; Runtime/computed method names enter the same declaration protocol as static forms.
(def (method-fragment name contributions (accept combination.standard-contribution?) (hidden? #f))
  (declaration-form 'method name
    (object<-alist (list (cons 'contributions contributions) (cons 'admit accept) (cons 'hidden hidden?)))))
;; Typed declarations enter the SAME method form, merge/finalize and inherited
;; Slot path. The existing certified seed owns types, policy, C4 and watches.
;; Keep it shared across compatible fragments; a fresh certificate is a new signature.
(def (typed-method-fragment name certified declarations (hidden? #f))
  (unless (extension.certificate? certified) (error "invalid declared generic signature"))
  (declaration-form 'method name (.o
    (signature certified) (contributions declarations) (admit metadata.declaration?) (hidden hidden?))))
;; Standard, simple, forwarding, inner and Simula adapters all reuse existing
;; interpreters. They are functions suitable for .defgeneric's combination: option.
(def (standard-combination parts arguments)
  (combination.effective (admit-contributions combination.standard-contribution? parts) arguments
    (lambda (_) (error "no primary method"))))
;; Custom simple policies retain their existing short-circuit/failure semantics.
(def (simple-combination policy)
  (lambda (parts arguments)
    (combination.simple-effective policy (admit-contributions combination.simple-contribution? parts) arguments)))
;; Forwarding validates every replacement payload through the supplied Type.
(def (forwarding-combination payload-type)
  (lambda (parts arguments)
    (combination.forward-effective (admit-contributions combination.forward-contribution? parts) arguments
      (lambda (_) (error "no forwarding primary method")) (cut validate payload-type <>))))
;; Inner bodies use their existing next-thunk calling convention and terminal.
(def (inner-combination terminal)
  (lambda (parts arguments)
    (combination.inner-chain (admit-contributions procedure? parts) arguments terminal)))
;; Simula descriptors keep superclass-first prefixes and reverse suffix unwinding.
(def (simula-combination parts arguments)
  (combination.simula-effective (admit-contributions combination.simula-body? parts) arguments))

;; Private source stamp binds the checked field expression/path to its exact
;; compiled Function descriptor and direct revision. This is factory provenance,
;; not a proof of arbitrary Type callbacks or transitive global metadata stability.
(defstruct signature-origin (expression path descriptor revision) final: #t)
;; Read a factory stamp once while assembling a group. Runtime owners retain
;; that exact private record, so public metadata replacement cannot forge it.
(def (declared-source signature)
  (def descriptor (dispatch.function-signature (extension.snapshot signature)))
  (def source (and descriptor (.has? descriptor .declaration-source) (.get descriptor .declaration-source)))
  (when (signature-origin? source)
    (unless (eq? descriptor (signature-origin-descriptor source))
      (refuse-type 'bounds "Signature source names a different descriptor")))
  (and (signature-origin? source) source))
;; Direct revision checks surround successful invocation and snapshot access.
;; Failure returns no result/cache successor; callback effects are not rolled back.
;; Transitive Type/global callback stability remains an explicit model premise.
(def (check-signature-source! source)
  (when source
    (unless (= (object-revision (signature-origin-descriptor source)) (signature-origin-revision source))
      (refuse-type 'bounds "Declared Function descriptor was revised" (signature-origin-path source)))))
;; Extend the newly compiled Type through the existing MOP before publishing it.
;; Its lazy source slot captures one private stamp AFTER the supported edit, so
;; the exact final descriptor/revision is known and clones cannot borrow identity.
(def (signature-descriptor descriptor expression path)
  (def origin #f)
  (.setslot! descriptor .declaration-source ($computed-slot-spec (lambda (_self _inherited) origin)))
  (set! origin (make-signature-origin (copy-type expression) (map identity path)
                 descriptor (object-revision descriptor)))
  descriptor)
;; Recompile the checked finite Function/CaseFunction expression. Required,
;; optional, keyword, rest and exact output rows use the existing validator;
;; clause order remains observable. Dispatch axes are fixed independently of
;; variable call length (default: first clause's required positional count).
(def (instance-signature instance precedence watches
       (combine standard-combination) (accept combination.standard-contribution?) (prepare #f) (budget 8192) (arity #f) (path []))
  (def work (type-work budget))
  (def expression (.get instance expression))
  (type-expression expression [] work)
  (def ground (function-expression (normalize-type expression work) path work))
  (def descriptor (signature-descriptor (compile-expression ground work) ground path))
  (def first (car (.get descriptor signatures)))
  (def axes (or arity (length (.get first inputs))))
  (def seed (dispatch.make-function descriptor precedence combine axes accept))
  (extension.check (if prepare (dispatch.prepared seed prepare) seed) watches))

;; Only explicit Object paths ending at Function/CaseFunction are declaration
;; requirements. Other data Types remain under ordinary contract validation; their
;; computed values are not forced by method installation.
(def (signature-catalog? term work)
  (work)
  (and (pair? term)
    (case (car term)
      ((Function CaseFunction) #t)
      ((Object) (ormap (lambda (field) (signature-catalog? (cadr field) work)) (cadr term)))
      (else #f))))
;; Admit EVERY required named method, not only groups the builder chose to return.
;; Source/path/descriptor/revision mismatch refuses before publication. Nested
;; carriers reuse object construction guards; finite syntax/work bounds the walk.
(def (admit-signatures instance receiver captured-expression captured-bindings (budget 8192))
  (def work (type-work budget))
  (def expression (.get instance expression))
  (type-expression expression [] work)
  (def bindings (.get instance bound-parameters))
  (bounded-type-data bindings work)
  (unless (and (equal? expression captured-expression) (equal? bindings captured-bindings))
    (refuse-type 'bounds "Declaration builder changed captured type metadata"))
  (def catalog (normalize-type expression work))
  (when (and (pair? catalog) (memq (car catalog) '(Function CaseFunction)))
    (let (found? #f)
      (for (entry (reflect-slots receiver include-hidden?: #t))
        (def slot (cdr entry))
        (when (and (method-slot? slot) (.@ slot signature))
          (let* ((group (.ref receiver (car entry))) (origin (declared-methods-source group)))
            (when origin
              (unless (and (null? (signature-origin-path origin))
                           (equal? (signature-origin-expression origin) catalog))
                (refuse-type 'bounds "Root declared signature differs from its captured expression" (car entry)))
              (set! found? #t)))))
      (unless found? (refuse-type 'bounds "No typed method implements the root Function signature"))))
  (when (and (pair? catalog) (eq? (car catalog) 'Object))
    (let walk ((term catalog) (owner receiver) (path []))
      (work)
      (unless (object? owner) (refuse-type 'bounds "Named signature carrier must be an Object" path))
      (instantiate-object! owner)
      (parameterize ((active-object-constructions (cons owner (active-object-constructions))))
        (for-each (lambda (field)
          (when (signature-catalog? (cadr field) work)
            (let* ((name (car field)) (location (append path (list name))))
            (unless (.slot? owner name) (refuse-type 'bounds "Missing declared signature" location))
            (def value (.ref owner name))
            (if (eq? (car (cadr field)) 'Object)
              (walk (cadr field) value location)
              (begin
                (unless (declared-methods? value) (refuse-type 'bounds "Signature field needs a typed method group" location))
                (let* ((snapshot (extension.snapshot (declared-snapshot value)))
                       (descriptor (dispatch.function-signature snapshot))
                       (origin (declared-methods-source value)))
                  (unless (and (signature-origin? origin)
                    (equal? (signature-origin-path origin) location)
                    (equal? (signature-origin-expression origin) (cadr field))
                    (eq? (signature-origin-descriptor origin) descriptor)
                    (= (signature-origin-revision origin) (object-revision descriptor)))
                    (refuse-type 'bounds "Declared signature source changed or differs from its catalog" location))))))))
          (cadr term)))))
  receiver)

;; Build from an already complete specialization under existing construction
;; guards. Freeze its receiver/context during the builder, normal declaration
;; elaboration and typed installation. Force typed groups only, including hidden
;; ones; unrelated ordinary/computed slots stay lazy. Errors return no published
;; instance; arbitrary earlier callback effects are not rolled back.
(def (declare-instance instance build)
  (using (build :~ procedure?)
    (def source (.get instance prototype))
    (instantiate-object! source)
    (parameterize ((active-object-constructions
                    (cons instance (cons source (active-object-constructions)))))
      (def source-work (type-work 8192))
      (def expression (.get instance expression))
      (type-expression expression [] source-work)
      ;; Record describes Class DATA callbacks, including optional absence and
      ;; initialization. It is valid in Function inputs/results; a method-group
      ;; interface must use the existing explicit Object catalog instead.
      (let (root (normalize-type expression source-work))
        (when (and (pair? root) (eq? (car root) 'Record))
          (refuse-type 'unsupported "Record value contract is not an Object method catalog")))
      (def bound-names (bound-parameters instance))
      (def bindings (.get instance bound-parameters))
      (bounded-type-data bindings source-work)
      (def captured-expression (copy-type expression))
      (def captured-bindings (copy-type bindings))
      (def forms (build instance))
      (def entries (expand-declarations MethodDeclaration. instance forms))
      (when (ormap (lambda (entry) (or (eq? (car entry) '.parameters) (memq (car entry) bound-names))) entries)
        (refuse-type 'bounds "Declarations cannot replace bound type parameters"))
      (def receiver (object<-expanded-declarations instance entries supers: [source]))
      (instantiate-object! receiver)
      (parameterize ((active-object-constructions (cons receiver (active-object-constructions))))
        (for (entry (reflect-slots receiver include-hidden?: #t))
          (def descriptor (cdr entry))
          (when (and (method-slot? descriptor) (.@ descriptor signature))
            (declared-snapshot (.ref receiver (car entry)))))
        (unless (null? (positional.parameters receiver))
          (refuse-type 'bounds "Declarations reopened positional parameters"))
        (def published (.cc instance prototype: receiver))
        (bound-parameters published)
        (admit-signatures published receiver captured-expression captured-bindings)
        published))))

;; Complete explicit binding precedes all declaration builders and installation.
;; Existing type refusal and declaration failure objects propagate unchanged.
(def (instantiate-declared scheme arguments build (budget 8192))
  (using (build :~ procedure?)
    (declare-instance (instantiate-prototype scheme arguments budget) build)))

;; The existing bounded exhaustive search owns classification. Ambiguous/no-solution
;; reports are returned untouched, without calling build. Only a unique complete
;; assignment enters guarded declaration elaboration and typed installation.
(def (infer-declared scheme candidates queries build (budget 8192))
  (using (build :~ procedure?)
    (def report (infer-prototype scheme candidates queries budget))
    (if (eq? (.get report status) 'unique)
      (.cc report instance: (declare-instance (.get report instance) build)) report)))

;; Joint call constraints feed the SAME uniquely completed inference/declaration
;; driver. The whole receiver's typed groups must install before any instance is
;; returned; a failed sibling group exposes no partially declared receiver.
(def (infer-declared-calls scheme candidates observations build (budget 8192))
  (using (build :~ procedure?)
    (def report (infer-prototype-calls scheme candidates observations budget))
    (if (eq? (.get report status) 'unique)
      (.cc report instance: (declare-instance (.get report instance) build)) report)))
