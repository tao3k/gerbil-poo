# Persistent prototype maps and guarded slot layouts

This implements the representation protocol acceptance target from TODO.md. The
Racket paper's “Different instance representation” uses balanced maps and delayed
sharing; “Same instance representation, different prototype representation” makes
explicit slot specifications compatible with the same final-self semantics.
Shape sharing, vector offsets and inline sites advance the implementation ideas
in the original representation TODO; they are not a new claim of a complete MOP.

## Current acceptance boundary

This work does not complete every performance idea in TODO.md. Persistent
prototype maps, explicit compact storage, lazy object values, opt-in vector
layouts and supported dependency invalidation are implemented. The instance hash
is still present. Shape-offset reuse across receivers now has a concrete current-
cell path, tests, a finite model and matched workflow studies. Full-vector-only
storage, automatic PIC/JIT selection and arbitrary dynamic module-loading qualification remain
separate optimization/acceptance work, not omitted algorithms of the original
paper. A cached module result is not evidence that fresh expansion, compilation,
linking or initialization is cheap.

Gerbil's installed `runtime/loader.ss:32–69` already implements registry hits,
`loading` synchronization and retained error states. The POO implementation does
not add a loader, evaluator or duplicate module registry. Object-body failures
remain retryable under the existing slot protocol; module error/reload behavior
continues to belong to the standard loader. These failure policies are distinct.

## Protocol and public operations

`prototype-map.ss` uses private compact vectors and V19 `std/struct/rbtree`, not a second tree implementation.
It stores ordered contributions and a first-name index. Persistent updates copy
balanced-tree paths, preserve later same-name methods and append new names. Input
and reflection list spines/entry pairs are owned; values and SlotSpecs are shared.
`prototype-map-remove` removes all direct contributions for a name, rebuilding the
order tree. There is no logarithmic removal or deep-value immutability claim.

The actual `object.ss` constructor, defaults, setters, `.putslot!`, `.putdefault!`
and `.cc` use these snapshots. `.cc` shares unaffected tree paths and rebinds
formulas to the new receiver; it does not retain an evaluated parent instance.
`.removeslot!` and `.removedefault!` expose inherited contributions again.

`slot-layout.ss` weakly interns a sorted unique symbolic shape. Symbol identities,
including uninterned names, determine its process-local order. No serial number
is a disk format or cross-process identity. Each live shape shares its name/index
mapping; each receiver owns its vector cells. Ordinary lookup retains the existing
hash interface. The vector is prepared only by an explicit `object-layout` or
`.ref/inline` access, and successful ordinary reads keep it coherent. This is an
opt-in representation protocol, not a claim that every hash instance was replaced.

A caller creates `make-slot-cache 'total`, then uses `.ref/inline receiver site`.
The site retains one owner, revision, layout and certified index, never a separate
cached result. Every hit requires exact owner/revision/layout identity. Equal
shapes on distinct receivers cannot share cells. Supported parent, protocol,
declaration, slot, default, topology and instance edits invalidate existing values,
compiled methods, ordering, reflection AND layout through the same registered
reverse-dependency closure. A diamond advances each affected owner once. Failed
preflight changes neither snapshots nor guards. Missing slots/errors never install
a successful index; present false remains a real value. An ABA value/shape change
still rejects the previous generation. Removal of a method does not erase an
explicit instance assignment; these are separate existing protocols.

## Integrated acceptance

`t/representation-test.ss` exercises persistent snapshots, duplicate method order,
uninterned symbols, live shape sharing, receiver switching, shared-parent diamonds,
computed values, insert/delete/default/topology changes, failed edits, cycles and
retry. `examples/representation-service.ss` composes checked ObjectContract/refine
with existing Reader/FUN bind and a reusable total access site. Every invocation
still validates the candidate; a layout hit does not substitute for admission.

Lean `Prototype/Representation.lean` proves first-write/frame/removal laws, current
index observations, owner/revision/layout rejection, present-false behavior and
connects stale-revision rejection to existing finite graph invalidation. Executable
controls live in top-level `Examples/Representation.lean`.

The proofs model source-level behavior. They do not verify the RBTree library,
weak table, collector, compiler or physical vector implementation. Token identity
must denote a fixed shape and receiver-local cells. All dependencies must be
registered; supported edits/evaluation are serialized. Raw generated struct setters,
raw instance-hash mutations and unregistered callback dependencies bypass the
protocol. No host process termination, concurrent atomicity, retained-function
revocation or speed/allocation improvement is claimed.

## Remaining optimization ideas

This closes the mapping/layout/invalidation protocol, not every speculative
performance idea in the historical TODO. Patricia trees,
frequency sorting, automatic JIT/PIC selection, full hash removal and compiler
constant-folding qualification remain unimplemented. Matched complete-workflow
benchmarks are required before claiming any strategy is faster.

## Compact persistent prototype maps

The concrete small-map item in the representation TODO is now implemented through
`prototype-map.ss`, without another public namespace or object API. The default policy remains `tree`. Explicit
`prototype-map entries policy: 'compact` selects private vectors through eight
**contributions**, including duplicates. Existing snapshots preserve their policy;
explicit `tree`/`compact` conversion owns a new snapshot with identical entries.
`prototype-map-policy` reports the selected policy, not the current physical backend. A first-name
identity scan selects replacement; appending the ninth contribution promotes to
Gerbil's existing RBTree representation. Removing all contributions for a name
can demote the remaining ordered entries only under the selected compact policy. Missing removal retains the snapshot.
The vector, entry pairs and mutable tree handles never escape; list observations
return fresh spines/pairs, while values and SlotSpecs remain intentionally shared.
This is source-level persistence, not deep immutability of arbitrary values.

The limit bounds a compact scan at eight identity comparisons and a compact
write's resulting row at nine cells, including promotion. Standard vector copying,
`std/vector/vector` filtering and `std/struct/rbtree` perform the storage work.
Promotion still pays tree construction; tree removal still rebuilds in order.
There is no logarithmic removal, universal speedup or allocator/GC cost theorem.

`representation-test.ss` compares 96 mixed revisions and every retained snapshot
with an independent ordered-list oracle. Boundary, duplicate-name, index-zero,
present-false, uninterned-symbol and failed-preflight controls cover both stores.
`expanded-service` crosses the bound through actual persistent object construction;
contraction, overrides, subsequent source edits, checked FUN observation, policy
refusal and retry keep the existing source invalidation/contract protocol.

Lean's existing `Prototype.Representation` namespace proves complete ordered
observations, first-write/frame laws, representation and policy selection/preservation, bounded compact
search/copy and arbitrary finite revision-trace equivalence. Its tree observation
assumes faithful standard-library iteration; distinct Scheme symbol identities
must map to distinct model keys. It does not verify RBTree balancing, vector
primitives, the collector or compiler. Existing revision/layout theorems still
supply cache rejection; changing map storage grants no new cache authority.

`object-scale-benchmark` now records CPU, wall, GC CPU, collection count and raw
allocation deltas via the existing shared Scheme sampler. Both natural and
pre-collected regimes retain the complete cold construction/read, clone-only and
clone/read workflows. Widths 1/4/8/9/16 supplement the original 8/64/256 cases;
all original depths remain. The final executable accepts `natural|collected` and `tree|compact`, exercising
both current policies through the same public map constructor and standard build.
The added cold construction/clone/read phase includes the first promotion inside
its measured workload. Balanced ABBA process order retains all widths/depths. Raw observations stay outside
Git, and GC/history differences must not be reported as selector-only speedups.

## Full-process acceptance and progress

The standard single-process harness retains all 123 compiled test modules, the
1 GiB heap and 300-second deadline. Its existing Gambit process counters now also
observe cases through public `TestSuite` initialization and `TestCase` entry hooks;
`dynamic-wind` records success, failure and continuation exits without replacing
the standard setup/cleanup/check/error/order machinery. No alternate runner,
forced GC, process splitting or new environment variable is used.

For the earlier automatic-compact candidate (before explicit policy selection),
the first complete attempt terminated with exit 137 after 57 modules; it is not
counted as a pass. That candidate's subsequent fully observed process completed 123/123 at
182.87 seconds overall, with 150.46 seconds recorded inside the runner, 34.03 CPU
seconds and 3.64 GC CPU seconds. These are local receipts, not a universal latency
bound or proof that the earlier timeout was caused by GC. The standard released
`gerbil env` context remains necessary for dynamically loaded gxtest tools; a
standalone entry-point probe did not establish complete dynamic-loader readiness.
Raw logs and benchmark binaries remain outside Git. CI must pass at the published
source commit separately from these local receipts.

## Explicit policy after a rejected default experiment

The first automatic compact candidate was rejected as a default: two ABBA samples
per GC regime showed eight-contribution clone-only CPU increasing by 61.1% under
natural GC and 90.9% after collection, aggregating the three retained depths.
Tree reconstruction at persistent promotion is real work; lower aggregate wall
observations did not certify this path. The latest design defaults to standard
trees and exposes compact storage as a deliberate constructor policy. Writes,
promotion, removal/demotion and conversion preserve that choice. Core `using`
rejects unknown policies before construction; the standard `length<=n?` bounds
compact admission without scanning a large input just to choose the backend.

Lean now carries that policy in tree snapshots, proves selection/observation
identity and write/removal/whole-trace policy preservation, and proves that a
default tree write remains a tree even for small rows. A compact scan bound is
not a total allocation bound: promotion still pays the standard tree builder.
This implements the concrete selectable representation protocol. Automatic
JIT/PIC selection and a universal speedup remain unimplemented qualification work.

The final explicit-policy build and all four compiler batches passed. Its complete
single process then checked all 123 modules successfully in 235.51 seconds overall
under the unchanged 300-second/1-GiB bounds (runner: 222.86 wall, 33.04 CPU, 3.49 GC
CPU seconds, 90 collections). This is a separate final-source receipt, not the
earlier automatic-candidate timing. The same-binary policy benchmark uses existing
constant SlotSpec recipes; it measures map construction, receiver binding, first
promotion/clone and reads. Allocation of the input recipes themselves is outside
that workload, and no general fresh-declaration construction speedup is claimed.

## Shared-shape offsets and prepared receiver values

A site's old owner/revision/layout guard still cannot authorize an old value.
`slot-cache-index` separately reuses the fixed-name offset only when canonical
shape identity agrees. On an owner miss, `.ref/inline` reads that index from the
CURRENT receiver's layout. A ready false or checked Function is data; an
uncomputed cell goes through the original lazy `.ref`. Failed computation binds
no new successful guard. Shape changes use the ordinary name/index resolution.
No PIC chain, global result cache, new ownership engine or new namespace is added.

Tracked reads now delegate directly to ordinary `.ref` before any vector
preparation, preserving bootstrap/read-record delivery, current receiver identity
and transitive dependencies. Parent/shape/instance edits
still discard receiver-local layouts through existing invalidation. Replay of
retired observations still refuses. `checked-total-action` continues complete
contract/refine admission before its FUN/IO consumer; shape evidence cannot grant
service approval. The standard cached-load regression preserves the module's
recipe identity and proves with a fresh clone that loading/preparing a layout
has not forced the business formula.

The finite `Prototype.Representation` model keeps `read`'s owner guard and adds
`reuseIndex`/`readPrepared`: equal shape certifies a name/index, but only the
current view supplies a value. Uncomputed/mismatched paths retain their fallback
and its refusal; stored false and opaque Functions remain exact. `resolutionWork`
counts only named-map resolutions: zero for a known shape, one for fallback.
It does not price guard checks, current-cell reads, object/layout construction,
tracking, lazy bodies, hash primitives, allocation or GC. Faithful canonical
shape identity, current layouts after serialized invalidation, stable payloads
and complete registered dependencies remain premises. No compiler/collector or
module-loader correctness proof is claimed.

### Matched slot studies

The existing complete collection study adds seven phases without removing any
original phase. Setup, prefix, first-call and post-GC preparation are retained;
AB/BA, A/A and B/B use identical source recipes and logical traces. Every action
checks its result inside timing. No generated datasets or archives belong in Git.

| Phase | Reference | Candidate and charged work |
| --- | --- | --- |
| slot-prepare | ordinary instance preparation | shape/vector construction, no business demand |
| slot-cold | symbolic `.ref` | fresh instances, site/layout preparation and first lazy demand |
| slot-hot | preceding shared-offset inline algorithm | unchanged-owner hot reads |
| slot-switch | preceding shared-offset inline algorithm | repeated same-shape receiver switching |
| slot-tracked | symbolic `.ref` | ordinary reader fallback, complete observer scope and dependency records |
| slot-revision | symbolic `.ref` | shared-parent changes, invalidation, recomputation and recovery |
| slot-load-workflow | symbolic `.ref` | standard CACHED module load, service clones and first total demand |

The reference inline helper is benchmark-only, used solely where observation is
disabled; it is not a compatibility API. The loader phase does not simulate cold
imports: the standard linked test consumer has already initialized its admitted
libraries. Whole-process startup is separately reported by the existing sampler.
Cold module discovery/expansion/linking and automatic access-policy selection
therefore remain open. A warm switched-read improvement cannot justify choosing
vectors for one-shot consumers; cold/workflow results must guide that decision.

The first paired study exposed extra tracked-read cost; the vector path is not
selected while read observation is active. `selectRead` preserves ordinary
behavior and refuses before layout preparation if the ordinary reader refuses.
The monomorphic/switching reference also retains the original observation-status
check. First measurements that omitted it are not accepted as a hot-read
regression result. The final study must be interpreted against its A/A/B/B
controls, allocation/GC and cold consumer costs.

### Earlier shared-offset qualification receipt and remaining priorities

macOS arm64, released Gerbil `1cfb032`; `just _run-collections 64 3 6` used the
standard linked consumer at `3945928`, before live-layout preparation reuse. Each hot/switch/tracked
operation contains 1,024 reads. Values below are microseconds per COMPLETE
operation, candidate minus its declared reference, paired wall medians. All old
phases, AB/BA, four A/A and four B/B controls, first-call and GC diagnostics remain.
The process completed in 27.38s; this is a local receipt, not a latency guarantee.

| Phase | Natural | Collected |
| --- | ---: | ---: |
| prepare | +94.7 | +88.7 |
| cold | +311.1 | +326.2 |
| hot | -4.2 | -2.9 |
| switch | -122.8 | -123.0 |
| tracked | -181.1 | +28.5 |
| revision | +472.0 | +268.2 |
| cached-load workflow | +420.7 | +235.2 |

Switching won 6/6 collected pairs (range -140.3 to -121.6us). Natural switching
won 5/6, with one +502.4us wall outlier despite a favorable CPU result; A/A and B/B
also retain large signed residuals. Hot reads have small mixed tails, not a
universal tail-latency improvement. Natural tracked gains are GC-history effects:
its paired non-GC median is +24.2us, while collected overhead is +28.5us. Callers
already doing tracked evaluation can use ordinary `.ref` directly. Cold, revision
and load-consumer costs favor the symbolic path here. The implementation therefore
remains opt-in for repeated stable unobserved access; no blanket vector default
or automatic amortization threshold is justified by these samples.

A separate diagnostic ran three FRESH gxi processes under the unchanged 1GiB /
90s limits, calling the standard loader twice. First module loads took 18.392s,
1.006s and 1.071s, each about 1.0s CPU, zero recorded GC, admitting 437 modules
from an SDK baseline of 124. Cached loads took 3/6/4us and admitted no new modules.
OS filesystem caches were not flushed. The first run's large wall residual is not
attributed to eval, hashing, linking or scheduling without further evidence.
This is process-cold loader diagnosis, not a paired implementation comparison.
The linked study separately reports 16.17ms startup with builtin libraries; its
different module graph/load route is not an apples-to-apples startup speedup claim.
Raw observations, probe scripts and binaries remain outside Git.

The next broad acceptance work is (1) cold dynamic loading and project dependency /
metadata preparation attribution using the standard loader, (2) layout memory and
preparation amortization, including a possible full-vector storage backend, and
(3) separately qualified multi-shape/PIC policies. Dynamic hash fallback is still
a supported design choice, not an alleged missing algorithm in the original
paper. No second loader, compatibility chain or compiler verification is needed
for this work; fresh expansion/link/initialization performance remains unclosed.


## Cold pinned hooks and live layout reuse

A self-hosted protocol's pinned hooks are available through ordinary `.ref` even
when unrelated metadata cannot currently be prepared. The prior cold inline
path called `object-layout` first and incorrectly propagated an unrelated
`compute-precedence-list` refusal. This was reproduced after supported cache
invalidation: ordinary hook access returned the exact captured Function while
inline hook access failed. Observation during construction already selected the
ordinary reader; this was a separate cold, unobserved route discrepancy.

The inline boundary now reads a cold pinned hook through `.ref` before creating
an instance/vector or binding a site. Non-anchor fields still require complete
preparation and preserve its exact refusal; retry can prepare the revised value.
A live receiver layout reuses completed preparation directly. Supported edits
clear both layout and instance together; raw generated setters remain outside
this invariant. Existing owner/revision/layout and current-cell guards still
apply, and no slot result, exception, module registry or second evaluator is added.

`checked-kernel-action` and `checked-total-action` share one private Reader/FUN
composition in the existing representation example. The cold hook, consumer,
refusal, retry, source revision and subsequent ordinary field demand are covered
together. Lean's `selectLayoutRead` laws model route selection and exact refusal;
they assume faithful supported invalidation and do not certify arbitrary hook
termination, compiler effects, allocation, module loading or wall-clock costs.

The hot/switch benchmark reference now retains the immediately preceding
shared-offset algorithm, including observer checks and current-cell delivery.
This isolates live preparation reuse from the earlier shape-offset improvement.
All other phase references and all full-suite controls remain unchanged. Earlier
hot/switch numbers above refer to their documented earlier reference and are not
measurements against this new reference.


### Prepared-layout qualification receipt

The final source passed all 148 modules and 1,811 cases in the existing single
process, including the new cold-hook/refusal/retry/FUN regression. The complete
linked collection study then passed every retained phase. An independent
`just _run-collections 64 3 6` completed in 30.13s with no concurrent local build
or full check. Each hot/switch operation performs 1,024 reads; these local paired
wall deltas compare against the immediately preceding shared-offset algorithm:

| Phase | Natural median | Collected median | Observed AB pair ranges |
| --- | ---: | ---: | --- |
| hot | -30.16us | -22.81us | natural -44.27 to -21.93us; collected -25.67 to -18.99us |
| switch | -31.51us | -32.50us | natural -34.65 to -26.70us; collected -37.59 to -27.02us |

All six pairs in each row/regime improved; recorded GC CPU is zero in these
pairs. CPU deltas track the improvements and measured sampler allocation is
unchanged. A/A and B/B remain visible: collected hot A/A includes a -70.33us
signed wall outlier, so these observations are not a universal tail bound.
This demonstrates removal of repeated preparation entry in these workloads,
not general evaluator or module-loader acceleration.

Cold and complete consumer costs still matter. Against ordinary symbolic reads,
collected cold construction remains +282.61us and cached-load/clone/first-demand
workflow remains +256.14us per complete 64-receiver operation. Collected tracked
access remains +29.80us per 1,024 reads; natural tracked gains still include GC
history effects. These workloads retain the ordinary-reader policy rather than
justify blanket promotion. They use a different reference from the hot/switch
rows and must not be mistaken for regressions against the preceding inline code.
Fresh module discovery, expansion, compilation and initialization remain open
qualification work under Gerbil's existing loader/build mechanisms.

## Standard downstream entry and startup qualification

The author source (`poof.scrbl`, mutable/lazy initialization and cache-invalidation
sections) separates delayed field demand from representation choices. Gerbil's
standard loader already caches initialized modules; the POO library does not need
another module registry or evaluator. A fresh-process phase probe found 50 newly
admitted modules at `object`, then 235 at `mop` (about 0.92s CPU in this diagnostic).
The latter graph includes standard JSON/IO/format dependencies. These are actual
standard-library imports, not duplicated POO parser implementations. The probe
uses compiled objects and unflushed filesystem caches; its wall times do not
establish a disk-cold bound or repeated-evaluation defect.

For a known downstream entry, `just example-representation` uses `defbuild-script`
and `std/make` to produce the ordinary loadable `representation-service` module
and the distinct `representation-main` executable. The latter binds the exact
same exported `main`, rather than providing another parser or business engine.
The same `main` can be called after an ordinary `gxi` import. No Lean checkout,
custom load path, environment selector, scheduler or build cache is introduced.
The existing compiler/heap/timeout limits apply. Link/build work is explicit;
this is not automatic discovery or a promise that first compilation is free.

Both roots must be in the build graph. An exe-only experiment produced new SSI
and static code while an old dynamic object remained: a fresh module consumer
reported undefined generated procedures and failed. Declaring a normal module
and exe for the SAME source is rejected by std/make as duplicate files. The final
standard graph therefore uses an importable workflow source and a separate
five-line executable entry, and standard clean/build owns both roots. Regression
coverage preserves the selected source roots, options and clean ownership. No
stale-object fallback or ignored warning is used.

`service-workflow` explicitly inherits one shared recipe, visits all children,
revises the source tariff, refuses a negative tariff before consumer delivery,
and recovers after a fresh revision. An empty batch and invalid command/width
controls are retained. Source copies made by `.cc` are snapshots; live source
revision needs the declared inheritance edge. The consumer action captures its
access choice once through the existing checked-action and Reader/FUN bind.
Symbolic access is the one-shot default and retains lazy ordinary value caching
without a site/vector. Explicit indexed access executes the identical trace;
neither policy reuses admission across receivers. For width 64, both must produce
`#(6240 8256 10272 192)`, including exact successful delivery count.

Lean's existing Representation namespace proves symbolic/prepared-demand equality
under current-cell/evaluator fidelity and lifts it to arbitrary finite ordered
batches with first-refusal semantics. Executable examples cover initial values,
original refusal and current-view recovery. This is a source-result proof, not a
proof of module loading, linking, callback effects or physical startup costs.

`just benchmark-representation-startup` compares the standard runtime-only `load-module`
entry against linking, with four alternating AB/BA pairs
and four A/A plus four B/B controls per access policy. Every child starts a fresh
registry and runs the SAME module `main`; the OS filesystem cache is not flushed.
Parent wall time includes process startup, dependency admission, initialization,
first demand, revisions, refusal/retry, output and exit. The child's standard
`time` form separately retains business CPU/GC/allocation. Portable `/usr/bin/time -p` additionally records whole child CPU. Parent process CPU is
not reported as child CPU. Foreground child deadlines remain in the outer guarded
process group. A refused child or absent success receipt fails qualification;
raw observations remain outside Git. Build setup is charged separately and must
be amortized explicitly before selecting an executable deployment strategy.

A separate CI atom builds and executes both policies and calls the same exported
entry through ordinary module loading, after checking source revision and release
compiler identity. All existing compile/test and single-process checks remain.
This qualifies a concrete fixed-entry deployment path; arbitrary fresh dynamic
modules, full-vector-only storage and automatic multi-shape policies remain open.


### Fixed-entry local receipt and remaining loading costs

macOS arm64, released Gerbil `1cfb032`: the same finite consumer returned
`#(6240 8256 10272 192)` through the standard import, runtime-only loader and exe.
All 148 modules / 1,813 tests and the existing complete collection study passed
under unchanged limits. The final driver was then recompiled through ordinary
qualification and ran all 48 fresh children, with no concurrent local build or
full check. Four alternating pairs plus four A/A and four B/B per policy remained.
Filesystem caches were not flushed. These are process-cold deployment samples,
not physical-disk-cold or cross-platform latency guarantees.

| Access | Runtime-only whole-process wall median (range) | Linked whole-process wall median (range) | Paired linked-minus-runtime median (range) |
| --- | --- | --- | --- |
| symbolic | 2.506s (2.193–2.714s) | 53.70ms (37.62–88.35ms) | -2.431s (-2.670 to -2.156s) |
| indexed | 2.481s (2.401–2.546s) | 42.40ms (40.99–60.31ms) | -2.430s (-2.505 to -2.357s) |

Whole child CPU medians were 2.315s / 25ms for symbolic and 2.380s / 20ms for
indexed. Business CPU medians were only 20.39ms / 15.37ms and 23.94ms / 18.38ms,
respectively. Thus this route qualification does not claim that slots or formulas
became fifty times faster. Loader/image startup accounts for most of the observed
whole-entry difference; exact syscall/VM attribution is not established.

A/A runtime wall ranges remained -98.50 to +147.10ms (symbolic) and -111.45 to
+175.74ms (indexed); linked B/B retained about -46.63 to +0.95ms. All four primary
pairs improved per policy, but these controls and small sample size prohibit a
universal tail bound. Standard business timing retained different GC histories
(runtime about one collection versus linked ten/eleven in representative samples).
Signed negative allocation counters reported by the stock time form remain raw
observations, not claimed allocation savings or byte-cost proofs.

An earlier separate full import-entry study also completed its 48 children and
all controls. Public SSI/import expansion is included there; it is not isolated
`load-module` timing. It showed a large first-policy wall tail and signed A/A
residuals; its medians must not be subtracted from the later runtime-only study
as a paired expander optimization result. No new dynamic import mechanism was
implemented. Both routes remain executable through the same driver using
`just benchmark-representation-startup import` or its default `runtime` reference.

The final paired run's standard build check took 4.43s; construction of the final
module-plus-entry graph earlier took 13.98s using already available dependencies.
Neither is a genuinely cold compiler/SDK measurement. Building before a one-shot
invocation can cost more than a dynamic launch; release/deployment tooling should
prepare the standard artifact once and charge/amortize that setup explicitly.
Full-vector-only storage, automatic shape policies and cheaper arbitrary dynamic
module startup remain unclosed. This unit supplies a reproducible fixed-entry
choice and current-artifact discipline, not a blanket performance default.

## Explicit demand-filled layout cells

`make-slot-cache 'total eager?: #f` captures an explicit creation preference for
selected-field consumers. The default remains eager; this is not an automatic
promotion threshold or a blanket rollout based on fewer allocations. On a cold
layout, `.ref/inline` uses the preference through the existing `object-layout`.
An already allocated layout is shared by the receiver's sites and is reused;
preferences do not retroactively reseed or replace it. Supported invalidation
still discards that receiver layout, and the first subsequent creation selects
its own preference. `object-layout receiver eager?: #f` also exposes explicit
preparation without inventing another protocol or evaluator.

A demand-filled layout keeps the SAME dense finite vector and canonical shape,
but initializes cells with the private unpromoted sentinel. It does not enumerate
ordinary cached values through one `hash-ref` per name or allocate the mapped
value-list just to populate unused cells. Key inventory, deduplication, sorting,
shape interning and dense vector allocation/fill remain real work. The ordinary
instance hash is retained. This is not constant-time construction, a sparse
storage backend or full hash removal.

First demand delegates to `.ref`, including a warmed cached false or exact checked
Function. Only success promotes the value at this receiver's certified index,
then binds the existing owner/revision/layout guard. A refusal promotes no value
and retains the site's previous successful guard. Successful ordinary dependency
computations can still populate their own cells, as before; no evaluator rollback
is claimed. Explicit index writes and named writes share one narrow vector setter,
without new per-read closures, approval caches or result wrapper objects. The
site adds one boolean creation preference; its allocation/guard footprint is not
proved free by the source lookup ledger.

The ordinary direct `object-layout` creation default still seeds cached values
for eager consumers. Raw layout cells now represent the promoted subset when
that layout was created with demand filling. An unpromoted cell is not proof of
field absence or of a body never having been evaluated: ordinary `.ref` remains
the value authority. Existing slot presence, type/refine/evidence, observation and
registered invalidation protocols are unchanged. No result from another owner or
retired generation becomes authorized through shape identity.

Regressions cover warmed false and Function identity without recooking, index
promotion, shared-source revisions, retired read refusal, original error identity,
old-guard retention, retry and rejection of a nonboolean preference. The existing
service example and complete downstream workflow continue to exercise the same
Reader/FUN/contract chain. Lean's existing Representation model adds deferred
views, promotion identity/frame/fidelity, arbitrary finite deferred batches and
explicit initial value-probe counts. Canonical unique names, faithful current
cells and supported serialized invalidation remain premises; no compiler,
collector or module-loader proof is implied.

The complete paired study retains every previous phase and adds preparation,
selected-field workflow and all-field workflow comparisons. Both workflow sides
charge object construction, ordinary warming, fresh access sites, first reads,
source revision/invalidation and recovery. Sites retain the selected preference
across these generations. The reference is explicit eager seeding in the CURRENT
runtime; hot/switch reference code keeps the preceding read algorithm, not a
second production implementation. Preparation measures a predeclared finite key
catalog and ordinary cached table; setup and complete workflows are separately
visible. Few-field and all-field results must both be admitted before making any
automatic policy claim.

### Demand-filled-cell local acceptance

Final explicit-choice source passed all 148 modules and 1,815 cases, including
its multi-service ObjectContract/refine/FUN action with `eager?: #f`. Every prior
collection phase and the three new phases passed. A separate quiet
`just _run-collections 64 3 6` completed in 35.97s. Values below are microseconds
per complete operation, demand minus eager wall medians on this local macOS SDK:

| Phase | Natural | Collected |
| --- | ---: | ---: |
| 64-name shape/vector preparation | -3.70 | -3.70 |
| construction/warm/select/revise/recover | +253.36 | +79.15 |
| construction/warm/read-all/revise/recover | +91.99 | +17.84 |

The final preparation's six collected pairs all improved (-4.61 to -0.32us),
with zero measured GC CPU. A representative GC-free three-operation batch
allocated 85,328 bytes eager versus 76,112 demand-filled. These are local sampler
observations, not a formal byte bound or persistent-heap reduction. The same
64-cell vector and ordinary hash still exist.

Complete-workflow data do NOT establish a stable speedup. Natural selected/all
pairs retain about +230/+206us median GC CPU differences. Collected selected
CPU improved about 12.33us but its wall delta ranged -2.60ms to +0.93ms; collected
all-field CPU increased about 23.67us and wall ranged +2.62us to +4.46ms. A/A and
B/B controls also retain substantial CPU/wall residuals (including collected
all-field B/B +0.454ms median). Medians of these components are not additive,
and the residuals are not attributed to another process or a particular VM cause.
No tail/throughput improvement is certified by a lower initialization count.

Consequently default eager seeding is RETAINED. Selected-field users can request
`make-slot-cache 'field eager?: #f`, or opt in through the example's existing
`checked-total-action ... eager?: #f`; the same shared action builder keeps
complete admission before delivery. All-field callers can keep eager creation.
First layout allocation wins within the receiver generation; no automatic policy
or wrapper chain is introduced. This closes the explicit demand-promotion
capability and its failure/invalidation laws, not broad performance qualification
or arbitrary dynamic-loader startup.

## Certified prior-shape reuse during construction

An inline site's existing layout now supplies a hint to `object-layout` through
`previous:`. `make-slot-layout` first uses the existing standard identity-based
duplicate removal. It reuses the prior immutable shape only when cardinality and
EVERY name's identity membership match. Reordering and repeated catalog entries
are allowed. Additions, removals and equal-spelling distinct uninterned symbols
retain the original canonical sort and standard weak-value `hash-ensure-ref` path.
The shape retains its canonical ordered names alongside its identity hash index;
reuse skips sorting and intern lookup, not inventory or complete-set checking.

Only positions are shared. Fresh cells are seeded from the CURRENT receiver's
ordinary cache, or initialized to the existing unpromoted sentinel. False and
checked Function identity, eager/demand preference, observation routing,
owner/revision/layout guards and refusal/retry behavior remain unchanged. No new
per-read wrapper, registry, loader or evaluator is introduced. Existing live
layouts still return immediately. Supported revisions discard receiver layouts;
an old site can then provide only a freshly checked shape hint.

The author source's prototype metadata discussion (`poof.scrbl`, "A prototype is
more than a function") explicitly separates representation choices from open
recursion; its cache-invalidation section requires deliberate mutation handling.
Gerbil's standard `runtime/loader.ss` already caches initialization and errors.
This unit improves clone preparation AFTER that standard loader, not arbitrary
cold discovery, compilation or initialization. `service-workflow ... layout: #t
reshape?: #t` uses the existing checked Reader action through shared approval
addition/removal, invalid refinement and recovery. The source edit changes shape
without bypassing refinement or forcing unrelated business fields.

Lean's existing Representation namespace proves the full-set certificate from
unique current names, equal length and membership; selected-name/index presence;
current owner/revision/token/field preservation; whole-cache fidelity; and the
existing ordinary value/refusal access law after hint preparation. String identity
stands for faithful Scheme symbol identity. Canonical fallback and runtime index
fidelity remain premises. The work law counts skipped canonical-sort entries;
deduplication, failed-match probes, allocation, current seeding, construction,
GC, standard loader behavior and wall-clock time are not proved free.

The complete paired study adds `slot-shape-prepare`, `slot-shape-workflow` and
`slot-shape-change`, without dropping any prior phase. Preparation uses the SAME
current constructor, with/without `previous:`, including duplicate capture and
eager seeding. Full operations compare the preceding eager inline route with the
production shape-hint route in the same runtime, including successful promotion
on both sides. One existing checked-action boundary admits the receiver before
either route runs; the source gets no redundant layout. Complete operations include standard cached loading,
four fresh inherited services, checked consumers, shared revisions, original
refinement refusal and recovery; change also adds/removes a shared field. AB/BA,
A/A/B/B, natural/collected execution, all prefixes and per-sample wall/CPU/GC
metrics remain mandatory. A cached module is not a fresh-process loading sample.

### Local whole-operation receipt and design review

The unchanged bounded full consumer passed all 148 modules / 1,817 cases and all
study phases. A separate quiet `just _run-collections 64 3 6` passed the COMPLETE
study in 30.40s on the installed macOS V19 release. This is a study duration,
not a paired old/new whole-entry speedup. All raw samples remain outside Git.
Candidate minus reference wall microseconds per complete operation:

| Phase | Natural median (range) | Collected median (range) |
| --- | --- | --- |
| Complete preparation | -5.05 (-216.33 to -4.29) | -8.03 (-9.38 to -4.93) |
| Complete checked service workflow | -288.17 (-401.02 to +100.29) | -227.17 (-292.38 to -191.69) |
| Workflow with shared field addition/removal | -238.34 (-440.68 to +184.30) | -244.82 (-333.63 to -93.30) |

Each collected workflow has six negative wall differences; collected non-GC CPU
medians are -245.67us / -213.83us respectively. Their GC CPU medians are +7.83us /
-8.50us: the improvement is not solely a lower GC count. Components are separately
summarized medians and must not be added. Natural workflow A/A spans -267.66 to
+241.68us, B/B -586.67 to +329.97us; changed-workflow A/A spans -130.73 to +177.30us,
B/B -341.34 to +94.97us. The positive natural tails remain visible. Preparation
also has large natural A/A/B/B wall outliers despite no median GC difference.
This receipt supports these complete workloads, not universal latency or an
arbitrary module-loader speed claim. The small two-field full gate retains its
natural GC counterexamples as well.

The design keeps one shape and one existing access site instead of adding a
metadata registry or memoizing validated receivers/constructors. Effective methods
and checked Function fields depend on final self and revision; only immutable
field positions are safely reusable here. The successful complete-set check has
real linear work, and a mismatch adds checks before the original sorting path.
The change-phase benchmark keeps that cost. Ordinary instance hashes and full
construction/admission still remain; vector-only storage is separate work.
