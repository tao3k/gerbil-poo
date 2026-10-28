;;; Persistent ordered prototype specifications: compact vectors and standard trees.
(export prototype-map? prototype-map prototype-map-policy prototype-map-list prototype-map-keys
        prototype-map-for-each prototype-map-put prototype-map-remove)
(import :std/struct/rbtree :std/iter
        (only-in :std/vector/vector vector-filter)
        (only-in :std/list/list length<=n?))

;; Entries retain contribution order, including repeated methods for one slot.
;; Names point to the first contribution, matching the public replacement protocol.
(defstruct specifications (entries names count next compact?))
;; Count contributions, not distinct names: repeated methods still occupy cells.
;; This bounds each compact scan/copy; larger maps retain the standard tree path.
(def small-map-limit 8)
;; Search by symbol identity and stop at the FIRST contribution, including index 0.
;; The private vector and entry pairs are never exposed to snapshot consumers.
(def (small-index entries name)
  (let loop ((index 0))
    (and (< index (vector-length entries))
      (if (eq? name (car (vector-ref entries index))) index (loop (1+ index))))))
;; Symbol identity, including distinct uninterned symbols with the same spelling,
;; determines the tree order. Serial numbers are process-local, not serialized IDs.
(def (compare-name left right) (- (object->serial-number left) (object->serial-number right)))
;; Recognize the opaque snapshot without exporting mutable tree accessors.
(defalias prototype-map? specifications?)
;; Capture one private entry pair while retaining the original value/SlotSpec.
;; The existing symbolic-specification refusal remains the constructor policy.
(def (capture-entry entry)
  (unless (and (pair? entry) (symbol? (car entry))) (error "symbolic specification required"))
  (cons (car entry) (cdr entry)))
;; Observe the selected policy, independent of the current physical backend.
;; A promoted compact snapshot retains its policy for subsequent removal/demotion.
(def (prototype-map-policy source)
  (if (specifications-compact? source) 'compact 'tree))
;; Select storage explicitly with the core contract binder. New lists default to
;; trees; an existing snapshot retains its policy unless conversion is requested.
;; Conversion owns fresh entry pairs and never changes the original snapshot.
(def (prototype-map entries policy: (policy #f))
  (using (policy :~ (one-of #f tree compact))
    (if (specifications? entries)
      (if (or (not policy) (eq? policy (prototype-map-policy entries))) entries
        (prototype-map (prototype-map-list entries) policy: policy))
      (if (and (eq? policy 'compact) (length<=n? entries small-map-limit))
        (make-specifications (list->vector (map capture-entry entries)) #f (length entries) (length entries) #t)
        (tree-map entries (eq? policy 'compact))))))
;; The official RBTree supplies construction and persistent update. Capturing
;; each entry also makes promotion independent of private vector entry handles.
(def (tree-map entries (compact? #f))
  (let ((ordered (RBTree -)) (names (RBTree compare-name)) (count 0))
    (for (input entries)
      (let (entry (capture-entry input))
        ;; The first ordinal remains the replacement target. Later ordinals need
        ;; no ordering among themselves; immutable consing retains every method.
        ;; Keep the common singleton as its ordinal, without allocating a list.
        ;; Only actual duplicate methods require a position spine.
        (rbtree-update! names (car entry)
          (lambda (positions)
            (cond ((not positions) count)
                  ((pair? positions) (cons (car positions) (cons count (cdr positions))))
                  (else (list positions count)))) #f)
        (rbtree-put! ordered count entry)
        (set! count (+ count 1))))
    (make-specifications ordered names count count compact?)))
;; Delegate ordered traversal to the existing compact vector or standard RBTree.
;; This private iterator never crosses the snapshot boundary.
(def (in-specifications source)
  (let (entries (specifications-entries source))
    (if (vector? entries) (in-vector entries) (in-rbtree-values entries))))
;; Deliver only symbols and shared payloads, never private entry pairs/handles.
;; Standard iteration preserves order and stops at the original callback refusal.
(def (prototype-map-for-each source consume)
  (using (consume :~ procedure?)
    (for (entry (in-specifications source)) (consume (car entry) (cdr entry)))))
;; Names need an owned spine, without exporting/copying every unused entry pair.
(def (prototype-map-keys source)
  (for/collect (entry (in-specifications source)) (car entry)))
;; Return fresh list/entry pairs so caller edits cannot corrupt retained snapshots.
(def (prototype-map-list source)
  (for/collect (entry (in-specifications source))
    (cons (car entry) (cdr entry))))
;; Copy a bounded compact vector or standard balanced-tree paths. Promotion keeps
;; every contribution in order; all later same-name methods retain their identity.
(def (prototype-map-put source name value)
  (unless (symbol? name) (error "symbolic specification required"))
  (def entries (specifications-entries source))
  (if (vector? entries)
    (let (index (small-index entries name))
      (if index
        (let (next (vector-copy entries))
          (vector-set! next index (cons name value))
          (make-specifications next #f (specifications-count source) (specifications-count source) #t))
        (let (next (vector-append entries (vector (cons name value))))
          (if (<= (vector-length next) small-map-limit)
            (make-specifications next #f (vector-length next) (vector-length next) #t)
            (tree-map (vector->list next) #t)))))
    (let* ((positions (rbtree-ref (specifications-names source) name #f))
           (index (and positions (if (pair? positions) (car positions) positions)))
           (next (specifications-next source)))
      (make-specifications
        (rbtree-put entries (or index next) (cons name value))
        (if index (specifications-names source)
          (rbtree-put (specifications-names source) name next))
        (+ (specifications-count source) (if index 0 1))
        (+ next (if index 0 1)) (specifications-compact? source)))))
;; Remove every direct contribution for a name; inherited contributions are untouched.
;; Compact filtering reuses std/vector. Tree deletion delegates only the indexed
;; ordinals to persistent RBTree removal; surviving ordinals are never renumbered.
;; A monotone next ordinal prevents delete/reinsert from overwriting survivors.
;; Explicit compact policy still demotes at eight live contributions; missing
;; names preserve the exact snapshot. Payloads are not deeply copied.
(def (prototype-map-remove source name)
  (def entries (specifications-entries source))
  (if (vector? entries)
    (if (small-index entries name)
      (let (next (vector-filter (lambda (entry) (not (eq? (car entry) name))) entries))
          (make-specifications next #f (vector-length next) (vector-length next) #t)) source)
    (let (indexed (rbtree-ref (specifications-names source) name #f))
      (if indexed
        (let* ((positions (if (pair? indexed) indexed (list indexed)))
               (ordered (for/fold (tree entries) (index positions) (rbtree-remove tree index)))
               (count (- (specifications-count source) (length positions)))
               (next (make-specifications ordered
                       (rbtree-remove (specifications-names source) name)
                       count (specifications-next source) (specifications-compact? source))))
          (if (and (specifications-compact? source) (<= count small-map-limit))
            (prototype-map (prototype-map-list next) policy: 'compact) next))
        source))))
