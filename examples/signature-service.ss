;;; Seeded service checks combine nested callbacks, optional and keyword defaults.
(export RetiredCallServiceType retired-call-target retired-call-view retired-call-callback retired-call-action staged-service-action catalog-service-type checked-operation-action callback-service-action specialized-action selected-declarations selected-action Callback ServiceSignature service checked-service service-property service-tests)
(import ../object
        ../mop
        ../type
        ../number
        ../testing/function
        ../testing/type
        (only-in ../types/relation expression-type)
        (only-in ../prototype-types prototype-type specialize-prototype-type)
        ../method-declaration
        ../declaration
        ../object-contract
        (runtime: :clan/poo/multimethod)
        (prefix-in (only-in ../multimethod prototype) dispatch.)
        (runtime: :clan/poo/method-combination)
        (prefix-in (only-in ../method-combination primary standard-contribution?) combination.)
        (runtime: :clan/poo/declarative-metadata)
        (prefix-in (only-in ../declarative-metadata contract predicate replace truth) metadata.)
        (runtime: :clan/poo/generalized-prototype)
        (prefix-in (only-in ../generalized-prototype Observation.) observation.)
        (prefix-in ./contract-publication publication.)
        (runtime: :clan/poo/examples/polymorphic-services)
        (prefix-in (only-in ./polymorphic-services DescriptorServiceType
                   descriptor-service-action signature-request-action
                   signature-service-declarations) service.))

;; Function values require explicit semantic generation: arbitrary procedures
;; cannot be synthesized from recognition alone. This fixture generates identity.
(def Callback
  (.o self: callback inherit: [(Function [Integer] [Integer])]
      .generator: (lambda () (make-generator callback
        (lambda (_random _size) identity) (lambda (_value) []) (lambda (_value) 0)
        dependencies: [Integer]))))
;; The container's callbacks acquire recursive wrappers before target execution.
(def ServiceSignature
  (Function [Integer] [Integer] optional: [(List Callback)]
            keywords: (list (cons scale: Integer) (cons offset: Integer))))
;; Omitted callbacks and keywords retain the host's ordinary default semantics.
(def (service value (callbacks []) scale: (scale 1) offset: (offset 0))
  (+ (* scale (foldl (lambda (callback result) (callback result)) value callbacks)) offset))
;; The same descriptor used for generated calls also checks actual invocations.
(def checked-service (validate ServiceSignature service))
;; Compare wrapped calls against the original at every generated supplied shape.
(def (service-property arguments)
  (= (apply checked-service arguments) (apply service arguments)))
;; One Reader/FUN chain runs the property and passes its report to an IO consumer.
(def (service-tests consume)
  (property-action (FunctionArguments ServiceSignature) service-property consume))

;; Compile both explicit Object methods through the same finite declaration
;; factory. The caller may reuse the run-path buffer while computed parameters
;; are refreshed: its ORIGINAL field selection must own the resulting signature.
;; No method body runs while this nested catalog is assembled/admitted.
(def (selected-declarations instance run-path operation)
  (using (operation :~ procedure?)
    ;; Share the established typed fragment/standard combination pipeline.
    (def (fragment name path body)
      (def signature (instance-signature instance (lambda (_) [['Service]]) []
        standard-combination combination.standard-contribution? #f 8192 1 path))
      (typed-method-fragment name signature
        [(metadata.replace (symbol->string name) [(dispatch.prototype 'Service)]
          (combination.primary (lambda (_next value) (body value))))]))
    (def api (object<-declaration-forms MethodDeclaration. instance
      [(fragment 'run run-path operation) (fragment 'audit '(api audit) not)]))
    [(declaration-form 'public 'api (.o (constant api)))]))

;; FUN sequences current approval and both installed methods. Refine checks the
;; whole result after recursive callback wrapping, then the existing publisher
;; binds exact subject/descriptor/context evidence before the IO consumer.
;; Body effects before a later policy refusal are observable, never rolled back.
(def (selected-action instance input context consume (maximum 20))
  (def contract (refine (.cc ObjectContract. responsibilities:
    (.o answer: UInt callback: Callback audit: Bool))
    (lambda (subject location)
      (if (<= (.get subject answer) maximum) []
        [(.o bind-these: #f kind: 'service-limit path: location)]))))
  (def invocation (metadata.contract (metadata.predicate "subject" object?)
    (metadata.predicate "evidence" object?) (lambda _ #t) metadata.truth))
  (def publish (publication.publication-action contract invocation context
    (lambda (subject)
      (consume subject)
      (values (.o bind-these: #f subject: subject descriptor: contract context: context) context))))
  (.call observation.Observation. .bind
    (lambda (_)
      (unless (eq? (.get context approved) #t) (error "service approval refused"))
      (.get instance prototype api))
    (lambda (api) (lambda (_)
      (defvalues (answer callback _run-owner) (invoke-declared (.get api run) (list input)))
      (defvalues (audit _audit-owner) (invoke-declared (.get api audit) [#f]))
      (publish (.o bind-these: #f answer: answer callback: callback audit: audit))))))

;; Prepare one persistent Type prefix, infer the remaining shared assignment
;; from Reader-supplied constraints, then reuse the whole qualified declaration
;; and descriptor/refine/evidence/IO chain. This application requires a unique
;; result; an ambiguous/no-solution report is retained as the error irritant,
;; never coerced to a Type or sent to a method/consumer. Source effects before
;; refusal are observable; retry uses a fresh request after repairing metadata.
(def (specialized-action schema prefix candidates requests operation input context consume (allowed? #t))
  (.call observation.Observation. .bind
    (service.signature-request-action schema prefix candidates requests operation)
    (lambda (report)
      (unless (eq? (.get report status) 'unique)
        (error "service request requires unique type inference" report))
      (service.descriptor-service-action (.get report instance) input context consume allowed?))))

;; A residual DescriptorServiceType retains its already bound Input Function.
;; Two finite inequalities select an equivalent Output without guessing Types.
;; Reuse the whole declaration/refine/evidence/FUN/IO chain. Stale retained
;; descriptors require a fresh residual; revision counters are never reset.
(def (callback-service-action residual target candidates operation input context consume (allowed? #t))
  (specialized-action residual [] candidates
    (lambda (_context) `((Output ,target) (,target Output)))
    operation input context consume allowed?))

;; Compile an explicit boundary contract before preparing the inferred service.
;; Live directory observers may edit the caller's syntax during admission; the
;; public compiler owns its complete input first. Reuse recursive Function
;; wrapping, the existing declaration factory and its refine/evidence/FUN/IO chain.
(def (checked-operation-action expression schema prefix candidates requests operation input context consume (allowed? #t))
  (def checked (validate (expression-type expression) operation))
  (specialized-action schema prefix candidates requests checked input context consume allowed?))

;; Policy is retained configuration Type metadata, independently of the callable
;; Input/Output signature. It must stay current even after prefix substitution
;; removes it from the remaining inference problem. No approval is cached here.
(def CatalogServiceType
  (prototype-type (.o .parameters: '(Policy Input Output)) '(Policy Input Output)
    (.get service.DescriptorServiceType expression) (.get service.DescriptorServiceType bounds)))
;; Bind an explicit catalog token and input through the ordinary prefix factory.
;; Callers reuse specialized-action for inference/declarations/FUN publication;
;; revised directories require recapture and a fresh residual, never reset stamps.
(def (catalog-service-type policy input)
  (specialize-prototype-type CatalogServiceType (list policy input)))

;; Stage explicit external metadata during the existing declaration callback.
;; Even candidate/query directories absent from the selected callable signature
;; must remain current until the whole solve/build returns. Reuse Reader/FUN,
;; qualified methods and the original refine/evidence/IO service consumer.
(def (staged-service-action residual candidates queries operation stage input context consume (allowed? #t))
  (.call observation.Observation. .bind
    (lambda (_context)
      (infer-declared residual candidates queries
        (lambda (instance)
          (stage instance)
          (service.signature-service-declarations instance operation void))))
    (lambda (report)
      (unless (eq? (.get report status) 'unique)
        (error "staged service requires unique type inference" report))
      (service.descriptor-service-action (.get report instance) input context consume allowed?))))

;; Reserved callback positions remain structurally declared but cannot be invoked:
;; the one-argument clause has an impossible product, and optional/rest extensions
;; must supply Never before reaching rest. Zero and two inputs remain live.
(def (retired-call-target value)
  `(CaseFunction (Function (,value) ())
    (Function (String) ((Pair Never (Function (,value) (,value)))))
    (Function (,value) (,value ,value) optional: (Never) rest: ,value)))
;; Nested handler tables and refresh results share the exact same callback Type.
;; The directory remains a closed readable object, not a projection or codec cast.
(def (retired-call-view value callback)
  `(Object ((handlers (Map ,callback <- UInt)) (refresh (Function (,callback) (,value)))) closed))
;; Value is specialized first; one complete Callback assignment then serves every
;; nested field and the original declared bound. No independent child solve runs.
(def RetiredCallServiceType
  (prototype-type (.o .parameters: '(Value Callback)) '(Value Callback)
    `(Function (Value ,(retired-call-view 'Value 'Callback)) (Value))
    (list (list 'Callback (retired-call-target 'Value)))))
;; Gerbil's case-lambda supplies actual zero/two-argument dispatch. Contract
;; inference does not add arities or execute a retired clause/default.
(def (retired-call-callback seed)
  (case-lambda (() seed) ((left right) (+ seed left right))))
;; Reuse Reader/FUN specialization, complete typed declaration and the existing
;; recursive refine/evidence publication. A refreshed callback keeps its wrappers;
;; policy refusal remains observable and a new action can retry independently.
(def (retired-call-action candidates seed context consume (allowed? #t))
  (specialized-action RetiredCallServiceType '(UInt) candidates (lambda (_) [])
    (lambda (value)
      (values value (.o handlers: (hash (0 (retired-call-callback value)))
        refresh: retired-call-callback)))
    seed context consume allowed?))
