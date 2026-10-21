;;; Explicit bounded Self/Super polymorphism through existing FUN and contracts.
(export infer-tagged-worker-service infer-callback-directory-service infer-availability-service infer-plugin-service infer-retired-route-service infer-worker-service infer-measurement-service infer-handler-batch-service infer-single-handler-service infer-optional-handler-service infer-decision-service)
(export RetiredKeywordServiceType infer-retired-keyword-service)
(export TokenCallbackServiceType infer-token-callback-service)
(export shared-service-calls)
(export MetadataServiceType infer-metadata-service metadata-service-request)
(export infer-schema-service infer-type-value-service DescriptorServiceType infer-descriptor-service descriptor-service-action EmptyCallbackServiceType infer-empty-callback-service empty-callback-action scalar-union-service-type infer-scalar-service scalar-service-action BooleanServiceType infer-boolean-service boolean-service-action UnsignedUnionServiceType UnboundedUnionServiceType UnionServiceType EnumServiceType RangeServiceType infer-range-service TextServiceType infer-text-service text-service-action OptionalRoutingServiceType infer-optional-routing-service infer-signature-alias-service RecordServiceView infer-record-view-service CorrelatedRestCallback LiteralRestCallback RestCallbackServiceType LiteralCallbackServiceType infer-correlated-rest-service infer-literal-rest-service KeywordValueCallback infer-keyword-value-service KeywordPrefixCallback infer-keyword-prefix-service PositionalCallbackServiceType KeywordCallbackServiceType infer-positional-callback-service infer-keyword-callback-service CoveredServiceType infer-covered-service infer-shared-catalog-service catalog-service-action CatalogServiceType infer-catalog-service RecordServiceType record-service record-service-class infer-record-service record-service-action RoutingServiceType route-service routing-declarations infer-routing-service routing-service-action SharedServiceType report-service recover-service shared-service-declarations
        infer-shared-service shared-service-action invoke-signature-service invoke-report-service SignatureServiceType
        signature-service-declarations instantiate-signature-service infer-signature-service signature-service-action convert conversion-declarations instantiate-conversion infer-conversion conversion-action FunctionPrototypeType Service ServiceType service-action publish-service)
(import (only-in :std/list/list delete-duplicates/hash)
        (only-in ../function-signature encode-arguments) (only-in ../type Record) ../number ../type-relation ../object ../mop ../prototype-types ../object-contract ../object-contract-flow
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
;; Calls and prefix specialization use the same typed fragment builder for
;; numeric, text and Boolean services. Gerbil using checks host callbacks before
;; inference; no target or declaration builder executes before a unique solution.
(def (infer-signature-calls schema prefix candidates observations procedure (record void))
  (using ((procedure :~ procedure?) (record :~ procedure?))
    (infer-declared-calls (specialize-prototype-type schema prefix) candidates observations
      (cut signature-service-declarations <> procedure record))))
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

;; An open read view reorders fields and forgets internal limits/optional hooks.
;; The callback contract remains precise; no Any or runtime Type discovery is used.
(def RecordServiceView
  '(Record ((bias Integer optional) (run (Function (UInt) (Integer)) required)) open))
;; Prefix-bind Self, infer Super from one shared call/output obligation, then use
;; the original declaration builder and inherited Class initialization protocol.
(def (infer-record-view-service (record void))
  (infer-record-service '(UInt) '(UInt Integer)
    (list (list [] '(Integer) (list RecordServiceView))) record))

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
  (def publish (publication.publication-action contract signature-invocation context
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

;; A retired keyword has an impossible mandatory payload, while ordinary/rest
;; values remain live. The callback contract retains that original declaration;
;; finite coverage may remove only raw edges that cannot carry an actual value.
(def RetiredKeywordServiceType
  (prototype-type (.o .parameters: '(Value Callback)) '(Value Callback)
    '(Function (Value Callback) (Value))
    '((Callback (Function (Value) (Value)
      keywords: ((retired: . (Pair Never (Function (Value) (Value))))) rest: Value)))))
;; Reuse the same prefix solver, complete qualified builder and source guards.
;; Returned positional callbacks still acquire their original recursive wrapper;
;; keyword-language coverage neither executes them nor invents keyword defaults.
(def (infer-retired-keyword-service prefix candidates observations operation (record void))
  (infer-signature-calls RetiredKeywordServiceType prefix candidates observations operation record))

;; Optional token-valued callbacks retain real false/void data as well as escaped
;; keyword/marker values. Only their private raw origin view uses flat inclusion;
;; the original ordered descriptors own validation and the published metadata.
(def TokenCallbackServiceType
  (prototype-type (.o .parameters: '(Value Callback)) '(Value Callback)
    '(Function (Value Callback) (Value))
    '((Callback (Function (Value) ((OrFalse (Maybe (Or Keyword (Exactly #!rest)))))
      keywords: ((scale: . Value)) rest: Value)))))
;; Share complete candidate search, qualified declaration construction and the
;; existing FUN/refine/evidence action; no callback executes during inference.
(def (infer-token-callback-service prefix candidates observations operation (record void))
  (infer-signature-calls TokenCallbackServiceType prefix candidates observations operation record))

;; One schema combines literal field names, a disjoint row extension and nested
;; callback containers. Value/Tail specialize first; Callback is solved only after
;; their complete residual bound is known. Metadata transforms must not turn the
;; literal Value field or ready:/idle: tags into variable occurrences.
(def MetadataServiceType
  (prototype-type (.o .parameters: '(Value Tail Callback)) '(Value Tail Callback)
    '(Function (Value Callback) (Value))
    '((Callback (Function
      ((Object ((Value (Pair (List Value) (Map (Function (Value) (Integer)) <- UInt)))
                (state (OrFalse (Maybe (Sum ready: (Tuple (Function (Value) (Integer)))
                                           idle: (List (Function (Value) (Integer))))))))
        (Row Tail))) (Value))))))
;; Prepare the explicit prefix once; each returned request separately owns one
;; residual inference/installation quota. This closure caches no approval, method
;; result or admitted candidate. The public driver rechecks current metadata and
;; captures the caller's candidate/call lists on every attempt, including retries.
(def (metadata-service-request prefix candidates observations operation (record void))
  (using ((operation :~ procedure?) (record :~ procedure?))
    (let (residual (specialize-prototype-type MetadataServiceType prefix))
      (lambda (budget)
        (infer-declared-calls residual candidates observations
          (cut signature-service-declarations <> operation record) budget)))))
;; Ordinary construction uses the same prepared request and unchanged default
;; quota. The original body is not run to infer a Type; the resulting instance
;; still enters catalog-service-action's refine/bind-evidence/FUN publication.
(def (infer-metadata-service prefix candidates observations operation (record void))
  ((metadata-service-request prefix candidates observations operation record) 8192))

;; The candidate supplies the scalar and callback Types. Existing publication
;; checks both recursively, refines the normalized scalar, and binds exact
;; subject/descriptor/context evidence before IO. No result escapes on refusal.
(def (catalog-service-action instance input context consume (maximum 100))
  (signature-refinement-action instance input context consume
    (lambda (subject path)
      (if (<= (.get subject answer) maximum) []
        [(.o bind-these: #f kind: 'limit path: path)]))))

;; Each policy refines the same recursively checked answer/callback object.
;; Keep descriptor construction and FUN/IO/evidence publication in one chain.
(def (signature-refinement-action instance input context consume check)
  (using (check :~ procedure?)
    (def outputs (.get instance descriptor outputs))
    (signature-publication-action instance input context
      (refine (.cc ObjectContract. responsibilities:
        (.o answer: (car outputs) callback: (cadr outputs))) check) consume)))

;; Invariant invocation metadata belongs to this workflow, not each request.
;; Binding still constructs fresh subject/context relations and executes all
;; predicates/formulas; this private template stores no approval or result.
(def signature-invocation
  (metadata.contract (metadata.predicate "subject" object?)
    (metadata.predicate "evidence" object?) (lambda _ #t) metadata.truth))

;; Policies supply the descriptor; FUN approval, generic invocation, checked
;; publication and exact evidence binding are one shared numeric/text workflow.
;; User effects before a later refinement refusal are not rolled back.
(def (signature-publication-action instance input context contract consume)
  (def publish (publication.publication-action contract signature-invocation context
    (lambda (subject)
      (consume subject)
      (values (.o bind-these: #f subject: subject descriptor: contract context: context) context))))
  (.call observation.Observation. .bind
    (lambda (_)
      (unless (eq? (.get context approved) #t) (error "catalog approval refused"))
      (.get instance prototype))
    (lambda (receiver) (lambda (_)
      ;; Encode semantic inputs through the existing keyword transport protocol.
      ;; Keyword data must not become a keyword argument or an escape marker.
      (defvalues (answer callback _owner)
        (apply invoke-signature-service receiver
          (encode-arguments (list input) [] (pair? (.get instance descriptor keywords)))))
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


;; A fixed UInt case serves unchanged single-value calls; the optional Any case
;; serves every other spelling of the one-value, optional-scale keyword API.
;; This closes a finite raw language without declaring unbounded Any rest.
(def KeywordPrefixCallback
  '(CaseFunction (Function (UInt) (UInt))
    (Function (UInt) (Any Any) optional: (Any Any Any))))
;; Complete candidate inference rejects a mismatched first result before building
;; declarations, then publishes the real Gerbil case-lambda through existing FUN/IO.
(def (infer-keyword-prefix-service (record void))
  (infer-keyword-callback-service
    (list '(CaseFunction (Function (Bool) (UInt))
             (Function (UInt) (Any Any) optional: (Any Any Any))) KeywordPrefixCallback)
    (lambda (n)
      (values n (case-lambda ((value) (1+ value)) ((first second . rest) (+ 2 (length rest))))))
    record))

;; An Any-free raw callback language: values remain Integer, keyword/escape
;; markers are finite Enums, and the five-token endpoint has exact slot origins.
;; First-match case order keeps the typed endpoint ahead of the optional clause.
(def KeywordValueCallback
  '(CaseFunction (Function (UInt) (UInt))
    (Function (UInt) ((Enum scale: #!key) Integer (Enum scale: #!key) Integer (Exactly #!rest)))
    (Function (UInt) ((Union Integer (Enum scale: #!key #!rest))
                     (Union Integer (Enum scale: #!key #!rest)))
      optional: ((Union Integer (Enum scale: #!key #!rest))
                 (Union Integer (Enum scale: #!key #!rest))))))
;; Reuse residual parameter specialization, inference and typed declarations.
;; The bad five-token payload candidate is rejected before the builder executes.
;; The callback is genuinely Gerbil case-lambda; no unchecked forwarding shim.
(def (infer-keyword-value-service (record void))
  (infer-keyword-callback-service
    (list `(CaseFunction (Function (UInt) (UInt))
             (Function (UInt) ((Enum scale: #!key) Bool (Enum scale: #!key) Integer (Exactly #!rest)))
             ,(cadddr KeywordValueCallback)) KeywordValueCallback)
    (lambda (n)
      (values n (case-lambda ((value) (1+ value))
        ((first second . rest)
         (if (= (length rest) 3) (abs (+ second (cadr rest))) (+ 2 (length rest)))))))
    record))

;; Boolean keyword payloads may occur after a marker, never at the first raw slot.
;; The prefix excludes Bool while the infinite tail retains its proper origins.
(def CorrelatedRestCallback
  '(Function (UInt) ((Union Integer (Enum enabled: #!key #!rest)))
     rest: (Union Integer Bool (Enum enabled: #!key #!rest))))
;; A first positional rest-escape literal must be transported as data. It cannot
;; be an ordinary decoder step; the second raw slot is a literal or key payload.
(def LiteralRestCallback
  '(Function (UInt) ((Enum scale: #!key #!rest) (Union Integer (Exactly #!rest)))
     rest: (Union Integer Keyword (Enum #!key #!rest))))
;; Preserve the existing Value/Callback parameter and service declaration layout.
;; Only the callback's explicitly declared call language changes to an infinite tail.
(def RestCallbackServiceType
  (prototype-type (.o .parameters: '(Value Callback)) '(Value Callback)
    '(Function (Value Callback) (Value))
    '((Callback (Function (Value) (Value) keywords: ((enabled: . Bool)) rest: Value)))))
;; Literal metadata survives prefix specialization unchanged; rest values still
;; use the original Value parameter rather than a guessed universal carrier.
(def LiteralCallbackServiceType
  (prototype-type (.o .parameters: '(Value Callback)) '(Value Callback)
    '(Function (Value Callback) (Value))
    '((Callback (Function (Value) ((Exactly #!rest)) keywords: ((scale: . Value)) rest: Value)))))
;; Complete unique inference rejects a missing Boolean tail before building the
;; existing sibling declarations. FUN/refine/bind-evidence consume the same instance.
(def (infer-correlated-rest-service (record void))
  (infer-declared-calls (specialize-prototype-type RestCallbackServiceType '(UInt))
    (list '(Function (UInt) ((Union Integer (Enum enabled: #!key #!rest)))
             rest: (Union Integer (Enum enabled: #!key #!rest))) CorrelatedRestCallback)
    '((() (UInt) (UInt (Function (UInt) (UInt) keywords: ((enabled: . Bool)) rest: UInt))))
    (cut signature-service-declarations <> (lambda (n) (values n (lambda arguments (length arguments)))) record)))
;; A competing candidate cannot omit rest escape from its first marker set. Both
;; infinite input families enter the original unified declaration builder intact.
(def (infer-literal-rest-service (record void))
  (infer-declared-calls (specialize-prototype-type LiteralCallbackServiceType '(UInt))
    (list '(Function (UInt) ((Enum scale: #!key) (Union Integer (Exactly #!rest)))
             rest: (Union Integer Keyword (Enum #!key #!rest))) LiteralRestCallback)
    '((() (UInt) (UInt (Function (UInt) ((Exactly #!rest)) keywords: ((scale: . UInt)) rest: UInt))))
    (cut signature-service-declarations <> (lambda (n) (values n (lambda arguments (length arguments)))) record)))

;; Two spellings describe one rich callback after a Value prefix is fixed. The
;; original joint solver must merge only metadata aliases before declaring once.
;; Missing optional values remain absent until the Gerbil target applies defaults.
(def (infer-signature-alias-service (record void))
  (infer-positional-callback-service
    '((Function (Bool) (UInt))
      (Function (UInt) (UInt) optional: (UInt) keywords: ((scale: . UInt)) rest: UInt)
      (Function (UInt) (UInt) rest: UInt required-keywords: () keywords: ((scale: . UInt)) optional: (UInt)))
    (lambda (n)
      (values n (lambda (value (bonus n) scale: (scale 1) . rest)
        (* scale (+ value bonus (apply + rest)))))) record))

;; False route entries and a void/false fallback retain distinct absence protocols.
;; Invariant Key is fixed once; nested Function Types share Self <: Super with
;; the original route method, Class/data validators and complete publication chain.
(def OptionalRoutingServiceType
  (prototype-type (.o .parameters: '(Key Self Super)) '(Key Self Super)
    '(Function ((Pair (Map (OrFalse (Function (Self) (Super))) <- Key)
                      (Maybe (OrFalse (Function (Self) (Super))))))
               ((Map (OrFalse (Function (Self) (Super))) <- Key)))
    '((Self Super))))
;; Use existing route fragments, qualifiers and FUN action; no parallel optional
;; validator, optional dispatcher or declaration builder is introduced here.
(def (infer-optional-routing-service prefix candidates observations (record void))
  (using (record :~ procedure?)
    (infer-declared-calls (specialize-prototype-type OptionalRoutingServiceType prefix)
      candidates observations (cut routing-declarations <> record))))

;; Text conversion uses unrelated scalar families, not a manufactured numeric
;; subtype. Prefix-bound Label and residual Value are constrained by whole calls.
(def TextServiceType
  (prototype-type (.o .parameters: '(Label Value)) '(Label Value)
    '(Function (Value (Function (Value) (Label))) (Label)) []))
;; Reuse the complete existing typed fragment builder; Gerbil owns symbol/string
;; primitives and using owns observer admission. Inference never runs the target.
(def (infer-text-service prefix candidates observations (record void))
  (infer-signature-calls TextServiceType prefix candidates observations
    (lambda (label) (values (symbol->string label) symbol->string)) record))
;; The same shared publication chain admits a nonempty String and its recursively
;; wrapped callback; refinement refusal runs no consumer and publishes no evidence.
(def (text-service-action instance label context consume)
  (signature-refinement-action instance label context consume
    (lambda (subject path)
      (if (positive? (string-length (.get subject answer))) []
        [(.o bind-these: #f kind: 'empty-text path: path)]))))

;; Reuse the original rich signature and parameter template, strengthening only
;; Super's declared bound. Inclusive endpoints are literal Type metadata.
(def RangeServiceType
  (prototype-type (.get SignatureServiceType prototype) (.get SignatureServiceType variables)
    (.get SignatureServiceType expression)
    (append (.get SignatureServiceType bounds) '((Super (IntegerRange min: 0 max: 100))))))
;; Original fragments own qualifiers, negative checks and the generic cache.
;; The host owns defaults; every supplied input and both user results pass the
;; existing Function wrapper before the shared numeric publication policy.
(def (infer-range-service prefix candidates observations (record void) schema: (schema RangeServiceType))
  (infer-signature-calls schema prefix candidates observations
    (lambda (value (bonus 0) scale: (scale 1) . rest)
      (def clamp (lambda (value) (max 0 (min 10 value))))
      (values (clamp (* scale (+ value bonus (apply + rest)))) clamp)) record))

;; The same rich service can require a finite output/argument alphabet without
;; replacing the range descriptor selected by inference or its wrapper protocol.
(def EnumServiceType
  (prototype-type (.get SignatureServiceType prototype) (.get SignatureServiceType variables)
    (.get SignatureServiceType expression)
    (append (.get SignatureServiceType bounds) '((Super (Enum 10 0 9 1 8 2 7 3 6 4 5))))))

;; Joint coverage constrains the same Super parameter without flattening the
;; public descriptor. Nested alternatives retain their declared branch order.
(def UnionServiceType
  (prototype-type (.get SignatureServiceType prototype) (.get SignatureServiceType variables)
    (.get SignatureServiceType expression)
    (append (.get SignatureServiceType bounds)
      '((Super (Union (IntegerRange min: 7 max: 10)
                      (Union (Enum 5 6) (IntegerRange min: 0 max: 4))))))))

;; An unbounded input alphabet is covered jointly by two infinite tails and a
;; finite bridge. Keep the original optional/keyword/rest declaration factory,
;; bounded Self results, callback wrapping and FUN publication policy unchanged.
(def UnboundedUnionServiceType
  (prototype-type (.get SignatureServiceType prototype) (.get SignatureServiceType variables)
    (.get SignatureServiceType expression)
    (append (.get SignatureServiceType bounds)
      '((Super (Union (IntegerRange min: 1)
                      (Union (Enum 0) (IntegerRange max: -1))))))))

;; UInt uses the same declaration, wrapper and FUN publication chain as Integer.
;; This ordered bound covers zero separately from the unbounded positive tail;
;; negative inputs remain inadmissible even though Self has bounded outputs.
(def UnsignedUnionServiceType
  (prototype-type (.get SignatureServiceType prototype) (.get SignatureServiceType variables)
    (.get SignatureServiceType expression)
    (append (.get SignatureServiceType bounds)
      '((Super (Union (IntegerRange min: 1) (Enum 0)))))))

;; Both Boolean values must be covered by the original ordered alternatives;
;; the duplicate true branch deliberately retains observable declaration order.
(def BooleanServiceType
  (prototype-type (.get SignatureServiceType prototype) (.get SignatureServiceType variables)
    (.get SignatureServiceType expression)
    (append (.get SignatureServiceType bounds)
      '((Super (Union (Exactly #t) (Union (Enum #f) (Exactly #t))))))))
;; Reuse the complete call/declaration factory. The wrapper checks optional,
;; keyword and rest inputs; higher-order aggregation preserves Boolean results
;; and returns the existing identity callback for recursive Function wrapping.
(def (infer-boolean-service prefix candidates observations (record void))
  (infer-signature-calls BooleanServiceType prefix candidates observations
    (lambda (value (bonus #f) scale: (scale 1) . rest)
      (values (and (positive? scale) (or value bonus (ormap identity rest))) identity)) record))
;; A policy can approve false just as precisely as true. Refinement occurs
;; before the shared FUN/IO consumer and binds evidence to the exact context.
(def (boolean-service-action instance input context consume (required #t))
  (using (required :~ boolean?)
    (signature-refinement-action instance input context consume
      (lambda (subject path)
        (if (eq? (.get subject answer) required) []
          [(.o bind-these: #f kind: 'boolean-policy path: path)])))))

;; Infinite scalar domains need their complete intrinsic family in the ordered
;; flat bound. Earlier finite/token alternatives retain their original order;
;; neither family conversion nor a universal fallback is inferred.
(def (scalar-union-service-type family)
  (using (family :~ (cut memq <> '(String Symbol Keyword)))
    (prototype-type (.get SignatureServiceType prototype) (.get SignatureServiceType variables)
      (.get SignatureServiceType expression)
      (append (.get SignatureServiceType bounds)
        `((Super (Union (Enum report ready: #!key #!rest) (Union ,family Bool))))))))
;; The rich host signature gives a missing bonus the already checked input's
;; value. Supplied optional/keyword/rest arguments pass the existing wrapper;
;; identity results and callbacks reuse the same declaration factory.
(def (infer-scalar-service family prefix candidates observations (record void))
  (infer-signature-calls (scalar-union-service-type family) prefix candidates observations
    (lambda (value (bonus value) scale: (scale 1) . rest)
      (values value identity)) record))
;; Policy equality refines the shared object contract before its IO consumer.
;; The common publication action owns raw keyword encoding and context evidence.
(def (scalar-service-action instance input context consume (required input))
  (signature-refinement-action instance input context consume
    (lambda (subject path)
      (if (equal? (.get subject answer) required) []
        [(.o bind-these: #f kind: 'scalar-policy path: path)]))))

;; A disabled capability has an impossible mandatory payload, not a permissive
;; callback input. Value is prefix-bound; only a witnessed empty Dead candidate
;; can satisfy Dead <: String while retaining its original structured descriptor.
(def EmptyCallbackServiceType
  (prototype-type (.o .parameters: '(Value Dead)) '(Value Dead)
    '(Function (Value (Function (Value) (Dead))) (Value)) '((Dead String))))
;; Reuse the complete qualified declaration builder and existing using checks.
;; The host callback is returned and recursively wrapped, never invoked by inference.
(def (infer-empty-callback-service prefix candidates observations procedure (record void))
  (infer-signature-calls EmptyCallbackServiceType prefix candidates observations procedure record))
;; Publication uses the same refinement/evidence chain as the other services.
;; A negative policy can refuse after method effects, before consumer admission.
(def (empty-callback-action instance input context consume (allowed? #t))
  (signature-refinement-action instance input context consume
    (lambda (_subject path)
      (if allowed? [] [(.o bind-these: #f kind: 'disabled path: path)]))))

;; Prefix-bound data/callback inputs and candidate outputs retain descriptor kinds.
;; The same schema handles singleton, fixed integer and byte-buffer services.
;; In particular an impossible-element List batch can return nil into an
;; intrinsic Null/Bool/Keyword Union without erasing its original List artifact.
;; Fixed-width metadata is literal, never evaluated as a prototype parameter.
(def DescriptorServiceType
  (prototype-type (.o .parameters: '(Input Output)) '(Input Output)
    '(Function (Output (Function (Output) (Input))) (Input)) '((Output Input))))
;; Reuse the existing whole qualified builder, host contracts and complete solve.
;; The caller supplies the host operation; returned callbacks are checked later.
(def (infer-descriptor-service prefix candidates observations procedure (record void))
  (infer-signature-calls DescriptorServiceType prefix candidates observations procedure record))
;; Reuse FUN approval, recursive result wrapping, refinement and exact evidence.
;; A policy failure occurs after method effects and before consumer admission.
(def (descriptor-service-action instance input context consume (allowed? #t))
  (signature-refinement-action instance input context consume
    (lambda (_subject path)
      (if allowed? [] [(.o bind-these: #f kind: 'descriptor-policy path: path)]))))

;; A heterogeneous typed-value input and uniquely inferred output use the same
;; qualified declaration, recursive callback, FUN/refine/evidence chain. Catalog
;; compilation is fresh per request, so prior descriptor edits cannot be approvals.
(def (infer-type-value-service candidates observations procedure (record void))
  (infer-signature-calls DescriptorServiceType '((TypeValuePair UInt Bool String))
    candidates observations procedure record))

;; Require a nonempty batch of checked handlers while accepting empty input.
;; Pair/List inclusion feeds the existing shared solver and complete qualified
;; declaration; both produced handlers and the returned batch callback are wrapped.
;; Publication reuses descriptor-service-action, including refine and evidence.
(def (infer-handler-batch-service candidates procedure (record void))
  (def handler '(Function (UInt) (Integer)))
  (def input (list 'List handler))
  (def output (list 'Pair handler input))
  (infer-descriptor-service (list input) candidates
    (list (list [] (list input) (list output `(Function (,output) (,input)))))
    procedure record))

;; A singleton handler pipeline accepts and returns exactly one checked handler.
;; Candidate Pair tails may use List of a witnessed empty payload Type; inference
;; must prove that tail is Null rather than discard it or coerce a vector.
;; Reuse the qualified declaration and descriptor-service-action publication.
(def (infer-single-handler-service candidates procedure (record void))
  (def handler '(Function (UInt) (Integer)))
  (def input (list 'Pair handler 'Null))
  (infer-descriptor-service (list input) candidates
    (list (list [] (list input) (list input `(Function (,input) (,input)))))
    procedure record))

;; One optional handler schema accepts void/false or a proper batch of callbacks.
;; Candidates may retain either nesting order or lift a concrete batch payload;
;; the shared solver proves both sentinel obligations before method installation.
;; Existing descriptor-service-action owns refinement and exact FUN/IO evidence.
(def (infer-optional-handler-service candidates procedure (record void))
  (def batch '(List (Function (UInt) (Integer))))
  (def input (list 'Maybe (list 'OrFalse batch)))
  (infer-descriptor-service (list input) candidates
    (list (list [] (list input) (list input `(Function (,input) (,input)))))
    procedure record))

;; A decision packet retains its checked handler, Boolean decision and void ack.
;; Candidate metadata may use OrFalse/Maybe fields, but both source branches must
;; satisfy the concrete Bool/Unit fields before the complete declaration is built.
;; Existing descriptor-service-action publishes refined, exact FUN/IO evidence.
(def (infer-decision-service candidates procedure (record void))
  (def input '(Pair (Function (UInt) (Integer)) (Pair Bool Unit)))
  (infer-descriptor-service (list input) candidates
    (list (list [] (list input) (list input `(Function (,input) (,input)))))
    procedure record))

;; Capture dynamic Class/Schema selection once, then feed exact snapshot tokens
;; into the existing qualified declaration and FUN/refine/evidence publication.
;; The producer converts typed payloads explicitly; inclusion never changes tags.
(def (infer-schema-service provider names selected procedure (record void) sources: (sources []))
  (unless (and (list? names) (symbol? selected) (memq selected names))
    (error "selected Schema must name a finite catalog entry"))
  (def directory (capture-type-catalog provider names sources: sources))
  (def types (delete-duplicates/hash (map cdr directory) table: (make-hash-table-eq) from-end?: #t))
  (def input (cons 'TypeValuePair types))
  (def output (list 'TypeValuePair (agetq selected directory)))
  (def observations (list (list [] (list input) (list output `(Function (,output) (,input))))))
  (.cc (infer-descriptor-service (list input)
         (map (lambda (type) (list 'TypeValuePair type)) types)
         observations procedure record)
    catalog: directory))

;; Retain the checked callback and UInt-indexed measurement table. Every original
;; numeric/Boolean Union branch must fit its ordinary Pair field before the shared
;; complete inference, qualified declarations and FUN/refine/evidence publication.
(def (infer-measurement-service candidates procedure (record void))
  (def input '(Pair (Function (UInt) (Integer)) (Map (Pair Integer Bool) <- UInt)))
  (infer-descriptor-service (list input) candidates
    (list (list [] (list input) (list input `(Function (,input) (,input)))))
    procedure record))

;; A structural worker interface consumes inherited Record values without a cast.
;; Candidate outputs retain Class optional slots and their original metadata;
;; ordered Record/Object alternatives must ALL satisfy this one readable view.
;; Their source validators keep first selection, recursive wrappers and errors;
;; complete inference checks every named field before qualified publication.
;; Closure is a checked interface policy, not a runtime projection: sealed
;; consumers may forget only fields whose optional payload is proved impossible.
(def (infer-worker-service candidates procedure (record void) closed?: (closed? #f))
  (using (closed? :~ boolean?)
    (def input `(Object ((run (Function (UInt) (Integer))) (limit Integer)
      (jobs (Map (List (Function (UInt) (Integer))) <- UInt))) ,(if closed? 'closed 'open)))
    (infer-descriptor-service (list input) candidates
      (list (list [] (list input) (list input `(Function (,input) (,input)))))
      procedure record)))

;; Publish a sealed plugin directory using one explicit intrinsic name or captured
;; Type token. The existing dependent checker retains that Type and wraps payloads;
;; complete candidate inference may prove retired optional catalogs impossible.
(def (infer-plugin-service tag candidates procedure (record void))
  (def input `(Object ((plugins (Map (TypeValuePair ,tag) <- UInt)) (limit Integer)) closed))
  (infer-descriptor-service (list input) candidates
    (list (list [] (list input) (list input `(Function (,input) (,input)))))
    procedure record))

;; Publish a callback-bearing route packet whose retired table is necessarily
;; empty. Complete inference retains the original key/value declarations, while
;; the shared Map rule permits a different consumer layout only from a witness.
;; Existing qualified declarations and descriptor-service-action own publication.
(def (infer-retired-route-service candidates procedure (record void))
  (def handler '(Function (UInt) (Integer)))
  (def input `(Pair ,handler (Map ,handler <- UInt)))
  (infer-descriptor-service (list input) candidates
    (list (list [] (list input) (list input `(Function (,input) (,input)))))
    procedure record))

;; Publish an availability packet with a live handler and a tagged service state.
;; Ready states preserve void/false or an exact captured dependent Type; idle
;; states preserve false or checked handler batches. Original alternative layouts
;; are solved together before existing declarations and FUN/evidence publication.
;; The common syntax checker owns finite directory admission and shared budgets.
(def (infer-availability-service tags candidates procedure (record void))
  (def handler '(Function (UInt) (Integer)))
  (def directory (cons 'TypeValuePair tags))
  (def input `(Pair ,handler (Sum ready: (Maybe (OrFalse ,directory))
                                idle: (OrFalse (List ,handler)))))
  (infer-descriptor-service (list input) candidates
    (list (list [] (list input) (list input `(Function (,input) (,input)))))
    procedure record))

;; Publish one directory of overloaded callbacks and a fallback callback vector.
;; Or's first actual member and Union's first structural branch keep their own
;; selection discipline. Every callable alternative implements the same one/two
;; argument interface before the existing whole declaration and FUN/refine/
;; bind-evidence chain runs. Validation retains first-selected Function wrappers;
;; neither a later branch nor a retry can repair a failed checked callback call.
(def (infer-callback-directory-service candidates procedure (record void))
  (def callback '(CaseFunction (Function (UInt) (Integer))
                               (Function (UInt UInt) (Integer Integer))))
  (def input `(Pair (Map (List ,callback) <- UInt) (Tuple ,callback)))
  (infer-descriptor-service (list input) candidates
    (list (list [] (list input) (list input `(Function (,input) (,input)))))
    procedure record))

;; Publish heterogeneous tagged workers through one readable object interface.
;; Sum owns tag dispatch and recursive wrapping; the existing whole solve and
;; declaration/refine/evidence chain checks each inhabited variant against the
;; open tag/value view. Retired variants need a positive impossible-payload witness;
;; their original metadata and runtime refusal remain. No codec cast is implied.
(def (infer-tagged-worker-service candidates procedure (record void))
  (def worker '(Object ((tag (Enum primary backup))
                       (value (Function (UInt) (Integer)))) open))
  (def input `(Pair (Map (List ,worker) <- UInt) (Function (UInt) (Integer))))
  (infer-descriptor-service (list input) candidates
    (list (list [] (list input) (list input `(Function (,input) (,input)))))
    procedure record))

;; A whole report/recovery batch constrains one residual Super after Self binding.
;; The report uses optional, keyword and rest positions and returns a recursively
;; wrapped callback; recovery selects the first existing CaseFunction clause.
;; Consumers pass these observations to infer-shared-service, then publish through
;; shared-service-action's Reader/FUN approval and checked output continuation.
(def shared-service-calls
  '(((.report) (Integer Integer scale: UInt Integer)
       (UInt (Function (UInt) (Integer))))
    ((.recover) (UInt) (Integer))))
