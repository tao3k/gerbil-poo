;;; Seeded service checks combine nested callbacks, optional and keyword defaults.
(export signature-preparation-test service-admission-tests RetiredCallServiceType retired-call-target retired-call-view retired-call-callback retired-call-action staged-service-action catalog-service-type checked-operation-action callback-service-action specialized-action selected-declarations selected-action Callback ServiceSignature service checked-service service-property service-tests)
(import :std/test :std/error :std/iter
        (only-in ../testing/generation-graph generation-refusal?)
        (prefix-in :clan/poo/testing/property/generator core.)
        ../object
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
        (runtime: :clan/poo/fun)
        (prefix-in ./contract-publication publication.)
        (runtime: :clan/poo/examples/polymorphic-services)
        (prefix-in (only-in ./polymorphic-services DescriptorServiceType
                   descriptor-service-action signature-request-action
                   signature-service-declarations) service.)
        (prefix-in (only-in :clan/poo/fun Observation.) fun.))

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
  (.call fun.Observation. .bind
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
  (.call fun.Observation. .bind
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
  (.call fun.Observation. .bind
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

;; Specialize the supplied input domains while retaining the real service's
;; optional/keyword defaults and nested callback wrapping. FUN passes either the
;; checked equivalence evidence or a shrinkable target discrepancy to consume.
(def (service-admission-tests input callbacks coefficient target consume)
  (def signature (Function [Integer] (list input) optional: (list callbacks)
    keywords: (list (cons scale: coefficient) (cons offset: Integer))))
  (def checked (validate signature target))
  (property-action (FunctionArguments signature)
    (lambda (arguments) (= (apply checked arguments) (apply service arguments))) consume))

;; These controls use delayed declaration fields: constructing the public
;; FunctionArguments Type has no effects; preparation owns the first observation.
(def signature-preparation-test
  (test-suite "Function call declaration preparation"
    (test-case "nested keyword discovery cannot renew the Function or clause"
      (for (owner '(function clause))
        (def armed #f) (def reads 0) (def later 0)
        (def base (Function [Integer] [Integer]))
        (def clause (.o bind-these: #f inherit: [base]
          keywords: (begin (set! reads (1+ reads))
            (when armed (.set! (if (eq? owner 'function) subject clause) epoch 1)) [])
          inputs: (begin (set! later (1+ later)) [Integer])))
        (def subject (.o bind-these: #f inherit: [base] signatures: [clause] sexp: 'service-inputs))
        (def request (FunctionArguments subject))
        (check-equal? (list reads later) '(0 0))
        (set! armed #t)
        (check-exception (generator request)
          (lambda (cause) (if (eq? owner 'function) (generation-refusal? cause)
            (and (Error? cause) (equal? (Error-message cause) "object mutation during computation")))))
        (check-equal? (list reads later) '(1 0))))
    (test-case "later positional metadata cannot retire an already observed input Type"
      (def input (.cc Integer epoch: 0)) (def later 0)
      (def base (Function [Integer] [Integer]))
      (def clause (.o bind-these: #f inherit: [base] inputs: [input]
        optional: (begin (.set! input epoch 1) [])
        rest: (begin (set! later (1+ later)) #f)))
      (def request (FunctionArguments (.o bind-these: #f inherit: [base] signatures: [clause] sexp: 'inputs)))
      (check-equal? (object-revision input) 0)
      (check-exception (generator request) generation-refusal?)
      (check-equal? later 0))
    (test-case "early keyword Types remain owned before positional discovery"
      (def input (.cc Integer epoch: 0)) (def later 0)
      (def base (Function [Integer] [Integer]))
      (def clause (.o bind-these: #f inherit: [base] keywords: (list (cons scale: input))
        inputs: (begin (.set! input epoch 1) [Integer])
        optional: (begin (set! later (1+ later)) [])))
      (def request (FunctionArguments (.o bind-these: #f inherit: [base] signatures: [clause] sexp: 'keys)))
      (check-equal? (object-revision input) 0)
      (check-exception (generator request) generation-refusal?)
      (check-equal? later 0))
    (test-case "metadata exceptions including false survive retirement exactly"
      (for (cause (list #f (cons 'metadata 'fault)))
        (def base (Function [Integer] [Integer]))
        (def clause (.o bind-these: #f inherit: [base]
          keywords: (begin (.set! subject epoch 1) (raise cause))))
        (def subject (.o bind-these: #f inherit: [base] signatures: [clause] sexp: 'throwing))
        (def request (FunctionArguments subject))
        (def outcome (with-catch (lambda (value) (cons 'caught value))
          (lambda () (generator request) 'unexpected)))
        (check-eq? (car outcome) 'caught)
        (check-eq? (cdr outcome) cause))
      (check-equal? (core.sample-value (core.generate (core.generator-unit 7) (core.random-at 0) 0)) 7))

    (test-case "cached layouts retain dormant Types and cannot erase their source guard"
      (def factories 0)
      (def dormant (.cc Integer epoch: 0 .generator: (lambda ()
        (set! factories (1+ factories)) (generator Integer))))
      (def first (Function [Integer] [Integer]))
      (def shadowed (Function [Integer] [dormant]))
      (def subject (.o inherit: [first] signatures: [first shadowed] sexp: 'ordered))
      (def request (FunctionArguments subject))
      (def sampler (generator request))
      (def generation (generator-core (.cc sampler sources: [])))
      ;; Both proposals select the first clause; no shadowed generator is forced.
      (core.generate generation (core.random-at 1) 0)
      (core.generate generation (core.random-at 2) 0)
      (check-equal? factories 0)
      (.set! dormant epoch 1)
      (check-exception (core.generate generation (core.random-at 3) 0) core.stale-generation?)
      (check-equal? factories 0)
      ;; Explicit renewed construction succeeds; the obsolete cached graph stays stale.
      (def fresh (generator request))
      (core.generate (generator-core fresh) (core.random-at 4) 0)
      (check-exception (core.generate generation (core.random-at 5) 0) core.stale-generation?)
      (check-equal? factories 0))
    (test-case "nested callback services keep FUN failure shrinking replay and explicit retry"
      (def configuration (make-instance PropertyConfiguration seed: 43 cases: 20 size: 5 shrink-budget: 60))
      (def signature (.cc ServiceSignature epoch: 0))
      (def request (FunctionArguments signature))
      (def sampler (generator request))
      (def action (property-action request (lambda (arguments) (not (service-property arguments)))
        identity sampler: sampler))
      (def failed (action configuration))
      (check-eq? (.get failed status) 'failed)
      (check (replay-counterexample failed) => #f)
      (check-eq? (.get (replay-property failed) status) 'failed)
      (.set! signature epoch 1)
      (check-exception (replay-property failed) Error?)
      (def stale (action configuration))
      (check-eq? (.get stale status) 'stale)
      (check-eq? (.get ((property-action request service-property identity) configuration) status) 'passed))))
