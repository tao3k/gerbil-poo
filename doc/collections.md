# Persistent table revisions

This is a concrete part of the proposed collection library in TODO.md, advancing
future work. It reuses `methods.table`, RationalDict's Gerbil `std/struct/rbtree`
backend, the existing Patricia trie, optional bindings and the ordinary Lens and
Reader/FUN protocols. It introduces no collection implementation or execution
engine. The original Racket construction's dictionary interfaces and Appendix B
getter/setter composition motivate the protocol; the delta API is an extension,
not a claim that the paper specifies this algorithm. The
[original proposal](https://github.com/fare/projects/issues/10) uses incremental
primarily for layered definitions of typeclasses/data structures and calls for
further automatic translations and symmetry-derived algorithms. This unit adds
one shared algorithm layer to existing table methods; finite data revisions do
not replace that broader goal.

## Complete supported unit

For finite, persistent tables with the **same Key and Value descriptors**:

* `.diff before after` produces an opaque finite delta. Updates and removals
  follow source traversal order, followed by target-only insertions in target
  order. No sorting or branch reordering is introduced.
* `.apply-delta current delta` compares each expected optional old value using
  the existing `.update/opt` structural `equal?` rule, then uses the backend's existing `.acons` or `.remove`. The first
  conflict raises `table-conflict`, whose key is available through
  `table-conflict-key`. No intermediate table is returned.
* `invert-table-delta` reverses edit order and swaps old/new bindings. With stable
  persistent values, applying it after success restores the old
  observations. Empty deltas return the original carrier by identity.
* Deltas move between RationalDict and SimpleTrie without converting their
  internal representation or enumerating bindings through `.for-each`. Matching logical key/value
  types and backend lookup/write laws are required. Physical shapes need not be
  isomorphic: preservation is stated in terms of every key's lookup result.
* `.lens/opt key` implements the existing Lens `.get`/`.set` convention. `#f`
  means missing, while `(some #f)` stores false. Compose it with `.lens ledger`
  using `Lens.compose` to update a ledger inside a service.

Snapshots passed to discovery and installation must already be admitted through
`validate` or `checked-action`. Discovery recognizes both tables without wrapping
again; application only admits the carrier shape and accesses changed bindings.
Deltas retain exact admitted values, including nested Function wrappers. Creating
one from raw, unwrapped procedures is not a substitute for recursive admission.
Children and callback state must remain stable while snapshots are retained.

`prepare-ledger-revision` in `examples/service-collection.ss` admits a new proposal
with `checked-action` before discovering changes. Full admission may create new
Function identities even in previously present entries. For identity-preserving
incremental use, validate new payloads individually, build the persistent proposal
from the admitted source, and call `.diff` directly. `apply-ledger-revision`
composes installation with an IO consumer through the existing Observation FUN
map; a conflict suppresses that consumer, and rediscovery permits retry.

## Failure and invalidation

A delta captures its original table descriptor, Key and Value revisions. Supported
writes to these descriptors invalidate it; applying to another carrier also
requires identical Key/Value descriptor identities. These descriptors and the
current carrier descriptor are protected by the existing construction guard during
recognition and installation. Callback exceptions preserve their original identity;
external side effects are not rolled back.

This is optimistic conflict detection at **changed keys**, not a global snapshot
or ABA fence. Unrelated concurrent edits can be rebased. A changed old binding
refuses; a binding changed away and back compares equal. Cross-thread atomic
publication remains the responsibility of the existing publication protocols.
The protocol neither caches approval nor grants authority to a retained delta.

## Cost and verification

Discovery scans both finite snapshots and retains only differing bindings.
Temporary Option wrappers and traversal objects still allocate.
It performs source lookups in target and target lookups in source. Application
performs one old-value lookup and one persistent write per accepted edit; the
empty case returns its source. Trie shape admission still recursively visits its
structure, whereas RationalDict carrier recognition is a record check. Thus total
installation is not claimed to be sublinear for every carrier. Carrier shape admission, descriptor preparation, metadata observation and
structural equality retain their own costs. No wall-clock or allocation improvement is
claimed. The regression backend that refuses enumeration/normalization during
application checks this sparse operational boundary.

`table-validation-test.ss` covers false versus missing, ordered insert/update/
delete, inverse installation, original persistence, different carriers, 48 rounds
against an independent alist oracle, late conflict, unrelated rebase, retry, nested
List/Tuple/Function wrappers, descriptor changes and composed service lenses.

The companion Lean `Functional/TableRevision.lean` proves finite discovery
completeness, sequence composition, first conflict refusal, inverse restoration,
frame preservation, all three optional lens laws and carrier transport preserving
both observations and error keys. Its `TableCarrier.read_write` premise exposes
the backend boundary. Equality is mathematical decidable equality, requiring the supplied
Scheme structural values to refine that observation model; Scheme
procedure identity can be represented by opaque handles, not extensional function
equality. The model does not prove Scheme structural equality, mutable leaves,
termination of supplied callbacks, the Gerbil tree implementation, concurrency,
allocation, GC or compiler correctness. The Lean example is top-level
`Examples/TableRevision.lean`; Scheme does not load or locate a Lean checkout.

## Explicit key/value isomorphisms

`table-isomorphism source target key value` lifts two existing `Wrapper.` objects
into a collection Wrapper. Each supplied Wrapper declares `Domain`, `Codomain`,
`.ap` and `.unap`; the descriptors must be identical to the corresponding table
Key/Value descriptors. No new conversion namespace or automatic inference is used.
The resulting `.ap` converts source to target, and `.unap` converts back. Sets use
their existing `Table` with the Unit value identity Wrapper.

`(.@ mapping Delta)` is another Wrapper. Its input and output are ordinary
`(base . delta)` pairs. It first installs the original delta against the supplied
admitted base. It then converts both snapshots through one typed key registry,
and translates edits in their original order, reading their expected/replacement
values from those converted snapshots. The paired base keeps Function wrappers
coherent with delta expectations; there is no global wrapper memo.
`transport-ledger-action` composes this operation, target installation and an IO
consumer through existing Observation/FUN maps. Every refusal suppresses the
consumer; rediscovering from the winning base permits a fresh attempt.

The contract is a pure, stable bijection **on admitted values**, respecting the
backend key equality and structural payload equality. Both inverses are supplied,
not inferred. Runtime checks recognize outputs and check encountered roundtrips;
they never recursively normalize admitted callbacks again. A converter must retain
admitted Function leaves (for example, Tuple-to-Pair reordering). Recognition of a
procedure alone cannot prove wrapping, and finite roundtrips cannot prove arbitrary
stateful or malicious callbacks safe. These are explicit premises in Lean.

A registry using the target backend rejects distinct source keys that alias under
its lookup equality. The registry spans **both** snapshots, including unchanged
keys and deleted/inserted aliases. A lawful key bijection is injective; a failing
runtime map raises `table-isomorphism-failure` with `collision`, `left-inverse` or
`right-inverse` and the offending key/value. Invalid result membership raises the
existing TypeError. Domain mismatch, stale conversion or stale delta metadata
raises the existing Gerbil Error. Source conflicts precede converter callbacks;
callback exceptions retain their identity. No partial carrier/delta is returned.
External callback side effects cannot be rolled back.

Converted deltas retain deduplicated origin and converter descriptor revisions;
inversion retains that lineage. Supported metadata changes invalidate both the
retained conversion and its produced deltas. Guards prevent supported metadata
writes during conversion. Mutable hidden state is outside that revision discipline.

Conversion scans the complete admitted snapshots and builds a private target
carrier plus key registry. Delta transport also performs the original installation;
it is not an O(edits)-only transformation and no speedup or GC claim is made.
Existing backends supply their own fold, equality, allocation and shape costs.

The companion Lean proofs add key/optional-value injectivity, view/edit roundtrips,
undo commutation, finite discovery commutation, write commutation and installation
commutation including the **first mapped conflict key**. The existing optional lens
laws continue to apply to the target view. Regressions cover canonical UInt/String
keys, Tuple/Pair values with shared checked Functions, forward/inverse deltas,
conflict/retry, consumer suppression, cross-history collision and metadata refusal.
The top-level Lean example models callback identities as opaque handles.

Automatically inferred isomorphisms and asymptotic backend optimization remain
outside this unit. The general library remains open
in TODO.md; explicit conversions advance the original proposal's future work.

## Delta-driven retractable folds

`table-fold descriptor aggregate project` reuses `Wrapper.` and the existing
`.zero`, `.add`, `.sub` arithmetic protocol. `aggregate` is an explicit Type
(including a Tuple with pointwise arithmetic); `project` maps admitted keys and
values to admitted contributions. No unrestricted descriptor or inferred inverse
is substituted for a missing algebra.

* `.ap admitted-table` initializes an opaque, owner-bound state containing the
  original table, folded value and metadata revisions.
* `.get state` observes the aggregate; `.unap state` recovers the retained table.
  Both reject foreign/stale states. Recovery uses the retained source, not an
  impossible inverse from a lossy sum alone.
* `.apply-delta state delta` first runs complete existing old-value, origin and
  carrier checks. Only after successful private installation does it retract each
  present old contribution with `.sub`, then add each present replacement with
  `.add`. It returns one new state containing both results. It does not refold
  unchanged bindings or revalidate/rewrap Function leaves.

Initialization scans recognition plus one fold. Accepted updates project at most
`2 * delta-count` bindings, with one arithmetic operation per present side. Empty
updates perform no projections but still check metadata/shape and retain the new
origin lineage in a fresh state. Application retains the existing backend shape,
lookup and persistent-write costs: Trie shape recognition may scan its structure.
Aggregate membership, arbitrary callbacks, equality, object preparation, revision
lineage, state allocation and GC have their own costs. Unique metadata dependencies
are deduplicated, not assumed constant across all future origins.

The semantic premise is the **optional-write fold law**. If `F` is the complete
fold, `w(k, none) = zero` and `w(k, some(v)) = project(k,v)`, then:

```
F(replace(view, k, after)) = F(view) - w(k, view(k)) + w(k, after)
```

Operations and admitted payloads must be pure/stable on successful paths. Exact
integer sums and pointwise count/sum metrics satisfy this law for a unique finite
inventory covering all updated keys. Arbitrary order-sensitive left folds,
floating-point sums and arbitrary predicates do not acquire that law by providing
methods with these names. Existing `.foldl/.foldr` remain available for them.

Inverting a successfully installed delta restores both original observations and
lawful aggregate values. A conflict or stale origin refuses **before project**.
Late project/arithmetic exceptions preserve their cause; bad aggregate membership
raises TypeError; supported metadata writes refuse through the construction guard.
No partial state escapes and the old state remains usable for retry. Hidden
mutable callback state and external effects cannot be rolled back or certified by
recognition. `fold-ledger-action` composes staging and the consumer through the
existing Observation/FUN map; consumer failure is not an atomic publication proof.

Retained states carry all accepted delta origins, including isomorphism metadata,
through inverse and empty updates. Supported changes invalidate subsequent `.get`,
`.unap` or update; create a fresh fold/state after changing the fold descriptors.
A fresh admitted winner can be initialized and a new delta discovered for retry.

For explicit key/value isomorphisms, initialize the target fold with the mapped
source once and use the existing paired-base `Delta` Wrapper for later revisions.
The target contribution pulls back through both inverse maps. Its aggregate then
agrees with the source fold, while converted deltas preserve Function handles and
first conflicts. Initial target folding and isomorphism delta conversion still scan
snapshots: the **complete conversion workflow is not O(delta-count)**.

Regression coverage includes 24 rounds on each RationalDict/Trie backend against
an independent complete sum, a backend refusing accidental fold enumeration during
updates, count/weighted-sum ledgers sharing checked Functions under UInt/String
and Tuple/Pair conversion, inverse recovery, late conflicts without project calls,
consumer suppression, late failures and retry, wrong result types, foreign states,
metadata guards, and converter lineage retained through empty updates.

The companion Lean `foldl_correct` proves the general optional-write law sufficient
for arbitrary accumulators. `foldView_replace` derives it for a complete finite
exact-integer fold; `foldChanges_correct` and `applyFold_correct` connect that oracle
to installation. Further proofs cover inverse recovery, full/sparse/isomorphic fold
commutation (including the mapped error key), and the `foldWork_bound` projection
bound. These are semantic and source-work bounds, not a Scheme compiler, allocator,
callback termination, GC or wall-clock proof. Automatically inferred algebras and
asymptotic backend optimization remain future work; Scheme requires no Lean files.

## Reusing aggregate states across representations

`(.call source-fold .isomorphism target key-wrapper value-wrapper)` derives a
Wrapper whose Domain is the source fold and Codomain is a target fold. The target
contribution is the source contribution pulled back through both supplied inverse
maps. The caller does not hand-write a second score and claim it equivalent.
The underlying `table-isomorphism` supplies the same descriptor/law checks.

* `.ap source-state` converts once and adopts its already admitted aggregate.
  Repeating the identical state returns the same target state, after freshness
  checks, without table enumeration, conversion or aggregate initialization.
  A different independently fresh state with the exact same immutable table root
  rebinds that representation and takes its aggregate/origins from the fresh input;
  empty updates therefore need no conversion either.
* `.unap target-state` returns the retained source state directly on a pairing hit.
  A valid target updated outside the bridge uses full inverse conversion plus
  key-ownership reconstruction, but still reuses the aggregate without refolding.
* `.apply-delta source-state delta` first completes the existing source fold update.
  A warm pairing then translates only changed keys and present replacement values,
  writes them persistently, and adopts the new source aggregate. The derived target
  fold is never initialized again and never reprojects unchanged or old values.
  Recover the new source with `.unap`, or apply an inverted source delta for undo.

The one-pair cache is private to that Wrapper. It holds two opaque fold states and
the current target-key-to-source-key registry, not a global or weak-key memo. Each
attempt starts from the immutable registry root. Deleted keys stay registered until
**all** edits pass union-domain collision checks, then their owners are removed.
Only complete success replaces the pairing. A late conversion, aggregate or backend
exception leaves the previous pairing intact; `fold-ledger-action` can consume this
same `.apply-delta` protocol, suppressing its consumer on failure and allowing retry.
`make-capacity-ledger` combines checked shared Functions, UInt key XOR, Tuple/Pair
layouts, optional-key lenses, FUN consumption and inverse recovery.

Invalidation is scoped. The source fold captures its own descriptor/aggregate;
a bridge and its target states additionally capture the conversion descriptors.
Changing an unrelated converter preserves the pairing. Changing this converter
rejects this bridge and dependent target states, including chained descendants;
it does not invalidate an independently retained original source aggregate.
Construct a fresh bridge to convert that source again without reinitializing it.
Incoming delta origins remain dependencies of new source and target states. A stale
cached pair cannot poison a different independently fresh input: it is replaced by
private materialization only after that attempt succeeds. Cold inverse fallback
retains incoming lineage. Same-root rebinding requires an independently fresh input
and unchanged converter/type captures; it does not make either old state fresh.
The successful memo is not an IO/approval cache. Consumer failure does not roll back
already completed memoization or external effects; its original source remains
available for retry.

The invariant is `target = map(source)` with equal lawful aggregates. Supplied maps,
operations, admitted leaves and backend equality must remain stable and satisfy the
existing inverse/fold/carrier laws. Metadata guards cover captured POO descriptors;
mutation hidden inside Scheme closures or raw mutable payloads is not detected or
proved safe. In particular, membership alone does not certify Function wrapping.
Target writes skip repeated carrier admission only on the privately established
paired path, not on arbitrary public snapshots.

### Costs and proof boundary

A cold miss still recognizes/converts the complete source and target snapshots and
builds their ownership registry. It performs zero target aggregate projections.
A hit performs metadata/state checks but no snapshot work. A warm edit path performs
at most two **source** projections per edit, no target projections, and key/value
conversion and persistent writes only for edited bindings. Existing source carrier
admission remains: Trie shape checks may still traverse the source. Metadata
preparation and lineage comparisons, aggregate recognition, finite roundtrip checks,
registry lookup/write, allocations and GC retain their costs. The registry is
bounded by the live key domain; retained metadata depends on distinct origins.
Cold inverse fallback may scan both the target representation and recovered keys.
This is not a claim that every operation or arbitrary backend is O(delta-count).

Lean `applyChanges_writeChanges` proves that successful source checking justifies
write-only replay. `transport_writeChanges` preserves the paired-view invariant;
`reuseFold_correct` equates reused execution with full target fold execution,
including the first mapped error. Inverse recovery reuses the prior bridge laws.
Selective invalidation reuses the existing table frame theorem for captured stamp
scopes, with a separate changed-stamp refusal theorem. `reuseFoldWork_bound` counts
source projections and zero target full scans on the paired path. These annotations
are source-work counts; they do not verify Scheme pointer identity, arbitrary
callback effects, backend allocation, GC, scheduler or compiler behavior. Runtime
regressions check identity, scanner refusal, shared Function wrappers, chained
invalidation, collisions, old-state retention and failure/retry.

### Fair paired study

Build through the existing `defbuild-script` target selection:

```
just build library
just _build-benchmark collection-paired-benchmark
# Run the emitted test binary under the existing 1 GiB / 300-second boundary.
gtimeout --signal=TERM --kill-after=3s 300s .build/package/bin/collection-paired-benchmark -:max-heap=1G,debug=q 64 3 6
```

The example uses the standard managed package output. If GERBIL_PATH is selected
explicitly when building, run its emitted binary instead; no loader override is
required. The same compiled workload can run as an ordinary Gerbil module,
using `gxc -O -d "$GERBIL_PATH/lib" t/collection-paired-benchmark.ss` followed by
`gerbil env gxi -e '(import :clan/poo/t/collection-paired-benchmark) (main "64" "10" "6")'`.
Keep the compiler's 90-second and runtime's 300-second watchdogs and `-:max-heap=1G,debug=q`
on both entry points. On Linux use the available `timeout` executable.
No Lean checkout or test-data JSON is used.

The study compares the prior source-update / full snapshot transport / target-fold
path with the paired path in the same process. Fresh fixtures per pair share
input size, admitted base, exact deltas, source contribution and result oracles.
Both variants execute the same fixed prefix. Alternating AB/BA pairs, baseline A/A
controls, natural and pre-collected GC regimes retain raw CPU, wall, GC and signed
allocation observations; allocation is attributable only on GC-free nonnegative
samples. Positive signed differences mean regression. No adverse row is dropped.

Cold measures fresh mapping/fold factory construction and materialization in an
already loaded, prefix-warmed runtime; it is not process cold start. Hit measures
repeated materialization. Revision includes forward and inverse transport; workflow
also includes delta discovery; retry includes an expected failed attempt and a
successful retry/undo. Warm phases declare their common setup outside measurement.
Raw observations are emitted to stdout and must remain outside Git; summaries do
not replace the semantic oracles or prove an end-to-end performance theorem.

### Local observation, 2026-10-22

Darwin arm64, Gerbil `1cfb032` / Gambit `ea114fc`, compiled module through the
standard package environment, 64 bindings, 10 operations per observation, six
balanced AB/BA pairs and four A/A pairs per phase/regime. Every result oracle
passed. Medians below are **candidate minus baseline per operation**, in ms;
negative is an improvement. GC samples are retained, not filtered out.

| Phase | Natural wall | Collected wall | Natural CPU | Collected CPU |
| --- | ---: | ---: | ---: | ---: |
| Factory/materialization | +5.211 | -9.090 | -0.376 | -0.101 |
| Repeated materialization | -26.603 | -4.197 | -2.802 | -2.665 |
| Revision and inverse | -11.026 | -16.342 | -4.450 | -4.281 |
| Discovery/revision/inverse workflow | -16.907 | -15.943 | -4.573 | -4.597 |
| Refusal/retry/inverse | -25.978 | -9.424 | -6.497 | -6.589 |

All warm AB/BA wall differences were negative in this run and the earlier
three-operation run. However, A/A wall medians span -35.359 to +32.829 ms and
individual controls span -63.285 to +60.017 ms. Factory differences cross zero;
**cold wall-time improvement is not established**, and the warm medians are local
observations rather than portable speedup guarantees. Eight of 200 observations
contained collections (all in the natural regime); per-phase median paired GC
CPU differences were zero. That does not establish a reduction in GC cost or
make signed allocation differences attributable on those rows.

The executable's first static compilation exceeded the unchanged 90-second
watchdog. Subsequent attempts also exposed closed output locks left by cancellation;
those failures remain failures. Only after checking that no process held the
locks were they removed. Static linking still exceeded that deadline, so this
study used successful bounded standard module compilation and execution, not the
old executable. These results do not certify cold executable-build performance.
An initial harness run refused before sampling because results were read before
the measurement loop; sequential `let` bindings fix that ordering. Both complete
reported runs use the corrected harness. Full observations and failure logs remain
outside Git.
