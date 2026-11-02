;;; Strengthened structural contracts and exact invocation binding through FUN.
(export CapacityContract publication-action evidence-view)
(import ../object
        ../object-contract
        (runtime: :clan/poo/declarative-metadata)
        (prefix-in (only-in ../declarative-metadata bind-evidence publish) metadata.)
        (prefix-in ./object-contracts service.))

;; Keep all five service fields and both original relations, then add a local
;; policy phase. This is explicit strengthening, not subtype inference.
(def CapacityContract
  (refine service.ServiceContract
    (lambda (candidate location)
      (if (<= (.get candidate capacity) 100) '()
        [(.o kind: 'capacity-limit path: (append location '(capacity)))]))))

;; Project an existing application's result; this does not authenticate its fields.
(def (evidence-view result) result)

;; Admission runs before the state-producing callback. Existing invocation
;; predicates/formula still run, followed by the fresh exact-reference relation.
;; Consumers keep candidate, descriptor and context immutable while using the
;; prepared action. Only accepted publication returns the proposed next state;
;; source effects are not rolled back by a later output/logic refusal.
(def (publication-action descriptor invocation context execute)
  (checked-action descriptor
    (lambda (candidate)
      (metadata.publish
        (metadata.bind-evidence invocation candidate descriptor context evidence-view)
        context execute candidate))))
