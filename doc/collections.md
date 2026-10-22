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

Build and run through the existing standard package targets:

```
just benchmark-collections 64 10 6
```

`defbuild-script` prepares the library and existing `test-program` executable.
That executable statically links the shared library roots once, checks the complete
123-module inventory, and uses Gerbil's `load-module` to run the compiled collection
workload. The collection target is an ordinary module specification, so repeated
studies do not compile/link another copy of the shared C closure. The dispatch
inventory is fixed; arbitrary module names and symbols are refused.

The existing shared-executable construction still belongs to preparation and keeps
its original 300-second stage bound. It is not a new 90-second cold-build claim.
The workload compiler retains 90 seconds, execution retains 300 seconds, and both
retain the existing 1 GiB heap bound. Standard GERBIL_PATH/defbuild-script own the
outputs; no loader-path override, custom artifact cache or Lean checkout is used.
The complete one-process test suite remains unchanged. CI runs all study phases
as an additional smoke check after the full suite. The linked program starts
directly rather than starting another Gerbil tools VM around it. It uses the
standard GERBIL_HOME from release activation; when absent, Just asks the installed
compiler `(gerbil-home)` under a bounded query. No installation path is baked in.

The study compares the prior source-update / full snapshot transport / target-fold
path with the paired path in the same process. Fresh fixtures per pair share
input size, admitted base, exact deltas, source contribution and result oracles.
Both variants execute the same fixed prefix. Alternating AB/BA pairs, baseline A/A
controls, natural and pre-collected GC regimes retain raw CPU, wall, GC and signed
allocation observations; allocation is attributable only on GC-free nonnegative
samples. Positive signed differences mean regression. No adverse row is dropped.

Factory isolates metadata/closure construction and checks the resulting protocols
without materializing a snapshot. Cold measures fresh mapping/fold factory construction and materialization in an
already loaded, prefix-warmed runtime; it is not process cold start. Hit measures
repeated materialization. Revision includes forward and inverse transport; workflow
also includes delta discovery; retry includes an expected failed attempt and a
successful retry/undo. Warm phases declare their common setup outside measurement.
Raw observations are emitted to stdout and must remain outside Git; summaries do
not replace the semantic oracles or prove an end-to-end performance theorem.

### Earlier local observation, 2026-10-22

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

### Shared direction preparation

Ordinary isomorphisms and fold derivations now call the same private direction
preparer. It performs exact Domain/Codomain matching, checks all four callbacks
with Gerbil `using`, and holds the union of the relevant descriptor scopes. Fold
derivation no longer constructs a private ordinary transport Wrapper, its unused
Delta Wrapper, a duplicate forward direction, or that private transport's revision
capture. The original source fold and derived fold guards remain in place.
Cold inverse recovery uses the already checked backward direction and the same
existing translator, under the bridge's complete dependency guard.

This removes confirmed preparation/construction work. It does not equate a noisy
wall-time difference with the cost of one descriptor lookup. The factory phase
isolates combined metadata/closure work; the cold phase also includes conversion
and materialization, and GC statistics remain separate in every measured pair.
The previous +5.211 ms cold natural median had much larger A/A variation and no
median GC difference, so it did not establish a stable GC-driven regression.

Lean `stampMatches_append` and `stampMatches_dedup` preserve the complete dependency
predicate under scope union/deduplication. `prepareStamped_fuse` proves that fused
preparation has exactly the same success or uniform refusal as nested preparation
on one stable stamp snapshot. Arbitrary callback exceptions, compiler cache validity,
linker behavior, allocation and GC remain outside that theorem. Regression checks
cover malformed callbacks in every direction, no callback invocation at construction,
existing stale-reference refusal and the original full collection protocol.

The first full-suite attempt in this revision reported 123 module successes but
exceeded the outer deadline after the harness OK marker (exit 137). It is a failed
process-level acceptance, despite the harness OK marker; it remains recorded
outside Git. A direct start without release home also correctly refused missing
tool modules. The final direct route supplies only the compiler-discovered standard
home and retains the original heap/deadline and complete inventory.

### Prior-core shared-runtime paired observation, 2026-10-22

This observation precedes the `096da65` weak-identity merge and uses the preceding
`4a39774` core plus this contribution. It is not acceptance for the later core.
The same Darwin/Gerbil/Gambit release ran 64 bindings, 10 operations, six balanced
AB/BA and four A/A pairs in each regime, now including the separate factory phase.
All 240 observations and all result/refusal/undo oracles completed. The runtime
is the standard linked program, so these are within-run comparisons; the earlier
gxi-module run is not a matched before/after runtime comparison.

Median candidate-minus-baseline differences per operation:

| Phase | Natural wall ms | Collected wall ms | Natural CPU ms | Collected CPU ms |
| --- | ---: | ---: | ---: | ---: |
| Factory metadata/closures | -0.122 | -0.018 | -0.028 | -0.005 |
| Cold materialization | -0.870 | +0.085 | -0.338 | -0.397 |
| Repeated materialization | -7.349 | -22.280 | -3.120 | -3.232 |
| Revision/inverse | -12.279 | -30.155 | -4.699 | -4.999 |
| Discovery/revision/inverse | -29.995 | -43.987 | -4.396 | -5.286 |
| Refusal/retry/inverse | -23.213 | -30.515 | -7.591 | -7.435 |

Cold natural/collected A/A wall medians were +3.834/+1.537 ms, and AB/BA ranges
were -9.104..+4.870 / -12.152..+17.358 ms. Factory collected pairs ranged -0.414..+14.734 ms as well. Cold improvement remains unresolved
against that noise; +0.085 ms is retained rather than declared away. Cold median
paired GC CPU differences were +0.004/-0.025 ms, versus the CPU differences above;
these samples do not establish a GC explanation for the earlier +5.211 ms.
The complete natural workflow also retained a +5.165 ms adverse pair. No adverse
sample or collection was removed, and arbitrary allocation/GC speedup is not proved.

After the already required shared binary was built, first module compilation
completed in 41.30 s (9.95 user/1.31 system CPU), with two ordinary compile jobs
and no link job. An unchanged repeat completed in 26.21 s (6.23/0.75 CPU), with
zero compile/link jobs. Metadata/startup/freshness still cost time on the repeat;
cache reuse is not an instant-build claim. The shared executable itself took
192.89 s inside its unchanged 300-second stage. Avoiding its duplicate link does
not erase that preparation cost or prove a fresh standalone executable links in
90 seconds. The existing static roots remain linked and checked in the runtime.

Final full-suite acceptance used the same direct Just entry, 123/123 modules,
heap/deadline unchanged, exit 0; harness wall 147.23 s, CPU 35.90 s, GC CPU 3.82 s.
Another direct attempt had reached the harness OK marker but timed out (124),
and remains a failed attempt. Read-only process sampling in the accepted run
reported peak footprint about 607M; the clock variation and that sample do not
prove the cause of the earlier timeouts. Power logs did not show system sleep
in those attempts. No other tasks were stopped, and no resource limit was raised.


### Integrated-core verification, 2026-10-22

The same contribution was rebased onto `096da65`, preserving the merged weak
identity backends, and the complete build, single-process inventory and paired
study were repeated. This section supersedes the prior-core observation for
current acceptance. Width 64, ten operations, six balanced AB/BA pairs and four
A/A pairs per phase/regime completed all 240 observations and 24 summaries.
Every result, refusal, inverse and retry oracle passed.

Median candidate-minus-baseline differences per operation:

| Phase | Natural wall ms | Collected wall ms | Natural CPU ms | Collected CPU ms |
| --- | ---: | ---: | ---: | ---: |
| Factory metadata/closures | +0.005 | -0.002 | +0.005 | -0.001 |
| Cold materialization | +0.198 | -1.692 | -0.363 | -0.401 |
| Repeated materialization | -14.692 | -8.811 | -2.946 | -3.186 |
| Revision/inverse | -16.515 | -20.053 | -4.300 | -5.183 |
| Discovery/revision/inverse | -13.239 | -16.703 | -4.418 | -4.730 |
| Refusal/retry/inverse | -33.706 | -39.810 | -7.553 | -7.325 |

Cold natural/collected A/A wall medians were +2.649/-1.517 ms. AB/BA ranges
were -3.466..+23.451 / -13.570..+1.944 ms; these retain substantial adverse pairs.
Cold paired GC CPU medians were +0.028/-0.018 ms. Reduced cold CPU is observed,
but cold wall-time improvement remains unresolved against the A/A variation.
Factory natural A/A was +0.044 ms, versus the +0.005 ms AB/BA median.
The collected complete-workflow A/A median was +11.834 ms; its AB/BA median
was -16.703 ms with a retained +6.131 ms adverse pair. No observations were
dropped. This does not prove a stable universal construction or GC speedup.

The integrated library build took 212.11 s; the required shared executable link
took 131.97 s within its original 300-second stage. Subsequent benchmark module
preparation took 75.31 s (two compile jobs, zero link jobs), and an unchanged
repeat took 65.97 s (zero compile/link jobs), both within the original 90-second
module stage. The remaining startup, dependency and metadata freshness costs are
real; eliminating duplicate compilation/linking does not eliminate those costs.
This route reuses the required linked test runtime rather than certifying that a
fresh standalone benchmark executable links within 90 seconds.

Full single-process acceptance completed all 123 modules and returned normally:
harness wall 271.14 s, CPU 23.75 s, GC CPU 4.01 s, 90 collections. The subsequent
public benchmark recipe completed with `COLLECTION-PAIRED-OK`. All resource
limits and the complete inventory remain unchanged. Earlier timeout attempts
remain failures, and earlier wall times are not relabeled as current results.


### Consumer build scope and constant-time guards, 2026-10-22

The preceding 65.97 s unchanged build was not reproduced on this Darwin run:
unchanged source took 4.83 s before this contribution (4.41 user/0.37 system),
plain interpreter startup 0.14 s, and build metadata selection 0.48 s. The earlier
65.97 s is retained as historical wall evidence, not attributed entirely to startup.
Standard make's instrumented dependency check took 3.97 s, including 0.74 s GC,
and cumulatively allocated 2.98 GB. Cumulative allocation is not resident memory;
the heap bound remains 1 GiB. No backend compile or link jobs ran in that check.

The benchmark consumer now expands under t/, using defbuild-script and the existing
clan/poo/t prefix. Root producer source paths no longer shadow checked package
interfaces in this consumer graph. Public preparation still checks the complete
library and required shared executable first; standard make retains source/output
and compiled-dependency freshness. Single-target build entries omit the extra
batching-driver interpreter while keeping the original 300 s stage bound; full
builds and test batches retain the complete bounded driver. Stdout progress and
standard wall/user/system timing remain visible. No custom cache, load path,
namespace, compiler patch or extra environment variable is introduced.

Four fresh-process AB/BA pairs compared the original root graph with the t/
consumer graph against identical source/output bytes, with two A/A pairs. No
compilation, linking, other local build or forced collection ran alongside it:

| Observation | Root graph | Consumer graph |
| --- | ---: | ---: |
| Complete process wall range | 4.457–4.979 s | 1.486–1.546 s |
| Cumulative make allocation | about 2.984 GB | about 233.85 MB |
| Make GC collections | 15 | 2 |
| Make GC wall range | 0.624–0.708 s | 0.043–0.046 s |

The paired wall median difference was -3.281 s; the two A/A differences were
+0.022/+0.108 s. This establishes improvement for the measured unchanged consumer
check, not a claim that every 65-second historical run is now 1.5 seconds.
The allocation/GC counters come from Gambit's standard time form around make.
The root control is reproducible with the same compiled library and source tree:

```sh
# Run the two bounded commands in AB/BA and A/A order, with no concurrent build.
# Use the same official package output for both controls and public preparation.
export GERBIL_PATH="$PWD/.build/package"
just build library
just build test-program
gtimeout --signal=TERM --kill-after=3s 90s gxi -:max-heap=1G,debug=q \
  -e '(import :std/make (only-in "./t/build-spec.ss" build-benchmark))' \
  -e '(time (make (quote ("t/collection-paired-benchmark")) srcdir: (current-directory)))'
gtimeout --signal=TERM --kill-after=3s 90s gxi -:max-heap=1G,debug=q \
  -e '(import :std/make (only-in "./t/build-spec.ss" build-benchmark))' \
  -e '(time (build-benchmark "collection-paired-benchmark"))'
```

A general scope-membership filter was rejected: it added about 0.28/0.14 us
natural/collected hot-call wall time and retained retry regressions. The accepted
guard implementation instead uses constant-time exact-list-identity and empty-outer
checks. Partial overlaps keep the original append. Every descriptor instantiation
still runs before either fast path; active membership never implies readiness.
Existing provenance, revision and callback mutation checks remain authoritative.
Lean proves equal protection membership under faithful sharing, exact empty/shared
scope reuse, a list-length bound, and unchanged metadata acceptance/refusal. The
proof does not cover arbitrary callback effects, GC, pointer implementation or
compiler cache validity. Regression covers nested discovery during initialization,
mutation refusal, cleanup, retry, and recursive-construction refusal.

Four balanced old/new process pairs loaded the same compiled study module from
retained linked programs, with six inner AB/BA and four A/A pairs for all six
phases and both GC regimes. All 1,920 observations and semantic oracles completed.
Each table cell below is the median of the four differences between per-process
median observations on the reused algorithm, current minus prior, in microseconds:

| Phase | Natural wall | Collected wall | Natural CPU | Collected CPU |
| --- | ---: | ---: | ---: | ---: |
| Factory metadata/closures | +1.532 | -2.062 | +1.450 | -2.000 |
| Cold materialization | -29.153 | -56.338 | -30.450 | -52.750 |
| Repeated materialization | +0.006 | +0.030 | -0.025 | -0.025 |
| Revision/inverse | -11.700 | -15.432 | -9.650 | -13.950 |
| Discovery/revision/inverse | -5.275 | -25.529 | -5.825 | -25.725 |
| Refusal/retry/inverse | -17.077 | -16.922 | -14.800 | -15.450 |

Cold paired wall ranges retained -47.708..+136.936 / -128.233..+1897.049 us.
Cold paired GC CPU medians were +5.725/-15.425 us. Factory natural and collected
retain adverse pairs, and workflow/retry ranges also retain positive differences.
Thus the cold medians improve in this study, while tail wall-time stability and a
universal GC explanation remain unresolved. Hot-call wall differences are near
zero; no adverse row was discarded. Neither the earlier 5.211 ms difference nor
this run's CPU change is presented as a runtime or compiler correctness theorem.
Full logs, retained binaries and machine observations remain outside Git.


Current integrated acceptance retained all checks and resource limits: full build
51.42 s; all 123 modules passed in one process and exited 0, command wall 28.92 s
(harness wall 24.87 s, CPU 17.46 s, GC CPU 2.91 s, 88 collections). The public
complete study command took 24.40 s and passed every phase/oracle. The earlier
31.83 s unchanged-source public entry is a separate, unpaired receipt, so its
difference is not an isolated causal speedup claim. Post-suite unchanged workload
checks took 1.86 s and 1.63 s with no compile/link jobs. Advancing an imported
compiled interface's freshness forced the expected two workload compile jobs
(4.48 s), followed by a zero-compile/zero-link check. Namespace/output paths
remained clan/poo/t; the standard dependency invalidation was not bypassed.
The companion complete Lean gate passed all 343 atoms with 14 workers, with
original process/heap limits, independently of these runtime timing claims.
