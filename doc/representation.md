# Persistent prototype maps and guarded slot layouts

This implements the representation protocol acceptance target from TODO.md. The
Racket paper's “Different instance representation” uses balanced maps and delayed
sharing; “Same instance representation, different prototype representation” makes
explicit slot specifications compatible with the same final-self semantics.
Shape sharing, vector offsets and inline sites advance the implementation ideas
in the original representation TODO; they are not a new claim of a complete MOP.

## Current acceptance boundary

Persistent prototype maps, explicit compact storage, lazy primary vector values
and supported dependency invalidation are implemented. Ordinary HashTable reads,
inline sites and reflection share those cells; there is no secondary instance
hash value cache. Source overrides, compiled methods, shape indices and issued
read provenance retain their separate metadata representations. The explicit hash
qualification also owns a single value store. Automatic PIC/JIT selection,
removal of all metadata hashes and arbitrary dynamic module-loading qualification
remain separate research/acceptance boundaries. A cached module result is not
evidence that fresh expansion, compilation, linking or initialization is cheap.

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
mapping; each receiver owns its vector cells. The standard HashTable interface
exposes the primary vector to ordinary lookup, IO and reflection. Instance
preparation allocates uncomputed cells without demanding slot bodies; successful
ordinary and inline reads publish to that same store. `object-layout` exposes
that store by identity, and a site keeps only guards/offsets. There is no seeding
preference or per-site value-policy field.

A caller creates `make-slot-cache 'total`, then uses `.ref/inline receiver site`.
The site retains one owner, revision, layout and certified index, never a separate
cached result. Every hit requires exact owner/revision/layout AND immutable shape identity. Equal
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
raw primary-store mutations and unregistered callback dependencies bypass the
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


## Lazy primary cells

The receiver's primary vector starts with private uncomputed sentinels. False
and wrapped Function values remain ordinary successful values. Ordinary `.ref`
and `.ref/inline` demand the same evaluator and retain its exact successful value;
no second promotion/write is needed. Refused slot-body evaluation adds no target
publication and retains the original cause. Already evaluated dependencies and
callback effects are not rolled back. An observer/consumer refusal after a
successful publication does not undo that memo. Delete/clear make cells demandable again.

The former per-site eager/demand option and record field have been removed.
They controlled seeding of an auxiliary value cache, which no longer exists.
Examples use the same checked Reader/FUN action directly. Direct
`make-slot-layout` construction can still seed explicitly supplied values; that
constructor capability is separate from ordinary object-demand policy.

All prior benchmark scenarios remain. Constructor seeding compares supplied
values with uncomputed cells. Its two complete workflow arms now intentionally
use the SAME current primary-storage protocol and are matched controls. Slot
hot/switch compares ordinary lookup with current inline lookup, not a copied
previous evaluator. Historical auxiliary-cache timings remain in Git history;
they do not qualify this implementation.

## Certified prior-shape reuse during construction

An inline site's existing layout now supplies a hint to `object-layout` through
`previous:`. `make-slot-layout` first uses the existing standard identity-based
duplicate removal. It reuses the prior immutable shape only when cardinality and
EVERY name's identity membership match. Reordering and repeated catalog entries
are allowed. Additions, removals and equal-spelling distinct uninterned symbols
retain the original canonical sort and standard weak-value `hash-ensure-ref` path.
The shape retains its canonical ordered names alongside its identity hash index;
reuse skips sorting and intern lookup, not inventory or complete-set checking.

Only positions are shared. Fresh primary cells contain current explicit source
assignments or the uncomputed sentinel; no old receiver values are copied. False
and checked Function identity, observation routing,
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
explicit value seeding. Full operations compare explicit current preparation
without a hint with the current inline site's automatic shape hint. Both use the
SAME public read operation and primary value authority. One existing checked-action boundary admits the receiver before
either route runs; the source gets no redundant layout. Complete operations include standard cached loading,
four fresh inherited services, checked consumers, shared revisions, original
refinement refusal and recovery; change also adds/removes a shared field. AB/BA,
A/A/B/B, natural/collected execution, all prefixes and per-sample wall/CPU/GC
metrics remain mandatory. A cached module is not a fresh-process loading sample.

### Historical shape-hint receipt and design review

The following receipt predates primary vector storage. Its auxiliary-cache and
preceding-read baselines are retired; it is not a current speedup claim.

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

`object-supers` now returns a standard owned list copy while retaining actual parent
object identities, order and repetitions. Changing or cycling a public snapshot
cannot edit the source graph or its warm C3/value/layout caches. Internal C3,
composition and clone paths borrow `%supers`; constructor `flatten` still captures
its own finite parent tree. This follows the standard list implementation, not a
new snapshot representation or validation wrapper.

`object-supers-set!` directly aliases `replace-object-supers!`. Gerbil's standard
expanded `(set! (getter args ...) value)` invokes `getter-set!`, so generalized
assignment shares the SAME C3/cycle admission, sealed/active preflight, dependency
registration and transitive invalidation. No custom setter macro is needed. The
explicit private `%supers` corruption test retains the independent C3 cycle guard;
raw private setters and concurrent mutation remain outside the supported protocol.
Failed admission does not roll back unrelated callback/preparation effects. Valid
finite input trees keep their original grammar and refusal semantics. A retained
parent snapshot is historical data, not a freshness credential; issued value reads
still reject subsequent source revisions, including restored values.

The existing traversal/composition paired workload now gives both strategies the
same live parent via `object-supers-set!` on a warmed override INSIDE timing.
Public snapshot composition and engine-private borrowing then build equivalent
fresh receivers. Both pay C3 admission, invalidation and the same public result-
parent identity oracle. The complete module/FUN publication uses its existing
composition callback; no extra loader or benchmark runner is introduced. This
expands the workload, so earlier parent-free timings are not a speedup baseline.

Reproduce with standard `just build`, `just test-atomic inheritance-hooks`,
`just check-built 2 1 4 300` and `just benchmark-prototype-traversal`. The full
matrix keeps 64 fields, 16 repetitions, six AB/BA pairs and four A/A/B/B controls
per regime, including charged GC preparation and complete publication. Unsafe
aliasing is never used as a faster reference. Snapshot output cells are only one
component: constructor capture, graph preparation, payload admission and GC stay
paid. Raw traces and full benchmark data remain outside Git.

#### Warm precedence demand

The existing C3 cache now precedes traversal preparation on default queries.
A successful warm `compute-precedence-list!` still returns a fresh list; callers
cannot mutate the retained order. An explicit `heads` argument keeps its original
finite traversal and diagnostic priority. Cache clearing on
supported parent, protocol and source revisions still forces the checked engine;
a previous result never bypasses a new hook refusal. This implements the author's
observation that even inheritance-order recomputation below application code can
be expensive, without extending mutation tracking to arbitrary language effects.

`precedence-cache-workflow` in `examples/inherited-services.ss` combines repeated
C3 queries, a shared declaration diamond, FUN revision and refused topology edits.
The existing `just benchmark-prototype-traversal` includes `c3-hot` and
`c3-workflow`, with AB/BA, A/A, B/B, natural, collected and post-GC controls.
Both sides own public snapshots and run identical result oracles. The reference
retains a nonempty explicit diagnostic context; its standard active table and one
insertion remain charged. The candidate uses default queries. Setup and complete
workflow construction/revision remain measured; this is not a claim that all
observed time differences come from removing an empty table. Cold C3, snapshot
copying, hook execution and GC costs are not removed or inferred from hit counts.

#### Leaf edits and the compiled admission foundation

`object-state` checks the root before choosing invalidation storage. A pristine
post-check leaf advances and clears directly; retained weak tables keep the full
existing traversal, even when empty. A root check that registers children or a
self edge therefore cannot bypass their checks. All graph preflight still precedes
clearing, shared joins clear once, clear results remain Unit and a thrown clear
error does not roll back its already advanced generation. This removes temporary
traversal storage from scratch-field construction without caching an approval.

The standard `representation-main` executable now links the common value-admission
root `object-contract`. Business modules remain cold
standard plugins. This moves their foundation initialization into bootstrap and
charges it in whole-process wall/CPU/GC/readiness measurements; it does not remove
that work. It changes neither `module-action` nor Gerbil's loader or registry.
The ordinary `gerbil test` full-suite path remains unchanged. Its observed macOS
`dlopen/mapSegments/fcntl` waits are external admission evidence, not a proof of
repeated Scheme evaluation or GC, and no security/signing workaround is installed.

`just benchmark-representation-startup` retains the standard dynamic/linked
matrix, with both service bindings, symbolic/indexed access and all AB/BA and
A/A/B/B controls. The linked foundation owns FUN and the complete object-contract
boundary; the business plugin stays cold. Readiness and exit clocks bracket the
actual IO in explicit evaluation order. Fresh process/registry state does not
mean the OS filesystem cache was reset. Historical executable comparisons apply
only to their recorded source/ABI, not to a later module ownership revision.

## Authoritative vector values

The default `slot-value-storage` is `vector`: `object-instance` returns the
standard Gerbil `HashTable` interface over one receiver-local layout. Ordinary
`.ref`, `.ref/cached`, printing, copy/iteration and inline sites share its cells.
`object-layout` exposes that existing layout by identity; it never copies a hash
value table. Creation hints do not erase computed cells. The explicit `hash`
qualification remains a single symbolic value table; inline requests fall back
to ordinary lookup and never create an auxiliary value vector.

`slot-layout.ss` implements the actual core `HashTable` methods using the same
`bind-method!` convention as Gerbil runtime/hash. Unknown successful delegation
prepares a complete new shape/cell arrangement before installing it. Sites retain
the old immutable shape identity separately from the mutable layout. Evaluation
can insert an earlier dependency, so cold binding rechecks the final descriptor
and resolves its final index. Delete/clear leave cells uncomputed; subsequent
hits demand the original cycle-aware evaluator. False and Function identities
remain values. Failures publish no target value or new successful guard; earlier
dependency memoization and callback effects are retained.

The existing invalidation protocol discards instance and exposed layout together
through registered shared descendants. The read-route guard now recognizes the
pinned vector wrapper/ref/backend/shape/missing identities and authenticates its
standard index-table route before calling it. It keeps the old hash route and
read-provenance checks. No successful validation verdict or receiver registry is
added. Raw setters/namespace mutation, arbitrary callback termination, concurrent
cache mutation and runtime/compiler correctness remain outside this protocol.

This advances the author's TODO representation proposal. Compiled method tables,
source overrides, shape indices and provenance still use their existing metadata
representations. Full hash removal, automatic JIT/PIC policy and OS cold-mapping
latency are separate boundaries.

`slot-value-storage` selects a backend only when preparing a new instance. It
does not migrate a live store or create a hash/vector pair. Preparation, fresh
shape costs and GC history remain charged in the study. GC-affected or negative
allocation differences are not admitted as attributable allocation savings.

The existing slot benchmark suite includes the full value-storage study with
shared/fresh shapes, cold/hot access, preparation, exact refusal/retry and paired
FUN service publication. Both strategies run the same evaluator and contracts;
complete setup, prefix, AB/BA, A/A/B/B, natural/collected/post-GC and tails remain
charged. `ValueStorage.lean` proves logical publication/read/reshape laws and a
preparation-sensitive work bound, not allocator or wall-clock speed.

### Unified cell mutation and computed cardinality

Named insertion, certified indexed writes and standard `HashTable` writes share
one cell setter. A named key outside the original shape grows that same layout;
it is never silently dropped. Delete, clear, independent copy and new-table
operations preserve the same presence invariant. A scalar computed-cell count
makes cardinality independent of declared width; it stores no values. Uncomputed
cells contribute zero, while false and Function payloads each contribute one.
Seeded construction and shape growth still pay their preparation/copy cost.

The existing FUN observation example composes lazy demand, a nested write followed
by an exact callback refusal, retry with a Function, independent copy/clear and
source invalidation. Failure retains earlier callback effects without installing
the failed target. Lean proves overwrite/empty/growth/publication cardinality
laws assuming faithful current offsets, disjoint sentinels and serialized mutation.
The paired study adds sparse cardinality and this complete observation chain,
retaining setup, A/A/B/B, AB/BA, GC controls and the preceding workflows. Neither
a constant-time count nor fewer writes establishes a whole-workflow speedup.

The occupancy qualification on macOS retained all preceding phases and added
sparse count and FUN observation phases. The complete standard benchmark entry
finished in 104.06 s (16.04 s library preparation, 3.11 s startup preparation,
83.58 s official runner). Against the current single-hash strategy, vector
observation had a natural paired mean of +13.21 us and upper observed tail of
+14.99 us (six losses); 256 sparse count queries averaged +1.39 us per action.
The existing collected full-service comparison averaged +723.38 us (six losses).
These are current-strategy comparisons, not attribution to the occupancy change;
the hot-read comparison and A/A/B/B controls establish no universal speedup.

The unchanged-source complete check passed 149 modules / 1,981 cases in 75.52 s,
followed by collection and generator checks in 16.26 s and 4.19 s. Earlier attempts
remain failed qualifications: a first full-suite entry reached its 300 s deadline after module loading,
and another attempt hit the independent library's 60 s build guard. That same
isolated control subsequently passed in 34.74 s. A one-second sample of the first
load showed dlopen; it does not attribute the entire interval or prove a cold-load
bound. Heap/deadline limits and all controls remain unchanged. Raw data stays
outside Git.

### Direct vector seeding

Seeded construction now allocates its final receiver-local vector once and fills
it through the existing indexed setter. It no longer allocates a temporary value
list, copies that list to a vector, then scans the vector for occupancy. Empty
construction remains lazy and does not perform a seed pass. Sparse object
initialization still uses the existing entry writes; it is not replaced by an
eager scan of every declaration. Unknown-field growth uses the same seeded
constructor before installing its new shape/cells/count.

Ordered explicit entries still override initial values, with the last entry
winning; false and Function payloads retain identity. Construction refusal does
not replace the caller's existing store, and independent retry remains possible.
The FUN observation chain now grows its shape again after callback refusal and
Function-valued retry, checking the rebound site against the same primary store.
The paired suite retains all preceding scenarios and controls and adds independent
sparse-seed construction/copy/clear, including setup and source independence.

`seedPrimaryCells_values` and `seedPrimaryCells_population` prove finite cell and
occupancy fidelity together; refusal/retry laws assume a private candidate and
faithful canonical names/lookup. The source work model removes one width-sized
occupancy pass. It does not prove Gerbil vector allocation, callbacks, GC, compiler
correctness or a wall-clock improvement.

The direct-seed qualification retained the complete offset/value matrices and
added one sparse-seed phase (16 declared extra names, two present values). Both
current representations receive the same source, construct an independent store,
and clear the result while checking that the source is intact. The complete
standard entry passed in 123.38 s: library preparation 15.01 s, startup 2.98 s,
runner 104.26 s. Vector-minus-symbolic-hash natural seed construction averaged
+6.21 us, with observed upper tail +6.38 us and six losses. Natural same-side
means were -0.034 us (hash) and +0.060 us (vector). This is a representation
comparison, not a before/after attribution to the fused constructor.

The FUN observation now includes another shape growth after Function-valued
retry; its workload differs from the preceding receipt. In this cohort its
natural vector-minus-hash mean was +22.55 us, upper tail +27.45 us (six losses).
The retained collected full-service comparison averaged +691.07 us, upper tail
+777.26 us (six losses). Hot natural reads averaged -0.032 us, with upper tail
zero; these samples do not establish a general latency advantage. Explicit setter
presence checks, shape canonicalization and metadata preparation remain real work.
The removed temporary list/count pass is not presented as a physical memory or
wall-clock proof.

After integrating the existing shared model-shrink changes, the unchanged Slot
sources passed all 149 modules / 1,985 cases in 154.08 s, including the independent
stdlib-only package's 50-case control. Collection and generator checks passed in
24.09 s and 7.02 s. A preceding cold complete entry reached its fixed deadline
(exit 124, 304.32 s including termination grace), following a long initial module
load; a one-second sample then showed dlopen, not an attribution of the whole
interval. The initial cold test-package build also hit 300 s; normal standard
incremental completion and the integrated build later passed. These failed cold
qualifications remain distinct from the successful current tests. No workload,
heap, deadline or negative control was reduced. Raw observations remain outside Git.

### Evicted inline demand and final-shape publication

A previously warmed site can still point at an uncomputed cell after standard
HashTable deletion/clear. The preceding hit branch returned ordinary demand
without rebinding; if demand grew the dynamic shape, the successful read left a
stale site. A source regression reproduced a correct Function value followed by
`slot-cache-hit? = #f` instead of the final offset 2.

Cold reads and evicted warm cells now share the existing successful binding path.
The fast hit reads the current primary vector once; ordinary `.ref` remains the
evaluator and publisher for demanded values. Recovery captures the shape before demand and
resolves the final offset when that shape changes. Failure does not publish a new
guard, successful fallback without an index has no indexed credential, and later source revisions
still reject old owner/revision/layout/shape credentials. No value cache, loader,
namespace or new wrapper is introduced.

The FUN Reader example combines two dynamic dependency insertions, deletion,
exact callback refusal with retained dependencies, Function-valued retry, shared
diamond revision and explicit false assignment. The finite Lean model proves
final-site validity/read fidelity, identical cold/warm success publication,
refusal/unindexed semantics, revision rejection and zero next-read named
resolution under unchanged guards. Host index fidelity, serialized supported
mutation, sentinel separation and callback behavior remain premises; these laws
do not prove GC, allocation, compiler correctness or wall-clock speedup.

The regression was first run against the preceding public implementation: it
returned the Function but the post-demand guard was false rather than offset 2.
The corrected implementation passes the same assertion plus the FUN chain on
both current storage strategies. The redemand qualification checks the current
primary authority on both sides: a current indexed guard for vector storage and
field membership in the current HashTable for the symbolic strategy. An earlier
experimental comparison short-circuited that assertion for hash; those raw
observations were withdrawn before publication, not used as performance evidence.

The balanced complete standard benchmark entry passed in 100.00 s (library
preparation 14.52 s, startup 2.73 s, official runner 81.49 s). All preceding offset
and value-storage phases, workloads, pairs, A/A/B/B, AB/BA, GC controls and tails
remain; one bounded redemand phase was added. Its natural vector-minus-hash mean
was +30.62 us, upper observed tail +33.42 us (six losses). Same-side natural means
were -2.91 us (hash) and -5.63 us (vector). The post-GC redemand mean was +29.89 us,
upper tail +38.06 us (six losses); its charged 17-call component normalization
reported +27.96 us non-GC, zero GC delta and +0.17 us residual for the batch.
These components are diagnostic differences, not a causal construction profile.
The full-service collected comparison still averaged +717.86 us, upper tail
+819.86 us (six losses). Hot natural reads averaged -0.022 us, upper tail +0.060 us,
with three wins and three losses. This qualifies correctness and exposes remaining
cost; it establishes neither universal speedup nor a before/after latency claim.

The balanced frozen-source complete check passed 149 modules / 1,992 cases in
299.60 s, including the independent stdlib-only package's 55-case control. It
finished within the unchanged 300 s deadline, with little margin; this is not a
stable cold-entry bound. Collection and generator checks passed in 15.59 s and
7.66 s. A prior cohort passed the same inventory in 270.62 s; it is not merged
with the balanced benchmark history. All heap/deadline/check inventories remain
unchanged. Local qualification used the Slot change atop 13a3000; later existing
PBT handoff changes are admitted separately by the merged commit's complete CI.
Raw observations remain outside Git.


### Sparse growth and retained recovery guards

Single-key growth now uses the existing canonical weak shape table and Gerbil's
standard `vector-copy!` for the two old segments. It skips redundant duplicate-name
filtering and per-old-cell HashTable lookups/setters. The private candidate keeps
the old occupancy count, admits the inserted cell through the ordinary setter,
and publishes shape/cells/count only after preparation succeeds. False, functions
and uncomputed cells retain their exact identity; copying a table still owns its
own cells. Canonical symbolic order and serialized supported mutation are premises.

After successful demand, a guard checked again after the callback survives
when it still names this owner/revision/layout/shape. A negative control with explicit
nested rebinding through the public site API rejects elision based only on the
pre-callback hit; the final implementation checks the post-callback guard. Cold or changed-shape sites still bind the final certified offset;
refusal preserves the original exception and prior credential. Lean proves
credential identity, exact recovery of the old sparse segments, occupancy transfer
and elimination of old-value named probes. Bulk copies still visit all old cells;
these source laws do not establish a wall-clock or physical-GC improvement.

The existing paired engine retains the complete recovery workflow and all A/A,
B/B, AB/BA and GC controls. Added growth and guard-eviction phases charge fresh
preparation or ordinary demand respectively. Value workloads now live beside the
existing representation workloads, keeping the measurement engine below 1,000
lines without adding a runtime module or another cache.

The final frozen Slot cohort atop 366d175 passed the first post-build complete
standard check: 149 modules / 2,004 cases, including the isolated stdlib-only
55-case control. The test process took 252.23 s (82.55 s user, 7.02 s system);
collection and generator checks took 22.90 s and 4.10 s. The test deadline stays
300 s with 1-GiB heap; workload and negative controls are unchanged. This run
included four bounded two-second read-only stack samples, so its duration is a
diagnostic receipt, not an uninstrumented before/after speedup measurement.

At separated startup observations, the main process had used 2.47 s CPU after
45 s elapsed and 4.27 s after 114 s. All three startup samples were dominated by
`___dynamic_load` / `dlopen` / `mapSegments` / `fcntl`; the later independent-package
control sample waited in `__select`. These samples distinguish loader/process
waiting from POO evaluation and GC; they neither attribute every unsampled second
nor establish a cold-loading bound. No security policy, loader or resource limit
is changed. Lean's complete 20-phase check passed in 103.48 s.

The uninstrumented fixed paired entry completed in 124.41 s (standard root
preparation 19.51 s, executable startup 2.84 s, official test runner 101.02 s).
Both complete offset and value-storage studies passed with every existing pair,
workload and control retained. Recovery candidate-minus-current-hash natural
mean was +24.87 us, empirical upper tail/max +29.68 us, all six losses; A/A mean
+0.48 us and B/B -3.33 us. Post-GC recovery mean was +24.77 us, max +27.19 us.
The batch component's normalized non-GC difference was +23.31 us, GC zero and
wall residual approximately zero (the existing component denominator is 17;
this is not a causal per-operation construction profile). Fresh-store-plus-growth
natural mean was +7.57 us; unchanged-guard eviction/demand +0.360 us. The former
includes preparation and cannot be subtracted from recovery to isolate growth.

These measurements expose a remaining systematic non-GC recovery cost; they do
not close the vector/hash latency gap. The historical +30.62/+33.42 us recovery
mean/tail used a different process/GC history, so the apparent reduction is not
claimed as a controlled before/after speedup. No result is justified by reduced
allocation alone. Raw paired observations and stack traces stay outside Git.

The broader service workflow also remains unqualified for a speedup: natural
candidate-minus-hash mean +1,299.18 us, maximum +4,647.25 us, three losses in six;
A/A and B/B means were -1,110.67 and -1,070.97 us, demonstrating substantial
history variation. Post-GC mean was +751.26 us, max +942.42 us, six losses.
Its normalized batch difference included +676.38 us non-GC, +25.32 us GC and
+5.36 us residual. Recovery's smaller operation count must not stand in for
this broader result or for a full-service latency guarantee.

### macOS loader diagnosis and complete-check deadline

The complete-suite deadline is now explicitly 600 seconds in both `justfile`
and CI, following the requested budget change. The earlier implicit default was
900 seconds; previous explicit 300-second local checks and default CI checks were
therefore different qualifications. Compiler deadlines, 1-GiB test heaps,
2-GiB backend heaps, all suites, and cleanup remain unchanged.

On the same frozen source, standard `gerbil clean` followed by `just build`
took 295.44 seconds (library 115.96, startup package 7.17, test packages 171.30).
An initially empty package prefix took 298.74 seconds. Standard clean removes
Gerbil interface/static sources but retains Gambit's versioned dynamic objects;
neither measurement clears the OS page or validation caches. These are separate
build cohorts, not evidence that deleting objects improves total build time.
The following first full checks exceeded 300 seconds: harness preparation took
189, 208, and 276 seconds in separate observations. The last control also ran
outside the tool sandbox; it did not remove the delay.

Read-only startup stacks locate the dominant sampled wait in
`dlopen -> mapSegments -> fcntl`. The installed dyld instruction at the sampled
return address passes command 98 (`F_CHECK_LV`), identifying library validation.
This does not identify the policy provider or attribute all unsampled wall time.
The official Gerbil loader already caches successful module identities under its
load mutex; no second POO loader or initialization registry is introduced.
Previously observed post-OK stacks instead enter `dlclose`, debugger unload
notification, and image-atlas maintenance. Those loader allocations are distinct
from Scheme heap GC. No signature checking, unloading, or cleanup is bypassed.

The isolated standard-library package control now streams prefixed child output
using `run-process`'s standard coprocess interface and preserves its exact captured
text, exception, and status checks. START/END timestamps include child cleanup;
END is emitted only after the standard process API returns successfully. This
exposes compilation/loading waits without counting child cases as parent cases
or adding a heartbeat. Its existing 60-second per-command limits remain intact.

A subsequent diagnostic complete entry naturally exited: 149 modules / 2,014
cases, including the isolated 55-case control; main test 155.93 seconds and the
whole test/collection/generator entry 180.83 seconds. A ten-second Time Profiler
attachment observed dyld allocator and atlas serialization work during this run.
It is a warm, instrumented qualification, not a cold speedup receipt or proof
that the library-validation delay is fixed. The cold-loader performance issue
remains open. Existing Lean laws concern source-level caching and preparation;
they do not prove macOS policy latency or physical cleanup time.

After normally merging the concurrent PBT changes, the standard incremental build
completed in 198.70 seconds (library 44.26, startup package 3.62, all 25 test
packages 149.83). The first subsequent uninstrumented complete check naturally
exited with 149 modules / 2,027 cases: main test 119.87 seconds, collections 14.10,
generators 2.52, whole entry 138.30. A read-only log observer measured approximately
8.27 seconds from main `OK` to the test command's natural return; this includes
cleanup and reporting, not exclusively dyld. The isolated fresh package used
26.98 seconds for build and 5.89 for its 55-case test. This is a post-incremental-
build qualification with the existing package prefix, not an empty-prefix cold
comparison. It preserves the full workload and does not establish that the
previous 276-second library-validation episode cannot recur.

### Bounded standard compiler sessions

The build audit found repeated preparation. Concurrent progress fragments can
interleave, so raw parsed log counts are not used as an exact job inventory.
The completed source-matched controls each retain 149 test interfaces and 310
first-version test loader/runtime/meta objects. Each of the 25 original test
packages started its own package CLI and compiler, imported common compiler/POO contexts, and unloaded
them at exit. An actually empty project prefix then exceeded the unchanged
300-second test-build phase: library 118.10 s, startup program 8.55 s, overall
427.58 s with exit 124. It is a failed baseline, not a completed speed measurement.
The installed compiler/release and OS caches were not removed.

One all-test graph overflowed the 1-GiB compiler frontend before compilation;
sequential groups in one session also overflowed at group 6. With the explicitly
authorized 2-GiB frontend ceiling, that session still overflowed at group 15.
The standard expander retains module contexts for the session lifetime. Clearing
its private registry or growing the heap is not the repair.

Compiler-only standard packages now bound those context lifetimes by collections,
indexes, prototypes, contracts, types and publication. Their empty `gerbil.pkg`
descriptors add no installed library namespace. The existing `t/build.ss` owns one
ordinary make-spec inventory; the original 25 CI packages select it unchanged.
The four local builders use the same source paths and `clan/poo/t` output prefix.
Gerbil still owns dependency discovery, freshness, code generation and backend
jobs. Just's standard `[parallel]`/`--jobs` owns concurrent recipes; no custom queue,
source scanner, loader or persistent cache has been added.

On the 12-core machine, four active compiler sessions use two backends each;
Just queues the six functional parts without increasing that capacity. Compiler
frontends and backends remain capped at 2 GiB; the waiting package CLIs and test
processes retain their original 1-GiB bounds. The original outer 300-second phase
owns the complete compiler process tree; redundant nested timeout groups are
removed. TERM and resistant-KILL controls each started four recorded descendants
and left none. These are negative controls, not successful application exits.
RSS snapshots around 1.0–2.1 GiB are observations, not aggregate memory bounds.
Lean's `BuildPreparation.lean` separates configured ceilings from physical RSS,
bounds active capacities, and counts repeated common preparation requests.

Earlier matched project-artifact-empty cohorts used source base `b6ca3ea`, four
functional parts, and the same
149 compiled suites / 2,037 cases, plus three source-only build-declaration cases:

| Standard Just / Gerbil policy | Library | Startup program | Test build | Complete `just check 2 1 4 600` |
| --- | ---: | ---: | ---: | ---: |
| Two active sessions, five backends each | 154.49 s | 10.37 s | 269.75 s | 833.00 s |
| Four active sessions, two backends each | 106.43 s | 7.46 s | 242.15 s | 725.52 s |

Both entries naturally exited zero, including normal cleanup and the complete
collection/generator studies. The four-session build-stage timers sum to 356.04 s;
that sum excludes task-launch overhead and is not a separately measured build-only
wall clock. Root library settings/work were unchanged, yet its time varied; the
full test processes also varied (372.07 / 328.72 s). Therefore the entire observed
entry difference is not attributed to scheduling, and no stable tail/speedup or
exclusive dyld/GC latency bound is claimed. The earlier 512.41-s standard-clean
build retained versioned dynamic objects and is a different coldness definition.

A repeated complete build naturally exited in 56.49 s with zero compilation jobs.
Touching the two existing ordered/mapping include files rebuilt only their two
registered targets; original timestamps and contents were restored. Their focused
standard tests passed. Declaration regressions also retain the included-source
paths, distinct package inventory and refusal on an unknown package. All 149
installed test interfaces had compiled loader objects; interface counts alone
were not accepted as build success. Build data/traces remain outside Git. These are
infrastructure/cache-cost results, not completion of a paper feature or compiler
correctness verification; cold dyld admission remains a separate measured limit.

After merging the independent property-test changes through `a724da4`, the full
unchanged entry naturally exited zero in 391.69 s. It ran all 149 compiled
modules / 2,052 cases and the source-only declaration suite / three cases, plus
the collection and generator studies. Its test build took 150.70 s and its
single-process tests took 149.08 s. This source-current acceptance reused standard
artifacts and is not another cold-performance sample.

A later empty-prefix control at `76ce5e6` failed the same 300-second test-build
deadline (whole entry 483.87 s). Its root-library phase finished in 170.86 s;
the final backend was compiling the 261,065-line generated `table.c`. A short GCC
sample identified dominator/range propagation work. Samples of the remaining test
frontends showed child/backend waits, not evidence that those intervals were dyld
unloading. An isolated test host-layout threshold candidate also failed and was
withdrawn; compiler flags and optimization remain unchanged.

The six-part queue splits the largest collection and contract context inventories
while retaining four workers, their backend limits, all 25 CI groups and all 149
test modules. Bash's standard `time` labels each actual package completion; it
adds no watchdog or configuration interface. This scopes existing standard caches
instead of replacing them, and makes the late queue visible.

Its empty-prefix complete entry naturally exited zero in 742.39 s: root library
123.97 s, startup program 7.38 s, test build 211.17 s, full tests 376.02 s,
declaration tests 1.26 s, collections 16.23 s and generators 4.15 s. All 149
compiled modules / 2,052 cases and three declaration cases passed. The source
base was `76ce5e6` with the six-part build-only change; later property-test changes
require separate source-current acceptance. The compiler-stage timer sum is
342.52 s, not another measured build-only entry. This closes this control's
300-second compile refusal, but the full wall time does not qualify an improvement
over the older 725.52-s cohort. No stable latency/tail claim follows from it.

Two short samples in first test loading showed `dlopen -> mapSegments -> fcntl`;
they identify waits in those windows, not ownership of the entire 376.02 s.
Repeated complete `just build` then naturally exited in 45.10 s with zero
compilation events (root 18.64 s, startup 3.11 s, six-part queue 22.36 s).
The unchanged 3-second failure escalation also reaps queued dependencies that
Just may start after TERM: the TERM control needed KILL/137 and all 18 recorded
descendants disappeared; the resistant control exited 137 with all 12 gone.
Probe permission errors are failures, not interpreted as absent processes. These
negative controls are distinct from the successful natural application exits.

After merging the property proposal-admission update through `a915460`, the full
source-current entry also naturally exited zero: all 149 compiled modules / 2,057
cases, the three declaration cases and both studies passed. Its standard build
rebuilt the changed dependency closure (test phase 108.65 s); full tests took
154.37 s. This reused prefix is functional acceptance, not an empty-prefix
performance cohort or a claim that the first-load wait is fixed.

### Fixed-source first-load controls

The standard Just dependency graph now starts contracts, types, indexes and
collections before the two shorter prototype/publication tails. No worker,
backend, heap, deadline or test is added or removed. This avoids relying on
parallel sibling launch order: one earlier control started collections only at
282.151 seconds and failed the unchanged 300-second preparation deadline.
The source-only declaration suite checks the actual `just --dump` graph.

A fixed-source ABBA comparison kept the same canonical checkout path, compiler,
12-core / four-package / two-backend configuration, initially absent package
prefixes and full `just check 2 1 4 600` entry. The baseline was `6b6027e`,
before the subsequent independent property-test changes. All controls used
Gerbil `1cfb032` / Gambit `ea114fc` from the same installed compiler on macOS
26.6.1. Compiler and OS caches were not purged; these are empty-project-prefix
controls, not reboot-cold measurements.
All four successful runs retained the same ordered 2,108-case trace and exited
naturally, including the source-only checks and both studies.

| Physical test layout | Full wall seconds | Preparation wall seconds |
| --- | --- | --- |
| Existing 144 modules, forward | 616.73 | 176.93 |
| Candidate 131 modules, forward | 702.81 | 177.75 |
| Candidate 131 modules, reverse | 600.57 | 170.08 |
| Existing 144 modules, reverse | 620.48 | 177.36 |

The candidate does not establish a stable wall/tail improvement and was withdrawn.
Its changed module layout is not part of this PR. The successful baseline
preparation phases took 158.98 and 145.11 seconds, below the unchanged deadline;
these observations do not prove a deadline on arbitrary machines.

The first/last standard TestModule fixtures report cumulative process CPU, wall,
GC CPU, GC wall, collection count and raw allocation. The existing complete-entry
observer checks both boundaries and monotonic GC/non-GC CPU before accepting the
record. Raw allocation can be signed and is not treated as live bytes or a cost.
The counters include bootstrap and initialization; they do not isolate either.
Across these four first-load controls, preparation used only 5.52–7.03 seconds
of process CPU and 0.114–0.139 seconds of GC CPU against 170.08–177.75 seconds
of wall time. This rules out own-process CPU/GC as the dominant measured component,
not external child or system work. A separate two-second diagnostic of the
standard runner found 168 of 172 loading stack samples in
`dyld -> mapSegments -> fcntl`; this identifies that sampled wait, not an exclusive
timer for the whole residual. Profiling runs are not included in the timing table.

Lean's `ProcessCounters.delta_partition` proves the exact abstract CPU split
under valid cumulative snapshots and monotone GC/non-GC components. It does not
verify floating-point measurements, the compiler, macOS loading, or a latency
bound. EOF and successful natural process exit remain separate admission checks.

After normally merging the independent property-testing work through `82232c1`,
the unchanged complete entry naturally exited zero in 411.38 seconds: 144 compiled
modules / 2,130 cases, five source-only declaration checks, and both studies passed.
This reused a prepared prefix and overlapped Lean functional verification; it is
source-current functional acceptance, not a cold timing sample or a speedup claim.

### Optional helper dependency closure

The standard loader's complete diagnostic inventory contained 796 entries:
80 built-ins and 716 file-backed Gerbil images. Those files had 716 distinct
device/inode identities; the inventory does not show duplicate physical aliases.
413 were project images (330 phase-zero and 83 phase-one), and 303 belonged to
the compiler/standard library. This is the loader inventory, not an exhaustive
inventory of macOS system mappings. Minimal source and compiled diagnostic
controls already included the same 26 compiler images. They cannot all be
attributed to an accidental POO dependency.

Two unnecessary eager roots were identified: ordinary DDT and ordinary test
assertions imported the typed property engine through `debug.ss` and
`support/testing.ss`. Their optional property operations now compose the existing
IO `module-action` with standard `compose`/`list`. The standard loader still owns
discovery, initialization, synchronization and retained failures; no binding,
result or module registry is cached here. Diagnostics and the standard TestError
admission gate follow the same demand boundary. The declaration test observes
public expander import descriptors, without a source scanner or recursive resolver.
The existing recovered-command example exercises wrapped Function fields, named
assertions, keyword-valued data, replay and cleanup through the unchanged protocol.

Demand changes when an optional initializer runs: a dormant helper does not
initialize it; an actual request retains its errors. This does not equate arbitrary
eager/delayed global side effects. A standard logical loader entry can admit extra
entry-stub images even if a body was already initialized. This is real routing
work, not evidence that the body was initialized twice. Likewise, the official
JSON dependency reaches std/io/socket support; no replacement parser is introduced.
Thirteen test-owned macro images were also identified, including private fqcheck
helpers; lexical scoping is a separate unqualified candidate, not a claimed fix.

The fixed-source ABBA controls used eager `316b7fc` and deferred `b13b78b`, the
same canonical source path, Gerbil `1cfb032` / Gambit `ea114fc`, macOS 26.6.1,
12 cores / four standard package workers / two backends, and the full
`just check 2 1 4 600` entry. Each project prefix started absent; compiler/OS
caches were not purged. These are empty-project-prefix controls, not reboot-cold
measurements. The source-only oracle differs in its expected optional-import bit;
the six checks, production fixtures and main case order otherwise stay the same.

| Variant / order | Full wall s | Loading preparation s | Preparation CPU s | Preparation GC CPU s |
| --- | ---: | ---: | ---: | ---: |
| Eager / forward | 909.27 | 205.01 | 6.48 | 0.144 |
| Deferred / forward | 727.99 | 200.48 | 6.31 | 0.133 |
| Deferred / reverse | 753.25 | 272.71 | 7.04 | 0.165 |
| Eager / reverse | 918.54 | 232.14 | 7.40 | 0.161 |

All four retained 144 main modules / 2,130 cases, six source checks, both studies,
the same ordered case digest and natural exit plus EOF. An earlier eager run
failed an incorrect new source-only import oracle; it is excluded from this table,
not counted as a successful full entry. The corrected oracle passed independently
for both frozen variants before these controls.

The paired complete entries improve by 19.9% and 18.0%; these are four observed
samples, not a statistical tail bound. Loading preparation itself has no stable
improvement and its worse sample remains unresolved. Own-process CPU and GC do
not account for its wall residual; that residual is not exclusively dyld time.
The full suite still needs the engine through its property tests. Avoided optional
preparation in other compiler/client contexts must not be described as deleting
that required complete-suite dependency.

Lean's `optionalModuleEntry` preserves unchanged rows, current bindings, present
false and failure causes on demand. `optionalPreparation_partition` charges only
exclusive unused preparation. `optionalWorkflowWork_le_iff` additionally charges
closures, argument rows, binding resolution and standard loader-entry admission:
declared complete work improves exactly when this routing fits the saved work.
Its negative control rejects routing 127 against savings 126. These are finite
source-work laws, not compiler, physical allocation, GC or macOS latency proofs.
They advance implementation preparation inspired by the author's shared delayed
dictionary construction (`poof.scrbl:980–1008`), which is not a module-loader design.

Subsequent integration retains the standard assertion owner's actual-report
authority: typed `require-property-passed` extracts the existing Record execution
and delegates it, plus lazy diagnostics, through the same optional IO entry.
Formatting cannot manufacture a successful execution. This newer assertion
implementation is covered by the source-current full checks; the frozen cold
table above is not a cold-performance qualification of that subsequent change.
