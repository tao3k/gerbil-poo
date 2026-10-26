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
  -e '(import :std/make (only-in "./t/build-spec.ss" build-consumer))' \
  -e '(time (make (quote ("t/collection-paired-benchmark")) srcdir: (current-directory)))'
gtimeout --signal=TERM --kill-after=3s 90s gxi -:max-heap=1G,debug=q \
  -e '(import :std/make (only-in "./t/build-spec.ss" build-consumer))' \
  -e '(time (build-consumer "benchmark" "collection-paired-benchmark"))'
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

## Shared consumer construction and timing boundaries

The linked test program now joins the existing benchmark consumer in
`t/build-spec.ss`: `build-consumer` uses the standard `defbuild-script` source
directory and the existing `clan/poo/t` prefix. The complete library producer
check still runs first. Consumer dependency discovery uses its compiled
interfaces; standard make retains all dependency and output freshness checks.
No dependency database, load path, cache policy or environment flag is added.
`pkg-config` still selects OpenSSL linker options. The shared program's macro
reads the test inventory through `this-source-directory`; the inventory does
not depend on make's current directory. Runtime admission still checks the
current test inventory and that every shared runtime root is actually linked.

The measurement helper retains its five existing columns and original explicit
GC placement. An optional observer receives the same before/after Gambit
statistics snapshots after the timed action. It is not called when the action
raises; the original exception propagates. The collection study records runtime
identity, cumulative startup, fixture preparation and each sample's history.
History contains cumulative GC/allocation, most recent GC wall/heap/live size,
then interval GC wall and minor/major page faults. Statistics slot 9 remains
statistics-object overhead, not live heap. Natural samples never force GC.
Diagnostic formatting occurs outside the measured interval; its effect on
subsequent history is shared by both strategies and the A/A controls. These
observations cannot be directly substituted for older uninstrumented samples.

The companion finite Lean laws preserve acceptance/refusal under faithful
source-to-interface metadata relabeling and prove that stale producer refusal
precedes consumer admission. They assume matching captured/current stamps at
every corresponding dependency. They do not verify the compiler, make, linker,
filesystem timestamps or GC, and do not authorize omitting the producer check.

### Complete-entry paired receipt

On the same macOS host, Gerbil `1cfb032` / Gambit `ea114fc`, the public command
`just benchmark-collections 64 10 6` was measured in four balanced old/new process
pairs, followed by two old/old process pairs. The control routes only test-program
through the former root source graph; both routes use the same already linked
program and compiled workload. All 12 complete invocations retained the producer
check, consumer check, study check, 90 linked roots, 123-module inventory, 240
samples, 24 summaries and all semantic controls. None compiled or linked a job.

| Complete process pair | Order | Old wall (s) | New wall (s) | New minus old (s) |
| --- | --- | ---: | ---: | ---: |
| 1 | old/new | 27.462 | 20.649 | -6.813 |
| 2 | new/old | 24.678 | 20.698 | -3.980 |
| 3 | old/new | 24.365 | 20.183 | -4.182 |
| 4 | new/old | 24.649 | 20.634 | -4.014 |

The four-process wall medians were 24.663 / 20.642 s (16.3% lower); the median
paired difference was -4.098 s. The two A/A second-minus-first differences were
+1.966 / -0.028 s. Both controls, including the slower first old observation, are
retained. The producer check stayed 8.70–9.49 s in the four comparison pairs. The
unchanged test-program stage changed from 5.72–6.04 s to 1.89–1.97 s. This localizes
the principal gain to redundant consumer dependency traversal, not faster C
compilation or a changed collection algorithm. The earlier unpaired 24.40 s
receipt is historical, not the control for this comparison. Actual relinking
still cost 23.69 s after support changes; it is not described as a cache-hit check.

Across all 2,880 instrumented observations, the existing baseline/reuse cold
algorithm comparisons had process-median wall differences -249 / -238 us in
natural/collected regimes. Their largest signed cold differences were -99 /
-156 us. This does not reproduce or eliminate the historical +1.897 ms tail,
and is not a new runtime speedup caused by the build-scope change. The largest
positive cold A/A observations were +198 / +325 us: respectively GC wall
+85/+11 us and non-GC wall +113/+314 us, with no major page faults. The collected
+325 us observation had CPU +127 us, so neither GC alone nor CPU alone accounts
for its wall time. Factory natural comparisons had median wall +54 us, largely
GC wall +51 us, while natural A/A was -54 us; this shows history/order sensitivity
and is not evidence of a causal factory-construction regression. Collected
factory differences were about +1.2 us with no interval GC. No adverse observation
is dropped and no universal tail-stability claim is made.

Freshness regression advanced an imported compiled interface and observed standard
consumer recompilation/relinking; the following check ran no compile/link jobs.
Adding a source-only test inventory entry made the linked program refuse before
benchmark dispatch, then removing it restored ordinary admission. The observer
regression checks exact action count, post-action timing snapshots, collected-mode
GC before timing, the five-column result shape and original exception propagation.
Every original deadline and heap bound remains in force. Full observations and
control scripts remain outside Git.

Final complete acceptance passed all 123 modules in one process, naturally
exited 0 and retained the 300-second/1-GiB limits. Harness wall was 34.672 s,
CPU 19.001 s, GC CPU 3.116 s, 88 collections. The instrumented public entry then
completed in 21.77 s with all controls: producer 9.55 s, linked consumer 2.10 s,
workload module 1.46 s, workload process 7.53 s. Their sum is 20.64 s; the remaining
1.13 s includes recipe/process setup and is not attributed entirely to Gerbil
startup. Standard shell `time -p` now reports module and workload stages, matching
the existing producer/consumer timing; progress output and original bounds remain.
Across the 12 paired runs, runtime startup statistics had wall median 13.4 ms
(range 12.3 ms–1.341 s), CPU median 17.8 ms and GC-wall median 0.929 ms. The slow
startup is retained and not called a GC stall. Each run prepared 120 fixtures;
setup and measured-action intervals are recorded separately from fixed warmup,
printing, explicit collected-mode GC and startup. For example, the first new run
had setup wall 0.625 s (GC wall 0.067 s), measured wall 5.860 s (GC wall 0.480 s).
Factory actions include descriptor/closure construction; these numbers do not
separately establish a cost for each individual metadata operation.

## Whole-module import scopes and check costs

The tool/example import boundary now uses Gerbil's core `runtime:` import to
retain the complete existing facade dependency and initialization, alongside
`prefix-in` / `only-in` for the names actually used. Canonical runtime paths name
the existing `clan/poo/...` modules; existing aliases and public exports are kept.
The runner uses the official expander as one ordinary import set, rather than
flattening its complete interface into renamed bindings. The harness entry still
resolves to the official `gerbil/tools/gxtest` main. No facade wrapper, namespace,
cache database, load-path override or environment variable is introduced. These
are static import declarations, not a new discovery or build algorithm.

An audit using the official expander checked 73 changed modules: public export
names/phases, ordered module dependency coverage and the compiler-generated
runtime initialization code are unchanged. Dependency records fell from 6,343
to 1,502; the runner alone changed from 1,462 to 10. The declaration-only changes
retain function bodies; the runner's former private expander prefixes become
direct references to the same official functions. Reflective declaration helpers
with generated names are left unchanged. Standard make still checks every source,
extra input, output and dependency. Its complete original target list is retained.

Regression checks every selected alias against the retained facade's actual
public export object. The official loader generator produces the same initialization
for its former full prefixed interface and retained facade plus selected aliases.
A facade freshness control advances the polymorphic-service compiled interface,
requires its numeric-service consumer to recompile, then requires the unchanged
repeat to run no compile jobs. This retains invalidation by the whole facade,
including changes unrelated to the single retained service alias.

The finite Lean model now covers positive binding groups, identical module-label
coverage after regrouping, exact admission/refusal preservation and a compositional
inspection-count bound. It separately shows that an empty group would incorrectly
omit a stale dependency. These laws assume faithful module stamps in a stable
snapshot; they do not verify Gerbil's compiler, filesystem timestamp semantics,
allocation, GC or wall-clock speed. This cost work does not close the general
incremental/isomorphism-aware library proposal.

### Matched complete-entry observations

On macOS with the same Gerbil `1cfb032` / Gambit `ea114fc` installation, four
balanced process pairs compare the original and selected import declarations.
Every timed invocation follows one identical complete untimed workflow, keeping
all build checks, workloads and oracles. Both controls use the same original
collection workload and measurement procedure. Each timed run retains 240 samples,
24 summaries, all six phases and both GC regimes, with no compile/link jobs. Two
additional new/new process pairs are retained as A/A controls. All deadlines,
heap limits and worker budgets are unchanged. A standard `time` form reports
make's own interval/GC in both controls; shell timing still covers the full process.

| Pair | Order | Original wall (s) | Selected wall (s) | Difference (s) |
| --- | --- | ---: | ---: | ---: |
| 1 | original/selected | 21.157 | 20.864 | -0.293 |
| 2 | selected/original | 20.765 | 21.931 | +1.166 |
| 3 | original/selected | 21.209 | 20.856 | -0.352 |
| 4 | selected/original | 21.364 | 21.021 | -0.343 |

Complete-entry medians are 21.183 / 20.943 s (1.1% lower); the median signed
paired difference is -0.318 s. New/new differences are -0.333 / -0.602 s. The
remaining adverse pair and A/A variation prevent a stable end-to-end speedup
claim. The historical unpaired 21.77 s observation is not substituted for these
controls. The final independent acceptance command completed in 20.59 s.

| Median component | Original | Selected |
| --- | ---: | ---: |
| Library process wall (s) | 9.135 | 8.975 |
| Make interval wall (s) | 8.341 | 8.165 |
| Make CPU (s) | 8.289 | 8.117 |
| Make GC wall (s) | 1.564 | 1.596 |
| Make non-GC wall (s) | 6.787 | 6.569 |
| Cumulative make allocation (decimal GB) | 8.451 | 7.954 |
| Linked consumer wall (s) | 2.055 | 2.005 |
| Workload module check wall (s) | 1.505 | 1.495 |
| Workload process wall (s) | 7.765 | 7.755 |

Allocation is cumulative, not peak memory. Lower allocation did not establish
less GC wall time. The roughly 0.8 s library process residual includes startup,
script preparation and timing output; it is not attributed entirely to startup.
The remaining dominant make cost is non-GC source expansion/preparation, not the
linked consumer, whose unchanged dependency scope was already narrowed.

The four comparison processes' largest cold A/A observations are 236/33 us in
the original natural/collected regimes and 73/107 us in the selected regimes.
The selected +107 us observation contains GC wall +16 us, non-GC wall +91 us and
CPU +109 us, with no interval major/minor faults. Cold action code is unchanged,
so these observations do not prove that the historical +325 us tail was eliminated
or causally improved by the build import change. GC history and non-GC preparation
remain separate costs. The extra new/new controls also contain a natural cold A/A observation of
+1,746 us: GC wall +194 us, non-GC wall +1,553 us and CPU +1,639 us, with no
interval major/minor faults. Thus the complete data do NOT establish resolution
of the earlier +325 us variance; reporting only the four matched comparisons
would understate the tail. Every adverse row remains in the unversioned observations.

A deferred-output sampler was tried and rejected: a matched study retained a
+604 us cold A/A observation, including +589 us non-GC wall, worse than the cited
+325 us tail. Its helper and call-chain changes are not included. A scope-splitting
pilot also supplied no convincing benefit and is not retained.

Full local build and all 123 modules passed in one process with natural exit 0
under the original 300-second / 1-GiB bound. After rebuilding many modules, harness
wall was 140.811 s versus CPU 17.870 s, GC CPU 3.013 s and 90 collections. The 123
load/initialization intervals sum to 120.476 s wall but 1.997 s CPU; this identifies
a separate loading/initialization wait contribution, not a measured compute or
GC regression. Its OS/loader cause has not been established. This cold suite
receipt is separate from the paired complete benchmark command. Full raw data,
source snapshots and temporary controls remain outside Git.

### Hygienic declaration preparation and shared benchmark entry

The object macro's constant-hash identifier table put every slot name into one
comparison bucket. It now uses Gerbil compiler/base's
`make-bound-identifier-table`, with the same complete `bound-identifier=?`
predicate and standard first-occurrence deduplication. Slot normalization and
lexical capture live in the existing `support/object-syntax` module; `object.ss`
is 927 lines. Name hashing does not equate different contexts or marks.

A bounded compiler-phase Scheme study compares the actual helper with the former
constant-hash reference, using repeated identical syntax objects, two fixed
warmups, ten repetitions and four alternating AB/BA pairs. Both actions check
retained syntax identity and order. Median wall milliseconds per preparation:

| Distinct slot names | Constant hash | Compiler identifier table |
| --- | ---: | ---: |
| 64 | 0.825 | 0.043 |
| 256 | 16.594 | 0.140 |
| 512 | 62.153 | 0.348 |

These are declaration-preparation measurements, not runtime cold-factory results
or complete build-speed ratios. The 512-name ranges are 61.416–64.110 ms and
0.343–0.359 ms. Full finite identifier equality remains authoritative, even when
hashes collide. Lean's sequence-equivalence and candidate-list bounds assume a
consistent discriminator; they do not verify Gerbil's compiler or allocator.

A separate candidate replaced mapped revision snapshots with length-guarded
standard `andmap`. It was rejected: four complete-entry pairs gave medians
20.798 s before and 20.919 s after, with mixed signed differences including a
+1.016 s adverse pair. Existing mapped runtime guards remain installed. Public
reader regressions protect against truncated, extended and malformed snapshots;
plain two-list `andmap` would otherwise accept a matching shorter prefix.

The accepted entry uses standard `just` recipe dependencies. Library freshness,
linked-program freshness, workload-module freshness and the full workload remain
in the same order with their original heap and deadline limits. It removes three
nested `just` invocations without introducing a build cache or environment
protocol. In a fixed-source/output comparison, four full-command AB/BA pairs had
signed wall differences -0.49, -0.11, -0.27 and -0.33 s; medians were
20.745/20.525 s. The additional new/new control differed by +0.56 s, so the modest
entry gain does not establish a universal tail-latency guarantee. An outer
system timer and the Scheme process driver agreed within milliseconds, ruling
out substantial driver waiting in those observations.

Earlier constructor/guard candidates, cold A/A outliers and the adverse entry
pair remain part of the assessment. Full data and sampling profiles stay in the
temporary evidence directory and are not committed. System sampling of the
existing binary shows object reads, dynamic environments, table operations and
GC; it does not attribute the historical 1.75 ms cold outlier to one mechanism.
Non-GC time can still depend on GC history through subsequent table maintenance.
The peak must not be called eliminated merely because it was absent in a finite
rerun. Scheme sources and tests do not import or locate a Lean checkout.

To reproduce the declaration study, build the library and run the following
Scheme source with the same standard `GERBIL_PATH`. Save the script outside the
checkout and keep the 90-second / 1-GiB invocation bound, for example
`gtimeout --signal=TERM --kill-after=3s 90s gxi -:max-heap=1G,debug=q /tmp/slot-preparation.ss`.
It prints observations only; no generated matrix is part of the package.

```scheme
(import
 (only-in :clan/poo/support/object-syntax deduplicate-slot-identifiers)
 (for-syntax :std/iter
  (only-in :std/list/list delete-duplicates/hash)
  (only-in :clan/poo/t/closure-measure measure)))
;; Compare the actual compiler-phase helper with its independent constant-hash oracle.
;; These are declaration-preparation controls, not runtime collection measurements.
(defsyntax (study stx)
 (for (width '(64 256 512))
  (def unique (map (lambda (n) (datum->syntax (stx-car stx) (string->symbol
    (string-append "field-" (number->string n))))) (iota width)))
  (def input (append unique unique))
  (def (old)
    (delete-duplicates/hash input
      table: (make-hash-table test: bound-identifier=? hash: (lambda (_) 0)) from-end?: #t))
  (def (new) (deduplicate-slot-identifiers input))
  (def (checked action)
    (lambda ()
      (def output (action))
      (unless (and (= (length output) width) (andmap eq? output unique))
        (error "declaration preparation identity or order changed" width)) #t))
  (for (round (in-range 4))
    (def actions (if (even? round) (list (checked old) (checked new)) (list (checked new) (checked old))))
    (for* ((_ (in-range 2)) (action actions)) (action))
    (let-values (((ignored-a a) (measure (car actions) 10))
                 ((ignored-b b) (measure (cadr actions) 10)))
      (displayln "SLOT-PREPARE width=" width " round=" round " old-first=" (even? round)
        " first=" a " second=" b))))
 #'(void))
(study)
```

Final-code confirmation restored the original mapped guards before rebuilding
and running the entire 123-module suite. Two further full-entry AB/BA pairs
recorded 25.41/22.12 s and 25.56/24.27 s (before/after); the new/new control
recorded 21.52/21.06 s. Stage costs themselves varied substantially, including
workload walls of 7.68–10.41 s and library checks of 8.86–11.26 s. These full
results therefore do **not** establish a stable integrated speedup or justify
attributing the large apparent improvements to three fewer launches.

Cold A/A also rebounded. Signed microseconds per call (the sign only identifies
which invocation of the identical action was slower):

| Observation | Wall | GC wall | Non-GC wall | Non-GC CPU | Non-GC wall minus CPU |
| --- | ---: | ---: | ---: | ---: | ---: |
| Historical natural outlier | +1746.1 | +193.6 | +1552.5 | +1482.5 | +70.0 |
| Final-code natural outlier | -1346.2 | -304.7 | -1041.5 | -439.5 | -602.0 |
| Final-code collected outlier | -1838.7 | -552.0 | -1286.7 | -732.1 | -554.6 |

All three reported zero minor/major fault differences. The historical 1.55 ms
non-GC difference is predominantly CPU work; it cannot be explained away as
process waiting. The later outliers mix CPU work and a much larger wall/CPU
residual. That residual includes waiting, scheduling and counter overhead; it
is not a proof of one OS cause. Absolute A/A deviations must be retained in
both directions. The expensive historical CPU path has not been isolated to
one function, and the cold-tail issue remains open.

The complete configured local suite passed 123 modules and 1187 cases with
normal exit under the original 300-second / 1-GiB limits. An earlier full run
failed the OpenSSL metadata check because the test process lacked the same
standard `PKG_CONFIG_PATH` used for building; its failed log is retained. No
test, deadline or heap check was relaxed.

Ordered multi-round composition, intermediate-value transport, retained live key
ownership and full failure/retry laws are documented in [table-batches.md](table-batches.md).

Explicit carrier/key/value Wrappers now derive a complete table protocol without
a target backend; see [table-representations.md](table-representations.md).

## Captured optional point updates

`.delta/opt key update before` captures the same optional replacement used by
`.update/opt`, returning an ordinary revision-bound table delta. It admits the
source and Key, reads that key, calls `update` exactly once, then checks that its
result is false (absence) or `some` of an already admitted Value. It does not
normalize a Function again. Callback exceptions retain their exact causes;
malformed options and wrong child Types refuse before any backend write or delta
publication. Descriptor guards cover capture as in `.diff`.

Capture does not construct a trial carrier and never invokes `.for-each-change`.
An unchanged binding produces an empty delta with complete origins. This matches
`.diff` and `.update/opt`: an empty request is not an assertion that the old value
will remain unchanged on a later installation. A changed request retains the
original expectation, so a stale target refuses with that exact key; unrelated
bindings may be rebased. Applying a delta never calls `update` again.

The callback owns its argument/result Option shells. Capture copies these shells
with the existing `map/option`, preserving the exact admitted leaves; later box
mutation cannot change the recorded expectation or replacement. Immutable leaf
values, stable recognizers, pure persistent backend laws and serialized metadata
mutation remain premises. Callback/IO effects are not rolled back.

Point requests reuse ordinary ordered batches, inverse deltas, explicit key/value
isomorphisms, incremental folds and all three ownership styles. Correlated index
`.acons` / `.remove` now use this capture protocol instead of constructing a trial
primary and discovering a whole-table difference. `update-indexed-service` shares
the existing linear FUN/IO installer with whole-table revision workflows, including
multi-key alias/team indexes, uniqueness refusal, explicit retry and shared checked
Functions.

Lean's `pointChanges` equals finite discovery restricted to the written key. Its
laws prove installation, unrelated-base rebasing, exact stale-key refusal, inverse
recovery, at most one emitted edit, callback failure and explicit isomorphism
commutation. This is a finite semantic/work bound. Source admission, lookup,
metadata preparation, callback/type recognition and actual backend costs remain;
no unconditional O(1), allocation, GC or wall-time improvement is claimed.

### Complete fold publication boundary

Source and warm-target fold updates now recognize their complete final root;
compatible child Types or paired bindings alone do not establish root refinements.
Aggregate reuse still avoids target reinitialization/reprojection, but complete
recognition may scan both snapshots. `reuseFoldWork` explicitly charges supplied
source and target admission visits. See [table-fold.md](table-fold.md) for atomic
batch semantics, retained-pair failure/retry, service composition and proof scope.


## Selective grouped aggregation and direct summary delivery

`(table-group-fold Source Target Aggregate classify project [origins])` returns
one Wrapper-shaped protocol: `.ap` prepares an admitted source, `.unap` observes
that source, `.get` observes the summary table, and `.apply-delta` prepares a
successor. Target.Value must be the exact Aggregate descriptor. Aggregate supplies
`.zero`, `.add` and recognition; `.sub` is not required. The ordinary table fold
and grouped fold share the same evaluation kernel, not parallel implementations.
As with ordinary folds, `.add` must be pure and must not mutate the shared `.zero`
seed or prior aggregates; persistent rows/leaves must not be changed behind the
revision protocol. Recognition alone cannot establish these behavioral laws.

Each source row belongs to the explicit, stable `classify(key,row)` group. Existing
`table-indexes` owns grouped membership/retraction and structural bucket carriers;
whole-source business refinements apply only to the complete primary, not each
bucket. A nonempty group is folded in its declared backend traversal order through
`project(key,row)` and `.add`. A live group whose sum is zero remains present;
removing its last member removes the target key. No inverse, commutativity or
retraction law is inferred for arbitrary aggregation. Stable logical key equality
and repeatable bucket traversal are backend premises.

Warm updates check all ordered source conflicts and complete primary admission
before classification or contribution evaluation. Original/final group keys of
edited owners are coalesced by the target backend. Each affected surviving bucket
is refolded once; unaffected summaries are reused. The protocol prepares one
ordinary target delta with exact old values, admits the complete target, and then
calls optional `receive(next, target-delta)` (default: successor only). Gerbil
`values` retains both results. No target `.diff` or full target enumeration is
needed on this path. Target equality uses existing table Option/data equality;
already admitted Function leaves are not normalized again.

The existing `publish-projected-ledger-action` handles this delivery without a new
publication wrapper: complete target constraints and existing pure/mutable/linear/
posh/classy installation precede Reader/FUN/IO consumption. Preparation/refinement/
arithmetic/old-value failure exposes no successor; retry uses the unchanged
predecessor and a fresh public owner when necessary. Explicit source inverses
restore source/group observations; target inverses restore summaries independently.
Postcommit IO effects are not rolled back. Empty and transient source batches
retain all delta origins, so even a no-edit successor refuses after invalidation.
Metadata writes retain the existing cross-thread serialization discipline.

`make-team-capacity-fold` in `examples/service-collection.ss` groups typed service
rows by team, preserving their admitted callbacks in the primary. Regressions cover
RationalDict/Trie backends, zero-valued live groups, last-owner deletion, 32 mixed
revisions against an independent list oracle, untouched-group callback refusal,
final-source/target refusal, original exception identity and corrected retry,
transient edits, inherited origin invalidation, five-style stale-target retry and
inverse recovery. An ordered list-concatenation aggregate has no `.sub` and verifies
that group refolding does not assume a commutative or retractable algebra.

Cold work includes complete source/index/target recognition, grouping, one fold per
nonempty bucket, and one bulk target construction. Warm work includes source delta
installation, existing index maintenance, complete recognition, group-key discovery,
**all rows of affected buckets**, changed-target installation and separate public
style installation. Repeated source edits may repeat pure classification. A hot
single large group may require a whole-source fold; this is selective group reuse,
not per-edit constant-time aggregation. The regressions count contribution calls,
not machine speedups or GC bounds.

The finite Lean `TableFold` laws establish presence by live ownership, empty-group
removal, grouped-index repair, old/final group framing, selective summary repair,
complete direct target deltas and explicit source inverse recovery. The summary
function is generic over complete bucket observations; ordered finite sums are a
concrete instance in top-level `Examples/ServiceCollection.lean`. Existing admission
and publication laws cover refusal/consumer ordering. Finite inventories, stable
pure classification/contribution functions, faithful recognizers and persistent
backend laws are premises. This advances the proposed collection library's future
work; automatic dependency/algebra discovery, destructive rollback, compiler/GC
correctness and general whole-library completion are not claimed.

### Finite multivalued grouped aggregation

`table-group-fold` accepts `multiple?: #t`: classify returns a finite proper
list of typed cohort keys. Default classification still returns one key, even when
that key is itself a list. Duplicate memberships contribute once; empty membership
retains the primary row without contributing to any group. A live zero summary
remains present, and deleting its last owner removes the group.

The implementation extends the existing grouped index, fold kernel, owned cache,
exact target delta and five-style publication chain. A shared private admission
function captures the classifier list spine, checks its keys without normalizing
Function leaves, and uses standard stable deduplication. It replaces the duplicated
index checks rather than wrapping each operation. Classifiers, logical keys and
contributions must remain stable and pure; capturing a spine does not freeze keys.

Warm repair refolds only old/final affected groups. Every surviving row in each
affected bucket is charged; finite classification, spine copying, key recognition,
index preparation, whole-root recognition and style installation remain costs.
There is no constant-time, GC or wall-clock speedup claim. Invalid membership,
stale origins, final refinement refusal or callback failure exposes no successor;
the old persistent cache remains available for corrected explicit retry. Inverting
the delivered target delta restores observations, not information discarded by an
aggregate.

The service example combines duplicate cohorts, checked Function capacities,
migration and untouched-group reuse. Regressions cover Trie/RationalDict oracles,
all five styles, inverse recovery, malformed membership, callback-owned list
mutation, refinement retry, origin invalidation and list-valued single keys.
Lean proves the old/final membership frame, selective repair, exact target delta
and duplicate-membership invariance; finite service examples include zero-valued
live groups and inverse recovery. These laws assume faithful equality/recognizers,
finite owner inventories and persistent backend laws. This advances the collection
proposal's future work and does not prove host callbacks, GC or compiler behavior.

Design review: no second grouping algorithm, cache representation, installer or
namespace was added. The explicit multiplicity flag follows the existing index
and projection interface. The necessary list ownership copy is visible in the cost
boundary; further automatic dependency/algebra discovery remains research work.

## Checked list and singleton construction

Public Table `.<-list` and `.singleton` now share complete construction admission.
The boundary first requires a finite proper list using Gerbil's standard contract,
then captures its spine and Pair shells **before any child predicate**. Every key
and value is recognized in input order, including duplicate entries that a backend
will later supersede. Recognition retains admitted leaves; it does not cook or
wrap Functions again. Raw normalization is still the separate `.validate` / style
`.admit` operation.

Only admitted captured rows reach the existing raw backend strategies. `.<-list/key`
is the bulk-construction capability; `.singleton/key` retains the Trie's direct
leaf path. RationalDict keeps Gerbil RBTree's list builder. Order, representation
and indexed families retain their complete delegation/initialization paths behind
the same boundary. The complete business root is recognized before return. This
permits a final two-row refinement even when empty/singleton business roots are
forbidden; no public point insertion or invented valid empty seed is required.
A backend needing a specialized whole-root builder must declare that capability.
The generic persistent foldr remains the fallback, under its ordinary backend laws.

Backend duplicate conventions are **not unified**. The generic foldr keeps the
first occurrence; Gerbil's RBTree list builder keeps the last. Admitted captured
order/multiplicity is passed unchanged, so source/derived behavior remains governed
by the declared constructor. Finite Iterator import deliberately has its separate
last-yielded policy, already implemented by its key registry.

Malformed lists use the standard contract refusal; invalid Pair/child/final-root
membership uses the existing POO TypeError boundary. Constructor and unexpected
recognizer exceptions retain their original cause. No successful root/owner is
returned on refusal. Input/callback effects are not undone. Backend primitives are
implementation capabilities, not safe public import APIs: controlled tests of raw
carrier normalization may explicitly construct external/raw fixtures, then call
`.validate`. Arbitrary overrides of public methods remain the implementer's law
obligation; there is no global interposition or compatibility wrapper.

All five Table/Set style factories expose `.<-list` and `.singleton` via ordinary
fresh-owner creation. They do not retire an existing owner. Receiver updates keep
their existing step/import APIs; no ambiguous constructor-that-mutates-an-owner is
added. `construct-ledger-action` composes complete construction through Reader/FUN
before IO, suppressing the consumer on failure and retaining Function identities.

Regressions cover direct/generic/ordered/represented/indexed builders, malformed
and superseded rows, alias mutation during child recognition, duplicate precedence,
partial refinements, the Trie singleton capability, all fresh presentations,
original exceptions and Reader/FUN/IO retry. Constructor-specific tests live in
`t/table-construction-test.ss`; the existing validation module stays below 1,000
lines and is not expanded with an unrelated monolithic case inventory.

Lean's finite `TableBatch` constructor model proves unchanged admitted row order,
multiplicity and leaf identity, child/backend/final refusal precedence, exact
backend observation preservation and a source-length bound on row checks. The
backend observation law supplies its actual duplicate policy; it is not guessed.
The default first-write foldr and existing last-write stream model have separate
examples. Physical capture/alias behavior is a Scheme regression; immutable model
rows, stable admitted leaves and lawful persistent builders are premises.
Capture, recursive child recognition, backend construction, index preparation,
whole-result recognition, owner allocation and GC remain charged. No universal
termination, physical ownership, backend complexity or compiler/runtime proof is
claimed. This advances the proposed collection library's finite future work.

Design reflection: preserve mature constructors and the singleton fast path behind
one public boundary, reuse standard list/contracts and existing owner creation,
and keep normalization explicit. No new namespace, storage algorithm, cache or
parallel validation/ownership engine is introduced.


## Complete collection IO

Table and Set JSON, bytes and port codecs now share one guarded dispatch in the
existing table module (`table/io.scm`). It retains the existing List/Pair codecs
and wire formats. Trie now gives the collection protocol precedence over its raw
node Wrapper, matching the existing representation-derived table ordering. Table
payloads are bindings; Set payloads are elements. Encoding
recognizes the complete root before projecting rows or invoking child codecs.
Decoding uses the original decoder and complete persistent constructor, then
recognizes the resulting business root. Backend duplicate precedence, unique
indexes and partial whole-root refinements are retained, not replaced by a new
serialization or storage engine. Normalization and wire conversion remain separate.

The dynamic scope covers schema/method resolution, child calls and construction,
including descriptor origins, Key/Value and custom Set constraints. Supported
metadata edits refuse; original child/parser/backend errors are preserved. Pure
JSON/bytes operations expose no partial successful root or byte vector. Port IO is
not transactional: invalid source roots are refused before a prefix is written,
but later codec refusal retains bytes already emitted or consumed. Byte-vector
decoding retains the standard rejection of trailing bytes; port unmarshalling
retains the original sequential stream convention.

All five Table/Set styles encode through the existing nonconsuming snapshot reader.
JSON/bytes/unmarshal factory operations use the ordinary fresh creator only after
complete decoding. They neither replace nor retire a prior owner. Gerbil receivers
expose encoding/marshal observations through that same protocol; decoding belongs
to the factory. Metadata and owner guards retain their original failure semantics.
No custom environment, binary format, build graph or owner representation is added.

The service example combines represented indexed tables, a unique rank index,
linear style and Reader/FUN/IO. An explicitly declared finite JSON handle registry
restores the exact known checked Function objects; this does not serialize closure
code or infer a binary codec. Failed index construction suppresses consumption,
leaves the original owner live and allows a fresh retry. Built-in Function values
remain unsupported on formats without a declared codec. Custom codecs must obey
their stated laws; membership alone does not imply a lawful codec.

`TableRepresentation.lean` models pre-encoder admission, private decode/build/final
admission, exact refusal precedence and conditional roundtrip from existing child
codec and carrier inverse laws. Its port model retains state beside failure and
proves both untouched ports on invalid roots and prior prefixes on late refusal.
Finite input, lawful codecs/persistent constructors, stable leaves and supported
metadata writes are premises. Actual parser correctness, callback termination,
physical ownership, allocation, GC and runtime/compiler correctness are not proved.
Preparation, full recognition, row traversal, child encoding and construction all
remain charged; no unconditional complexity or latency claim follows.

Design reflection: one boundary coordinates the existing codec and constructor
protocols; thin public entries select a format. Styles reuse observation and fresh
creation rather than adding another IO wrapper/owner engine. The implementation
is kept in a functional include, with no new public namespace or compatibility path.

The functional IO include is registered in the existing `std/make` `extra-inputs`
for both library and complete qualification targets. A build-inventory regression
prevents edits to that include from reusing an older table module. Acceptance uses
the standard clean/build path after correcting this missing dependency; no extra
cache credential, environment variable or scheduler is introduced.

## Complete normalization through same-Type views

An ordered or indexed descriptor preserves the source's Key and Value Types.
Its recursive validator now reuses the original source validator rather than
starting with a business `.empty` and applying checked point edits. An indexed
view initializes caches from the entire cooked primary only after source validation
succeeds. A simultaneous unique-key swap therefore need not pass through an invalid
intermediate indexed root. An unchanged primary retains its original snapshot and
cache roots; current metadata and complete receiver membership are still checked.

The existing `make-ordered-services` and Reader/FUN `admit-ledger-action` example
combine an exact-two-service refinement, unique priority swaps, nested Function
wrapping and all five ownership presentations. Late child failure suppresses IO;
unique-index conflicts retain the old primary/caches for fresh retry. Source handles
remain untouched and fresh admitted owners receive the checked callbacks. Validation
normalizes but does not execute those callbacks.

`table-view-validator` selects whole-source delegation only when both child Type
identities match. An inherited view with overridden Types follows ordinary validation;
normalization equivalence is not inferred from membership or an arbitrary carrier/key
isomorphism. The original source collision and backend-error order remains unchanged.
`validate-table` shares metadata protection, shape and final receiver admission for
both paths. This reuses source validators and existing index construction, rather
than wrapping every point operation or introducing another cache implementation.

Lean's `VariantValidation.tableView` models guarded read, complete source cooking,
identity reuse, one full rebuild and final receiver admission. Its theorems retain
exact read/child/index failures and the normalized primary, conditional on sound
identity and a faithful builder. Existing `table_positions` supplies finite wrapper
fidelity. Callback effects are not rolled back, and these laws do not certify the
Gerbil evaluator, GC or arbitrary user normalization termination. Child work,
complete membership and cold cache initialization remain explicit costs.

Local complete acceptance: 142 modules / 1,598 cases passed in one process,
including existing collision/backend-order controls, under the unchanged 1 GiB heap
and 300-second runtime limit. The complete Lean gate passed all 20 phases.

### Backend-equivalent cache work

Incremental index maintenance uses the source's declared `.key-table` to schedule
one rebuild per logical primary key. Multivalued memberships use an analogous
Unit-valued registry over the declared index backend. Projection, indexes, grouped
folds and grouped joins share this boundary rather than guessing structural key
equality. First physical representatives and encounter order are retained. All
memberships are recognized before coalescing, including repeated aliases.

Every sequential old-value expectation is still checked by `.apply-delta` before
any index projection. Composed and cancelling requests retain their original
changes and inverse history. A refused intermediate expectation publishes nothing;
a distinct primary owner claiming an occupied unique key still conflicts. Only
the cache worklist is coalesced. Opaque Function leaves remain the admitted objects.

The declared key-table capability must preserve backend key equivalence. Callbacks
must respect that equivalence: lookup, membership classification and projection
must agree on logical aliases. This does not discover a canonical representation
or make arbitrary representation-sensitive callbacks congruent. Source, registry
and declaration revisions remain dependencies; stale metadata refuses reuse.

`t/table-index-equivalence-test.ss` combines RationalDict exact/inexact aliases,
ordered unique/grouped indexes, chained migrations, inverse recovery, all five
ownership styles and Function-valued grouped aggregates. The finite companion
`distinctKeyWork` model proves logical coverage, unique scheduling, first-key
retention, a work-count bound and grouped observation equivalence. Sequential
installer failure is preserved. Registry construction, lookups, full recognition,
allocation and GC remain charged; these laws do not establish a latency bound.

Design reflection: one private helper replaces the projection's local key loop
and the membership boundary's structural hash deduplication. Registries are
prepared once per family and carry their own metadata dependencies. No new public
collection namespace, per-method wrapper stack or delta-squashing protocol is added.

### Logical ownership through isomorphism histories

The target registry still decides whether two translated keys collide. When a
translated class already has an owner, the source's declared Unit-valued key
registry decides whether that owner and the incoming source key are the same
logical key. Structural `equal?` is not a source-key equivalence oracle. One
attempt prepares that source registry once; an occupied-target probe uses the
existing private empty/point-insertion and membership protocol under metadata
protection. Admitted keys and Unit values do not need public constructor
recognition again. Identity-equal owners need no backend probe.

This closes cross-snapshot alias revisions, including exact/inexact RationalDict
keys, ordered composed edits, deletion/reinsertion, inverse deltas and paired
aggregate transfer. The owner registry continues to span the whole encountered
history; distinct logical source owners cannot steal an occupied target class.
No edit or intermediate old-value expectation is discarded. Source conflicts
precede conversion, and failures suppress the existing FUN/IO consumer. Retry
starts from an explicitly retained source snapshot or aggregate state.

Physical key/value roundtrips remain checked with the existing strict inverse
boundary. Accepting backend-equivalent owners does not authorize a converter to
change admitted representation tags or Function leaves during recovery. A lawful
map respects both declared backend equivalences; source-key registry capability,
persistent backends, pure stable conversion and the existing inverse laws remain
premises. Arbitrary quotient discovery or lossy conversions are not inferred.

`make-rational-capacity-ledger` combines negated RationalDict keys, Tuple/Pair
Function-valued rows, retractable capacity aggregates and existing transport/FUN
actions. `table-transport-test.ss` exercises forward/backward deltas, both numeric
alias orders, aggregate adoption, deletion/reinsertion, inverse recovery, all five
presentations, true collisions, source conflicts, strict inverse refusal and retry.
Lean's `claimTransportOwner` laws state fresh admission, alias admission, exact
collision payloads, logical-bijection safety and unchanged logical observations.
They complement existing sequential transport and aggregate laws; primitive
registry correctness, converter termination, allocation and GC are not proved.

Design reflection: one source-owner decision is corrected inside the existing
translator, so snapshot, delta and fold transport share the fix. Existing target
collision tracking and physical inverse checks stay in place. There is no new
namespace, public method wrapper, global memo or parallel transport implementation.
Registry preparation and occupied-target point/probe costs remain charged;
this unit makes no latency or asymptotic improvement claim.

### Capture declaration buffers at admission

Origin arguments are finite lists of dependency identities. Factories copy their
list spines before forcing further descriptor getters. `table-sources` captures
`.sources` before `Key`/`Value` discovery and uses the existing source-protection
scope; comparer dependencies use the same owned-spine discipline. Caller list
reuse cannot detach old dependencies, even when a replacement object happens to
have the same revision. A supported edit of the original object invalidates old
focuses, deltas, cursors and derived states. Buffer reuse alone does not invalidate
unchanged objects; a new construction captures the new declaration.

`make-policy-capacity-fold` demonstrates revisioned team-capacity aggregation over
rows containing checked Functions. `fold-ledger-action` suppresses IO on a stale
policy, a fresh factory retries the same delta, and inverse installation restores
capacity and the original callback handle. table-origins-test.ss covers this chain
and all public explicit-origin factories without another publication abstraction.

Capture allocates one list cell per declared origin, preserving order, duplicates
and leaf identities. Normal root admission, preparation and revision checks still
cost work. It neither copies mutable child objects nor discovers undeclared closure
dependencies. Design reflection: own declarations once at their existing factory
boundary and reuse stamp checks, rather than layer wrappers onto individual methods.
Finite Lean laws cover membership, ordered capture, length and fresh/stale decisions;
they do not prove Gambit heap, GC or arbitrary metadata reflection behavior.

### Complete Set observation boundary

`.foldl`, `.foldr`, `.for-each`, `.for-each/reverse`, `.count`, `.list<-` and
`.elt?` admit the complete original Set before reading results or invoking user
callbacks. Raw Table traversal remains a backend primitive used by recognition;
putting the same Set check into that primitive would recurse during admission.
The Set boundary reuses `with-set-inputs`. One fold adapter projects elements out
of Unit-valued rows and delegates both directions without sorting/materialization.
Visits discard all callback results; folds retain opaque seeds/results without an
unrestricted fallback Type. Callback contracts also apply to empty traversals.
Count/list/membership keep their original specialized backend algorithms and key
equivalence; observed Function handles are never normalized again.

All five styles expose both visit directions; Posh/Classy receivers reuse Gerbil
class-method dispatch. The existing snapshot-bound query path retains custom Set
methods. Reentrant publication may update an owner, but the current traversal
continues on the captured persistent root. `fold-access-action` composes raw or
style Set folds with Reader/FUN/IO. Root refusal suppresses callbacks and consumers;
callback failure retains its exact cause and already executed prefix, without
installing a new root. Retry is a separate invocation.

`set-observation-test.ss` covers the complete family, malformed/excluded carriers,
empty callbacks, both orders, specialized delegates, opaque Function accumulators,
metadata protection, effect-prefix refusal/retry and five-style receiver publication.
Finite Lean laws cover admission-before-read, exact delegation, original causes,
ordered Unit erasure and first-callback refusal/consumer suppression. Faithful
recognizers, backend enumeration, stable leaves and supported metadata edits are
premises, not automatic certificates. Validation and every crossed public boundary
retain their full costs; no constant-time, GC or arbitrary termination claim follows.
Design reflection: keep the existing read/fold kernels and custom delegate semantics;
do not bypass a public validation boundary for an unproved reuse optimization.

### Declared ordinary-fold policies

`table-fold source aggregate project origins` shares the existing constructor with
its three-argument empty-declaration form. A finite origin list declares metadata
read by the contribution callback. Its spine is captured before descriptor or
algebra getters execute; the existing source scope protects discovered participants.
The public `.sources` field reports the complete declaration. Representation
construction passes that private scope into its target fold and exposes the bridge
scope too. A Wrapper identity is not a substitute for the objects it depends on.

Consequently a supported policy revision refuses every dependent old fold, including
Codomain states initialized directly from target roots. Restoring a policy's old
value does not restore its old revision. Converter-only changes leave the source
aggregate valid; an empty delta's additional origins remain specific to states
that adopted them. A fresh independent state can rebind an unchanged persistent
representation under its own current scope, retaining the existing reuse protocol.

The policy option in `make-capacity-ledger` demonstrates checked Function leaves,
Tuple/Pair conversion, XOR keys, ordinary weighted aggregates, sparse changes,
Reader/FUN/IO and inverse recovery. Score-only policies do not invalidate independent
represented-data owners in Pure/Mutable/Linear/Posh/Classy styles. Without a supplied
policy the factory keeps its original projection; it adds no per-row policy branch.

Eight controls in table-fold-test.ss cover declaration capture, malformed/cyclic
lists, mutation during algebra discovery, independent target caches, selective
framing, historical no-op lineage, source conflict ordering, exact failures, IO
suppression and fresh retry/undo. `TableFold.lean` composes the existing stamp
checker and capture laws; it does not introduce another dependency checker.
Complete source/target recognition, preparation, conversion and GC costs remain
charged. Declaration capture copies one spine cell per origin. No automatic hidden
closure dependency or universal runtime bound is claimed. Design reflection: expose
an existing constructor capability and transmit its private scope, rather than
build synthetic source descriptors or stack additional read wrappers.

### Comparer seals and zero-comparison observations

A constructed comparer seals both its own revision and the numeric revisions of
its captured key/dependency list. The previous self-revision-only test could accept
a stale comparer when a new view captured already-revised dependencies, especially
on empty/singleton roots or unbounded backend cursors where no comparison ran.
`with-table-comparer` now reuses the existing source scope to admit known seals
before ordering, wrapper and cursor discovery. The comparison primitive retains its private source guard, independently of
public-label revisions. Wrapper endpoint Types are protected before reading converter callbacks.

Unsealed custom comparers still use declared reference sorting, including copied
custom comparison functions; callback identity alone grants no positioned capability.
Editing constructor metadata revokes positioning evidence. The original comparison
closure remains usable under its captured source guard; fresh declaration is needed
to obtain new backend-positioning evidence.
Retained views/pulls still use their existing version guards, including after EOF.
Constructor-owned `.sources` metadata is read-only: supported changes go through
revisioned object slots. Raw in-place mutation of returned metadata lists and
arbitrary concurrent writes remain outside this protocol.

`make-ordered-service-indexes` accepts an optional `order-policy` with direction
1 or -1. Positive order keeps the original procedure/equality pair; reverse order
uses the existing sort fallback. Both indexes capture the policy. The worked flow
covers five ownership styles, old-workflow rejection, fresh reconstruction over the
same admitted source, checked callback identity, sparse updates, undo and FUN/IO.
Eight controls in table-order-test.ss include empty/same-root comparison, no-callback
cursor pulls, EOF, protected getters, key revision, redeclaration and custom fallback.

The weak registry's values are only own revisions and numeric version lists; no
descriptor or guard closure is added to its values. `TableObservation.lean` models
this full seal and proves freshness/refusal, absent-seal fallback separation, exact
observation delegation and zero backend pulls on stale snapshots. Faithful identity
lookup, stable version snapshots, lawful comparers and backend enumeration remain
premises. GC and unrestricted callback termination are not proved. Guard and source
preparation costs remain charged. Design reflection: repair the capability evidence
and reuse one admission/Iterator path rather than wrap each individual range result.

### Reference-order admission across comparison and decomposition

Whole comparison now separates lawful reference observation from structural-backend
capability. Custom or label-edited comparers may use the existing checked Iterator
comparison; only a complete current constructor seal selects `.compare/key`.
Both complete roots and strict Integer callback results retain their original
admission/failure order. No sorting or order discovery is inferred for a backend:
the declared Iterator order must agree with the comparer.

Ordered decomposition now shares comparer-origin admission before key metadata,
pivot lookup and either successor construction, including empty roots. Table, Set
and five ownership styles reuse that boundary. Current custom protocols retain
their existing private comparison guard; edited labels do not acquire positioning
evidence. Stale declared origins require explicit reconstruction. Both source
snapshots, Function leaves and failed owners remain available for retry.

The service example composes comparison and linear decomposition with Reader/FUN,
then invokes one IO consumer after both sides accept. Indexed swaps, reverse custom
order, original callback failures, inverse recovery and consumer suppression have
regressions. Finite Lean laws prove callback selection, stale-origin suppression,
exact delegation and empty/opaque-payload examples. Lawful ordering, faithful host
revisions and persistent carriers remain premises; no runtime/GC theorem is claimed.
Design reflection: share the established comparer boundary and observation kernels,
keep backend evidence distinct, and add no per-method validation wrappers.

### Owned finite batch requests

`methods.table` now captures `.join/list` roots and `.compose-deltas` requests
before metadata discovery, recognition or validation can reuse the caller's list
cells. Style `.join/list` captures right-owner identities before entering the
existing generation-captured update. One standard `map identity` at each public
batch boundary owns only the finite spine: persistent roots, delta objects and
checked Function leaves remain shared. No new namespace, cache, lock or per-method
validation wrapper is introduced.

Previously a first-root recognizer could replace the caller's second request:
joining roots containing 10 and 20 could silently install 10 and 90. The same
interference could change a validated delta batch after origin collection. Capture
now preserves order, repetitions, later-source join priority, intermediate delta
expectations and origin lineage. An invalid original root/owner still refuses even
if the caller list is later repaired; failure leaves update ownership available
for an explicit fresh batch retry. Existing complete admission and single-commit
publication remain unchanged.

`join-ledger-action` is the existing Reader/FUN map over this shared join boundary.
The worked scenario combines checked Function leaves, unique indexes, inverse
swaps, retractable folds, consumer suppression and policy invalidation. Regressions
also cover metadata getters, root-recognizer interference, five styles and
right-owner retention. `TableCapture.lean` reuses ordinary finite list capture and
the existing batch correctness theorem to prove original-request delegation,
preparation/installation failure preservation, exact order/count and intermediate
conflict semantics after caller-buffer reuse.

Capture costs one spine cell per request at each crossed public batch boundary;
roots and payloads are not copied or normalized. All original recognition, lookup,
index preparation and conflict costs remain charged. Stable leaves, faithful
revision/ownership checks and serialized caller-cell capture remain premises.
Arbitrary simultaneous writes during the copy and callback-effect rollback are
outside these finite future-work laws. Design reflection: own the existing request
boundary before callbacks, instead of cloning data or introducing another executor.

### Constructor requests captured before metadata and delegation

`capture-table-bindings` owns a finite request spine and its binding Pair shells.
The raw Table constructor invokes it before discovering descriptor sources or
child Types. Existing style factories reuse it before invoking a custom public
Table constructor. Set factories copy only the outer element list: Pair-valued
elements are opaque leaves, not binding shells. Original keys, values and checked
Functions retain identity. The backend still owns duplicate-key precedence,
bulk/singleton construction and complete-result recognition.

Previously metadata or a custom factory delegate could rewrite caller-owned Pair
fields before the constructor took its snapshot. Now changing a requested value
from 20 to 90 cannot alter the captured constructor request. Repairing an original
invalid occurrence cannot make it acceptable either. Malformed outer requests in
styles retain the existing guarded delegation order, including stale-factory refusal
before the downstream list contract. Unexpected delegate/backend errors retain
their original causes; fresh explicit requests can retry.

The existing `construct-ledger-action` accepts raw descriptors and all existing
Table/Set style factories through the same Reader/FUN map. The worked indexed
service scenario composes complete construction, checked Function identity, unique
index refusal, consumer suppression, retry, atomic swaps and inverse recovery.
Seven regressions cover metadata interference, invalid original entries, five
Table/Set factories, Pair-valued Set identity and stale/failure precedence.
`TableCapture.lean` composes the existing batch capture with finite child/backend/
root admission, proving failure suppression, exact delegation, original Pair-field
observations and identity recapture. This advances finite collection future work;
stable leaves, serialized capture and faithful backend/type protocols are premises.

A crossed public Table constructor boundary copies one list cell and one binding
Pair shell per valid request entry. Set factories copy only list cells. Private
captured lists are passed through ordinary delegates; no deep copy, cache or new
validation-wrapper layer is introduced. Existing recognition, index preparation
and backend costs remain charged. These laws do not prove arbitrary mutable-leaf,
runtime/GC or concurrent-heap correctness. Design reflection: share the request
capture kernel, preserve each representation's leaf semantics, and keep backend
algorithms and standard contract failure boundaries intact.

### Owned finite Set-image outputs

The multivalued `set-image` boundary now owns the callback's proper output-list
spine before any target `Elt` predicate runs. Previously a recognizer could reuse
the response buffer: an original `(7 8 8)` request could publish `(7 8 9)`. One
standard `map identity` in the existing multiple-output branch prevents that request
substitution. Single-output mappings already own their private singleton list and
retain the original path. Elements, including checked Functions and list-valued
single keys, remain shared opaque leaves.

Every original output occurrence is recognized before backend-equivalent keys are
coalesced. A recognizer cannot repair an invalid original member by replacing its
caller cell; an inexact representation rejected by an explicit exact-only Elt
contract still refuses even when numerically equivalent to an accepted key.
Type/backend errors and first-failure order remain unchanged. Callback writes to
the external response buffer are retained, without publishing partial caches or
consuming a target owner on failure.

Cold indexing and warm touched-key discovery share this same boundary. Existing
grouped indexes still implement shared witnesses, deleting one owner, last-owner
retraction, exact target deltas and inverse recovery. The existing permission
publication example composes all five styles, conflict refusal, a fresh-owner
retry and inverse target installation through Reader/FUN/IO. Six regressions also
cover cold/warm malformed responses and Function-wrapper identity.

`SetAlgebra.lean` reuses the existing finite request capture and constructor
admission laws. It proves original-output delegation, refusal before coalescing,
original membership, empty output and compatibility with the existing existential
image semantics. Those image repair/inverse laws remain conditional on faithful
backends and stable finite mapping observations. This advances the collection
proposal's future work; it does not prove runtime/GC, arbitrary concurrent writes
during capture or mutable-leaf correctness.

Each multivalued callback adds one shallow spine cell per emitted occurrence;
validation still visits all occurrences before deduplication. Existing registry
capture, source/target admission, indexing and publication costs remain charged.
No target snapshot diff, cache engine, wrapper layer or namespace is added. Design
reflection: capture at the existing Elt boundary and reuse grouped-index ownership,
rather than clone keys or bypass the more specific Set contract.
