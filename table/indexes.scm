;;; Declarative correlated indexes over the existing persistent table protocol.

;; The first duplicate retains the declaration and both competing primary owners.
(defstruct table-index-conflict (name key existing incoming) final: #t)
;; Prepared immutable recipes retain the declared backend and pure projection.
(defstruct %table-index (name table project unique?) final: #t)
;; One private snapshot carries the primary root, every index and all live origins.
(defstruct %indexed-table (owner primary indexes sources versions) final: #t)

;; Own the finite classifier spine before child recognition can alter its caller's
;; buffer. Index installation and grouped aggregation share membership admission
;; and stable deduplication; admitted keys are never normalized again.
(def (require-table-index-keys type keys (where 'table-indexes))
  (using (keys :~ list?)
    (def captured (map identity keys))
    (for-each (lambda (key)
      (unless (element? type key) (raise-type-error type key where))) captured)
    (if (and (pair? captured) (pair? (cdr captured)))
      (delete-duplicates/hash captured from-end?: #t) captured)))

;; Derive a complete table with atomic correlated indexes. A unique index stores
;; primary keys; a grouped index stores persistent source-table buckets. No hash
;; engine, balancing algorithm, Function normalization or ownership API is copied.
(def (table-indexes source declarations)
  (using (declarations :~ list?)
    ;; Own the finite request spine before getters can change the caller's buffer.
    ;; First protect declarations/source, then discovered backends, then all their
    ;; child/origin Types. Recipes are read only inside this complete protection.
    (def captured (map identity declarations))
    (with-table-sources (cons source captured) (lambda ()
      (def tables (map (lambda (declaration) (.@ declaration table)) captured))
      (with-table-sources tables (lambda ()
        (def sources (delete-duplicates/hash
          (append (table-sources source) captured (append-map table-sources tables))
          table: (make-hash-table-eq) from-end?: #t))
        (with-table-sources sources
          (lambda () (make-table-indexes source captured tables sources)))))))))

;; Compile and publish one family while every captured participant is protected.
;; Later operations retain the existing source stamp and first-failure protocol.
(def (make-table-indexes source declarations tables sources)
  (def recipes (map (lambda (declaration table)
    (def name (.@ declaration name))
    (def project (.@ declaration project)) (def unique? (.@ declaration unique?))
    (def multiple? (and (.has? declaration multiple?) (.@ declaration multiple?)))
    (using ((name :~ symbol?) (project :~ procedure?) (unique? :~ boolean?) (multiple? :~ boolean?))
      (unless (eq? (.@ table Value) (if unique? (.@ source Key) source))
        (error "incompatible table index value type" name))
      ;; Prepare one finite-key projection for both declaration cardinalities.
      ;; A list-valued single key stays one key unless multiple? is explicit.
      (make-%table-index name table
        (if multiple? project (lambda (key row) (list (project key row)))) unique?))) declarations tables))
  (def names (map %table-index-name recipes))
  (unless (= (length names) (length (delete-duplicates/hash names table: (make-hash-table-eq))))
    (error "duplicate table index name"))
  (def versions (map object-revision sources))
  (def owner (list source declarations)) (def result #f)
  ;; Capture metadata over the complete operation. Descriptor mutations must be
  ;; serialized with other threads, exactly as in the existing table style API.
  (def (guard dependencies action)
    (with-table-sources (append (if result (list result) []) dependencies) (lambda ()
      (unless (equal? versions (map object-revision sources)) (error "stale table indexes"))
      (action))))
  ;; Private ownership prevents another recipe family from supplying unchecked caches.
  (def (check state)
    (unless (and (%indexed-table? state) (eq? (%indexed-table-owner state) owner))
      (error "incompatible indexed table"))
    (unless (equal? (%indexed-table-versions state) (map object-revision (%indexed-table-sources state)))
      (error "stale indexed table")))
  ;; Query and modification callbacks see one admitted complete snapshot.
  (def (observe state action)
    (check state)
    (guard (%indexed-table-sources state) (lambda () (check state) (action state))))
  ;; Resolve a declared name once under the same private-state admission as every
  ;; indexed observation. Keep backend roots private and share the lookup boundary.
  (def (with-index state name receive)
    (observe state (lambda (_)
      (def recipe (find (lambda (recipe) (eq? name (%table-index-name recipe))) recipes))
      (unless recipe (error "unknown table index" name))
      (receive (%table-index-table recipe) (cdr (assq name (%indexed-table-indexes state)))))))
  ;; Backend Iterator owns traversal and bounds. The family guard is still needed
  ;; on each deferred pull: primary, sibling declaration and origin changes can
  ;; invalidate an otherwise unchanged selected backend, even after its EOF.
  (def (index-cursor state name method args)
    (with-index state name (lambda (table root)
      (unless (.slot? table method) (error "unsupported table index cursor" name method))
      (iterator-map identity (apply (.ref table method) root args)
        (lambda (action) (observe state (lambda (_) (action))))))))
  ;; Validate the complete finite key list before any cache update. Standard
  ;; stable deduplication preserves first-conflict order and callback identities.
  ;; Empty lists mean no membership; list-valued keys remain unambiguous.
  (def (project recipe key row)
    (require-table-index-keys (.@ (%table-index-table recipe) Key)
      ((%table-index-project recipe) key row)))
  ;; Insert one membership using the existing unique-owner or grouped backend.
  ;; A grouped bucket shares the exact admitted row, including its Functions.
  (def (insert-key recipe cache key row projected)
    (def table (%table-index-table recipe))
    (def existing (.call table .ref/opt cache projected))
    (if (%table-index-unique? recipe)
      (begin
        (when (and (some? existing) (not (equal? key (some-value existing))))
          (raise (make-table-index-conflict (%table-index-name recipe) projected (some-value existing) key)))
        (.call table .acons projected key cache))
      (.call table .acons projected
        (.call source .acons key row (option-get/default existing (lambda () (.@ source .empty)))) cache)))
  ;; Retract one membership. Empty buckets disappear, preserving absence.
  (def (retract-key recipe cache key row projected)
    (def table (%table-index-table recipe))
    (def existing (.call table .ref/opt cache projected))
    (if (not (some? existing)) cache
      (if (%table-index-unique? recipe) (.call table .remove cache projected)
        (let (bucket (if (.call source .key? (some-value existing) key)
                      (.call source .remove (some-value existing) key) (some-value existing)))
          (if (.call source .empty? bucket) (.call table .remove cache projected)
            (.call table .acons projected bucket cache))))))
  ;; Fold all memberships through the same persistent insertion protocol.
  (def (insert recipe cache key row)
    (foldl (lambda (projected cache) (insert-key recipe cache key row projected))
      cache (project recipe key row)))
  ;; Remove all old memberships before any final-row insertion or unique check.
  (def (retract recipe cache key row)
    (foldl (lambda (projected cache) (retract-key recipe cache key row projected))
      cache (project recipe key row)))
  ;; Recognize the complete declared cache without normalizing its keys or
  ;; values. Grouped Value=source also checks each final bucket's root refinement.
  ;; Keep this boundary after one recipe finishes and before the next is prepared.
  (def (checked-entry recipe cache)
    (cons (%table-index-name recipe) (require-table (%table-index-table recipe) cache)))
  ;; Allocate only after every declared cache has completed; failed callbacks
  ;; expose neither an updated primary nor a partially prepared index list.
  (def (snapshot primary indexes origins)
    (make-%indexed-table owner primary indexes origins (map object-revision origins)))
  ;; Cold construction scans the admitted primary once per declaration.
  (def (initialize primary)
    (guard sources (lambda ()
      (require-table source primary)
      (snapshot primary (for/collect ((recipe recipes))
        (checked-entry recipe (.call source .foldl
          (lambda (key row cache) (insert recipe cache key row))
          (.@ (%table-index-table recipe) .empty) primary))) (if result (cons result sources) sources)))))
  ;; All primary expectations are checked before index projection. Warm updates
  ;; visit only edit keys: retract all old bindings, then insert final bindings.
  (def (update state delta (admit identity))
    (unless (procedure? admit) (error "index admission procedure required"))
    (unless (table-delta? delta) (error "table delta required"))
    (observe state (lambda (_)
      (def origins (delete-duplicates/hash (append (%indexed-table-sources state) (table-delta-sources delta))
        table: (make-hash-table-eq) from-end?: #t))
      (guard origins (lambda ()
        (def before (%indexed-table-primary state))
        (def after (.call source .apply-delta before delta))
        ;; The source delta primitive admits shape, not custom root refinements.
        ;; Recognize its complete final primary before preparing any index cache.
        (require-table source after)
        ;; An enclosing collection can require its complete final refinement here,
        ;; before projection, without applying the same primary delta twice.
        (admit after)
        (def keys (map table-change-key (table-delta-changes delta)))
        (def indexes (for/collect ((recipe recipes) (entry (%indexed-table-indexes state)))
          (def stripped (foldl (lambda (key cache)
            (def old (.call source .ref/opt before key))
            (if (some? old) (retract recipe cache key (some-value old)) cache)) (cdr entry) keys))
          (checked-entry recipe (foldl (lambda (key cache)
            (def new (.call source .ref/opt after key))
            (if (some? new) (insert recipe cache key (some-value new)) cache)) stripped keys))))
        (snapshot after indexes origins))))))
  ;; Capture one optional point edit without a trial carrier/full difference scan.
  ;; The original installer still owns primary conflicts and atomic index updates.
  (def (edit state key transform)
    (observe state (lambda (_)
      (update state (.call source .delta/opt key transform (%indexed-table-primary state))))))
  ;; Capture this immutable primary once and delegate its standard cursor.
  ;; The old snapshot remains readable after another owner publishes; origin
  ;; invalidation refuses before each source pull, including repeated EOF.
  (def (cursor state)
    (observe state (lambda (_)
      (iterator-map identity (.call source .iter<- (%indexed-table-primary state))
        (lambda (action) (observe state (lambda (_) (action))))))))
  ;; Existing Wrap supplies IO and FUN operations. Guard complete callbacks and
  ;; rebuild only for an explicit representation-wide .map/wrap transformation.
  (def wrapper (.cc Wrapper. .ap: initialize .unap: (lambda (state)
    (observe state %indexed-table-primary))))
  (set! result
    (.cc (.mix methods.table (.cc Wrap. T: source Wrapper: wrapper .wrap?: %indexed-table?))
      Key: (.@ source Key) Value: (.@ source Value) .sources: sources
      ;; Private key-space registries retain the source's equality, not indexes
      ;; whose projection and cache Types belong to this family's original rows.
      .key-table: (lambda (value) (guard sources (lambda () (table-key-table source value))))
      ;; One complete primary construction precedes one complete cache family.
      .<-list: (lambda (bindings) (guard sources
        (lambda () (initialize (.call source .<-list bindings)))))
      .empty: (initialize (.@ source .empty))
      ;; Private snapshot identity is not a test for logical collection emptiness.
      .empty?: (lambda (state) (observe state (lambda (_) (.call source .empty? (%indexed-table-primary state)))))
      .validate-shape: (lambda (state) (observe state (lambda (_) state)))
      .ref: (lambda (state key (missing (lambda () (error "missing key"))))
        (observe state (lambda (_) (.call source .ref (%indexed-table-primary state) key missing))))
      .acons: (lambda (key row state) (edit state key (lambda (_) (some row))))
      .remove: (lambda (state key) (edit state key (lambda (_) #f)))
      .foldl: (lambda (f seed state) (observe state (lambda (_) (.call source .foldl f seed (%indexed-table-primary state)))))
      .foldr: (lambda (f seed state) (observe state (lambda (_) (.call source .foldr f seed (%indexed-table-primary state)))))
      .iter<-: cursor
      .apply-delta: update
      .index-ref/opt: (lambda (state name key)
        (with-index state name (lambda (table root)
          (unless (element? (.@ table Key) key) (raise-type-error (.@ table Key) key 'table-indexes))
          (.call table .ref/opt root key))))
      ;; Observe one complete named index through its declared fold, retaining
      ;; guards and bucket identity without exposing a mutable cache handle.
      .index-fold: (lambda (state name f seed)
        (using (f :~ procedure?)
          (with-index state name (lambda (table root) (.call table .foldl f seed root)))))
      ;; Standard observation aliases add no cache, sorting or element wrapping.
      .index-iter<-: (lambda (state name) (index-cursor state name '.iter<- []))
      .index-seek<-: (lambda (state name lower (inclusive? #t))
        (index-cursor state name '.seek<- (list lower inclusive?)))
      .index-range<-: (lambda (state name lower upper (lower-inclusive? #t) (upper-inclusive? #t))
        (index-cursor state name '.range<- (list lower upper lower-inclusive? upper-inclusive?)))
      ;; Ordered backends own comparator and bound semantics; never infer order
      ;; from projection values or expose the private cache root to callers.
      .index-range: (lambda (state name lower upper (lower-inclusive? #t) (upper-inclusive? #t))
        (with-index state name (lambda (table root)
          (unless (.has? table .range) (error "unordered table index" name))
          (.call table .range root lower upper lower-inclusive? upper-inclusive?))))
      .bind/wrap: (lambda (state f) (observe state (lambda (_) (.call wrapper .bind state f))))
      .map/wrap: (lambda (f state) (observe state (lambda (_) (.call wrapper .map f state))))))
  result)
