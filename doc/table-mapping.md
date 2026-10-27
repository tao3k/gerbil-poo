# Checked bulk binding maps

## Composed incremental views

`(table-projection-compose upstream downstream)` closes the explicit view chain.
The upstream `Value` must be the identical descriptor as downstream `Domain`;
representation conversion needs an explicit view. Middle/final values are tables;
the source can also be a captured Pair of table heads owned by a binary join.
Existing `table-projection`, `table-group-fold`, lookup/group joins and recursively composed views
share `.ap`, `.unap`, `.get`, `.sources` and continuation-bearing revision delivery.
The constructor requires exactly one upstream revision protocol. Unary chains
retain `.apply-delta state delta receive`; lookup/group-join chains retain
`.apply-deltas state left-delta right-delta receive`, including nested chains.
`.ap` takes the same input as upstream: a table root or `(cons left-root right-root)`.
Both source requests reach ONE existing joint admission before downstream work;
the composition never replaces it with sequential single-source installations.

Cold construction initializes each cache once. Warm revision delivers the exact
upstream output delta directly to the downstream cache, including zero-edit deltas
with origins. It never calls middle/target `.diff`, reconstructs a middle cache,
or normalizes Function leaves. Each stage still pays its original whole-root
recognition, registry, affected-bucket and backend installation costs. Sparse
callback counts do not establish a sublinear complete operation or a wall-time win.

Both declarations and their complete declared sources stay protected across the
chain. Foreign caches and descriptor mismatch refuse; source conflicts, stale
origins, projection/collision/refinement failures preserve their original causes.
Neither successor cache nor the final receive continuation is exposed unless
both stages accept. The old immutable state remains available for explicit retry.
Callback effects are not rolled back. Final public style installation is a distinct
existing commit boundary; refusal there returns no composed successor to the caller.

The returned exact final delta supports all five existing publication styles and
ordinary inverse target installation. Source inverses can drive the same chain to
recover observations under stable pure projections; no inverse projection is
invented. `make-service-route-summary` combines multivalued service expansion and
selective per-cohort aggregation; it uses the existing Reader/FUN/IO publisher.
`make-service-policy-summary` joins shared Boolean policy rows with service
callbacks before cohort aggregation. A valid left request and stale right request
cannot demand downstream callbacks; downstream refusal returns no chain successor.
Lookup and many-to-many group joins share this composition with no new index or
installation engine. Existing affected-group cross-products/refolds remain charged.

Regression tests cover nested chains, coalesced revisions, inherited no-op origins,
Function identity and call guards, descriptor invalidation, conflicts, collision,
retry, inverse recovery and all five styles. `TableProjection.lean` models the
shared delta-delivery kernel, proves both-success witnesses, connected middle
observations under faithful per-view laws, invariant preservation, refusal before
publication and the sum of the existing callback bounds. The same request type
can be a pair of deltas; no duplicate proof kernel is added for binary views.
Three-stage semantic reassociation preserves exact results and failure order;
runtime states still belong to their creating chain and cannot be interchanged.
Gerbil metadata guards,
callbacks, persistence and backend equality remain explicit implementation premises;
these laws do not prove the compiler or GC. This advances the collection proposal's
future work, not completion of the general collection library.

This closes a concrete collection TODO: `.map/2` was listed but absent from
`methods.table`, while Trie exposed only its carrier-specific traversal. The new
standard include `table/mapping.scm` stays inside `clan/poo/table`. This advances
the collection proposal's future work, reusing existing folds, writes, Option,
metadata guards, FUN/IO and declared Trie mapping, without a new tree or namespace.

## One key-preserving protocol

* `.map/2 transform input` calls `transform key value` once per ORIGINAL binding
  and retains that key with the returned admitted Value. False is a stored false
  when the Value descriptor accepts it.
* `.filter-map/2 transform input` accepts only `#f` (remove) or `(some value)`
  (retain/replace). `(some #f)` differs from removal. Invalid Option shells and
  incompatible values refuse with the existing Option/type failure conventions.
* Input and complete output are recognized without normalization. Original keys
  and retained Function leaves keep exact identities; new Function payloads must
  be admitted explicitly before being returned. There is no Any fallback.
* The callback order is the existing backend fold order. Traversal always uses
  the captured original root, never partially updated rows or reentrant additions.
  Required mapping preserves the domain; optional mapping can only shrink it.
* Whole-table refinements may refuse a well-typed result, including an empty one.
  Callback and recognition failure exposes no partial root; external effects are
  observable and are not rolled back. Supported edits to declared table/Type
  origins are blocked throughout traversal and admission.

Both methods are available through all five `table-styles` protocols and through
Gerbil receiver `map/2` / `filter-map/2`. They reuse one original `step`, so all
results and postconditions finish before a single head comparison/installation.
Pure/posh retain the predecessor, mutable/classy retain identity, and linear retires
it once, even for an identity mapping. Foreign/consumed owners and stale metadata
refuse under the same guards. A reentrant winner remains visible; an older mapped
snapshot cannot overwrite it. FUN `.map` still transforms one whole root: it is
not renamed or overloaded with a binding callback. On `set-styles`, these explicit
binding APIs operate on its backing Unit-valued map; they do not remap elements.

`map-ledger-action` composes optional mapping under a local linear owner with the
existing Reader/FUN map. Only a completely admitted result reaches IO. Failure
suppresses the consumer; retry uses the caller's unchanged persistent base. The
result remains an ordinary table, so existing delta discovery, inverse recovery,
indexes and representation wrappers need no separate mapping data format.

## Backend reuse and costs

A declared `.map/key/opt` capability uses the existing specialized traversal,
with checked callback outputs. Trie already supplies this left-to-right routine.
Otherwise the shared algorithm visits the original snapshot, captures only changed
optional bindings with the standard list builder, and installs one ordinary delta.
Correlated indexes therefore retract all old owners before inserting the final
ones: valid unique-value swaps do not fail on an intermediate point update.
Representation Wrappers conjugate visible key/value callbacks through their
existing conversions and delegate one source bulk operation, preserving this
final-state discipline. Both paths retain the
original root by identity when every result compares equal under the existing
`.update/opt` `equal?` convention. A specialized backend may nevertheless allocate
temporary nodes before detecting that no-op: identity is not zero allocation.

For n original bindings, the callback runs n times on success; the generic path
emits at most n primary changes, exactly one per changed optional binding. The
ordinary primary backend performs one write per accepted change; index retraction,
insertion and projection preparation, conversions and their equality checks are
additional costs, not included in that primary-write bound.
Full initial/final recognition and per-payload recognition remain charged. A
specialized backend rebuild has its own node/allocation cost; no changed-write or
host wall-time bound is claimed for it. Unexpected user/backend exceptions retain
their original cause. Pure lawful persistent backend operations, stable leaves,
correct declared traversal and terminating callbacks are explicit premises.

## Verification

Regression controls compare RationalDict and Trie against an independent 16-mask
oracle; check original callback order, no-op identity, both required and optional
semantics, all five styles, receiver calls, unchanged FUN mapping, late refusal,
refinement failure, foreign/stale owners and reentrant publication. Reused Option
shells cannot rewrite prior outputs; opaque Function keys and values stay exact.
Unique swaps and genuine collision/refusal are tested through both direct indexed
carriers and key-negating representations across all five styles, with synchronized
unique and grouped observations. An instrumented generic backend verifies zero
primary writes for no-op, one for one update
or deletion, and no callback on an empty input. Reader/IO retry and inverse delta
recovery complete the workflow. Full checking and resource bounds are unchanged.

`TableMapping.lean` proves stable pure filterMap/map agreement, identity for opaque
payloads, output length bound, no new keys, callback and whole-root failure before
installation, consumed/linear no-op behavior and stale-winner rejection. A conditional representation-transfer law aligns source and visible callback
results. Generic
changed-primary-write accounting is bounded by one decision per visited original binding.
These are finite semantic and conditional work laws, not compiler, allocation or
GC proofs. The service examples combine shared callbacks, capacity reservation,
row removal, late failure, explicit retry and a required-service postcondition.

## Explicit heterogeneous entry projection

`(.call source .map/into target project input)` accepts one target Pair per
original binding. `filter-map/into` accepts the existing Option protocol: `#f`
drops a row, while `(some (cons key #f))` retains a false target value. A present
non-Pair is a TypeError; a malformed Option retains the existing table refusal.
Both keys and values may change Type. No inverse or Any fallback is inferred.

The common entry boundary protects both descriptors and their declared origins,
admits the original source, then obtains the target's existing typed `.key-table`
capability. Missing/incompatible capability refuses before any project callback,
even on an empty input. Each original row is visited once in backend order. The
callback-owned Option/Pair shells are copied before child recognition; admitted
Function leaves stay identical. The target registry checks its own lookup equality
rather than host hashing/equal?. The first duplicate raises the existing
`table-index-conflict` with name `primary` and both source owners, before later
callbacks or target construction. A late callback failure retains its exact cause.

Only the complete row list reaches one target `.<-list` call, followed by whole
recognition. Business refinements, represented carriers and correlated indexes
therefore see the final target, without requiring an admitted empty or singleton
prefix. Cache uniqueness failures keep their existing index names. No partial
target is returned and IO is suppressed on any refusal. External callback effects
and mutations inside shared payload leaves are not rolled back.

All five source styles and the receiver methods expose the same projection as a
nonconsuming snapshot observation. The result is a raw target root; use the
existing target style `.ap` to choose its presentation. A cross-type result never
replaces a source owner. Reentrant source publications remain visible; observing
an earlier captured snapshot does not assert freshness for a later publication.
`map-ledger-into-action` composes the source FUN protocol with Reader/IO. The
worked service flow reorders Pair/Function fields into Tuple rows, changes the key
Type, builds unique badge/endpoint and shared-team indexes, retries after genuine
constraint refusal, and uses ordinary target deltas for revision/inverse recovery.
An inverse of those target edits is not an inverse of the general projection.

Lean `mapEntries` uses target logical key classes and standard Except/Sum/List
sequencing. It proves first callback/collision refusal, no duplicate published
keys, avoidance of prior keys, the output-length bound and correspondence with
the existing ordered `mapBindings` traversal, without equality on payloads.
`prepareEntryMap` proves source/projection/whole-target failure order and exact,
faithfully admitted publication. Existing `observeStyle` laws supply stale and
consumed-source refusal for the different target type. The backend registry must
implement these logical key classes; traversal, bulk construction, callback
termination, faithful recognizers and stable leaves remain premises. This does
not verify the Gerbil compiler, arbitrary predicate implication or wall time.

For n source bindings and m retained rows, a successful projection invokes n
callbacks and performs m target-registry lookups and insertions. It allocates a
finite row list and constructs the target once. Source/result recognition, child
checks, registry preparation, target/index construction, comparisons, converters,
allocation and GC are additional charged costs; no O(edits) or speedup is claimed.

## Incremental heterogeneous projection

`(table-projection source target project [origins])` derives an existing `Wrapper`
inside `clan/poo/table`. The callback returns `#f` or `(some (cons key value))`,
using exactly the checked entry boundary above. `.ap` prepares an immutable owned
state from a source root; `.unap` reads its source; `.get` reads its target;
`.apply-delta state delta` returns a new state. The predecessor remains reusable.
The factory requires both source and target typed `.key-table` capabilities before
any projection, even for empty inputs. Private source-key/output and target-key/owner
registries use their respective backend equalities. No global cache is introduced.

Cold preparation visits each original row once, saves admitted projected rows,
checks target-key uniqueness, and invokes one complete target constructor. Warm
preparation follows this order:

1. Check protocol/state ownership and every metadata stamp, including delta origins.
2. Apply the complete ordered source delta and recognize its final source root.
   Any intermediate expectation conflict or final source refusal precedes callbacks.
3. Deduplicate touched source keys by SOURCE equality, in first-touch order. Repeated
   writes in a composed batch demand only the final present value. Deleted keys
   invoke no callback. Untouched rows, including Function leaves, are not projected.
4. Retract all affected old target owners and ledger rows privately, before any
   new reservation. Thus two owners can swap output keys in one revision. An
   untouched owner's key still blocks an insertion; equal payloads do not waive it.
5. Project final present rows once, snapshot Option/Pair shells before recognition,
   reserve target keys using TARGET equality, and collect ordinary target edits.
6. Install one target delta (all retractions, then additions). Existing correlated
   index installation handles final unique swaps and grouped indexes. Recognize
   the complete target before returning the source/target/ledger/owners successor.

The first callback or collision failure retains its original cause/owner diagnostic
and suppresses later callbacks and target installation. A target index/refinement
failure exposes no successor. The original state remains available for a corrected
request; no snapshot cache is mutated. Empty deltas retain origins, so stale lineage
cannot be laundered by a no-op. Independent predecessor branches remain valid:
this persistent protocol does not invent a global publication generation or CAS.
Caller-selected target styles own later publication, as in ordinary `map/into`.

Stable key-local pure projection, immutable admitted leaves, source-key equivalence
invariance and persistent backend laws are explicit premises. Reading undeclared
mutable state is not safely incremental: declare its descriptor in `origins`, revise
it, and create a fresh protocol/state. Metadata edits during callbacks are blocked
by the existing guards. External effects/leaf mutations are not rolled back; the
same inter-thread descriptor serialization premise as the existing style API applies.
No automatic dependency discovery, inverse projection, callback equivalence test,
Function equality or destructive ownership inference is asserted.

`revise-projected-ledger-action` composes preparation with the existing Reader/FUN
observation and IO consumption. The service example migrates source Tuple rows to
different target keys and Tuple fields, swaps primary keys and unique badges and
endpoints, moves shared-team memberships, preserves untouched checked Functions,
rejects genuine primary/index conflicts, retries, and restores via source inverse
deltas plus target Linear style publication. Ordinary target styles remain distinct
from the immutable projection state. Thirty-two-round RationalDict/Trie controls
compare every incremental result with an independent full `filter-map/into` oracle;
composed repeated-key batches check one callback per final touched key.

### Laws and costs

`TableProjection.lean` proves selective-cache frame and full-recomputation
correspondence at every source key, reusing `applyChanges_frame` for inventory
coverage. `reserveProjection_unique` reuses the existing ordered entry collision
laws to exclude both new/new and new/untouched duplicates. Its retained-key list is
a logical view of the cached registry, not a new runtime full scan. Successful
source/callback/target admission, refusal-before-publication and immutable retry
laws model the same pipeline. Logical keys abstract each backend's equality classes;
faithful registries, traversals, constructors, recognizers and delta installation
remain explicit implementation premises. These are not compiler/runtime proofs.

For n source rows cold initialization demands n callbacks. Let d be the number of
ordered source edits, u their distinct source keys, r the number with cached old
outputs and a the number of retained new outputs. Warm preparation deduplicates d
edits, processes u source keys, demands at most u callbacks (zero for deleted keys),
and submits r+a target edits in ONE delta. It does not rerun target `.<-list` or
scan untouched rows for projection/difference discovery. It may still inspect them
through complete source/target recognition, backend index preparation or backend
operations. Registry preparation/lookups, source installation, full recognition,
comparisons, index work, allocations and GC remain charged. Touched keys whose net
source value cancels may be recomputed once; arbitrary Function equality is not
used to try to remove that work. No O(d) end-to-end or wall-time speedup is claimed.

## Delivering target deltas and publishing styles

`(.call projection .apply-delta state source-delta [receive])` now hands the exact
already-installed target delta to an optional standard continuation, AFTER complete
private source/cache/target admission. The continuation receives `(next output-delta)`;
omitting it returns `next`. Passing Gerbil `values` obtains both results directly:

```scheme
(defvalues (next output-delta)
  (.call projection .apply-delta before source-delta values))
(def published (.call target-style .apply-delta owner output-delta))
(def recovered (.call target-style .apply-delta published
  (invert-table-delta output-delta)))
```

The receiver is checked with the existing `using` procedure contract before any
projection work. A preparation refusal never calls it; a receiver exception retains
its original cause. The receiver runs under all captured metadata guards, including
inherited source-delta origins. The delta is the SAME opaque delta used for private
target installation, with the same ordered retractions/additions, typed children,
expectations and origins. Empty deltas retain origins. No new last-delta slot,
state-history chain, snapshot scan, `.diff`, normalization or change format is used.

The existing `publish-projected-ledger-action` example prepares a revision from a
request with `state` and `target` fields. Its continuation eagerly calls the existing
target style `.apply-delta`, then returns ordinary POO fields `state`, `target`,
`delta`. Only after that does the existing Reader/FUN observation invoke IO, on the
ACTUAL published root read from the target style. Tests construct request value
fields through `object<-alist`; `.o state: before target: owner` also works when the
lexical name differs from the field (a same-name lazy slot would self-reference).

Pure/posh retain the predecessor, mutable/classy preserve owner identity, and linear
retires the old owner only after success. Public target old-value conflicts, final
root/index refusal or generation races suppress the returned publication and IO.
The immutable projection predecessor remains available for a corrected request.
Late IO errors follow the ordinary FUN/IO semantics: an already committed target
and arbitrary external effects are not rolled back. A user-written receiver may
also expose prepared data or perform effects; it is not a general transaction.

Target installation intentionally retains the existing CHANGED-KEY rebase rule:
unrelated public rows are preserved, while a mismatched old value or an occupied
new key refuses. Thus the canonical `.get next` projection need not include every
unrelated row in the public target owner. Consumers of the public target use the
style's `.unap`; subsequent projection computation uses its own immutable cache.
The inverse of the delivered target delta recovers the actual public predecessor,
including its unrelated rows, when that restored root is admitted. This is explicit
target-edit inversion, not an inferred inverse of an arbitrary projection. Replay
of an empty delta may remain legal; it is not a one-shot publication credential.

Regressions cover all five styles, refusal/retry, new-key presence conflicts,
public-only whole-root refinement failure, unrelated-row rebasing/inverse recovery,
opaque receiver exceptions, stale empty origins and reentrant generation winners.
The indexed service workflow now publishes primary key, unique badge/endpoint and
shared-team swaps with preserved Function leaves, then recovers from the delivered
inverse. Target `.diff` is deliberately made unusable in the direct and service
controls; the direct control also refuses difference traversal and checks identity
of the exact installed/delivered delta. Existing single-process inventory and
compiler/runtime limits are unchanged.

`deliverProjection` / `publishProjectionDelivery` in `TableProjection.lean` prove
exact handoff, preparation/receiver refusal, ordinary state-only correspondence,
style-specific ownership, public changed-key conflicts, inverse/frame recovery and
existing generation rejection. They reuse `styleStep`, `applyChanges`,
`applyChanges_inverse`, `applyChanges_frame` and `installStyle_stale`. Opaque cache
payloads require no equality; explicit old-value equality/faithful carrier and
recognizer laws remain premises for target edit replay. Runtime concurrency, IO
rollback, compiler/GC behavior and arbitrary Function equality are not inferred.

Delivery adds no snapshot difference discovery, but private projection preparation
and PUBLIC style installation remain distinct admitted operations. Replaying the
delivered delta into a style may perform another backend/index preparation and
complete validation. Those costs, registry preparation, comparisons, allocation
and GC stay charged; removing `.diff` is not an end-to-end speedup claim.


## Two-source indexed lookup join

`(table-lookup-join Left Right Target classify project [origins])` returns the
existing Wrapper-shaped view: `.ap` accepts `(cons left-root right-root)`, `.unap`
returns a fresh Pair shell containing the two admitted heads, `.get` reads the
prepared target, and `.apply-deltas state left-delta right-delta [receive]` prepares
a successor. The default returns the successor; `values` receives both successor
and exact target delta. Left and right key Types may differ. `classify(key,row)`
must produce an admitted Right.Key, respecting the declared backend equalities.

This is an explicit many-to-one foreign-key lookup, not the existing same-key
left-biased `.join`. `project(left-key,left-row,right-option)` returns the existing
optional target entry. Missing right rows can suppress output (inner lookup), or
produce an explicit fallback (left lookup). A stored false is `(some #f)`, never
absence. A private typed Pair/Sum row reuses existing child recognition to preserve
this distinction without an Any fallback or a new public Option representation.
Already admitted Function leaves retain identity; no wire codec is inferred.

Existing `table-indexes` maintains the left-to-right dependency buckets. Existing
`table-projection` owns output claims, collision refusal, final-state key swaps,
complete target admission and ordered target delta delivery. There is no second
collision engine, target installer or dynamically shared right-hand context.
Cold construction captures the caller's Pair shell, admits both complete roots,
builds the dependency index and materializes the typed enriched source once.

Warm preparation installs/admit-checks the left source, then the right source,
before classification or projection. The existing index admission continuation
stages the right head before index maintenance, so each source delta installs once.
A source conflict/refinement refusal suppresses these later callbacks. The left-key
registry coalesces left edits and the old/final left buckets referencing edited
right keys. Each final present affected row is enriched/projected once; deleted
left rows have no output callback. Untouched dependency buckets are not enumerated.
No-op and transient edit histories remain ordered source checks; they may cause
conservative re-enrichment of dependents, but no transient right payload reaches
projection. Inherited origins from both sources remain live even with zero edits.

The exact ordinary output delta is the existing projection's removal/addition
trace, not a claim of a minimal edit list. It reaches the existing five-style
Reader/FUN/IO publication boundary through `publish-join-action`. Source
heads/indexes/projection caches stay private until preparation and public target
installation succeed. A late target conflict, refinement refusal, output collision
or callback exception exposes no successor; corrected retry uses the predecessor.
Explicit source inverses restore both joined observations; target inverses restore
the public target independently. This does not atomically consume two separately
owned public source objects or roll back external callback/postcommit IO effects.

`make-service-routing-join` in `examples/service-collection.ss` joins Function-bearing
services to shared routing policies. Tests cover selective shared-policy changes,
missing versus stored false, 24 mixed revisions against a full lookup oracle,
different left/right key Types, source admission order, Pair alias shells,
collision refusal and key swaps, whole-target refusal and callback exception retry,
metadata/foreign-state rejection, inherited origins, five styles and inverse
recovery while preserving exact callback identities.

Costs include cold source/index/enriched/target preparation and all complete
recognizers. Warm work includes both source installations, index maintenance,
changed-right dependency-bucket enumeration, the coalesced enriched edits,
projection claims and separate public target installation. Large shared buckets
can demand many left rows, repeated right edits can repeat bucket enumeration,
and origin/recognition/backend/GC costs are not constant-time claims. Classification,
projection, backend observations and stored leaves must obey the existing stable,
pure, persistent discipline; metadata mutation retains existing serialization rules.
This advances the collection proposal's future work. Automatic query/foreign-key
and inverse discovery remain research boundaries. Finite many-to-many expansion
and destructive backend integration are separate implementation units;
compiler/runtime correctness is outside this model.

Companion finite `TableProjection` laws prove left-key preservation, precise right
presence, affected-row framing, selective enriched repair, reuse of complete
projection-cache refresh, ordered paired admission and joint source inverse
recovery. Logical keys denote backend equality classes and source frame/affected
inventory laws are premises. Top-level `Examples/ServiceCollection.lean` gives
shared false policies, selective updates, deletion/insertion and inverse controls.

## Finite many-to-many grouped expansion

This explicit library unit advances the collection-library future work.

`(table-group-join Left Right Target Groups Pairs classify-left classify-right project [origins] multiple?: #f)`
uses the existing two-source `.ap` / `.unap` / `.get` / `.apply-deltas` protocol.
`Groups` declares logical group-key equality through its `.key-table` capability.
`Pairs.Key` must declare `(Pair Left.Key Right.Key)` with the exact component Types;
its backend must implement faithful componentwise pair equality. Its original
Value is unused: the existing key-space derivation supplies typed joined rows.
No hash encoding, equality coercion, query inference or untyped fallback is added.

Each classifier returns one group key. Every finite matching left/right row pair
has identity `(left-key . right-key)`, independently of equal payloads or groups.
`project(left-key,left-row,right-key,right-row)` returns `#f` or
`some(target-key . target-value)`. Thus a group with m left and n right rows can
produce m*n independently owned outputs. Distinct pairs targeting the same logical
key are refused by the existing projection claim protocol, including equal-valued
outputs. Dropping a pair does not accidentally retract another pair's output.

Cold preparation admits both complete source roots before either classification,
constructs two ordinary grouped indexes, then projects the finite matched pairs.
Warm preparation installs each ordered source delta exactly once and admits both
complete roots before index classifiers run. It enumerates old and final matching
buckets for edited endpoints on both sides, coalesces pair identities using the
explicit pair backend, and refreshes only final present pairs. Deletions require no
projection callback. Both old and new buckets are necessary for simultaneous
migration, insertion and removal. Untouched groups retain their cached projection.
A repeated/no-op edit can conservatively refresh surviving pairs; minimal-delta
or zero-classification claims are not made.

The existing projection performs all reservations, final target admission and
exact delta delivery. `publish-join-action` is the common Reader/FUN/IO publisher
for grouped and lookup joins; it installs the delivered delta directly into any
of the five existing styles. No target `.diff`, extra Function wrapper or second
collision engine is involved. Source conflicts, whole-root refusal, output
collisions and callback exceptions expose no successor and leave the immutable
predecessor available for corrected retry. A public target conflict suppresses
consumption and permits retry with a fresh owner. Callback effects and postcommit
IO are not rolled back. Metadata origins, including zero-edit origins, remain
live; incompatible states and stale observations are rejected.

`make-service-placement-join` demonstrates shared service/worker groups,
heterogeneous UInt/Symbol keys, enabled-worker filtering, retained checked
Functions and common five-style publication. Regressions include a 36-revision
independent Cartesian-list oracle, bidirectional migration, source deletions,
selective callback counts, cold/warm collisions, complete-source admission order,
original exception identity, failed-publication retry, source/target inverse
recovery, metadata invalidation and unchanged callback identity.

The finite Lean `groupJoinView`/`groupJoinAffected` laws prove missing-endpoint
behavior, live-pair inventory coverage, the unchanged-pair frame, selective-cache
agreement with full recomputation, source inverse recovery and a finite inventory
bound. They reuse the existing projection collision, preparation and style
publication laws. Premises include stable pure classifiers/projections, faithful
backend group/pair equality, complete old/final bucket inventories and persistent
atomic installers. They do not verify Gerbil code generation, runtime GC, callback
purity or a particular backend's equality implementation.

Costs include both index constructions, finite matched-pair materialization,
metadata preparation and complete recognizers. Warm work includes source/index
installation, old/final bucket enumeration, pair-key deduplication, final pair
lookups, affected projection/target preparation and public style installation.
Large matching groups necessarily expand quadratically; old/final overlap still
has enumeration and deduplication cost. Validation may scan complete snapshots.
The projection-call bound is not a wall-clock, allocation or GC bound. Arbitrary
multi-stage query optimization and automatic inverse discovery remain research
boundaries; this explicit finite equijoin is an implemented collection protocol.

The standard shared-library and executable consumer builds declare Gambit's
supported `___SINGLE_HOST_LIMIT`: generated C procedures above 10,000 labels use Gambit's
multiple-host representation. This avoids one oversized GCC optimization graph;
`std/make` still owns dependency scheduling and object caching. Stage deadlines,
heap limits and the complete tests remain unchanged. This build choice is not
a proof or a claim of faster collection calls; host/compiler behavior remains
outside the finite Lean laws.
Executable consumers pass the same option explicitly because dependency gsc
options are not inherited by their static-object preparation. The standard
consumer still owns object preparation; the complete linked test program checks
this path separately from the shared-library regression run.

## Finite multivalued projection

`(table-projection Source Target expand origins multiple?: #t)` generalizes the
existing optional entry protocol to a **finite proper list** of target entries
per source row. `expand key value` returns `((target-key . target-value) ...)`;
an empty list contributes no bindings. The default optional mode is unchanged.
This supplies one-to-many configuration/rule expansion without a fabricated
second join input. It advances the collection proposal's future work.

The shared projection implementation retains one finite list per contributing
source owner. Both modes use the same owner registry, metadata guards, target
constructor, delta installer and publication continuation. There is no second
validator or style wrapper. Standard `using`, `list?`, `map`, `for-each` and the
existing list builder supply finite admission and traversal. All caller-owned
list/pair shells are copied before child recognition; admitted Function leaves
are retained exactly, rather than normalized or wrapped again.

Every duplicate logical target key refuses with `table-index-conflict`, including
two outputs of the SAME source row and equal-valued duplicates. Backend equality
remains authoritative. This is distinct from Set image's deliberate deduplication.
Warm updates admit every ordered source expectation and the complete final source
before calling expansion. They coalesce source keys, retract ALL affected old
outputs, then expand only final present source rows once. This admits final-state
key swaps, skips deleted rows and leaves unrelated owners' output lists intact.
Only the complete target must satisfy its business refinement and indexes.

`.apply-delta state delta values` delivers the exact target delta with the new
state; `publish-projected-ledger-action` already publishes it through Pure,
Mutable, Linear, Posh and Classy without a target `.diff`. Input conflicts, malformed
lists/entries, callback exceptions, duplicate claims and final target refusal
expose no successor and suppress precommit consumers. Immutable predecessors can
be retried. Inverting the source delta recomputes the original expansion; inverting
the delivered target delta restores the published target. Projection itself need
not be invertible. Postcommit IO and callback effects are not rolled back.

`make-service-routes` expands each service's explicit route list with one shared
checked Function. Regressions cover all five publication styles, old/new key swaps,
empty/removed owners, coalesced multi-round edits, exact delivery/undo, late refusal,
unchanged predecessor retry, stored false, malformed lists, shell mutation and
metadata invalidation. `TableProjection.lean` reuses the existing selective cache
and reservation kernels to prove packet preservation, full-refresh correspondence,
untouched-owner framing, collision freedom and inverse recovery. Finite inventories,
faithful backend equality, stable pure callbacks, immutable leaves and lawful
persistent installers remain premises. No host compiler or GC proof is asserted.

Cost: one expansion call per final present touched owner, plus traversing/copying
its output list; releasing old outputs, key-registry operations, target writes,
metadata preparation and complete source/target recognition remain charged. An
owner can emit arbitrarily many finite entries, so output work is NOT bounded by
source count alone. Cold preparation visits the entire source and every emitted
entry. The protocol does not discover expansion rules or a query optimizer.

### Multivalued grouped joins

`table-group-join` accepts `multiple?: #t` for both classifiers. Each returns a
finite proper list of admitted group keys. Default classifiers still return one
group key, including a list-valued key. A pair exists exactly when both rows are
present and share at least one group; empty memberships contribute no pairs.
Repeated tags or several shared groups never multiply its projection.

Both existing grouped indexes own membership admission and invalidation. Cold
multivalued construction uses the existing pair-key backend to coalesce witnesses
before projection; ordinary single-group construction skips that registry work.
Warm repair reuses the old/final edited-endpoint inventory and pair registry.
Finding a match in one bucket is not undone by absence in a later bucket. The
same projection cache still owns target-key collisions, exact delivered deltas,
callback identity and all five styles of atomic publication.
Delivery retains the existing old-owner retraction followed by final insertion;
an exact replayable delta is not promised to be a minimal edit list.

`make-service-placement-join` exposes the same option. The integrated example
places checked service Functions onto workers with overlapping cohort lists,
migrates both sides, retains surviving associations and publishes through FUN/IO.
Independent Cartesian oracles cover Trie/RationalDict, mixed insertion/deletion,
empty memberships, duplicate tags and inverse recovery. Other regressions cover
malformed lists, stale expectations before projection, downstream collision,
explicit corrected retry, origins and ordinary list-valued keys.

Costs include complete source/index recognition, finite membership admission and
spine ownership, every encountered matching bucket, logical pair deduplication,
projection and target installation. Shared groups can repeat bucket visits even
though they do not repeat a user projection; dense relations can produce a
Cartesian number of pairs. No sublinear backend, wall-clock or GC bound is claimed.
Classifiers, keys and callbacks must be stable/pure, logical group and pair
equality must agree with their backends, and roots must be persistent. Callback
effects before refusal are not rolled back.

Lean's existing TableProjection namespace now shares a row-local relation model
and frame/inverse laws between ordinary equality joins and finite-membership joins.
It proves duplicate-witness invariance, singleton correspondence, preservation of
any shared cohort and full-refresh equivalence under the complete old/final
affected-pair inventory premise. Existing reservation/delivery/publication laws
remain the collision and failure boundary; host recognizers, mutable leaves and
compiler/GC correctness are not proved.

Design reflection: no new public engine, cache state, namespace or publication
wrapper was added. The finite multiplicity option follows the existing index and
projection interfaces; membership validation is shared rather than stacked on
individual operations. This closes an explicit association-composition unit of
the proposed collection library's future work, not automatic relation discovery.

### Incremental value-table combination

`(table-combination Left Right Target choose [origins])` maintains a key-preserving
merge of two persistent tables. All three Key descriptors must be identical and
their backend logical equalities coherent; Value descriptors may differ.
`choose key left-option right-option` returns an admitted target Option, without
normalizing Function leaves. Both absent bypasses choose and removes the result.
Stored false is present. Resolution must be stable and key-local; external callback
dependencies belong in explicit origins.

Cold preparation admits both roots, enumerates their union through the target's
key registry and resolves each logical key once. Warm revision installs both
guarded source deltas before resolving any key, coalesces their touched keys,
and skips target writes when the selected optional value is unchanged. Source
conflict, malformed response, target refinement or arbitrary resolver failure
exposes no successor and does not call the consumer. The original persistent cache
remains available for corrected explicit retry. Effects inside callbacks are not
rolled back. No target snapshot scan or .diff is used to deliver the exact delta.

The implementation generalizes the existing set-combination engine rather than
adding another installer. Set/Elt refinements and invalidation retain their own
admission boundary; Unit-valued algebra now uses the same private state, key
registry, conflict checks and update loop. Wrapper, view composition and the
existing binary FUN/IO publisher preserve all five ownership styles. The service
override example merges checked default Functions with enabled typed override
records, then publishes their exact retained Function identities. Another example
feeds merged values directly into grouped aggregation.

Regressions cover heterogeneous values, all styles, independent full-merge
oracles on Trie/RationalDict, simultaneous edits, deletion of the final owner,
zero/no-op writes, stale source conflicts, malformed Options, original exception
identity, refinement refusal/retry, origin invalidation and inverse recovery.
Lean's TableProjection laws reuse the existing selective repair and delta
operators: union-domain absence, two-source frame, complete sparse repair, exact
target delta, coalesced inventories and source inverse recovery. SetAlgebra proves
that the shared resolver specializes exactly to all four Unit-valued operations. Faithful
recognizers/equality, finite inventories, pure callbacks and persistent backend
laws remain premises; compiler/GC and arbitrary mutation are not proved.

Design reflection: this is the missing value-carrying counterpart of snapshot
.merge and incremental Set algebra. One shared engine replaces the Set-specific
copy; there is no new namespace, per-operation wrapper stack or compatibility
path. Cold union enumeration, complete admission, metadata preparation and target
installation remain costs. Warm resolver count is bounded by distinct edited
keys, but complete backend/admission work is still charged; no wall-clock speedup
or generally sublinear workflow is asserted. Automatic resolver/dependency
discovery remains research work within the proposed collection library.


### Captured cached-output retirement

Incremental projections retain a ledger response before backend eviction can
reuse its Option shell. The already owned cached rows supply all original target
deletions before any new reservation. This closes single/multiple output maps,
composed exact delta delivery and all five publication styles without snapshot
`.diff`, repeated callback execution or a second row-wrapper layer. The integrated
reroute-service-action captures a finite route request and preserves the service
Function through the existing FUN/IO publisher. Refusal/retry and inverse recovery
remain ordinary persistent-delta operations. See the composition audit for the
six original counterexamples, finite laws, stable-row premise and charged costs.
