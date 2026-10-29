;;; Shared shapes and receiver-local value vectors for guarded access sites.
(export slot-value-storage make-slot-values slot-values-layout
        make-slot-layout slot-layout-shape slot-layout-index slot-layout-ref slot-layout-set! slot-layout-put!
        make-slot-cache slot-cache-name slot-cache-layout slot-cache-hit? slot-cache-offset slot-cache-index slot-cache-read slot-cache-bind!)
(import (only-in :gerbil/runtime/hash HashTable) (only-in :gerbil/runtime/interface interface-instance? interface-instance-object)
        (only-in :std/hash/misc hash-ensure-ref) :std/iter (only-in :std/list/list delete-duplicates/hash))

;; Weak values allow unused canonical shapes to disappear; live layouts retain them.
(def shapes (make-hash-table test: equal? weak-values: #t))
;; A shape owns the immutable name-to-index mapping. Cells always belong to one receiver.
(defstruct shape (indices names))
(defstruct layout (shape cells missing))
;; Expose shape identity without exposing its mutable implementation fields.
(defalias slot-layout-shape layout-shape)
;; Canonicalize symbolic identity order, independent of parent/declaration order.
;; An explicit initial table seeds all cached values. False selects demand-filled
;; cells: make-vector allocates the same finite layout without scanning values.
;; An old layout supplies only an immutable shape hint. Full identity-set checking
;; precedes reuse, so additions/removals still canonicalize through the weak table.
;; Reusing its ordered names skips sorting/interning, never current value seeding.
(def (make-slot-layout names initial missing previous: (previous #f))
  (def unique (delete-duplicates/hash names table: (make-hash-table-eq)))
  (def hint (and previous (slot-layout-shape previous)))
  (def canonical
    (if (and hint (= (length unique) (length (shape-names hint)))
             (andmap (cut hash-key? (shape-indices hint) <>) unique)) hint
      (let (keys (list-sort (lambda (a b) (< (object->serial-number a) (object->serial-number b))) unique))
        (hash-ensure-ref shapes keys
          (lambda ()
            (let (indices (make-hash-table-symbolic))
              (for ((name keys) (index (in-range (length keys)))) (hash-put! indices name index))
              (make-shape indices keys)))))))
  (def keys (shape-names canonical))
  (make-layout canonical (if initial
    (list->vector (map (lambda (name) (hash-ref initial name missing)) keys))
    (make-vector (length keys) missing)) missing))
;; Explicit backend qualification uses the same evaluator and resource limits.
;; The default owns all computed values in one vector; hash is a measured control.
(def slot-value-storage (make-parameter 'vector))
;; Build the sole instance value store before publishing any read credentials.
;; Symbolic shapes describe uncomputed cells, so construction runs no slot body.
(def (make-slot-values names initial entries missing previous: (previous #f))
  (def values
    (case (slot-value-storage)
      ((vector) (HashTable (make-slot-layout
        (append names (if initial (hash-keys initial) []) (map car entries))
        #f missing previous: previous)))
      ((hash) (make-hash-table-symbolic))
      (else (error "unknown slot value storage" (slot-value-storage)))))
  (when initial (hash-for-each (lambda (key value) (hash-put! values key value)) initial))
  (for (([key . value] entries)) (hash-put! values key value))
  values)
;; Unwrap the standard interface once when exposing its existing value layout.
;; There is no value copy, promotion, lineage alias or auxiliary cache.
(def (slot-values-layout table)
  (and (interface-instance? table)
    (let (value (interface-instance-object table)) (and (layout? value) value))))
;; Translate an uncomputed cell to the caller's ordinary HashTable default.
(def (layout-value self key default)
  (let (index (slot-layout-index self key))
    (if index
      (let (value (vector-ref (layout-cells self) index))
        (if (eq? value (layout-missing self)) default value)) default)))
;; Unknown successful delegation grows the SAME store, after preparing all new
;; metadata/cells. Existing sites retain an immutable shape stamp and must rebind.
(def (layout-store! self key value)
  (using (key :~ symbol?)
    (let (index (slot-layout-index self key))
      (if index (vector-set! (layout-cells self) index value)
        (let (next (make-slot-layout (cons key (shape-names (layout-shape self)))
                      (HashTable self) (layout-missing self)))
          (vector-set! (layout-cells next) (slot-layout-index next key) value)
          (set! (layout-shape self) (layout-shape next))
          (set! (layout-cells self) (layout-cells next)))))
    (void)))
;; Reuse the compiler's HashTable interface for printers, reflection and clients.
;; Only computed cells participate; deletion/clear never evaluate a slot body.
(bind-method! layout::t 'HashTable::ref layout-value)
(bind-method! layout::t 'HashTable::set! layout-store!)
(bind-method! layout::t 'HashTable::update!
  (lambda (self key update default)
    (layout-store! self key (update (layout-value self key default)))))
(bind-method! layout::t 'HashTable::delete!
  (lambda (self key)
    (let (index (slot-layout-index self key))
      (when index (vector-set! (layout-cells self) index (layout-missing self))))))
(bind-method! layout::t 'HashTable::for-each
  (lambda (self proc)
    (for ((key (shape-names (layout-shape self))) (value (layout-cells self)))
      (unless (eq? value (layout-missing self)) (proc key value)))))
(bind-method! layout::t 'HashTable::length
  (lambda (self)
    (for/fold (count 0) ((value (layout-cells self)))
      (if (eq? value (layout-missing self)) count (1+ count)))))
(bind-method! layout::t 'HashTable::copy
  (lambda (self)
    (HashTable (make-layout (layout-shape self) (vector-copy (layout-cells self)) (layout-missing self)))))
(bind-method! layout::t 'HashTable::new
  (lambda (self (size-hint #f)) (HashTable (make-slot-layout [] #f (layout-missing self)))))
(bind-method! layout::t 'HashTable::clear!
  (lambda (self) (vector-fill! (layout-cells self) (layout-missing self))))
;; Absence is false; zero is a valid index in Scheme.
(def (slot-layout-index layout name) (hash-get (shape-indices (slot-layout-shape layout)) name))
;; Only the guarded object access path consumes an index obtained from this shape.
(def (slot-layout-ref layout index) (vector-ref (layout-cells layout) index))
;; Promote one successfully demanded value at its certified CURRENT layout index.
;; Callers must resolve the index from this layout; false values are ordinary data.
(def (slot-layout-set! layout index value) (vector-set! (layout-cells layout) index value))
;; Keep a prepared vector coherent with ordinary successful object reads/writes.
(def (slot-layout-put! layout name value)
  (let (index (slot-layout-index layout name))
    (when index (slot-layout-set! layout index value))))
;; One value guard retains one receiver/version/layout, independent of offset capacity.
(defstruct access-cache (name owner revision layout shape index))
;; An explicit two-shape site adds one immutable descriptor/offset, never cells.
;; This fixed record guard is not a general LRU or a second name/hash registry.
(defstruct (two-shape-cache access-cache) (previous-shape previous-index))
;; The fixed slot name belongs to the access site, not to the last receiver.
(defalias slot-cache-name access-cache-name)
;; An old receiver layout is a shape hint only; its cells never seed a new owner.
(defalias slot-cache-layout access-cache-layout)
;; Sites retain only access guards and one or two descriptor offsets. Successful
;; values always belong to the receiver, so sites have no value-seeding policy.
(def (make-slot-cache name shapes: (count 1))
  (using (count :~ (cut memv <> '(1 2)))
    (unless (symbol? name) (error "symbolic cache slot required"))
    (if (= count 1) (make-access-cache name #f #f #f #f #f)
      (make-two-shape-cache name #f #f #f #f #f #f #f))))
;; Guard receiver identity, monotone revision and exact receiver-local layout together.
(def (slot-cache-hit? cache owner revision layout)
  (using (cache : access-cache)
    (and (eq? owner cache.owner) (eqv? revision cache.revision)
         (eq? layout cache.layout) (eq? cache.shape (slot-layout-shape layout)) cache.index)))
;; Shape identity certifies only an offset, never another receiver's cells.
;; Compare one or two immutable descriptors without resolving a name.
;; False alone denotes a miss; index zero remains a successful offset.
(def (slot-cache-offset cache layout)
  (using (cache : access-cache)
    (if (and cache.layout cache.index
             (eq? (slot-layout-shape layout) cache.shape))
      cache.index
      (if (and (two-shape-cache? cache)
               (eq? (slot-layout-shape layout) (two-shape-cache-previous-shape cache)))
        (two-shape-cache-previous-index cache)
        #f))))
;; Resolve a name only after both bounded descriptor guards miss.
(def (slot-cache-index cache layout)
  (or (slot-cache-offset cache layout)
      (slot-layout-index layout (slot-cache-name cache))))
;; Read the current vector cell, not a retained value that could outlive invalidation.
(def (slot-cache-read cache)
  (using (cache : access-cache) (slot-layout-ref cache.layout cache.index)))
;; Bind only after successful computation; an absent index must never become a hit.
(def (slot-cache-bind! cache owner revision layout index)
  (using (cache : access-cache)
    ;; Successful indexed demand alone changes offset history. Missing offsets
    ;; clear the primary value guard but cannot replace a certified second entry.
    (when (and index cache.index (two-shape-cache? cache)
               (not (eq? (slot-layout-shape layout) cache.shape)))
      (set! (two-shape-cache-previous-shape cache) cache.shape)
      (set! (two-shape-cache-previous-index cache) cache.index))
    (set! cache.owner owner) (set! cache.revision revision)
    (set! cache.layout layout) (set! cache.shape (slot-layout-shape layout)) (set! cache.index index)))
