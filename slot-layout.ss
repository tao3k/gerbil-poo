;;; Shared shapes and receiver-local value vectors for guarded access sites.
(export slot-value-storage make-slot-values slot-values-layout
        make-slot-layout slot-layout-shape slot-layout-index slot-layout-ref slot-layout-set! slot-layout-put!
        make-slot-cache slot-cache-name slot-cache-layout slot-cache-hit? slot-cache-offset slot-cache-index slot-cache-read slot-cache-bind!)
(import (only-in :gerbil/runtime/hash HashTable HashTable::interface symbol-hash-table::t)
        (only-in :gerbil/runtime/interface interface-instance? interface-instance-object
                 &interface-descriptor-type &interface-descriptor-index interface-subclass?
                 prototype-table? prototype-table-table)
        (prefix-in (only-in :gerbil/runtime/mop object? object-class make-class-slot-accessor
                           class-slot-offset &class-type-slot-table &class-type-interface) route.)
        (only-in :gerbil/runtime/table raw-table? symbolic-table-ref symbolic-table-set!)
        (only-in :gerbil/runtime/gambit table? table-ref table-set! macro-table-test macro-table-hash macro-table-flags
                 random-integer macro-max-fixnum32)
        (only-in ./support/base %compare-symbol-identity)
        (only-in ./object-state object-state-revision)
        (only-in :std/hash/misc hash-ensure-ref) :std/iter (only-in :std/list/list delete-duplicates/hash find))

;; Carry Gambit's macro definitions in this module's static source as well as
;; its standard make invocation. Linked programs compile the dependency closure
;; independently of the per-module dynamic compiler command (as in io.ss).
(begin-foreign
  (include "~~lib/_gambit#.scm"))

;; Weak values allow unused canonical shapes to disappear; live layouts retain them.
(def shapes (make-hash-table test: equal? weak-values: #t))
;; Read the existing Gerbil adapter cache; never create a replacement adapter.
;; A cold/changed adapter uses ordinary admission. Pins describe class/method
;; identities and backend configuration; every call reads the current routes.
(def scalar-shape-routes-current?
  (let* ((wrapper (route.object-class shapes))
         (wrapper-id (##type-id wrapper))
         (backend-id (##type-id symbol-hash-table::t))
         (object-offset (route.class-slot-offset wrapper 'object))
         (ref-offset (route.class-slot-offset wrapper 'ref))
         (set-offset (route.class-slot-offset wrapper 'set!))
         (last-offset (max object-offset ref-offset set-offset))
         (object-field (route.make-class-slot-accessor wrapper 'object))
         (ref-field (route.make-class-slot-accessor wrapper 'ref))
         (set-field (route.make-class-slot-accessor wrapper 'set!))
         (cache-backend (object-field shapes))
         (cache-test (macro-table-test cache-backend))
         (cache-hash (macro-table-hash cache-backend))
         (cache-flags (macro-table-flags cache-backend)))
    (lambda ()
      (and (eq? (&interface-descriptor-type HashTable::interface) wrapper)
           (eq? (##type-id wrapper) wrapper-id)
           (eq? (##type-id symbol-hash-table::t) backend-id)
           (not (eq? wrapper-id backend-id))
           (not (interface-subclass? symbol-hash-table::t))
           (let (slots (route.&class-type-slot-table wrapper))
             (and (raw-table? slots)
               (eqv? (symbolic-table-ref slots 'object #f) object-offset)
               (eqv? (symbolic-table-ref slots 'ref #f) ref-offset)
               (eqv? (symbolic-table-ref slots 'set! #f) set-offset)))
           (eq? (ref-field shapes) table-ref)
           (eq? (set-field shapes) table-set!)
           (let (backend (object-field shapes))
             (and (table? backend)
               (eq? (macro-table-test backend) cache-test)
               (eq? (macro-table-hash backend) cache-hash)
               (eqv? (macro-table-flags backend) cache-flags)))
           (let ((table (route.&class-type-interface symbol-hash-table::t))
                 (index (&interface-descriptor-index HashTable::interface)))
             (and (prototype-table? table) (fixnum? index) (fx>= index 0)
               (let (entries (prototype-table-table table))
                 (and (vector? entries) (fx< index (vector-length entries))
                   (let (prototype (vector-ref entries index))
                     (and (route.object? prototype)
                          (eq? (route.object-class prototype) wrapper)
                          (> (##structure-length prototype) last-offset)
                          (eq? (ref-field prototype) symbolic-table-ref)
                          (eq? (set-field prototype) symbolic-table-set!)))))))))))
;; A shape owns the immutable name-to-index mapping. Cells always belong to one receiver.
(defstruct shape (indices names))
;; Object-backed cells belong to one revision of the existing invalidation state.
;; Standalone layouts and HashTable copies have no receiver revision.
(defstruct layout (shape cells missing count state revision))
;; Expose shape identity without exposing its mutable implementation fields.
(defalias slot-layout-shape layout-shape)
;; Intern an already canonical identity order through the one existing weak table.
;; An admitted private membership table can become the index of a new shape.
;; A hit leaves it unpublished. This routine never edits the keys' spine.
(def (intern-ordered-shape keys (members #f) (seed #f))
  (hash-ensure-ref shapes keys
    (lambda ()
      (let (indices (or members (if seed (make-hash-table-symbolic seed: seed)
                                   (make-hash-table-symbolic))))
        (for ((name keys) (index (in-range (length keys)))) (hash-put! indices name index))
        (make-shape indices keys)))))
;; Full and revised directories share the same symbolic order.
(def (shape-name<? left right)
  (negative? (%compare-symbol-identity left right)))
;; Fresh unrelated name sets still use the standard complete sort.
(def (intern-shape names members)
  (intern-ordered-shape (list-sort shape-name<? names) members))
;; Merge two disjoint canonical identity runs. The existing standard sorter owns
;; the new run; a tail loop and append-reverse share the untouched borrowed tail.
;; No intermediate shape/index is interned, and neither source spine is mutated.
(def (merge-shape-names left right)
  (let loop ((left left) (right right) (prefix []))
    (cond ((null? left) (append-reverse prefix right))
          ((null? right) (append-reverse prefix left))
          ((not (shape-name<? (car right) (car left)))
            (loop (cdr left) right (cons (car left) prefix)))
          (else (loop left (cdr right) (cons (car right) prefix))))))
;; One absent key extends an immutable sorted directory without sorting it again.
;; Standard prefix/copy operations share the untouched suffix; no second index or
;; cached transition is retained. The caller has already certified key absence.
(def (extend-shape previous key (members #f))
  (def keys (shape-names previous))
  ;; Standard find stops at the successor; its already-existing index supplies
  ;; the cut. False is not a symbolic key, and zero remains a valid offset.
  (def successor (find (lambda (name) (not (shape-name<? name key))) keys))
  (def at (if successor (hash-ref (shape-indices previous) successor) (length keys)))
  (intern-ordered-shape (append (take keys at) (cons key (drop keys at))) members))
;; Check exact identity coverage through the old index. One byte per offset
;; counts unique arrivals even when names are reordered or repeated. An unknown
;; key falls back to ordinary admission. A contraction cannot allocate old-width
;; scratch space if its entire request is smaller than the old shape.
(def (same-shape-names? names hint)
  (def indices (shape-indices hint))
  (def width (hash-length indices))
  (and (<= width (length names))
    (let (seen (make-u8vector width 0))
      (let loop ((names names) (remaining width))
        (if (null? names) (zero? remaining)
          (let* ((name (car names)) (index (and (symbol? name) (hash-get indices name))))
            (and index
              (if (zero? (u8vector-ref seen index))
                (begin (u8vector-set! seen index 1) (loop (cdr names) (1- remaining)))
                (loop (cdr names) remaining)))))))))

;; Admit every key before symbolic hashing. The private deduplication table
;; already owns exactly the new identities and can be filled with offsets.
(def (scalar-shape-request? names)
  (or (null? names) (and (pair? names) (null? (cdr names)))))
(def (admit-shape-name name) (using (name :~ symbol?) name))
(def (shape-for-names names hint)
  (if (and (not hint) (scalar-shape-request? names) (scalar-shape-routes-current?))
    ;; Keep the native seed draw BEFORE admission, even for a hit or a bad key.
    ;; This fixed RNG primitive preserves routes/caller spines in the serial
    ;; runtime law. It is not an author callback or a reusable currentness check.
    (let* ((seed (random-integer (macro-max-fixnum32)))
           (owned (if (null? names) [] (list (admit-shape-name (car names))))))
      (intern-ordered-shape owned #f seed))
    (ordinary-shape-for-names names hint)))
(def (ordinary-shape-for-names names hint)
  (def members (make-hash-table-symbolic))
  (def unique (delete-duplicates/hash names table: members
    key: admit-shape-name))
  (if (not hint) (intern-shape unique members)
    (let ((width (length unique)) (prior-width (hash-length (shape-indices hint))))
      ;; Bound filtering by the old/new width ratio. Large contractions sort
      ;; the small new request without scanning the obsolete directory.
      (if (or (zero? prior-width) (> prior-width (* 2 width))) (intern-shape unique members)
        (let (added (filter (lambda (name) (not (hash-key? (shape-indices hint) name))) unique))
          (cond
            ((null? added)
             (if (= width prior-width) hint
               (intern-ordered-shape
                 (filter (cut hash-key? members <>) (shape-names hint)) members)))
            ;; Cardinality and one unknown certify the cheaper single insert.
            ((and (= width (1+ prior-width)) (null? (cdr added)))
             (extend-shape hint (car added) members))
            (else
             (intern-ordered-shape
               (merge-shape-names
                 (filter (cut hash-key? members <>) (shape-names hint))
                 (list-sort shape-name<? added))
               members))))))))

;; Build independent cells after certifying the canonical shape. The hint can
;; share metadata only. An explicit initial table seeds values in shape order.
(def (make-slot-layout names initial missing previous: (previous #f) state: (state #f))
  (using (names :~ list?)
    (def hint (and previous (slot-layout-shape previous)))
    (def canonical
      (if (and hint (same-shape-names? names hint)) hint (shape-for-names names hint)))
    (def keys (shape-names canonical))
    ;; Fill the final vector through the same presence boundary as ordinary writes.
    ;; No intermediate value list, list-to-vector copy or second count scan exists.
    ;; A refused seed leaves this unpublished receiver local to this constructor.
    (def result (make-layout canonical (make-vector (length keys) missing) missing 0
      state (and state (object-state-revision state))))
    (when initial
      (for ((name keys) (index (in-range (length keys))))
        (slot-layout-set! result index (hash-ref initial name missing))))
    result))
;; Explicit backend qualification uses the same evaluator and resource limits.
;; The default owns all computed values in one vector; hash is a measured control.
(def slot-value-storage (make-parameter 'vector))
;; Build the sole instance value store before publishing any read credentials.
;; Symbolic shapes describe uncomputed cells, so construction runs no slot body.
(def (make-slot-values names initial entries missing previous: (previous #f) state: (state #f))
  ;; Admit both spines before append/map; layout construction owns key admission.
  (using ((names :~ list?) (entries :~ list?))
    ;; Source enumeration is extensible through the standard HashTable interface.
    ;; Own request spines/pairs before its first call; opaque values stay shared.
    ;; Without a source there is no callback handoff and no extra capture cost.
    (let ((names (if initial (list-copy names) names))
          (entries (if initial
                     (map (lambda (entry)
                       ;; Leave invalid rows to the original key-preparation
                       ;; primitives, without introducing an earlier refusal.
                       (if (pair? entry) (cons (car entry) (cdr entry)) entry)) entries)
                     entries)))
      (def keys (append names (if initial (hash-keys initial) []) (map car entries)))
      (def values
        (case (slot-value-storage)
          ((vector) (HashTable (make-slot-layout
            keys #f missing previous: previous state: state)))
          ((hash)
            ;; The qualification backend has the same admission, before any seed writes.
            (for-each (lambda (key) (using (key :~ symbol?) (void))) keys)
            (make-hash-table-symbolic))
          (else (error "unknown slot value storage" (slot-value-storage)))))
      (when initial (hash-for-each (lambda (key value) (hash-put! values key value)) initial))
      (for (([key . value] entries)) (hash-put! values key value))
      values)))
;; Unwrap the standard interface once when exposing its existing value layout.
;; There is no value copy, promotion, lineage alias or auxiliary cache.
(def (slot-values-layout table)
  (and (interface-instance? table)
    (let (value (interface-instance-object table)) (and (layout? value) value))))
;; HashTable dispatch already supplies a layout receiver. Check the symbolic
;; key here and read its existing index and cells without rechecking the receiver.
(def (layout-value self (key :~ symbol?) default)
  (using (self :- layout)
    (using (directory self.shape :- shape)
      (let (index (hash-get directory.indices key))
        (if index
          (let (value (vector-ref self.cells index))
            (if (eq? value self.missing) default value))
          default)))))
;; Unknown successful delegation grows the SAME store, after preparing all new
;; metadata/cells. Existing sites retain an immutable shape stamp and must rebind.
(def (layout-store! self key value)
  (let (index (slot-layout-index self key))
    (if index (slot-layout-set! self index value)
      (let* ((canonical (extend-shape (layout-shape self) key))
             (at (hash-ref (shape-indices canonical) key))
             (old (layout-cells self))
             (cells (make-vector (1+ (vector-length old)) (layout-missing self)))
             (next (make-layout canonical cells (layout-missing self) (layout-count self) #f #f)))
        ;; The admitted key is absent. Canonical order inserts exactly one cell;
        ;; standard bulk copies preserve false, functions and uncomputed cells.
        ;; Finish the private candidate before replacing the authoritative store.
        (vector-copy! cells 0 old 0 at)
        (vector-copy! cells (1+ at) old at (vector-length old))
        (slot-layout-set! next at value)
        (set! (layout-shape self) (layout-shape next))
        (set! (layout-cells self) (layout-cells next))
        (set! (layout-count self) (layout-count next)))))
  (void))
;; Reuse the compiler's HashTable interface for printers, reflection and clients.
;; Only computed cells participate; deletion/clear never evaluate a slot body.
(bind-method! layout::t 'HashTable::ref layout-value)
(bind-method! layout::t 'HashTable::set! layout-store!)
(bind-method! layout::t 'HashTable::update!
  (lambda (self key update default)
    (layout-store! self key (update (layout-value self key default)))))
(bind-method! layout::t 'HashTable::delete!
  (lambda (self key)
    (let (index (slot-layout-index self key))
      (when index (slot-layout-set! self index (layout-missing self))))))
(bind-method! layout::t 'HashTable::for-each
  (lambda (self proc)
    (for ((key (shape-names (layout-shape self))) (value (layout-cells self)))
      (unless (eq? value (layout-missing self)) (proc key value)))))
(bind-method! layout::t 'HashTable::length
  (lambda (self) (layout-count self)))
(bind-method! layout::t 'HashTable::copy
  (lambda (self)
    (HashTable (make-layout (layout-shape self) (vector-copy (layout-cells self))
                 (layout-missing self) (layout-count self) #f #f))))
(bind-method! layout::t 'HashTable::new
  (lambda (self (size-hint #f)) (HashTable (make-slot-layout [] #f (layout-missing self)))))
(bind-method! layout::t 'HashTable::clear!
  (lambda (self)
    (vector-fill! (layout-cells self) (layout-missing self))
    (set! (layout-count self) 0)))
;; Admit a symbolic name and return its offset for indexed callers and writes.
;; An absent name returns false; zero remains a valid offset.
(def (slot-layout-index layout (name :~ symbol?))
  (hash-get (shape-indices (slot-layout-shape layout)) name))
;; Only the guarded object access path consumes an index obtained from this shape.
(def (slot-layout-ref layout index) (vector-ref (layout-cells layout) index))
;; All indexed/named writes share this boundary. Check the current cell first;
;; only an empty/present transition changes occupancy. False and functions count.
;; The count is metadata, not another value store. Callers certify current indices.
(def (slot-layout-set! layout index value)
  (def old (vector-ref (layout-cells layout) index))
  (def missing (layout-missing layout))
  (vector-set! (layout-cells layout) index value)
  (unless (eq? (eq? old missing) (eq? value missing))
    (set! (layout-count layout)
      ((if (eq? old missing) 1+ 1-) (layout-count layout)))))
;; Named writes use the SAME growth, key admission and occupancy protocol as
;; HashTable::set!, including keys absent from the original static descriptor.
(defalias slot-layout-put! layout-store!)
;; One value guard retains one receiver/version/layout, independent of offset capacity.
(defstruct access-cache (name owner revision layout shape index))
;; An explicit two-shape site adds one immutable descriptor/offset, never cells.
;; This fixed record guard is not a general LRU or a second name/hash registry.
(defstruct (two-shape-cache access-cache) (previous-shape previous-index))
;; The fixed slot name belongs to the access site, not to the last receiver.
(defalias slot-cache-name access-cache-name)
;; An old receiver layout is a shape hint only; its cells never seed a new owner.
(defalias slot-cache-layout access-cache-layout)
;; Sites retain only access guards and one or two descriptor offsets. Successful
;; values always belong to the receiver, so sites have no value-seeding policy.
(def (make-slot-cache name shapes: (count 1))
  (using (count :~ (cut memv <> '(1 2)))
    (unless (symbol? name) (error "symbolic cache slot required"))
    (if (= count 1) (make-access-cache name #f #f #f #f #f)
      (make-two-shape-cache name #f #f #f #f #f #f #f))))
;; Admit the generation of receiver-owned cells through the existing state.
;; An independent layout has no receiver authority to check.
(def (layout-revision-current? layout revision)
  (let (state (layout-state layout))
    (or (not state) (and (eqv? revision (layout-revision layout))
                        (eqv? revision (object-state-revision state))))))
;; A matching caller stamp alone cannot authorize a retired value layout.
;; Offset hints still share immutable shapes without claiming live cells.
(def (slot-cache-hit? cache owner revision layout)
  (using (cache : access-cache)
    (and cache.index (eq? owner cache.owner) (eqv? revision cache.revision)
         (eq? layout cache.layout) (eq? cache.shape (slot-layout-shape layout))
         (layout-revision-current? layout revision) cache.index)))
;; Shape identity certifies only an offset, never another receiver's cells.
;; Compare one or two immutable descriptors without resolving a name.
;; False alone denotes a miss; index zero remains a successful offset.
(def (slot-cache-offset cache layout)
  (using (cache : access-cache)
    (if (and cache.layout cache.index
             (eq? (slot-layout-shape layout) cache.shape))
      cache.index
      (if (and (two-shape-cache? cache)
               (eq? (slot-layout-shape layout) (two-shape-cache-previous-shape cache)))
        (two-shape-cache-previous-index cache)
        #f))))
;; Resolve a name only after both bounded descriptor guards miss.
(def (slot-cache-index cache layout)
  (or (slot-cache-offset cache layout)
      (slot-layout-index layout (slot-cache-name cache))))
;; Read a materialized cell only while its receiver revision and shape are live.
;; Eviction keeps the offset but requires ordinary demand to refill the cell.
(def (slot-cache-read cache)
  (using (cache : access-cache)
    (unless (and cache.layout cache.index
                 (eq? cache.shape (slot-layout-shape cache.layout)))
      (error "stale slot cache offset"))
    (unless (layout-revision-current? cache.layout cache.revision)
      (error "stale slot cache revision"))
    (let (value (slot-layout-ref cache.layout cache.index))
      (when (eq? value (layout-missing cache.layout))
        (error "empty slot cache cell"))
      value)))
;; Admit a binding only for the site's name in a live layout revision.
;; Refusal preserves both entries; false clears the primary guard without a hit.
(def (slot-cache-bind! cache owner revision layout index)
  (using (cache : access-cache)
    (def current-shape (slot-layout-shape layout))
    (when (and index (not (layout-revision-current? layout revision)))
      (error "stale slot cache revision"))
    (when (and index (not (eqv? index (slot-cache-index cache layout))))
      (error "invalid slot cache offset" cache.name index))
    ;; Successful indexed demand alone changes offset history. Missing offsets
    ;; clear the primary value guard but cannot replace a certified second entry.
    (when (and index cache.index (two-shape-cache? cache)
               (not (eq? current-shape cache.shape)))
      (set! (two-shape-cache-previous-shape cache) cache.shape)
      (set! (two-shape-cache-previous-index cache) cache.index))
    (set! cache.owner owner) (set! cache.revision revision)
    (set! cache.layout layout) (set! cache.shape current-shape) (set! cache.index index)))
