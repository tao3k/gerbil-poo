;;; Shared shapes and receiver-local value vectors for guarded access sites.
(export make-slot-layout slot-layout-shape slot-layout-index slot-layout-ref slot-layout-set! slot-layout-put!
        make-slot-cache slot-cache-name slot-cache-eager? slot-cache-layout slot-cache-hit? slot-cache-offset slot-cache-index slot-cache-read slot-cache-bind!)
(import (only-in :std/hash/misc hash-ensure-ref) :std/iter (only-in :std/list/list delete-duplicates/hash))

;; Weak values allow unused canonical shapes to disappear; live layouts retain them.
(def shapes (make-hash-table test: equal? weak-values: #t))
;; A shape owns the immutable name-to-index mapping. Cells always belong to one receiver.
(defstruct shape (indices names))
(defstruct layout (shape cells))
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
            (let (indices (make-hash-table-eq))
              (for ((name keys) (index (in-range (length keys)))) (hash-put! indices name index))
              (make-shape indices keys)))))))
  (def keys (shape-names canonical))
  (make-layout canonical (if initial
    (list->vector (map (lambda (name) (hash-ref initial name missing)) keys))
    (make-vector (length keys) missing))))
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
(defstruct access-cache (name owner revision layout index eager?))
;; An explicit two-shape site adds one immutable descriptor/offset, never cells.
;; This fixed record guard is not a general LRU or a second name/hash registry.
(defstruct (two-shape-cache access-cache) (previous-shape previous-index))
;; The fixed slot name belongs to the access site, not to the last receiver.
(defalias slot-cache-name access-cache-name)
;; A creation preference, never value authority: an existing layout is reused.
(defalias slot-cache-eager? access-cache-eager?)
;; An old receiver layout is a shape hint only; its cells never seed a new owner.
(defalias slot-cache-layout access-cache-layout)
;; Capture an explicit seeding choice once, without a per-read policy closure.
;; Default eager remains qualified; demand filling is opt-in for selected fields.
;; Capacity is explicitly one or two shapes; the default record stays unchanged.
(def (make-slot-cache name eager?: (eager? #t) shapes: (count 1))
  (using ((eager? :~ boolean?) (count :~ (cut memv <> '(1 2))))
    (unless (symbol? name) (error "symbolic cache slot required"))
    (if (= count 1) (make-access-cache name #f #f #f #f eager?)
      (make-two-shape-cache name #f #f #f #f eager? #f #f))))
;; Guard receiver identity, monotone revision and exact receiver-local layout together.
(def (slot-cache-hit? cache owner revision layout)
  (using (cache : access-cache)
    (and (eq? owner cache.owner) (eqv? revision cache.revision)
         (eq? layout cache.layout) cache.index)))
;; Shape identity certifies only an offset, never another receiver's cells.
;; Compare one or two immutable descriptors without resolving a name.
;; False alone denotes a miss; index zero remains a successful offset.
(def (slot-cache-offset cache layout)
  (using (cache : access-cache)
    (if (and cache.layout cache.index
             (eq? (slot-layout-shape layout) (slot-layout-shape cache.layout)))
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
               (not (eq? (slot-layout-shape layout) (slot-layout-shape cache.layout))))
      (set! (two-shape-cache-previous-shape cache) (slot-layout-shape cache.layout))
      (set! (two-shape-cache-previous-index cache) cache.index))
    (set! cache.owner owner) (set! cache.revision revision)
    (set! cache.layout layout) (set! cache.index index)))
