;;; CyclicPublication: finite least closure followed by staged value publication.
;;; Procedure services and checked typed multimethods share one publication.
(export prepare publish finish stage-from version?
        version-family version-admission-source same-service? version-view version-facts version-cache version-source version-service invoke probe
        failure? failure-stage failure-cause)
(import :std/iter ./closure (prefix-in ./generic-family generic-family.) (prefix-in ./dispatch-extension dispatch-extension.)
        (prefix-in ./declarative-metadata declarative-metadata.))
(defstruct version (plan result view services invokers contracts contract-builder readmit admission-source) final: #t)
(defstruct failure (stage cause) final: #t)

(def (version-facts current)
  (closure->list (version-result current)))

(def (version-family current)
  (and (generic-family.family? (version-services current)) (version-services current)))
(def (service-ref services key)
  (if (generic-family.family? services) (generic-family.family-ref services key) (hash-ref services key)))
(def (service-has? services key)
  (if (generic-family.family? services) (generic-family.family-has? services key) (hash-key? services key)))
(def (version-service current service) (service-ref (version-services current) service))
(def (same-service? old candidate key)
  (and old (service-has? (version-services old) key) (service-has? (version-services candidate) key)
       (eq? (version-service old key) (version-service candidate key))
       (eq? (hash-get (version-contracts old) key) (hash-get (version-contracts candidate) key))))
(def (with-services current services)
  (make-version (version-plan current) (version-result current) (version-view current) services
    (version-invokers current) (version-contracts current) (version-contract-builder current) (version-readmit current) (version-admission-source current)))
(def (invoke-source current service arguments)
  (def implementation (version-service current service))
  (cond
    ((version-family current)
     (defvalues (result next) (apply generic-family.invoke (version-family current) service arguments))
     (values result (if (eq? next (version-family current)) current (with-services current next))))
    ((dispatch-extension.certificate? implementation)
     (defvalues (result checked) (apply dispatch-extension.invoke implementation arguments))
     (if (eq? checked implementation) (values result current)
       (let (services (hash-copy (version-services current)))
         (hash-put! services service checked)
         (values result (with-services current services)))))
    (else (values (apply implementation arguments) current))))

(def (invoke-checked current service . arguments)
  (def checked (hash-get (version-invokers current) service))
  (if checked
    (checked arguments current)
    (invoke-source current service arguments)))

(def (probe current service . arguments)
  (defvalues (result _) (apply invoke-checked current service arguments))
  result)
(def (admit! admit candidate)
  (def accepted (admit candidate))
  (unless (and (boolean? accepted) accepted) (error "publication candidate refused")))

(def (invoke current service . arguments)
  (defvalues (result candidate) (apply invoke-checked current service arguments))
  ;; Admission observes this exact cache successor. Probes inside admission use
  ;; probe, which checks contracts without recursively admitting another version.
  (when (version-readmit current)
    (try
      (admit! (version-readmit current) candidate)
      (catch (cause) (raise (make-failure 'admission cause)))))
  (values result candidate))

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
(def (prepare-contracts declarations services)
  (def invokers (make-hash-table-eq))
  (def contracts
    (prepare-bindings declarations
      (lambda (name value) (and (service-has? services name) (declarative-metadata.contract? value))) 'contracts
      (lambda (name contract)
        (hash-put! invokers name
          (declarative-metadata.wrap contract (lambda (args current) (invoke-source current name args))))
        contract)))
  (values contracts invokers))
(def (no-contracts _) [])
(def (prepare-services methods view)
  (def bindings (methods view))
  (if (generic-family.family? bindings) bindings
    (prepare-bindings bindings
      (lambda (_ value) (or (procedure? value) (dispatch-extension.certificate? value))) 'services)))

;; Callbacks must be pure with respect to already published values. External
;; callback side effects are outside this value-publication/rollback contract.
(def version-source version-plan)
(def version-cache version-result)
(def (finish old source materialized cook methods admit contracts-builder readmit (admission-source #f))
  (def phase 'cooking)
  (try
    (def view (cook materialized))
    (set! phase 'services)
    (def services (prepare-services methods view))
    (set! phase 'metadata)
    (def declarations (contracts-builder view))
    (defvalues (contracts invokers) (prepare-contracts declarations services))
    (def candidate (make-version source materialized view services invokers contracts contracts-builder readmit admission-source))
    (set! phase 'admission)
    (admit! admit candidate)
    (values candidate #f)
    (catch (cause) (values old (make-failure phase cause)))))
(def (stage-from old construct cook methods admit contracts-builder readmit (admission-source #f))
  (try
    (defvalues (source materialized) (construct))
    (finish old source materialized cook methods admit contracts-builder readmit admission-source)
    (catch (cause) (values old (make-failure 'construction cause)))))
(def (stage old equations cook methods admit retain? contracts-builder readmit)
  (def phase 'construction)
  (try
    (def plan (if (and old retain?) (reconfigure-closure (version-plan old) equations)
                  (compile-closure equations 'cold)))
    (set! phase 'closure)
    (def facts (solve-closure plan))
    (finish old plan facts cook methods admit contracts-builder readmit)
    (catch (cause) (values old (make-failure phase cause)))))

(def (prepare equations cook methods admit (contracts-builder no-contracts) (readmit #f))
  (stage #f equations cook methods admit #f contracts-builder readmit))
(def (publish old equations cook methods admit (retain? #t) (contracts-builder (version-contract-builder old)) (readmit (version-readmit old)))
  (unless (version? old) (error "expected previous cyclic publication version"))
  (stage old equations cook methods admit retain? contracts-builder readmit))
