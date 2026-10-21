;;; A checked Reader workflow reuses access-site mappings across shared inheritance.
(export Service expanded-service checked-total-action)
(import ../object ../prototype-map ../mop ../number ../slot-layout ../object-contract-flow
        (prefix-in ../object-contract contract.)
        (prefix-in ../generalized-prototype observation.))

;; Shared inherited data remains a live registered dependency of both branches.
(def base (.o capacity: 10 tariff: 3))
;; Each branch contributes a field without copying or evaluating the shared parent.
(def left (.o inherit: [base] fee: 1))
;; A second consumer of the same parent exercises the diamond invalidation path.
(def right (.o inherit: [base] surcharge: 2))
;; Computation uses the final receiver; persistent copies rebind its field reads.
(def Service (.o self: self inherit: [left right]
  (total (+ (* (.get self capacity) (.get self tariff)) (.get self fee) (.get self surcharge)))))
;; Reuse the existing ObjectContract/refine boundary before allowing a consumer effect.
(def ValidService (contract.refine
  (.cc contract.ObjectContract. responsibilities: (.o capacity: Integer tariff: Integer)
       extra-fields: 'delegate constraints: (list Object))
  (lambda (value location)
    (if (and (>= (.get value capacity) 0) (>= (.get value tariff) 0)) []
      [(.o kind: 'negative-parameter path: location)]))))
;; One action owns one access site. FUN's existing bind threads the same admitted
;; receiver into the consumer, preserving normal exception and multiple-value behavior.
;; Every invocation still checks its contract; a layout hit is never admission evidence.
(def (checked-total-action consume)
  (def site (make-slot-cache 'total))
  (checked-action ValidService
    (.call observation.Observation. .bind
      (lambda (candidate) (.ref/inline candidate site))
      (lambda (amount) (lambda (candidate) (consume candidate amount))))))

;; A real service crosses the compact contribution bound without changing its
;; inheritance/contract protocol. Removing the five auxiliary direct fields later
;; exposes the same inherited computation and returns storage to the compact case.
;; Capacity still passes through checked-total-action before any consumer effect.
(def (expanded-service capacity)
  (let (base (.cc Service capacity: capacity tariff: 3 fee: 1 surcharge: 2))
    (object-slots-set! base (prototype-map (object-slots base) policy: 'compact))
    (.cc base region: 'north approval: #t audit: #f enabled: #t revision: 0)))
