;;; Explicit typed order, transported through the existing key Wrapper protocol.

;; Bind a three-way comparer to its key Type and current source revisions.
;; Totality, transitivity and purity are caller laws; encountered zero/equality
;; disagreement and non-sign results refuse rather than silently merging keys.
(def (table-comparer key compare (dependencies []))
  (using (compare :~ procedure?)
    (def sources (cons key dependencies))
    (def versions (map object-revision sources))
    (.cc Type. Key: key .sources: sources
      .compare: (lambda (left right)
        (with-table-sources sources (lambda ()
          (unless (equal? versions (map object-revision sources)) (error "stale table comparer"))
          (unless (element? key left) (raise-type-error key left 'table-comparer))
          (unless (element? key right) (raise-type-error key right 'table-comparer))
          (def sign (compare left right))
          (unless (and (memv sign '(-1 0 1)) (eq? (= sign 0) (equal? left right)))
            (error "invalid table comparison" left right sign)) sign))))))

;; Pull order back through an explicit key isomorphism. Negated numeric keys thus
;; retain source order, not their incidental host numeric order. Check encountered
;; inverse laws using the existing translation failure and typed admission logic.
(def (table-comparer-wrapper comparer key)
  (unless (eq? (.@ comparer Key) (.@ key Domain)) (error "incompatible comparer domain"))
  (def domain (.@ key Domain)) (def codomain (.@ key Codomain))
  (def ap (.@ key .ap)) (def unap (.@ key .unap))
  ;; Translate only compared keys; no table scan or Function wrapping is needed.
  (def (decode value)
    (translate-table-value codomain domain unap ap value))
  (table-comparer codomain
    (lambda (left right) (.call comparer .compare (decode left) (decode right)))
    (append (list comparer key domain) (.@ comparer .sources))))

;; Reuse the original persistent carrier and point operations, replacing only
;; traversal with Gerbil's list-sort. No ordered backend or balancing is copied.
;; Inclusive/exclusive bounds use Option, so false remains a possible key.
(def (table-order source comparer)
  (unless (eq? (.@ source Key) (.@ comparer Key)) (error "incompatible table order key"))
  (def sources (append (table-sources source) (list comparer) (.@ comparer .sources)))
  (def versions (map object-revision sources)) (def result #f)
  ;; Complete queries/folds hold metadata guards, including the public receiver.
  (def (observe state action)
    (with-table-sources (if result (cons result sources) sources) (lambda ()
      (unless (equal? versions (map object-revision sources)) (error "stale table order"))
      (.call source .validate-shape state)
      (action))))
  ;; Sorting reorders pairs only; existing admitted row and Function identities stay.
  (def (bindings state)
    (list-sort (lambda (left right) (< (.call comparer .compare (car left) (car right)) 0))
      (.call source .list<- state)))
  ;; Reject malformed/foreign bounds before sorting. Reversed intervals refuse;
  ;; equal open endpoints denote the empty interval, not a conflicting request.
  (def (range state lower upper (lower-inclusive? #t) (upper-inclusive? #t))
    (using ((lower-inclusive? :~ boolean?) (upper-inclusive? :~ boolean?))
      (observe state (lambda ()
        (for-each (lambda (bound)
          (unless (or (not bound) (some? bound)) (error "table range bound must be Option"))
          (when (some? bound)
            (unless (element? (.@ source Key) (some-value bound))
              (raise-type-error (.@ source Key) (some-value bound) 'table-order)))) (list lower upper))
        (when (and (some? lower) (some? upper)
          (> (.call comparer .compare (some-value lower) (some-value upper)) 0))
          (error "reversed table range"))
        (filter (lambda (entry)
          (and (or (not lower) (let (sign (.call comparer .compare (car entry) (some-value lower)))
                 (if lower-inclusive? (>= sign 0) (> sign 0))))
               (or (not upper) (let (sign (.call comparer .compare (car entry) (some-value upper)))
                 (if upper-inclusive? (<= sign 0) (< sign 0)))))) (bindings state))))))
  (set! result (.cc methods.table Key: (.@ source Key) Value: (.@ source Value)
    .empty: (.@ source .empty) .sources: sources Comparer: comparer
    ;; Rebind derived methods to this descriptor, not a cached source receiver.
    ;; Point operations keep the original backend and the same metadata discipline.
    .validate-shape: (lambda (state) (observe state (lambda () state)))
    .empty?: (lambda (state) (observe state (lambda () (.call source .empty? state))))
    .ref: (lambda (state key (missing (lambda () (error "missing key"))))
      (observe state (lambda () (.call source .ref state key missing))))
    .acons: (lambda (key row state) (observe state (lambda () (.call source .acons key row state))))
    .remove: (lambda (state key) (observe state (lambda () (.call source .remove state key))))
    .range: range
    .foldl: (lambda (f seed state) (observe state (lambda ()
      (foldl (lambda (entry acc) (f (car entry) (cdr entry) acc)) seed (bindings state)))))
    .foldr: (lambda (f seed state) (observe state (lambda ()
      (foldr (lambda (entry acc) (f (car entry) (cdr entry) acc)) seed (bindings state)))))))
  result)
