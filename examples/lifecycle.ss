;;; Functional TODO chain: checked classes, nested optics and receiver-local fallback.
(export Account Service make-service revise-service report revision-action)
(import ../object
        ../mop
        ../number
        ../brace
        (only-in ../type Symbol)
        (runtime: :clan/poo/fun)
        (prefix-in (only-in :clan/poo/fun Observation.) fun.))
;; Typed fields are checked before this construction hook enforces the cross-field law.
(define-type (Account @ Class.)
  slots: =>.+ {capacity: {type: Integer} used: {type: Integer}}
  .instantiate: (lambda (value)
    (unless (<= 0 (.@ value used) (.@ value capacity)) (error "invalid account capacity")) value))
;; The outer descriptor composes the existing Account type and current tenant metadata.
(define-type (Service @ Class.)
  slots: =>.+ {account: {type: Account} tenant: {type: Symbol}})
;; Validate both layers before attaching an ordinary lazy delegation prototype.
;; The external source remains a thunk; no I/O or remote method runs at construction.
(def (make-service capacity used tenant delegate)
  (def account (make-instance Account capacity: capacity used: used))
  (.mix (make-instance Service account: account tenant: tenant) (fallback-to delegate)))
;; Persistently revise a nested component and re-admit its cross-field constraint
;; before validating the enclosing service. Failure leaves the caller's old value.
(def (revise-service service capacity tenant)
  (def candidate (.call (.lens account capacity) .set capacity service))
  (def account (instantiate Account (.@ candidate account)))
  (instantiate Service (.call (.lens tenant) .set tenant (.cc candidate account: account))))
;; Resolve a delegated function lazily, then pass the CURRENT tenant on every call.
;; A cached delegate or method is not a cached policy/result for an older tenant.
(def (report service)
  (list (.call (.lens account capacity) .get service) (.@ (.@ service account) used)
    (.@ service tenant) ((.@ service quota) (.@ service tenant))))
;; Native Reader/FUN composition stops before report/delegation on any revision error.
(def (revision-action capacity tenant)
  (.call fun.Observation. .map report (lambda (service) (revise-service service capacity tenant))))
