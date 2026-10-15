;;; Shared contract preparation in a cross-service atomic publication.
;;; Generalized-prototype future work: immutable closed inputs, native mixins.
(export source independent-source model cancellation shared-input prepare-shared project-shared construct)
(import ../object (prefix-in ../contract-family family.)
        (prefix-in ../declarative-metadata metadata.)
        (prefix-in ./service-metadata service.) (prefix-in ./service-bundle bundle.))
(def (cancellation invoice)
  (metadata.contract
    (metadata.predicate "consent" (match <> ([customer #t] (string? customer)) (else #f)))
    (metadata.predicate "invoice-event" (match <> ([customer tag] (and (string? customer) (string? tag))) (else #f)))
    (lambda (_ args result) (equal? result (list (car args) invoice))) (metadata.atom 'invoice)))
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
(def independent-source
  (.cc family.Source. keys: (lambda (_ __) '(reserve cancel))
    project: (lambda (key policy view) (project-shared key (prepare-shared (shared-input policy view))))
    construct: construct))
(def source
  (.mix (.cc family.methods.inputs<-shared
          shared-input: shared-input prepare-shared: prepare-shared project-shared: project-shared)
    independent-source))
;; Existing generic projections, exact-service approval reuse, dynamic cache
;; budget and atomic refusal all remain in the native staged composition chain.
(def model (.cc bundle.model contract-source: source))
