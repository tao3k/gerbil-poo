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
  final: #t constructor: :init!)
(defmethod {:init! object}
  (lambda (self ;; : (Object A)
      supers: (supers '()) ;; : (Listof Objects) ;; Actually, can be a pair-tree of Object's and nulls.
      slots: (slots '()) ;; : (Listof (Pair Symbol (SlotSpec ? ?)))
      defaults: (defaults '())
      protocol: (protocol #f) declarations: (declarations '()) bootstrap: (bootstrap #f)) ;; : (Listof (Pair Symbol ?))
    (using (self :- object)
      (set! self.%supers (flatten supers))
      (set! self.%slots (prototype-map slots))
      (set! self.%defaults (prototype-map defaults))
      (set! self.%instance #f)
      (set! self.%reads #f)
      (set! self.%layout #f)
      (set! self.%precedence-list #f)
      (set! self.%slot-funs #f)
      (set! self.%all-slots #f)
      (set! self.%state (make-object-state))
      (set! self.%protocol protocol)
      (set! self.%overrides #f)
      (set! self.%declarations (prototype-map declarations))
      (set! self.%declaration-index #f)
      (set! self.%bootstrap bootstrap)
      ;; The finite direct catalog is a source at construction, including clones.
      ;; Register all descriptors before any C3/definition hook can evaluate one.
      (prototype-map-for-each self.%declarations
        (lambda (_name descriptor) (depend-on-object! self descriptor)))
      (for-each (cut depend-on-object! self <>) self.%supers)
      (when protocol (depend-on-object! self protocol)))))

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
  (let (overrides (object-%overrides self))
    (if overrides
      (map (lambda (entry) (cons (car entry) ($constant-slot-spec (cdr entry))))
           (hash->list/sort overrides symbol<?)) '())))

;; Inspect one direct contribution without constructing the receiver or copying its catalog.
(def (object-direct-slot-specification self name (default #f))
  (prototype-map-ref (object-%slots self) name default))

(def (object-direct-slot-declared? self name)
  (not (eq? (prototype-map-ref (object-%declarations self) name absent-value) absent-value)))

(def (object-slot-assigned? self (name :~ symbol?))
  (let (overrides (object-%overrides self))
    (and overrides (hash-key? overrides name))))

(def (object-direct-protocol? self)
  (and (object-%protocol self) #t))

;; Track dependencies on prototypes, protocol objects and declaration descriptors.
(def (depend-on-object! self source)
  (unless (object? source) (error "object dependency required"))
  (let ((dst-state (object-%state self)))
    (using ((source :- object) (dst-state :- %object-state))
      (depend-on-state! source.%state self dst-state))))
;; The caller must have captured a materialized assignment independent of
;; this slot. Ordinary reads and unclassified edits keep whole-owner edges.
(def (%depend-on-object-except-slot! self source slot)
  (using ((self :- object) (source :- object))
    (depend-on-state! source.%state self self.%state slot)))
;; Read-only revision identity for source-bound external caches.
(def (object-revision self)
  (using (state (object-%state self) :- %object-state)
    state.revision))
;; SOURCES is an ordered list of POO objects. REVISIONS is the list captured
;; by (map object-revision sources) when a Lens or fragment was prepared.
;; Both lists must end together and every live revision must match its snapshot.
;; Compare revision fields without demanding slots or running callbacks.
(def (%object-revisions-current? sources revisions)
  (let loop ((sources sources) (revisions revisions))
    (cond
      ((null? sources) (null? revisions))
      ((null? revisions) #f)
      (else (and (equal? (car revisions) (object-revision (car sources)))
                 (loop (cdr sources) (cdr revisions)))))))
;; Active construction is separate from slot computation: no partial method table
;; or instance is published when an inherited hook tries to read its own receiver.
(def active-object-constructions (make-parameter []))
;; Private, dynamically scoped receiver sets, built only from authenticated reads.
;; Nested replays retain outer ownership; no process-global read-only switch.
(def active-read-replays (make-parameter '()))
;; Clear all derived state together. Explicit instance assignments remain separate.
(def (clear-object-cache! self)
  (set! (object-%declaration-index self) #f)
  (using (self :- object)
    (set! self.%reads #f)
    (set! self.%instance #f)
    (set! self.%layout #f)
    (set! self.%precedence-list #f)
    (set! self.%slot-funs #f)
    (set! self.%all-slots #f)))
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
(def (before-object-edit! self (edited-slot #f))
  (using (state (object-%state self) :- %object-state)
    (when state.sealed? (error "sealed prototype"))
    (invalidate-state! self state check-object-edit clear-object-cache! edited-slot)))
;; Seal the current receiver's specifications and explicit instance assignments.
;; Ancestors can still change through the invalidation protocol unless sealed too.
(def (seal-object! self)
  (using (state (object-%state self) :- %object-state)
    (check-object-edit self state)
    (set! state.sealed? #t)
    self))
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
  (and (object? self)
       (using (self :- object)
         (and (eq? self.%protocol self) self.%bootstrap
              (assq name self.%bootstrap)))))
;; Invoke one optional inherited hook. The continuation is the existing engine,
;; not a second evaluator; hook errors propagate and never install partial caches.
(def (invoke-object-hook self name next . args)
  (def protocol (object-protocol self))
  (cond
    ((bootstrap-anchor self name) => (lambda (entry) (apply (cdr entry) self next args)))
    ((and protocol (.slot? protocol name)) (apply (.ref protocol name) self next args))
    (else (next))))
