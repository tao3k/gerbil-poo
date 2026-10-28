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
`prototype-map-remove` removes all direct contributions through private ordinal
indices and standard persistent RBTree deletion. It preserves surviving order;
there is no deep-value immutability or verified tree-balancing claim.

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

`t/representations/representation-test.ss` exercises persistent snapshots, duplicate method order,
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
Promotion still pays tree construction. Current tree deletion uses indexed
positions; earlier rebuild measurements below describe the preceding strategy.
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
from an Gerbil interpreter baseline of 124. Cached loads took 3/6/4us and admitted no new modules.
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

## Original fixed-entry baseline

This section records the preceding fixed-entry deployment and its historical
receipts. The current runtime-entry interface and acceptance are documented below;
the historical fixed-entry numbers do not measure dynamic plugin admission.


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
The same `main` is used by the standard-built programs. No Lean checkout,
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

The earlier interpreter-command deployment comparison is withdrawn. Its generated
`gxi -e` expressions bypassed the standard test interface and charged a different
bootstrap graph. The old timing tables are retained only in Git history; they do
not establish a current loading speedup. Current acceptance uses `gerbil test`
and standard-built programs, as described below. Complete service results,
initialization/refusal/recovery controls and the original resource limits remain.


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
per complete operation, demand minus eager wall medians on this local macOS Gerbil compiler build:

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

## Standard runtime entries and shared dependency preparation

The author source (`poof.scrbl`, checkout `9affa8f`, "Different instance
representation" and the staged-computation future-work discussion) motivates
sharing common preparation without replacing observable computation. This unit
advances that implementation/deployment direction; it is not a claim that the
paper implemented or verified Gerbil's loader/compiler.

`io.module-action module binding` is a Reader-compatible IO action in the existing
IO module. Construction checks the two arguments with Gerbil `using` and captures
a private copy of the path; it performs no requested-module discovery. Invocation
uses standard `load-module`, then standard `eval` on the explicit canonical runtime
identifier, then tail `apply` to the original row. No lookup registry, search-path
rewrite, retained procedure or per-field validation wrapper is added. A concrete
binding may be the canonical target of a reexport; export-alias inference is not
performed here. Successful standard reload BETWEEN invocations remains visible.

The loader remains responsible for dependency initialization and its cached errors.
An already visible global binding is NOT module admission: a module can publish a
binding and then fail initialization. The action still refuses through the loader
before looking up that binding. Module-not-found, initialization, missing binding,
nonprocedure apply and business errors retain their standard causes. No rollback
of independently initialized dependencies or arbitrary initializer effects is
promised. Business failures are not cached as initialization errors. Multiple
values, including false, pass through unchanged.

The example executable imports only the common POO/FUN/IO foundation and delegates
the selected business module/binding to this action. Normal `defbuild-script` and
`std/make` own imports, compilation, static object reuse and linking. An invocation
now supplies the explicit module and runtime binding, for example:

```
representation-main -:max-heap=1G,debug=q \
  clan/poo/examples/representation-service \
  clan/poo/examples/representation-service#joint-main 64 indexed
```

`entry-workflow` composes three actions with existing Observation/FUN bind/map:
the checked service lifecycle (shared revisions, shape changes, refusal, recovery)
precedes on-demand checkout preparation and its C3/lens/final-self report. No
business plugin is imported merely to construct an action. The joint result for
width 64 is `#(#(6240 8256 10272 192) (30 33 3))`. Standard module caching shares
code/initialization, never validated receivers or business results. The ordinary
service entry remains available as the explicitly selected `#main` binding.

Public `just example-representation` runs BOTH bindings under BOTH access policies.
The business binding is shared by the independently built dynamic reference and
the shared-foundation program. The shared executable is appropriate for plugins
requiring that foundation: a rebuilt core requires a rebuilt executable, while
optional modules retain standard dynamic loading/reload behavior. Common startup
initializers still run once; their work moves to bootstrap instead of disappearing.

### Cold-process acceptance boundary

`just benchmark-representation-startup` uses the official `gerbil test` harness.
Its two cases each retain 48 fresh child processes: two access policies, four AB/BA pairs and four
A/A plus four B/B controls per policy. Both deployment paths call the SAME compiled
business binding. Every sample verifies that the selected module was absent
before demand; the shared entry additionally requires the foundation to be builtin.
Full result values and one whole-process counter receipt are mandatory. Filesystem
caches are not flushed; these are process/registry-cold, not disk-cold samples.

A standard `read-all` reader timestamps arrival of the successful receipt using the
SAME parent monotonic clock for readiness and process completion. It retains ALL
stdout/stderr rather than waiting for EOF before observing readiness. Raw records
separate receipt latency, complete monotonic lifetime and the interval after the
receipt; the existing process-statistics parent wall remains an independent clock
observation. Post-receipt time includes output/EOF, child exit and process waiting;
it must not be credited entirely to discovery or initialization. This is receipt
arrival, checked against the complete result, not a universal network latency.

Portable time-p retains whole-child CPU. Standard Gambit snapshots additionally
retain pre-exit runtime wall/CPU/GC counters, including bootstrap and loading;
the business time form alone cannot report these stages. Gambit allocation counters
can be NEGATIVE (also observed in its time form), so that column is preserved only
as raw diagnostics and is not admitted as an allocation cost or memory speedup.
CPU snapshots, child lifetime and parent receipt timing have different boundaries.
No lower GC count or cached-module hit alone establishes a cold-entry improvement.

The earlier approximately two-second difference is withdrawn along with the
interpreter-command reference. Both current deployment paths are ordinary
`defbuild-script` executables. The reference is the existing startup module's
closed `main` binding, which admits the current IO action at runtime; the candidate
links the shared foundation. Standard `gerbil test` owns discovery, execution and
failures. There is no generated expression, interpreter subprocess, alternative
runner, loader or compatibility branch. All 96 processes and both controls remain.

The first corrected macOS run admitted all 96 full-result samples. Main's paired
whole-process medians were -174.69/-173.39 ms (symbolic/indexed); joint-main's were
-179.78/-176.45 ms. Successful-receipt medians were approximately -99 to -104 ms,
with another -71 to -78 ms after the receipt. Main symbolic retained a -781.58 ms
pair outlier, and main indexed A/A ranged from -10.86 to +210.67 ms, exceeding
that row's median saving. These are small, controlled observations, not a stable
tail guarantee. They supersede, rather than reproduce, the withdrawn two-second
interpreter comparison. Initial standard preparation reused existing objects
and took 8.43 seconds; it is not a fully cold compiler measurement.

### Proof and design boundaries

The existing Lean Representation namespace models client stages load/resolve/invoke,
with exact failure short-circuiting, current binding results and unchanged argument
rows. Value can denote a bundle of multiple results. A ghost observation of standard
published readiness retains initialization errors until explicit refresh. The
finite dependency cost model counts bootstrap and entry initialization separately:
prelinking removes entry-time discovery/dynamic-admission work for declared common
dependencies, but preserves their TOTAL initializer count. Registry probes, image
mapping, build/link costs, code size, GC and exit work remain separately charged.

These laws assume faithful standard registration/resolution and the supplied
finite required dependency closure. They do not prove arbitrary initializer
purity/termination, effect reordering, module cycles, concurrent reload, compiler
correctness or a latency bound. The concrete two-plugin lifecycle is checked by
source regression and paired receipts. Source startup sharing is advanced here;
arbitrary export discovery, core migration and unrestricted module initialization
remain explicit boundaries, not hidden successes.

## Explicit two-shape offset sites

The author's [Caching subsection](https://github.com/metareflection/poof/blob/9affa8fbbb4f12cbd98cb97f8b8b84474fc39429/ltuo_10_efficient_object_implementation.scrbl#L1140)
proposes one or a few descriptor/offset entries for a constant field identifier,
with guards and general lookup on misses. The concrete remaining workload was
alternating two different layouts: the one-entry site forgot the preceding
layout on every successful switch. This is a bounded implementation refinement,
not automatic PIC/JIT policy selection or a claim of full hash removal.

`make-slot-cache` accepts explicit `shapes: 1` (the unchanged default record) or
`shapes: 2`. The latter extends the existing Gerbil record with two fields: one
immutable previous shape and its certified offset. `slot-cache-offset` exposes
only a recognized offset; `slot-cache-index` uses the existing shape name table
when neither descriptor matches. General LRU machinery would add a hash lookup
and linked nodes to this fixed identity-guard path. No general cache, eviction
framework, name registry or loader is implemented here.

One successful receiver/revision/layout value guard remains authoritative. Both
shape entries read current receiver cells. Successful indexed demand updates the
descriptor history; an evaluator refusal retains both entries and the old value
guard. A successful missing-name fallback clears its primary offset and leaves
the secondary intact. A third different descriptor uses ordinary name lookup and
replaces the older descriptor only after successful indexed demand. Observation
still selects ordinary `.ref` before preparation or cache binding.

The shared service workflow accepts explicit prototype `variants:` and `shapes:`.
The existing C3/refinement/FUN chain runs mixed audit/policy services, shared
approval addition/removal, revision refusal and retry through one action. The
same argument row is exercised through standard `io.module-action`; Gerbil still
owns module discovery, initialization and reloading. False and Function cells
retain their exact values and ordinary wrappers.

Lean's existing `Prototype.Representation` now proves offset soundness, two-shape
working-set closure after two successful reads, success-only publication, current
false/Function delivery and exact lazy refusal. Shape identity must denote an
immutable complete canonical name sequence; supported serialized edits and
receiver-cache fidelity retain their existing premises. Layout name-to-index work is
zero for either remembered descriptor and one for an unknown descriptor. This
bound excludes descriptor comparisons, larger record allocation, shape preparation,
value guards, refinement, evaluation, module loading and GC.

The complete collection study now invokes its importable module through the
existing shared-foundation `representation-main` / `io.module-action` entry.
This avoids a second static link of its full dependency closure; no additional
loader, executable selector or cache registry is introduced. Startup remains
charged by the outer whole-command clock and the reported startup counters.
The original startup reference worker remains a standard executable with its
90-second build bound.
The shared entry declares `std/crypto/digest` as a standard runtime dependency:
the measurement plugin needs its FFI bindings, which a standalone executable
cannot obtain merely from a compiled Scheme import. This is compiler-owned
linkage, not a POO module registry or an arbitrary-FFI admission guarantee.

The complete collection paired study adds `slot-offset-prepare`,
`slot-offset-hot`, `slot-offset-switch`, `slot-offset-churn` and `slot-offset-workflow`. Both sides
use the production reader and differ only in explicit capacity. Common ordered
warming, AB/BA, A/A/B/B, natural/collected regimes and post-GC complete workflows
retain preparation and tail observations. The three-shape control and complete
workflow may regress; no default policy or total-time guarantee follows from
eliminating a hash lookup. Full measurements remain local outputs.

`just benchmark-slot-offset` runs all five offset phases at width 32, 64
repetitions and six AB/BA pairs using the SAME measurement/reporting engine,
including A/A/B/B, matched setup, fixed prefixes and all GC regimes. Default
complete acceptance still runs every collection phase. The focused standard
TestSuite complements that entry and never replaces it. Access-site operations
and supported edits are serialized. Cost correspondence additionally assumes
live canonicalization returns the same descriptor for the same symbol-identity
set; identity guards alone suffice for safety, not for predicting every hit.

The macOS compiler receipt uses Gerbil 1cfb032, width 32, 64 repetitions and
six balanced pairs; the fixed focused entry passed in 59.05 seconds, including
setup, controls, collections and reporting. Both sides use the CURRENT reader;
only capacity differs. It does not measure a previous-revision default reader.
Candidate-minus-single-shape median wall microseconds per action were:

| Action | Natural GC | Collected |
| --- | ---: | ---: |
| Site construction | +0.011 | +0.013 |
| One ready receiver | +0.002 | -0.022 |
| Two-shape traversal | +0.011 | -0.037 |
| Three-shape traversal | +0.156 | +0.108 |
| Complete 32-receiver publication | +224.59 | -2.27 |

Construction allocated 32 extra bytes per two-shape site in zero-collection
samples. Traversal units contain respectively one, two or three receiver reads.
The three-shape natural range was +0.153 to +0.156 microseconds. Complete natural
workflow differences ranged from -403.46 to +524.01 microseconds; collected
differences ranged from -74.45 to +77.02. A/A and B/B controls include millisecond
outliers, so neither a favorable median nor fewer named probes certifies a
whole-workflow speedup.

The inclusive post-GC workflow control charges forced collection and first
invocation as well as the batch. Its median difference was +61.16 microseconds
(+11.80 to +96.30); additive mean components were +31.31 non-GC CPU, +24.32 GC CPU
and +2.14 wall-minus-CPU microseconds. This run's difference includes non-GC CPU
work, but same-side controls preclude attributing it solely to capacity.
Single-shape remains the default, and two-shape capacity
is an explicit semantic/cost option, not a recommended automatic promotion.
Raw samples remain outside Git; these observations are not a stable tail bound.

## Sparse persistent contribution deletion

The author's efficient representation discussion separates lookup indices,
contribution order and cache invalidation. The concrete previous omission was
`prototype-map-remove`: even one removed name rebuilt every remaining ordered
contribution and its name index. Gerbil `std/struct/rbtree` already provides
`rbtree-remove`, so the POO layer now supplies its existing ordinal keys directly.
No balancing algorithm, secondary hash or module cache is implemented.

The private name index stores a single ordinal directly for an ordinary field.
Only duplicate methods need a list, with the first contribution ordinal at its
head and every later duplicate in its tail. Construction uses immutable consing;
first-contribution replacement keeps that head. Removal visits all indexed
positions and removes the one name-index entry. Surviving ordinals retain their
order and are never renumbered. Live contribution count controls compact demotion;
a separate next ordinal controls append, including empty sparse trees. Using
live count as a new key would overwrite an unrelated survivor after deletion.
Old snapshots and opaque false/Function payloads retain their observations.

For a present name with k contributions, the non-demoting path delegates k
ordered removals, one name lookup and one name removal. No complete snapshot
traversal is needed by deletion itself. This is a primitive-work bound, not a
verified RBTree balance, pointer-sharing, integer-bit or wall-time theorem.
Compact demotion exports at most eight remaining contributions. Missing names
return the original map after the ordinary name lookup. Singleton preparation
allocates no position list. Duplicate names retain one cell per contribution and
allocate up to two new cons cells per additional contribution; singleton removal
uses one temporary position cell. The next-ordinal field is also real metadata.

`removal-workflow` composes duplicate local tariff methods, two shared consumers,
C3 fallback after removal, sparse reinsert, static total demand, contract refusal,
retry and whole-source restoration through the existing Reader action. The same
workflow runs with explicit compact policy across promotion/demotion. Ordinary
sealed-edit rejection retains a previously warmed descendant guard.

`Prototype.RepresentationIndex` stays in the existing Representation namespace.
`IndexMatches` requires complete and sound name/ordinal membership; ordinal
freshness requires `PositionsBelow`. With these premises, indexed deletion equals
the authoritative ordered name filter, removes every duplicate, preserves other
indices and allows append after arbitrary gaps. Remembering another contribution
preserves the first ordinal and adds exactly one logical position. Singleton and
list storage normalize to the same finite index in this model. Model String
keys denote injective symbol identities; equal-spelling uninterned controls run
in Gerbil. Standard tree correctness and supported serialized edits are premises.

The complete paired suite adds hot/cold removal, misses, remove/reinsert and full
publication phases. `just benchmark-prototype-map` runs the same engine at width
64, 16 repetitions and six pairs, with AB/BA, A/A/B/B, natural/collected GC and
post-GC cold/full controls. The reference uses the supported public whole-map
rebuild/whole-specification installation. Both strategies use the current index
constructor, so these measurements do NOT certify an old-versus-new cold builder.
Cold/full samples include preparation and complete snapshot observation. The
reference omits its previous initial name probe, favoring rebuilding. All original
checks and limits remain; samples and binaries stay outside Git.

The macOS 1cfb032 receipt (width 64, 16 repetitions, six pairs) completed all five
phases and controls. Candidate-minus-rebuild median wall microseconds per action:

| Action | Natural GC | Collected |
| --- | ---: | ---: |
| Prepared source, delete and export | -65.59 | -68.31 |
| Construct, delete and export | -56.00 | -53.84 |
| Missing-name identity control | +0.007 | +0.007 |
| Delete, reinsert, delete and export | -90.81 | -99.23 |
| Complete shared-service publication | -122.69 | -151.63 |

Every hot/cold/reinsert pair improved in both regimes. All collected workflow
pairs improved (-296.76 to -117.50 microseconds), with zero GC CPU in measured
batches and -152.41 microseconds median CPU. A/A ranges were -45.94 to +24.42 and
B/B -52.36 to +79.94 microseconds. The inclusive post-GC workflow control also
improved in every pair: median -126.40, range -200.23 to -73.42 microseconds.
Its additive mean components were -146.66 non-GC CPU, +12.77 GC CPU and +0.91
wall-minus-CPU microseconds, retaining forced collection and first invocation.

Natural workflow tails still overlap zero (-1,616.70 to +1,482.44 microseconds),
as do natural same-side controls near +/-1.5 milliseconds. No universal natural
tail improvement follows. The whole command took 40.51 seconds, with 9.83 CPU;
reported pre-study process wall/CPU were 31.16/1.70 seconds and the measured
complete study was 7.71 wall seconds. Thus the per-action gains do not establish
whole-command startup acceleration or explain its large pre-study wall residual.
No raw log, versioned data file or archive is committed.

## Owned structural names and bounded read authentication

Public `.all-slots` now returns an owned list spine. Previously it exposed the
receiver's cached canonical directory: editing a returned pair could corrupt
later reflection while a warmed static access site retained a different view.
The existing private `object-slot-names` query retains canonical ownership;
`.alist`, `.for-each!` and `force-object` borrow it internally. They preserve the
same names observation and preparation parents without allocating a temporary
public names list. Symbols, false values, Function values and ordinary mutable
field payloads retain identity. A user field named `names` is not the structural
query key `'(names)`.

The original weak read authority moves into the existing `read-route` module;
there is no second registry, loader or cache. Structural read records expose a
separate names spine, checked against private finite canonical names. The check
recurses over that finite directory, so cyclic or improper presented spines
cannot prolong authentication indefinitely. A damaged cached names record is
replaced only before observed delivery. Revision, preparation parents, current
value cells and warmed static layout remain unchanged. Restoring the old record's
contents does not revive its current identity after replacement.

This selective repair does not rewrite cached dependency graphs containing the
old record. Those graphs still refuse before consumer work. The existing explicit
`uninstantiate-object!` flush permits fresh computation and retry. Ordinary
observer exceptions preserve their exact cause. Supported source revisions still
invalidate old evidence; raw record setters and mutation of the deliberately
borrowed `hash<-object` table remain outside this protocol.

This implements a concrete ownership discipline within the author's cached,
purity-by-default choice (`poof.scrbl`, cache discussion at lines 1533–1553).
It does not implement pervasive language-wide mutation tracking. Gerbil's
standard list map, HashTable, runtime reflection and module-action/FUN/IO remain
the underlying mechanisms. The issuer extraction reduces `object.ss` below 1,000
lines and keeps provenance in its existing functional module. The extra public
copy and observed authentication are real costs: safety is not free.

`benchmarks/names-test.ss` uses the existing paired sampler through `gerbil test`.
Both strategies are safe: public names-plus-lookup is the reference; existing
internal enumeration is the candidate. Cold construction, every result pair,
field read and complete dynamic-entry/refinement/publication work remain charged.
This is not a comparison against the old unsafe implementation. Natural,
collected and inclusive post-GC controls retain AB/BA and A/A/B/B samples.

### Local paired receipt

On macOS with Gerbil 1cfb032 / Gambit ea114fc, 64 additional fields,
16 actions per batch and six cross-side pairs, candidate-minus-reference median
wall microseconds were:

| Complete operation | Natural | Collected | Post-GC batch |
| --- | ---: | ---: | ---: |
| Alist export | -0.44 | -0.38 | n/a |
| Callback enumeration | -0.29 | -0.25 | n/a |
| Observed export and authentication | -0.34 | -2.00 | n/a |
| Construct and export | -9.66 | +6.47 | -11.19 |
| Shared module/refinement/publication workflow | -526.09 | -57.40 | -34.74 |

These are current safe strategies, not before/after revision claims. Collected
cold pairs span -194.70 to +58.11 microseconds. Collected workflow pairs span
-438.50 to +265.20, and post-GC batch pairs -665.83 to +233.69. Natural
workflow pairs span -3,273.38 to +8,022.19; same-side controls also show large
history effects (natural B/B median +751.09). Thus neither cold construction nor
complete-workflow tail acceleration is established. Collected workflow median
CPU difference is only -4.75 microseconds; do not attribute its entire wall
median to saved copying. Every allocation statistic must retain its zero-GC,
nonnegative-counter validity guard.

The command took 27.85 wall seconds; the inner study took 15.79. Process startup
reported 8.88 wall / 2.41 CPU seconds. Those costs are not hidden inside the
sub-microsecond export result and do not establish faster module discovery or
startup. Raw logs remain outside Git. All original checks and limits remain.


The names study's separately CHARGED inclusive workflow includes forced GC and
first invocation: median -41.84, mean -93.40, range -610.07 to +434.74
microseconds. The post-GC batch column above excludes those preparation stages
and must not be described as inclusive. Its natural workflow mean is +644.46
microseconds despite a favorable median; no uniform workflow gain follows.

See [slot-specs.md](slot-specs.md) for super-independent construction and its
separately charged preparation/first-call/GC controls.

### Symbolic mutation admission

The paper presents named slots with Symbol keys (`poof.scrbl:251,384–421`), and
POO's direct read/write protocols already enforce symbolic specification names.
The old removal path instead treated non-symbols as missing names, allowing
`.removeslot!`/`.removedefault!` to invalidate shared owners. `.put!` invalidated
before reaching its symbolic hash. The original non-symbol-removal regression
failed because no key refusal occurred before this edit boundary.

Two standard `using` contracts now close that grammar: persistent map removal and
explicit instance writes. They run before traversal/invalidation, without another
per-method wrapper or namespace. Supported Symbol behavior is unchanged, including
uninterned identity, missing-name revisions, sealed-source refusal and explicit
instance values independent of direct source removal. A rejected key neither
allocates an override table nor clears a warmed shape/vector, source snapshot or
issued credential. Explicit instance assignments remain local, even though\ntheir ordinary invalidation clears descendants; only specification edits change\ninherited contributions. Argument expressions are evaluated before entry and their
side effects are not undone. Invalid-key grammar takes precedence just as existing
prototype-map writes admit keys before mutation preflight.

Regressions retain shared-diamond cache identity and generations across false,
number, string, empty-list and vector key refusals, then verify once-only
invalidation and old-read rejection after a corrected Symbol write. False and
Function payloads keep their identity. `symbolic-edit-workflow` composes these
refusals with the existing checked total/FUN action and fresh successful service
publication. The ordinary standard map study compares valid indexed removal with
a safe snapshot/rebuild strategy; it does not use unsafe invalid-key behavior as
a faster baseline or claim that the new guard makes successful writes faster.

The fixed standard removal study (64 fields, 16 repetitions, six AB/BA and four
A/A/B/B pairs per regime) retained the full oracle and current constructors.
Indexed-minus-safe-rebuild mean/tail differences were -88.00/-85.52 us for hot
natural removal, -61.26/-51.69 us cold natural, and -83.81/-47.95 us cold post-GC.
These are retained indexed-removal benefits, not a causal claim about guard cost.
Complete-workflow mean/tail were +112.03/+1431.57 us natural,
-89.10/+283.49 us collected and -286.63/+209.12 us post-GC. Natural same-side
A/A and B/B tails were +1420.69/+1492.38 us. The adverse samples remain visible;
there is no universal workflow-speedup claim. Inclusive standard entry took 31.57
seconds: root dependency preparation 14.36, startup 2.94 and test entry 13.85
(study 9.56). Zero frontend compilations/backend jobs were emitted.

The first complete macOS check stopped at the unchanged 300-second module-
preparation limit (303.54 inclusive seconds, 7.02 user/1.48 system, no cases).
A same-source/same-product complete diagnostic invocation passed all 150 modules
and 1,899 cases, plus both complete collection/generator paired benchmarks.
A one-second sample of that invocation observed 854/888 main-thread samples in
`dynamic_load`/`dlopen` segment mapping's `fcntl` path; it neither proves the cause
of every loading delay nor certifies cold-loader stability. No security checks,
module inventory, process model, timeout or heap limit were changed. No task
process remained from the timed-out invocation. Raw traces/data stay outside Git.

Replay roots share one cold admission boundary: the standard core `using` /
`list?` contract rejects improper or cyclic caller spines before projection
construction. A warm exact signature is already finite and keeps its original
per-record issuance/freshness checks without another list scan. The cached weak
projection remains an optimization, never a saved validation verdict. Valid root
order, duplicate-node elimination and error messages are retained; malformed root
grammar now precedes entry authentication. Refusal does not undo caller argument
or spine mutation effects. Repairing the spine retries normally, while supported
source revisions keep old records stale even after values are restored.

A diagnostic reproduction reached the cold cyclic-root case and timed out at a
shorter 30-second diagnostic deadline before the fix. The regression also covers
foreign/improper roots, forged entries in proper versus improper lists, empty
roots, damaged warm signatures and corrected retry. `replay-workflow` combines
this boundary with the existing module action, refined checked total and FUN
publication, preserving exact stale-read refusal across source revisions. This
advances the author's scoped cache-invalidation future work, not pervasive host
mutation tracking or proof of module initializer termination.

This unit's focused suite passed all 20 cases. The complete single-process run
passed 150 modules / 1,902 cases in 240.33 seconds at an explicit 300-second test
limit, followed by the unchanged complete collection (14.25 seconds) and generator
(4.30 seconds) paired checks. One second of loading observed 881 samples in
`dynamic_load` / `dlopen`, including 846 in segment mapping / `fcntl`; that window
is not an explanation of the whole run or proof of cold-loader stability.

The unchanged standard names matrix ran separately after builds/checks: 64 fields,
16 repetitions, six AB/BA pairs and four A/A/B/B controls per regime, including
charged post-GC preparation. Full standard entry took 30.71 seconds (dependency
preparation 13.85, startup 2.91, test entry 13.36, study 9.08), with zero frontend
compilations/backend jobs. Borrowed-minus-owned cold mean / empirical p90 were
-6.14/+18.88 us natural, -0.03/+11.50 us collected and -1.19/+16.12 us post-GC.
Full workflow mean / p90 were +603.41/+1568.88 us natural,
+138.99/+810.56 us collected and +10.10/+107.26 us post-GC. Natural same-side
A/A and B/B p90 were +1550.12/+1427.43 us; collected B/B reached +1593.20 us.
The adverse observations remain part of acceptance, not a universal speedup claim.
This compares two safe strategies on the corrected implementation, not an old/new
causal measurement of the guard. The concrete improvement is terminating cold
root admission with no second grammar scan on an exact warm hit; physical GC,
allocation and machine-time claims are outside the finite Lean cost bound.

The common object constructor now owns the complete finite direct descriptor
catalog's dependency registration before C3 or field-definition hooks can run.
Direct `make-object`, `.cc` and the declaration convenience constructor share that
boundary. Previously the convenience constructor registered every descriptor but
raw construction/cloning only registered them as each field was defined: an early
hook could revise a later descriptor without reaching its active receiver. Those
late and convenience-layer duplicate bindings are removed. Discovery/registration
of resolved type objects remains at the existing preparation boundary. Unknown
callback sources, raw field setters and concurrent edits remain outside scope.

The regression first witnessed a successful value where active-construction
refusal was required. Direct definition hooks, clone inheritance hooks, both
compact/tree catalogs, shared source revision and the refined FUN service workflow
cover refusal before cache publication, unchanged source values, repair and normal
post-construction invalidation. `declaration-source-workflow` crosses a failed
first clone construction, retry, two shared services and rejection of old reads.
This advances the author's explicit scoped cache-invalidation future work.

Acceptance passed 22 declaration-index cases and the complete single-process
150-module / 1,904-case suite (243.23 seconds at the explicit 300-second limit),
plus the unchanged collection (13.87 seconds) and generator (3.79 seconds) checks.
The full standard declaration matrix ran separately: 32 fields, 16 repetitions,
six AB/BA pairs and four A/A/B/B controls per regime. Inclusive entry took 75.22
seconds (dependency preparation 13.69, startup 2.88, test entry 57.99; study 53.25),
with no frontend compilations or backend jobs.

Indexed-minus-safe-scan cold mean / empirical p90 were -459.31/+10.43 us natural,
-11.17/+32.38 us collected and +3.78/+37.13 us post-GC. Complete publication
mean / p90 were -3751.43/-2203.69 us, -4177.66/-3928.12 us and
-5672.02/-3926.38 us respectively; shared publication was
-5054.74/-4147.81 us, -3171.11/-2581.19 us and -4601.72/-3823.13 us.
All six complete-workflow pairs favored indexing in each regime. The construction
phase intentionally measures identical constructors: its natural mean / p90
were -15.76/+1427.99 us, so it is a variability control, not an optimization win.
Both query strategies pay the corrected constructor and its earlier descriptor
registration; this is not an old/new causal wall-time comparison of that change.
Only logical repeated known-descriptor binding attempts are removed by the Lean
cost law. Type discovery, cold registration, iterators, construction and GC remain
paid costs, including for a receiver whose fields have not yet been demanded.

Those local 150-module receipts precede the independent test-ownership migration
in `9afe842`; they describe the implementation cohort, not the later compiled
module inventory. The retired tools package is cleaned using its original standard
build declaration and `gerbil clean` before the current standard build, so obsolete
interfaces cannot silently enter the post-integration complete-suite glob. The
latest declared inventory and CI are separate integration acceptance.

Complete finite C3 type preparation closes the next source-binding gap. Before
any `.slot.define` executes, the standard ordered map resolves/registers every
catalog's actual `.type`; standard list builders capture private one-shot actions.
Only after all catalogs resolve do those actions define the original per-catalog
scratch receivers, preserving definition order and incremental scratch visibility.
No pending action is retained on an owner or reused after failure/revision. The
existing weak source graph, invalidation guards and Slot dispatch own all runtime
behavior; no evaluator, namespace, loader or registry is added.

The observable admission policy is explicit: a type-resolution exception (even
`#f`) wins before ALL definition effects; once resolution succeeds, original
first-definition errors still win. Type getters themselves remain ordered and may
have their ordinary effects; this is not rollback or discovery of arbitrary
callback sources. Active receivers protect the registered type identities, including
later C3 branches. Failed attempts publish no scratch method table and repair
resolves fresh identities. Empty catalogs allocate no pending action/scratch.
One-shot closures and family lists are paid cold preparation costs; warm values
or successful old checks never stand in for current source admission.

Reproduce this unit with the existing standard `just build`,
`just test-atomic declaration-index`, `just check-built 2 1 4 300`, and
`just benchmark-declaration-index` entries. The fixed declaration matrix retains
32 fields, 16 repetitions, six AB/BA pairs and four A/A/B/B controls per regime,
including charged GC preparation, cold construction and complete shared-module
publication. Both safe scan/index strategies pay the new complete type phase;
identical construction controls expose variability rather than claiming a causal
old/new optimization. Raw benchmark output stays outside version control.
