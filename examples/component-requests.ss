;;; Competing staged services share an authoritative component publication.
(export start stage policies build-group value)
(import ../object ../mop ../brace ../lens-laws
        (prefix-in ../component-publication publication.)
        (prefix-in ../construction-cache cache.)
        (prefix-in ./component-membership initial.) (prefix-in ./component-rounds service.))
;; Both services have independent current approval metadata.
(def (policies) [(.o (allowed #t) (limit 30)) (.o (allowed #t) (limit 30))])
;; Existing complete source equations and lawful fixed lenses close every SCC.
(def build-group service.build-group)
;; Observations resolve the current SCC receipt, never the staged predecessor.
(def value service.value)
;; Begin from an actual approved compact graph, refusing an invalid initial source.
(def (start approvals)
  (defvalues (initial failure) (initial.publish #f (service.source 3 4) (car approvals) (.cc cache.Builder.)))
  (when failure (raise failure))
  (unless ((service.admit approvals) #f initial) (error "initial joint component approval refused"))
  (publication.publication initial))
;; Stage work without executing constructors. Additional admission composes with
;; BOTH current service decisions on the exact candidate; it may model a competing
;; coordinator request for deterministic interleaving controls. Pure callbacks are
;; the production discipline; coordinator effects are explicit test scheduling.
(def (stage owner phase inputs approvals builder extra-admit: (extra-admit (lambda (_ __) #t)))
  (publication.stage owner (service.contributions phase inputs) build-group
    (lambda (old candidate) (and ((service.admit approvals) old candidate) (extra-admit old candidate)))
    guards: [(lens-check (.lens) approvals sources: approvals)] builder: builder))
