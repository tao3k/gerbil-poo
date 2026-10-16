;;; Comparable non-record raw state, controlled dependency closure and callable cooking.
(export base rate-focus fee-focus reserve-focus checks prepare-service report)
(import (only-in :gerbil/runtime/gambit vector-copy) ../object ../mop ../brace
        ../generalized-declaration ../generalized-closure ../lens-laws
        (prefix-in ../method-combination combination.)
        (prefix-in ../generalized-prototype gp.))
;; Custom vector getters/setters use functional copying; their product analogues
;; have universal Lean laws, while native checks cover supplied immutable points.
(def (vector-focus index)
  (lens-of-get-set (cut vector-ref <> index) (lambda (value raw)
    (def copy (vector-copy raw)) (vector-set! copy index value) copy)))
;; Native Lens.compose preserves the outside audit frame through nested storage.
(def outer-focus (vector-focus 0))
;; The root rate feeds a two-edge dependent chain through cooked final self.
(def rate-focus (.call Lens .compose outer-focus (vector-focus 0)))
;; Fee reads the preceding raw stage's cooked rate.
(def fee-focus (.call Lens .compose outer-focus (vector-focus 1)))
;; Reserve reads the preceding raw stage's cooked fee.
(def reserve-focus (.call Lens .compose outer-focus (vector-focus 2)))
;; Raw state has NO freshly allocated closures; full structural equality is usable.
(def base (vector (vector 0 0 0) 'audit))
;; Existing method contributions live in immutable cooking policy, outside raw state.
;; Every call still receives current units/rate/fee/reserve; no call result is cached.
(def effective (combination.prepare-standard
  [(combination.around (lambda (next units rate fee reserve) (* 2 (next))))
   (combination.primary (lambda (_ units rate fee reserve) (+ (* units rate) fee reserve)))]
  (lambda (_) (error "no primary method"))))
;; Cook a callable interface using existing demand-driven fields and method assembly.
(def cook (gp.cook-fields (list
  (cons 'rate (lambda (raw) (vector-ref (vector-ref raw 0) 0)))
  (cons 'fee (lambda (raw) (vector-ref (vector-ref raw 0) 1)))
  (cons 'reserve (lambda (raw) (vector-ref (vector-ref raw 0) 2)))
  (cons 'audit (lambda (raw) (vector-ref raw 1)))
  (cons 'charge (lambda (raw) (lambda (units)
    (effective (cons units (vector->list (vector-ref raw 0))))))))))
;; The same generalized declaration macro now feeds actual raw closure.
(def (prepare-service (rate 10))
  (.prototype GeneralizedDeclaration. (.o) cook
    (fragment rate (lens-fragment rate-focus (lambda (value _ inherited) value) rate))
    (fragment fee (lens-fragment fee-focus (lambda (value self inherited) (+ value ((self) 'rate))) 3))
    (fragment reserve (lens-fragment reserve-focus (lambda (value self inherited) (+ value ((self) 'fee))) 2))))
;; Nonempty focus values exercise all three laws on EACH visited actual raw state.
;; This receipt is finite-domain operational evidence, not a serialized Lean proof.
(def (checks)
  (map (lambda (focus) (lens-check focus '(0 3 10 13 15) sources: [outer-focus]))
    (list rate-focus fee-focus reserve-focus)))
;; Observe the closed callable interface rather than guessing closure from samples.
(def (report closed units)
  (def view (closed-interface closed))
  (list (view 'rate) (view 'fee) (view 'reserve) ((view 'charge) units) (view 'audit)))
