;;; Seeded service checks combine nested callbacks, optional and keyword defaults.
(export callback-service-action specialized-action selected-declarations selected-action Callback ServiceSignature service checked-service service-property service-tests)
(import ../object ../mop ../type ../number ../function-testing ../property-testing
        ../method-declaration ../declaration ../object-contract
        (prefix-in ../multimethod dispatch.)
        (prefix-in ../method-combination combination.) (prefix-in ../declarative-metadata metadata.)
        (prefix-in ../generalized-prototype observation.)
        (prefix-in ./contract-publication publication.)
        (prefix-in ./polymorphic-services service.))

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
