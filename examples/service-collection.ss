;;; Gerbil Iterable classes over checked POO services and source-bound snapshots.
(export approved-ledger-action ledger-action make-services observe-services observe-cached-services prepare-ledger-revision apply-ledger-revision transport-ledger-action fold-ledger-action make-capacity-ledger batch-ledger-action make-mirrored-ledger revise-ledger-point revise-ledger-styles make-indexed-services make-tagged-services make-ordered-services make-seek-services make-ordered-service-indexes revise-indexed-services update-indexed-service)
(import (only-in ../support/base number-comparer) :std/iter (prefix-in :std/instance std.)
        (only-in ../table iterator-map table-fold table-wrapper table-styles table-indexes table-comparer table-comparer-wrapper table-order)
        (only-in ../fun Wrapper.) (only-in ../number UInt Integer)
        (only-in ../type Fun Tuple Pair List) (only-in ../rationaldict RationalDict)
        (only-in ../trie SimpleTrie)
        ../object ../mop ../object-contract ../object-contract-flow ../support/option
        (prefix-in ../construction-cache cache.)
        (prefix-in ../dependency-analysis code.)
        (only-in ../generalized-prototype Observation.))

;; Host ownership uses generated class fields; POO retains descriptor semantics.
(defstruct %services (descriptor rows) final: #t)
;; Delegate interface registration and class-aware receiver binding to std/instance.
;; The existing Iterator mapper validates one row per pull, without a new iterator engine.
(std.instance Iterable (self %services)
  ((iter) (iterator-map (checked-action self.descriptor identity) self.rows)))

;; Require finite host input while keeping descriptor validation in the POO protocol.
;; Creating the collection or its iterator does not normalize any service row.
(def (make-services descriptor rows)
  (validate Type descriptor)
  (using (rows :~ list?) (make-%services descriptor rows)))

;; Each ordered pull completes recursive wrapping/refinement before this IO consumer.
;; Return one observation per row; callback failures propagate, with prior effects retained.
(def (observe-services descriptor rows consume)
  (using (consume :~ procedure?)
    (for/collect (checked (make-services descriptor rows)) (consume checked))))

;; Observe a completed source-bound cache entry; absence and source failure refuse.
;; Cached raw rows are freshly admitted for each observation, never cached approvals.
(def (observe-cached-services snapshot key descriptor consume)
  (let (entry (cache.cache-ref snapshot key))
    (unless (and (some? entry) (code.success? (some-value entry)))
      (error "required service collection unavailable" key))
    (observe-services descriptor (code.success-value (some-value entry)) consume)))

;; Consume a normalized ledger without validating it again. The callback completes
;; before IO; its error suppresses consume and preserves prior external effects.
(def (consume-ledger descriptor key argument consume ledger)
  (let* ((callback (vector-ref (car (.call descriptor .ref ledger key)) 0))
         (result (callback argument)))
    (consume result)
    (values result (.call descriptor .count ledger))))

;; FUN passes a recursively normalized List/Tuple/Function table into lookup once.
;; Source remains persistent; a fresh invocation can retry after a refused request.
(def (ledger-action descriptor key argument consume)
  (checked-action descriptor (cut consume-ledger descriptor key argument consume <>)))

;; Named-schema refinement observes a normalized persistent table before IO. The
;; same consumer receives its already wrapped callbacks, without revalidating the
;; ledger. A false approval or bad callback result cannot reach the IO consumer.
(def (approved-ledger-action descriptor key argument consume)
  ;; Use the existing ObjectContract/refine chain; no table-specific approval API.
  (def submission (refine
    (.cc ObjectContract. responsibilities: (.o approved: Bool ledger: descriptor))
    (lambda (candidate location)
      (if (.@ candidate approved) '()
        [(.o kind: 'approval-refused path: (append location '(approved)))]))))
  (checked-action submission
    (lambda (candidate)
      (consume-ledger descriptor key argument consume (.@ candidate ledger)))))

;; Admit a proposed ledger through Reader/FUN once, retaining recursive Function
;; wrappers inside the generated delta. Before is a previously admitted snapshot.
;; Full admission may create fresh wrapper identities; use .diff directly between
;; admitted snapshots when unchanged callbacks must retain identity. Discovery
;; failure suppresses the consumer; no IO or source mutation occurs here.
(def (prepare-ledger-revision descriptor before)
  (checked-action descriptor (cut .call descriptor .diff before <>)))

;; Compose optimistic installation with an IO consumer through the existing FUN
;; map. The supplied current ledger is already admitted; revalidation here would
;; create new Function identities and invalidate legitimate captured expectations.
;; A conflict suppresses IO, leaving callers free to rediscover against the winner.
(def (apply-ledger-revision descriptor delta consume)
  (using (consume :~ procedure?)
    (.call Observation. .map consume (cut .call descriptor .apply-delta <> delta))))

;; Compose explicit collection/delta conversion, target installation and IO through
;; the existing Reader/FUN maps. Input is an admitted (base . delta) pair; every
;; conversion/law/conflict refusal suppresses consume, and no Function is rewrapped.
(def (transport-ledger-action mapping consume)
  (using (consume :~ procedure?)
    (def target (.@ mapping Codomain))
    (def changes (.@ mapping Delta))
    (.call Observation. .map consume
      (.call Observation. .map
        (lambda (staged) (.call target .apply-delta (car staged) (cdr staged)))
        (cut .call changes .ap <>)))))

;; Reader/FUN stages the aggregate and source snapshot together, then invokes IO.
;; The consumer receives the new opaque state only after complete success. Keep the
;; previous state for retry or apply an inverted delta; no mutable cache is installed.
(def (fold-ledger-action folding state consume)
  (using (consume :~ procedure?)
    (.call Observation. .map consume (cut .call folding .apply-delta state <>))))

;; Admit shared service callbacks once, and derive a capacity-preserving Trie view
;; from the source fold. Key XOR and Tuple/Pair conversion are explicit inverses.
;; Callers edit through the source table's optional lenses, discover a delta, then
;; reuse fold-ledger-action with transport; .unap recovers the paired source state.
(def (make-capacity-ledger rows)
  (def callback (Fun Integer <- Integer))
  (def payload (Tuple callback UInt))
  (def cooked (Pair UInt callback))
  (def source-type (.cc (RationalDict payload) Key: UInt))
  (def target-type (SimpleTrie UInt cooked))
  (def keys (.cc Wrapper. Domain: UInt Codomain: UInt
    .ap: (cut bitwise-xor <> 1) .unap: (cut bitwise-xor <> 1)))
  (def values (.cc Wrapper. Domain: payload Codomain: cooked
    .ap: (lambda (v) (cons (vector-ref v 1) (vector-ref v 0)))
    .unap: (lambda (v) (vector (cdr v) (car v)))))
  (def source-fold (table-fold source-type Integer (lambda (_ v) (vector-ref v 1))))
  (.o source: source-type target: target-type folding: source-fold
    transport: (.call source-fold .isomorphism target-type keys values)
    state: (.call source-fold .ap (validate source-type (.call source-type .<-list rows)))))

;; Stage an ordered revision batch once, then reuse the existing checked fold/FUN
;; continuation. A late conflict suppresses the consumer; retry supplies a fresh
;; source state and rediscovered deltas, without exposing an intermediate ledger.
(def (batch-ledger-action descriptor folding state consume)
  (.call Observation. .map (fold-ledger-action folding state consume)
    (cut .call descriptor .compose-deltas <>)))

;; Gerbil owns this carrier's representation and accessor; no tree algorithm is copied.
(defstruct %mirrored-ledger (tree) transparent: #t final: #t)

;; Derive a descending-key service table from RationalDict, retaining shared checked
;; callbacks while swapping Tuple/Pair fields. The raw target only recognizes its
;; host carrier and declares child Types; table-wrapper supplies every table method.
(def (make-mirrored-ledger)
  (def callback (Fun Integer <- Integer))
  (def payload (Tuple callback UInt))
  (def cooked (Pair UInt callback))
  (def source (RationalDict payload))
  (def target (.cc Type. Key: (.@ source Key) Value: cooked .element?: %mirrored-ledger?))
  (def carrier (.cc Wrapper. Domain: source Codomain: target
    .ap: make-%mirrored-ledger .unap: %mirrored-ledger-tree))
  (def keys (.cc Wrapper. Domain: (.@ source Key) Codomain: (.@ target Key) .ap: - .unap: -))
  (def values (.cc Wrapper. Domain: payload Codomain: cooked
    .ap: (lambda (v) (cons (vector-ref v 1) (vector-ref v 0)))
    .unap: (lambda (v) (vector (cdr v) (car v)))))
  (table-wrapper source carrier keys values))

;; Capture an optional-field request once, then publish through the existing
;; Reader/FUN continuation. The consumer is reached only after complete checked
;; installation; callers retain before and the inverse request for explicit undo.
(def (revise-ledger-point table before key transform consume)
  (using ((transform :~ procedure?) (consume :~ procedure?))
    (def delta (.call table .delta/opt key transform before))
    ((.call Observation. .map consume (cut .call table .apply-delta before <>)) delta)))

;; Reuse an admitted snapshot, transfer mutable ownership to a consuming reference, install a
;; complete batch and extract a pure snapshot before the existing Reader/IO map.
;; Any earlier refusal suppresses consume; a later IO failure retains no ownership
;; for automatic replay, so callers must choose a fresh explicit retry from base.
(def (revise-ledger-styles table base batch consume)
  (using (consume :~ procedure?)
    (def styles (table-styles table))
    (def mutable (.@ styles Mutable))
    (def linear (.@ styles Linear))
    (def owned (.call mutable .ap base))
    (def next (.call linear .apply-batch (.call mutable .convert owned 'linear) batch))
    ((.call Observation. .map consume (cut .call linear .convert <> 'pure)) next)))

;; Two unique service identifiers and a shared-team index are declared once.
;; Buckets reuse the primary persistent table, preserving each checked callback.
;; The returned descriptor works directly with deltas, batches, lenses and styles.
(def (make-indexed-services)
  (def source (RationalDict (Tuple UInt UInt UInt (Fun Integer <- Integer))))
  (def badge (.cc Type. name: 'badge table: (RationalDict (.@ source Key))
    project: (lambda (_ row) (vector-ref row 0)) unique?: #t))
  (def endpoint (.cc Type. name: 'endpoint table: (RationalDict (.@ source Key))
    project: (lambda (_ row) (vector-ref row 1)) unique?: #t))
  (def team (.cc Type. name: 'team table: (SimpleTrie UInt source)
    project: (lambda (_ row) (vector-ref row 2)) unique?: #f))
  (values (table-indexes source (list badge endpoint team)) source (list badge endpoint team)))

;; Each checked service owns several aliases and belongs to several teams.
;; Empty/duplicate memberships, ordered ranges and linear publication all use
;; the existing correlated index protocol; callbacks retain their admitted identity.
(def (make-tagged-services)
  (def source (SimpleTrie UInt (Tuple (List UInt) (List UInt) (Fun Integer <- Integer))))
  (def aliases (.cc Type. name: 'aliases table: (SimpleTrie UInt UInt) unique?: #t multiple?: #t
    project: (lambda (_ row) (vector-ref row 0))))
  (def backend (SimpleTrie UInt source))
  (def teams (.cc Type. name: 'teams table: (table-order backend (.@ backend Comparer))
    unique?: #f multiple?: #t project: (lambda (_ row) (vector-ref row 1))))
  (values (table-indexes source (list aliases teams)) source (list aliases teams)))

;; An explicit transported order indexes negative external service identifiers in
;; positive internal priority order. Existing table indexes own atomic publication;
;; existing styles own capability transfer. Function payloads are never rewrapped.
(def (make-ordered-services)
  (def source (RationalDict (Tuple Integer (Fun Integer <- Integer))))
  (def backend (RationalDict (.@ source Key)))
  (def key (.cc Wrapper. Domain: (.@ backend Key) Codomain: (.@ backend Key) .ap: - .unap: -))
  (def comparer (table-comparer (.@ backend Key) number-comparer))
  (def ordered (table-order backend (table-comparer-wrapper comparer key)))
  (def declaration (.cc Type. name: 'priority table: ordered unique?: #t
    project: (lambda (_ row) (- (vector-ref row 0)))))
  (values (table-indexes source (list declaration)) source comparer key))

;; Transfer Trie positioning through an explicit xor-key isomorphism. Numeric
;; external order differs from source order, so the transported Comparer is shared
;; explicitly. Correlated publication and FUN ownership remain unchanged.
(def (make-seek-services)
  (def source (SimpleTrie UInt (Tuple UInt (Fun Integer <- Integer))))
  (def backend (SimpleTrie UInt UInt))
  (def target (.cc Type. Key: UInt Value: UInt .element?: (.@ (.@ backend T) .element?)))
  (def carrier (.cc Wrapper. Domain: backend Codomain: target .ap: identity .unap: identity))
  (def keys (.cc Wrapper. Domain: UInt Codomain: UInt
    .ap: (cut bitwise-xor <> 1) .unap: (cut bitwise-xor <> 1)))
  (def payloads (.cc Wrapper. Domain: UInt Codomain: UInt .ap: identity .unap: identity))
  (def derived (table-wrapper backend carrier keys payloads))
  ;; Repeated order views retain positioning through the transported key domain.
  ;; No layer materializes/sorts a complete list merely to restore the capability.
  (def inner (table-order derived (.@ derived Comparer)))
  (def ordered (table-order inner (.@ inner Comparer)))
  (def declaration (.cc Type. name: 'priority table: ordered unique?: #t
    project: (lambda (_ row) (bitwise-xor (vector-ref row 0) 1))))
  (values (table-indexes source (list declaration)) source derived))

;; Declare unique priority and shared-team caches on the persistent ordered backend.
;; Cold construction reuses shape-preserving updates; admitted service callbacks
;; remain shared through grouped buckets, atomic deltas and FUN style conversion.
(def (make-ordered-service-indexes)
  (def source (SimpleTrie UInt (Tuple UInt UInt (Fun Integer <- Integer))))
  (def owners (SimpleTrie UInt UInt))
  (def groups (SimpleTrie UInt source))
  (def priority (.cc Type. name: 'priority unique?: #t
    table: (table-order owners (.@ owners Comparer))
    project: (lambda (_ row) (vector-ref row 0))))
  (def team (.cc Type. name: 'team unique?: #f
    table: (table-order groups (.@ groups Comparer))
    project: (lambda (_ row) (vector-ref row 1))))
  (values (table-indexes source (list priority team)) source))

;; Install a captured revision through the existing linear FUN/IO chain. A refused
;; primary/index update never reaches consume; normalization is not repeated.
(def (apply-indexed-revision indexed base delta consume)
  (def linear (.@ (table-styles indexed) Linear))
  (def next (.call linear .apply-delta (.call linear .ap base) delta))
  ((.call Observation. .map consume (cut .call linear .convert <> 'pure)) next))

;; Discover a complete revision, sharing the same installer as single-key requests.
;; Callback effects are not replayed or rolled back; retry is explicitly requested.
(def (revise-indexed-services indexed source base revise consume)
  (using ((revise :~ procedure?) (consume :~ procedure?))
    (def before (.call indexed .unwrap base))
    (apply-indexed-revision indexed base (.call source .diff before (revise before)) consume)))

;; Capture one optional service update once, then install every correlated index
;; atomically before IO. The delta retains expected old values and opaque Functions.
(def (update-indexed-service indexed base key revise consume)
  (using ((revise :~ procedure?) (consume :~ procedure?))
    (apply-indexed-revision indexed base (.call indexed .delta/opt key revise base) consume)))
