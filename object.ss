;;-*- Gerbil -*-
;; Prototype Object Orientation Functionally, in Gerbil Scheme.
;;
;; Next version of poo, with multiple inheritance and a budding meta-object protocol.
;; See doc/poo.md for documentation
;; TODO: see Future Features and the Internals TODO sections in document above.

;; Reexport renamed version of core things we shadow
(export (except-out #t object-record-read object-read-query object-read-bootstrap
                    object-deliver-value require-object-read-route! object-issued-read-current?
                    call-with-issued-reads active-read-replays) @object? @make-object)

(import
  (only-in :gerbil/runtime/hash HashTable)
  (prefix-in (only-in Runtime object? make-object) @) ;; Rename them before we shadow them
  (only-in ./support/object-syntax parse-object-options
           deduplicate-slot-identifiers prepare-shared-slot-specs
           normalize-slot-specs normalize-slot-specs-for-match)
  (for-syntax :std/iter
              (only-in :std/list/list push! delete-duplicates/hash)
              (only-in :std/list/list-builder with-list-builder))
  (only-in :std/error deferror-class Exception)
  (only-in :std/hash/misc hash->list/sort hash-ref/default hash-ensure-modify!)
  :std/iter
  ./slot-observation
  (prefix-in (only-in :gerbil/runtime/mop object-class slot-ref slot-set! find-method) read-runtime.)
  (only-in ./read-route require-read-route!)
  ./object-state
  ./prototype-map
  ./slot-layout
  (only-in :std/list/list-builder with-list-builder)
  (only-in :std/list/list flatten delete-duplicates/hash)
  (only-in :std/string/symbol symbol<?)
  :std/stxparam
  (only-in :std/values first-value)
  (only-in :gerbil/runtime/c3 c4-linearize*)
  (only-in ./support/base λ let-id-rule defonce awhen))

;; TODO: formalize (Object A S D) and the type conditions under which an object is instantiatable?
(defstruct object ;; = (Object A)
  (supers ;; : (Listof (Object ?))
   %slots ;; : persistent ordered direct specifications
   %defaults ;; : persistent ordered defaults
   %reads ;; receiver-local read records; no global receiver retention
   %layout ;; : optional shared shape and receiver-local value vector
   %instance ;; : (Table (A_ k) <- k:Sym) ; hash table from slot keys to slot values
   %precedence-list ;; : (Listof (Object ?)) ; linearization of the supers DAG
   %slot-funs ;; : (Table (Fun (A_ k)) <- k:Symbol) ; functions to compute slots
   %all-slots
   %state ;; mutation revision, sealed flag and weak dependency edges
   %protocol ;; optional ordinary POO object supplying inheritance hooks
   %overrides ;; explicit INSTANCE assignments, never inherited specifications
   %declarations
   %bootstrap) ;; explicit constant hook anchors; only the self-hosted root uses them : (Listof Symbol) ; definition order for all slot keys
  constructor: :init!)
(defmethod {:init! object}
  (lambda (self ;; : (Object A)
      supers: (supers '()) ;; : (Listof Objects) ;; Actually, can be a pair-tree of Object's and nulls.
      slots: (slots '()) ;; : (Listof (Pair Symbol (SlotSpec ? ?)))
      defaults: (defaults '())
      protocol: (protocol #f) declarations: (declarations '()) bootstrap: (bootstrap #f)) ;; : (Listof (Pair Symbol ?))
    (set! (object-supers self) (flatten supers))
    (set! (object-%slots self) (prototype-map slots))
    (set! (object-%defaults self) (prototype-map defaults))
    (set! (object-%instance self) #f)
    (set! (object-%reads self) #f)
    (set! (object-%layout self) #f)
    (set! (object-%precedence-list self) #f)
    (set! (object-%slot-funs self) #f)
    (set! (object-%all-slots self) #f)
    (set! (object-%state self) (make-object-state))
    (set! (object-%protocol self) protocol)
    (set! (object-%overrides self) #f)
    (set! (object-%declarations self) declarations)
    (set! (object-%bootstrap self) bootstrap)
    (for-each (cut depend-on-object! self <>) (object-supers self))
    (when protocol (depend-on-object! self protocol))))

;; Reflection preserves contribution order without exposing the persistent storage.
(def (object-slots self) (prototype-map-list (object-%slots self)))
;; Reflection returns an owned list while the persistent map remains shareable.
(def (object-defaults self) (prototype-map-list (object-%defaults self)))
;; Expose only explicit instance assignments as constant specifications. Recursive
;; validation can retain them on a fresh receiver without copying computed caches;
;; ordinary prototype inheritance still does not inherit these assignments.
(def (object-override-specifications self)
  (if (object-%overrides self)
    (map (lambda (entry) (cons (car entry) ($constant-slot-spec (cdr entry))))
         (hash->list/sort (object-%overrides self) symbol<?)) '()))

;; Track dependencies on prototypes, protocol objects and declaration descriptors.
(def (depend-on-object! self source)
  (unless (object? source) (error "object dependency required"))
  (depend-on-state! (object-%state source) self (object-%state self)))
;; Read-only revision identity for source-bound external caches.
(def (object-revision self) (object-state-revision (object-%state self)))
;; Active construction is separate from slot computation: no partial method table
;; or instance is published when an inherited hook tries to read its own receiver.
(def active-object-constructions (make-parameter []))
;; Private, dynamically scoped receiver sets, built only from authenticated reads.
;; Nested replays retain outer ownership; no process-global read-only switch.
(def active-read-replays (make-parameter '()))
;; Clear all derived state together. Explicit instance assignments remain separate.
(def (clear-object-cache! self)
  (set! (object-%reads self) #f)
  (set! (object-%instance self) #f)
  (set! (object-%layout self) #f)
  (set! (object-%precedence-list self) #f)
  (set! (object-%slot-funs self) #f)
  (set! (object-%all-slots self) #f))
;; Refuse mutation during evaluation anywhere in the affected dependency closure.
(def (check-object-edit self state)
  (when (or (memq self (active-object-constructions))
            (any (lambda (entry) (eq? self (car entry))) (active-slot-computations)))
    (error "object mutation during computation"))
  (when (any (lambda (receivers) (hash-key? receivers self)) (active-read-replays))
    (error "object mutation during read replay")))
;; Explicit invalidation preserves specifications and reaches shared descendants once.
(def (uninstantiate-object! self)
  (invalidate-state! self (object-%state self) check-object-edit clear-object-cache!))
;; Sealed sources reject all supported writes; invalidation alone remains allowed.
(def (before-object-edit! self)
  (when (object-state-sealed? (object-%state self)) (error "sealed prototype"))
  (uninstantiate-object! self))
;; Seal the current receiver's specifications and explicit instance assignments.
;; Ancestors can still change through the invalidation protocol unless sealed too.
(def (seal-object! self)
  (check-object-edit self (object-%state self))
  (set! (object-state-sealed? (object-%state self)) #t) self)
;; Replace direct specifications, invalidating every retained dependent cache.
(def (object-slots-set! self slots)
  (def next (prototype-map slots))
  (before-object-edit! self)
  (set! (object-%slots self) next))
;; Replace direct defaults through the same invalidation discipline.
(def (object-defaults-set! self defaults)
  (def next (prototype-map defaults))
  (before-object-edit! self)
  (set! (object-%defaults self) next))
;; Install a new protocol; old dependency edges conservatively remain valid.
(def (object-protocol-set! self protocol)
  (unless (or (not protocol) (object? protocol)) (error "protocol object required"))
  (before-object-edit! self)
  (when protocol (depend-on-object! self protocol))
  (set! (object-%protocol self) protocol))
;; Replace parent topology only after C3 admission and cycle checks. Low-level
;; generated struct setters are internal escape hatches, not this public protocol.
(def (replace-object-supers! self supers)
  (def parents (flatten supers))
  (for-each (lambda (parent)
    (unless (object? parent) (error "prototype parent required"))
    (when (memq self (compute-precedence-list! parent)) (error "cyclic prototype revision"))) parents)
  (compute-precedence-list! (make-object supers: parents))
  (before-object-edit! self)
  (for-each (cut depend-on-object! self <>) parents)
  (set! (object-supers self) parents))
;; Resolve the most-specific explicit protocol after checked C3 linearization.
;; Core ormap returns the exact first protocol and never visits the suffix.
;; Select ONE protocol object: a missing hook there does not search other branches.
(def (object-protocol self)
  (ormap object-%protocol (object-%precedence-list self)))
;; The explicit metalevel base exposes only its pinned hook values. Ordinary
;; objects and arbitrary cycles retain the normal construction/slot guards.
(def (bootstrap-anchor self name)
  (and (object? self) (eq? (object-%protocol self) self) (object-%bootstrap self)
       (assq name (object-%bootstrap self))))
;; Invoke one optional inherited hook. The continuation is the existing engine,
;; not a second evaluator; hook errors propagate and never install partial caches.
(def (invoke-object-hook self name next . args)
  (def protocol (object-protocol self))
  (cond
    ((bootstrap-anchor self name) => (lambda (entry) (apply (cdr entry) self next args)))
    ((and protocol (.slot? protocol name)) (apply (.ref protocol name) self next args))
    (else (next))))
;; Instantiate atomically with respect to native exceptions. Mutating callbacks and
;; concurrent reads/writes are outside the sequential protocol, and are rejected
;; for actively evaluated receivers rather than returning a partially built value.
(def (instantiate-object! self)
  (unless (object? self) (error "Not an object"))
  (unless (object-%instance self)
    (when (memq self (active-object-constructions)) (error "recursive object construction"))
    (parameterize ((active-object-constructions (cons self (active-object-constructions))))
      (try
        (defvalues (instance dependencies)
          (%call-with-recorded-slot-reads
            (lambda ()
              (compute-precedence-list! self)
              (compute-slot-funs! self)
              (def instance (make-hash-table-symbolic))
              (when (object-%overrides self)
                (for (([key . value] (object-%overrides self))) (hash-put! instance key value)))
              ;; The constant base is also present in ordinary full-cache reflection.
              (when (and (eq? (object-%protocol self) self) (object-%bootstrap self))
                (for (([key . value] (object-%bootstrap self))) (hash-put! instance key value)))
              instance)))
        (set! (object-%instance self) instance)
        (hash-put! (object-read-table self) '(preparation)
          (object-record-read self '(preparation) instance dependencies))
        (catch (cause) (clear-object-cache! self) (raise cause))))))

(defclass (InvalidObject Exception) (slots) transparent: #t)
(def (invalid-object-summary self)
  (InvalidObject slots: (map car (append (object-slots self) (object-defaults self) (object-%declarations self)))))

;; Delegate ordering directly to core C4 while retaining POO cycles, hooks and caches.
(def (compute-precedence-list! self (heads '()))
  ;; Preserve the ordered heads for diagnostics while keeping the cycle guard
  ;; as private implementation state at this abstraction boundary.
  (def active (make-hash-table-eq))
  (for-each (lambda (head) (hash-put! active head #t)) heads)
  (let compute ((object self) (heads heads))
    (cond
     ((object-%precedence-list object))
     ((hash-key? active object)
      (error "Circular precedence graph" (member object heads)))
     (else
      (hash-put! active object #t)
      (parameterize ((active-object-constructions (cons object (active-object-constructions))))
        (let (precedence-list
            (first-value
             (c4-linearize*
              [object] (list (object-supers object)) suffix: (lambda (_) #f)
              get-precedence-list:
              (lambda (super) (compute super [object . heads]))
              eq: eq?
              get-name: invalid-object-summary)))
        (hash-remove! active object)
        (set! (object-%precedence-list object) precedence-list)
        (try
          (let (chosen (invoke-object-hook object 'compute-precedence-list (lambda () precedence-list)))
            (unless (and (list? chosen) (= (length chosen) (length precedence-list))
                         (andmap eq? chosen precedence-list))
              (error "inheritance hook must preserve checked C3 order"))
            chosen)
          (catch (cause) (clear-object-cache! object) (raise cause)))))))))

;; Compile declaration metadata through the existing Slot protocol on a fresh
;; private receiver. Repeating this after descriptor edits cannot retain stale
;; constant/default/compute specifications from the previous metadata revision.
(def (declaration-specifications self)
  (if (null? (object-%declarations self)) (cons [] [])
    (let (scratch (make-object))
      (for (([name . descriptor] (object-%declarations self)))
        (def type (.@ descriptor .type))
        (depend-on-object! self descriptor)
        (depend-on-object! self type)
        (.call type .slot.define descriptor name scratch))
      (cons (object-slots scratch) (object-defaults scratch)))))
;; Assemble the ordinary inheritance chain, then let inherited hooks transform
;; each effective thunk. Direct specification writes override their declaration.
(def (compute-slot-funs! self)
  (def h (make-hash-table-symbolic))
  (def sources (map (lambda (super) (cons super (declaration-specifications super)))
                   (reverse (object-%precedence-list self))))
  (for (([super . declarations] sources))
    (for (([slot . value] (append (cdr declarations) (object-defaults super))))
      (hash-put! h slot (lambda _ value))))
  (for (([super . declarations] sources))
    (for (([slot . spec] (append (car declarations) (object-slots super))))
      (hash-ensure-modify! h slot
        (lambda () (cut no-applicable-method self slot))
        (cut apply-slot-spec self spec <>))))
  (for (([slot . standard] (hash->list h)))
    ;; Pinned hook definitions are the terminating base of self-description.
    (def compiled (if (bootstrap-anchor self slot) standard
      (invoke-object-hook self 'compute-slot (lambda () standard) slot)))
    (unless (procedure? compiled) (error "compute-slot must return a thunk" slot))
    (hash-put! h slot compiled))
  (set! (object-%slot-funs self) h))

;; Given a list of list of keys, in precedence order,
;; return a list of keys from containing from left to right
;; all the keys from tail to head of the precedence list, skipping repetitions.
(def (merge-super-slots super-slots)
  (delete-duplicates/hash (apply append (reverse super-slots))
    table: (make-hash-table-symbolic) from-end?: #t))

(defstruct $slot-spec () transparent: #t) ;; = (SlotSpec A k)
(defstruct ($constant-slot-spec $slot-spec) (value) transparent: #t) ;; constant value
(defstruct ($thunk-slot-spec $slot-spec) (thunk) transparent: #t) ;; thunk
(defstruct ($self-slot-spec $slot-spec) (fun) transparent: #t) ;; fun to be passed self as argument, not super
(defstruct ($computed-slot-spec $slot-spec) (fun) transparent: #t) ;; fun to be passed self and superfun as arguments

(def (apply-slot-spec self spec superfun)
  (match spec
    (($constant-slot-spec val) (lambda _ val))
    (($thunk-slot-spec fun) fun)
    (($self-slot-spec fun) (cut fun self))
    (($computed-slot-spec fun) (cut fun self superfun))))

(def (object-instance self)
  (instantiate-object! self)
  (object-%instance self))

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
    (raise (CyclicSlot path: (reverse (cons key active)))))
  (parameterize ((active-slot-computations (cons key active))) (thunk)))
;; MOP read records live on the receiver and are cleared with its native cache.
;; A retained record may retain its receiver; no global registry retains either.
(def (object-read-table self)
  (or (object-%reads self)
      (let (table (make-hash-table)) (set! (object-%reads self) table) table)))
(def (object-read-current? read)
  (and (object-read-issued? read)
       (begin (require-object-read-route! read)
              (object-issued-read-current? read))))
(def (object-issued-read-current? read)
  (def self (slot-read-receiver read))
  (def key (slot-read-key read))
  (and (= (slot-read-revision read) (object-revision self))
       (cond
         ((and (pair? key) (eq? (car key) 'bootstrap))
          (let (anchor (bootstrap-anchor self (cadr key)))
            (and anchor (eq? (cdr anchor) (slot-read-value read)))))
         ((not (eq? (slot-read-instance read) (object-%instance self))) #f)
         ((and (pair? key) (eq? (car key) 'cache-miss))
          (not (hash-key? (object-%instance self) (cadr key))))
         (else
          (and (object-%reads self) (eq? read (hash-get (object-%reads self) key))
               (or (pair? key)
                   (eq? (slot-read-value read)
                        (hash-ref (object-%instance self) key absent-value))))))))
(defvalues (object-record-read object-read-issued? object-read-issuance)
  (let ()
    ;; Both sides are weak: the registry is not a root for records, receivers or
    ;; birth closures. A live record itself keeps its original closure alive.
    (def issued (HashTable (make-table test: eq? weak-keys: #t weak-values: #t)))
    (def record-class
      (read-runtime.object-class (make-slot-read #f #f 0 #f #f '() values)))
    (def (same-list? current saved)
      (if (null? saved) (null? current)
        (and (pair? current) (eq? (car current) (car saved))
             (same-list? (cdr current) (cdr saved)))))
    ;; A single non-vector identity needs no separate private vector. The
    ;; dense fallback also handles unusual vector-valued parents without an
    ;; ambiguous tag. Public spines, repeated occurrences and delivery stay
    ;; unchanged; neither representation caches an authentication result.
    (def (same-dependencies? current saved)
      (if (vector? saved)
        (let loop ((current current) (index 0))
          (if (= index (##vector-length saved)) (null? current)
            (and (pair? current) (eq? (car current) (##vector-ref saved index))
                 (loop (cdr current) (1+ index)))))
        (and (pair? current) (eq? (car current) saved) (null? (cdr current)))))
    (def (issue self key value dependencies)
      (def preparation (and (object-%reads self)
                           (hash-get (object-%reads self) '(preparation))))
      (def parents
        (if (and preparation
                 (not (and (pair? key) (memq (car key) '(preparation bootstrap)))))
          (cons preparation dependencies) dependencies))
      (def revision (object-revision self))
      (def instance (object-%instance self))
      (def key-copy (and (pair? key) (map values key)))
      (def parent-copy
        (cond ((null? parents) '#())
              ((and (null? (cdr parents)) (not (vector? (car parents)))) (car parents))
              (else (list->vector parents))))
      (def checker object-read-current?)
      (def read (make-slot-read self key revision instance value parents checker))
      ;; Captured payload is not a public struct whose fields can be rewritten
      ;; through runtime.slot-set!. The registry authenticates this procedure
      ;; before it is invoked, so replacing birth with a true-returning closure
      ;; does not turn another arbitrary callback into a trusted checker.
      (def birth
        ;; RTD-checked records are truthy. False is the private copy request;
        ;; the public inspector still obtains ONLY the registered procedure.
        ;; A fixed lane captures this payload once, rather than retaining two
        ;; payload closures and a rest-argument case-lambda dispatcher per read.
        (lambda (candidate)
          ;; Copy primitive metadata; do not dispatch a mutable class constructor.
          (if (not candidate)
              (values read
                (vector self key revision instance value
                  (if (vector? parent-copy) (vector->list parent-copy) (list parent-copy)) checker)
                (and key-copy (map values key-copy)))
          (and (eq? candidate read)
               (eq? (slot-read-receiver read) self)
               (eq? (slot-read-key read) key)
               (or (not key-copy) (same-list? key key-copy))
               (= (slot-read-revision read) revision)
               (eq? (slot-read-instance read) instance)
               (eq? (slot-read-value read) value)
               (eq? (read-runtime.slot-ref read 'current?) checker)
               (same-dependencies? (slot-read-dependencies read) parent-copy)))))
      (read-runtime.slot-set! read 'birth birth)
      (hash-put! issued read birth)
      read)
    (def (issued? read)
      (and (eq? (read-runtime.object-class read) record-class)
        (let (birth (read-runtime.slot-ref read 'birth))
          (and (procedure? birth) (eq? birth (hash-get issued read)) (birth read)))))
    ;; Inspect the actual private association, not a caller's alleged birth.
    ;; Only the registered native closure is invoked, and only in copy mode.
    (def (inspect read)
      (unless (eq? (read-runtime.object-class read) record-class)
        (error "foreign slot-read type"))
      (def presented (read-runtime.slot-ref read 'birth))
      (def original (hash-get issued read))
      (if original
        (let-values (((signed snapshot shape) (original #f)))
          (values presented original signed snapshot shape))
        (values presented #f #f #f #f)))
    (values issue issued? inspect)))

(def (require-object-read-route! read)
  (def receiver (slot-read-receiver read))
  (require-read-route! (slot-read-key read)
    (object-%reads receiver) (object-%instance receiver)))

(def call-with-issued-reads
  (let ()
    ;; The index owns neither roots nor cache receivers. A live projection keeps
    ;; its ordinary native cache owner alive; GC eviction is always a cold miss.
    ;; No mutable visitation set or successful validation result is retained.
    (def owners (make-table test: eq? weak-keys: #t weak-values: #t))
    (defstruct projection (owner roots reads receivers) final: #t)
    ;; A cold cache owner must not dispatch an injected CLOS initializer during
    ;; authentication. Changed constructor metadata keeps the original DFS path.
    (def object-init (read-runtime.find-method object::t #f ':init!))
    (def state-class (read-runtime.object-class (make-object-state)))
    (def state-init (read-runtime.find-method state-class #f ':init!))
    (def (construction-current?)
      (and (eq? object-init (read-runtime.find-method object::t #f ':init!))
           (eq? state-init (read-runtime.find-method state-class #f ':init!))))
    (def (require-issued! read)
      (unless (object-read-issued? read) (error "unissued slot dependency")))
    (def (require-current! read)
      (require-issued! read)
      ;; Keep the original issuance/route/currentness order and diagnostics.
      (unless (object-read-current? read)
        (error "stale slot dependency" (slot-read-key read))))
    (def (same-roots? roots saved)
      (if (null? saved) (null? roots)
        (and (pair? roots) (eq? (car roots) (car saved))
             (same-roots? (cdr roots) (cdr saved)))))
    (def (build owner roots)
      (def seen (make-hash-table-eq))
      (def receivers (make-hash-table-eq))
      (def ordered '())
      (def (collect read)
        (unless (hash-key? seen read)
          (require-issued! read)
          (hash-put! seen read #t)
          (hash-put! receivers (slot-read-receiver read) #t)
          (set! ordered (cons read ordered))
          (for-each collect (slot-read-dependencies read))))
      ;; Preserve the original full preflight, even for malformed root input.
      ;; Only successful traversal copies roots and publishes a cached value.
      (for-each collect roots)
      (make-projection owner (map values roots) (reverse ordered) receivers))
    (def (obtain roots)
      (def owner (table-ref owners roots #f))
      (def instance (and owner (object-%instance owner)))
      (def cached (if instance (hash-ref instance 'projection absent-value) absent-value))
      (cond
       ((and (not (eq? cached absent-value))
             (same-roots? roots (projection-roots cached)))
        (begin
          ;; Signed dependency sequences are reauthenticated on EVERY hit.
          ;; Their equality proves this exact preorder remains complete; it
          ;; does not prove live revisions, values or external sources current.
          (for-each require-issued! (projection-reads cached))
          cached))
       ((construction-current?)
        (let* ((owner (make-object slots:
                        (list (cons 'projection
                          ($self-slot-spec (lambda (self) (build self roots)))))))
               (next (.ref owner 'projection)))
          ;; Existing native slot computation owns success/failure caching.
          ;; Do not install a failed or partially authenticated projection.
          (table-set! owners roots owner)
          next))
       (else (build #f roots))))
    (lambda (roots consume)
      (def selected (without-observation (lambda () (obtain roots))))
      (def traversal (projection-reads selected))
      ;; The receiver set is private/read-only. Nested frames and unwind remain
      ;; per call; sharing structure never shares a populated DFS seen table.
      (parameterize ((active-read-replays
                      (cons (projection-receivers selected) (active-read-replays))))
        (begin0 (consume traversal require-current!)
          (without-observation (lambda () (for-each require-current! traversal))))))))

(def (replay-slot-reads! roots observe)
  (call-with-issued-reads roots
    (lambda (reads current!)
      (without-observation
        (lambda ()
          (for-each
            (lambda (read)
              (current! read)
              (observe (slot-read-receiver read) (slot-read-key read))) reads))))))

;; The Type catalog's warm path delivers ORIGINAL records into its caller's
;; frame. Keep the same selected write protection across work and delivery, not
;; only the initial check. Metadata inspection itself remains unobserved.
(def (reobserve-slot-reads! roots (work void))
  (call-with-issued-reads roots
    (lambda (reads current!)
      (without-observation (lambda () (for-each current! reads)))
      (for-each
        (lambda (read)
          (work)
          (%deliver-slot-read read (slot-read-value read))) reads))))

(def (object-deliver-value self slot value)
  (def table (object-read-table self))
  (def read
    (or (hash-get table slot)
        ;; Explicit instance writes are values, never inferred computed traces.
        (and (object-%overrides self) (hash-key? (object-%overrides self) slot)
             (eq? value (hash-ref (object-%overrides self) slot))
             (let (read (object-record-read self slot value '()))
               (hash-put! table slot read) read))))
  (unless read (error "unrecorded cached slot" slot))
  (%deliver-slot-read read value))
(def (object-read-bootstrap self slot anchor)
  (def key (list 'bootstrap slot))
  (%slot-read-demand! self key)
  (def table (object-read-table self))
  (def read (or (hash-get table key)
               (let (read (object-record-read self key (cdr anchor) '()))
                 (hash-put! table key read) read)))
  (%deliver-slot-read read (cdr anchor)))
;; Structural preparation can itself read MOP configuration. Retain its FIRST
;; preparation dependencies even when later name/presence queries are hot.
(def (object-read-query self key action cache?: (cache? #t))
  (%slot-read-demand! self key)
  (def revision (object-revision self))
  (defvalues (value dependencies) (%call-with-recorded-slot-reads action))
  (unless (= revision (object-revision self)) (error "object changed during query" key))
  (def table (object-read-table self))
  (def read (or (and cache? (hash-get table key))
               (let (read (object-record-read self key value dependencies))
                 (when cache? (hash-put! table key read)) read)))
  (%deliver-slot-read read value))
;; Read a cached slot or compute it through the original cycle-aware protocol.
(def (.ref self slot)
  (%slot-read-demand! self slot)
  (def anchor (bootstrap-anchor self slot))
  (if anchor (object-read-bootstrap self slot anchor)
    (let* ((instance (object-instance self))
           (value (hash-ref instance slot absent-value)))
      (if (eq? value absent-value)
        (let (revision (object-revision self))
          (defvalues (value dependencies)
            (%call-with-recorded-slot-reads
              (lambda ()
                (compute-slot-value self slot
                  (hash-ref/default (object-%slot-funs self) slot
                    (cut cut no-applicable-method self slot))))))
          (unless (and (= revision (object-revision self)) (eq? instance (object-%instance self)))
            (error "object changed during slot computation" slot))
          (def read (object-record-read self slot value dependencies))
          (hash-put! instance slot value)
          (hash-put! (object-read-table self) slot read)
          (when (object-%layout self) (slot-layout-put! (object-%layout self) slot value))
          (%deliver-slot-read read value))
        (if (%slot-read-active?) (object-deliver-value self slot value) value)))))

;; Prepare a shared symbolic shape lazily. Ordinary lookup retains its hash API;
;; opting into an access site adds a coherent receiver-local vector, not a new evaluator.
(def (object-layout self)
  (def instance (object-instance self))
  (or (object-%layout self)
    (let (layout (make-slot-layout
      (append (hash-keys (object-%slot-funs self)) (hash-keys instance)) instance absent-value))
      (set! (object-%layout self) layout) layout)))
;; Guarded access sites reuse only an index, never another receiver's slot value.
;; Observation reuses ordinary .ref, including bootstrap, prechecks and read
;; records; it needs no vector preparation or duplicate metadata delivery path.
;; Failed computations publish no new guard; absence never becomes a cached index.
(def (.ref/inline self cache)
  (if (%slot-read-active?) (.ref self (slot-cache-name cache))
    (let ((layout (object-layout self)) (revision (object-revision self)))
      (if (slot-cache-hit? cache self revision layout) (slot-cache-read cache)
        (let* ((slot (slot-cache-name cache)) (index (slot-cache-index cache layout))
               ;; Only this receiver's current cells may satisfy a switched-owner
               ;; read. An uncomputed cell still delegates to original lazy .ref.
               (stored (if index (slot-layout-ref layout index) absent-value))
               (value (if (eq? stored absent-value) (.ref self slot) stored)))
          (slot-cache-bind! cache self revision layout index) value)))))

;; Get an existing cached slot value from an object
(def (.ref/cached self slot (default false))
  (%slot-read-demand! self slot)
  (def anchor (bootstrap-anchor self slot))
  (if anchor (object-read-bootstrap self slot anchor)
    (let* ((instance (object-instance self)) (value (hash-ref instance slot absent-value)))
      (if (eq? value absent-value)
        ;; A miss is not field absence. Later cache population makes it stale
        ;; without any mutation revision; each default invocation has its own dependencies.
        (object-read-query self (list 'cache-miss slot) default cache?: #f)
        (if (%slot-read-active?) (object-deliver-value self slot value) value)))))

(defclass (NoApplicableMethod Exception) (self slot) transparent: #t)

;; Prototype to put at the end of the list, to handle
;; undefined-prototype-behavior a bit better.
;; Should it send a special message in that case?
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

;; Lazy delegation is ordinary prototype behavior, using the existing missing
;; method hook. Each receiver computes/caches its own fallback only on first miss;
;; direct slots never force it. Delegate failures and cycles propagate unchanged.
(def (fallback-to thunk)
  (unless (procedure? thunk) (error "fallback must be a thunk"))
  (.o (.fallback-handler (thunk))
    (no-applicable-method (lambda (self slot) (.ref (.@ self .fallback-handler) slot)))))

;; : (Object A) <- (IndexedList ? ((Pair s (A s)) <- s:Symbol)) \
;;     supers: ? (ConsTreeOf (Object ?)) defaults: ? (Table ? Symbol)
(def (object<-alist a supers: (supers '()) defaults: (defaults '()))
  (make-object slots: (for/collect (([k . v] a)) (cons k ($constant-slot-spec v)))
               supers: supers defaults: defaults))

(def (object<-hash h supers: (supers '()) defaults: (defaults '()))
  (object<-alist (hash->list/sort h symbol<?) supers: supers defaults: defaults))

(def (object<-fun f keys: (keys '()) supers: (supers '()) defaults: (defaults '()))
  (make-object slots: (map (lambda (k) (cons k ($thunk-slot-spec (cut f k)))) keys)
               supers: supers defaults: defaults))

(def (.mix slots: (slots '()) defaults: (defaults '()) . supers)
  (make-object supers: supers slots: slots defaults: defaults))
(def (.extend self defaults: (defaults '()) . slots)
  (make-object slots: slots supers: [self] defaults: defaults))
;; Merge direct specifications together with their direct protocol/declarations.
;; Declaration compilation registers copied metadata sources before any cache exists.
(def (.+ base override)
  (make-object slots: (object-slots override)
               supers: [(object-supers override)... base] defaults: (object-defaults override)
               protocol: (object-%protocol override) declarations: (object-%declarations override)))

;; : Bool <- (Object _) Symbol
(def (.slot? self slot)
  (if (bootstrap-anchor self slot)
    (begin (object-read-bootstrap self slot (bootstrap-anchor self slot)) #t)
    (object-read-query self (list 'presence slot)
      (cut object-slot-present? self slot))))
(def (object-slot-present? self slot)
  (if (bootstrap-anchor self slot) #t
    (begin (instantiate-object! self) (hash-key? (object-%slot-funs self) slot))))

(defrules .has? ()
  ((_ x) #t)
  ((_ x slot) (.slot? x 'slot))
  ((_ x slot1 slot2 slot3 ...) (and (.has? x slot1) (.has? x slot2 slot3 ...))))

;; : (Listof Symbol) <- (Object _)
(def (.all-slots self)
  (object-read-query self '(names) (cut object-slot-names self)))
(def (object-slot-names self)
  (instantiate-object! self)
  (or (object-%all-slots self)
      (let (esl (merge-super-slots
                 (map (lambda (super) (map car (append (object-slots super) (object-defaults super) (object-%declarations super))))
                      (object-%precedence-list self))))
        (def defined (filter (lambda (slot) (hash-key? (object-%slot-funs self) slot)) esl))
        (set! (object-%all-slots self) defined)
        defined)))

;; : Unit <- (Object A) (Fun _ <- s:Symbol (A s))
(def (.for-each! self fun)
  (for-each (lambda (slot) (fun slot (.ref self slot))) (.all-slots self)))

;; : (Listof Symbol) <- (Object _)
(def (.all-slots/sort object) (list-sort symbol<? (.all-slots object)))

;; : (Listof (Pair s:Symbol (A s))) <- (Object A)
(def (.alist self)
  (map (λ (slot) (cons slot (.ref self slot))) (.all-slots self)))

;; : (Listof (Pair s:Symbol (A s))) <- (Object A)
(def (.alist/sort self)
  (map (λ (slot) (cons slot (.ref self slot))) (.all-slots/sort self)))

;; Force the lazy computation of all slots in an object
;; : (Object A) <- (Object A)
(def (force-object self) (for-each (cut .ref self <>) (.all-slots self)) self)

;; : (Table (A s) <- s:Symbol) <- (Object A)
(def (hash<-object self)
  (object-%instance (force-object self)))

;; For (? test :: proc => pattern),
;;   test = (o?/slots ks)
;;   proc = (.refs/slots ks)
;; : Bool <- (Object _) <- (Listof Symbol)
(def ((o?/slots slots) o) (and (object? o) (andmap (cut .slot? o <>) slots)))
;; : (IndexedList ss A) <- (Object A) <- ss:(Listof Symbol)
(def ((.refs/slots slots) o) (map (cut .ref o <>) slots))

;; the ctx argument exists for macro-scope purposes
;; TODO: use a syntax-parameter for self instead of the ctx argument?
;; Parse the lexical option prefix or legacy :: form before shared slot lowering.
(defsyntax (.o/ctx stx)
  (syntax-case stx ()
    ((_ ctx (:: self) specs ...) #'(object/slots ctx self [] () specs ...))
    ((_ ctx (:: self parents slots ...) specs ...)
     #'(object/slots ctx self parents (slots ...) specs ...))
    ((_ ctx () specs ...) #'(object/slots ctx self [] () specs ...))
    ((_ ctx specs ...)
     (let-values (((self super parents bindings include? rest)
                   (parse-object-options #'ctx #'(specs ...))))
       (with-syntax ((self self) (super super) (parents parents)
                     (bindings bindings) (include? include?) (rest rest))
         #'(object/configured ctx self parents bindings include? super . rest))))))

;; the ctx argument exists for macro-scope purposes
(defrule (object/slots ctx self parents bindings specs ...)
  (object/configured ctx self parents bindings #t #f specs ...))

;; Lower all construction syntax to the same slot/default/inheritance engine.
;; The optional super name denotes the current slot's inherited computation,
;; matching $slot-gen, and never reifies another slot's super-instance.
(defsyntax (object/configured stx)
  (syntax-case stx ()
    ((_ ctx self parents (bindings ...) include? super . slot-specs)
     (let* ((normalized (normalize-slot-specs #'ctx #'slot-specs))
            (methods (car normalized)) (defaults (cadr normalized))
            (names (append (map stx-car defaults) (map stx-car methods)))
            (selected (append (syntax->list #'(bindings ...))
                              (if (syntax-e #'include?) names []))))
       (when (and (identifier? #'super) (bound-identifier=? #'self #'super))
         (raise-syntax-error #f "self and super must be distinct" stx))
       (for-each (lambda (name)
         (when (or (bound-identifier=? name #'self)
                   (and (identifier? #'super) (bound-identifier=? name #'super)))
           (raise-syntax-error #f "slot binding conflicts with self or super" stx name))) selected)
       ;; Preserve lexical shorthand capture; only actual computed formulas need
       ;; the inherited computation alias. Explicit per-slot names keep working.
       (def transformed (if (eq? (syntax-e #'super) #f) methods
         (map (lambda (spec)
           (with-syntax ((super #'super))
             (syntax-case spec (=> =>.+)
               ((name) spec)
               ((name => form args ...) #'(name (super) (form (super) args ...)))
               ((name =>.+ args ...) #'(name (super) (.+ (super) args ...)))
               ((name (next) form) #'(name (next) (let ((super next)) form)))
               ((name form) #'(name (super) form))))) methods)))
       (def prepared (prepare-shared-slot-specs transformed))
       (with-syntax (((selected ...) selected)
                     (((default-slot . default-value) ...) defaults)
                     (((constant-id constant-value) ...) (car prepared))
                     (((prepared-slot prepared-spec ...) ...) (cadr prepared)))
         #'(let ((constant-id constant-value) ...)
             (object/init self parents (selected ...)
                          ((default-slot . default-value) ...)
                          (prepared-slot prepared-spec ...) ...)))))))

(defrule (object/defaults (default-slot default-value) ...)
  (list (cons 'default-slot default-value) ...))

(defrule (object/init self super slots ((default-slot default-value) ...) (slot slotspec ...) ...)
  (make-object
   supers: super
   slots: (%with-shared-slot-bindings slots (slot-self)
           (list (cons 'slot (object/slot-spec %with-shared-slots slot-self self slots slot slotspec ...)) ...))
   defaults: (object/defaults (default-slot default-value) ...)))

(defrules object/slot-spec (=> =>.+ lexical-slot-value)
  ((_ scope slot-self self slots slot lexical-slot-value value)
   ($constant-slot-spec value))
  ((_ scope slot-self self slots slot form)
   ($self-slot-spec (lambda (self)
    (scope slot-self slots self form))))
  ((_ scope slot-self self slots slot => form args ...)
   ($computed-slot-spec (lambda (self superfun)
    (scope slot-self slots self (form (superfun) args ...)))))
  ((_ scope slot-self self slots slot =>.+ args ...)
   (object/slot-spec scope slot-self self slots slot => .+ args ...))
  ((_ scope slot-self self slots slot (next-method) form)
   ($computed-slot-spec (lambda (self superfun)
     (defonce (next-method) (superfun))
     (scope slot-self slots self form))))
  ((_ scope slot-self self slots slot)
   ($constant-slot-spec slot)))

(defsyntax (%with-slots stx)
  (syntax-case stx ()
    ((_ (slots ...) self body ...)
     (with-syntax (((slot ...) (deduplicate-slot-identifiers #'(slots ...))))
       #'(let-id-rule ((slot (.@ self slot)) ...) body ...)))))

;; Core syntax parameters own receiver scope and its unbound-scope error. Core
;; identifier-rules owns field identifier/application expansion and lexical binding.
;; The shared parameter is rebound only while expanding a particular method body;
;; no custom transformer factory or syntax-tree substitution remains in this path.
(defsyntax (%with-shared-slot-bindings stx)
  (syntax-case stx ()
    ((_ (slots ...) (slot-self) body ...)
     (with-syntax (((slot ...) (deduplicate-slot-identifiers #'(slots ...))))
       #'(let ()
           (defsyntax-parameter* receiver slot-self "slot reference outside object method scope")
           (let-syntax ((slot (identifier-rules (set!)
                               ((set! _ value) (syntax-error "slot binding is read-only"))
                               ((_ . args) ((.ref receiver 'slot) . args))
                               (_ (.ref receiver 'slot)))) ...)
             body ...))))))

(defrule (%with-shared-slots slot-self _ self body ...)
  (syntax-parameterize ((slot-self (quote-syntax self))) body ...))

(defrule (%with-direct-slots _ slots self body ...)
  (%with-slots slots self body ...))

(defrules with-slots ()
  ((_ () self body ...) (begin body ...))
  ((_ (slots ...) self body ...) (let (object self) (%with-slots (slots ...) object body ...))))

(defrule (def-slots (slot ...) self)
  (begin
    (def object self)
    (defvalues (slot ...) (values (.@ object slot) ...))))

;; Lower the whole prefixed lexical binding group at once. Gerbil owns syntax
;; traversal and foldr retains nested identifier scopes, including repeated
;; names. Only the explicit context determines generated identifiers. The receiver
;; expression remains lazy and is reevaluated at each use, as before.
(defsyntax (with-prefixed-slots input)
  (syntax-case input ()
    ((_ (prefix slot ...) self body ...)
     #'(with-prefixed-slots prefix (prefix slot ...) self body ...))
    ((_ ctx (prefix slot ...) self body ...)
     (foldr (lambda (slot tail)
       (with-syntax ((var (stx-identifier #'ctx #'prefix slot))
                     (slot slot) (tail tail))
         #'(let-syntax ((var (identifier-rules ()
                              ((_ . args) ((.@ self slot) . args))
                              (_ (.@ self slot))))) tail)))
       #'(begin body ...) (syntax->list #'(slot ...))))))

;; Snapshot prefixed fields with one core definition sequence. Template ellipsis
;; replaces recursive macro invocations; definitions still read in source order,
;; reevaluate the receiver per field and stop at the first failure. These bindings
;; retain their captured values after the receiver's source or metadata changes.
(defsyntax (def-prefixed-slots input)
  (syntax-case input ()
    ((_ (prefix slot ...) self)
     #'(def-prefixed-slots prefix (prefix slot ...) self))
    ((_ ctx (prefix slot ...) self)
     (with-syntax (((var ...) (stx-map (lambda (slot)
                      (stx-identifier #'ctx #'prefix slot)) #'(slot ...))))
       #'(begin (def var (.@ self slot)) ...)))))

;; TODO: use defsyntax-for-match, and in the pattern use (? test :: proc => pattern) to do the job
(defsyntax-for-match .o
  (lambda (stx)
    (syntax-case stx ()
      ((_ args ...)
       (with-syntax ((((k v) ...) (normalize-slot-specs-for-match stx #'(args ...))))
        #'(? (o?/slots '(k ...)) :: (.refs/slots '(k ...)) => [v ...])))))
  (lambda (stx)
    (syntax-case stx ()
      ((_ args ...)
       (with-syntax ((ctx stx)) #'(.o/ctx ctx args ...))))))

(defsyntax (.def stx)
  (syntax-case stx ()
    ((_ args ...)
     (with-syntax ((ctx stx)) #'(.def/ctx ctx args ...)))))

;; the ctx argument exists for macro-scope purposes
(defrules .def/ctx ()
  ((_ ctx (name options ...) slot-defs ...)
   (def name (.o/ctx ctx (:: options ...) slot-defs ...)))
  ((_ ctx name slot-defs ...)
   (def name (.o/ctx ctx () slot-defs ...))))

(defrules .get ()
  ((_ object) object)
  ((_ object slot slots ...) (.get (.ref object 'slot) slots ...)))

(defalias .@ .get)

(defrules .get-set! ()
  ((_ object slot v) (.put! object 'slot v))
  ((_ object slot0 slot1 slots ... v) (.get-set! (.@ object slot0) slot1 slots ... v)))

(defalias .@-set! .get-set!)

(defrules .call ()
  ((_ object slot args ...) ((.get object slot) args ...)))

;; Install a direct specification; all retained descendants lose derived caches.
;; : Unit <- (Object A) s:Symbol (SlotSpec A s)
(def (.putslot! self slot slot-spec)
  (def next (prototype-map-put (object-%slots self) slot slot-spec))
  (before-object-edit! self)
  (set! (object-%slots self) next))
;; Change a default persistently through the same descendant invalidation protocol.
(def (.putdefault! self slot default)
  (def next (prototype-map-put (object-%defaults self) slot default))
  (before-object-edit! self)
  (set! (object-%defaults self) next))
;; Remove every direct method contribution; inherited methods/defaults can reappear.
(def (.removeslot! self slot)
  (def next (prototype-map-remove (object-%slots self) slot))
  (before-object-edit! self)
  (set! (object-%slots self) next))
;; Remove a direct fallback without removing inherited or explicit instance values.
(def (.removedefault! self slot)
  (def next (prototype-map-remove (object-%defaults self) slot))
  (before-object-edit! self)
  (set! (object-%defaults self) next))

(defrules .setslot! () ((_ object. slot slot-spec) (.putslot! object. 'slot slot-spec)))

(defrules .def! ()
  ((_ object slot (:: self _ slots ...) slotspec ...)
   (.putslot! object 'slot
              (object/slot-spec %with-direct-slots #f self
                                (slot slots ...) slot slotspec ...)))
  ((_ object slot (:: self) slotspec ...)
   (.def! object slot (:: self []) slotspec ...))
  ((_ object slot (slots ...) slotspec ...)
   (.def! object slot (:: self [] slots ...) slotspec ...)))

;; Side-effect the value of a field into an object.
;; Assumes the top-object-proto was used.
;; : Unit <- (Object A) s:Symbol (A s)
(def (.put! self slot value)
  (before-object-edit! self)
  (unless (object-%overrides self)
    (set! (object-%overrides self) (make-hash-table-symbolic)))
  (hash-put! (object-%overrides self) slot value)
  (hash-put! (object-instance self) slot value))

(defrules .set! () ((_ object. slot value) (.put! object. 'slot value)))

;; carbon copy / clone c...
;; : (Object A') <- (Object A) <<TODO: type for overrides from A to A' ...>>
(def (.cc self . overrides)
  (def added-hash (make-hash-table-symbolic))
  (def added
    (with-list-builder (c)
      (def (add-slot! slot value)
        (when (hash-key? added-hash slot) (error "Cannot override slot twice" self slot))
        (hash-put! added-hash slot ($constant-slot-spec value))
        (c slot))
      (let loop ((l overrides))
        (match l
          ([] (void))
          ([(? symbol? s) v . r] (add-slot! s v) (loop r))
          ([(? keyword? k) v . r] (add-slot! (make-symbol k) v) (loop r))
          (else (error "invalid object overrides" overrides))))))
  ;; Persistent path copies preserve direct contribution order and share all
  ;; unaffected tree branches. No evaluated receiver or cache is inherited.
  (def slots (foldl (lambda (slot source)
    (prototype-map-put source slot (hash-ref added-hash slot))) (object-%slots self) added))
  ;; Clone direct metadata with direct formulas; .cc does not inherit SELF.
  (make-object slots: slots supers: (object-supers self) defaults: (object-%defaults self)
               protocol: (object-%protocol self) declarations: (object-%declarations self)))

;; Persistent direct overrides now copy balanced-tree paths; allocation and end-to-end
;; workflow performance still require measurement before selecting a faster policy.
;; TODO: maybe have explicitly distinct variants of stateful vs pure object?
;; Could one convert from the other, with some freezing and thawing or copying operations?
;; When overriding a field, should we invalidate all the cached values for all fields?
;; Should we keep an indefinitely growing list of the super formulas?
;; Should we maintain flags as to which formulas do or don't use the super and/or self references,
;; so we know what to invalidate or not?

;; TODO: For type validation,
;; 1. cache which types an instance was tested to be part of,
;; which allows for fast checking of types for recursive data structures,
;; maybe even with cycles.
;; 2. have a mechanism to extend the above to non-instances.
