;;; Shared shapes and receiver-local value vectors for guarded access sites.
(export make-slot-layout slot-layout-shape slot-layout-index slot-layout-ref slot-layout-put!
        make-slot-cache slot-cache-name slot-cache-hit? slot-cache-read slot-cache-bind!)
(import :std/iter (only-in :std/list/list delete-duplicates/hash))

;; Weak values allow unused canonical shapes to disappear; live layouts retain them.
(def shapes (make-hash-table test: equal? weak-values: #t))
;; A shape owns the immutable name-to-index mapping. Cells always belong to one receiver.
(defstruct shape (indices))
(defstruct layout (shape cells))
;; Expose shape identity without exposing its mutable implementation fields.
(defalias slot-layout-shape layout-shape)
;; Canonicalize symbolic identity order, independent of parent/declaration order.
(def (make-slot-layout names initial missing)
  (def keys (list-sort (lambda (a b) (< (object->serial-number a) (object->serial-number b)))
    (delete-duplicates/hash names table: (make-hash-table-eq))))
  (def canonical (or (hash-get shapes keys)
    (let (indices (make-hash-table-eq))
      (for ((name keys) (index (in-range (length keys)))) (hash-put! indices name index))
      (let (result (make-shape indices)) (hash-put! shapes keys result) result))))
  (make-layout canonical (list->vector (map (lambda (name) (hash-ref initial name missing)) keys))))
;; Absence is false; zero is a valid index in Scheme.
(def (slot-layout-index layout name) (hash-get (shape-indices (slot-layout-shape layout)) name))
;; Only the guarded object access path consumes an index obtained from this shape.
(def (slot-layout-ref layout index) (vector-ref (layout-cells layout) index))
;; Keep a prepared vector coherent with ordinary successful object reads/writes.
(def (slot-layout-put! layout name value)
  (let (index (slot-layout-index layout name))
    (when index (vector-set! (layout-cells layout) index value))))
;; One monomorphic access site retains one receiver/version/layout, never just a shape.
(defstruct access-cache (name owner revision layout index))
;; The fixed slot name belongs to the access site, not to the last receiver.
(defalias slot-cache-name access-cache-name)
;; Require symbolic access names; no values or exceptions are cached before success.
(def (make-slot-cache name)
  (unless (symbol? name) (error "symbolic cache slot required"))
  (make-access-cache name #f #f #f #f))
;; Guard receiver identity, monotone revision and exact receiver-local layout together.
(def (slot-cache-hit? cache owner revision layout)
  (and (eq? owner (access-cache-owner cache)) (eqv? revision (access-cache-revision cache))
       (eq? layout (access-cache-layout cache)) (access-cache-index cache)))
;; Read the current vector cell, not a retained value that could outlive invalidation.
(def (slot-cache-read cache) (slot-layout-ref (access-cache-layout cache) (access-cache-index cache)))
;; Bind only after successful computation; an absent index must never become a hit.
(def (slot-cache-bind! cache owner revision layout index)
  (set! (access-cache-owner cache) owner) (set! (access-cache-revision cache) revision)
  (set! (access-cache-layout cache) layout) (set! (access-cache-index cache) index))
