;;; Shared contract preparation in a cross-service atomic publication.
;;; Generalized-prototype future work: immutable closed inputs, native mixins.
(export configured-source repeated-source selection-prices source independent-source selected-source cached-source model selected-model cached-model workflow-model cached-workflow-model expanded-generics expanded-cached-model expanded-cached-workflow-model budgeted-source budgeted-model budgeted-workflow-model shared-checks-source shared-checks-model shared-checks-workflow-model shared-checks-cached-model shared-checks-cached-workflow-model specialized-construct expanded-model expanded-workflow-model project-direct cancellation shared-input prepare-shared project-shared construct)
(import ../object (prefix-in ../contract-family family.) (prefix-in ../generic-family generics.)
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

;; Share the closed immutable reconstruction for each changed heterogeneous generic.
;; The existing seed/declarations inspect values only and permit sharing; keep their
;; source, negative watches and per-key closed-context invalidation unchanged.
(def expanded-generics
  (let (original (.@ selected-model generics))
    (.cc original projection:
      (.mix generics.methods.instantiate<-shared-expansion (.@ original projection)))))
;; Cross-service joint revision with dynamic contract selection and one expansion
;; per changed generic. Contract construction/binding and approval are unchanged.
(def expanded-model (.cc selected-model generics: expanded-generics))
;; Combine the shared settlement DAG, cooked interface, shared generic expansion,
;; checked contracts and joint approval. Warm siblings retain their certificates.
(def expanded-workflow-model (.cc workflow-model generics: expanded-generics))

;; Direct combination control: change only selection reuse under shared expansion.
(def expanded-cached-model (.cc expanded-model contract-source: cached-source))
;; Same DAG, generic reconstruction and approval as expanded-workflow-model, with
;; stable-support selection caching as the only changed preparation strategy.
(def expanded-cached-workflow-model (.cc expanded-workflow-model contract-source: cached-source))
;; Construct the same capacity/invoice descriptors while sharing invariant checks.
;; Unknown keys fail before a complete family can be published.
(def (specialized-construct key input (share? #t))
  (case key
    ((reserve) (service.specialized-reservation input share?))
    ((cancel) (metadata.with-meaning cancellation-template (cancellation-meaning input) share?))
    (else (error "unknown contract" key))))
;; Dynamic projection choice plus stamped immutable descriptor-check reuse.
(def shared-checks-source (.cc selected-source construct: specialized-construct))
;; Combine shared generic expansion and descriptor checks; selection remains dynamic.
(def shared-checks-model (.cc expanded-model contract-source: shared-checks-source))
;; Multi-level shared dependencies with the same independent approval/retention rules.
(def shared-checks-workflow-model (.cc expanded-workflow-model contract-source: shared-checks-source))
;; Isolate selection-cache effect after both other construction optimizations.
(def shared-checks-cached-model (.cc expanded-cached-model contract-source:
  (.cc cached-source construct: specialized-construct)))
;; Same cached/check-sharing composition in the complete settlement DAG workflow.
(def shared-checks-cached-workflow-model (.cc expanded-cached-workflow-model contract-source:
  (.cc cached-source construct: specialized-construct)))

;; Conservative one-miss budget: many workflow revisions may retain the closed
;; context, so they must not be counted as repeated selector savings. These explicit
;; operation weights are an illustrative model, not embedded measured timings.
;; Reusable immutable selection budget: callback validation is amortized across
;; source configurations. These are illustrative operation weights, not timings.
(def selection-prices (.cc family.SelectionCacheCosts. setup: 2 guard: 1 calls: 1
  collection-price: 1 extra-collections: 1))
;; Compile independent selector-entry and descriptor-use horizons into an existing
;; source. Both counts are supplied premises, not learned timings. Invalid horizons
;; raise through the existing cost protocols. A fresh source is the existing clone
;; constructor; shared checks use the existing stamped invariant specialization.
(def (configured-source selector-calls check-uses)
  (let (mode (family.choose-checks (.cc family.TemplateCosts. setup: 2 specialize: 1 rebuild: 2) check-uses))
    (family.choose-source (.cc selection-prices calls: selector-calls)
      (if (eq? mode 'shared) shared-checks-source selected-source) (lambda () contract-keys))))
;; One cold use chooses existing fresh checks and dynamic selection by exact source identity.
(def budgeted-source (configured-source 1 1))
;; A sustained service uses a separate supported horizon. With these weights,
;; checks amortize but selector guards do not; the exact shared-checks source wins.
(def repeated-source (configured-source 64 64))
;; Shared generic expansion with independently budgeted checks and selector choice.
(def budgeted-model (.cc shared-checks-model contract-source: budgeted-source))
;; Complete DAG workflow; cold/fallback/GC budgets are separate from descriptor
;; reconstruction, current-state binding and mandatory joint approval.
(def budgeted-workflow-model (.cc shared-checks-workflow-model contract-source: repeated-source))
