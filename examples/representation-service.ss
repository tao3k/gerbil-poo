;;; A checked Reader workflow reuses access-site mappings across shared inheritance.
(export value-storage-workflow Service ValidService expanded-service checked-total-action checked-kernel-action service-workflow removal-workflow reflection-workflow override-workflow composition-workflow catalog-workflow admission-workflow symbolic-edit-workflow declaration-source-workflow declaration-type-workflow topology-workflow replay-workflow entry-workflow main joint-main)
(import :std/error (only-in ../slot-observation %call-with-recorded-slot-reads) (only-in ../reflection read-slot write-slot!) (only-in :std/list/list map-in-order) :std/iter ../object
        ../prototype-map
        ../mop
        ../number
        ../slot-layout
        ../object-contract
        (only-in ../io module-action)
        (prefix-in ../object-contract contract.)
        (runtime: :clan/poo/fun)
        (prefix-in (only-in :clan/poo/fun Observation.) fun.))

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
(def (checked-field-action descriptor name consume (layout? #t) (shapes 1))
  (def read (if layout?
    (let (site (make-slot-cache name shapes: shapes)) (cut .ref/inline <> site))
    (cut .ref <> name)))
  (checked-action descriptor
    (.call fun.Observation. .bind
      read
      (lambda (amount) (lambda (candidate) (consume candidate amount))))))

;; The service path retains full refinement before total demand or consumer effects.
;; Selected fields share the receiver's ordinary lazy value authority.
(def (checked-total-action consume layout: (layout? #t) shapes: (shapes 1))
  (checked-field-action ValidService 'total consume layout? shapes))
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

;; Duplicate local tariff methods, sparse deletion/reinsertion and restoration
;; exercise the same C3/contract/Reader chain on shared descendants. The removal
;; argument admits an existing whole-specification replacement for paired costs;
;; production callers use .removeslot!, with no alternate cache or slot engine.
(def (removal-workflow width remove: (remove .removeslot!) policy: (policy 'tree))
  (using ((width :~ (lambda (n) (and (fixnum? n) (>= n 0)))) (remove :~ procedure?))
    (let* ((callback (lambda (x) (+ x 1)))
           (auxiliary (for/collect (n (in-range width))
             (cons (string->symbol (string-append "aux-" (number->string n))) ($constant-slot-spec n))))
           (specs (append auxiliary
             (list (cons 'callback ($constant-slot-spec callback)) (cons 'enabled ($constant-slot-spec #f))
               (cons 'tariff ($constant-slot-spec 7))
               (cons 'tariff ($computed-slot-spec (lambda (_ next) (+ 1 (next))))))))
           (recipe (make-object supers: (list Service) slots: (prototype-map specs policy: policy)))
           (receivers (list (.o inherit: [recipe] capacity: 2) (.o inherit: [recipe] capacity: 4)))
           (delivered 0)
           (action (checked-total-action (lambda (_ amount) (set! delivered (1+ delivered)) amount))))
      ;; One shared action owns validation, static demand and consumer effects.
      (def (observe expected)
        (let (total (apply + (map-in-order action receivers)))
          (unless (= total expected) (error "indexed removal service oracle" total expected)) total))
      (def initial (object-slots recipe))
      (observe 54)
      (remove recipe 'tariff) (observe 24)
      (.putslot! recipe 'tariff ($constant-slot-spec 4)) (observe 30)
      (when (pair? auxiliary) (remove recipe (caar auxiliary)))
      (.putslot! recipe 'tariff ($constant-slot-spec -1))
      (let ((before delivered) (cause (with-catch identity (cut action (car receivers)))))
        (unless (and (TypeError? cause) (= before delivered)) (error "refused removal consumer")))
      (remove recipe 'tariff) (observe 24)
      (object-slots-set! recipe initial) (observe 54)
      (unless (and (= delivered 10) (eq? (.get recipe callback) callback) (not (.get recipe enabled)))
        (error "indexed removal payload or delivery oracle"))
      (vector 54 24 30 24 54 delivered))))

;; A schema presenter may edit its own names without changing shared recipes.
;; Borrowed internal enumeration still crosses the same names observation and
;; checked Reader boundary; inspection is a normal alist consumer, not a loader.
(def (reflection-workflow width inspect: (inspect .alist) slots: (slots '()))
  (using ((width :~ (lambda (n) (and (fixnum? n) (>= n 0)))) (inspect :~ procedure?) (slots :~ list?))
    (let* ((callback (lambda (x) (+ x 1)))
           (extra (for/collect (n (in-range width))
             (cons (string->symbol (string-append "visible-" (number->string n))) ($constant-slot-spec n))))
           (recipe (make-object supers: (list Service) slots: (append extra slots
             (list (cons 'callback ($constant-slot-spec callback)) (cons 'enabled ($constant-slot-spec #f)))))))
      (reflection-publication recipe callback inspect))))

;; One existing checked pipeline serves ordinary and composed persistent recipes.
;; Sharing specifications never shares receivers, evidence or successful results.
(def (reflection-publication recipe callback inspect)
    (let* ((receivers (list (.o inherit: [recipe] capacity: 2) (.o inherit: [recipe] capacity: 4)))
           (delivered 0)
           (action (checked-total-action
             (lambda (candidate amount)
               (let (fields (inspect candidate))
                 (unless (and (eq? (cdr (assq 'callback fields)) callback)
                              (not (cdr (assq 'enabled fields)))
                              (= (cdr (assq 'total fields)) amount))
                   (error "reflection payload oracle")))
               (set! delivered (1+ delivered)) amount))))
      ;; Names require structural preparation, never eager business evaluation.
      (let* ((expected (.all-slots recipe)) (client (.all-slots recipe)))
        (unless (eq? (.ref/cached recipe 'total (lambda () 'not-forced)) 'not-forced)
          (error "reflection forced a lazy total"))
        (set-car! client 'client-only)
        (unless (equal? (.all-slots recipe) expected) (error "public names changed the cache")))
      ;; The same validated consumers cover shape changes, refusal and retry.
      (let (first (apply + (map-in-order action receivers)))
        (.putslot! recipe 'approval ($constant-slot-spec #f))
        (.putslot! recipe 'tariff ($constant-slot-spec 4))
        (let (second (apply + (map-in-order action receivers)))
          (.putslot! recipe 'tariff ($constant-slot-spec -1))
          (let ((before delivered) (cause (with-catch identity (cut action (car receivers)))))
            (unless (and (TypeError? cause) (= before delivered)) (error "reflection refused consumer")))
          (.removeslot! recipe 'approval)
          (.putslot! recipe 'tariff ($constant-slot-spec 5))
          (let (third (apply + (map-in-order action receivers)))
            (unless (equal? (vector first second third delivered) '#(24 30 36 6))
              (error "reflection revision oracle"))
            (vector first second third delivered))))))

;; Compose owned immutable specifications with a live shared service. The override
;; is deliberately warmed and assigned an instance-only total: neither cache nor
;; assignment belongs to the newly composed recipe. Both storage policies use the
;; SAME refinement/FUN/IO revision/refusal/retry pipeline above.
(def (composition-workflow width compose: (compose .+) policy: (policy 'tree))
  (using ((width :~ (lambda (n) (and (fixnum? n) (>= n 0))))
          (compose :~ procedure?) (policy :~ (one-of tree compact)))
    (def callback (lambda (x) (+ x 1)))
    (def override (make-object
      slots: (prototype-map (for/collect (n (in-range width))
        (cons (string->symbol (string-append "visible-" (number->string n))) ($constant-slot-spec n))) policy: policy)
      defaults: (prototype-map (list (cons 'callback callback) (cons 'enabled #f)) policy: policy)))
    (.put! override 'total -999)
    (.ref/inline override (make-slot-cache 'callback))
    (reflection-publication (compose Service override) callback .alist)))

;; Capture a finite typed catalog once, then compose fresh receivers from its
;; immutable root or an owned public recapture. Descriptor objects remain shared
;; invalidation sources. The existing checked publication pipeline covers module
;; entry, refinement, FUN binding, live revisions, refusal and corrected retry.
(def (catalog-workflow width recapture?: (recapture? #f) policy: (policy 'tree) inspect: (inspect .alist) shared?: (shared? #f))
  (using ((width :~ (lambda (n) (and (fixnum? n) (>= n 0))))
          (recapture? :~ boolean?) (shared? :~ boolean?) (policy :~ (one-of tree compact)) (inspect :~ procedure?))
    (def callback (lambda (x) (+ x 1)))
    (def input (append
      (list (cons 'callback (.new Slot type: (Fun Integer <- Integer) constant: callback))
            (cons 'enabled (.new Slot type: Bool constant: #f)))
      (for/collect (n (in-range width))
        (cons (make-symbol "visible-" n) (.new Slot type: Integer constant: n)))))
    (def template (make-object declarations: (prototype-map input policy: policy)))
    ;; Public edits cannot change membership, payload identity or inherited layout.
    (set-car! (car input) 'client-only)
    (def catalog (object-declarations template))
    (set-car! (car catalog) 'client-only)
    ;; The optional diamond splits overlapping catalogs across independent owners;
    ;; final-self values, first-descriptor priority and shared revision edges remain.
    (def shared-entries (and shared? (object-declarations template)))
    (def shared (if shared?
      (.mix (make-object supers: [template] declarations: (prototype-map (take shared-entries 2) policy: policy))
            (make-object supers: [template] declarations: (prototype-map (reverse shared-entries) policy: policy)))
      template))
    (def recipe (if recapture?
      (make-object supers: (if shared? [Service shared] [Service]) declarations:
        (prototype-map (object-declarations shared) policy: policy))
      (.+ Service shared)))
    (reflection-publication recipe callback inspect)))

;; A shared descriptor may invalidate both service branches during its own check.
;; Reader/FUN publication sees the refusal before consumer effects. Repair uses
;; the existing source protocol; a fresh request and checked write then succeed.
(def (admission-workflow)
  (def slot (.new Slot type: Integer default: 7))
  (def armed? #f)
  (def original (.ref slot '.type))
  (.putslot! slot '.type ($constant-slot-spec
    (.cc original '.slot.check (lambda (metadata name candidate)
      (when armed? (.putslot! slot 'hidden ($constant-slot-spec #t)))
      (.call original .slot.check metadata name candidate)))))
  (def base (make-object declarations: (list (cons 'value slot))))
  (def recipe (.mix Service (.mix base) (.mix base)))
  (def receiver (.cc recipe capacity: 2))
  (def delivered 0)
  (def action (checked-total-action (lambda (candidate amount)
    (read-slot candidate 'value)
    (set! delivered (1+ delivered)) amount)))
  (set! armed? #t)
  (def cause (with-catch identity (cut action receiver)))
  (unless (and (and (Error? cause) (equal? (error-message cause) "object changed during declaration reflection")) (= delivered 0)) (error "stale admission escaped"))
  (set! armed? #f)
  (.putslot! slot 'hidden ($constant-slot-spec #f))
  (def first (action receiver))
  (write-slot! receiver 'value 11)
  (def second (action receiver))
  (vector first second (read-slot receiver 'value) delivered))

;; Explicit self overrides cut construction, not validation or business admission.
;; The opaque encoding is the same lawful computation expressed as computed;
;; its unused inherited chain must remain available because bodies are opaque.
;; Both share the complete existing reflection/refinement/FUN revision workflow.
(def (override-workflow depth opaque?: (opaque? #f))
  (using ((depth :~ (lambda (n) (and (fixnum? n) (>= n 0)))) (opaque? :~ boolean?))
    ;; Final-self reads are the same computation in the explicit/opaque encodings.
    (def (base self) (* (.get self capacity) (.get self tariff)))
    (reflection-workflow 0 slots:
      (append
        (list (cons 'total ($thunk-slot-spec (lambda () (error "shadowed body forced")))))
        (for/collect (_ (in-range depth))
          (cons 'total ($computed-slot-spec (lambda (_self next) (+ 100 (next))))))
        (list (cons 'total (if opaque?
                ($computed-slot-spec (lambda (self _next) (base self))) ($self-slot-spec base)))
              (cons 'total ($computed-slot-spec
                (lambda (self next) (+ (next) (.get self fee) (.get self surcharge))))))))))

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
  (def checkout (.call fun.Observation. .bind prepare
    (lambda (snapshot) (lambda (_request) (report (list snapshot))))))
  ((.call fun.Observation. .bind
    (lambda (_request) (service (list width layout: layout? reshape?: #t)))
    (lambda (totals) (.call fun.Observation. .map (cut vector totals <>) checkout))) []))

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

;; Rejected symbolic edits preserve one shared service generation and both inline
;; consumers. A corrected symbolic specification edit invalidates descendants once;
;; the same existing checked FUN action revalidates before delivering new totals.
(def (symbolic-edit-workflow)
  (def source (.o capacity: 2 tariff: 3))
  (def recipe (.mix source Service))
  (def receivers (list (.mix recipe) (.mix recipe)))
  (def delivered 0)
  (def action (checked-total-action (lambda (_ amount) (set! delivered (1+ delivered)) amount)))
  (def first (apply + (map-in-order action receivers)))
  (def revisions (map object-revision (cons source receivers)))
  (for* ((bad (list #f 7 "capacity"))
         (edit (list (lambda () (.put! source bad -1))
                     (lambda () (.removeslot! source bad))
                     (lambda () (.removedefault! source bad)))))
    (def cause (with-catch identity edit))
    (unless (contract-violation-error? cause) (error "symbolic edit did not refuse"))
    (unless (equal? revisions (map object-revision (cons source receivers)))
      (error "rejected key changed service generations")))
  (.removeslot! source 'capacity)
  (vector first (apply + (map-in-order action receivers)) delivered))

;; A caller-owned replay spine can be damaged independently of genuine records.
;; Repair reuses ordinary checked replay, never a cached freshness verdict. The
;; same FUN action admits revised/restored values; obsolete reads remain stale.
(def (replay-workflow)
  (def receiver (.cc Service capacity: 2))
  (def delivered 0)
  (def action (checked-total-action (lambda (_ amount) (set! delivered (1+ delivered)) amount)))
  (def first (action receiver))
  (defvalues (_value roots)
    (%call-with-recorded-slot-reads (cut .ref receiver 'total)))
  (def visits 0)
  ;; Keep the same callback so refusals cannot masquerade as successful delivery.
  (def (observe _owner _key) (set! visits (1+ visits)))
  (def initial (begin (replay-slot-reads! roots observe) visits))
  (def cause (begin (set-cdr! roots roots)
    (with-catch identity (lambda () (replay-slot-reads! roots observe)))))
  (unless (and (contract-violation-error? cause) (= visits initial))
    (error "damaged replay roots delivered"))
  (set-cdr! roots [])
  (replay-slot-reads! roots observe)
  ;; Legitimate source edits keep old credentials stale, including ABA values.
  (def (revise capacity)
    (def failure (begin
      (.putslot! receiver 'capacity ($constant-slot-spec capacity))
      (with-catch identity (lambda () (replay-slot-reads! roots observe)))))
    (unless (and (Error? failure) (equal? (error-message failure) "stale slot dependency"))
      (error "obsolete replay roots accepted"))
    (action receiver))
  (let (second (revise 3))
    (vector first second (revise 2) delivered)))

;; Copied catalogs share live descriptor sources, never evaluated receiver caches.
;; A definition hook cannot edit a later declaration while its clone is active.
;; Repair and supported source revision use the same refined FUN consumer.
(def (declaration-source-workflow)
  (def tariff (.new Slot type: Integer constant: 3))
  (def original (.ref tariff '.type))
  (def attack? #t)
  (def defining (.cc original '.slot.define
    (lambda (metadata name target)
      (when attack? (.putslot! tariff 'constant ($constant-slot-spec 99)))
      (.call original .slot.define metadata name target))))
  (def capacity (.cc (.new Slot type: Integer constant: 2) '.type defining))
  (def recipe (make-object supers: [Service]
    declarations: (list (cons 'capacity capacity) (cons 'tariff tariff))))
  (def receivers (list (.cc recipe fee: 1) (.cc recipe fee: 1)))
  (def delivered 0)
  (def action (checked-total-action (lambda (_ amount) (set! delivered (1+ delivered)) amount)))
  (def failure (with-catch identity (cut action (car receivers))))
  (unless (and (Error? failure) (equal? (error-message failure) "object mutation during computation")
               (= (.ref tariff 'constant) 3) (= delivered 0))
    (error "later declaration escaped construction guard"))
  (set! attack? #f)
  (let* ((initial (map-in-order action receivers)))
    (defvalues (_value reads) (%call-with-recorded-slot-reads (cut .ref (car receivers) 'total)))
    (.putslot! tariff 'constant ($constant-slot-spec 4))
    (unless (every (lambda (read) (not (object-read-current? read))) reads)
      (error "old declared service read survived source edit"))
    (vector initial (map-in-order action receivers) delivered)))

;; A resolved type is a source even when its descriptor lives on another branch.
;; One checked FUN consumer survives refusal, repaired preparation and a supported
;; type-definition revision; old reads cannot authorize the rebuilt service.
(def (declaration-type-workflow)
  (def original (.ref (.new Slot type: Integer constant: 3) '.type))
  (def tariff-type (.cc original))
  (def attack? #t)
  (def capacity-type (.cc original '.slot.define
    (lambda (metadata name target)
      (when attack? (.putslot! tariff-type '.slot.define
        ($constant-slot-spec (lambda (_ key receiver)
          (.putslot! receiver key ($constant-slot-spec 99))))))
      (.call original .slot.define metadata name target))))
  (def older (make-object supers: [Service] declarations:
    [(cons 'capacity (.cc (.new Slot type: Integer constant: 2) '.type capacity-type))]))
  (def newer (make-object supers: [Service] declarations:
    [(cons 'tariff (.cc (.new Slot type: Integer constant: 3) '.type tariff-type))]))
  ;; Reverse C3 consumes older first; the later branch's type must already be bound.
  (def receiver (make-object supers: [newer older]))
  (def delivered 0)
  (def action (checked-total-action (lambda (_ amount) (set! delivered (1+ delivered)) amount)))
  (def cause (with-catch identity (cut action receiver)))
  (unless (and (Error? cause) (equal? (error-message cause) "object mutation during computation")
               (= delivered 0) (eq? (.ref tariff-type '.slot.define) (.ref original '.slot.define)))
    (error "later type escaped family preparation"))
  (set! attack? #f)
  (let (first (action receiver))
    (defvalues (_value reads) (%call-with-recorded-slot-reads (cut .ref receiver 'total)))
    (.putslot! tariff-type '.slot.define ($constant-slot-spec
      (lambda (_ key target) (.putslot! target key ($constant-slot-spec 4)))))
    (unless (and (pair? reads) (every (lambda (read) (not (object-read-current? read))) reads))
      (error "old typed service read survived definition edit"))
    (vector first (action receiver) delivered)))

;; Parent snapshots own only their list cells. The refined FUN action retains its
;; access site across checked parent replacement, restored values and stale reads.
;; Both direct and standard generalized setters use the same topology protocol.
(def (topology-workflow)
  (def source (.cc Service capacity: 2))
  (def replacement (.cc Service capacity: 3))
  (def receiver (.mix source))
  (def delivered 0)
  (def action (checked-total-action (lambda (_ amount) (set! delivered (1+ delivered)) amount)))
  (def first (action receiver))
  (def snapshot (object-supers receiver))
  (def parents (list replacement))
  (set-car! snapshot replacement)
  (set-cdr! snapshot snapshot)
  (unless (and (eq? (car (object-supers receiver)) source) (= (action receiver) first))
    (error "parent snapshot changed the service source"))
  (let-values (((_value reads) (%call-with-recorded-slot-reads (cut .ref receiver 'total))))
    (object-supers-set! receiver parents)
    (set-car! parents source)
    (set-cdr! parents parents)
    (unless (and (eq? (car (object-supers receiver)) replacement) (pair? reads)
                 (every (lambda (read) (not (object-read-current? read))) reads))
      (error "parent replacement retained an old source or read"))
    (let (second (action receiver))
      (set! (object-supers receiver) [source])
      (unless (every (lambda (read) (not (object-read-current? read))) reads)
        (error "restored parents revived obsolete reads"))
      (vector first second (action receiver) delivered))))

;; Complete shared-diamond revisions, shape edits, failed admission and retry use
;; both readers through the existing FUN consumer. Each trace owns fresh receivers;
;; the declared backend changes storage, never evaluation, contracts or approval.
(def (value-storage-workflow width storage)
  (parameterize ((slot-value-storage storage))
    (vector (service-workflow width layout: #f reshape?: #t)
            (service-workflow width layout: (eq? storage 'vector) reshape?: #t))))
