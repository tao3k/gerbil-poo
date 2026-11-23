;; The demand precheck and instance lookup may have changed methods. Check
;; the stored closure through the current native table before skipping the
;; child's empty recording frame. The caller still issues its original read.
(def (current-constant-method? self slot constant)
  (and constant (null? (active-slot-computations))
       (let (methods (object-%slot-funs self))
         (and (%standard-symbol-table-lookup? methods)
              (eq? constant (symbolic-table-ref (interface-instance-object methods) slot #f))))))

;; Admit runtime names before recording reads, bootstrap lookup or preparation.
;; Read a cached slot or compute it through the original cycle-aware protocol.
(defrule (define-slot-ref name project)
  (def (name self (slot :~ symbol?))
    (%slot-read-demand! self slot)
    (def anchor (bootstrap-anchor self slot))
    (if anchor (object-read-bootstrap self slot anchor)
      (let* ((prepared (and (object? self) (object-%instance self)))
             (constant (and (not prepared) (instantiate-for-demand! self #f slot)))
             (instance (or prepared (object-%instance self)))
             (value (hash-ref instance slot absent-value)))
        (if (eq? value absent-value)
          (let (revision (object-revision self))
            (defvalues (value dependencies)
              (if (current-constant-method? self slot constant)
                (values (constant) [])
                (%call-with-recorded-slot-reads
                  (lambda ()
                    (compute-slot-value self slot
                      (hash-ref/default (object-%slot-funs self) slot
                        (cut cut no-applicable-method self slot)))))))
            (unless (and (= revision (object-revision self)) (eq? instance (object-%instance self)))
              (error "object changed during slot computation" slot))
            (def read (object-record-read self slot value dependencies))
            (hash-put! instance slot value)
            (hash-put! (object-read-table self) slot read)
            (project (%deliver-slot-read read value)))
          (project (if (%slot-read-active?) (object-deliver-value self slot value) value)))))))

(define-slot-ref .ref %owned-list-value)
;; Internal traversals borrow only while doing their own immediate traversal.
(define-slot-ref %ref-owned-list %borrow-owned-list)

;; Expose the existing primary vector by identity, without seeding another store.
;; The explicit hash qualification stays symbolic and never allocates a second cache.
(extern namespace: clan/poo/object/slot-layout %layout-snapshot access-cache-layout)
(def (%live-object-layout self previous: (previous #f))
  (instantiate-object! self previous: previous)
  (or (object-%layout self)
    (let (layout (slot-values-layout (object-%instance self)))
      (when layout (set! (object-%layout self) layout)) layout)))
(def (object-layout self)
  (%layout-snapshot (%live-object-layout self)))
;; Sites retain offsets, never values. Observed/bootstrap reads use ordinary .ref;
;; live layouts certify preparation and are discarded by supported edits.
;; Failures bind no guard; absent names never become certified indices.
(def (.ref/inline self cache)
  (def slot (slot-cache-name cache))
  (if (%slot-read-active?) (.ref self slot)
    (let (prepared (object-%layout self))
      (if (and (not prepared) (bootstrap-anchor self slot)) (.ref self slot)
        (let (layout (or prepared (%live-object-layout self previous: (access-cache-layout cache))))
          (if (not layout) (.ref self slot)
            (let* ((revision (object-revision self))
                   (hit (slot-cache-hit? cache self revision layout))
                   (index (or hit (slot-cache-index cache layout)))
                   (stored (if index (slot-layout-ref layout index) absent-value)))
              (if (and hit (not (eq? stored absent-value))) (%owned-list-value stored)
                ;; Cold sites and evicted cells share ordinary cycle-aware demand.
                ;; Only successful demand publishes the final-shape access guard.
                (let* ((shape (slot-layout-shape layout))
                       (value (if (eq? stored absent-value) (.ref self slot) (%owned-list-value stored)))
                       (same-shape? (eq? shape (slot-layout-shape layout))))
                  ;; Recheck after callbacks: a shared site may have rebound to another owner.
                  (unless (slot-cache-hit? cache self revision layout)
                    (slot-cache-bind! cache self revision layout
                      (if same-shape? index (slot-layout-index layout slot)))) value)))))))))
;; Read an already stored vector cell through the stock HashTable route.
;; A cold cell or an unsupported table returns absent-value. A stored #f
;; remains a value. This probe does not instantiate, demand, or issue a read.
(extern namespace: clan/poo/object/read-route %prepared-vector-value %prepared-vector-values)
(def (%prepared-vector-slot-ref self slot)
  (let (instance (and (object? self) (object-%instance self)))
    (if (and instance (not (object-protocol self))
             (not (bootstrap-anchor self slot)) (symbol? slot))
      (%prepared-vector-value instance slot)
      absent-value)))

;; One uninterrupted inspection of the receiver's existing symbolic vector
;; store. Author hooks and bootstrap reads remain with ordinary demand.
(def (%prepared-vector-slots-ref self first second third)
  (let (instance (and (object? self) (object-%instance self)))
    (if (and instance (object-%precedence-list self)
             (not (object-protocol self)) (not (object-%bootstrap self))
             (symbol? first) (symbol? second) (symbol? third))
      (%prepared-vector-values instance first second third)
      (values absent-value absent-value absent-value))))

(extern namespace: clan/poo/object/slot-observation %first-registered-read?)

;; Use the native capture's first registration of both records. The caller
;; must have qualified the observer scope and supply only stock predicates.
;; A missing or changed record leaves the ordinary path in charge.
(def (%registered-field-reader self)
  (let ((registered? (%first-registered-read?))
        (instance (object-%instance self))
        (reads (object-%reads self))
        (methods (object-%slot-funs self)))
    (and registered? instance reads methods (object-%precedence-list self)
         (not (object-%bootstrap self)) (not (object-protocol self))
         (with-catch (lambda (_) #f)
           (lambda ()
             (%require-read-route! 'presence reads instance #f)
             (and (%standard-symbol-table-lookup? methods) #t)))
         (let (revision (object-revision self))
           (def (registered-current? read key expected)
             (and read (registered? read) (object-read-issued? read)
                  (eq? (slot-read-receiver read) self)
                  (eq? (record-instance-field read) instance)
                  (= (slot-read-revision read) revision)
                  (equal? (record-key-field read) key)
                  (eq? (record-value-field read) expected)))
           (lambda (key)
             (let (presence-key (list 'presence key))
               (if (and (hash-key? methods key)
                        (registered-current? (hash-get reads presence-key) presence-key #t))
                 (let (value (hash-ref instance key absent-value))
                   (if (and (not (eq? value absent-value))
                            (registered-current? (hash-get reads key) key value))
                     value absent-value))
                 absent-value)))))))

;; Get an existing cached slot value from an object
(def (.ref/cached self (slot :~ symbol?) (default false))
  (%slot-read-demand! self slot)
  (def anchor (bootstrap-anchor self slot))
  (if anchor (object-read-bootstrap self slot anchor)
    (let* ((instance (%live-object-instance self)) (value (hash-ref instance slot absent-value)))
      (if (eq? value absent-value)
        ;; A miss is not field absence. Later cache population makes it stale
        ;; without any mutation revision; each default invocation has its own dependencies.
        (object-read-query self (list 'cache-miss slot) default cache?: #f)
        (%owned-list-value
         (if (%slot-read-active?) (object-deliver-value self slot value) value))))))

(defclass (NoApplicableMethod Exception) (self slot) transparent: #t)
;; .get reaches this through .ref when there is no slot definition.
;; A refinement's sup reaches it when there is no inherited definition.
;; Both call the receiver's no-applicable-method slot with self and slot.
(def (no-applicable-method self slot)
  (def nam (and (not (eq? slot 'no-applicable-method))
    (try (.@ self no-applicable-method)
      (catch (NoApplicableMethod? cause)
        ;; Only genuine absence of THIS hook means no handler. A broken hook,
        ;; cyclic definition or delegate's own missing slot remains a source error.
        (if (and (eq? (NoApplicableMethod-self cause) self)
                 (eq? (NoApplicableMethod-slot cause) 'no-applicable-method))
          #f (raise cause))))))
  (if nam (nam self slot) (raise (NoApplicableMethod self: self slot: slot))))

;; Structural queries follow the same receiver-local delegate as value reads.
;; A structural cycle must fail before a recursive query can publish a record.
(def active-fallback-queries (make-parameter '()))
(def (call-with-fallback-query self action)
  (def active (active-fallback-queries))
  (when (memq self active) (error "cyclic fallback reflection"))
  (parameterize ((active-fallback-queries (cons self active)))
    (with-slot-dependencies self action)))

;; Construct a prototype whose no-applicable-method hook delegates missing
;; slots to a lazily obtained object. Presence and name queries use that same delegate.
(def (fallback-to thunk reserved: (reserved '()))
  (unless (procedure? thunk) (error "fallback must be a thunk"))
  (unless (and (list? reserved) (andmap symbol? reserved))
    (error "fallback reserved slots must be symbols"))
  (def hidden '(no-applicable-method .fallback-handler))
  (def (reserved? slot) (memq slot reserved))
  (make-object
    protocol:
    (.o fallback-slot-present?:
        (lambda (self slot)
          (and (not (reserved? slot))
               (call-with-fallback-query self
                 (lambda () (.slot? (.ref self '.fallback-handler) slot)))))
        fallback-slot-names:
        (lambda (self names)
          (call-with-fallback-query self
            (lambda ()
              (append names
                      (filter (lambda (slot)
                                (not (or (memq slot hidden) (reserved? slot) (memq slot names))))
                              (.all-slots (.ref self '.fallback-handler))))))))
    slots:
    (list (cons '.fallback-handler ($thunk-slot-spec thunk))
          (cons 'no-applicable-method
            ($constant-slot-spec
              (lambda (self slot)
                (if (reserved? slot)
                  (raise (NoApplicableMethod self: self slot: slot))
                  (with-slot-dependencies self
                    (lambda () (.ref (.ref self '.fallback-handler) slot))))))))))
