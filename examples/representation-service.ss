;;; A checked Reader workflow reuses access-site mappings across shared inheritance.
(export Service expanded-service checked-total-action checked-kernel-action service-workflow main)
(import (only-in :std/list/list map-in-order) :std/iter ../object
        ../prototype-map
        ../mop
        ../number
        ../slot-layout
        ../object-contract-flow
        (prefix-in ../object-contract contract.)
        (runtime: :clan/poo/generalized-prototype)
        (prefix-in (only-in ../generalized-prototype Observation.) observation.))

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
(def (checked-field-action descriptor name consume (layout? #t))
  (def read (if layout?
    (let (site (make-slot-cache name)) (cut .ref/inline <> site))
    (cut .ref <> name)))
  (checked-action descriptor
    (.call observation.Observation. .bind
      read
      (lambda (amount) (lambda (candidate) (consume candidate amount))))))

;; The service path retains full refinement before total demand or consumer effects.
(def (checked-total-action consume layout: (layout? #t))
  (checked-field-action ValidService 'total consume layout?))
;; Inspect an opaque pinned hook through the same Reader/FUN boundary. This does
;; not demand unrelated service metadata or authorize arbitrary recursive fields.
(def (checked-kernel-action consume) (checked-field-action Object 'compute-slot consume))

;; A real service crosses the compact contribution bound without changing its
;; inheritance/contract protocol. Removing the five auxiliary direct fields later
;; exposes the same inherited computation and returns storage to the compact case.
;; Capacity still passes through checked-total-action before any consumer effect.
(def (expanded-service capacity)
  (let (base (.cc Service capacity: capacity tariff: 3 fee: 1 surcharge: 2))
    (object-slots-set! base (prototype-map (object-slots base) policy: 'compact))
    (.cc base region: 'north approval: #t audit: #f enabled: #t revision: 0)))


;; One finite downstream lifecycle shares a recipe but never evaluated child
;; caches. Explicit symbolic access is appropriate for this one-shot workload;
;; indexed access remains selectable for a directly comparable complete trace.
;; Supported source revisions invalidate every child; refused refinement runs no
;; consumer, and recovery requires a fresh successful demand, not a cached error.
(def (service-workflow width layout: (layout? #f))
  (using (width :~ (lambda (n) (and (fixnum? n) (>= n 0))))
    (let* ((recipe (.cc Service tariff: 3))
           (receivers (for/collect (n (in-range width)) (.o inherit: [recipe] capacity: n)))
           (delivered 0)
           (action (checked-total-action (lambda (_ amount)
             (set! delivered (1+ delivered)) amount) layout: layout?)))
      ;; Check laziness before the first business demand, without warming it.
      (for-each (lambda (receiver)
        (unless (and (not (object-%instance receiver)) (not (object-%layout receiver)))
          (error "fresh service was prepared eagerly"))) receivers)
      ;; Standard ordered mapping retains every admission and consumer, including
      ;; the empty batch. It does not infer purity or reuse approval across owners.
      (def (stage tariff)
        (.putslot! recipe 'tariff ($constant-slot-spec tariff))
        (let ((total (apply + (map-in-order action receivers)))
              (expected (+ (* 3 width) (* tariff (/ (* width (1- width)) 2)))))
          (unless (= total expected) (error "service batch oracle" tariff total))
          (unless layout?
            (for-each (lambda (receiver)
              (when (object-%layout receiver) (error "symbolic service prepared a vector"))) receivers))
          total))
      (let* ((first (stage 3)) (revised (stage 4)))
        (.putslot! recipe 'tariff ($constant-slot-spec -1))
        (when (pair? receivers)
          (let* ((before delivered) (cause (with-catch identity (cut action (car receivers)))))
            (unless (and (TypeError? cause) (= before delivered))
              (error "refused service delivered a consumer"))))
        (let (recovered (stage 5))
          (unless (= delivered (* 3 width)) (error "service delivery count" delivered))
          (vector first revised recovered delivered))))))

;; Both ordinary gxi imports and standard exe builds call this SAME entry point.
;; Timing belongs to the host time form: no loader registry, alternate evaluator
;; or build cache is implemented here. A successful marker requires all stages.
(def (main (width "64") (access "symbolic"))
  (using (access :~ (cut member <> '("symbolic" "indexed")))
    (let (result (time (service-workflow (string->number width) layout: (equal? access "indexed"))))
      (displayln "SERVICE-WORKFLOW-OK " width " " access " " result)
      (force-output))))
