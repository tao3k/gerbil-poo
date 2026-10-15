;;; CyclicPublication: finite least closure followed by staged value publication.
;;; Procedure services and checked typed multimethods share one publication.
(export prepare publish version?
        version-view version-facts version-service invoke
        failure? failure-stage failure-cause)
(import :std/iter ./closure (prefix-in ./dispatch-extension dispatch-extension.)
        (prefix-in ./declarative-metadata declarative-metadata.))
(defstruct version (plan result view services invokers contract-builder) final: #t)
(defstruct failure (stage cause) final: #t)

(def (version-facts current)
  (closure->list (version-result current)))

(def (version-service current service) (hash-ref (version-services current) service))
(def (invoke-source current service arguments)
  (def implementation (version-service current service))
  (if (dispatch-extension.certificate? implementation)
    (let-values (((result checked) (apply dispatch-extension.invoke implementation arguments)))
      (if (eq? checked implementation) (values result current)
        (let (services (hash-copy (version-services current)))
          (hash-put! services service checked)
          (values result (make-version (version-plan current) (version-result current) (version-view current) services (version-invokers current) (version-contract-builder current))))))
    (values (apply implementation arguments) current)))

(def (invoke current service . arguments)
  (def checked (hash-get (version-invokers current) service))
  (if checked
    (checked arguments current)
    (invoke-source current service arguments)))

(def (prepare-bindings declarations valid? label (adapt (lambda (_ value) value)))
  (unless (list? declarations) (error "expected metadata association list" label))
  (def table (make-hash-table-eq))
  (for (entry declarations)
    (match entry
      ([name . value]
       (unless (and (symbol? name) (valid? name value)) (error "invalid metadata binding" label name))
       (when (hash-key? table name) (error "duplicate metadata binding" label name))
       (hash-put! table name (adapt name value)))
      (else (error "invalid metadata declaration" label entry))))
  table)
(def (prepare-contracts builder view services)
  (prepare-bindings (builder view)
    (lambda (name value) (and (hash-key? services name) (declarative-metadata.contract? value))) 'contracts
    (lambda (name contract)
      (declarative-metadata.wrap contract (lambda (args current) (invoke-source current name args))))))
(def (no-contracts _) [])
(def (prepare-services methods view)
  (prepare-bindings (methods view)
    (lambda (_ value) (or (procedure? value) (dispatch-extension.certificate? value))) 'services))

;; Callbacks must be pure with respect to already published values. External
;; callback side effects are outside this value-publication/rollback contract.
(def (stage old equations cook methods admit retain? contracts-builder)
  (def stage 'construction)
  (try
    (def plan (if (and old retain?) (reconfigure-closure (version-plan old) equations)
                  (compile-closure equations 'cold)))
    (set! stage 'closure)
    (def facts (solve-closure plan))
    (set! stage 'cooking)
    (def view (cook facts))
    (set! stage 'services)
    (def services (prepare-services methods view))
    (set! stage 'metadata)
    (def invokers (prepare-contracts contracts-builder view services))
    (def candidate (make-version plan facts view services invokers contracts-builder))
    (set! stage 'admission)
    (unless (admit candidate) (error "closure candidate refused"))
    (values candidate #f)
    (catch (cause) (values old (make-failure stage cause)))))

(def (prepare equations cook methods admit (contracts-builder no-contracts))
  (stage #f equations cook methods admit #f contracts-builder))
(def (publish old equations cook methods admit (retain? #t) (contracts-builder (version-contract-builder old)))
  (unless (version? old) (error "expected previous cyclic publication version"))
  (stage old equations cook methods admit retain? contracts-builder))
