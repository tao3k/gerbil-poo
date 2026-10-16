;;; Shared contract preparation in a cross-service atomic publication.
;;; Generalized-prototype future work: immutable closed inputs, native mixins.
(export source independent-source selected-source cached-source model selected-model cached-model workflow-model cached-workflow-model project-direct cancellation shared-input prepare-shared project-shared construct)
(import ../object (prefix-in ../contract-family family.)
        (prefix-in ../declarative-metadata metadata.)
        (prefix-in ./construction-workflow workflow.)
        (prefix-in ./service-metadata service.) (prefix-in ./service-bundle bundle.))
;; Close only over the current invoice; accept an event containing the consenting
;; customer and that invoice. Input/output shape checks are supplied by the template.
(def (cancellation-meaning invoice)
  (lambda (_ args result) (equal? result (list (car args) invoice))))
;; Invariant consent/event predicates and invoice logical rule shared by every
;; cancellation descriptor. The empty invoice is a placeholder specialized below.
(def cancellation-template
  (metadata.contract
    (metadata.predicate "consent" (match <> ([customer #t] (string? customer)) (else #f)))
    (metadata.predicate "invoice-event" (match <> ([customer tag] (and (string? customer) (string? tag))) (else #f)))
    (cancellation-meaning "") (metadata.atom 'invoice)))
;; Specialize only invoice meaning on the invariant template. Returns a descriptor,
;; not a service result; actual invocation still checks consent/output/logical meaning.
(def (cancellation invoice) (.cc cancellation-template meaning: (cancellation-meaning invoice)))
;; Extract the complete preparation context from the cooked view: capacity/invoice.
;; Policy is intentionally unused; no executor or mutable snapshot is captured.
(def (shared-input _ view) (list (.@ view capacity) (.@ view invoice)))
;; Only the closed pair is observable here. Preparing a shared lookup once avoids
;; rebuilding the key routing table for each contract and unchanged revision.
;; Prepare one private key-routing lookup from the closed capacity/invoice pair.
;; Its immutable entries serve both contracts; malformed context or unknown lookup
;; keys raise. The family can retain this lookup only for an equal closed pair.
(def (prepare-shared context)
  (match context
    ([capacity invoice]
     (def inputs (make-hash-table-eq))
     (hash-put! inputs 'reserve capacity)
     (hash-put! inputs 'cancel invoice)
     (lambda (key) (hash-ref inputs key)))))
;; Read one closed contract input through the prepared lookup; propagate missing-key
;; failure. This is the reference meaning for direct projection coherence.
(def (project-shared key lookup) (lookup key))
;; Construct reserve/cancel metadata from its heterogeneous closed input.
;; Unknown keys raise; returned descriptors are checked again by ContractFamily.
(def (construct key input)
  (case key ((reserve) (service.reservation input)) ((cancel) (cancellation input))
    (else (error "unknown contract" key))))
;; Canonical immutable support shared by all source variants. Stable identity
;; allows a constant-time cached-choice hit without removing support validation.
(def contract-keys '(reserve cancel))
;; Reference source that prepares the closed lookup independently for each key.
;; Use as a semantic/cost control; all variants retain these constructors and support.
(def independent-source
  (.cc family.Source. keys: (lambda (_ __) contract-keys)
    project: (lambda (key policy view) (project-shared key (prepare-shared (shared-input policy view))))
    construct: construct))
;; Default composition: prepare shared inputs once and retain equal contexts.
;; Mix with the independent source to reuse its key/constructor protocol.
(def source
  (.mix (.cc family.methods.inputs<-shared
          shared-input: shared-input prepare-shared: prepare-shared project-shared: project-shared)
    independent-source))
;; Existing generic projections, exact-service approval reuse, dynamic cache
;; budget and atomic refusal all remain in the native staged composition chain.
;; Install the default contract source into the existing cross-service publisher.
;; Generic construction, cache budget and joint approval remain its original chain.
(def model (.cc bundle.model contract-source: source))
;; For a two-field context, routing through an allocated index is unnecessary.
;; A larger source can supply a cheaper shared/indexed price instead.
;; Project the same capacity/invoice inputs without allocating the routing table.
;; Unknown keys raise; this two-field optimization does not generalize to arbitrary
;; large sources without coherent projections and suitable cost weights.
(def (project-direct key context)
  (match context ([capacity invoice]
    (case key ((reserve) capacity) ((cancel) invoice) (else (error "unknown contract" key))))))
;; Derive dynamic shared/direct choice with explicit operation weights.
;; Weights select direct for this small support; this is an optional example policy,
;; not measured timing embedded in the runtime or a universal default.
(def selected-source
  (.mix (.cc family.methods.inputs<-selection
          shared-input: shared-input prepare-shared: prepare-shared project-shared: project-shared
          project-direct: project-direct
          preparation-costs: (.cc family.PreparationCosts. prepare-cost: 3 shared-cost: 1 direct-cost: 1 selection-cost: 1))
    independent-source))
;; Use dynamic contract preparation with the unchanged atomic bundle publisher.
(def selected-model (.cc bundle.model contract-source: selected-source))

;; Shared settlement DAG → cooked interface → selected contracts → joint approval.
;; Connect the existing shared settlement DAG and cooked interface to dynamic
;; contract preparation and joint approval; construction invalidation stays graph-owned.
(def workflow-model (.cc workflow.model contract-source: selected-source))

;; Stable support can cache its projection strategy once, before revision work.
;; Derive the same contract source with a stable-support SelectionCache.
;; Reuse only the projection strategy; contract/source/approval checks stay active.
;; Changed prices require a new cache, and changed support size reselects normally.
(def cached-source
  (.mix (.cc family.methods.inputs<-cached-selection
          shared-input: shared-input prepare-shared: prepare-shared project-shared: project-shared
          project-direct: project-direct
          selection-cache: (.cc family.SelectionCache. keys: contract-keys
            preparation-costs: (.@ selected-source preparation-costs)))
    independent-source))
;; Install cached strategy selection into atomic cross-service publication.
;; This optional variant is benchmarked against dynamic/independent preparation.
(def cached-model (.cc bundle.model contract-source: cached-source))
;; Combine cached strategy choice with the existing multi-level shared-dependency
;; workflow. DAG rebuilding and application approval retain their own invalidation rules.
(def cached-workflow-model (.cc workflow.model contract-source: cached-source))
