;;; Explicit typed order, transported through the existing key Wrapper protocol.

;; Weak seals contain only the constructor revision and numeric dependency stamps.
;; They retain no descriptors; copied protocols cannot borrow another seal.
(def %table-comparer-versions (make-table test: eq? weak-keys: #t))

;; The capability identity check is valid only for the constructor's unchanged fields.
(def (table-comparer-current? comparer)
  (def seal (table-ref %table-comparer-versions comparer #f))
  (and seal (= (car seal) (object-revision comparer))
    (equal? (cdr seal) (map object-revision (.@ comparer .sources)))))

;; Admit known constructor seals before discovery/callbacks, even for empty reads.
;; Unsealed custom comparers retain reference sorting under their declared laws;
;; the separate capability predicate never grants them a backend fast path.
(def (with-table-comparer comparer extra action)
  (with-table-sources (cons comparer extra) (lambda ()
    ;; Metadata edits revoke capability evidence, but may leave a deliberately
    ;; reused comparison closure valid. Such protocols use reference fallback.
    (def registered (table-ref %table-comparer-versions comparer #f))
    (def seal (and registered (= (car registered) (object-revision comparer)) registered))
    (def sources (.@ comparer .sources))
    (using (sources :~ list?)
      (with-table-sources sources (lambda ()
        (when (and seal (not (table-comparer-current? comparer)))
          (error "stale table comparer"))
        (action)))))))

;; Bind a three-way comparer to its key Type and current source revisions.
;; Totality, transitivity and purity are caller laws; encountered zero/equality
;; disagreement and non-sign results refuse rather than silently merging keys.
(def (table-comparer key compare (dependencies []) equal?: (same? equal?))
  (using ((compare :~ procedure?) (same? :~ procedure?) (dependencies :~ list?))
    ;; Retain dependency identities, not the caller-owned declaration cells.
    (def sources (cons key (map identity dependencies)))
    (def versions (map object-revision sources))
    (def result (.cc Type. Key: key .sources: sources .procedure: compare .equality: same?
      .compare: (lambda (left right)
        ;; The primitive's captured sources remain authoritative even if public
        ;; labels change; capability seals separately govern backend positioning.
        (with-table-sources sources (lambda ()
          (unless (equal? versions (map object-revision sources)) (error "stale table comparer"))
          (unless (element? key left) (raise-type-error key left 'table-comparer))
          (unless (element? key right) (raise-type-error key right 'table-comparer))
          (def sign (compare left right))
          ;; An invalid sign refuses before a caller equality predicate runs.
          (unless (memv sign '(-1 0 1)) (error "invalid table comparison" left right sign))
          (let (same (same? left right))
            (using (same :~ boolean?)
              (unless (eq? (= sign 0) same)
                (error "invalid table comparison" left right sign)) sign)))))))
    (table-set! %table-comparer-versions result (cons (object-revision result) versions))
    result))

;; Pull order back through an explicit key isomorphism. Negated numeric keys thus
;; retain source order, not their incidental host numeric order. Check encountered
;; inverse laws using the existing translation failure and typed admission logic.
(def (table-comparer-wrapper comparer key)
  (with-table-comparer comparer (list key) (lambda ()
    (def domain (.@ key Domain))
    (unless (eq? (.@ comparer Key) domain) (error "incompatible comparer domain"))
    (def codomain (.@ key Codomain))
    ;; Discover endpoints before callback getters, as in table isomorphism binding.
    (with-table-sources (list domain codomain) (lambda ()
      (def ap (.@ key .ap)) (def unap (.@ key .unap))
      ;; Translate only compared keys; no table scan or Function wrapping is needed.
      (def (decode value)
        (translate-table-value codomain domain unap ap value))
      (table-comparer codomain
        (lambda (left right) (.call comparer .compare (decode left) (decode right)))
        (append (list comparer key domain) (.@ comparer .sources))
        equal?: (lambda (left right) ((.@ comparer .equality) (decode left) (decode right)))))))))

;; Expose an explicitly ordered backend's existing Iterator without sorting or
;; copying a tree. Positioning filters the prefix in linear time; no height-bound
;; seek is inferred. Capture bounds and admit the complete persistent snapshot
;; once; every pull, including EOF, checks origins and every emitted row is typed.
(def (table-ordered-cursor descriptor input lower inclusive? producer compare same?)
  (using ((inclusive? :~ boolean?) (producer :~ procedure?)
          (compare :~ procedure?) (same? :~ procedure?))
    (def bound (map/option identity lower))
    (def comparer (.@ descriptor Comparer))
    (with-table-comparer comparer (list descriptor) (lambda ()
      (def sources (append (table-sources descriptor) (list comparer) (.@ comparer .sources)))
      (def versions (map object-revision sources))
      ;; Use the same source scope at construction and across each deferred pull.
      (def (guard action)
        (with-table-sources sources (lambda ()
          (unless (and (equal? versions (map object-revision sources))
                       (table-comparer-current? comparer)
                       (eq? (.@ comparer Key) (.@ descriptor Key)))
            (error "stale ordered table cursor"))
          ;; Replacing a backend's advertised comparer cannot change its producer.
          ;; Check the actual producer's declared comparison/equality pair here.
          (unless (and (eq? (.@ comparer .procedure) compare)
                       (eq? (.@ comparer .equality) same?))
            (error "incompatible ordered table cursor"))
          (action))))
      (guard (lambda ()
        (require-table descriptor input)
        (require-table-option (.@ descriptor Key) bound)
        (def binding (Pair (.@ descriptor Key) (.@ descriptor Value)))
        (iterator-map (lambda (entry)
          (some-value (require-table-entry binding (some entry)))) (in-coroutine (lambda (yield)
          (for (entry (producer input))
            (when (or (not bound)
              (let (sign (.call comparer .compare (car entry) (some-value bound)))
                (if inclusive? (>= sign 0) (> sign 0))))
              (yield entry))))) guard)))))))

 ;; Compare admitted cursor rows without constructing a merge result. Pair shells
;; are copied before any other pull/callback; value leaves keep their identity.
(def (compare-table-cursors descriptor comparer compare left right)
  (def binding (Pair (.@ descriptor Key) (.@ descriptor Value)))
  ;; Standard Iterator owns EOF and producer effects, including original failures.
  (def (pull cursor)
    (using (cursor :- Iterator)
      (let (row (cursor.next!))
        (if (eq? row #!eof) row (some-value (require-table-entry binding (some row)))))))
  (let* ((a (.call descriptor .iter<- left)) (b (.call descriptor .iter<- right))
         (x (pull a)) (y (pull b)))
    (let loop ((x x) (y y))
      (cond
        ((eq? x #!eof) (if (eq? y #!eof) 0 -1))
        ((eq? y #!eof) 1)
        (else
          (let (key-sign (.call comparer .compare (car x) (car y)))
            (cond
              ((negative? key-sign) 1)
              ((positive? key-sign) -1)
              (else (let (sign (compare (cdr x) (cdr y)))
                (if (zero? sign)
                  (let* ((x (pull a)) (y (pull b))) (loop x y)) sign))))))))))

;; Union-key order places absence before presence. Both complete roots precede
;; shortcuts; only explicitly ordered descriptors may compare. Structural backend
;; capabilities retain their algorithm under the same declared ordering law.
(def (compare-table-bindings descriptor compare left right)
  (with-table-sources (table-sources descriptor) (lambda ()
    (require-table descriptor left)
    (require-table descriptor right)
    (using (compare :~ procedure?)
      (unless (.has? descriptor Comparer) (error "unsupported table comparison"))
      (let (comparer (.@ descriptor Comparer))
        (with-table-comparer comparer [] (lambda ()
          (unless (eq? (.@ comparer Key) (.@ descriptor Key)) (error "incompatible comparer domain"))
          ;; Unlike key equality, value comparison may equate distinct payloads.
          ;; Its exact Integer result and original callback exceptions are retained.
          (def (checked a b)
            (let (sign (compare a b)) (using (sign :~ exact-integer?) sign)))
          ;; Reference comparison needs a lawful declared order, not positioning
          ;; evidence. Only a current constructor may select the backend shortcut.
          (if (and (table-comparer-current? comparer) (.has? descriptor .compare/key))
            (.call descriptor .compare/key checked left right)
            (compare-table-cursors descriptor comparer checked left right)))))))))

;; Reuse the original persistent carrier, point operations and positioned traversal.
;; Gerbil list-sort supplies only the fallback; no balancing algorithm is copied.
;; Inclusive/exclusive bounds use Option, so false remains a possible key.
(def (table-order source comparer)
  (with-table-comparer comparer (list source) (lambda ()
    (unless (eq? (.@ source Key) (.@ comparer Key)) (error "incompatible table order key"))
    (def sources (append (table-sources source) (list comparer) (.@ comparer .sources)))
    ;; Identity is a conservative capability check, never function equivalence inference.
    (def seek? (and (.has? source Comparer .seek<-)
      (table-comparer-current? (.@ source Comparer)) (table-comparer-current? comparer)
      (eq? (.@ (.@ source Comparer) Key) (.@ source Key))
      (eq? (.@ (.@ source Comparer) .procedure) (.@ comparer .procedure))
      (eq? (.@ (.@ source Comparer) .equality) (.@ comparer .equality))))
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
      ;; Capture request cells before source admission can invoke caller code.
      (set! lower (map/option identity lower))
      (observe state (lambda ()
        (let-values (((lo _hi) (bounds lower #f inclusive? #t)))
          (iterator-map identity (entries state lo inclusive?)
            (lambda (action) (observe state action)))))))
    ;; Standard coroutine iteration supplies sticky EOF and demand-driven traversal.
    ;; The outer Iterator guard covers every pull, including repeated EOF, without
    ;; retaining metadata protection across a yield or copying admitted payloads.
    (def (range-cursor state lower upper (lower-inclusive? #t) (upper-inclusive? #t))
      ;; Capture request cells before source admission can invoke caller code.
      (set! lower (map/option identity lower))
      (set! upper (map/option identity upper))
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
      ;; Capture request cells before source admission can invoke caller code.
      (set! lower (map/option identity lower))
      (set! upper (map/option identity upper))
      (observe state (lambda ()
        (for/collect (entry (range-cursor state lower upper lower-inclusive? upper-inclusive?)) entry))))
    ;; Seek observes only the first admitted binding at/after the optional lower bound.
    (def (seek state lower (inclusive? #t))
      ;; Capture request cells before source admission can invoke caller code.
      (set! lower (map/option identity lower))
      (observe state (lambda ()
        (let-values (((lo _hi) (bounds lower #f inclusive? #t)))
          (using ((cursor (entries state lo inclusive?) :- Iterator))
            (def entry (cursor.next!))
            (if (eq? entry #!eof) #f (some entry)))))))
    (set! result (.o (:: @ methods.table) Key: (.@ source Key) Value: (.@ source Value)
      ;; Declaration does not materialize a root; explicit construction still admits
      ;; the complete source under the same revision and mutation guards.
      (.empty (protect (lambda () (require-table source (.@ source .empty)))))
      .sources: sources Comparer: comparer
      ;; Order changes traversal only: normalize through the identical source
      ;; Key/Value Types, without constructing or admitting intermediate roots.
      (.validate (table-view-validator @ source (cut validate source <>)))
      ;; Ordering changes traversal, not lookup equality. Reuse the source key space
      ;; and constructor while protecting comparator/declaration callbacks throughout.
      .key-table: (lambda (value) (protect (lambda () (table-key-table source value))))
      .<-list/key: (lambda (bindings) (protect (lambda () (.call source .<-list bindings))))
      ;; Rebind derived methods to this descriptor, not a cached source receiver.
      ;; Point operations keep the original backend and the same metadata discipline.
      .validate-shape: (lambda (state) (observe state (lambda () state)))
      .empty/key?: (lambda (state) (observe state (lambda () (table-empty-key? source state))))
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
    result)))

;; Decompose under an explicit lawful order, retaining admitted leaves and indexes.
;; Reuse checked optional mapping on the original root for each side, never an
;; intermediate remainder that might violate a custom refinement. This reference
;; path costs two traversals plus full admission; it claims no logarithmic split.
(def (split-table descriptor pivot input)
  (with-table-sources (list descriptor) (lambda ()
    (unless (.has? descriptor Comparer) (error "unordered table split"))
    (def comparer (.@ descriptor Comparer))
    (with-table-comparer comparer [] (lambda ()
      (with-table-sources (table-sources descriptor) (lambda ()
      (unless (eq? (.@ descriptor Key) (.@ comparer Key)) (error "incompatible table order key"))
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
      (values left middle right))))))))
