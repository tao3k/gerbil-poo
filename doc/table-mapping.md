# Checked bulk binding maps

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
Reader/FUN/IO publication boundary through `publish-lookup-join-action`. Source
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
