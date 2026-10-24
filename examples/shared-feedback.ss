;;; Shared quota → cross-service feedback ring → joint approval and fresh revision.
(export base prepare-services admit report revise)
(import (only-in :std/number/misc uint?)
        ../object
        ../mop
        ../brace
        ../generalized-declaration
        ../generalized-closure
        ../feedback-revision
        (runtime: :clan/poo/examples/closed-declarations)
        (prefix-in (only-in ./closed-declarations vector-focus) product.)
        (runtime: :clan/poo/generalized-prototype)
        (prefix-in (only-in ../generalized-prototype cook-fields) gp.)
        (runtime: :clan/poo/method-combination)
        (prefix-in (only-in ../method-combination around prepare-standard primary) combination.))
;; Two service groups share one computed quota, approval and independent audit.
(def base (vector 0 (vector 0 0) (vector 0 0) #f 'audit))
;; Both service groups depend on this same raw quota node, not copied policy reads.
(def quota-focus (product.vector-focus 0))
;; Outer service lenses permit nested persistent updates with an unchanged sibling.
(def left-focus (product.vector-focus 1))
;; The right service is a separate branch sharing quota and approval.
(def right-focus (product.vector-focus 2))
;; Build one nested scalar focus with the existing Lens composition operation.
(def (member-focus outer index) (.call Lens .compose outer (product.vector-focus index)))
;; Joint readiness is a distinct Boolean component of the whole feedback state.
(def ready-focus (product.vector-focus 3))
;; Existing primary/around policy handles fresh units and per-service multipliers.
(def effective (combination.prepare-standard
  [(combination.around (lambda (next units allocation factor ready)
      (unless ready (error "joint approval pending")) (* factor (next))))
   (combination.primary (lambda (_ units allocation factor ready) (* units allocation)))]
  (lambda (_) (error "no primary method"))))
;; Raw dependency reads and service method binding share the same cooked snapshot.
(def cook (gp.cook-fields (append
  [(cons 'quota (lambda (raw) (vector-ref raw 0)))
   (cons 'a (lambda (raw) (vector-ref (vector-ref raw 1) 0)))
   (cons 'b (lambda (raw) (vector-ref (vector-ref raw 1) 1)))
   (cons 'c (lambda (raw) (vector-ref (vector-ref raw 2) 0)))
   (cons 'd (lambda (raw) (vector-ref (vector-ref raw 2) 1)))
   (cons 'ready (lambda (raw) (vector-ref raw 3)))
   (cons 'audit (lambda (raw) (vector-ref raw 4)))]
  (map (lambda (key index factor) (cons key (lambda (raw)
    (lambda (units) (effective [units (apply + (vector->list (vector-ref raw index))) factor (vector-ref raw 3)])))))
    '(left right) '(1 2) '(2 3)))))
;; Read the policy once into a complete shared quota equation. Register policy,
;; approval and composed-lens sources; changed inputs require fresh preparation.
(def (prepare-services policy approval)
  (def quota (.@ policy quota))
  (unless (and (uint? quota) (uint? (.@ policy limit))) (error "natural shared quota and joint limit required"))
  (.prototype GeneralizedDeclaration. policy cook
    (fragment quota (lens-fragment quota-focus (lambda (value _ inherited) value) quota sources: [approval]))
    (fragment a (lens-fragment (member-focus left-focus 0)
      (lambda (_ self inherited) (min ((self) 'quota) (+ 1 ((self) 'b)))) #f sources: [left-focus]))
    (fragment b (lens-fragment (member-focus left-focus 1)
      (lambda (_ self inherited) (min ((self) 'quota) (+ 1 ((self) 'c)))) #f sources: [left-focus]))
    (fragment c (lens-fragment (member-focus right-focus 0)
      (lambda (_ self inherited) (min ((self) 'quota) (+ 1 ((self) 'd)))) #f sources: [right-focus]))
    (fragment d (lens-fragment (member-focus right-focus 1)
      (lambda (_ self inherited) (min ((self) 'quota) (+ 1 ((self) 'a)))) #f sources: [right-focus]))
    (fragment ready (lens-fragment ready-focus (lambda (_ self inherited)
      (and (= ((self) 'a) ((self) 'quota)) (= ((self) 'b) ((self) 'quota))
           (= ((self) 'c) ((self) 'quota)) (= ((self) 'd) ((self) 'quota)))) #f))))
;; Approve the EXACT closed candidate against current shared policy and permission.
;; Both objects are registered preparation sources, guarded through this callback.
(def (admit policy approval)
  (lambda (_ candidate)
    (def view (closed-interface candidate))
    (and (eq? (.@ approval allowed) #t) (view 'ready) (= (view 'quota) (.@ policy quota))
      (<= (+ (view 'a) (view 'b) (view 'c) (view 'd)) (.@ policy limit)))))
;; Observe both service methods on the same accepted closed family and fresh units.
(def (report candidate units)
  (def view (closed-interface candidate))
  (def left ((view 'left) units)) (def right ((view 'right) units))
  (list (view 'quota) left right (+ left right) (view 'ready) (view 'audit)))
;; Re-elaborate changed sources, warm-start from old raw only, and publish once.
(def (revise old policy approval (budget 6))
  (try (publish-feedback-revision old (prepare-services policy approval) base budget (admit policy approval))
    (catch (failure) (values old failure))))
