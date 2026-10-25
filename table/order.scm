;;; Explicit typed order, transported through the existing key Wrapper protocol.

;; Weak revision seals identify constructor-owned compare/procedure pairs without
;; retaining descriptors. A copied or modified protocol cannot borrow a stale fast path.
(def %table-comparer-versions (make-table test: eq? weak-keys: #t))

;; The capability identity check is valid only for the constructor's unchanged fields.
(def (table-comparer-current? comparer)
  (def revision (table-ref %table-comparer-versions comparer #f))
  (and revision (= revision (object-revision comparer))))

;; Bind a three-way comparer to its key Type and current source revisions.
;; Totality, transitivity and purity are caller laws; encountered zero/equality
;; disagreement and non-sign results refuse rather than silently merging keys.
(def (table-comparer key compare (dependencies []))
  (using (compare :~ procedure?)
    (def sources (cons key dependencies))
    (def versions (map object-revision sources))
    (def result (.cc Type. Key: key .sources: sources .procedure: compare
      .compare: (lambda (left right)
        (with-table-sources sources (lambda ()
          (unless (equal? versions (map object-revision sources)) (error "stale table comparer"))
          (unless (element? key left) (raise-type-error key left 'table-comparer))
          (unless (element? key right) (raise-type-error key right 'table-comparer))
          (def sign (compare left right))
          (unless (and (memv sign '(-1 0 1)) (eq? (= sign 0) (equal? left right)))
            (error "invalid table comparison" left right sign)) sign)))))
    (table-set! %table-comparer-versions result (object-revision result))
    result))

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

;; Reuse the original persistent carrier, point operations and positioned traversal.
;; Gerbil list-sort supplies only the fallback; no balancing algorithm is copied.
;; Inclusive/exclusive bounds use Option, so false remains a possible key.
(def (table-order source comparer)
  (unless (eq? (.@ source Key) (.@ comparer Key)) (error "incompatible table order key"))
  (def sources (append (table-sources source) (list comparer) (.@ comparer .sources)))
  ;; Identity is a conservative capability check, never function equivalence inference.
  (def seek? (and (.has? source Comparer .seek<-)
    (table-comparer-current? (.@ source Comparer)) (table-comparer-current? comparer)
    (eq? (.@ (.@ source Comparer) Key) (.@ source Key))
    (eq? (.@ (.@ source Comparer) .procedure) (.@ comparer .procedure))))
  (when seek? (set! sources (append sources (list (.@ source Comparer))
    (.@ (.@ source Comparer) .sources))))
  ;; Shared Key/Value/comparer origins are prepared once, not revisited per alias.
  (set! sources (delete-duplicates/hash sources table: (make-hash-table-eq) from-end?: #t))
  (def admit-source (table-shape-checker source))
  (def versions (map object-revision sources)) (def result #f)
  ;; Complete queries/folds hold metadata guards, including the public receiver.
  (def (protect action)
    (with-table-sources (if result (cons result sources) sources) (lambda ()
      (unless (equal? versions (map object-revision sources)) (error "stale table order"))
      (action))))
  ;; Existing observations still admit their root within the common protected scope.
  (def (observe state action)
    (protect (lambda () (admit-source state) (action))))
  ;; A typed point update preserves shape only when the backend declares that law.
  ;; Run the operation before recording its result: raised callbacks retain no root.
  ;; Unknown roots still pass full admission, including after a failed update.
  (def (update state key action)
    (observe state (lambda ()
      (unless (element? (.@ source Key) key)
        (raise-type-error (.@ source Key) key 'table-order))
      (admit-source (action) #t))))
  ;; Sorting reorders pairs only; existing admitted row and Function identities stay.
  (def (bindings state)
    (list-sort (lambda (left right) (< (.call comparer .compare (car left) (car right)) 0))
      (.call source .list<- state)))
  ;; Shared admission runs before backend positioning or the fallback enumeration.
  (def (bounds lower upper lower-inclusive? upper-inclusive?)
    (using ((lower-inclusive? :~ boolean?) (upper-inclusive? :~ boolean?))
      (for-each (lambda (bound)
        (unless (or (not bound) (some? bound)) (error "table range bound must be Option"))) (list lower upper))
      ;; Own both Option shells before predicates/comparisons can alter caller
      ;; buffers. Logical key immutability remains the existing order premise.
      (def lo (map/option identity lower)) (def hi (map/option identity upper))
      (for-each (lambda (bound)
        (when (some? bound)
          (unless (element? (.@ source Key) (some-value bound))
            (raise-type-error (.@ source Key) (some-value bound) 'table-order)))) (list lo hi))
      (when (and lo hi (> (.call comparer .compare (some-value lo) (some-value hi)) 0))
        (error "reversed table range"))
      (values lo hi)))
  ;; Position once in the declared backend; mismatched order retains the reference
  ;; sort/filter path. No backend cursor is trusted merely because it is present.
  (def (entries state lower inclusive?)
    (if seek? (.call source .seek<- state lower inclusive?)
      (iter (filter (lambda (entry)
        (or (not lower) (let (sign (.call comparer .compare (car entry) (some-value lower)))
          (if inclusive? (>= sign 0) (> sign 0))))) (bindings state)))))
  ;; Publish the same ordered cursor for further order/Wrapper composition.
  ;; Existing Iterator mapping guards every deferred pull, including EOF, without
  ;; copying entries or keeping metadata protection across coroutine suspension.
  (def (position state lower inclusive?)
    (observe state (lambda ()
      (let-values (((lo _hi) (bounds lower #f inclusive? #t)))
        (iterator-map identity (entries state lo inclusive?)
          (lambda (action) (observe state action)))))))
  ;; Standard coroutine iteration supplies sticky EOF and demand-driven traversal.
  ;; The outer Iterator guard covers every pull, including repeated EOF, without
  ;; retaining metadata protection across a yield or copying admitted payloads.
  (def (range-cursor state lower upper (lower-inclusive? #t) (upper-inclusive? #t))
    (observe state (lambda ()
      (let-values (((lo hi) (bounds lower upper lower-inclusive? upper-inclusive?)))
        (def cursor (entries state lo lower-inclusive?))
        (iterator-map identity (in-coroutine (lambda (yield)
          (let/cc stop
            (for (entry cursor)
              (when hi
                (let (sign (.call comparer .compare (car entry) (some-value hi)))
                  (unless (if upper-inclusive? (<= sign 0) (< sign 0)) (stop (void)))))
              (yield entry)))))
          (lambda (action) (observe state action)))))))
  ;; Materialization is now an ordinary consumer of the same bounded cursor.
  (def (range state lower upper (lower-inclusive? #t) (upper-inclusive? #t))
    (observe state (lambda ()
      (for/collect (entry (range-cursor state lower upper lower-inclusive? upper-inclusive?)) entry))))
  ;; Seek observes only the first admitted binding at/after the optional lower bound.
  (def (seek state lower (inclusive? #t))
    (observe state (lambda ()
      (let-values (((lo _hi) (bounds lower #f inclusive? #t)))
        (using ((cursor (entries state lo inclusive?) :- Iterator))
          (def entry (cursor.next!))
          (if (eq? entry #!eof) #f (some entry)))))))
  (set! result (.cc methods.table Key: (.@ source Key) Value: (.@ source Value)
    .empty: (.@ source .empty) .sources: sources Comparer: comparer
    ;; Ordering changes traversal, not lookup equality. Reuse the source key space
    ;; and constructor while protecting comparator/declaration callbacks throughout.
    .key-table: (lambda (value) (protect (lambda () (table-key-table source value))))
    .<-list: (lambda (bindings) (protect (lambda () (.call source .<-list bindings))))
    ;; Rebind derived methods to this descriptor, not a cached source receiver.
    ;; Point operations keep the original backend and the same metadata discipline.
    .validate-shape: (lambda (state) (observe state (lambda () state)))
    .empty?: (lambda (state) (observe state (lambda () (.call source .empty? state))))
    .ref: (lambda (state key (missing (lambda () (error "missing key"))))
      (observe state (lambda () (.call source .ref state key missing))))
    .acons: (lambda (key row state) (update state key (lambda () (.call source .acons key row state))))
    .remove: (lambda (state key) (update state key (lambda () (.call source .remove state key))))
    ;; Keep the source's atomic installer across an order view: rebuilding a
    ;; delta with point writes could reject transient unique-index conflicts.
    .apply-delta: (lambda (state delta)
      (unless (table-delta? delta) (error "table delta required"))
      (with-table-sources (table-delta-sources delta) (lambda () (protect (lambda ()
        (require-table-delta result delta)
        (admit-source state)
        (admit-source (.call source .apply-delta state delta)))))))
    ;; Unbounded iteration is the same positioned cursor without a lower bound;
    ;; retain declared seek and every-pull guards instead of materializing a fold.
    .iter<-: (lambda (state) (position state #f #t))
    .range: range .range<-: range-cursor .seek: seek .seek<-: position
    .foldl: (lambda (f seed state) (observe state (lambda ()
      (for/fold (acc seed) (entry (entries state #f #t)) (f (car entry) (cdr entry) acc)))))
    .foldr: (lambda (f seed state) (observe state (lambda ()
      (foldr (lambda (entry acc) (f (car entry) (cdr entry) acc)) seed
        (if seek? (.call source .list<- state) (bindings state))))))))
  result)

;; Decompose under an explicit lawful order, retaining admitted leaves and indexes.
;; Reuse checked optional mapping on the original root for each side, never an
;; intermediate remainder that might violate a custom refinement. This reference
;; path costs two traversals plus full admission; it claims no logarithmic split.
(def (split-table descriptor pivot input)
  (unless (.has? descriptor Comparer) (error "unordered table split"))
  (def comparer (.@ descriptor Comparer))
  (unless (eq? (.@ descriptor Key) (.@ comparer Key)) (error "incompatible table order key"))
  (with-table-sources (append (table-sources descriptor) (list comparer) (.@ comparer .sources))
    (lambda ()
      (require-table descriptor input)
      (require-table-key descriptor pivot)
      (def middle (require-table-option (.@ descriptor Value)
        (map/option identity (.call descriptor .ref/opt input pivot))))
      ;; Classify with the declared comparer, not the host order of encoded keys.
      (def (side keep?)
        (.call descriptor .filter-map/2 (lambda (key value)
          (and (keep? (.call comparer .compare key pivot)) (some value))) input))
      (def left (side negative?))
      (def right (side positive?))
      (require-table descriptor left)
      (require-table descriptor right)
      (values left middle right))))
