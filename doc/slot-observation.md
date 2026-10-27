# Slot observations and cache replay

The MOP exports `call-with-slot-read-observer` and `replay-slot-reads!`.
`object.ss` owns read delivery across `.ref`, `.ref/cached`, `.ref/inline`,
presence queries and name enumeration. There is one value evaluator and one
cycle guard. No consumer needs to patch an object engine or inventory fields.

Internal replay-root consumers may call
`%call-with-recorded-slot-reads action unique-roots?: #t`. The recording frame
retains only the first reference to each original record, using `eq?` identity.
Every delivery still invokes every observer in the original order, including
duplicates and their exception/effect boundaries. No replacement token is made.
The default remains an exact trace: native construction/slot computations use
it to record dependency edge occurrences. Do not compact those signed lists.
The optional identity table belongs only to the bounded recording call; it is
not a registry, source-currentness cache, or approval cache. With no active
recording frame, delivery allocates no collection/table.

```scheme
(def records (make-hash-table-eq))
(def result
  (call-with-slot-read-observer
    (cut hash-put! records <> #t)
    (lambda () (.ref/inline configuration site))
    before: (lambda (receiver key) (check-selected-source receiver key))))
(replay-slot-reads! (hash-keys records) check-selected-source)
```

`check-selected-source` in this example is an application callback, not a POO
export. It may inspect source specifications without recursively observing its
own metadata accesses. Nested observers receive the same actual read tokens.
The `before:` callback runs before the selected getter; replay runs when the
consumer requests it, including immediately before admission returns. An
observer does not itself prove source identity or approve a configuration.

## Record and cache ownership

Each receiver owns its read table, cleared together with its normal cache and
layout. There is no global strong receiver registry. Cold computation captures
actual dependencies even outside an observer, so a value warmed before admission
can later replay them. Failed computations install neither a value nor a record.
A live token retains its receiver intentionally; releasing the receiver and all
consumer tokens leaves ordinary collectible cycles, not a registry root.

Value tokens bind the receiver, mutation revision, instance table, current cell
identity and dependency tokens. Supported edits invalidate them. Bootstrap
anchors bind their explicit constant value and revision without requiring an
instance table during self-hosted construction. Structure tokens retain their
first preparation dependencies, including reads made by MOP preparation hooks.
They enumerate names without demanding unselected field values.

Inline cache hits use the same delivery boundary as ordinary warm reads when a
computation or observer needs dependencies. An inactive hot inline read still
reads its guarded vector cell; it does not redirect through `.ref` or allocate a
new record. The access-site guard retains receiver, revision and layout identity.

A `.ref/cached` miss invokes the native default thunk without computing the slot.
It records **cache absence**, not field absence. Later cache population can make
that observation stale without changing the revision. Defaults have independent
observations because different invocations can depend on different inputs.
False values remain distinguishable from missing cache entries.

## Refusal and scope

### Issuer-owned traversal projection

`call-with-issued-reads` privately retains preorder and receiver membership in
an ordinary native object slot. A weak key/value index locates the cache receiver
by the original root-list identity; it is not a second evaluator or a successful
admission cache. The index is not a strong root for tokens, receivers or cache
owners. Collection may evict it at any time and cause the original DFS to run.

Every hit compares the copied ordered root sequence and authenticates all saved
records in original DFS order. Native issuance checks every dependency sequence
against the original private birth closure; altered edges cannot hide behind a
cached preorder. The private membership table is read-only after construction.
The mutable DFS `seen` table is never retained. Nested protection frames still
enter/unwind independently, and route/currentness checks before delivery and
after the consumer are unchanged. Temporary cache-miss tokens remain valid inputs
without being inserted in receiver read caches.

The retained value describes **structure**, not live validity. Changed receiver
revision, instance/value or filled cache absence still fails the fresh check.
New tokens or changed root order require new structure. A failed construction
installs no cache entry. Source-file checks and final application admission still
belong to their consumers and must run at their original boundaries.

Cold cache-owner construction compares actual native object/state initializer
identities. Replacing either CLOS initializer takes the original non-cached DFS
instead of introducing an opaque callback into authentication. This is derived
from runtime metadata, not a caller-supplied purity marker. The existing trusted
module-initialization and serial supported-runtime premises remain; this does
not claim protection against arbitrary VM/FFI rewriting or concurrent mutation.

The existing `issued-read` suite covers immediate no-GC reuse, root-order change,
forged dependencies, transient-miss staleness without revision change, child
isolation, weak eviction and replaced constructors, in addition to its original
issuance, observer and frame-unwind controls. Its private extern access is only
for checking structural identity; no new public MOP entry is exported.

Replay refuses a stale token with `stale slot dependency` and its key. It does
not rerun potentially effectful getters. Native prototype invalidation remains
unchanged; arbitrary dynamic cross-object reads are validated on replay rather
than silently recomputed. Caller synchronization of mutation/evaluation remains
a prerequisite. Raw struct/cache writes and mutation inside an already cached
container do not become supported revision events.

Source files, JSON origins, domain Contracts, selected contributions and final
plan identity remain application concerns. POO records accesses to their values;
it does not authenticate files, rewrite source provenance, or implement a Loader.
Eager `def-slots` extraction and closures over already-extracted scalars remain
ordinary lexical captures. They are not retroactively receiver-aware references.

## Issuance and selected metadata routes

`object.ss` owns both native issuance and replay; `mop.ss` reexports replay.
`slot-observation.ss` only maintains dynamic observation frames and delivery.
`object-read-issued?` answers whether a record has the native issuer's identity
association and unchanged original payload. It is not a currentness check.

Persistent value/query records and transient cache-miss records use one private
mint. The public seven-argument `make-slot-read` constructs a raw record and
never authenticates it. Minting helpers are not module exports. A private weak
identity map associates a record with its original frozen-payload closure. The
record retains that closure; both map keys and values are weak, so the issuer
does not become a global root. A live transient record remains verifiable after
GC without adding it to the receiver's read/value cache.

Before calling a closure, verification compares its exact identity with the
private association. Borrowing another record's closure, changing a signed
field, or replacing the closure with a true-returning function is refused.
Replay authenticates the complete selected graph before its first observer,
then checks and observes in DFS preorder and repeats native checks in that same
order. A forged child can therefore be refused before a stale authentic root;
this is an entry policy, not diagnostic equivalence for malformed inputs.

The fixed native checker validates actual metadata dispatch: exact table/backend
classes, `ref`, backend hash/equality procedure identities and no backend lock.
It does not call those target methods to authenticate them, rebuild cleared
caches, or force unselected getters. Custom table routes need separate auditing.
The internal native key vocabulary remains closed and bounded.

An observer remains an arbitrary application callback. Persistent replacement
of a checker or metadata route is refused before subsequent dispatch, including
in the final sweep. This is not proof that a callback never changed and restored
external state. Unsafe closure inspection, private issuer mutation, replacement
of trusted runtime primitives and unsynchronized concurrent writes are outside
the supported serial boundary. Source-observer restrictions and external atomic
commit protocols remain consumer responsibilities.

`t/objects/issued-read-test.ss` exercises export privacy, actual persistent/miss issuance,
forgery and payload rejection, complete dependency preflight, metadata-route
replacement before/inside observation, and live/dead transient GC lifetimes.

## Inspecting issuance without granting it

`object-read-issuance` returns five values: the currently presented birth,
registered original birth, originally bound read identity, a fresh seven-field
metadata vector and a copy of the frozen key shape (or false for a symbol key).
A read with no private registry entry has no original/signed snapshot. The
inspector calls only the registry's original closure in its zero-argument copy
branch; it never calls a supplied replacement. The existing one-argument branch
still verifies the same lexical captures. No getter, observer or mutable class
constructor is invoked by the copy branch.

The metadata vector follows the existing read fields: receiver, key, revision,
instance, value, dependency list, checker. Its container and list spines are
copies; referenced object identities are intentionally shared. Reconstructing a
raw read from these fields grants no issuance. Inspection does not register a
miss or warm any selected value. It is a low-level diagnostic/proof interface,
not a new configuration surface or signing API.

A consumer may project these actual registry/environment observations into a
formal model instead of assuming a private Birth. That projection must preserve
live eq? identities, dependency order and revision, and keep cache membership
separate from authority. Endpoint agreement does not certify a callback's
history: a callback can execute an effect and restore metadata before return.
Supported receiver edits still advance revision even when values are restored.

## Receiver ownership while replaying

Replay authenticates the complete selected read graph, then privately collects
its receiver identities. The existing invalidation preflight rejects a supported
edit affecting any receiver in an active replay with `object mutation during
read replay`, before clearing caches or advancing revisions. Nested replay keeps
outer receiver sets; normal and exceptional returns restore the caller's frame.
The frame is private, thread-local and constructed by replay, not by a caller's
purity flag. Replay's public arguments and diagnostic traversal order are unchanged.

An ancestor edit is also rejected if its affected dependency closure reaches a
protected child. Independent unselected receivers are not frozen. Transient
miss records protect their receiver without being inserted into the read cache.
Outside replay, the existing mutation/revision protocol is unchanged.

This guards supported POO edits in a serial callback, not arbitrary raw runtime writes.
`runtime.slot-set!`, generated raw setters, FFI and concurrent writes do not
acquire this frame. In particular, raw metadata modification/restoration still
can execute an effect and leave matching endpoints. This is neither a metadata
write-history certificate nor a rollback mechanism.

## Type catalogs use the same authenticated replay

`reobserve-slot-reads!` is owned by `object.ss`, alongside `replay-slot-reads!`.
`slot-observation.ss` transports observations; it cannot authenticate arbitrary
caller-provided checkers. `optional-validation.ss` imports both replay operations
from the object engine. The public MOP reexports those same bindings.

Both operations enter one private `call-with-issued-reads` scope. It authenticates
the full selected dependency graph before any work/observer callback, derives
the protected receiver set from those records, and checks currentness before
return. Reobservation first checks all records, then delivers the original token
identities to its caller's recording frame. Its work and delivery callbacks stay
inside the same selected receiver frame. A supported write is rejected before
changing a selected receiver; payload/route replacement is rejected on the final
authentication/currentness sweep. No getter is rerun and a transient miss need
not be inserted into its receiver's read cache.

This preserves the new Type catalog's warm-path dependency observations without
giving it a second issuer or a purity annotation. Raw reflective writes, foreign
code and concurrent external changes retain the limitations above. In particular,
these APIs do not authenticate an effect that was changed and restored outside
the supported mutation boundary.

## Unified observation scopes and complete-entry cost

This is a concrete performance refinement of the generalized prototype protocol
proposed as future work. It reuses Gerbil `make-parameter` / `parameterize`, the
existing receiver read records and the existing FUN/IO publication paths.

### Representation and semantics

One private dynamic parameter carries all three existing channels. False disables
observation; capture alone retains the original frame directly; an observer scope
contains that same frame and the original ordered observer/precheck lists. The
already-disabled `without-observation` path invokes its action directly. Active
scopes suppress all channels together. No global publication cache or alternate
object path is introduced.

The standard dynamic environment owns nesting, errors, continuations and thread
inheritance. Recording replaces only the capture frame. Storage deduplication does
not deduplicate delivery; callbacks/prechecks retain order, identity, effects and
original failures. `t/objects/slot-observation-test.ss` covers disabled multivalues/refusal,
nested prechecks, exact repeated reads, continuation escape/reentry and separately
created thread scopes, in addition to the existing stale/replay controls.

The companion Lean `Object/SlotObservation` model reuses `DictionaryBridge` and
proves exact scope unpack/pack, canonical representation, capture-only frame reuse
and preservation of arbitrary interpreted results. Its primitive-cost bound
charges tag tests, field reads and the additional capture-entry premium, including
context allocation when observers already exist. Explicit price assumptions are
required. An expensive-capture counterexample refutes unconditional improvement.
This does not verify Gerbil's compiler, collector, scheduler or arbitrary callback
termination. Scheme neither imports nor locates a Lean checkout.

### Clock and accounting boundary

Gambit `ea114fc` process-statistics uses the system clock for its real-time field.
The original five columns (CPU, real wall, GC CPU, collections, signed allocated
bytes) remain unchanged. An independent released-runtime monotonic duration is
appended as the sixth history field; no real-wall observation is replaced.
Scratch preparation precedes each boundary and observer reporting follows it.
Natural-regime collection is unchanged. Unsupported clock frequency refuses.

The 20-element runtime layout is checked. History fields for faults are the
runtime's `getrusage(RUSAGE_SELF)` minor/major counters, not context switches.
Negative/GC-affected allocation remains raw and unattributable. A clock difference,
wall-minus-CPU residual or context-switch count alone is not a cause or speedup.
The unchanged measurement-observer regression checks actual work, positive elapsed
time, all five result columns, collection placement and exact failure propagation.

### Matched complete-entry receipt, 2026-10-23

Baseline is `071cbf3` with the identical timing harness; candidate changes the
observation representation. Both use the same released Gerbil/Gambit, ordinary
`just benchmark-collections 64 10 6`, 12 standard backend workers, and independent
standard build outputs. Every run retains 219 summaries, fresh fixtures, fixed
prefixes, AB/BA, A/A, B/B, natural/collected/post-GC, forced collection, first call,
full workflow, retry and inverse oracles. Limits remain 1 GiB, 300 seconds for
library/test-program/execution and 90 seconds for benchmark compilation.

Each accepted pair starts by the standard `build.ss benchmark
collection-paired-benchmark clean`, then runs the full entry. Cleaning, dependency
preparation, consumer preparation, compilation, loading and execution are all
charged. This is a benchmark-target-cold study, not a cold OS or cold whole-package
claim. Order is baseline/candidate then candidate/baseline, with no concurrent
owned build or other timed workload. The enclosing standard Scheme process uses
`run-process/batch` and the released runtime monotonic clock; POSIX real time is
retained independently. No production environment selector or scheduler is added.

| Accepted pair | Baseline | Candidate |
| --- | ---: | ---: |
| First complete real wall (s) | 74.34 | 71.26 |
| First complete monotonic (s) | 73.733 | 70.855 |
| First library / program preparation (s) | 10.77 / 2.72 | 11.77 / 2.40 |
| First benchmark compile (s) | 9.62 | 7.36 |
| First loaded CPU / wall (s) | 40.672 / 47.286 | 35.980 / 46.006 |
| First loaded GC CPU (s) | 4.699 | 4.367 |
| Reverse complete real wall (s) | 58.52 | 53.87 |
| Reverse complete monotonic (s) | 58.240 | 53.581 |
| Reverse library / program preparation (s) | 9.06 / 2.04 | 9.11 / 2.12 |
| Reverse benchmark compile (s) | 7.05 | 7.07 |
| Reverse loaded CPU / wall (s) | 36.971 / 37.584 | 32.889 / 33.004 |
| Reverse loaded GC CPU (s) | 4.213 | 3.887 |

Complete real wall improves 3.08 / 4.65 seconds, about 4.1% / 7.9%. The empirical
maximum across these two entries improves 74.34 to 71.26 seconds. Non-GC CPU
improves 4.360 / 3.757 seconds. These are finite paired observations, not a future
latency guarantee. Compiler wall does NOT consistently improve: the reverse pair
is 0.02 seconds worse. The benchmark remains one module with its ordinary three
backend C jobs; there is no claim of eliminating this legitimate cold compilation.

The first post-ablation entry is retained separately: 126.06 seconds, including
61.82 seconds of ordinary `test-program` reconstruction after the build-spec input
changed. It is not paired against a warm consumer or subtracted to manufacture a
complete-entry speedup. Subsequent unchanged consumers reuse standard artifacts.

### Rejected split and retained adverse observations

A three-fixture-module split was tested and withdrawn. Its four complete pairs
were 50.98→53.77, 52.92→47.66, 58.04→56.56 and 98.51→88.31 seconds. The first pair
regressed 2.79 seconds; startup increased 1.458→5.496 seconds. Cold compile pairs
7.32→5.38 and 9.42→10.51 seconds did not establish a consistent compile win.
The extra first-load cost defeated treating module splitting as the optimization.
All fixtures remain in the original benchmark module and no helper package was
introduced. The counterexamples are retained rather than relabeled as passes.

The large residual was reproduced: baseline loaded real/monotonic were both about
74.139 seconds versus 42.779 CPU, leaving 31.361 seconds. Disjoint timed partitions
locate 3.311 seconds in setup, 4.789 in prefixes, 22.234 in measured batches, 0.187
in first calls and 0.061 in explicitly measured GC preparation. Remaining reporting,
untimed collection and oracles together account for only about 0.779 seconds of
the residual. Thus reporting alone cannot explain the old 25.92-second gap.

All 22.234 batch residual seconds occurred with zero measured major faults.
Another fast baseline also had 58 interval major faults but only 0.613 seconds of
whole-loaded residual. Paging counts therefore do not establish the cause. GC
wall minus CPU was about 3.128 seconds in the slow entry, also insufficient.

Adverse within-workflow samples remain. In a candidate B/B control, the SAME
retry action took 0.018971 CPU / 0.150661 wall seconds, with about 0.002213 GC wall
and zero major faults; its sibling took 0.023206 CPU / 0.069035 wall. One cross-run
sample difference reached +14.447 ms per call. This is not accepted as a stable
all-tail speedup merely because the complete-entry maximum improved.

A separate macOS `time -l` diagnostic, still bounded at 1 GiB / 300 seconds,
reported reference/candidate 35.49/34.09 seconds and 9,382/22,921 involuntary context
switches. Those runs did not reproduce the large gap, and switch counts are not
pause durations. Its extra diagnostic permission is not required by normal recipes.
No claim assigns the unresolved off-CPU tail to GC, paging, a particular competing
process or the source transformation. Scheduler/physical wait tails remain an
explicit unresolved performance boundary; no timeout or check was relaxed.

### Reproduction and acceptance

Use two independent standard builds. Install the same released Gerbil compiler and OpenSSL
metadata discoverable by `pkg-config`; run `just build` and the complete suite in
each. Copy the candidate timing-only `benchmarks/closure-measure.ss`,
`benchmarks/collection-paired-benchmark.ss`, matching observer test and POSIX timing recipe
to the baseline. Keep baseline `slot-observation.ss` unchanged. Prepare each
consumer normally, alternate roots in the order above, clean only the benchmark
target through `build.ss`, then invoke the full entry. Retain every stdout/stderr,
exit status, source/artifact identity and failure outside Git. Never compare an
old executable with a different library output or rewrite artifact mtimes.

Initial final-core checks passed all 128 modules / 1,279 cases on both sides.
The final comment/test cleanup is rechecked by the same full bounded suite. Raw
observations, generated JSON and compressed archives are not repository inputs.
