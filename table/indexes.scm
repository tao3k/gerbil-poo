;;; Declarative correlated indexes over the existing persistent table protocol.

;; The first duplicate retains the declaration and both competing primary owners.
(defstruct table-index-conflict (name key existing incoming) final: #t)
;; Prepared immutable recipes retain the declared backend and pure projection.
(defstruct %table-index (name table project unique?) final: #t)
;; One private snapshot carries the primary root, every index and all live origins.
(defstruct %indexed-table (owner primary indexes sources versions) final: #t)

;; Derive a complete table with atomic correlated indexes. A unique index stores
;; primary keys; a grouped index stores persistent source-table buckets. No hash
;; engine, balancing algorithm, Function normalization or ownership API is copied.
(def (table-indexes source declarations)
  (using (declarations :~ list?)
    (def recipes (map (lambda (declaration)
      (def name (.@ declaration name)) (def table (.@ declaration table))
      (def project (.@ declaration project)) (def unique? (.@ declaration unique?))
      (def multiple? (and (.has? declaration multiple?) (.@ declaration multiple?)))
      (using ((name :~ symbol?) (project :~ procedure?) (unique? :~ boolean?) (multiple? :~ boolean?))
        (unless (eq? (.@ table Value) (if unique? (.@ source Key) source))
          (error "incompatible table index value type" name))
        ;; Prepare one finite-key projection for both declaration cardinalities.
        ;; A list-valued single key stays one key unless multiple? is explicit.
        (make-%table-index name table
          (if multiple? project (lambda (key row) (list (project key row)))) unique?))) declarations))
    (def names (map %table-index-name recipes))
    (unless (= (length names) (length (delete-duplicates/hash names table: (make-hash-table-eq))))
      (error "duplicate table index name"))
    (def sources (delete-duplicates/hash
      (append (table-sources source) declarations
        (append-map (lambda (recipe) (table-sources (%table-index-table recipe))) recipes))
      table: (make-hash-table-eq) from-end?: #t))
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
    ;; Validate the complete finite key list before any cache update. Standard
    ;; stable deduplication preserves first-conflict order and callback identities.
    ;; Empty lists mean no membership; list-valued keys remain unambiguous.
    (def (project recipe key row)
      (def keys ((%table-index-project recipe) key row))
      (def type (.@ (%table-index-table recipe) Key))
      (using (keys :~ list?)
        (for-each (lambda (value)
          (unless (element? type value) (raise-type-error type value 'table-indexes))) keys)
        ;; Empty/single-key lists are already unique; keep their path hash-free.
        (if (and (pair? keys) (pair? (cdr keys)))
          (delete-duplicates/hash keys from-end?: #t) keys)))
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
    ;; Allocate only after every declared cache has completed; failed callbacks
    ;; expose neither an updated primary nor a partially prepared index list.
    (def (snapshot primary indexes origins)
      (make-%indexed-table owner primary indexes origins (map object-revision origins)))
    ;; Cold construction scans the admitted primary once per declaration.
    (def (initialize primary)
      (guard sources (lambda ()
        (require-table source primary)
        (snapshot primary (map (lambda (recipe)
          (cons (%table-index-name recipe) (.call source .foldl
            (lambda (key row cache) (insert recipe cache key row))
            (.@ (%table-index-table recipe) .empty) primary))) recipes) (if result (cons result sources) sources)))))
    ;; All primary expectations are checked before index projection. Warm updates
    ;; visit only edit keys: retract all old bindings, then insert final bindings.
    (def (update state delta)
      (unless (table-delta? delta) (error "table delta required"))
      (observe state (lambda (_)
        (def origins (delete-duplicates/hash (append (%indexed-table-sources state) (table-delta-sources delta))
          table: (make-hash-table-eq) from-end?: #t))
        (guard origins (lambda ()
          (def before (%indexed-table-primary state))
          (def after (.call source .apply-delta before delta))
          (def keys (map table-change-key (table-delta-changes delta)))
          (def indexes (map (lambda (recipe entry)
            (def stripped (foldl (lambda (key cache)
              (def old (.call source .ref/opt before key))
              (if (some? old) (retract recipe cache key (some-value old)) cache)) (cdr entry) keys))
            (cons (car entry) (foldl (lambda (key cache)
              (def new (.call source .ref/opt after key))
              (if (some? new) (insert recipe cache key (some-value new)) cache)) stripped keys)))
            recipes (%indexed-table-indexes state)))
          (snapshot after indexes origins))))))
    ;; Single writes reuse discovery/installation rather than a second index mutator.
    (def (edit state transform)
      (observe state (lambda (_)
        (def before (%indexed-table-primary state))
        (update state (.call source .diff before (transform before))))))
    ;; Existing Wrap supplies IO and FUN operations. Guard complete callbacks and
    ;; rebuild only for an explicit representation-wide .map/wrap transformation.
    (def wrapper (.cc Wrapper. .ap: initialize .unap: (lambda (state)
      (observe state %indexed-table-primary))))
    (set! result
      (.cc (.mix methods.table (.cc Wrap. T: source Wrapper: wrapper .wrap?: %indexed-table?))
        Key: (.@ source Key) Value: (.@ source Value) .sources: sources
        .empty: (initialize (.@ source .empty))
        ;; Private snapshot identity is not a test for logical collection emptiness.
        .empty?: (lambda (state) (observe state (lambda (_) (.call source .empty? (%indexed-table-primary state)))))
        .validate-shape: (lambda (state) (observe state (lambda (_) state)))
        .ref: (lambda (state key (missing (lambda () (error "missing key"))))
          (observe state (lambda (_) (.call source .ref (%indexed-table-primary state) key missing))))
        .acons: (lambda (key row state) (edit state (cut .call source .acons key row <>)))
        .remove: (lambda (state key) (edit state (cut .call source .remove <> key)))
        .foldl: (lambda (f seed state) (observe state (lambda (_) (.call source .foldl f seed (%indexed-table-primary state)))))
        .foldr: (lambda (f seed state) (observe state (lambda (_) (.call source .foldr f seed (%indexed-table-primary state)))))
        .apply-delta: update
        .index-ref/opt: (lambda (state name key) (observe state (lambda (_)
          (def recipe (find (lambda (recipe) (eq? name (%table-index-name recipe))) recipes))
          (unless recipe (error "unknown table index" name))
          (def type (.@ (%table-index-table recipe) Key))
          (unless (element? type key) (raise-type-error type key 'table-indexes))
          (.call (%table-index-table recipe) .ref/opt (cdr (assq name (%indexed-table-indexes state))) key))))
        ;; Ordered backends own comparator and bound semantics; never infer order
        ;; from projection values or expose the private cache root to callers.
        .index-range: (lambda (state name lower upper (lower-inclusive? #t) (upper-inclusive? #t))
          (observe state (lambda (_)
            (def recipe (find (lambda (recipe) (eq? name (%table-index-name recipe))) recipes))
            (unless recipe (error "unknown table index" name))
            (def table (%table-index-table recipe))
            (unless (.has? table .range) (error "unordered table index" name))
            (.call table .range (cdr (assq name (%indexed-table-indexes state)))
              lower upper lower-inclusive? upper-inclusive?))))
        .bind/wrap: (lambda (state f) (observe state (lambda (_) (.call wrapper .bind state f))))
        .map/wrap: (lambda (f state) (observe state (lambda (_) (.call wrapper .map f state))))))
    result))
