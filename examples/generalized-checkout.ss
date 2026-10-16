;;; A diamond checkout composes inheritance, two lenses, effective methods and FUN.
(export protocol base root declarations prepare-checkout total report)
(import ../object (only-in ../mop define-type) (prefix-in ../generalized-prototype gp.)
        (prefix-in ../method-combination combination.))
;; Raw fields are price contributions, rebate contributions and an untouched audit.
(def base (list [] [] 'audit))
;; Replace one nested method list while preserving the other list and audit frame.
(def (set-price value raw) (list value (cadr raw) (caddr raw)))
;; The second focus updates rebates without touching price or audit.
(def (set-rebate value raw) (list (car raw) value (caddr raw)))
;; Cook once per demanded self: precompile both existing sum method combinations.
(def (cook raw)
  (def price (combination.prepare-simple combination.sum (car raw)))
  (def rebate (combination.prepare-simple combination.sum (cadr raw)))
  (lambda (slot) (case slot ((price) (price [])) ((rebate) (rebate []))
    (else (error "unknown checkout observation" slot)))))
;; Each fragment contributes an existing item; inherited contributions stay ordered.
(def (wrap fragment self parent)
  (cons (combination.item (lambda () (fragment self))) (parent)))
;; Two independently reusable lens compilers share the raw carrier and cooked self.
(def protocol (.cc gp.Protocol. cook: cook compile:
  (gp.sum-compiler (gp.lens-compiler car set-price wrap)
    (gp.lens-compiler cadr set-rebate wrap))))
;; Shared foundation is inherited exactly once in the native C3 diamond.
(def foundation (.o))
;; Left service adds a base price above the shared foundation.
(def left (.mix foundation))
;; Right service independently adds another price above the same foundation.
(def right (.mix foundation))
;; Joint checkout keeps local precedence left then right, followed by foundation.
(def root (.mix left right))
;; Local contributions remain separate from inherited lookup; root price uses final
;; cooked rebate, exercising self dependence without a recursive Scheme knot.
(def (declarations node)
  (cond ((eq? node root) (list (cons 'left (lambda (self) ((self) 'rebate)))))
        ((eq? node left) (list (cons 'left (lambda (_) 10))))
        ((eq? node right) (list (cons 'left (lambda (_) 20))))
        ((eq? node foundation) (list (cons 'right (lambda (_) 3))))
        (else (error "unknown checkout ancestor"))))
;; Fresh preparation captures C3 order and compiles hooks, independently of Lean.
(def (prepare-checkout) (gp.prepare-inheritance protocol root declarations))
;; Demand only price from a finite public observation; depth two reaches 33.
(def (total snapshot depth) ((gp.observe snapshot base base depth) 'price))
;; Compose two observations with native FUN bind/map and the exact same raw seed.
(def (report snapshot)
  (def action ((.@ gp.Observation. .bind) (gp.observation-action snapshot base 1)
    (lambda (first) ((.@ gp.Observation. .map)
      (lambda (second) (list (first 'price) (second 'price) (second 'rebate)))
      (gp.observation-action snapshot base 2)))))
  (action base))
