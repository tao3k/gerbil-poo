;;; A checked Reader workflow reuses access-site mappings across shared inheritance.
(export Service ValidService expanded-service checked-total-action checked-kernel-action service-workflow entry-workflow main joint-main)
(import (only-in :std/list/list map-in-order) :std/iter ../object
        ../prototype-map
        ../mop
        ../number
        ../slot-layout
        ../object-contract-flow
        (only-in ../io module-action)
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
(def (checked-field-action descriptor name consume (layout? #t) (eager? #t) (shapes 1))
  (def read (if layout?
    (let (site (make-slot-cache name eager?: eager? shapes: shapes)) (cut .ref/inline <> site))
    (cut .ref <> name)))
  (checked-action descriptor
    (.call observation.Observation. .bind
      read
      (lambda (amount) (lambda (candidate) (consume candidate amount))))))

;; The service path retains full refinement before total demand or consumer effects.
;; Selected-field clients can opt into deferred seeding at this same boundary.
(def (checked-total-action consume layout: (layout? #t) eager?: (eager? #t) shapes: (shapes 1))
  (checked-field-action ValidService 'total consume layout? eager? shapes))
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
;; Optional shared approval addition/removal exercises shape changes through the
;; SAME checked action, without a second loader, evaluator or validation wrapper.
;; Explicit prototype variants exercise alternating finite shapes through the same
;; C3/refinement/FUN pipeline. Capacity selects offset history only, never approval.
(def (service-workflow width layout: (layout? #f) reshape?: (reshape? #f)
  shapes: (shapes 1) variants: (variants []))
  (using ((width :~ (lambda (n) (and (fixnum? n) (>= n 0)))) (variants :~ list?))
    (let* ((recipe (.cc Service tariff: 3))
           (receivers (if (null? variants)
             (for/collect (n (in-range width)) (.o inherit: [recipe] capacity: n))
             (let (count (length variants))
               (for/collect (n (in-range width))
                 (.o inherit: [recipe (list-ref variants (modulo n count))] capacity: n)))))
           (delivered 0)
           (action (checked-total-action (lambda (_ amount)
             (set! delivered (1+ delivered)) amount) layout: layout? shapes: shapes)))
      ;; Check laziness before the first business demand, without warming it.
      (for-each (lambda (receiver)
        (unless (and (not (object-%instance receiver)) (not (object-%layout receiver)))
          (error "fresh service was prepared eagerly"))) receivers)
      ;; Standard ordered mapping retains every admission and consumer, including
      ;; the empty batch. It does not infer purity or reuse approval across owners.
      (def (stage tariff)
        (when reshape?
          (case tariff
            ((4) (.putslot! recipe 'approval ($constant-slot-spec #f)))
            ((5) (.removeslot! recipe 'approval))))
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

;; Three explicit runtime entries share standard initialized dependencies. Reader
;; bind keeps service refinement/revisions ahead of the second plugin's C3/lens
;; preparation and report; an original refusal prevents every later consumer.
;; No business module is imported or discovered merely by constructing an action.
(def (entry-workflow width layout: (layout? #f))
  (def service (module-action "clan/poo/examples/representation-service"
    'clan/poo/examples/representation-service#service-workflow))
  (def prepare (module-action "clan/poo/examples/generalized-checkout"
    'clan/poo/examples/generalized-checkout#prepare-checkout))
  (def report (module-action "clan/poo/examples/generalized-checkout"
    'clan/poo/examples/generalized-checkout#report))
  (def checkout (.call observation.Observation. .bind prepare
    (lambda (snapshot) (lambda (_request) (report (list snapshot))))))
  ((.call observation.Observation. .bind
    (lambda (_request) (service (list width layout: layout? reshape?: #t)))
    (lambda (totals) (.call observation.Observation. .map (cut vector totals <>) checkout))) []))

;; The same dynamically selected binding runs through gxi or the shared-core exe.
;; Standard time retains complete entry business/GC work; startup is charged by
;; the parent paired study, including both modules' first initialization.
(def (joint-main (width "64") (access "symbolic"))
  (using (access :~ (cut member <> '("symbolic" "indexed")))
    (finish-entry width access (time (entry-workflow (string->number width) layout: (equal? access "indexed"))))))

;; One receipt boundary is shared by both entries. Whole-process standard Gambit
;; counters include bootstrap/loading GC, unlike the inner business time form.
;; Columns: CPU, runtime wall, GC CPU, GC wall, collections, raw allocation counter.
;; The Gambit allocation counter can be negative; it is diagnostic, not a byte cost.
;; Parent process wall and portable time -p remain independent startup observations.
(def (finish-entry width access result)
  (displayln "SERVICE-WORKFLOW-OK " width " " access " " result)
  (let (stats (##process-statistics))
    (unless (= (f64vector-length stats) 20) (error "unsupported process statistics layout"))
    (display "MODULE-PROCESS ")
    (write (vector (+ (f64vector-ref stats 0) (f64vector-ref stats 1)) (f64vector-ref stats 2)
      (+ (f64vector-ref stats 3) (f64vector-ref stats 4)) (f64vector-ref stats 5)
      (f64vector-ref stats 6) (f64vector-ref stats 7)))
    (newline) (force-output)))

;; Both ordinary gxi imports and standard exe builds call this SAME entry point.
;; Timing belongs to the host time form: no loader registry, alternate evaluator
;; or build cache is implemented here. A successful marker requires all stages.
(def (main (width "64") (access "symbolic"))
  (using (access :~ (cut member <> '("symbolic" "indexed")))
    (finish-entry width access (time (service-workflow (string->number width) layout: (equal? access "indexed"))))))
