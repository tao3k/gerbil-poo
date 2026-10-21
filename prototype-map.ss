;;; Persistent ordered prototype specifications: compact vectors and standard trees.
(export prototype-map? prototype-map prototype-map-policy prototype-map-list prototype-map-put prototype-map-remove)
(import :std/struct/rbtree :std/iter
        (only-in :std/vector/vector vector-filter)
        (only-in :std/list/list length<=n?))

;; Entries retain contribution order, including repeated methods for one slot.
;; Names point to the first contribution, matching the public replacement protocol.
(defstruct specifications (entries names count compact?))
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
        (make-specifications (list->vector (map capture-entry entries)) #f (length entries) #t)
        (tree-map entries (eq? policy 'compact))))))
;; The official RBTree supplies construction and persistent update. Capturing
;; each entry also makes promotion independent of private vector entry handles.
(def (tree-map entries (compact? #f))
  (let ((ordered (RBTree -)) (names (RBTree compare-name)) (count 0))
    (for (input entries)
      (let (entry (capture-entry input))
        (unless (rbtree-ref names (car entry) #f) (rbtree-put! names (car entry) count))
        (rbtree-put! ordered count entry)
        (set! count (+ count 1))))
    (make-specifications ordered names count compact?)))
;; Return fresh list/entry pairs so caller edits cannot corrupt retained snapshots.
(def (prototype-map-list source)
  (for/collect ((entry (if (vector? (specifications-entries source))
                        (in-vector (specifications-entries source))
                        (in-rbtree-values (specifications-entries source)))))
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
          (make-specifications next #f (specifications-count source) #t))
        (let (next (vector-append entries (vector (cons name value))))
          (if (<= (vector-length next) small-map-limit)
            (make-specifications next #f (vector-length next) #t)
            (tree-map (vector->list next) #t)))))
    (let (index (rbtree-ref (specifications-names source) name #f))
      (make-specifications
        (rbtree-put entries (or index (specifications-count source)) (cons name value))
        (if index (specifications-names source)
          (rbtree-put (specifications-names source) name (specifications-count source)))
        (+ (specifications-count source) (if index 0 1)) (specifications-compact? source)))))
;; Remove every direct contribution for a name; inherited contributions are untouched.
;; Compact filtering reuses std/vector. Tree removal retains the existing ordered
;; rebuild, demoting when it fits; an absent name preserves the original snapshot.
;; No logarithmic deletion or deep-value immutability is claimed.
(def (prototype-map-remove source name)
  (def entries (specifications-entries source))
  (if (vector? entries)
    (if (small-index entries name)
      (let (next (vector-filter (lambda (entry) (not (eq? (car entry) name))) entries))
        (make-specifications next #f (vector-length next) #t)) source)
    (if (rbtree-ref (specifications-names source) name #f)
      (prototype-map (filter (lambda (entry) (not (eq? (car entry) name))) (prototype-map-list source))
        policy: (prototype-map-policy source)) source)))
