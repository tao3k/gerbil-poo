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
  (def (observe state action)
    (with-table-sources (if result (cons result sources) sources) (lambda ()
      (unless (equal? versions (map object-revision sources)) (error "stale table order"))
      (admit-source state)
      (action))))
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
        (unless (or (not bound) (some? bound)) (error "table range bound must be Option"))
        (when (some? bound)
          (unless (element? (.@ source Key) (some-value bound))
            (raise-type-error (.@ source Key) (some-value bound) 'table-order)))) (list lower upper))
      (when (and (some? lower) (some? upper)
        (> (.call comparer .compare (some-value lower) (some-value upper)) 0))
        (error "reversed table range"))))
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
      (bounds lower #f inclusive? #t)
      (iterator-map identity (entries state lower inclusive?)
        (lambda (action) (observe state action))))))
  ;; A fresh positioned iterator stops on the first upper-bound failure. The
  ;; enclosing guard covers positioning, every pull and bound comparison.
  (def (range state lower upper (lower-inclusive? #t) (upper-inclusive? #t))
    (observe state (lambda ()
      (bounds lower upper lower-inclusive? upper-inclusive?)
      (with-list-builder (emit)
        (let/cc stop
          (for (entry (entries state lower lower-inclusive?))
            (when upper
              (let (sign (.call comparer .compare (car entry) (some-value upper)))
                (unless (if upper-inclusive? (<= sign 0) (< sign 0)) (stop (void)))))
            (emit entry)))))))
  ;; Seek observes only the first admitted binding at/after the optional lower bound.
  (def (seek state lower (inclusive? #t))
    (observe state (lambda ()
      (bounds lower #f inclusive? #t)
      (using ((cursor (entries state lower inclusive?) :- Iterator))
        (def entry (cursor.next!))
        (if (eq? entry #!eof) #f (some entry))))))
  (set! result (.cc methods.table Key: (.@ source Key) Value: (.@ source Value)
    .empty: (.@ source .empty) .sources: sources Comparer: comparer
    ;; Rebind derived methods to this descriptor, not a cached source receiver.
    ;; Point operations keep the original backend and the same metadata discipline.
    .validate-shape: (lambda (state) (observe state (lambda () state)))
    .empty?: (lambda (state) (observe state (lambda () (.call source .empty? state))))
    .ref: (lambda (state key (missing (lambda () (error "missing key"))))
      (observe state (lambda () (.call source .ref state key missing))))
    .acons: (lambda (key row state) (update state key (lambda () (.call source .acons key row state))))
    .remove: (lambda (state key) (update state key (lambda () (.call source .remove state key))))
    .range: range .seek: seek .seek<-: position
    .foldl: (lambda (f seed state) (observe state (lambda ()
      (for/fold (acc seed) (entry (entries state #f #t)) (f (car entry) (cdr entry) acc)))))
    .foldr: (lambda (f seed state) (observe state (lambda ()
      (foldr (lambda (entry acc) (f (car entry) (cdr entry) acc)) seed
        (if seek? (.call source .list<- state) (bindings state))))))))
  result)
