;;; Two recursively closed non-record services in one audited wider carrier.
(export base left-focus right-focus stages cook publish)
(import ../object ../mop ../lens-laws ../focused-closure
        (prefix-in ./closed-declarations service.))
;; The wider computation has two comparable service states and one shared frame.
;; Persistent setters never mutate these nested vectors or the shared base.
(def base (vector service.base service.base '(tenant audit)))
;; Separate product components are independent, with universal product-lens
;; proofs in the paired Lean example; native law checks remain finite controls.
(def left-focus (service.vector-focus 0))
;; The other service uses the same child carrier/compiler but a different policy.
(def right-focus (service.vector-focus 1))
;; Reuse local fragment closure and custom outer lenses; actual settled children
;; are automatically added to each stage's finite lens replacement domain.
(def (stages (left-rate 10) (right-rate 20))
  (map (lambda (focus rate)
    (closure-focus (service.prepare-service rate) (lens-check focus [service.base])
      service.base 4 checks: (service.checks)))
    (list left-focus right-focus) (list left-rate right-rate)))
;; Cook the complete family only after BOTH final projected equations pass.
;; Existing child method combinations remain callable on every fresh units input.
(def (cook whole)
  (def left (service.cook (vector-ref whole 0)))
  (def right (service.cook (vector-ref whole 1)))
  (lambda (units)
    (def a ((left 'charge) units)) (def b ((right 'charge) units))
    (list a b (+ a b) (vector-ref whole 2))))
;; One publication boundary retains the exact old cooked family on ANY refusal.
(def (publish old (seed base))
  (publish-focused-closures old (stages) seed cook))
