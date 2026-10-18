;;; Explicit bounded Self/Super polymorphism through existing FUN and contracts.
(export PositionalCallbackServiceType KeywordCallbackServiceType infer-positional-callback-service infer-keyword-callback-service CoveredServiceType infer-covered-service infer-shared-catalog-service catalog-service-action CatalogServiceType infer-catalog-service RecordServiceType record-service record-service-class infer-record-service record-service-action RoutingServiceType route-service routing-declarations infer-routing-service routing-service-action SharedServiceType report-service recover-service shared-service-declarations
        infer-shared-service shared-service-action invoke-signature-service invoke-report-service SignatureServiceType
        signature-service-declarations instantiate-signature-service infer-signature-service signature-service-action convert conversion-declarations instantiate-conversion infer-conversion conversion-action FunctionPrototypeType Service ServiceType service-action publish-service)
(import (only-in ../type Record) ../number ../type-relation ../object ../mop ../prototype-types ../object-contract ../object-contract-flow
        (prefix-in ../declarative-metadata metadata.) ../method-declaration
        (prefix-in ../generalized-prototype observation.)
        (prefix-in ./contract-publication publication.)
        (prefix-in ../multimethod dispatch.) (prefix-in ../dispatch-extension extension.)
        (prefix-in ../method-combination combination.))

;; Ordinary prototype parameters remain Type descriptors. Computed inherited
;; methods bind to the specialized receiver, with no new metaclass or registry.
(def Service (.o self: receiver .parameters: '(Self Super)
  (operation (lambda (value) (validate (.get receiver Self) (abs (validate (.get receiver Super) value)))))))
;; Appendix Self <: Super bounds specialize to the existing Function constructor.
;; Inputs may be broader than the return type (e.g. Integer input, UInt output).
(def ServiceType
  (prototype-type Service '(Self Super) '(Function (Self) (Super)) '((Self Super))))

;; The appendix Proto A B has signature A <- A B with A <: B. Here A/B
;; themselves are Function descriptors; existing wrappers check both nested calls.
(def FunctionPrototype (.o .parameters: '(Self Super)
  (combine (lambda (_self super) (lambda (value) (abs (super (abs value))))))))
;; Universals are explicit outer prototype parameters; there is no impredicative
;; runtime inference and the prototype does not force a recursive self eagerly.
(def FunctionPrototypeType
  (prototype-type FunctionPrototype '(Self Super)
    '(Function (Self) (Self Super)) '((Self Super))))

;; Admit the inferred Function, recursively wrap it as a field, then add a whole
;; service obligation. The Reader/FUN consumer receives only the normalized value.
(def (service-action instance maximum consume)
  (let* ((signature (.get instance descriptor))
         (shape (.cc ObjectContract. responsibilities: (.o operation: signature limit: signature)))
         (contract (refine shape
           (lambda (value path)
             (if (<= ((.get value operation) -3) maximum) []
               (list (.o bind-these: #f kind: 'service-limit path: path)))))))
    (checked-action contract consume)))

;; Bind exact subject/signature/revision references before the existing publisher.
;; A stale identity fails logic and preserves old state; this function performs no
;; caching and creates no new approval authority.
(def (publish-service instance subject context evidence old-state)
  (let* ((invocation (metadata.contract
                      (metadata.predicate "subject" object?)
                      (metadata.predicate "evidence" object?)
                      (lambda (_atom _input _output) #t) metadata.truth))
         (bound (metadata.bind-evidence invocation subject (.get instance descriptor) context identity)))
    (metadata.publish bound old-state (lambda (_) (values evidence subject)) subject)))

;; One statically bound generic keeps Gerbil formal binding and both result/cache
;; values; its method slot was installed only after complete type specialization.
(.defgeneric (convert service value) slot: .convert combination: invoke-declared)
;; Turn the checked instance's ground Function into the existing typed dispatcher.
;; Multiple fragments share one signature; inherited operations still read the
;; specialized Self/Super fields. The preparer is the established standard policy.
(def (conversion-declarations record instance)
  (def certified (instance-signature instance (lambda (_) [['Number]])
    [(extension.shape [['Blocked]])] standard-combination combination.standard-contribution?
    (lambda (methods) (combination.prepare-standard methods (lambda (_) (error "missing conversion"))))))
  (def path [(dispatch.prototype 'Number)])
  (def operation (.get instance prototype operation))
  [(typed-method-fragment '.convert certified
     [(metadata.replace "convert" path (combination.primary (lambda (_ value) (record 'primary) (operation value))))])
   (typed-method-fragment '.convert certified
     [(metadata.contribute "audit" path (combination.before (lambda (_) (record 'before))))
      (metadata.contribute "observe" path (combination.after (lambda (_) (record 'after))))])])
;; Explicit ground substitution and declaration installation use the same entry.
;; The builder is a normal higher-order callback, not a second declaration DSL.
(def (instantiate-conversion schema arguments record)
  (instantiate-declared schema arguments (cut conversion-declarations record <>)))
;; A ground prefix leaves a checked residual schema; exhaustive inference of the
;; remaining parameters must be uniquely complete before any builder is invoked.
(def (infer-conversion schema prefix candidates queries record (budget 8192))
  (infer-declared (specialize-prototype-type schema prefix budget) candidates queries
    (cut conversion-declarations record <>) budget))
;; FUN sequences current approval, the installed generic and the IO consumer.
;; A rejected context or bad argument has no method/consumer effects; successful
;; invocation retains the complete cache successor as the second returned value.
(def (conversion-action instance value consume)
  (.call observation.Observation. .bind
    (lambda (context)
      (unless (eq? (.get context approved) #t) (error "conversion approval refused"))
      (.get instance prototype))
    (lambda (receiver) (lambda (_context)
      (defvalues (answer next) (convert receiver value))
      (consume answer)
      (values answer next)))))

;; The same rank-one schema now has optional/rest/keyword input positions and two
;; outputs, one itself a checked callback. Literal keyword names are not variables.
(def SignatureServiceType
  (prototype-type (.o .parameters: '(Self Super)) '(Self Super)
    '(Function (Self (Function (Self) (Super))) (Super)
       optional: (Super) keywords: ((scale: . UInt)) required-keywords: () rest: Super)
    '((Self Super))))
;; Rest-only generic forwarding leaves optional defaults in the target procedure.
;; Returned user values precede the complete immutable declaration/cache successor.
(.defgeneric (invoke-signature-service service . arguments) slot: .invoke combination: invoke-declared)
;; Core optional/keyword binding resolves these defaults before constructing the
;; declared argument row; the method then receives each supplied value once.
(.defgeneric (invoke-report-service service value (bonus 0) scale: (scale 1) . rest)
  slot: .invoke combination: invoke-declared)
;; A whole qualified declaration group shares one inferred signature and existing
;; standard preparer. No method executes until a shape/type-checked call succeeds.
(def (signature-service-declarations instance procedure record)
  (def certified (instance-signature instance (lambda (_) [['Service]]) []
    standard-combination combination.standard-contribution?
    (lambda (methods) (combination.prepare-standard methods (lambda (_) (error "missing service"))))
    8192 1))
  (def path [(dispatch.prototype 'Service)])
  [(typed-method-fragment '.invoke certified
    [(metadata.replace "service" path
       (combination.primary (lambda (_next . arguments) (apply procedure arguments))))
     (metadata.contribute "audit-before" path (combination.before (lambda _ (record 'before))))
     (metadata.contribute "audit-after" path (combination.after (lambda _ (record 'after))))
     (metadata.contribute "audit-around" path
       (combination.around (lambda (next . _arguments) (record 'around) (next))))])])
;; Explicit complete binding uses the same declaration stream as residual inference.
(def (instantiate-signature-service schema arguments procedure (record void))
  (instantiate-declared schema arguments (cut signature-service-declarations <> procedure record)))
;; Specialize an ordered prefix, then exhaust the finite residual candidate set;
;; ambiguous/failed inference cannot call the builder or install a partial generic.
(def (infer-signature-service schema prefix candidates queries procedure (record void))
  (infer-declared (specialize-prototype-type schema prefix) candidates queries
    (cut signature-service-declarations <> procedure record)))
;; FUN supplies current approval; IO consumes both checked user outputs once. A
;; rejected call transfers neither partial outputs nor a cache successor to IO.
(def (signature-service-action instance arguments consume)
  (.call observation.Observation. .bind
    (lambda (context)
      (unless (eq? (.get context approved) #t) (error "signature service approval refused"))
      (.get instance prototype))
    (lambda (receiver) (lambda (_context)
      (defvalues (answer callback next) (apply invoke-signature-service receiver arguments))
      (consume answer callback)
      (values answer callback next)))))

;; The existing Object row grammar is a named catalog of callable signatures.
;; Both generics share the SAME bound descriptors and Self <: Super obligation.
(def SharedServiceType
  (prototype-type (.o .parameters: '(Self Super) service-name: 'shared) '(Self Super)
    '(Object
      ((.report (Function (Self (Function (Self) (Super))) (Super)
                   optional: (Super) keywords: ((scale: . Self)) rest: Super))
       (.recover (CaseFunction (Function (Super) (Self)) (Function (Super Super) (Self Self)))))
      closed)
    '((Self Super))))
;; Core formal binding supplies report defaults; the named catalog describes user
;; outputs only. invoke-declared always retains the separate trailing cache owner.
(.defgeneric (report-service service value (extra 0) scale: (scale 1) . rest)
  slot: .report combination: invoke-declared)
;; The same rest-forwarding entry admits every ordered case without custom macros.
(.defgeneric (recover-service service . arguments) slot: .recover combination: invoke-declared)
;; Install every named group under one receiver admission. These ordinary method
;; fragments reuse typed dispatch, completed negative checks and standard qualifiers.
(def (shared-service-declarations instance report recover (record void))
  ;; Field paths select existing explicit Object fields after complete substitution.
  (def (certified name)
    (instance-signature instance (lambda (_) [['Service]]) [(extension.shape [['Blocked]])]
      standard-combination combination.standard-contribution?
      (lambda (methods) (combination.prepare-standard methods (lambda (_) (error "missing shared service"))))
      8192 1 (list name)))
  (def path [(dispatch.prototype 'Service)])
  [(typed-method-fragment '.report (certified '.report)
    [(metadata.replace "report" path (combination.primary (lambda (_next . args) (apply report args))))
     (metadata.contribute "report-audit" path (combination.before (lambda _ (record 'report))))])
   (typed-method-fragment '.recover (certified '.recover)
    [(metadata.replace "recover" path (combination.primary (lambda (_next . args) (apply recover args))))
     (metadata.contribute "recover-audit" path (combination.before (lambda _ (record 'recover))))])])
;; Observe several named calls before any builder runs. One residual assignment
;; must satisfy all input and expected-output constraints plus the original bounds.
(def (infer-shared-service prefix candidates observations report recover (record void))
  (infer-declared-calls (specialize-prototype-type SharedServiceType prefix) candidates observations
    (cut shared-service-declarations <> report recover record)))
;; Reader/FUN approval precedes both generics; IO observes only their completed
;; checked user values. Each evolving cache owner remains an explicit result.
(def (shared-service-action instance value consume)
  (.call observation.Observation. .bind
    (lambda (context)
      (unless (eq? (.get context approved) #t) (error "shared service approval refused"))
      (.get instance prototype))
    (lambda (receiver) (lambda (_context)
      (defvalues (answer callback report-owner) (report-service receiver value 1 scale: 2))
      (defvalues (recovered recovery-owner) (recover-service receiver answer))
      (consume answer recovered callback)
      (values answer recovered report-owner recovery-owner)))))

;; Pair/Map/Sum/Union Type positions share Self/Super with the existing typed
;; declaration driver. Union branches stay literal and ordered during inference.
(def RoutingServiceType
  (prototype-type (.o .parameters: '(Key Self Super)) '(Key Self Super)
    '(Function ((Pair (Map (Sum active: (Function (Self) (Super)) count: Self) <- Key)
                       (Union (Function (UInt) (Integer)) Bool)))
               ((Map (Sum active: (Function (Self) (Super)) count: Self) <- Key)))
    '((Self Super))))
;; Gerbil owns argument forwarding; the user result and cache owner stay explicit.
(.defgeneric (route-service service routes) slot: .route combination: invoke-declared)
;; One prepared standard group retains existing qualifier and negative-watch
;; semantics while the signature recursively wraps the returned route callbacks.
(def (routing-declarations instance record)
  (def certified (instance-signature instance (lambda (_) [['Routes]]) []
    standard-combination combination.standard-contribution?
    (lambda (methods) (combination.prepare-standard methods (lambda (_) (error "missing routing method"))))))
  (def path [(dispatch.prototype 'Routes)])
  [(typed-method-fragment '.route certified
    [(metadata.replace "routes" path
       (combination.primary (lambda (_next routes) (cons routes abs))))
     (metadata.contribute "audit" path (combination.before (lambda (_) (record 'routes))))])])
;; Fix the invariant key prefix, then derive the remaining inequalities from an
;; observed call and expected output. No callback executes during candidate search.
(def (infer-routing-service prefix candidates observations (record void))
  (infer-declared-calls (specialize-prototype-type RoutingServiceType prefix) candidates observations
    (cut routing-declarations <> record)))
;; FUN checks current approval, invokes the declared method, refines its fully
;; wrapped result and binds exact subject/descriptor/context evidence before IO.
(def (routing-service-action instance routes context consume)
  (def signature (.get instance descriptor))
  (def output (car (.get signature outputs)))
  (def checked-output (refine (.cc ObjectContract. responsibilities: (.o routes: output))
    (lambda (candidate path)
      (if (positive? (hash-length (car (.get candidate routes)))) []
        [(.o bind-these: #f kind: 'empty-routes path: path)]))))
  (.call observation.Observation. .bind
    (lambda (_)
      (unless (eq? (.get context approved) #t) (error "routing approval refused"))
      (.get instance prototype))
    (lambda (receiver) (lambda (_)
      (defvalues (answer next) (route-service receiver routes))
      (def normalized (validate checked-output (.o routes: answer)))
      (def invocation (metadata.contract (metadata.predicate "subject" object?)
        (metadata.predicate "evidence" object?) (lambda _ #t) metadata.truth))
      (def bound (metadata.bind-evidence invocation normalized checked-output context identity))
      (metadata.publish bound context
        (lambda (subject)
          (consume (.get subject routes))
          (values (.o bind-these: #f subject: subject descriptor: checked-output context: context)
                  (.cc context owner: next))) normalized)))))

;; Required/optional metadata is finite Type syntax. Initialization callbacks are
;; deliberately absent: existing Class/Slot descriptors own those computations.
(def RecordServiceType
  (prototype-type (.o .parameters: '(Self Super)) '(Self Super)
    '(Function ((Record ((run (Function (Self) (Super)) required)
                         (limit UInt required) (bias UInt required)
                         (extra (Function (Self) (Super)) optional)) open)) (Super))
    '((Self Super))))
;; Gerbil binds one supplied input; all returned record fields pass through the
;; inferred Class validator before the ordinary result/cache pair can escape.
(.defgeneric (record-service service value) slot: .invoke combination: invoke-declared)
;; Multiple inheritance and child overrides are supplied to the existing Record
;; constructor. The checked hook receives wrapped computed fields and is checked
;; again; the inferred output descriptor subsequently validates the returned object.
(def (record-service-class instance record)
  (def output (car (.get instance descriptor outputs)))
  (def transform (.get output effective-slots run type))
  (def base (Record run: [transform default: abs] limit: [UInt default: 10]))
  (def limits (Record bias: [UInt default: 2]))
  (.cc (Record [base limits]
         run: [transform compute: (lambda (self _next) (lambda (n) (+ (.get self bias) (abs n))))])
    .instantiate: (lambda (checked) (record 'hook) checked)))
;; Type search and declaration installation finish before a Class is constructed.
;; The host callbacks remain under the same ordinary error and resource discipline.
(def (infer-record-service prefix candidates observations (record void))
  (infer-declared-calls (specialize-prototype-type RecordServiceType prefix) candidates observations
    (lambda (instance)
      (def descriptor (record-service-class instance record))
      (signature-service-declarations instance
        (lambda (_input) (make-instance descriptor)) record))))

;; FUN sequences current approval and the declared factory. The existing checked
;; publication combines recursive Class wrapping, whole-object refinement and
;; exact evidence binding before IO consumes the normalized record. Hook effects
;; are not rolled back if a later refinement refuses publication.
(def (record-service-action instance input context consume (maximum 20))
  (def output (car (.get instance descriptor outputs)))
  (def contract (refine (.cc ObjectContract. responsibilities: (.o processor: output))
    (lambda (candidate location)
      (if (<= (.get candidate processor limit) maximum) []
        [(.o bind-these: #f kind: 'record-limit path: location)]))))
  (def invocation (metadata.contract (metadata.predicate "subject" object?)
    (metadata.predicate "evidence" object?) (lambda _ #t) metadata.truth))
  (def publish (publication.publication-action contract invocation context
    (lambda (subject)
      (consume (.get subject processor))
      (values (.o bind-these: #f subject: subject descriptor: contract context: context) context))))
  (.call observation.Observation. .bind
    (lambda (_)
      (unless (eq? (.get context approved) #t) (error "record approval refused"))
      (.get instance prototype))
    (lambda (receiver) (lambda (_)
      (defvalues (answer _owner) (record-service receiver input))
      (publish (.o processor: answer))))))

;; The outer parameter is itself a finite candidate signature, rather than a
;; preselected Function skeleton. Existing inference determines its kind, call
;; language and nested callback result before any method declaration is built.
(def CatalogServiceType
  (prototype-type (.o .parameters: '(Signature)) '(Signature) 'Signature []))
;; Reuse the existing standard fragment/factory protocol and original source
;; guards. A callback result demonstrates recursive wrapping before FUN/refine
;; and exact bind-evidence publication; no callback runs during candidate search.
(def (infer-catalog-service candidates observations procedure (record void))
  (infer-declared-calls CatalogServiceType candidates observations
    (cut signature-service-declarations <> procedure record)))

;; The candidate supplies the scalar and callback Types. Existing publication
;; checks both recursively, refines the normalized scalar, and binds exact
;; subject/descriptor/context evidence before IO. No result escapes on refusal.
(def (catalog-service-action instance input context consume)
  (def outputs (.get instance descriptor outputs))
  (def contract (refine (.cc ObjectContract. responsibilities:
    (.o answer: (car outputs) callback: (cadr outputs)))
    (lambda (subject path)
      (if (<= (.get subject answer) 100) []
        [(.o bind-these: #f kind: 'limit path: path)]))))
  (def invocation (metadata.contract (metadata.predicate "subject" object?)
    (metadata.predicate "evidence" object?) (lambda _ #t) metadata.truth))
  (def publish (publication.publication-action contract invocation context
    (lambda (subject)
      (consume subject)
      (values (.o bind-these: #f subject: subject descriptor: contract context: context) context))))
  (.call observation.Observation. .bind
    (lambda (_)
      (unless (eq? (.get context approved) #t) (error "catalog approval refused"))
      (.get instance prototype))
    (lambda (receiver) (lambda (_)
      (defvalues (answer callback _owner) (invoke-signature-service receiver input))
      (publish (.o bind-these: #f answer: answer callback: callback))))))

;; Whole-catalog candidates can add or omit fields. Reuse the two existing
;; typed fragment factories; final admission still demands every required method,
;; including siblings absent from the observed calls. No inferred method appears
;; merely because a caller requested its path.
(def (infer-shared-catalog-service candidates observations report recover (record void))
  (infer-declared-calls CatalogServiceType candidates observations
    (cut shared-service-declarations <> report recover record)))

;; The required callback language contains two disjoint arities. The finite
;; candidate may use optional/rest or differently ordered cases to cover it.
;; Value is fixed through existing prefix specialization before callback inference.
(def CoveredServiceType
  (prototype-type (.o .parameters: '(Value Callback)) '(Value Callback)
    '(Function (Value Callback) (Value))
    '((Callback (CaseFunction (Function (Value) (Value)) (Function (Value) (Value Value)))))))
;; Callback coverage, call observations, source guards and full method admission
;; share one existing solver/builder chain. Bodies remain deferred until invocation.
(def (infer-covered-service candidates procedure (record void))
  (infer-declared-calls (specialize-prototype-type CoveredServiceType '(UInt)) candidates
    '((() (UInt) (UInt (CaseFunction (Function (UInt) (UInt)) (Function (UInt) (UInt UInt))))))
    (cut signature-service-declarations <> procedure record)))

;; Callers require an ordinary callback. A candidate may expose optional keywords
;; when every required caller input remains an outer-token-stable Type.
(def PositionalCallbackServiceType
  (prototype-type (.o .parameters: '(Value Callback)) '(Value Callback)
    '(Function (Value Callback) (Value)) '((Callback (Function (Value) (Value))))))
;; Reuse existing prefix binding, joint call inference and qualified declarations.
;; The callback's own keyword defaults remain deferred until actual invocation.
(def (infer-positional-callback-service candidates procedure (record void))
  (infer-declared-calls (specialize-prototype-type PositionalCallbackServiceType '(UInt)) candidates
    '((() (UInt) (UInt (Function (UInt) (UInt)))))
    (cut signature-service-declarations <> procedure record)))
;; A keyword caller may use a positional raw-row transport. Required arity is
;; checked against every decoded target minimum, not its normalized escape row.
(def KeywordCallbackServiceType
  (prototype-type (.o .parameters: '(Value Callback)) '(Value Callback)
    '(Function (Value Callback) (Value))
    '((Callback (Function (Value) (Value) keywords: ((scale: . Value)))))))
;; Existing construction preserves the callback's raw row through FUN/refinement
;; and exact evidence publication; no translation wrapper or secondary registry.
(def (infer-keyword-callback-service candidates procedure (record void))
  (infer-declared-calls (specialize-prototype-type KeywordCallbackServiceType '(UInt)) candidates
    '((() (UInt) (UInt (Function (UInt) (UInt) keywords: ((scale: . UInt))))))
    (cut signature-service-declarations <> procedure record)))
