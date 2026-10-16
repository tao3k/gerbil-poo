;;; Shared contract preparation in a cross-service atomic publication.
;;; Generalized-prototype future work: immutable closed inputs, native mixins.
(export source independent-source selected-source planned-source model selected-model planned-model workflow-model planned-workflow-model project-direct cancellation shared-input prepare-shared project-shared construct)
(import ../object (prefix-in ../contract-family family.)
        (prefix-in ../declarative-metadata metadata.)
        (prefix-in ./construction-workflow workflow.)
        (prefix-in ./service-metadata service.) (prefix-in ./service-bundle bundle.))
(def (cancellation-meaning invoice)
  (lambda (_ args result) (equal? result (list (car args) invoice))))
(def cancellation-template
  (metadata.contract
    (metadata.predicate "consent" (match <> ([customer #t] (string? customer)) (else #f)))
    (metadata.predicate "invoice-event" (match <> ([customer tag] (and (string? customer) (string? tag))) (else #f)))
    (cancellation-meaning "") (metadata.atom 'invoice)))
(def (cancellation invoice) (.cc cancellation-template meaning: (cancellation-meaning invoice)))
(def (shared-input _ view) (list (.@ view capacity) (.@ view invoice)))
;; Only the closed pair is observable here. Preparing a shared lookup once avoids
;; rebuilding the key routing table for each contract and unchanged revision.
(def (prepare-shared context)
  (match context
    ([capacity invoice]
     (def inputs (make-hash-table-eq))
     (hash-put! inputs 'reserve capacity)
     (hash-put! inputs 'cancel invoice)
     (lambda (key) (hash-ref inputs key)))))
(def (project-shared key lookup) (lookup key))
(def (construct key input)
  (case key ((reserve) (service.reservation input)) ((cancel) (cancellation input))
    (else (error "unknown contract" key))))
(def contract-keys '(reserve cancel))
(def independent-source
  (.cc family.Source. keys: (lambda (_ __) contract-keys)
    project: (lambda (key policy view) (project-shared key (prepare-shared (shared-input policy view))))
    construct: construct))
(def source
  (.mix (.cc family.methods.inputs<-shared
          shared-input: shared-input prepare-shared: prepare-shared project-shared: project-shared)
    independent-source))
;; Existing generic projections, exact-service approval reuse, dynamic cache
;; budget and atomic refusal all remain in the native staged composition chain.
(def model (.cc bundle.model contract-source: source))
;; For a two-field context, routing through an allocated index is unnecessary.
;; A larger source can supply a cheaper shared/indexed price instead.
(def (project-direct key context)
  (match context ([capacity invoice]
    (case key ((reserve) capacity) ((cancel) invoice) (else (error "unknown contract" key))))))
(def selected-source
  (.mix (.cc family.methods.inputs<-selection
          shared-input: shared-input prepare-shared: prepare-shared project-shared: project-shared
          project-direct: project-direct
          preparation-costs: (.cc family.PreparationCosts. prepare-cost: 3 shared-cost: 1 direct-cost: 1 selection-cost: 1))
    independent-source))
(def selected-model (.cc bundle.model contract-source: selected-source))

;; Shared settlement DAG → cooked interface → selected contracts → joint approval.
(def workflow-model (.cc workflow.model contract-source: selected-source))

;; Stable support can plan its projection strategy once, before revision work.
(def planned-source
  (.mix (.cc family.methods.inputs<-plan
          shared-input: shared-input prepare-shared: prepare-shared project-shared: project-shared
          project-direct: project-direct
          preparation-plan: (.cc family.PreparationPlan. keys: contract-keys
            preparation-costs: (.@ selected-source preparation-costs)))
    independent-source))
(def planned-model (.cc bundle.model contract-source: planned-source))
(def planned-workflow-model (.cc workflow.model contract-source: planned-source))
