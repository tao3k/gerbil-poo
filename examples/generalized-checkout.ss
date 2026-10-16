;;; A diamond checkout composes inheritance, two lenses, effective methods and FUN.
(export protocol base root declarations prepare-checkout total report nested-protocol nested-base nested-root nested-declarations prepare-nested nested-report)
(import ../object (only-in ../mop define-type Lens lens-of-get-set slot-lens) (prefix-in ../generalized-prototype gp.)
        (prefix-in ../method-combination combination.))
;; Raw fields are price contributions, rebate contributions and an untouched audit.
(def base (list [] [] 'audit))
;; Replace one nested method list while preserving the other list and audit frame.
(def (set-price value raw) (list value (cadr raw) (caddr raw)))
;; The second focus updates rebates without touching price or audit.
(def (set-rebate value raw) (list (car raw) value (caddr raw)))
;; Prepare a selected sum field without evaluating its methods or the other field.
(def (sum-field getter)
  (lambda (raw)
    (def effective (combination.prepare-simple combination.sum (getter raw)))
    (lambda () (effective []))))
;; Cook only the demanded method family, with standard promise sharing per raw view.
(def cooked-fields (gp.cook-fields (list (cons 'price (sum-field car)) (cons 'rebate (sum-field cadr)))))
;; Preserve the original callable interface while deferring its two prepared methods.
(def (cook raw)
  (def fields (cooked-fields raw))
  (lambda (slot) ((fields slot))))
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

;; A functional lens isolates the checkout inside an immutable native service object.
(def service-focus (slot-lens 'checkout))
;; Existing Lens.compose focuses through object storage into each method family.
(def price-focus (.call Lens .compose service-focus (lens-of-get-set car set-price)))
;; Independent nested focus keeps the enclosing service audit and checkout audit.
(def rebate-focus (.call Lens .compose service-focus (lens-of-get-set cadr set-rebate)))
;; Broader cooked view combines dependent checkout calls and untouched service metadata.
(def (cook-service raw)
  (def checkout (cook (.@ raw checkout)))
  (lambda (slot) (case slot ((price rebate) (checkout slot))
    ((service) (.@ raw service)) (else (error "unknown service view" slot)))))
;; Nested raw/cooked adaptation uses native POO slots plus the same existing wrappers.
(def nested-protocol (.cc gp.Protocol. cook: cook-service compile:
  (gp.sum-compiler (gp.focus-compiler price-focus wrap) (gp.focus-compiler rebate-focus wrap))))
;; Persistent service seed includes two independent audit frames.
(def nested-base (.o (checkout base) (service 'billing)))
;; A second declaration set reads final rebate repeatedly to exercise shared cooking.
(def nested-root (.mix left right))
;; Most-specific service pricing shares one cooked self, not one result across seeds.
(def (nested-declarations node)
  (if (eq? node nested-root)
    (list (cons 'left (lambda (self) (+ ((self) 'rebate) ((self) 'rebate) ((self) 'rebate)))))
    (declarations node)))
;; Compile the new service graph with inherited fragments and nested focus hooks.
(def (prepare-nested) (gp.prepare-inheritance nested-protocol nested-root nested-declarations))
;; Compose finite observations of the service, retaining both audit frames and metadata.
(def (nested-report snapshot)
  (def read ((.@ gp.Observation. .map)
    (lambda (view) (list (view 'price) (view 'rebate) (view 'service)))
    (gp.observation-action snapshot nested-base 2)))
  (read nested-base))
