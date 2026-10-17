;;; Persistent ordered prototype specifications, using the standard red-black tree.
(export prototype-map? prototype-map prototype-map-list prototype-map-put prototype-map-remove)
(import :std/struct/rbtree :std/iter)

;; Entries retain contribution order, including repeated methods for one slot.
;; Names point to the first contribution, matching the public replacement protocol.
(defstruct specifications (entries names count))
;; Symbol identity, including distinct uninterned symbols with the same spelling,
;; determines the tree order. Serial numbers are process-local, not serialized IDs.
(def (compare-name left right) (- (object->serial-number left) (object->serial-number right)))
;; Recognize the opaque snapshot without exporting mutable tree accessors.
(defalias prototype-map? specifications?)
;; Own the input list spine; slot specifications and values themselves are shared.
(def (prototype-map entries)
  (if (specifications? entries) entries
    (let ((ordered (RBTree -)) (names (RBTree compare-name)) (count 0))
      (for (entry entries)
        (unless (and (pair? entry) (symbol? (car entry))) (error "symbolic specification required"))
        (unless (rbtree-ref names (car entry) #f) (rbtree-put! names (car entry) count))
        (rbtree-put! ordered count (cons (car entry) (cdr entry)))
        (set! count (+ count 1)))
      (make-specifications ordered names count))))
;; Return fresh list/entry pairs so caller edits cannot corrupt retained snapshots.
(def (prototype-map-list source)
  (for/collect ((entry (in-rbtree-values (specifications-entries source))))
    (cons (car entry) (cdr entry))))
;; Copy only balanced-tree paths; keep all later contributions in their old order.
(def (prototype-map-put source name value)
  (unless (symbol? name) (error "symbolic specification required"))
  (def index (rbtree-ref (specifications-names source) name #f))
  (make-specifications
    (rbtree-put (specifications-entries source) (or index (specifications-count source)) (cons name value))
    (if index (specifications-names source)
      (rbtree-put (specifications-names source) name (specifications-count source)))
    (+ (specifications-count source) (if index 0 1))))
;; Remove every direct contribution for a name; inherited contributions are untouched.
;; Removal rebuilds the order tree; no logarithmic deletion cost is claimed here.
(def (prototype-map-remove source name)
  (prototype-map (filter (lambda (entry) (not (eq? (car entry) name))) (prototype-map-list source))))
