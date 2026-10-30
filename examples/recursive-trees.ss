;;; Automatic mutually recursive descriptors, shared children and checked FUN use.
(export Tree Message Batch tree-tests tree-total source-tree-tests preparation-tree-tests)
(import ../object
        ../mop
        ../type
        ../number
        ../testing/type
        (runtime: :clan/poo/recursive)
        (prefix-in (only-in ../recursive Generator. bind map-interaction request
                   solve value value-result value?) recursive.))

;; Integer leaves and recursive lists admit a base even at shallow depth. The
;; compiler discovers this knot by descriptor identity instead of unfolding it.
(def Tree (.o self: tree inherit: [Union.]
  (types (list Integer (List tree))) sexp: 'Tree))
;; Messages and batches are mutually recursive; the shared Integer descriptor is
;; discovered once and contributes to both source invalidation and cost rows.
(def Message (.o inherit: [Union.]
  (types (list (Enum idle) (Tuple (Enum send) Integer (List Batch)))) sexp: 'Message))
;; Nullable feedback and tuple/pair carriers exercise guarded recursion together.
(def Batch (.o inherit: [Union.]
  (types (list Bool (Pair Integer (Maybe Message)))) sexp: 'Batch))

;; Evaluation of generated trees also uses the existing explicit request protocol;
;; changing-argument child requests never rely on an unsafe host recursive knot.
(def total-program (.cc recursive.Generator. input: Any output: Integer
  generate: (lambda (tree)
    (if (exact-integer? tree) (recursive.value tree)
      (foldl (lambda (child accumulated)
        (recursive.bind accumulated (lambda (sum)
          (recursive.map-interaction (lambda (value) (+ sum value)) (recursive.request child)))))
        (recursive.value 0) tree)))))
;; The caller supplies an independent source observation depth. Pending does not
;; become zero, a property failure, or a divergence claim.
(def (tree-total tree depth)
  (def result (recursive.solve total-program depth tree))
  (unless (recursive.value? result) (error "tree total did not close"))
  (recursive.value-result result))
;; One existing Reader/FUN action generates, checks and shrinks a deliberately
;; bounded service claim before passing the complete report to its IO consumer.
(def (tree-tests consume)
  (property-action Tree (lambda (tree) (< (abs (tree-total tree 64)) 4)) consume))

;; A shared Record leaf exercises typed carrier derivation and nested Function
;; wrapping through the ordinary FUN action. trigger owns declared revisions;
;; the intentionally false service claim supplies a shrinkable replay witness.
(def (source-tree-tests owner trigger consume)
  (def schema (Record key: [UInt] handler: [(Function [Integer] [Integer])]))
  (def Leaf (.cc schema
    .element?: (lambda (value) (trigger 'admit) (element? schema value))
    .generator: (lambda ()
      (make-generator Leaf
        (lambda (_random size) (trigger 'draw) (make-instance schema key: size handler: abs))
        (lambda (value) (trigger 'shrink)
          (if (zero? (.get value key)) [] (list (.cc value key: 0))))
        (lambda (value) (trigger 'weight) (.get value key)) dependencies: (list owner)))))
  (def descriptor (Tuple (List Leaf) (Pair Leaf (Maybe Leaf))))
  (property-action descriptor (lambda (value)
    (trigger 'property)
    (= ((.@ (car (vector-ref value 1)) handler) -1) 0)) consume
    sampler: (generator descriptor 8 node-budget: 128 search-budget: 20000)))


;; Automatic preparation is part of the property action, so a mixed declaration
;; snapshot is a non-replayable stale report. Shared Record leaves reuse the same
;; factory, Function contracts and dependency ledger across all carrier edges.
(def (preparation-tree-tests owner trigger consume)
  (def schema (Record key: [UInt] handler: [(Function [Integer] [Integer])]))
  (def Left (.cc schema .element?: (cut element? schema <>)
    .generator: (lambda ()
      (trigger 'left Right)
      (make-generator Left (lambda (_random _size) (make-instance schema key: 2 handler: abs))
        (lambda (value) (if (zero? (.get value key)) [] (list (.cc value key: 0))))
        (cut .get <> key) dependencies: (list owner)))))
  (def Right (.cc schema epoch: 0 .element?: (cut element? schema <>)
    .generator: (lambda ()
      (trigger 'right owner)
      (make-generator Right (lambda (_random _size) (make-instance schema key: 2 handler: abs))
        (lambda (value) (if (zero? (.get value key)) [] (list (.cc value key: 0))))
        (cut .get <> key) dependencies: (list owner)))))
  (def Tail (.cc UInt .generator: (lambda ()
    (trigger 'tail owner)
    (make-generator Tail (lambda (_random _size) 2) (lambda (value) (if (zero? value) [] [0])) identity))))
  (property-action (Tuple Left Right (Pair Left Tail))
    (lambda (value) (trigger 'property owner) (= ((.@ (vector-ref value 1) handler) -1) 0)) consume))
