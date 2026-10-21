;;; Common declarations and methods for tables

(export methods.table Set<-Table. PreZipping. Zipping. FocusableZipping.
        iterator-map table-element? validate-table
        table-delta? table-delta-count invert-table-delta table-isomorphism
        table-isomorphism-failure? table-isomorphism-failure-kind table-isomorphism-failure-value
        table-conflict? table-conflict-key)

(import
  (only-in ./variant-validation validate-bindings)
  :std/interface
  :std/iter
  (only-in :std/list/list-builder with-list-builder)
  (only-in :std/list/list delete-duplicates/hash)
  (only-in :std/list/alist acons)
  (only-in :std/func compose)
  (only-in ./support/option some some? option-ref option-get/default map/option some-value)
  (only-in ./brace @method)
  (only-in ./io marshal)
  (only-in ./mop define-type Type. Any validate element? raise-type-error TypeError? lens-of-get-set)
  (only-in ./fun Wrapper.)
  (only-in ./object .@ .call .cc object-revision active-object-constructions instantiate-object!)
  (only-in ./type List Pair))

(defstruct %mapped-iterator (source transform) final: #t)
(implement Iterator %mapped-iterator
  (next!
   (lambda (self)
     (using ((source self.source :- Iterator))
       (def value (source.next!))
       (if (eq? value #!eof) #!eof (self.transform value))))))

(def (iterator-map transform source)
  (Iterator (%mapped-iterator (iter source) transform)))

;; Recognize carrier and child membership without constructing normalized wrappers.
;; Catch only typed refusal; user/backend exceptions preserve their original cause.
(def (table-element? descriptor source)
  (try
    (.call descriptor .validate-shape source)
    (.call descriptor .every
      (lambda (key value)
        (and (element? (.@ descriptor Key) key) (element? (.@ descriptor Value) value))) source)
    (catch (TypeError? _) #f)))

;; Validate a persistent table through its current public representation protocol.
;; Admit the carrier, normalize children, then privately rebuild and recognize the result.
(def (validate-table descriptor source)
  (.call descriptor .validate-shape source)
  ;; Post-recognition checks the normalized result without wrapping children again.
  (def checked (validate-bindings descriptor (.@ descriptor Key) (.@ descriptor Value) source
    (.call descriptor .list<- source) (lambda () (.@ descriptor .empty))
    (.@ descriptor .key?) (.@ descriptor .acons)))
  (unless (element? descriptor checked) (raise-type-error descriptor checked))
  checked)

;; Changes retain admitted values, including Function wrappers. Missing is #f;
;; a stored false is (some #f). Neither constructors nor mutable edit lists escape.
(defstruct table-change (key before after) final: #t)
;; Bind a finite delta to its source protocol and child descriptor revisions.
(defstruct table-delta (key value sources versions changes) final: #t)
;; A conflict reports the first changed key whose expected old value disagrees.
(defstruct table-conflict (key) final: #t)

;; Match the existing .update/opt equality: structural data and opaque procedure
;; identities, without requiring every type to implement an equality method.
(def (table-option=? left right)
  (if (some? left)
    (and (some? right) (equal? (some-value left) (some-value right)))
    (not (some? right))))

;; Protect supported descriptor writes for the whole operation, including user
;; recognizers/backend callbacks. Mutable leaf data remains a caller premise.
(def (with-table-sources sources action)
  (for-each instantiate-object! sources)
  (parameterize ((active-object-constructions (append sources (active-object-constructions))))
    (action)))

;; Recognition does not normalize again: callers admit snapshots through validate
;; or checked-action first, and deltas retain those exact normalized child values.
(def (require-table descriptor source)
  (unless (element? descriptor source) (raise-type-error descriptor source))
  source)

;; Enumerate each changed binding once: source order for updates/deletes, then
;; target order for inserts. Gerbil's list builder owns finite ordered accumulation.
;; Discovery scans both snapshots; only application is proportional to edit count.
(def (diff-table descriptor before after)
  (def sources (list descriptor (.@ descriptor Key) (.@ descriptor Value)))
  (with-table-sources sources
    (lambda ()
      (require-table descriptor before)
      (require-table descriptor after)
      (make-table-delta (.@ descriptor Key) (.@ descriptor Value) sources (map object-revision sources)
        (with-list-builder (emit)
          (.call descriptor .for-each
            (lambda (key value)
              (def next (.call descriptor .ref/opt after key))
              (unless (table-option=? (some value) next)
                (emit (make-table-change key (some value) next)))) before)
          (.call descriptor .for-each
            (lambda (key value)
              (unless (.call descriptor .key? before key)
                (emit (make-table-change key #f (some value))))) after))))))

;; Report edit count without exposing the owned edit list or its constructors.
(def (table-delta-count delta) (length (table-delta-changes delta)))

;; Undo in reverse order, retaining the exact callbacks and descriptor provenance.
;; Stable values and pure backend callbacks are required for reversible observations.
(def (invert-table-delta delta)
  (make-table-delta (table-delta-key delta) (table-delta-value delta)
    (table-delta-sources delta) (table-delta-versions delta)
    (map (lambda (change)
      (make-table-change (table-change-key change) (table-change-after change)
                         (table-change-before change)))
      (reverse (table-delta-changes delta)))))

;; Portable across persistent carriers with identical Key/Value descriptors.
;; Refuse stale metadata before lookup; stage all writes privately, so a conflict
;; exposes no partial table. Unrelated bindings may be rebased and remain intact.
;; Source is admitted; shape checks retain their cost without repeated wrapping.
(def (apply-table-delta descriptor source delta)
  (unless (table-delta? delta) (error "table delta required"))
  (def sources (table-delta-sources delta))
  (with-table-sources (cons descriptor sources)
    (lambda ()
      (unless (and (equal? (table-delta-versions delta) (map object-revision sources))
                   (eq? (.@ descriptor Key) (table-delta-key delta))
                   (eq? (.@ descriptor Value) (table-delta-value delta)))
        (error "stale or incompatible table delta"))
      (.call descriptor .validate-shape source)
      (foldl
        (lambda (change staged)
          (def key (table-change-key change))
          (unless (table-option=? (table-change-before change)
                    (.call descriptor .ref/opt staged key))
            (raise (make-table-conflict key)))
          (match (table-change-after change)
            (#f (.call descriptor .remove staged key))
            ((some value) (.call descriptor .acons key value staged))))
        source (table-delta-changes delta)))))

;; A failed finite law/collision check reports its kind and offending value.
;; No partially converted carrier or change sequence is included in this payload.
(defstruct table-isomorphism-failure (kind value) final: #t)
;; One captured direction uses the existing Wrapper operations with explicit Types.
;; Its inverse swaps the two descriptors and the two pairs of pure callbacks.
(defstruct table-translation (source target key unkey value unvalue) final: #t)

;; Check actual encountered values without normalizing admitted children again.
;; Both callbacks must map admitted values to admitted values and respect equal?.
;; Membership alone cannot establish Function wrapping or universal inverse laws.
(def (translate-table-value source target forward backward input (observe void))
  (def output (forward input))
  (unless (element? target output) (raise-type-error target output 'table-isomorphism))
  (observe output)
  (def recovered (backward output))
  (unless (and (element? source recovered) (equal? recovered input))
    (raise (make-table-isomorphism-failure 'left-inverse input)))
  (unless (equal? (forward recovered) output)
    (raise (make-table-isomorphism-failure 'right-inverse output)))
  output)

;; Each attempt owns one typed persistent key registry using the TARGET backend.
;; It detects the backend's own collisions, including keys deleted in one snapshot
;; and inserted in the next. Repeated occurrences of the same source key are legal.
(def (table-translators direction)
  (def source (table-translation-source direction))
  (def target (table-translation-target direction))
  (def owners (.cc target Value: (.@ source Key)))
  (def seen (.@ owners .empty))
  ;; Register before testing the inverse, so a lossy key map reports collision.
  (def (key input)
    (translate-table-value (.@ source Key) (.@ target Key)
      (table-translation-key direction) (table-translation-unkey direction) input
      (lambda (output)
        (def previous (.call owners .ref/opt seen output))
        (when (and (some? previous) (not (equal? input (some-value previous))))
          (raise (make-table-isomorphism-failure 'collision output)))
        (set! seen (.call owners .acons output input seen)))))
  ;; Rebuild privately with existing folds/insertion; retained Function leaves
  ;; remain the same admitted procedures in the converter's returned structures.
  (def (table input)
    (require-table source input)
    (require-table target
      (.call source .foldl
        (lambda (k v result)
          (.call target .acons (key k)
            (translate-table-value (.@ source Value) (.@ target Value)
              (table-translation-value direction) (table-translation-unvalue direction) v) result))
        (.@ target .empty) input)))
  (values key table))

;; Lift explicit typed Key/Value Wrappers to collection and delta Wrappers.
;; Domain/Codomain must match exactly. Captured metadata is checked on every use;
;; callback exceptions propagate, and supported metadata writes refuse in scope.
;; Finite checks are controls for supplied laws, never universal proof discovery.
(def (table-isomorphism source target key value)
  (unless (and (eq? (.@ key Domain) (.@ source Key))
               (eq? (.@ key Codomain) (.@ target Key))
               (eq? (.@ value Domain) (.@ source Value))
               (eq? (.@ value Codomain) (.@ target Value)))
    (error "incompatible table isomorphism types"))
  (def sources (delete-duplicates/hash
    (list source target key value (.@ source Key) (.@ source Value) (.@ target Key) (.@ target Value))
    table: (make-hash-table-eq) from-end?: #t))
  (with-table-sources sources
    (lambda ()
      (def versions (map object-revision sources))
      (def ka (.@ key .ap)) (def ku (.@ key .unap))
      (def va (.@ value .ap)) (def vu (.@ value .unap))
      (using ((ka :~ procedure?) (ku :~ procedure?) (va :~ procedure?) (vu :~ procedure?))
        (def forward (make-table-translation source target ka ku va vu))
        (def backward (make-table-translation target source ku ka vu va))
        ;; Own guards across the whole conversion, including delta origin metadata.
        (def (guard dependencies action)
          (with-table-sources dependencies
            (lambda ()
              (unless (equal? versions (map object-revision sources))
                (error "stale table isomorphism"))
              (action))))
        ;; Collection-only conversion has no retained global memo or registry.
        (def (convert direction input)
          (guard sources
            (lambda ()
              (defvalues (_ table) (table-translators direction))
              (table input))))
        ;; The Pair carries admitted base . delta. Install in source first, then
        ;; translate both snapshots through ONE registry, retaining edit order.
        ;; Read converted before/after bindings to avoid repeated Function wrapping.
        (def (changes direction input)
          (unless (and (pair? input) (table-delta? (cdr input)))
            (error "table isomorphism Delta requires base and delta"))
          (def delta (cdr input))
          (def dependencies (delete-duplicates/hash (append sources (table-delta-sources delta))
            table: (make-hash-table-eq) from-end?: #t))
          (guard dependencies
            (lambda ()
              (def from (table-translation-source direction))
              (def to (table-translation-target direction))
              (def after (.call from .apply-delta (car input) delta))
              (defvalues (key table) (table-translators direction))
              (def before* (table (car input)))
              (def after* (table after))
              (cons before*
                (make-table-delta (.@ to Key) (.@ to Value) dependencies (map object-revision dependencies)
                  (map (lambda (change)
                    (def k (key (table-change-key change)))
                    (make-table-change k (.call to .ref/opt before* k) (.call to .ref/opt after* k)))
                    (table-delta-changes delta)))))))
        (.cc Wrapper. Domain: source Codomain: target
          .ap: (cut convert forward <>) .unap: (cut convert backward <>)
          Delta: (.cc Wrapper. .ap: (cut changes forward <>) .unap: (cut changes backward <>)))))))

;; TODO: have APIs look more like LIL, less like OCaml?
;; Especially since we may (1) use similar metaprogramming for OO style (?), and
;; (2) distinguish between for-each / foldl / foldr (iterating over pairs)
;; vs for-each* / foldl* / afoldr (iterating with two separate arguments for k v)
;; (3) implement additional APIs like drop, decons, map/2, convert, etc.
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

  ;; Recognition never normalizes children. This keeps nested List/Schema shape
  ;; checks and postconditions from constructing or discarding Function wrappers.
  ;; Typed refusal is false; unexpected user/backend exceptions remain observable.
  .element?: (lambda (source) (table-element? @ source))

  ;; Both Key and Value recursively normalize after complete carrier admission.
  ;; Persistent reconstruction retains every replacement and rejects key collisions.
  .validate: (lambda (source) (validate-table @ source))

  ;; : (Fun Bool <- @)
  .empty?: (lambda (t) (eqv? t .empty))

  ;; : (Fun Bool <- @ Key)
  .key?: (lambda (t key) (let/cc ret (.ref t key (lambda _ (ret #f))) #t))

  ;; : (Fun (Option Value) <- @ Key)
  .ref/opt: (lambda (t key) (let/cc ret (some (.ref t key (lambda _ (ret #f))))))

  ;; : Unit <- (Fun Unit <- Key Value) @
  .for-each: (lambda (f t) (.foldl (lambda (k v a) (void (f k v))) (void) t))

  ;; : Unit <- (Fun Unit <- Key Value) @
  .for-each/reverse: (lambda (f t) (.foldr (lambda (k v a) (void (f k v))) (void) t))

  ;; : @ <- Key (Option Value) @
  .acons/opt: (lambda (k ov t) (match ov (#f t) ((some v) (.acons k v t))))

  ;; : @ <- Key Value
  .singleton: (lambda (k v) (.acons k v .empty))

  ;; Merging the hard way, by iterating on one table to add its entries,
  ;; then on the other table to add its one-sided entries.
  ;; : @ <- (Fun (Option Value) <- Key (Option Value) (Option Value)) @ @
  .merge:
  (lambda (f ta tb)
    (.foldl (lambda (k vb m)
              (if (.key? ta k) m (.acons/opt k (f k #f (some vb)) m)))
            (.foldl (lambda (k va m) (.acons/opt k (f k (some va) (.ref/opt tb k)) m))
                    .empty ta)
            tb))

  ;; Finite differences and optimistic persistent installation share this backend.
  .diff: (lambda (before after) (diff-table @ before after))
  .apply-delta: (lambda (source delta) (apply-table-delta @ source delta))

  ;; Optional focus is total at missing keys and uses the existing Lens protocol.
  ;; The setter receives value before state, as Lens.modify/compose require.
  .lens/opt: (lambda (key)
    (lens-of-get-set (cut .ref/opt <> key)
      (lambda (value source) (.update/opt key (lambda (_) value) source))))

  ;; : Nat <- @
  .count: (lambda (t) (.foldl (lambda (_1 _2 a) (1+ a)) 0 t))

  ;; : Bool <- (Fun Bool <- Key Value) @
  .every: (lambda (pred t) (let/cc return (.for-each (lambda (k v) (unless (pred k v) (return #f))) t) #t))

  ;; : Bool <- (Fun Bool <- Key Value) @
  .any: (lambda (pred t) (let/cc return (.for-each (lambda (k v) (when (pred k v) (return #t))) t) #f))

  ;; : (List (Pair Key Value)) <- @
  .list<-: (lambda (t) (.foldr acons [] t))

  ;; : @ <- (List (Pair Key Value))
  .<-list: (lambda (l) (foldr (lambda (kv t) (.acons (car kv) (cdr kv) t)) .empty l))

  ;; : (Option (Pair Key Value)) <- @
  .min-binding/opt: (lambda (t) (let/cc return (.for-each (lambda (k v) (return (some (cons k v)))) t) #f))

  ;; : (Option (Pair Key Value)) <- @
  .max-binding/opt: (lambda (t) (let/cc return (.for-each/reverse (lambda (k v) (return (some (cons k v)))) t) #f))

  ;; : (Pair Key Value) <- @
  .min-binding: (lambda (t) (option-ref (.min-binding/opt t)))

  ;; : (Pair Key Value) <- @
  .max-binding: (lambda (t) (option-ref (.max-binding/opt t)))

  ;; : (Option (Pair Key Value)) <- @
  .choose/opt: .min-binding/opt

  ;; : (Pair Key Value) <- @
  .choose: .min-binding

  ;; Linear scan for the first matching entry
  ;; BEWARE: this assumes for-each is in increasing key order.
  ;; : (Option (Pair Key Value)) <- (Fun Bool <- Key Value) @
  .find-first/opt:
  (lambda (p t) (let/cc return
             (.for-each (lambda (k v) (when (p k v) (return (some (cons k v))))) t) #f))

  ;; Linear scan for the last matching entry
  ;; BEWARE: this assumes for-each/reverse is in decreasing key order.
  ;; : (Option (Pair Key Value)) <- (Fun Bool <- Key Value) @
  .find-last/opt:
  (lambda (p t) (let/cc return
             (.for-each/reverse (lambda (k v) (when (p k v) (return (some (cons k v))))) t) #f))

  ;; : (Pair Key Value) <- (Fun Bool <- Key Value) @
  .find-first: (lambda (p t) (option-ref (.find-first/opt p t)))

  ;; : (Pair Key Value) <- (Fun Bool <- Key Value) @
  .find-last: (lambda (p t) (option-ref (.find-last/opt p t)))

  ;; : @ <- Key (Fun (Option Value) <- (Option Value)) @
  .update/opt:
  (lambda (k f t)
    (def o (.ref/opt t k))
    (def u (f o))
    (if (equal? o u) t
        (match u
          (#f (.remove t k))
          ((some v) (.acons k v t)))))

  ;; : @ <- Key (Fun Value <- Value) @ ?(Fun Value <-)
  .update: (lambda (k f t (default false))
             (.update/opt k (lambda (vo) (some (f (option-get/default vo default)))) t))
  ;; NB: For a handful of flat datastructures that don't have deep traversals, this could be better:
  ;;.update: (lambda (k f t (default false)) (.acons k (f (.ref t k (lambda _ (default)))) t))

  ;; : @ <- (Fun (Option Value) <- Key Value Value) @ @
  .union:
  (lambda (f a b)
    (def (g i a b)
      (if a (if b (f i (some-value a) (some-value b)) a) b))
    (.merge g a b))

  ;; : @ <- @ @
  .join: (lambda (a b) (.merge (lambda (_ a b) (or a b)) a b))

  ;; : @ <- (List @)
  .join/list: (lambda (l) (foldl .join .empty l))

  ;; : Bool <- @ @
  .=?: (lambda (a b) (let/cc return
                  (.merge (lambda (_ a b)
                            (unless (and a b (.call Value .=? (some-value a) (some-value b)))
                              (return #f)) #f)
                          a b) #t))

  ;; Split a table in two smaller trees, if possible, a somewhat balanced way, if possible.
  ;; Return two values, the first being true if the table was not empty, and the second being true
  ;; if the table had at least two elements.
  ;; ASSUMES that #f, if a valid table, is the empty table.
  ;; This default method does the stupid thing of taking the first element off.
  ;; : (OrFalse @) (OrFalse @) <- @
  .divide:
  (lambda (t)
    (match (.min-binding/opt t)
      ((some (cons k v)) (values (.singleton k v) (let (r (.remove t k)) (and (not (.empty? r)) r))))
      (#f (values #f #f))))

  ;; Split a table in two or more strictly smaller trees, if possible, a somewhat balanced way, if possible.
  ;; Fallback to an empty list if the table was empty, or a singleton list of itself if a singleton table.
  ;; This default method assumes that we have good way to divide table in two.
  ;; : (List @) <- @
  .divide/list:
  (lambda (t)
    (match (.divide t)
      ((values #f #f) [])
      ((values x #f) [x])
      ((values x y) [x y])))

  ;; : @ <- (Iterator (Pair Key Value)) ?@
  .<-iter: (lambda (s (t .empty)) (for/fold (t t) (kv s) (.acons (car kv) (cdr kv) t)))

  ;; : (Iterator (Pair Key Value)) <- @
  .iter<-: (lambda (x) (iter (.list<- x)))

  ;; : (Lens Value <- @) <- Key
  .lens: (lambda (k) {get: (lambda (t) (.ref t k)) set: (lambda (t v) (.acons k v t))})

  .Binding: (Pair Key Value)
  .Bindings: (List .Binding)
  .json<-: (compose (.@ .Bindings .json<-) .list<-) ;; : Json <- @
  .<-json: (compose .<-list (.@ .Bindings .<-json)) ;; : @ <- Json
  .bytes<-: (compose (.@ .Bindings .bytes<-) .list<-) ;; : Bytes <- @
  .<-bytes: (compose .<-list (.@ .Bindings .<-bytes)) ;; : @ <- Bytes
  .marshal: (lambda (x port) (marshal .Bindings (.list<- x) port))
  .unmarshal: (compose .<-list (.@ .Bindings .unmarshal)))

(define-type (Set<-Table. @ Type. Table sexp)
  ;; Table must be a table from Elt to Unit, i.e. (.@ Table Key) == Elt, (.@ Table Value) == Unit
  Elt: (.@ Table Key) ;; : Type
  .validate: (.@ Table .validate) ;; : @ <- Any
  .element?: (.@ Table .element?) ;; recognition retains the table protocol without normalization
  .empty: (.@ Table .empty)  ;; : @
  .empty?: (.@ Table .empty?) ;; : Bool <- @
  .elt?: (.@ Table .key?) ;; : Bool <- @ Elt
  .cons: (cut .call Table .acons <> (void) <>) ;; : @ <- Elt @
  .singleton: (lambda (elt) (.call Table .singleton elt (void))) ;; : @ <- Elt
  .remove: (.@ Table .remove) ;; : @ <- @ Elt
  .for-each: (lambda (f t) (.call Table .for-each (lambda (e _) (f e)) t)) ;; : Unit <- (Unit <- Elt) @
  .for-each/reverse: (lambda (f t) (.call Table .for-each/reverse (lambda (e _) (f e)) t)) ;; : Unit <- (Unit <- Elt) @
  .foldl: (lambda (f a t) (.call Table .foldl (lambda (e _ a) (f e a)) a t)) ;; : a <- (a <- Elt a)
  .foldr: (lambda (f a t) (.call Table .foldr (lambda (e _ a) (f e a)) a t)) ;; : a <- (a <- Elt a)
  .every: (lambda (f t) (.call Table .every (lambda (e _) (f e)) t)) ;; : Bool <- (Bool <- Elt) @
  .any: (lambda (f t) (.call Table .any (lambda (e _) (f e)) t)) ;; : Bool <- (Bool <- Elt) @
  .filter: (lambda (f t) (.call Table .filter (lambda (e _) (f e)) t)) ;; : @ <- (Bool <- Elt) @
  .partition: (lambda (f t) (.call Table .partition (lambda (e _) (f e)) t)) ;; : @ @ <- (Bool <- Elt) @
  .count: (.@ Table .count) ;; : Nat <- @
  .list<-: (lambda (t) (map car (.call Table .list<- t))) ;; : (List Elt) <- @
  .<-list: (lambda (l) (foldl .cons .empty l)) ;; : @ <- (List Elt)
  .sexp<-: (lambda (x) `(.call ,sexp .<-list (@list ,@(map (.@ Elt sexp<-) (.list<- x))))) ;; : Sexp <- @
  .min-elt: (lambda (t) (car (.call Table .min-binding t))) ;; : Elt <- @
  .min-elt/opt: (lambda (t) (map/option car (.call Table .min-binding/opt t))) ;; : (Option Elt) <- @
  .max-elt: (lambda (t) (car (.call Table .max-binding t))) ;; : Elt <- @
  .max-elt/opt: (lambda (t) (map/option car (.call Table .max-binding/opt t))) ;; : (Option Elt) <- @
  .choose: .min-elt ;; : Elt <- @
  .choose-opt: .min-elt/opt ;; : (Option Elt) <- @
  .split: (lambda (elt t) (defvalues (a v b) (.call Table .split elt t)) (values a (some? v) b)) ;; : @ Bool @ <- Elt @
  .find-first/opt: (lambda (f t) (map/option car (.call Table .find-first/opt (lambda (e _) (f e)) t))) ;; : (Option Elt) <- (Bool <- Elt) @
  .find-first: (lambda (f t) (option-ref (.find-first/opt f t))) ;; : Elt <- (Bool <- Elt) @
  .find-last/opt: (lambda (f t) (map/option car (.call Table .find-last/opt (lambda (e _) (f e)) t))) ;; : (Option Elt) <- (Bool <- Elt) @
  .find-last: (lambda (f t) (option-ref (.find-last/opt f t))) ;; : Elt <- (Bool <- Elt) @
  .iter<-: (lambda (t from: (from #f)) ;; : (Iterator Elt) <- @ ?Elt
              (iterator-map car
                            (if (not from)
                              (.call Table .iter<- t)
                              (.call Table .iter<- t from))))
  .<-iter: (lambda (s (t .empty)) (for/fold (t t) (elt s) (.cons elt t))) ;; : @ <- (Iterator Elt) ?@
  .List: (List Elt)
  .json<-: (compose (.@ .List .json<-) .list<-) ;; : Json <- @
  .<-json: (compose .<-list (.@ .List .<-json)) ;; : @ <- Json
  .bytes<-: (compose (.@ .List .bytes<-) .list<-) ;; : Bytes <- @
  .<-bytes: (compose .<-list (.@ .List .<-bytes)) ;; : @ <- Bytes
  .marshal: (lambda (x port) (marshal .List (.list<- x) port))
  .unmarshal: (compose .<-list (.@ .List .unmarshal))
  ;; TODO: for union, inter, diff, compare, equal, subset,
  ;; optimize for full subtables, by caching count in wrapper?
  .union: (lambda (a b) (.call Table .merge (lambda (_1 _2 _3) (some (void))) a b)) ;; : @ <- @ @
  .inter: (lambda (a b) (.call Table .merge (lambda (_ a b) (and a b (some (void)))) a b)) ;; : @ <- @ @
  .diff: (lambda (a b) (.call Table .merge (lambda (_ a b) (and (not b) a)))) ;; : @ <- @ @
  .compare: (lambda (a b) (.call Table .compare (lambda (_1 _2) 0) a b)) ;; : : Integer <- @ @
  .=?: (lambda (a b) (.call Table .=? a b)) ;; : Bool <- @ @
  .lens: (lambda (e) {get: (lambda (t) (.elt? t e)) set: (lambda (t v) (if v (.cons e t) (.remove t e)))})) ;; : (Lens Bool <- @) <- Elt


(define-type (PreZipping. @ [Type.]
  ;; StepF :: Type <- Type
  ;; PathF :: Type <- Type
  .path-step ;; (OrFalse (Pair (StepF a) (PathF a))) <- (PathF a)
  .step-down)) ;; (PathF a) <- (StepF a) (PathF a)

(define-type (Zipping. @ [PreZipping.]
  ;; Zipper = (Pair Node (PathF Node))
  .zipper<- ;; Zipper <- T
  .<-top-zipper ;; T <- Zipper
  .stepUp)) ;; node <- (StepF Node) Node

(define-type (FocusableZipping. @ [Zipping.]
  .refocus)) ;; Zipper <- FocusKey Zipper
