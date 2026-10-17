;;; Capped three-service feedback ring with joint approval and callable methods.
(export base prepare-services report)
(import ../object ../mop ../brace ../generalized-declaration ../generalized-closure ../feedback-closure
        (prefix-in ./closed-declarations product.)
        (prefix-in ../generalized-prototype gp.) (prefix-in ../method-combination combination.))
;; Comparable raw data stores three allocations, joint approval and an audit frame.
(def base (vector (vector 0 0 0) #f 'audit))
;; Nested native lenses reuse functional vector replacement and composition.
(def allocation-focus (product.vector-focus 0))
;; Each focus denotes one COMPLETE component equation, not an incremental method.
(def a-focus (.call Lens .compose allocation-focus (product.vector-focus 0)))
;; B feeds A while reading the same preceding whole self as every other component.
(def b-focus (.call Lens .compose allocation-focus (product.vector-focus 1)))
;; The final edge closes the ring C → B → A → C.
(def c-focus (.call Lens .compose allocation-focus (product.vector-focus 2)))
;; Joint approval is a different focus type in the same wider raw carrier.
(def ready-focus (product.vector-focus 1))
;; Existing method policy remains outside comparable raw state. Around refuses
;; before joint approval; after closure it doubles the primary allocation charge.
(def effective (combination.prepare-standard
  [(combination.around (lambda (next units a b c ready)
      (unless ready (error "approval pending")) (* 2 (next))))
   (combination.primary (lambda (_ units a b c ready) (* units (+ a b c))))]
  (lambda (_) (error "no primary method"))))
;; Cook current raw values with existing demand-driven fields and standard methods.
(def cook (gp.cook-fields (list
  (cons 'a (lambda (raw) (vector-ref (vector-ref raw 0) 0)))
  (cons 'b (lambda (raw) (vector-ref (vector-ref raw 0) 1)))
  (cons 'c (lambda (raw) (vector-ref (vector-ref raw 0) 2)))
  (cons 'ready (lambda (raw) (vector-ref raw 1)))
  (cons 'audit (lambda (raw) (vector-ref raw 2)))
  (cons 'charge (lambda (raw) (lambda (units)
    (effective (append [units] (vector->list (vector-ref raw 0)) [(vector-ref raw 1)]))))))))
;; The feedback edge reads cooked GLOBAL self, never an already updated prefix.
;; Explicit capped natural inputs ensure this concrete ring converges from zero.
(def (prepare-services (cap 3))
  (unless (and (exact-integer? cap) (>= cap 0)) (error "natural service cap required"))
  (.prototype GeneralizedDeclaration. (.o) cook
    (fragment a (lens-fragment a-focus (lambda (cap self inherited) (min cap (+ 1 ((self) 'b)))) cap
      sources: [allocation-focus]))
    (fragment b (lens-fragment b-focus (lambda (cap self inherited) (min cap (+ 1 ((self) 'c)))) cap
      sources: [allocation-focus]))
    (fragment c (lens-fragment c-focus (lambda (cap self inherited) (min cap (+ 1 ((self) 'a)))) cap
      sources: [allocation-focus]))
    (fragment ready (lens-fragment ready-focus (lambda (cap self inherited)
      (and (= ((self) 'a) cap) (= ((self) 'b) cap) (= ((self) 'c) cap))) cap))))
;; Observe the accepted actual closure and execute a fresh combined method call.
(def (report closed units)
  (def view (closed-interface closed))
  (list (view 'a) (view 'b) (view 'c) (view 'ready) ((view 'charge) units) (view 'audit)))
