;;; Heterogeneous fragments on nested vectors and on a procedure carrier.
(export base rate-part prepare-service report callable-service rate-focus)
(import (only-in :gerbil/runtime/gambit vector-copy) ../object ../mop ../brace ../declaration
        ../generalized-declaration (prefix-in ../generalized-prototype gp.)
        (prefix-in ../method-combination combination.))
;; A functional native vector lens copies before update, preserving caller storage.
(def (vector-focus index)
  (lens-of-get-set (cut vector-ref <> index)
    (lambda (value raw) (def result (vector-copy raw)) (vector-set! result index value) result)))
;; Compose the same existing Lens protocol through two non-record vector levels.
(def shell-focus (vector-focus 0))
;; Scalar rate, scalar fee and qualified methods have DIFFERENT focus types.
(def rate-focus (.call Lens .compose shell-focus (vector-focus 0)))
;; The dependent fee is computed from the prior stage's cooked self.
(def fee-focus (.call Lens .compose shell-focus (vector-focus 1)))
;; Method accumulation uses the same carrier as the two scalar fragments.
(def methods-focus (.call Lens .compose shell-focus (vector-focus 2)))
;; Preserve independent outer audit data across every functional update.
(def base (vector (vector 0 0 []) 'audit))
;; Scalar overwrite deliberately does not demand the inherited focused value.
(def rate-part (lens-fragment rate-focus (lambda (amount _ inherited) amount) 10))
;; Existing qualified method preparation runs only when the public field is demanded.
(def fields (gp.cook-fields
  (list (cons 'rate (lambda (raw) (vector-ref (vector-ref raw 0) 0)))
    (cons 'fee (lambda (raw) (vector-ref (vector-ref raw 0) 1)))
    (cons 'charge (lambda (raw) (combination.prepare-standard
      (vector-ref (vector-ref raw 0) 2) (lambda (_) (error "no declared primary")))))
    (cons 'audit (lambda (raw) (vector-ref raw 1))))))
;; A callable cooked interface shares only demanded preparations for this raw value.
(def (cook raw) (fields raw))
;; A method producer receives the same delayed cooked self as scalar wrappers.
(def (wrap-method producer self inherited) (cons (producer self) (inherited)))
;; Inherited nonlocal finalization checks current approval before ANY raw assembly.
(def expander (.o (:: @ GeneralizedDeclaration.)
  (finalize-declarations (inherited) (lambda (context entries)
    (unless (.@ context approved) (error "generalized declaration refused"))
    ((inherited) context entries)))))
;; The common declaration macro accepts named descriptors and ordinary splicing.
;; Three finite steps suffice for this triangular example, not every prototype.
(def (prepare-service context (rate-source rate-part))
  (.prototype expander context cook
    (fragment rate rate-source)
    (fragment fee (lens-fragment fee-focus
      (lambda (amount self inherited) (+ amount ((self) 'rate))) 3))
    ,@[(declaration-form 'fragment 'around (lens-fragment methods-focus wrap-method
        (lambda (_) (combination.around (lambda (next units) (* 2 (next)))))))
       (declaration-form 'fragment 'primary (lens-fragment methods-focus wrap-method
        (lambda (self) (combination.primary (lambda (_ units)
          (+ (* units ((self) 'rate)) ((self) 'fee)))))))]))
;; Observe values and actual combined method calls while retaining the audit frame.
(def (report view units) (list (view 'rate) (view 'fee) ((view 'charge) [units]) (view 'audit)))
;; The SAME protocol/macro works when raw and cooked are procedures, with no fields.
(def (callable-service)
  (def focus (lens-of-get-set identity (lambda (value _) value)))
  (def wrapper (lambda (factor _ inherited)
    (def parent (inherited)) (lambda (input) (+ (* factor input) (parent input)))))
  (.prototype GeneralizedDeclaration. (.o) identity
    (fragment first (lens-fragment focus wrapper 2))
    (fragment second (lens-fragment focus wrapper 3))))
