;;; Gerbil Iterable classes over checked POO services and source-bound snapshots.
(export observe-access-action singleton-ledger-action join-ledger-action reconcile-ledger-action fold-access-action make-policy-capacity-fold make-rational-capacity-ledger apply-indexed-revision admit-ledger-action empty-ledger-action choose-ledger-action decode-ledger-action equal-ledger-action associate-ledger-action construct-ledger-action compare-ledger-action import-ledger-action find-ledger-action divide-ledger-action observe-indexed-range observe-ledger-range make-service-override-view make-service-membership-fold make-service-policy-summary make-service-route-summary drop-ledger-action decons-ledger-action make-service-routes make-service-placement-join make-service-routing-join publish-join-action make-team-capacity-fold make-service-permission-image publish-set-combination-action publish-access-image-action publish-projected-ledger-action revise-projected-ledger-action map-ledger-into-action make-cohort-access make-service-ledger observe-ledger-first make-cohort-services partition-ledger-action merge-ledger-action split-ledger-action map-ledger-action revise-focused-ledger partition-access-action access-style-action prepare-access-revision prepare-ledger-transport approved-ledger-action ledger-action make-services observe-services observe-cached-services prepare-ledger-revision apply-ledger-revision transport-ledger-action fold-ledger-action make-capacity-ledger batch-ledger-action make-mirrored-ledger revise-ledger-point revise-ledger-styles revise-ledger-receivers observe-indexed-receiver make-indexed-services make-tagged-services make-ordered-services make-seek-services make-ordered-service-indexes revise-indexed-services update-indexed-service publish-indexed-services)
(import (only-in ../support/base number-comparer) :std/iter (prefix-in :std/instance std.)
        (only-in ../table Set<-Table. table-isomorphism iterator-map table-fold table-group-fold table-combination table-projection table-projection-compose table-group-join table-lookup-join table-wrapper table-styles set-styles set-image table-indexes table-comparer table-comparer-wrapper table-order)
        (only-in ../brace @@method) (only-in ../fun Wrapper.) (only-in ../number UInt Integer)
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

;; Reprepare current metadata for each request, then use the same Reader seed for
;; delta transport, installation and IO. Construction/admission failures suppress
;; every later stage; retry is an explicit new invocation, with no cached approval.
(def (prepare-ledger-transport source target keys values consume)
  (using (consume :~ procedure?)
    (.call Observation. .bind
      (lambda (_) (table-isomorphism source target keys values))
      (cut transport-ledger-action <> consume))))

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
;; Descriptor refinements reuse this same construction chain and child Types;
;; source and target final-root admission remains part of each fold publication.
(def (make-capacity-ledger rows source: (source-refine identity) target: (target-refine identity)
                           policy: (policy #f))
  (def callback (Fun Integer <- Integer))
  (def payload (Tuple callback UInt))
  (def cooked (Pair UInt callback))
  (def source-type (source-refine (.cc (RationalDict payload) Key: UInt)))
  (def target-type (target-refine (SimpleTrie UInt cooked)))
  (def keys (.cc Wrapper. Domain: UInt Codomain: UInt
    .ap: (cut bitwise-xor <> 1) .unap: (cut bitwise-xor <> 1)))
  (def values (.cc Wrapper. Domain: payload Codomain: cooked
    .ap: (lambda (v) (cons (vector-ref v 1) (vector-ref v 0)))
    .unap: (lambda (v) (vector (cdr v) (car v)))))
  ;; A supplied policy is an explicit fold origin, independent of representation.
  (def source-fold (table-fold source-type Integer
    (if policy (lambda (_ v) (* (.@ policy weight) (vector-ref v 1)))
      (lambda (_ v) (vector-ref v 1)))
    (if policy (list policy) [])))
  (.o source: source-type target: target-type folding: source-fold
    transport: (.call source-fold .isomorphism target-type keys values)
    state: (.call source-fold .ap (validate source-type (.call source-type .<-list rows)))))


;; Rational aliases share logical service ownership while negated keys and Pair
;; rows expose a different representation. Reuse the existing fold transport and
;; FUN actions; capacity ignores physical key spelling and retains checked calls.
(def (make-rational-capacity-ledger rows)
  (def callback (Fun Integer <- Integer))
  (def payload (Tuple UInt callback)) (def cooked (Pair UInt callback))
  (def source-type (RationalDict payload)) (def target-type (RationalDict cooked))
  (def key-map (.cc Wrapper. Domain: (.@ source-type Key) Codomain: (.@ target-type Key) .ap: - .unap: -))
  (def value-map (.cc Wrapper. Domain: payload Codomain: cooked
    .ap: (lambda (row) (cons (vector-ref row 0) (vector-ref row 1)))
    .unap: (lambda (row) (vector (car row) (cdr row)))))
  (def source-fold (table-fold source-type Integer (lambda (_ row) (vector-ref row 0))))
  (.o source: source-type target: target-type keys: key-map values: value-map folding: source-fold
    transport: (.call source-fold .isomorphism target-type key-map value-map)
    state: (.call source-fold .ap (validate source-type (.call source-type .<-list rows)))))

;; Stage an ordered revision batch once, then reuse the existing checked fold/FUN
;; continuation. A late conflict suppresses the consumer; retry supplies a fresh
;; source state and rediscovered deltas, without exposing an intermediate ledger.
(def (batch-ledger-action descriptor folding state consume)
  (.call Observation. .map (fold-ledger-action folding state consume)
    (cut .call descriptor .compose-deltas <>)))

 ;; Join one finite declared batch before IO, preserving existing later-source
;; priority and complete-root admission. The common Table boundary owns caller
;; cells; this Reader adds no validation wrapper or alternative merge algorithm.
(def (join-ledger-action descriptor consume)
  (using (consume :~ procedure?)
    (.call Observation. .map consume (cut .call descriptor .join/list <>))))

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

;; Derive receiver-bound pure/mutable collections over the same checked carrier.
;; The ordered batch must complete before conversion and Reader/IO observation;
;; failure exposes no staged receiver and never replays an external consumer.
(def (revise-ledger-receivers table base batch consume)
  (using (consume :~ procedure?)
    (def styles (table-styles table))
    (def posh (.call (.@ styles Posh) .ap base))
    (def classy (@@method posh.convert 'classy))
    (@@method classy.apply-batch batch)
    (def next (@@method classy.convert 'posh))
    ((.call Observation. .map consume (lambda (receiver) (@@method receiver.snapshot))) next)))

;; Select a correlated index range from one captured snapshot through FUN bind.
;; Checked service callbacks complete in index order before the outer IO consumer;
;; a query or callback refusal suppresses consume without replaying earlier effects.
(def (observe-indexed-receiver descriptor name lower upper argument consume)
  (using (consume :~ procedure?)
    (.call Observation. .map consume (lambda (receiver)
      (@@method receiver.bind (lambda (snapshot)
        (for/collect (entry (.call descriptor .index-range snapshot name lower upper))
          (def key (cdr entry))
          (def row (.call descriptor .ref snapshot key))
          (cons key ((vector-ref row 2) argument)))))))))

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

;; Route checked services in complete cohorts. The primary and every grouped
;; bucket use the SAME source Type, so final team membership must have even size.
;; Ordinary cache admission enforces that law; no separate approval engine is used.
(def (make-cohort-services)
  (def raw (RationalDict (Tuple UInt UInt (Fun Integer <- Integer))))
  (def source (.cc raw .element?: (lambda (root)
    (and (element? raw root) (even? (.call raw .count root))))))
  (def badge (.cc Type. name: 'badge table: (RationalDict (.@ source Key)) unique?: #t
    project: (lambda (_ row) (vector-ref row 0))))
  (def team (.cc Type. name: 'team table: (SimpleTrie UInt source) unique?: #f
    project: (lambda (_ row) (vector-ref row 1))))
  (def declarations (list badge team))
  (values (table-indexes source declarations) source declarations))

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
;; A caller may supply a refined source; deriving indexes/order does not demand
;; its partial empty constructor. Finite construction remains the admission boundary.
(def (make-ordered-services (source (RationalDict (Tuple Integer (Fun Integer <- Integer)))))
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
;; Choose the primary and index backend explicitly; the same declarations and
;; index initializer serve Trie and standard RBTree-backed rational key spaces.
(def (make-ordered-service-indexes
       (source (SimpleTrie UInt (Tuple UInt UInt (Fun Integer <- Integer))))
       (index-table (cut SimpleTrie UInt <>)) order-policy: (policy #f))
  ;; A policy selects one declared order at construction; its revision seals both
  ;; indexes. Positive order keeps the backend's exact procedure/equality pair.
  (def (ordered table)
    (def base (.@ table Comparer))
    (def comparer (if policy
      (let ((direction (.@ policy direction)) (compare (.@ base .procedure)))
        (unless (memv direction '(1 -1)) (error "service order direction must be 1 or -1"))
        (table-comparer (.@ table Key)
          (if (= direction 1) compare (lambda (a b) (- (compare a b))))
          (append (list base policy) (.@ base .sources)) equal?: (.@ base .equality))) base))
    (table-order table comparer))
  (def owners (index-table (.@ source Key)))
  (def groups (index-table source))
  (def priority (.cc Type. name: 'priority unique?: #t
    table: (ordered owners)
    project: (lambda (_ row) (vector-ref row 0))))
  (def team (.cc Type. name: 'team unique?: #f
    table: (ordered groups)
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

;; Prepare a whole declared index family before revising through the existing
;; linear FUN/IO action. Failed metadata preparation or installation reaches
;; neither the next phase nor the consumer; retry constructs a fresh family.
(def (publish-indexed-services source declarations before revise consume)
  (using ((revise :~ procedure?) (consume :~ procedure?))
    (def indexed (table-indexes source declarations))
    (revise-indexed-services indexed source (.call indexed .wrap before) revise
      (cut consume indexed <>))))

;; Define a complete approval cohort over the caller's existing Unit table. The
;; recognizer observes the backing table, never recursively calls its own count.
;; Every published set must contain whole cohorts; singletons may be inadmissible.
(def (make-cohort-access table (size 2))
  (using (size :~ (lambda (n) (and (exact-integer? n) (> n 0))))
    (.cc Set<-Table. Table: table sexp: 'cohort-access
      .element?: (lambda (root)
        (and (element? table root) (zero? (modulo (.call table .count root) size)))))))

;; Capture grants-then-revocations once using the existing finite set algebra.
;; The returned Reader action installs its ordinary Unit-valued table delta against
;; a supplied current snapshot. Conflict suppresses IO; retry explicitly re-captures
;; from the winner. Admitted Function keys are never normalized or replayed here.
(def (prepare-access-revision descriptor before grants revoked consume)
  (using (consume :~ procedure?)
    (def table (.@ descriptor Table))
    (def proposed (.call descriptor .diff (.call descriptor .union before grants) revoked))
    (def delta (.call table .diff before proposed))
    (.call Observation. .map consume (cut .call table .apply-delta <> delta))))

;; Compose element-level algebra and ownership transfer through the existing
;; Reader/FUN map. Intermediate owned states remain local; only the final posh
;; receiver reaches IO. Failure suppresses consume; retry starts from a fresh root.
(def (access-style-action descriptor grants revoked consume)
  (using (consume :~ procedure?)
    (.call Observation. .map consume (lambda (before)
      (def styles (set-styles descriptor))
      (def classy (.@ styles Classy))
      (def current (.call classy .ap before))
      (def additions (.call classy .ap grants))
      (def removals (.call classy .ap revoked))
      (@@method current.union additions)
      (@@method current.diff removals)
      (def linear (@@method current.convert 'linear))
      (.call (.@ styles Linear) .convert linear 'posh)))))

;; Route one admitted access snapshot into accepted/rejected receiver branches.
;; The classifier runs once per element; both branches finish admission before
;; linear retirement. Reader/FUN map invokes IO only after the pair is complete.
;; Predicate/refinement failure leaves the caller's persistent root for retry.
(def (partition-collection-action derive descriptor classify consume)
  (using ((classify :~ procedure?) (consume :~ procedure?))
    (.call Observation. .map (lambda (branches) (apply consume branches)) (lambda (before)
      (def protocol (.@ (derive descriptor) Linear))
      (def owner (.call protocol .ap before))
      (defvalues (accepted rejected) (.call protocol .partition classify owner))
      (list (.call protocol .list<- accepted) (.call protocol .list<- rejected))))))

;; Set policy predicates receive elements; the existing style factory owns arity.
(def (partition-access-action descriptor classify consume)
  (partition-collection-action set-styles descriptor classify consume))

;; Table policy predicates receive original keys and checked service rows. Both
;; correlated branches finish before Reader/FUN permits the IO consumer to run.
(def (partition-ledger-action descriptor classify consume)
  (partition-collection-action table-styles descriptor classify consume))

;; Compose the existing service lens with a guarded linear key focus. Lens.modify
;; delegates the entire user callback to one captured generation; Reader/FUN map
;; exposes only a completely admitted snapshot to IO. Refusal leaves base intact
;; so the caller can explicitly retry; consumer effects are never replayed here.
(def (revise-focused-ledger table base key transform consume optional?: (optional? #f))
  (using ((transform :~ procedure?) (consume :~ procedure?) (optional? :~ boolean?))
    (def protocol (.@ (table-styles table) Linear))
    (def state (.o ledger: (.call protocol .ap base) sibling: 'retained))
    ;; Select the existing required/optional capability; both share one commit.
    (def key-focus ((.ref protocol (if optional? '.lens/opt '.lens)) key))
    (def focus (.call Lens .compose (.lens ledger) key-focus))
    ((.call Observation. .map consume (lambda (service)
      (.call protocol .unap (.@ service ledger))))
      (.call Lens .modify focus transform state))))

;; Map the original ledger rows under one linear owner, then expose its complete
;; snapshot through Reader/FUN map. The supplied callback returns Option Value;
;; rejection suppresses IO and leaves the caller's persistent base for fresh retry.
;; New Function payloads are admitted before this action; retained ones stay exact.
(def (map-ledger-action table transform consume)
  (using ((transform :~ procedure?) (consume :~ procedure?))
    (.call Observation. .map consume (lambda (base)
      (def protocol (.@ (table-styles table) Linear))
      (def owner (.call protocol .ap base))
      (def next (.call protocol .filter-map/2 transform owner))
      (.call protocol .unap next)))))

;; Decompose an admitted ledger under explicit order using one linear transition.
;; Reader/FUN invokes IO only after both successor roots and the pivot observation
;; are ready. The caller retains its persistent base for explicit failure retry.
(def (split-ledger-action table pivot consume)
  (using (consume :~ procedure?)
    (.call Observation. .map (lambda (results) (apply consume results)) (lambda (base)
      (def protocol (.@ (table-styles table) Linear))
      (def owner (.call protocol .ap base))
      (defvalues (left found right) (.call protocol .split pivot owner))
      (list (.call protocol .unap left) found (.call protocol .unap right))))))

;; Reader/FUN combines two admitted ledgers before IO through one linear update.
;; The right owner is observed, never consumed. Failure exposes no staged root;
;; callers retain both persistent snapshots for an explicit fresh retry.
(def (merge-ledger-action table choose consume)
  (using ((choose :~ procedure?) (consume :~ procedure?))
    (.call Observation. .map consume (lambda (request)
      (def protocol (.@ (table-styles table) Linear))
      (def left (.call protocol .ap (car request)))
      (def right (.call protocol .ap (cdr request)))
      (.call protocol .unap (.call protocol .merge choose left right))))))


;; Read one snapshot-bound binding through the declared Gerbil Iterator, then
;; inspect its checked payload before the Reader/FUN map permits IO. Empty input
;; is #f; a present result is (some (key . result)), even when result is false.
;; Failure consumes no table owner; callers retry with a fresh cursor/request.
(def (observe-ledger-first descriptor inspect consume)
  (using ((inspect :~ procedure?) (consume :~ procedure?))
    (.call Observation. .map consume (lambda (state)
      (using ((cursor (.call descriptor .iter<- state) :- Iterator))
        (def entry (cursor.next!))
        (and (not (eq? entry #!eof))
          (some (cons (car entry) (inspect (car entry) (cdr entry))))))))))


;; Reuse the declared two-identifier/shared-team service family as a counted ledger.
;; A presentation function may compose existing order and representation views;
;; fold transfer still uses their complete constructor and atomic delta installer.
;; Admission happens once before the opaque state is handed to FUN/IO actions.
(def (make-service-ledger rows (present identity))
  (using (present :~ procedure?)
    (defvalues (indexed-type source-type recipes) (make-indexed-services))
    (def target-type (present indexed-type))
    (def source-fold (table-fold source-type Integer (lambda (_key _row) 1)))
    (def keys (.cc Wrapper. Domain: (.@ source-type Key) Codomain: (.@ target-type Key)
      .ap: identity .unap: identity))
    (def payloads (.cc Wrapper. Domain: (.@ source-type Value) Codomain: (.@ target-type Value)
      .ap: identity .unap: identity))
    (.o source: source-type target: target-type indexed: indexed-type declarations: recipes folding: source-fold
      transport: (.call source-fold .isomorphism target-type keys payloads)
      state: (.call source-fold .ap (validate source-type (.call source-type .<-list rows))))))

;; Observe one admitted source owner through its existing FUN protocol. Reader
;; invokes IO only after entry projection, collision checks and whole target/index
;; admission; failure leaves the original source owner available for fresh retry.
(def (map-ledger-into-action protocol target transform consume)
  (using ((transform :~ procedure?) (consume :~ procedure?))
    (.call Observation. .map consume (cut .call protocol .map/into target transform <>))))


;; Reader prepares one immutable projection revision; IO sees only its completely
;; admitted target. Callback/constraint refusal suppresses IO and preserves the
;; predecessor for retry. Consumers receive the new state after target consumption.
(def (revise-projected-ledger-action projection delta consume)
  (using (consume :~ procedure?)
    (.call Observation. .map
      (lambda (state) (consume (.call projection .get state)) state)
      (cut .call projection .apply-delta <> delta))))


;; Deliver the prepared target delta directly to the existing style installer.
;; Request fields are state/target; successful output retains state/target/delta.
;; Eager installation precedes the returned object and IO; precommit failure keeps
;; the predecessor reusable. IO failure after a commit does not roll it back.
(def (publish-projected-ledger-action projection delta protocol consume)
  (publish-collection-action
    (lambda (request receive) (.call projection .apply-delta (.@ request state) delta receive))
    protocol consume))

;; One shared Reader/FUN/IO boundary publishes exact prepared collection deltas.
;; Preparation may have one or several inputs; target ownership installs once.
(def (publish-collection-action prepare protocol consume)
  (using ((prepare :~ procedure?) (consume :~ procedure?))
    (.call Observation. .map
      (lambda (publication)
        (consume (.call protocol .unap (.@ publication target))) publication)
      (lambda (request)
        (prepare request (lambda (next output-delta)
          (def published (.call protocol .apply-delta (.@ request target) output-delta))
          (.o state: next target: published delta: output-delta)))))))

;; Jointly revise two source snapshots and deliver their maintained access set
;; through the same publication boundary. Refusal exposes neither source successor.
(def (publish-set-combination-action combination delta-left delta-right protocol consume)
  (publish-collection-action
    (lambda (request receive)
      (.call combination .apply-deltas (.@ request state) delta-left delta-right receive))
    protocol consume))


;; Revise source grants under its full Set contract, then publish only image
;; membership transitions. Shared owners retain their access region. The existing
;; Reader/FUN/IO delivery chain suppresses consumption on preparation/install
;; refusal; retry uses a fresh public owner and the unchanged image predecessor.
(def (publish-access-image-action image source grants revoked protocol consume)
  (lambda (request)
    (def before (.call image .unap (.@ request state)))
    (def after (.call source .diff (.call source .union before grants) revoked))
    (def delta (.call (.@ source Table) .diff before after))
    ((publish-projected-ledger-action image delta protocol consume) request)))


;; Compile an explicit immutable service-to-permission catalog into the existing
;; multikey image. Required catalog lookups reject unconfigured services; its
;; descriptor and declared origins invalidate reads and revisions together. The
;; shared publication action handles ownership, retry and Reader/FUN/IO delivery.
(def (make-service-permission-image services permissions catalog assignments)
  (unless (eq? (.@ services Elt) (.@ catalog Key))
    (error "incompatible service catalog keys"))
  (unless (element? catalog assignments) (raise-type-error catalog assignments))
  (set-image services permissions (lambda (service) (.call catalog .ref assignments service))
    (append (list catalog (.@ catalog Key) (.@ catalog Value))
      (if (.has? catalog .sources) (.@ catalog .sources) [])) multiple?: #t))


;; Summarize service capacities by the declared team, retaining original callback
;; leaves in the source. The shared projection publisher handles exact target
;; deltas, five ownership styles, conflict retry and Reader/FUN/IO consumption.
(def (make-team-capacity-fold source target)
  (table-group-fold source target Integer
    (lambda (_key row) (vector-ref row 0))
    (lambda (_key row) (vector-ref row 1))))


;; Route each service through its explicitly keyed shared policy. Missing policy
;; rows suppress routes; present policies preserve the admitted service callback.
;; Output keys come from policies, so existing projection claims reject collisions
;; and admit complete key swaps before the existing style publication boundary.
(def (make-service-routing-join services policies routes)
  (table-lookup-join services policies routes
    (lambda (_key row) (vector-ref row 0))
    (lambda (_key row policy)
      (and (some? policy) (some (cons (some-value policy) (vector-ref row 1)))))))

;; Publish a joint source revision through the same Reader/FUN/IO transaction as
;; unary projections and binary Set views. No new target installer is introduced.
(def (publish-join-action join delta-left delta-right protocol consume)
  (publish-collection-action
    (lambda (request receive)
      (.call join .apply-deltas (.@ request state) delta-left delta-right receive))
    protocol consume))


;; Expand each service onto enabled workers in its explicitly shared groups. Pair
;; identities keep placements distinct; admitted callbacks pass through unchanged.
;; Explicit multiple? allows cohort lists; sharing two cohorts places a service
;; once. The common publisher handles exact deltas and all five ownership styles.
(def (make-service-placement-join services workers placements groups pairs multiple?: (multiple? #f))
  (table-group-join services workers placements groups pairs
    (lambda (_key row) (vector-ref row 0))
    (lambda (_key row) (vector-ref row 0))
    (lambda (service-key service-row worker-key worker-row)
      (and (vector-ref worker-row 1)
        (some (cons (cons service-key worker-key) (vector-ref service-row 1)))))
    multiple?: multiple?))

;; Expand one service's declared route keys while retaining its checked callback.
;; Shared projection ownership rejects duplicate keys, prepares final-state swaps,
;; and lets publish-projected-ledger-action deliver the exact delta in any style.
(def (make-service-routes services routes)
  (table-projection services routes
    (lambda (_key row)
      (map (lambda (route) (cons route (vector-ref row 1))) (vector-ref row 0)))
    multiple?: #t))

;; Expand service routes once, then maintain per-cohort callback capacity totals.
;; Exact middle deltas drive grouped invalidation; the existing publisher commits
;; only the final summary, so downstream refusal leaves both old caches reusable.
(def (make-service-route-summary services routes summary)
  (table-projection-compose (make-service-routes services routes)
    (table-group-fold routes summary Integer
      (lambda (route _callback) (quotient route 10))
      (lambda (_route callback) (callback 0)))))

;; Shared Boolean policies gate service callbacks before per-cohort aggregation.
;; Both source deltas pass the existing joint join admission before downstream
;; maintenance; publish-join-action installs only the final summary in any style.
(def (make-service-policy-summary services policies routes summary)
  (table-projection-compose
    (table-lookup-join services policies routes
      (lambda (_key row) (vector-ref row 0))
      (lambda (key row policy)
        (and (some? policy) (eq? (some-value policy) #t)
          (some (cons key (vector-ref row 1))))))
    (table-group-fold routes summary Integer
      (lambda (key _callback) (quotient key 10))
      (lambda (_key callback) (callback 0)))))

;; A service contributes its checked callback capacity once to each declared
;; cohort. Repeated cohort tags do not multiply capacity; an empty tag list keeps
;; the service but contributes nowhere. Ordinary projection publication owns IO.
(def (make-service-membership-fold services summary)
  (table-group-fold services summary Integer
    (lambda (_key row) (vector-ref row 0))
    (lambda (_key row) ((vector-ref row 1) 0)) multiple?: #t))

;; Extract one service under a linear owner; Reader/FUN exposes the optional
;; binding and raw remainder to IO only after complete admission and one commit.
;; Failure preserves the caller's persistent input for explicit retry.
(def (decons-ledger-action table consume)
  (using (consume :~ procedure?)
    (.call Observation. .map (lambda (results) (apply consume results)) (lambda (base)
      (def protocol (.@ (table-styles table) Linear))
      (def owner (.call protocol .ap base))
      (defvalues (found rest) (.call protocol .decons/opt owner))
      (list found (.call protocol .unap rest))))))

;; Drain a completed service prefix through the existing linear style and Reader/IO
;; observation. The persistent input survives refusal; consume runs after admission.
(def (drop-ledger-action table count consume)
  (using (consume :~ procedure?)
    (.call Observation. .map consume (lambda (base)
      (def protocol (.@ (table-styles table) Linear))
      (.call protocol .unap (.call protocol .drop count (.call protocol .ap base)))))))

;; Resolve each service from checked defaults and enabled overrides. Source value
;; Types may differ; the selected admitted Function is retained without wrapping.
;; The existing binary publisher owns the exact delta and final FUN/IO installation.
(def (make-service-override-view defaults overrides services)
  (table-combination defaults overrides services
    (lambda (_key fallback override)
      (if (and override (vector-ref (some-value override) 0))
        (some (vector-ref (some-value override) 1)) fallback))))

;; Inspect a bounded ordered service stream through the existing Reader/FUN/IO
;; observation. Inspection failure suppresses consume; callbacks retain admitted
;; identities, and the caller decides how much of the lazy range to request.
(def (observe-ledger-range descriptor lower upper inspect consume)
  (using ((inspect :~ procedure?) (consume :~ procedure?))
    (.call Observation. .map consume (lambda (state)
      (inspect (.call descriptor .range<- state lower upper))))))

;; A named-index query is a thin presentation of the same bounded Reader/FUN/IO
;; inspection. The family owns lookup, backend iteration and every-pull guards;
;; neither a cache handle nor a parallel observation/publication flow is exposed.
(def (observe-indexed-range descriptor name lower upper inspect consume)
  (observe-ledger-range
    (.o .range<-: (cut .call descriptor .index-range<- <> name <> <>))
    lower upper inspect consume))

;; Divide one checked ledger through the existing linear style and Reader/FUN/IO
;; observation. Every part is admitted before the source owner retires or consume
;; runs. Empty division succeeds with no parts; application effects are not undone.
(def (divide-ledger-action descriptor consume)
  (using (consume :~ procedure?)
    (.call Observation. .map consume (lambda (base)
      (def protocol (.@ (table-styles descriptor) Linear))
      (map (cut .call protocol .unap <>)
        (.call protocol .divide/list (.call protocol .ap base)))))))

;; Search one admitted service snapshot through Reader/FUN/IO. Only a completed
;; optional observation reaches consume; predicate/admission failures suppress IO.
(def (find-ledger-action descriptor predicate consume)
  (using ((predicate :~ procedure?) (consume :~ procedure?))
    (.call Observation. .map consume
      (lambda (root) (.call descriptor .find-first/opt predicate root)))))

;; Supply a fresh finite input per attempt. Reader/FUN stages one linear import,
;; and IO receives only the admitted installed snapshot; stream failure suppresses IO.
(def (import-ledger-action descriptor consume)
  (using (consume :~ procedure?)
    (lambda (sequence)
      (.call Observation. .map consume (lambda (base)
        (def protocol (.@ (table-styles descriptor) Linear))
        (.call protocol .unap
          (.call protocol .<-iter sequence (.call protocol .ap base))))))))

;; Reader/FUN compares two admitted immutable snapshots before IO. The caller
;; supplies value order explicitly; failure suppresses consume and wraps no leaves.
(def (compare-ledger-action descriptor compare consume)
  (using ((compare :~ procedure?) (consume :~ procedure?))
    (.call Observation. .map consume (lambda (snapshots)
      (.call descriptor .compare compare (car snapshots) (cdr snapshots))))))

 ;; Compare two admitted snapshots, then linearly decompose the first one through
;; the existing Reader bind/map chain. One consumer sees the rank and both complete
;; successors; either stage's original refusal suppresses IO and preserves retry.
(def (reconcile-ledger-action table compare pivot consume)
  (using (consume :~ procedure?)
    (.call Observation. .bind (compare-ledger-action table compare identity)
      (lambda (rank)
        (.call Observation. .map
          (split-ledger-action table pivot (cut consume rank <> <> <>)) car)))))

;; Reader/FUN constructs the complete admitted ledger before IO; no Function leaf
;; is normalized again and a constructor failure suppresses the consumer. The same
;; entry accepts a raw descriptor or any existing Table/Set style factory.
(def (construct-ledger-action descriptor consume)
  (using (consume :~ procedure?)
    (.call Observation. .map consume (lambda (rows) (.call descriptor .<-list rows)))))

;; Reader/FUN commits one optional association before IO. Absence keeps the old
;; binding; a rejected request leaves its owner live for an explicit retry.
(def (associate-ledger-action protocol key response consume)
  (using (consume :~ procedure?)
    (.call Observation. .map consume
      (lambda (owner) (.call protocol .acons/opt key response owner)))))

;; Reader/FUN completes nonconsuming equality before IO. Both original snapshots
;; are admitted; comparator failures suppress consumption and remain retryable.
(def (equal-ledger-action descriptor consume)
  (using (consume :~ procedure?)
    (.call Observation. .map consume (lambda (roots)
      (.call descriptor .=? (car roots) (cdr roots))))))

;; Reader/FUN builds a fresh admitted collection from the declared JSON schema.
;; A codec/index refusal suppresses IO without consuming any existing owner.
(def (decode-ledger-action protocol consume)
  (using (consume :~ procedure?)
    (.call Observation. .map consume (lambda (wire) (.call protocol .<-json wire)))))

;; Reader/FUN observes one optional choice before IO. It never installs a root or
;; retires a linear owner; admission/backend refusal suppresses the consumer.
(def (choose-ledger-action protocol consume)
  (using (consume :~ procedure?)
    (.call Observation. .map consume (lambda (input) (.call protocol .choose/opt input)))))

;; Reader/FUN observes logical emptiness before IO without constructing an empty
;; business value, changing the ledger or retiring a linear owner.
(def (empty-ledger-action protocol consume)
  (using (consume :~ procedure?)
    (.call Observation. .map consume (lambda (input) (.call protocol .empty? input)))))

;; Reader/FUN normalizes a complete ledger and creates its requested ownership
;; presentation before IO. Refusal exposes no owner; retry is a fresh invocation.
(def (admit-ledger-action protocol consume)
  (using (consume :~ procedure?)
    (.call Observation. .map consume (lambda (input) (.call protocol .admit input)))))

;; Group service capacity by team under one explicitly declared revisioned policy.
;; Existing fold and FUN/IO publication reject old policy states before effects;
;; rebuilding after a supported policy change keeps admitted callback leaves intact.
(def (make-policy-capacity-fold source target policy)
  (table-group-fold source target Integer
    (lambda (_key row) (vector-ref row 0))
    (lambda (_key row) (* (.@ policy weight) (vector-ref row 1))) (list policy)))

;; Read one complete access cohort through its Set fold before publishing via IO.
;; Opaque accumulators and checked Function elements retain their identity; root
;; or callback refusal suppresses the consumer, with prior callback effects kept.
(def (fold-access-action descriptor step seed consume)
  (using ((step :~ procedure?) (consume :~ procedure?))
    (.call Observation. .map consume (cut .call descriptor .foldl step seed <>))))

;; Reader/FUN selects the declared singleton capability before IO publication.
;; Empty and batch policies stay independent; refusal runs no consumer, while
;; retry re-enters the same checked protocol without consuming an existing owner.
(def (singleton-ledger-action protocol consume)
  (using (consume :~ procedure?)
    (.call Observation. .map consume
      (lambda (entry) (.call protocol .singleton (car entry) (cdr entry))))))

;; Reader/FUN consumes one guarded grant snapshot before IO publication. A refused
;; Set, changed policy or late pull suppresses publication; retry issues a fresh
;; cursor. Admitted Function grants remain the original callable values.
(def (observe-access-action descriptor consume)
  (using (consume :~ procedure?)
    (.call Observation. .map consume (lambda (root)
      (for/collect (grant (.call descriptor .iter<- root)) grant)))))
