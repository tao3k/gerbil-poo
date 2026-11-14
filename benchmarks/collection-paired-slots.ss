;;; Slot layout, projection and lookup workloads.
(export +map-phases+ +names-phases+ +chain-phases+
        map-workload names-workload chain-workload offset-workload
        cycle-report-workload cycle-workflow seeding-workload slot-workload)
(import :std/iter :clan/poo/object
        :clan/poo/prototype-map
        (only-in :clan/poo/io module-action)
        (only-in :clan/poo/slot-layout slot-value-storage make-slot-cache
                 make-slot-layout slot-layout-index slot-layout-ref)
        (only-in :clan/poo/slot-observation call-with-slot-read-observer slot-read-key)
        (only-in :gerbil/runtime/loader load-module)
        (only-in :gerbil/runtime/gambit string->uninterned-symbol)
        (prefix-in :clan/poo/examples/representation-service service.))

;; Compare indexed deletion against the supported complete-specification rebuild.
;; Construction and snapshot observation are charged in the cold/full paths.
(def +map-phases+ '(map-remove-hot map-remove-cold map-remove-miss map-remove-repeat map-remove-workflow))

;; Both strategies own public outputs and authenticate the same structural reads.
;; Only the temporary public names copy differs from private internal borrowing.
(def +names-phases+ '(names-export names-enumerate names-observed names-cold names-workflow))

;; Both are supported CURRENT encodings: opaque computed versus explicit self.
;; Cold phases charge their metadata too; this is not an old-revision speed claim.
(def +chain-phases+ '(chain-single chain-cold chain-hot chain-workflow))

;; Full construction, vector preparation and observation retain the same result.
;; The single-contribution control charges admission/collection without a prefix.
(def (chain-workload size scenario)
  (def single? (eq? scenario 'chain-single))
  (def enter (module-action "clan/poo/examples/representation-service"
    'clan/poo/examples/representation-service#override-workflow))
  ;; Build both representations from fresh metadata inside every cold operation.
  (def (build opaque?)
    ;; Final receiver lookup stays lazy in both constructor encodings.
    (def (value self) (.get self seed))
    (make-object defaults: (list (cons 'seed 6) (cons 'enabled #f) (cons 'callback identity))
      slots: (append
        (if single? []
          (cons (cons 'value ($thunk-slot-spec (lambda () (error "shadowed benchmark body"))))
            (for/collect (_ (in-range size))
              (cons 'value ($computed-slot-spec (lambda (_self next) (next)))))))
        (list (cons 'value (if opaque?
          ($computed-slot-spec (lambda (self _next) (value self))) ($self-slot-spec value))))
        (if single? [] (list (cons 'value
          ($computed-slot-spec (lambda (_self next) (+ 1 (next))))))))))
  ;; Even the hot control uses the same public guarded API and complete oracle.
  (def (observe owner site)
    (def value (.ref/inline owner site))
    (def fields (.alist owner))
    (unless (and (= value (if single? 6 7)) (= (length fields) 4)
                 (= (cdr (assq 'value fields)) value)
                 (not (cdr (assq 'enabled fields)))
                 (eq? (cdr (assq 'callback fields)) identity))
      (error "slot construction oracle")) #t)
  ;; Warm state belongs to each side independently; no business result is shared.
  (def (action opaque?)
    (def warm (force-object (build opaque?)))
    (def site (make-slot-cache 'value))
    (observe warm site)
    (lambda ()
      (if (eq? scenario 'chain-workflow)
        (begin
          (unless (equal? (enter (list size opaque?: opaque?)) '#(24 30 36 6))
            (error "slot construction publication oracle")) #t)
        (observe (if (eq? scenario 'chain-hot) warm (build opaque?))
                 (if (eq? scenario 'chain-hot) site (make-slot-cache 'value))))))
  (values (action #t) (action #f)))

;; A safe public composition is the reference; the old leaking view is NOT a
;; valid alternative. Result pairs and every ordinary field read remain charged.
(def (reference-names-alist source)
  (map (lambda (name) (cons name (.ref source name))) (.all-slots source)))

;; Fixed false/Function/list payloads detect accidental deep copying. Warm, cold,
;; observed and complete module/contract workflows share the same finite oracles.
(def (names-workload size scenario)
  (def payload (list #f identity))
  (def entries (append (for/collect (n (in-range size))
    (cons (string->symbol (string-append "visible-" (number->string n))) n))
    (list (cons 'enabled #f) (cons 'callback identity) (cons 'names payload))))
  (def source (force-object (object<-alist entries)))
  (def enter (module-action "clan/poo/examples/representation-service"
    'clan/poo/examples/representation-service#reflection-workflow))
  ;; A callback path must retain ordered effects, not just equal final counts.
  (def (enumerate owner borrowed?)
    (def seen '())
    ;; Retain every callback's key/value order for the measured result oracle.
    (def (consume key value) (set! seen (cons (cons key value) seen)))
    (if borrowed? (.for-each! owner consume)
      (for-each (lambda (key) (consume key (.ref owner key))) (.all-slots owner)))
    (reverse seen))
  ;; Each side uses ordinary supported public APIs on the same warmed source.
  (def (action borrowed?)
    (def inspect (if borrowed? .alist reference-names-alist))
    (lambda ()
      (case scenario
        ((names-workflow)
          (unless (equal? (enter (list size inspect: inspect)) '#(24 30 36 6))
            (error "names publication oracle")))
        (else
          (let ((owner (if (eq? scenario 'names-cold) (object<-alist entries) source))
                (observed 0))
            ;; Actual issuance/currentness remains checked on every observed call.
            (def (observe read)
              (when (equal? (slot-read-key read) '(names))
                (unless (object-read-current? read) (error "names credential oracle"))
                (set! observed (1+ observed))))
            ;; Both strategies produce the full alist before validating its oracle.
            (def (read)
              (if (eq? scenario 'names-enumerate) (enumerate owner borrowed?) (inspect owner)))
            (let (result (if (eq? scenario 'names-observed)
              (call-with-slot-read-observer observe read) (read)))
              (unless (and (equal? result entries)
                           (or (not (eq? scenario 'names-observed)) (= observed 1)))
                (error "names observation oracle"))))))
      #t))
  (values (action #f) (action #t)))

;; The preceding present-name strategy, using the current public representation.
;; This deliberately omits its old initial name probe, favoring the reference.
;; Both constructors use the current index; this is not a prior-revision cold test.
(def (reference-map-remove source name)
  (prototype-map (filter (lambda (entry) (not (eq? (car entry) name))) (prototype-map-list source))
    policy: (prototype-map-policy source)))

;; Existing whole-specification installation owns invalidation on the reference.
(def (reference-object-remove source name)
  (object-slots-set! source
    (filter (lambda (entry) (not (eq? (car entry) name))) (object-slots source))))

;; A shared source contains duplicate contributions and a false opaque payload.
;; Complete observations remain inside timing, so removing rebuilding does not
;; conceal export/copy work. Every retry keeps the same immutable initial root.
(def (map-workload size scenario)
  (def entries (append (for/collect (n (in-range size))
    (cons (string->symbol (string-append "entry-" (number->string n))) n))
    (list (cons 'target #f) (cons 'kept identity) (cons 'target identity))))
  (def source (prototype-map entries))
  (def expected (filter (lambda (entry) (not (eq? (car entry) 'target))) entries))
  (def enter (module-action "clan/poo/examples/representation-service"
    'clan/poo/examples/representation-service#removal-workflow))
  ;; Preserve finite reinsert order across gaps instead of reusing live count.
  (def (action remove)
    (lambda ()
      (case scenario
        ((map-remove-workflow)
          (unless (equal? (enter (list size
                    remove: (if (eq? remove prototype-map-remove) .removeslot! reference-object-remove)))
                   '#(54 24 30 24 54 10)) (error "map service oracle")))
        ((map-remove-miss)
          (unless (eq? (prototype-map-remove source 'absent) source) (error "map absent identity oracle")))
        (else
          (let* ((root (if (eq? scenario 'map-remove-cold) (prototype-map entries) source))
                 (removed (remove root 'target))
                 (result (if (eq? scenario 'map-remove-repeat)
                   (remove (prototype-map-put removed 'target #f) 'target) removed)))
            (unless (equal? (prototype-map-list result) expected) (error "map ordered payload oracle")))))
      #t))
  (values (action reference-map-remove) (action prototype-map-remove)))

;; Both sides use the production reader, evaluator, binder and standard loader.
;; Capacity alone differs. Preparation includes the larger record allocation;
;; two shapes expose reuse, three expose bounded eviction, and complete workflows
;; charge prototype construction, refinement, shared invalidation and retry.
(def (offset-workload size scenario)
  (def variants (list (.o audit: #f) (.o policy: identity) (.o tier: 'third)))
  (def owners (map (lambda (variant) (.o inherit: [service.Service variant] capacity: 4))
    (case scenario ((slot-offset-hot) (list (car variants)))
      ((slot-offset-churn) variants) (else (list (car variants) (cadr variants))))))
  ;; Each capacity owns its site; both traverse exactly the same receivers.
  (def (action capacity)
    (def site (make-slot-cache 'total shapes: capacity))
    ;; Capturing the existing Reader action does not load or initialize a plugin.
    (def enter (module-action "clan/poo/examples/representation-service"
      'clan/poo/examples/representation-service#service-workflow))
    ;; Equal complete warming occurs before either measured side is selected.
    (for-each (cut .ref/inline <> site) owners)
    (lambda ()
      (case scenario
        ((slot-offset-prepare)
          (make-slot-cache 'total shapes: capacity))
        ((slot-offset-workflow)
          (let (result (enter (list size layout: #t reshape?: #t
                         shapes: capacity variants: (list (car variants) (cadr variants)))))
            (unless (and (= (vector-ref result 3) (* 3 size))
                         (service.slot-revision-workflow '(7 11 7 #f) capacity))
              (error "offset workflow oracle"))
            #t))
        (else
          (for-each (lambda (owner)
            (unless (= (.ref/inline owner site) 15) (error "offset current receiver oracle"))) owners)
          #t))))
  (values (action 1) (action 2)))

;; Qualify diagnostic pair ownership in one compiler context. Both strategies
;; construct/raise/catch the same exception and validate the full ordered report;
;; only copying each pair differs. No production compatibility option is added.
(def (cycle-report-workload size)
  (def receiver (.o callback: identity disabled: #f))
  (def frames (for/collect (n (in-range size))
    (cons receiver (string->uninterned-symbol (number->string n)))))
  (def path (cons (cons receiver 'repeat) frames))
  (def expected (reverse (map cdr path)))
  (def (action owned?)
    (lambda ()
      (for (_ (in-range 64))
        (let* ((cause (with-catch identity
                       (lambda () (raise (CyclicSlot path:
                         (for/fold (report []) (entry path)
                           (cons (if owned? (cons (car entry) (cdr entry)) entry) report)))))))
               (report (CyclicSlot-path cause)))
          (unless (and (equal? (map cdr report) expected)
                       (andmap (lambda (entry) (eq? (car entry) receiver)) report))
            (error "cycle report payload/order oracle"))))
      #t))
  (values (action #f) (action #t)))

;; Both complete cache workflows perform real diagnosis mutation, bounded guard
;; refusal, checked FUN repair and shared-source revision. Only the existing
;; hash/vector value backend differs; neither side runs the unsafe former guard.
(def (cycle-workflow size)
  (def (action storage)
    (lambda ()
      (for (_ (in-range size))
        (unless (equal? (parameterize ((slot-value-storage storage))
                         (service.cycle-diagnostic-workflow)) '#(3 9 11 #t))
          (error "cycle workflow oracle"))) #t))
  (values (action 'hash) (action 'vector)))

;; Compare the same current layout constructor with/without an old shape hint.
;; Full operations use explicit preparation or the current site's shape hint.
;; Preparation charges complete name capture, duplicate removal and value seeding.
;; Full workflows include cached standard loading, fresh inherited owners, checked
;; Reader consumers, shared invalidation, refused refinement and successful retry.
;; Changed layouts exercise both added and removed fields, not only steady hits.
;; Direct construction compares seeded/demand cells on identical finite shapes.
;; After removal of the auxiliary store, both complete workflow arms deliberately
;; use the same current storage: matched controls, not an old seeding algorithm.
(def (seeding-workload size scenario)
  (def names (for/collect (n (in-range size)) (string->symbol (string-append "field-" (number->string n)))))
  (def entries (map (lambda (name) (cons name 1)) names))
  (def initial (list->hash-table entries))
  (def first (car names))
  (def (action deferred?)
    (lambda ()
      (if (eq? scenario 'slot-seeding-prepare)
        (let* ((layout (make-slot-layout names (and (not deferred?) initial) absent-value))
               (stored (slot-layout-ref layout (slot-layout-index layout first))))
          (unless (if deferred? (eq? stored absent-value) (= stored 1)) (error "seeding preparation oracle")))
        (let ((owner (object<-alist entries)) (site (make-slot-cache first)))
          ;; Warming belongs INSIDE this complete workflow's timing boundary.
          (for-each (cut .ref owner <>) names)
          (if (eq? scenario 'slot-seeding-all)
            (for-each (lambda (name)
              (unless (= (.ref/inline owner (make-slot-cache name)) 1) (error "all-cell oracle"))) names)
            (unless (= (.ref/inline owner site) 1) (error "selected-cell oracle")))
          (.putslot! owner first ($constant-slot-spec #f))
          (unless (eq? (.ref/inline owner site) #f) (error "revised-cell oracle"))))
      #t))
  (values (action #f) (action #t)))

;; Compare existing symbolic reads with the explicit inline API through the same
;; receiver formulas and runtime. Each side owns its parent, instances and site.
(def (slot-workload size scenario)
  ;; Construction binds formulas without demanding either computed field.
  (def (family)
    (def parent (.o base: 3))
    (cons parent (for/collect (n (in-range size))
      (.o self: self inherit: [parent] offset: n
        (value (+ (.get self base) (.get self offset)))
        (unused (error "slot benchmark forced an unrelated body"))))))
  ;; The sum is checked inside every complete measured operation.
  (def (action inline?)
    (def fixture (family))
    (def site (and inline? (make-slot-cache 'value)))
    ;; Read only this receiver, never the last owner's retained result.
    (def (read receiver)
      (if inline? (.ref/inline receiver site) (.ref receiver 'value)))
    ;; The reference/candidate consume the same ordered receiver trace.
    (def (visit owners cycles base)
      (def total (for/fold (sum 0) (_ (in-range cycles))
        (for/fold (sum sum) (owner owners) (+ sum (read owner)))))
      (unless (= total (* cycles (+ (* base size) (/ (* size (1- size)) 2))))
        (error "slot access oracle" scenario total)) #t)
    (case scenario
      ((slot-prepare) (lambda ()
        (for (owner (cdr (family))) ((if inline? object-layout object-instance) owner)) #t))
      ((slot-cold) (lambda ()
        (def fresh (family)) (def cold-site (and inline? (make-slot-cache 'value)))
        (def total (for/fold (sum 0) (owner (cdr fresh))
          (+ sum (if inline? (.ref/inline owner cold-site) (.ref owner 'value)))))
        (unless (= total (+ (* 3 size) (/ (* size (1- size)) 2))) (error "cold slot oracle")) #t))
      ((slot-hot) (lambda ()
        (def total (for/fold (sum 0) (_ (in-range (* size 16))) (+ sum (read (cadr fixture)))))
        (unless (= total (* size 16 3)) (error "monomorphic slot oracle")) #t))
      ((slot-switch) (cut visit (cdr fixture) 16 3))
      ((slot-tracked) (lambda ()
        (call-with-slot-read-observer (lambda (_) (void)) (cut visit (cdr fixture) 16 3))))
      ((slot-revision) (lambda ()
        (.putslot! (car fixture) 'base ($constant-slot-spec 4)) (visit (cdr fixture) 1 4)
        (.putslot! (car fixture) 'base ($constant-slot-spec 3)) (visit (cdr fixture) 1 3)))
      ((slot-load-workflow) (lambda ()
        (load-module "clan/poo/examples/representation-service")
        ;; Keep initialization after the loader; Gerbil hoists internal defs.
        (let* ((access (and inline? (make-slot-cache 'total)))
               (total (for/fold (sum 0) (n (in-range size))
                 (let (receiver (.cc service.Service capacity: n))
                   (+ sum (if inline? (.ref/inline receiver access) (.ref receiver 'total)))))))
          (unless (= total (+ (* 3 size) (* 3 (/ (* size (1- size)) 2))))
            (error "cached module service oracle")) #t)))))
  (values (action #f) (action #t)))
