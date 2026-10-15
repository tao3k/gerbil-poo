;;; Least closure, cooking, heterogeneous services and admission form one value.
(export prepare-closure-bundle publish-closure-bundle closure-bundle?
        closure-bundle-view closure-bundle-facts closure-bundle-call
        closure-rejection? closure-rejection-stage closure-rejection-cause)
(import :std/iter ./closure)
(defstruct closure-bundle (plan result view services) final: #t)
(defstruct closure-rejection (stage cause) final: #t)

(def (closure-bundle-facts bundle)
  (closure->list (closure-bundle-result bundle)))

(def (closure-bundle-call bundle service . arguments)
  (apply (hash-ref (closure-bundle-services bundle) service) arguments))

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
(def (stage-closure-bundle old equations cook methods admit retain?)
  (def stage 'construction)
  (try
    (def plan (if (and old retain?) (reconfigure-closure (closure-bundle-plan old) equations)
                  (compile-closure equations 'cold)))
    (set! stage 'closure)
    (def facts (solve-closure plan))
    (set! stage 'cooking)
    (def view (cook facts))
    (set! stage 'services)
    (def services (prepare-services methods view))
    (def candidate (make-closure-bundle plan facts view services))
    (set! stage 'admission)
    (unless (admit candidate) (error "closure candidate refused"))
    (values candidate #f)
    (catch (cause) (values old (make-closure-rejection stage cause)))))

(def (prepare-closure-bundle equations cook methods admit)
  (stage-closure-bundle #f equations cook methods admit #f))
(def (publish-closure-bundle old equations cook methods admit (retain? #t))
  (unless (closure-bundle? old) (error "expected previous closure bundle"))
  (stage-closure-bundle old equations cook methods admit retain?))
