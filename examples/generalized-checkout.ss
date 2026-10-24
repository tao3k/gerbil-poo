;;; A diamond checkout composes inheritance, two lenses, effective methods and FUN.
(export protocol base root declarations prepare-checkout total report nested-protocol nested-base nested-root nested-declarations prepare-nested prepare-nested-unfused nested-report
        envelope-base envelope-root envelope-declarations prepare-envelope envelope-report bind-envelope-report prepare-envelope-items bind-envelope-items-report)
(import ../object
        (only-in ../mop define-type Lens lens-of-get-set slot-lens)
        (runtime: :clan/poo/generalized-prototype)
        (prefix-in (only-in ../generalized-prototype Observation. Protocol.
                   bind-context-observer cook-fields focus-compiler focus-protocol
                   lens-compiler observation-action observe prepare-focused-inheritance
                   prepare-inheritance sum-compiler) gp.)
        (runtime: :clan/poo/method-combination)
        (prefix-in (only-in ../method-combination item prepare-simple
                   prepare-simple-items sum) combination.))
;; Raw fields are price contributions, rebate contributions and an untouched audit.
(def base (list [] [] 'audit))
;; Replace one nested method list while preserving the other list and audit frame.
(def (set-price value raw) (list value (cadr raw) (caddr raw)))
;; The second focus updates rebates without touching price or audit.
(def (set-rebate value raw) (list (car raw) value (caddr raw)))
;; Select the raw family and its existing preparer once. Both representations
;; share demand/argument semantics; no method or unrelated field is evaluated here.
(def (sum-field getter (prepare combination.prepare-simple))
  (lambda (raw)
    (def effective (prepare combination.sum (getter raw)))
    (lambda () (effective []))))
;; Cook only the demanded method family, with standard promise sharing per raw view.
(def cooked-fields (gp.cook-fields (list (cons 'price (sum-field car)) (cons 'rebate (sum-field cadr)))))
;; Lift named demanded methods into the public callable interface. Capture the
;; field preparer once; every raw observation owns fresh per-field promises.
(def (method-cooking prepare-fields)
  (lambda (raw)
    (def fields (prepare-fields raw))
    (lambda (slot) ((fields slot)))))
;; Qualified storage uses the same higher-order interface as compact item storage.
(def cook (method-cooking cooked-fields))
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
;; Lift either local representation through the SAME service interface. Capture
;; cooking once, preserve the current metadata and keep method groups demanded.
(def (service-cooking local-cook)
  (lambda (raw)
    (def checkout (local-cook (.@ raw checkout)))
    (lambda (slot) (case slot ((price rebate) (checkout slot))
      ((service) (.@ raw service)) (else (error "unknown service view" slot))))))
;; Qualified contribution representation uses the shared native service adapter.
(def cook-service (service-cooking cook))
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
;; Retain the general per-fragment path as the public semantic/control counterpart.
(def (prepare-nested-unfused) (gp.prepare-inheritance nested-protocol nested-root nested-declarations))
;; All local updates target checkout: assemble locally, then persist one service
;; shell per stage. The public-self view is the same callable selector interface.
(def (prepare-nested)
  (gp.prepare-focused-inheritance protocol service-focus identity cook-service nested-root nested-declarations))
;; Compose finite observations of the service, retaining both audit frames and metadata.
(def (nested-report snapshot)
  (def read ((.@ gp.Observation. .map)
    (lambda (view) (list (view 'price) (view 'rebate) (view 'service)))
    (gp.observation-action snapshot nested-base 2)))
  (read nested-base))

;; A second enclosing service frame adds independent approval and tenant context.
(def envelope-base (.o (billing nested-base) (approved #t) (tenant 'eu)))
;; Compose the SAME native lenses to focus through billing into its checkout.
(def envelope-focus (.call Lens .compose (slot-lens 'billing) service-focus))
;; Extend either service cook with the SAME demanded typed approval and tenant.
;; Current metadata is read on every observation; no prior approval is retained.
(def (envelope-cooking service-cook)
  (lambda (raw)
    (def billing (service-cook (.@ raw billing)))
    (lambda (slot) (case slot ((price rebate service) (billing slot))
      ((approved) (let (value (.@ raw approved))
        (unless (boolean? value) (error "approval requires a Boolean" value)) value))
      ((tenant) (.@ raw tenant)) (else (error "unknown envelope view" slot))))))
;; Original qualified interface reuses the same envelope adapter as compact items.
(def cook-envelope (envelope-cooking cook-service))
;; Cross-service root adds a second rebate-dependent contribution after approval.
(def envelope-root (.mix nested-root))
;; Keep local declarations inspectable and inherited; a failed approval stops price.
(def (envelope-declarations node)
  (if (eq? node envelope-root)
    (list (cons 'left (lambda (self)
      (if ((self) 'approved) (+ ((self) 'rebate) ((self) 'rebate))
        (error "billing approval refused")))))
    (nested-declarations node)))
;; Select fusion explicitly. Both paths share graph, callbacks and demanded cooking;
;; the control changes only whether each fragment rewrites the enclosing lenses.
(def (prepare-envelope (fused? #t))
  (if fused?
    (gp.prepare-focused-inheritance protocol envelope-focus identity cook-envelope envelope-root envelope-declarations)
    (gp.prepare-inheritance (gp.focus-protocol protocol envelope-focus identity cook-envelope)
      envelope-root envelope-declarations)))
;; Project one current public interface, retaining the existing error on refusal.
(def (envelope-fields view)
  (list (view 'price) (view 'rebate) (view 'service) (view 'tenant) (view 'approved)))
;; Compile the fixed declaration graph once, then use each invocation's CURRENT
;; configuration as base and seed. This is code reuse, never cached admission.
(def (bind-envelope-report (fused? #t))
  ((.@ gp.Observation. .map) envelope-fields
    (gp.bind-context-observer (prepare-envelope fused?) 2 identity identity)))
;; Convenience for a one-off configuration. Repeated revisions should explicitly
;; retain bind-envelope-report while the declaration graph/callbacks stay unchanged.
(def (envelope-report raw (fused? #t))
  (envelope-fields (gp.observe (prepare-envelope fused?) raw raw 2)))

;; A known item-only raw family stores the method functions directly, exactly as
;; Lean SimpleMethods.items. No qualifier descriptor or per-item slot cache is
;; needed. This is a distinct raw representation, not an unvalidated mixed group.
(def (wrap-item fragment self parent)
  (cons (lambda () (fragment self)) (parent)))
;; Reuse the same higher-order field/interface adapters with the item preparer.
;; Demand and sharing stay identical while qualifier/slot-cache work disappears.
(def item-fields (gp.cook-fields (list
  (cons 'price (sum-field car combination.prepare-simple-items))
  (cons 'rebate (sum-field cadr combination.prepare-simple-items)))))
;; Compact raw methods expose the same public callable view through that adapter.
(def cook-items (method-cooking item-fields))
;; Only wrapper/cooking representation changes; C3 declarations/lenses are shared.
(def item-protocol (.cc gp.Protocol. cook: cook-items compile:
  (gp.sum-compiler (gp.lens-compiler car set-price wrap-item)
    (gp.lens-compiler cadr set-rebate wrap-item))))
;; Compose compact local cooking with the existing shared service adapter.
(def cook-item-service (service-cooking cook-items))
;; Reuse precisely the same typed policy/tenant boundary for both representations.
(def cook-item-envelope (envelope-cooking cook-item-service))
;; Explicit item-only factory: canonical empty checkout seeds or function-list raw
;; states, pure declarations, fixed item qualifiers. Mixed/around storage uses the
;; original prepare-envelope. This reuses C3, focused assembly, lenses and FUN.
(def (prepare-envelope-items)
  (gp.prepare-focused-inheritance item-protocol envelope-focus identity
    cook-item-envelope envelope-root envelope-declarations))
;; Reusable current-context report for that declared homogeneous representation.
;; Graph/callback changes need a new factory; current approval is never cached.
(def (bind-envelope-items-report)
  ((.@ gp.Observation. .map) envelope-fields
    (gp.bind-context-observer (prepare-envelope-items) 2 identity identity)))
