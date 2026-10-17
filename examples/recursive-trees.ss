;;; Automatic mutually recursive descriptors, shared children and checked FUN use.
(export Tree Message Batch tree-tests tree-total)
(import ../object ../mop ../type ../number ../property-testing
        (prefix-in ../recursive recursive.))

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
