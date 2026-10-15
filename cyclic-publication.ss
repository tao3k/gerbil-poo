;;; CyclicPublication: finite least closure followed by staged value publication.
;;; Procedure services and checked typed multimethods share one publication.
(export prepare publish version?
        version-view version-facts version-service invoke
        failure? failure-stage failure-cause)
(import :std/iter ./closure (prefix-in ./dispatch-extension dispatch-extension.))
(defstruct version (plan result view services) final: #t)
(defstruct failure (stage cause) final: #t)

(def (version-facts current)
  (closure->list (version-result current)))

(def (version-service current service) (hash-ref (version-services current) service))
(def (invoke current service . arguments)
  (def implementation (version-service current service))
  (if (dispatch-extension.certificate? implementation)
    (let-values (((result checked) (apply dispatch-extension.invoke implementation arguments)))
      (if (eq? checked implementation) (values result current)
        (let (services (hash-copy (version-services current)))
          (hash-put! services service checked)
          (values result (make-version (version-plan current) (version-result current) (version-view current) services)))))
    (values (apply implementation arguments) current)))

(def (prepare-services methods view)
  (def declarations (methods view))
  (unless (list? declarations) (error "services must be an association list"))
  (def table (make-hash-table-eq))
  (for (declaration declarations)
    (match declaration
      ([name . procedure]
       (unless (and (symbol? name) (or (procedure? procedure) (dispatch-extension.certificate? procedure))) (error "invalid closure service" name))
       (when (hash-key? table name) (error "duplicate closure service" name))
       (hash-put! table name procedure))
      (else (error "invalid closure service declaration" declaration))))
  table)

;; Callbacks must be pure with respect to already published values. External
;; callback side effects are outside this value-publication/rollback contract.
(def (stage old equations cook methods admit retain?)
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
    (def candidate (make-version plan facts view services))
    (set! stage 'admission)
    (unless (admit candidate) (error "closure candidate refused"))
    (values candidate #f)
    (catch (cause) (values old (make-failure stage cause)))))

(def (prepare equations cook methods admit)
  (stage #f equations cook methods admit #f))
(def (publish old equations cook methods admit (retain? #t))
  (unless (version? old) (error "expected previous cyclic publication version"))
  (stage old equations cook methods admit retain?))
