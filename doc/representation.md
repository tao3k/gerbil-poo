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
storage, automatic PIC/JIT selection and cold module-loading qualification remain
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
| slot-hot | prior untracked inline algorithm | unchanged-owner hot reads |
| slot-switch | prior untracked inline algorithm | repeated same-shape receiver switching |
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

### Local qualification receipt and remaining priorities

macOS arm64, released Gerbil `1cfb032`; `just _run-collections 64 3 6` used the
standard linked consumer and current compiled workload. Each hot/switch/tracked
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
