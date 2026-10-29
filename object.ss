;;-*- Gerbil -*-
;; Prototype Object Orientation Functionally, in Gerbil Scheme.
;;
;; Next version of poo, with multiple inheritance and a budding meta-object protocol.
;; See doc/poo.md for documentation

;; Reexport renamed version of core things we shadow
(export (except-out #t object-record-read object-read-query object-read-bootstrap
                    object-deliver-value require-object-read-route! object-issued-read-current?
                    call-with-issued-reads active-read-replays issue-object-read object-slot-names
                    slot-spec-discards-super? compile-slot-specs prepare-declaration-specifications compute-object-precedence!) @object? @make-object)

(import
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
  (only-in ./read-route require-read-route! make-read-issuer)
  ./object-state
  ./prototype-map
  ./slot-layout
  (only-in :std/list/list-builder with-list-builder)
  (only-in :std/list/list flatten delete-duplicates/hash map-in-order)
  (only-in :std/string/symbol symbol<?)
  :std/stxparam
  (only-in :std/values first-value)
  (only-in :gerbil/runtime/c3 c4-linearize*)
  (only-in ./support/base λ let-id-rule defonce awhen))

;; TODO: formalize (Object A S D) and the type conditions under which an object is instantiatable?
(defstruct object ;; = (Object A)
  (%supers ;; : private finite direct parent list
   %slots ;; : persistent ordered direct specifications
   %defaults ;; : persistent ordered defaults
   %reads ;; receiver-local read records; no global receiver retention
   %layout ;; : optional inline-access alias to the primary value vector
   %instance ;; : standard HashTable interface over the sole receiver-local value store
   %precedence-list ;; : (Listof (Object ?)) ; linearization of the supers DAG
   %slot-funs ;; : (Table (Fun (A_ k)) <- k:Symbol) ; functions to compute slots
   %all-slots
   %state ;; mutation revision, sealed flag and weak dependency edges
   %protocol ;; optional ordinary POO object supplying inheritance hooks
   %overrides ;; explicit INSTANCE assignments, never inherited specifications
   %declarations
   %declaration-index ;; lazy effective/visible catalog; cleared with every source revision
   %bootstrap) ;; explicit constant hook anchors; only the self-hosted root uses them : (Listof Symbol) ; definition order for all slot keys
  constructor: :init!)
(defmethod {:init! object}
  (lambda (self ;; : (Object A)
      supers: (supers '()) ;; : (Listof Objects) ;; Actually, can be a pair-tree of Object's and nulls.
      slots: (slots '()) ;; : (Listof (Pair Symbol (SlotSpec ? ?)))
      defaults: (defaults '())
      protocol: (protocol #f) declarations: (declarations '()) bootstrap: (bootstrap #f)) ;; : (Listof (Pair Symbol ?))
    (set! (object-%supers self) (flatten supers))
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
    (set! (object-%declarations self) (prototype-map declarations))
    (set! (object-%declaration-index self) #f)
    (set! (object-%bootstrap self) bootstrap)
    ;; The finite direct catalog is a source at construction, including clones.
    ;; Register all descriptors before any C3/definition hook can evaluate one.
    (prototype-map-for-each (object-%declarations self)
      (lambda (_name descriptor) (depend-on-object! self descriptor)))
    (for-each (cut depend-on-object! self <>) (object-%supers self))
    (when protocol (depend-on-object! self protocol))))

;; Public topology reflection owns its spine; parent objects retain their identity.
;; Internal construction/lookup borrows %supers, avoiding public snapshot copies.
(def (object-supers self) (list-copy (object-%supers self)))
;; Reflection preserves contribution order without exposing the persistent storage.
(def (object-slots self) (prototype-map-list (object-%slots self)))
;; Reflection returns an owned list while the persistent map remains shareable.
(def (object-defaults self) (prototype-map-list (object-%defaults self)))
;; Own the reflected catalog pairs while sharing descriptor objects as registered
;; sources. Catalog membership changes require a freshly constructed receiver.
(def (object-declarations self) (prototype-map-list (object-%declarations self)))
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
  (set! (object-%declaration-index self) #f)
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
    (when (memq self (compute-object-precedence! parent)) (error "cyclic prototype revision"))) parents)
  (compute-object-precedence! (make-object supers: parents))
  (before-object-edit! self)
  (for-each (cut depend-on-object! self <>) parents)
  (set! (object-%supers self) parents))
;; Standard generalized set! reaches the same checked topology/invalidation boundary.
(defalias object-supers-set! replace-object-supers!)
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
(def (instantiate-object! self previous: (previous #f))
  (unless (object? self) (error "Not an object"))
  (unless (object-%instance self)
    (when (memq self (active-object-constructions)) (error "recursive object construction"))
    (parameterize ((active-object-constructions (cons self (active-object-constructions))))
      (try
        (defvalues (instance dependencies)
          (%call-with-recorded-slot-reads
            (lambda ()
              (compute-object-precedence! self)
              (compute-slot-funs! self)
              (make-slot-values (hash-keys (object-%slot-funs self))
                (object-%overrides self)
                (if (eq? (object-%protocol self) self) (or (object-%bootstrap self) []) [])
                absent-value previous: previous))))
        (set! (object-%instance self) instance)
        (hash-put! (object-read-table self) '(preparation)
          (object-record-read self '(preparation) instance dependencies))
        (catch (cause) (clear-object-cache! self) (raise cause))))))

(defclass (InvalidObject Exception) (slots) transparent: #t)
(def (invalid-object-summary self)
  (InvalidObject slots: (append (prototype-map-keys (object-%slots self))
    (prototype-map-keys (object-%defaults self)) (prototype-map-keys (object-%declarations self)))))

;; Public inspection owns its spine; mutating it cannot edit cached C3 membership.
;; Internal construction borrows the private result without per-call snapshot copies.
(def (compute-precedence-list! self (heads '()))
  (list-copy (compute-object-precedence! self heads)))
;; Delegate ordering to core C4. Hook continuations receive independent snapshots;
;; compare against the private canonical order and retain only that canonical order.
;; Hook errors and changed/improper orders clear the candidate cache before escape.
(def (compute-object-precedence! self (heads '()))
  ;; Default warm queries need neither traversal state nor a second admission.
  ;; Explicit diagnostic heads retain their original preparation and error order.
  (or (and (null? heads) (object-%precedence-list self)) (let ()
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
                  [object] (list (object-%supers object)) suffix: (lambda (_) #f)
                  get-precedence-list:
                  (lambda (super) (compute super [object . heads]))
                  eq: eq?
                  get-name: invalid-object-summary)))
            (hash-remove! active object)
            (set! (object-%precedence-list object) precedence-list)
            (try
              (let (chosen (invoke-object-hook object 'compute-precedence-list (lambda () (list-copy precedence-list))))
                (unless (and (list? chosen) (= (length chosen) (length precedence-list))
                             (andmap eq? chosen precedence-list))
                  (error "inheritance hook must preserve checked C3 order"))
                precedence-list)
              (catch (cause) (clear-object-cache! object) (raise cause)))))))))))

;; Resolve/register each finite catalog before running ANY definition hook in C3.
;; The one-shot private action retains actual type identities, never a validation
;; verdict. Empty catalogs allocate neither scratch receivers nor pending actions.
(def (prepare-declaration-specifications self)
  (and (positive? (prototype-map-length (object-%declarations self)))
    (let (definitions (with-list-builder (add)
      (prototype-map-for-each (object-%declarations self)
        (lambda (name descriptor)
          (def type (.@ descriptor .type))
          (depend-on-object! self type)
          (add (lambda (scratch) (.call type .slot.define descriptor name scratch)))))))
      (lambda ()
        (let (scratch (make-object))
          (for-each (lambda (define-slot) (define-slot scratch)) definitions)
          (cons (object-%slots scratch) (object-%defaults scratch)))))))
;; Capture the whole C3 family first, then define each source in its original order.
;; Incremental scratch visibility remains local to each catalog; nothing pending
;; escapes or survives a failed build. Direct specifications still override declarations.
(def (compute-slot-funs! self)
  (def h (make-hash-table-symbolic))
  (def prepared (map-in-order (lambda (super) (cons super (prepare-declaration-specifications super)))
                             (reverse (object-%precedence-list self))))
  (def sources (map-in-order (lambda (entry)
    (cons (car entry) (and (cdr entry) ((cdr entry))))) prepared))
  ;; The same consumers handle normalized declarations and persistent maps;
  ;; no private entry pair escapes and no direct-map snapshot is materialized.
  (def (default! slot value) (hash-put! h slot (list ($constant-slot-spec value))))
  ;; Keep original admission order and diagnostics even for shadowed input.
  (def (contribution! slot spec)
    (def discards? (slot-spec-discards-super? spec))
    (unless (or discards? ($computed-slot-spec? spec)) (apply-slot-spec self spec #f))
    (if discards? (hash-put! h slot (list spec))
      (hash-ensure-modify! h slot (lambda () []) (cut cons spec <>))))
  (for (([super . declarations] sources))
    (when declarations (prototype-map-for-each (cdr declarations) default!))
    (prototype-map-for-each (object-%defaults super) default!))
  (for (([super . declarations] sources))
    (when declarations (prototype-map-for-each (car declarations) contribution!))
    (prototype-map-for-each (object-%slots super) contribution!))
  ;; Compile every surviving chain BEFORE invoking any user hook. A hook cannot
  ;; change the payload capture time of another field's SlotSpec.
  (for (([slot . specs] (hash->list h)))
    (hash-put! h slot (compile-slot-specs self slot specs)))
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
(defvalues (issue-object-read object-read-issued? object-read-issuance) (make-read-issuer))
;; Capture source state and preserve preparation parents at this one boundary.
;; The existing read module owns provenance, without receiver-accessor callbacks.
(def (object-record-read self key value dependencies)
  (def preparation (and (object-%reads self) (hash-get (object-%reads self) '(preparation))))
  (def parents
    (if (and preparation (not (and (pair? key) (memq (car key) '(preparation bootstrap)))))
      (cons preparation dependencies) dependencies))
  (issue-object-read self key (object-revision self) (object-%instance self) value parents object-read-current?))

(def (require-object-read-route! read)
  (def receiver (slot-read-receiver read))
  (require-read-route! (slot-read-key read)
    (object-%reads receiver) (object-%instance receiver)))

(def object-construction-current?
  (let* ((object-init (read-runtime.find-method object::t #f ':init!))
         (state-class (read-runtime.object-class (make-object-state)))
         (state-init (read-runtime.find-method state-class #f ':init!)))
    (lambda ()
      (and (eq? object-init (read-runtime.find-method object::t #f ':init!))
           (eq? state-init (read-runtime.find-method state-class #f ':init!))))))
(def call-with-issued-reads
  (let ()
    ;; The index owns neither roots nor cache receivers. A live projection keeps
    ;; its ordinary native cache owner alive; GC eviction is always a cold miss.
    ;; No mutable visitation set or successful validation result is retained.
    (def owners (make-table test: eq? weak-keys: #t weak-values: #t))
    (defstruct projection (owner roots reads receivers) final: #t)
    ;; A cold cache owner must not dispatch an injected CLOS initializer during
    ;; authentication. Changed constructor metadata keeps the original DFS path.
    (def construction-current? object-construction-current?)
    (def (require-issued! read)
      (unless (object-read-issued? read) (error "unissued slot dependency")))
    (def (require-current! read)
      (require-issued! read)
      ;; Birth was authenticated immediately above; retain route and freshness
      ;; on every visit and the existing post-observer visit.
      (require-object-read-route! read)
      (unless (object-issued-read-current? read)
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
      ;; The cold selector admits a finite root spine before entering this DFS.
      ;; Preserve full issuance preflight and its order for every admitted root.
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
       (else
        ;; A warm signature already proves exact finite membership. On a miss,
        ;; reject improper/cyclic caller spines before allocation or traversal;
        ;; successful validation itself is never stored as a reusable verdict.
        (using (roots :~ list?)
          (if (construction-current?)
            (let* ((owner (make-object slots:
                            (list (cons 'projection
                              ($self-slot-spec (lambda (self) (build self roots)))))))
                   (next (.ref owner 'projection)))
              ;; Existing slot computation owns success/failure caching.
              ;; Do not install a failed or partially authenticated projection.
              (table-set! owners roots owner)
              next)
            (build #f roots))))))
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
  (def saved (and cache? (hash-get table key)))
  ;; Unobserved readers only consume the private value, never the record. Before
  ;; observed delivery, replace a damaged name snapshot through the SAME issuer;
  ;; the preparation parent survives, and old credentials remain rejected.
  (def read (or (and saved
                    (or (not (and (%slot-read-active?) (equal? key '(names))))
                        (object-read-issued? saved)) saved)
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
          (%deliver-slot-read read value))
        (if (%slot-read-active?) (object-deliver-value self slot value) value)))))

;; Expose the existing primary vector by identity, without seeding another store.
;; The explicit hash qualification stays symbolic and never allocates a second cache.
(def (object-layout self previous: (previous #f))
  (instantiate-object! self previous: previous)
  (or (object-%layout self)
    (let (layout (slot-values-layout (object-%instance self)))
      (when layout (set! (object-%layout self) layout)) layout)))
;; Sites retain offsets, never values. Observed/bootstrap reads use ordinary .ref;
;; live layouts certify preparation and are discarded by supported edits.
;; Failures bind no guard; absent names never become certified indices.
(def (.ref/inline self cache)
  (def slot (slot-cache-name cache))
  (if (%slot-read-active?) (.ref self slot)
    (let (prepared (object-%layout self))
      (if (and (not prepared) (bootstrap-anchor self slot)) (.ref self slot)
        (let (layout (or prepared (object-layout self previous: (slot-cache-layout cache))))
          (if (not layout) (.ref self slot)
            (let (revision (object-revision self))
              (if (slot-cache-hit? cache self revision layout)
                (let (value (slot-cache-read cache))
                  (if (eq? value absent-value) (.ref self slot) value))
                (let* ((shape (slot-layout-shape layout))
                       (index (slot-cache-index cache layout))
                       (stored (if index (slot-layout-ref layout index) absent-value))
                       (value (if (eq? stored absent-value) (.ref self slot) stored)))
                  ;; Evaluation may memoize a dynamic dependency and reorder cells.
                  (slot-cache-bind! cache self revision layout
                    (if (eq? shape (slot-layout-shape layout)) index
                      (slot-layout-index layout slot))) value)))))))))

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
;; Immutable direct maps retain their policy and sharing; receiver caches and
;; explicit instance assignments are never inherited from the override object.
(def (.+ base override)
  (make-object slots: (object-%slots override)
               supers: [(object-%supers override)... base] defaults: (object-%defaults override)
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

;; Public structural reflection owns its finite list spine. Symbols are shared;
;; callers can edit their result without changing the cached directory or shapes.
(def (.all-slots self)
  (map values (object-slot-names self)))
;; Private borrowed directory for enumerators that never expose its spine. The
;; same query still delivers the original preparation/observation dependencies.
(def (object-slot-names self)
  (object-read-query self '(names) (lambda ()
    (instantiate-object! self)
    (or (object-%all-slots self)
      (let (esl (merge-super-slots
                 (map (lambda (super) (append (prototype-map-keys (object-%slots super))
                   (prototype-map-keys (object-%defaults super)) (prototype-map-keys (object-%declarations super))))
                      (object-%precedence-list self))))
        (def defined (filter (lambda (slot) (hash-key? (object-%slot-funs self) slot)) esl))
        (set! (object-%all-slots self) defined)
        defined)))))

;; : Unit <- (Object A) (Fun _ <- s:Symbol (A s))
(def (.for-each! self fun)
  (for-each (lambda (slot) (fun slot (.ref self slot))) (object-slot-names self)))

;; : (Listof Symbol) <- (Object _)
(def (.all-slots/sort object) (list-sort symbol<? (.all-slots object)))

;; : (Listof (Pair s:Symbol (A s))) <- (Object A)
(def (.alist self)
  (map (λ (slot) (cons slot (.ref self slot))) (object-slot-names self)))

;; : (Listof (Pair s:Symbol (A s))) <- (Object A)
(def (.alist/sort self)
  (map (λ (slot) (cons slot (.ref self slot))) (.all-slots/sort self)))

;; Force the lazy computation of all slots in an object
;; : (Object A) <- (Object A)
(def (force-object self) (for-each (cut .ref self <>) (object-slot-names self)) self)

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
   slots: (prototype-map
            (%with-shared-slot-bindings slots (slot-self)
              (list (cons 'slot (object/slot-spec %with-shared-slots slot-self self slots slot slotspec ...)) ...))
            policy: 'compact)
   defaults: (prototype-map (object/defaults (default-slot default-value) ...) policy: 'compact)))

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

;; Admit the symbolic key before invalidation, then install an explicit value.
;; Bad keys retain all source/cache generations; argument evaluation is not undone.
;; Assumes the top-object-proto was used.
;; : Unit <- (Object A) s:Symbol (A s)
(def (.put! self slot value)
  (using (slot :~ symbol?)
    (before-object-edit! self)
    (unless (object-%overrides self)
      (set! (object-%overrides self) (make-hash-table-symbolic)))
    (hash-put! (object-%overrides self) slot value)
    (hash-put! (object-instance self) slot value)))

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
  (make-object slots: slots supers: (object-%supers self) defaults: (object-%defaults self)
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
