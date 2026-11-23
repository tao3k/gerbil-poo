;; Select admitted bindings with the backend fold and insertion protocol. The
;; predicate runs once per visited binding, in fold order, and must return Bool.
;; Both branches remain private until complete recognition succeeds; Function
;; keys/values retain identity. Callback effects themselves cannot be rolled back.
;; TODO: have APIs look more like LIL, less like OCaml?
;; Especially since we may (1) use similar metaprogramming for OO style (?), and
;; (2) distinguish between for-each / foldl / foldr (iterating over pairs)
;; vs for-each* / foldl* / afoldr (iterating with two separate arguments for k v)
;; (3) explicit conversion is provided by Wrappers/styles; take/drop reuse selection below.
;; We could also reorder the arguments between object vs typeclass styles,
;; so the object is moved first in OO style, but at whatever "usual" place in the other style.

;; NB: General methods for maps, that are not trie-specific
(define-type (methods.table @ Type.
       .validate-shape ;; carrier-only admission, raises TypeError before enumeration
       Key ;; : Type
       Value ;; : Type
       .empty ;; : @
       .acons ;; : @ <- Key Value @
       .ref ;; : Value <- @ Key ?(Value <-)
       .remove ;; : @ <- @ Key
       .foldl ;; : (Fun o <- (Fun o <- Key Value o) o @)
       .foldr) ;; : (Fun o <- (Fun o <- Key Value o) o @)

  ;; Derived protocols publish their complete explicit origins to deltas and folds.
  .sources: []

  ;; This is an explicit backend capability. Closed families delegate it;
  ;; unknown/custom backends must declare its equality and payload laws.
  .key-table: #f

  ;; Recognition never normalizes children. This keeps nested List/Schema shape
  ;; checks and postconditions from constructing or discarding Function wrappers.
  ;; Typed refusal is false; unexpected user/backend exceptions remain observable.
  .element?: (lambda (source) (table-element? @ source))

  ;; Both Key and Value recursively normalize after complete carrier admission.
  ;; Persistent reconstruction retains every replacement and rejects key collisions.
  .validate: (lambda (source) (validate-table @ source))

  ;; Selection shares the same admitted binding traversal, without normalization.
  .filter: (lambda (predicate input) (car (select-table @ predicate input #f)))
  ;; Two-argument callbacks transform values at the original keys; FUN .map
  ;; remains a whole-root operation on style protocols.
  .map/2: (lambda (transform input) (map-table-bindings @ transform input #f))
  ;; Optional results can remove bindings, but cannot introduce or relabel keys.
  .filter-map/2: (lambda (transform input) (map-table-bindings @ transform input #t))
  ;; Explicit heterogeneous entry maps stage once and never overwrite collisions.
  .map/into: (lambda (target transform input) (map-table-into @ target transform input #f))
  .filter-map/into: (lambda (target transform input) (map-table-into @ target transform input #t))
  ;; Finite prefixes use the existing checked selection algorithm and backend order.
  .take: (lambda (count input) (select-table-prefix @ count input #t))
  .drop: (lambda (count input) (select-table-prefix @ count input #f))
  ;; Partition prepares and recognizes both branches before exposing either root.
  .partition: (lambda (predicate input)
    (def branches (select-table @ predicate input #t))
    (values (car branches) (cdr branches)))

  ;; Explicit order is required; both persistent sides are admitted before return.
  .split: (lambda (key input) (split-table @ key input))

  ;; : (Fun Bool <- @)
  ;; Logical observation never evaluates an unrelated empty constructor.
  .empty?: (cut empty-table? @ <>)

  ;; : (Fun Bool <- @ Key)
  .key?: (lambda (t key) (let/cc ret (.ref t key (lambda _ (ret #f))) #t))

  ;; : (Fun (Option Value) <- @ Key)
  .ref/opt: (lambda (t key) (let/cc ret (some (.ref t key (lambda _ (ret #f))))))

  ;; : Unit <- (Fun Unit <- Key Value) @
  .for-each: (lambda (f t) (.foldl (lambda (k v a) (void (f k v))) (void) t))

  ;; : Unit <- (Fun Unit <- Key Value) @
  .for-each/reverse: (lambda (f t) (.foldr (lambda (k v a) (void (f k v))) (void) t))

  ;; : @ <- Key (Option Value) @
  ;; Absence keeps the old binding but still checks the key, root and origins.
  .acons/opt: (lambda (k ov t) (.update/opt k (table-association-update @ ov) t))

  ;; : @ <- Key Value
  .singleton: (lambda (k v) (construct-table @ (list (cons k v)) #t))

  ;; Merge visits the union domain and validates private callback results before
  ;; one final-state installation; Trie retains its declared paired traversal.
  .merge: (lambda (choose left right) (merge-table-bindings @ choose left right))

  ;; Ordered callbacks let persistent backends skip shared subtrees while keeping
  ;; .diff admission, metadata protection and private delta construction centralized.
  .for-each-change: (lambda (emit before after) (table-for-each-change @ emit before after))

  ;; Finite differences and optimistic persistent installation share this backend.
  .diff: (lambda (before after) (diff-table @ before after))
  ;; Capture one .update/opt request for later batch, transport, fold or installation.
  ;; The callback runs once now; subsequent application never replays it.
  .delta/opt: (lambda (key transform before) (update-table-delta @ key transform before))
  .apply-delta: (lambda (source delta) (apply-table-delta @ source delta))
  ;; Ordered batches retain all origins and first-conflict semantics, including undo.
  .compose-deltas: (lambda (deltas) (compose-table-deltas @ deltas))

  ;; Optional focus is total at missing keys and uses the existing Lens protocol.
  ;; The setter receives value before state, as Lens.modify/compose require.
  .lens/opt: (lambda (key) (table-key-focus @ key #t))

  ;; : Nat <- @
  .count: (lambda (t) (.foldl (lambda (_1 _2 a) (1+ a)) 0 t))

  ;; : Bool <- (Fun Bool <- Key Value) @
  .every: (lambda (pred t) (not (find-table-entry @ pred t #f #f)))

  ;; : Bool <- (Fun Bool <- Key Value) @
  .any: (lambda (pred t) (and (find-table-entry @ pred t #f #t) #t))

  ;; : (List (Pair Key Value)) <- @
  ;; The backend supplies materialization, never whole-root admission.
  .list/key: (lambda (t) (.foldr acons [] t))
  .list<-: (lambda (t) (observe-table @ t (lambda () (.list/key t))))

  ;; : @ <- (List (Pair Key Value))
  .<-list: (lambda (rows) (construct-table @ rows #f))

  ;; Default persistent backend construction retains its original first-write
  ;; precedence. Specialized bulk builders declare their own existing policy.
  .<-list/key: (lambda (rows) (foldr (lambda (row root)
    (.acons (car row) (cdr row) root)) .empty rows))

  ;; Complete admission precedes the first forward/reverse binding observation.
  ;; The existing short-circuit query preserves leaves and declared backend order.
  ;; : (Option (Pair Key Value)) <- @
  .min-binding/opt: (cut find-table-entry @ true <> #f #t)

  ;; : (Option (Pair Key Value)) <- @
  .max-binding/opt: (cut find-table-entry @ true <> #t #t)

  ;; : (Pair Key Value) <- @
  .min-binding: (lambda (t) (option-ref (.min-binding/opt t)))

  ;; : (Pair Key Value) <- @
  .max-binding: (lambda (t) (option-ref (.max-binding/opt t)))

  ;; : (Option (Pair Key Value)) <- @
  .choose/opt: .min-binding/opt

  ;; : (Pair Key Value) <- @
  .choose: .min-binding

  ;; Extract the backend's chosen binding and an admitted persistent remainder.
  ;; Optional extraction returns Option Pair; required extraction refuses empty.
  .decons/opt: (lambda (input) (decons-table @ input #f))
  .decons: (lambda (input) (decons-table @ input #t))

  ;; First match in declared forward traversal; no monotonicity is inferred.
  ;; : (Option (Pair Key Value)) <- (Fun Bool <- Key Value) @
  .find-first/opt:
  (lambda (p t) (find-table-entry @ p t #f #t))

  ;; First match in declared reverse traversal, including nonmonotone predicates.
  ;; : (Option (Pair Key Value)) <- (Fun Bool <- Key Value) @
  .find-last/opt:
  (lambda (p t) (find-table-entry @ p t #t #t))

  ;; : (Pair Key Value) <- (Fun Bool <- Key Value) @
  .find-first: (lambda (p t) (option-ref (.find-first/opt p t)))

  ;; : (Pair Key Value) <- (Fun Bool <- Key Value) @
  .find-last: (lambda (p t) (option-ref (.find-last/opt p t)))

  ;; : @ <- Key (Fun (Option Value) <- (Option Value)) @
  .update/opt: (lambda (key transform input) (update-table-focus @ key transform input))

  ;; : @ <- Key (Fun Value <- Value) @ ?(Fun Value <-)
  .update: (lambda (k f t (default false))
             (.update/opt k (lambda (vo) (some (f (option-get/default vo default)))) t))
  ;; NB: For a handful of flat datastructures that don't have deep traversals, this could be better:
  ;;.update: (lambda (k f t (default false)) (.acons k (f (.ref t k (lambda _ (default)))) t))

  ;; : @ <- (Fun (Option Value) <- Key Value Value) @ @
  .union:
  (lambda (f a b)
    (using (f :~ procedure?)
      (.merge (lambda (key left right)
        (if (and left right) (f key (some-value left) (some-value right)) (or left right))) a b)))

  ;; Left-biased join retains false payloads because presence is an Option shell.
  .join: (lambda (a b) (.merge (lambda (_ left right) (or left right)) a b))

  ;; Retain foldl's existing later-source priority. Nonempty batches start at
  ;; their first admitted root, never an invented empty
  ;; seed that could violate a custom refinement. Empty batches admit .empty.
  .join/list: (lambda (roots)
    (using (roots :~ list?)
      ;; Own the finite request spine before metadata and root recognizers run.
      (set! roots (map identity roots))
      (with-table-sources (table-sources @) (lambda ()
        (for-each (cut require-table @ <>) roots)
        (if (null? roots) (require-table @ .empty) (foldl .join (car roots) (cdr roots)))))))

  ;; Equality observes admitted roots instead of constructing a throwaway merged
  ;; empty root, which may be forbidden by the table's own refinement.
  .=?: (lambda (a b) (equal-table-bindings? @ a b))

  ;; Explicit order and value comparison supply nonconstructive map comparison.
  .compare: (lambda (compare left right) (compare-table-bindings @ compare left right))

  ;; Complete optional nonempty parts share one checked division boundary.
  ;; : (OrFalse @) (OrFalse @) <- @
  .divide: (lambda (input) (table-division-values (divide-table @ input)))

  ;; Empty and singleton roots require no invented empty result or point writes.
  ;; : (List @) <- @
  .divide/list: (cut divide-table @ <>)

  ;; : @ <- (Iterator (Pair Key Value)) ?@
  .<-iter: (case-lambda
    ((sequence) (table-from-iter @ sequence []))
    ((sequence seed) (table-from-iter @ sequence (list seed))))

  ;; : (Iterator (Pair Key Value)) <- @
  ;; Backends may specialize traversal; the public entrypoint owns admission.
  .iter/key: (lambda (x) (iter (.list/key x)))
  .iter<-: (lambda (x (from #f)) (iterate-table @ x from))

  ;; : (Lens Value <- @) <- Key
  .lens: (lambda (key) (table-key-focus @ key #f))

  .Binding: (Pair Key Value)
  .Bindings: (List .Binding)
  ;; All formats share complete admission; the List/Pair codecs remain authoritative.
  .json<-: (cut collection-codec @ #f '.json<- <>) ;; : Json <- @
  .<-json: (cut collection-codec @ #f '.<-json <>) ;; : @ <- Json
  .bytes<-: (cut collection-codec @ #f '.bytes<- <>) ;; : Bytes <- @
  .<-bytes: (cut collection-codec @ #f '.<-bytes <>) ;; : @ <- Bytes
  .marshal: (cut collection-codec @ #f '.marshal <> <>)
  .unmarshal: (cut collection-codec @ #f '.unmarshal <>))
