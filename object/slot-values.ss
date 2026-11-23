(defstruct $slot-spec () transparent: #t) ;; = (SlotSpec A k)
(defstruct ($constant-slot-spec $slot-spec) (value) transparent: #t) ;; constant value
(extern namespace: clan/poo/object/slot-observation %make-owned-list %owned-list-value %borrow-owned-list
        %slot-store-snapshot)
(def (%owned-list-slot-spec values (copy list-copy))
  ($constant-slot-spec (%make-owned-list values copy)))
(extern namespace: clan/poo/object/slot-observation owned-list? owned-list-copy)
(def (own-assigned-slot-value self slot value)
  (let (spec (prototype-map-ref (object-%slots self) slot))
    (if (and ($constant-slot-spec? spec)
             (owned-list? ($constant-slot-spec-value spec))
             (list? value))
      (%make-owned-list value (owned-list-copy ($constant-slot-spec-value spec)))
      value)))
(defstruct ($thunk-slot-spec $slot-spec) (thunk) transparent: #t) ;; thunk
(defstruct ($self-slot-spec $slot-spec) (fun) transparent: #t) ;; fun to be passed self as argument, not super
(defstruct ($computed-slot-spec $slot-spec) (fun) transparent: #t) ;; fun to be passed self and superfun as arguments

;; These existing constructors explicitly ignore the prior effective thunk.
;; Never infer this property from a Function body or a successful cached value.
(def (slot-spec-discards-super? spec)
  (or ($constant-slot-spec? spec) ($thunk-slot-spec? spec) ($self-slot-spec? spec)))
;; Lists are most-specific first. Standard reverse/foldl builds only the suffix
;; retained after the last super-independent contribution, without recursive
;; construction or a second declaration evaluator. Missing-super stays lazy.
(def (compile-slot-specs self slot specs)
  (def ordered (reverse specs))
  (foldl (cut apply-slot-spec self <> <>)
    (if (slot-spec-discards-super? (car ordered)) #f (cut no-applicable-method self slot)) ordered))
;; Interpret one admitted SlotSpec through its original constructor semantics.
(def (apply-slot-spec self spec superfun)
  (match spec
    (($constant-slot-spec val) (lambda _ val))
    (($thunk-slot-spec fun) fun)
    (($self-slot-spec fun) (cut fun self))
    (($computed-slot-spec fun) (cut fun self superfun))))

(def (%live-object-instance self)
  (instantiate-object! self)
  (object-%instance self))

;; A caller can check readiness without forcing evaluation or borrowing cells.
(def (object-instantiated? self)
  (and (object? self) (object-%instance self) #t))

;; Authenticate the receiver's prepared route without handing out its table.
(def (require-object-instance-route! self key)
  (%require-read-route! key #f (object-%instance self) #f))

;; Qualify both routes of a warm observed read without delivering evidence.
;; The caller separately qualifies the dynamic observation scope.
(def (object-prepared-read? self (name :~ symbol?))
  (and (object? self) (not (bootstrap-anchor self name))
       (let ((instance (object-%instance self)) (reads (object-%reads self)))
         (and instance reads
              (begin (%require-read-route! name reads instance #f)
                     (let (read (hash-get reads name))
                       (and read (object-read-issued? read)
                            (not (eq? absent-value (hash-ref instance name absent-value))))))))))

;; Inspect a prepared value without instantiating the receiver, delivering an
;; observation, or invoking a default procedure. A cached #f remains a value.
;; Callers that need a SlotRead use .ref/cached at the actual demand boundary.
(def (object-cached-value self (name :~ symbol?) (default #f))
  (let (instance (and (object? self) (object-%instance self)))
    (if instance
      (begin
        (%require-read-route! name #f instance #f)
        (let (value (hash-ref instance name absent-value))
          (if (eq? value absent-value) default (%owned-list-value value))))
      default)))

;; Diagnostic storage identity and native hash dimensions. Neither the
;; instance wrapper nor its mutable backing table is part of this result.
(def (instance-native-table instance)
  (let (table (and (interface-instance? instance) (interface-instance-object instance)))
    (and (raw-table? table) table)))

(def (instance-storage-info instance)
  (let (table (instance-native-table instance))
    (values (and instance (object->serial-number instance))
            (and table (&raw-table-count table))
            (and table (vector-length (&raw-table-table table))))))

(def (object-native-instance-keys self)
  (let (table (instance-native-table (and (object? self) (object-%instance self))))
    (and table
         (let (keys '())
           (raw-table-for-each (lambda (key _) (set! keys (cons key keys))) table)
           keys))))

;; Reflection copies the prepared values into a separate standard table.
;; The receiver still owns its cells and its HashTable adapter.
(def (object-instance self)
  (%slot-store-snapshot (%live-object-instance self)))

;; Active computations are dynamically scoped per thread and unwind on failure.
;; Only cache misses enter this path; successful #f and other values stay cached.
(def active-slot-computations (make-parameter []))
;; Report receiver/slot paths without forcing any value while formatting the error.
(defclass (CyclicSlot Exception) (path) transparent: #t)
;; Evaluate one uncached slot with finite cycle detection, including lazy delegates.
;; Failures publish no value and parameterize restores the caller's active path.
(def (compute-slot-value self slot thunk)
  (def active (active-slot-computations))
  (def key (cons self slot))
  (when (any (lambda (entry) (and (eq? (car entry) self) (eq? (cdr entry) slot))) active)
    ;; Diagnostics own their spine AND receiver/slot pairs. A handler may edit
    ;; them while an outer computation is still active. One standard fold
    ;; preserves chronological order; only the failure path pays for snapshots.
    (raise (CyclicSlot path:
      (for/fold (path []) (entry (cons key active))
        (cons (cons (car entry) (cdr entry)) path)))))
  (parameterize ((active-slot-computations (cons key active))) (thunk)))
