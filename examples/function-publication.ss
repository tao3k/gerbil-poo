;;; JSON configuration, nested checked callbacks and exact publication binding.
(export EngineContract WorkflowContract workflow-action)
(import ../object
        ../mop
        ../number
        ../io
        ../object-contract
        (only-in ../type String Json)
        (runtime: :clan/poo/generalized-prototype)
        (prefix-in (only-in ../generalized-prototype Observation.) observation.)
        (prefix-in ./object-contracts service.)
        (prefix-in ./contract-publication publication.))

;; Standard Function descriptors own arity, argument/result validation and
;; higher-order result wrapping. Recognition alone only checks procedure?.
(def EngineContract
  (.cc ObjectContract. responsibilities:
    (.o tenant: String convert: (Fun Integer Bool <- Integer)
        policy: (Fun (Fun Bool <- Integer) <- Integer))))

;; Refine a nested immutable workflow. This relation observes the final checked
;; candidate after every declared Function field has acquired its wrapper.
(def WorkflowContract
  (refine (.cc ObjectContract. responsibilities:
            (.o config: publication.CapacityContract engine: EngineContract))
    (lambda (candidate location)
      (if (equal? (.get candidate config host) (.get candidate engine tenant)) '()
        [(.o kind: 'tenant-mismatch path: (append location '(engine tenant)))]))))

;; Use both multiple values and a returned checked callback, then encode only a
;; data projection through the existing JSON I/O. A failing callback preserves
;; its original cause through metadata.publish and cannot return the next state.
(def (produce context-value checked-value)
  (def engine-value (.get checked-value engine))
  (def config-value (.get checked-value config))
  (defvalues (units available) ((.get engine-value convert) (.get config-value used)))
  (def allowed ((.get engine-value policy) (.get config-value capacity)))
  (def encoded (json-string<- Json
    (hash ("tenant" (.get config-value host)) ("units" units)
          ("allowed" (and available (allowed units))))))
  (values (.o subject: checked-value descriptor: WorkflowContract context: context-value payload: encoded)
          (.cc context-value commits: (+ 1 (.get context-value commits)))))

;; Reader/FUN composition parses each request and binds only the actual wrapped
;; root object, not the raw request or a projected lookalike. No approval is cached.
(def (workflow-action invocation context-value engine-value)
  (def publish (publication.publication-action WorkflowContract invocation context-value
                 (cut produce context-value <>)))
  (.call observation.Observation. .bind
    (lambda (text) (.o config: (service.decode-service text) engine: engine-value))
    (lambda (candidate) (lambda (_text) (publish candidate)))))
