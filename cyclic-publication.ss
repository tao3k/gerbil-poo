;;; CyclicPublication: finite least closure followed by staged value publication.
;;; Callback-only subset; GenericFamily typed dispatch is not yet implemented.
(export prepare publish version?
        version-view version-facts invoke
        failure? failure-stage failure-cause)
(import :std/iter ./closure)
(defstruct version (plan result view services) final: #t)
(defstruct failure (stage cause) final: #t)

(def (version-facts current)
  (closure->list (version-result current)))

(def (invoke current service . arguments)
  (apply (hash-ref (version-services current) service) arguments))

(def (prepare-services methods view)
  (def declarations (methods view))
  (unless (list? declarations) (error "services must be an association list"))
  (def table (make-hash-table-eq))
  (for (declaration declarations)
    (match declaration
      ([name . procedure]
       (unless (and (symbol? name) (procedure? procedure)) (error "invalid closure service" name))
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
