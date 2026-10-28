# Persistent prototype traversal and composition

This advances the author's implementation future work. The paper's different
instance/prototype representations (`poof.scrbl` lines 980–1031) preserve semantic
observations while sharing dictionary computation. The Data representation TODO
also requires pure persistent maps and sharing across prototype operations.

Public `prototype-map-list` continues to return owned spines and entry pairs.
`prototype-map-for-each` uses Gerbil's existing ordered vector/RBTree iterator and
calls its consumer with the symbol and shared payload only. It exports no private
entry, vector or tree handle. A standard using/procedure contract runs once per
traversal, including empty sources. Original callback exceptions propagate and
stop the suffix; prior effects are not rolled back. Persistent updates made by
callbacks produce successors without changing the traversal's retained root.
`prototype-map-keys` returns an owned ordered name spine, preserving duplicates
and uninterned symbol identity without first copying unused entry pairs.

Object preparation uses the same consumers across normalized declaration maps
and direct maps. Their original order, full SlotSpec admission, before-hook
capture and deferred publication remain unchanged. Structural reflection uses
name projection; public `.all-slots` ownership and read authentication remain in
the existing boundary. Shared payloads, including mutable values and Functions,
are deliberately not deep-copied or wrapped again.

`.+` passes the override's existing immutable slots/defaults to the ordinary
constructor, matching `.cc`'s established sharing discipline. Explicit tree or
compact policy survives composition, including promoted compact maps. This
replaces the former incidental tree rebuild for compact overrides. Parents,
protocol and declaration semantics remain unchanged. The new receiver gets no
instance cache, layout, read evidence or instance-only assignment from the
override. Later direct-map changes produce new roots; supported ancestor or
shared metadata changes still invalidate through existing registered edges.
Raw private setters, arbitrary payload mutation and concurrent edits remain
outside this serialized protocol.

Five regression groups cover compact/promoted/sparse maps, duplicate contributions,
same-spelling symbols, false/Function identity, owned name snapshots, original
false callback refusal, persistent edits during traversal, policy/root sharing,
fresh caches, non-inherited instance assignments and inherited source revisions.
`composition-workflow` reuses the existing reflection/refinement/FUN/IO pipeline
for shared-service revisions, refusal and retry, including warmed override state.
No declaration evaluator, loader, index or cache registry is duplicated.

The existing Lean RepresentationIndex module proves traversal/snapshot equality,
concatenation order, first-error preservation, exact name projection, composition
policy/cache frames and persistent-update separation. Logical cons counts charge
two cells per publicly exported entry and one per name; root sharing eliminates
those export cells only. Standard iterator stacks, source map creation, balancing,
callbacks, parent construction, C3, declarations, contracts, all observation,
allocation and GC remain real costs. Faithful standard backend ordering and
persistence are premises; physical pointer sharing and compiler correctness are
not proved by immutable-list equality.

`just benchmark-prototype-traversal` runs the ordinary Gerbil TestSuite and existing
AB/BA + A/A/B/B sampler. Both strategies are safe CURRENT APIs: snapshot composition
is the reference, direct traversal/root sharing the candidate. The reference
reconstructs the SAME selected policy. Traversal and name projection charge full
ordered results; composition charges new receivers, preparation and all fields,
starting from the same warmed template. Single-contribution controls remain.
Full module workflows also charge constructing/warming templates, refinement,
publication, source changes and refusal/retry. Cached module lookup is not fresh
module compilation/initialization. Natural, collected, post-GC batches and the
separate CHARGED first-call/forced-GC inclusive receipt remain distinct.

Declaration scratch receivers also retain their private immutable maps; empty
declarations allocate no intermediate result pair. Nonempty malformed input is
not silently treated as empty. Shared descriptor revisions still force fresh
elaboration. IO failure-name printing and invalid-object summaries use the same
name projection without evaluating field values. The private declaration
preparation helper is no longer an accidental public export.

## Local paired receipt

On macOS, Gerbil 1cfb032 / Gambit ea114fc, width 64, 16 operations per batch and
six cross-side pairs, candidate-minus-reference median wall microseconds were:

| Complete operation | Natural | Collected | Post-GC batch |
| --- | ---: | ---: | ---: |
| Ordered callback traversal | -0.31 | -0.50 | n/a |
| Owned name projection | -0.37 | -0.44 | n/a |
| Compose warmed template and observe all fields | -75.41 | -75.59 | -136.87 |
| Single-contribution compose and observation | -1.10 | -2.65 | -0.57 |
| Complete module/refinement/publication/retry | +146.96 | -79.71 | -56.01 |

These are CURRENT safe strategies, not an old-revision constructor comparison.
Collected composition retains a -2,446.13 to +2,249.73 wall range despite its
-75.53 median CPU; a uniform tail improvement does not follow. Collected
single-contribution pairs span -12.56 to -1.13, but post-GC batches include a
+0.57 tail. Natural workflow spans -1,743.12 to +1,569.69. Small traversal/name
medians do not establish a universal process/workflow speedup.

The focused higher-resolution workflow entry uses the SAME final code and
sampler, with 32 operations and twelve cross-side pairs. Collected pairs improve
in eleven of twelve: mean -70.33, median -58.31, range -232.91 to +2.24. Natural
pairs have eight wins/four losses: mean -21.77, range -978.90 to +750.00. Post-GC
BATCHES have mean -117.06, median -97.45, range -420.09 to +217.24. These batches
exclude the separately measured forced collection and first invocation.

The CHARGED inclusive workflow retains those costs: ten wins/two losses, mean
-103.27, median -70.39, range -429.85 to +174.30. Additive mean wall components
are -113.52 batch, -2.53 first call and +12.78 forced collection. Corresponding
non-GC CPU means are -94.50, -2.40 and +0.04; forced GC CPU is +10.12. Remaining
wall-minus-CPU means are -19.02, -0.13 and +2.63 respectively. Medians are not
added or described as a decomposition. No blanket GC improvement is claimed.

An exploratory run before completing declaration/diagnostic traversal had a
+940.10 collected workflow mean, while its collected A/A itself spanned +449.02
to +2,712.38. That run motivated the larger controlled sample. It is not the
final code cohort, is not erased, and is not used as a before/after claim or as
proof that all differences were caused by GC or the OS. Same-side controls and
adverse tails remain required in every final run.

Raw logs remain outside Git. The complete five-phase command took 19.94 wall
seconds; the higher-resolution command took 16.63. These different workload
sizes are not a command-speed comparison. Neither result establishes fresh
module discovery, initialization or compilation acceleration. Signed allocation
counters retain their existing zero-GC/nonnegative validity guard; reduced logical
export cells alone are not measured bytes or a whole-workflow performance proof.

In the higher-resolution run, collected A/A spans -93.03 to +13.09 and B/B
-19.75 to +130.44 microseconds. Natural B/B spans -853.15 to -40.72 despite
identical code. These control ranges overlap meaningful parts of the measured
signal; twelve pairs are bounded qualification evidence, not a universal latency
or causal scheduling diagnosis.

## Declaration catalog ownership

The constructor now captures declaration membership through the same persistent
prototype map as slots/defaults. `object-declarations` returns an owned ordered
list and entry pairs. `reflect-slots` resolves inherited visibility using those
owned observations; editing a returned entry cannot replace a descriptor or
rename an authoritative field. Descriptor objects themselves remain shared,
registered sources: supported descriptor edits still invalidate every prepared
owner/clone, refresh visibility and rerun ordinary admission. This does not make
raw object setters or arbitrary external mutations safe.

Catalog input must satisfy the existing finite symbolic-specification grammar
at construction. Invalid keys/entry shape refuse before hooks. Descriptor bodies
are not evaluated by capture: their original elaboration/validation failures
remain lazy, propagate unchanged, publish no successful partial cache, and allow
a fresh corrected retry. Duplicate contribution order and most-specific reflection
selection are unchanged. New membership needs a freshly constructed object.
`.+` and `.cc` share catalog roots while creating fresh receiver caches.

`prototype-map-length` counts contributions, including duplicates. Two private
immutable empty snapshots retain the explicit tree/compact policy and avoid
allocating empty index builders for each undeclared receiver. Persistent writes
create successors; deleting entries from an existing tree still retains that
snapshot's monotone ordinal history. No mutable builder or vector is exported.

The paired catalog study compares safe public snapshot recapture with immutable
root reuse. It separately charges empty construction, fresh typed catalogs,
clones, owned public reflection, and the full standard module/refine/FUN-bind
publication with live source edits, refusal and retry. A/A and B/B controls and
natural/collected/charged post-GC observations remain in the existing sampler.
This is a current-strategy comparison, not an old-version performance claim.
Module actions use ordinary cached loads; this is not a fresh-process cold-import
benchmark. Exact compilation, module initialization and machine GC performance
are runtime evidence, not consequences of the finite Lean cost laws.

### Catalog paired receipt (2026-10-28, macOS)

Base `81732d5`, Gerbil compiler `1cfb032.patch618d76f9eb72`; no other build or
verification from this task ran during sampling. The standard `_test 300
benchmarks/prototype-catalog-test.ss` entry passed in **43.22 s**; its inclusive
study measured **35.40 s**. Tool approval startup timed out before execution and
is excluded from both measurements. Width 64, sixteen calls/batch, six AB/BA
pairs and four pairs per A/A and B/B control; the single-field phase uses width
one and the empty phase is an identical-path negative control. Both clone sides
use the same constructor and complete observation; only catalog recapture/root
reuse differs. Whole workflows include initial typed descriptors and admission.

Positive signed microseconds mean candidate regression. These are collected
batch results, not independently forced-GC inclusive results:

| Phase | AB median | AB min / max | AB wins / losses |
| --- | ---: | ---: | ---: |
| empty control | 0.00 | -20.50 / +4.17 | 3 / 3 |
| single cold | +0.62 | -2.12 / +3.76 | 3 / 3 |
| width-64 cold | -80.60 | -127.00 / -36.12 | 6 / 0 |
| clone | -110.33 | -579.80 / +127.26 | 5 / 1 |
| identical public reflection control | +19.87 | -10.01 / +66.43 | 2 / 4 |
| full publication | -97.62 | -479.76 / +443.06 | 3 / 3 |

Natural cold AB mean was **+39.41** (range -307.75 / +220.37), with B/B reaching
+2,167.82. Natural workflow had one win/five losses, mean -590.42 and a range
of -12,229.86 / +2,702.50; A/A reached +13,168.56 and B/B ranged
-1,895.92 / -1,166.95. The negative mean is not consistent tail improvement.
Collected workflow A/A ranged +64.43 / +485.57, and B/B -236.87 / +141.93.
Single collected A/A ranged -174.87 / +13.50, B/B -93.06 / +83.68. These
controls prevent treating small signed differences as reliable gains or losses.

CHARGED collection + first call + full batch workflow had median -106.99,
mean -110.15, five wins/one loss and range -322.08 / +201.41. Its A/A range
was -322.24 / +183.40 and B/B -245.11 / +1,233.03. Disjoint mean wall
contributions were batch -84.33, first -13.52, forced GC -12.31 microseconds;
medians must not be added. Batch non-GC CPU contributed -82.62, GC CPU +4.59
and residual -6.30. Counter history includes negative/unavailable allocation
samples, so no physical byte-saving claim is inferred. The formal 2n export
saving excludes private recapture/builders and is not an allocator measurement.

This accepts functional ownership and safe root reuse, not universal latency or
GC superiority. No strategy changes, weaker checks, larger limits, second loader
or snapshot registry were introduced to improve this receipt.

Final local acceptance: all **149 modules / 1,859 cases** passed through the
unchanged single-process standard test entry in **192.54 s**, followed by the
complete paired collection entry in **11.55 s**; whole `check-built 2 1 4`
wall time was **204.52 s**. Each phase retained its 300-second deadline and the
1 GiB runtime bound. The representation suite independently passed in 31.48 s.
The standard build completed before sampling; final dependency-currentness/build
phases were 25.43 / 5.77 / 66.01 seconds, with the final added preparation-refusal
control rebuilt through the existing representations package. These are reused
artifact build results, not a true-cold compiler speed claim. Full benchmark logs
remain outside Git. Lean focused checks retain 1 GiB/two threads; the full gate
and remote CI are separate acceptance steps.

## Effective declaration indexing

This advances the author's purity-by-default / explicit cache-flush future work
(`poof.scrbl` 1533–1553), using the existing persistent map and object invalidation.
`read-slot` and `write-slot!` previously rebuilt C3 catalog snapshots, deduplicated,
checked every visibility flag and linearly searched on every call. A lazy private
receiver index now retains the effective directory and a separately prepared
visible directory. Existing standard compact/RBTree storage supplies first-entry
lookup (`prototype-map-ref`); no second tree, loader or registration table is added.

There is one additional optional cache field per object, initialized empty and
cleared by the same source-invalidation boundary as layouts, methods and reads.
Fresh clones inherit no prepared index. Actual cache records/maps are allocated
only when declaration reflection is requested. Initial merging, visibility,
owned snapshots and map construction remain real cold costs; this does not claim
that an indexed first query or every small receiver is cheaper.

The earliest C3 declaration wins before visibility filtering. A hidden override
never falls through to a public ancestor. Include-hidden inspection does not read
visibility flags. Public lists/pairs are fresh; descriptor objects remain shared
registered sources. Failures leave no successful partial visible index. Supported
source changes during visibility getters/observers refuse the old query before
publication; effects already performed are not rolled back. A corrected retry
uses the current source and ordinary cache invalidation.

Observed queries always authenticate owner membership through the existing names
query, then preserve the original foldr visibility-read order. This adds the
owner structural dependency missing from descriptor-only reflection. Warm observed
queries still deliver current metadata reads and refuse changed sources; successful
Type/value admission is never cached. Unobserved warm point queries may reuse the
current private visibility map, but every read/write still runs the existing Slot
value checker. Raw struct mutation and arbitrary callback dependencies remain
outside the registered-source/purity discipline.

The paired reference is a safe snapshot/scan oracle with the SAME owner-membership
observation and revision fence. Cold/single/empty phases charge preparation;
hot, missing, observed and full module/FUN/refinement revision/refusal/retry paths
remain separate. This comparison measures the current indexed protocol against a
current safe scan, not an unsafe historical implementation or a new module loader.

### Effective-index paired receipt (2026-10-28, macOS)

Base `6701463`, Gerbil compiler `1cfb032.patch618d76f9eb72`. No build or other
verification from this task overlapped sampling. Standard `_test 300
benchmarks/declaration-index-test.ss` passed in **79.81 s**, including module/test
startup; its inclusive study measured **67.27 s** wall, **31.77 s** CPU and
**14.60 s** reported GC CPU. Width 32 (single uses one field), sixteen calls per
batch, six AB/BA pairs, four A/A and B/B pairs per regime. Natural and collected
regimes remain; cold/single/empty/workflow also retain charged post-GC controls.
Cold actions create their own complete typed descriptor graph. Only hot/missing/
observed phases prepare a warm owner outside their measured actions. Full workflow
outer enumeration uses the same public reflection API on both sides; only the
point resolver changes. Standard module actions use cached loads, not a claim
about fresh-process import performance.

Positive microseconds indicate candidate regression. These are collected batch
wall results, including the actual callbacks and concrete Slot checks:

| Phase | AB median | AB min / max | AB wins / losses |
| --- | ---: | ---: | ---: |
| empty reflection | +0.72 | -19.88 / +5.75 | 2 / 4 |
| single cold | +0.25 | -85.32 / +3.81 | 3 / 3 |
| width-32 cold | +351.31 | -793.37 / +641.63 | 1 / 5 |
| hot point read | -9.06 | -11.44 / +85.37 | 4 / 2 |
| missing point read | -9.82 | -42.26 / -9.00 | 6 / 0 |
| observed point read | -5.77 | -9.55 / +2.88 | 5 / 1 |
| complete publication | -7,972.91 | -15,304.70 / -6,288.07 | 6 / 0 |

Cold collected CPU/non-GC median was -24.59 while wall residual median was
+235.24; medians are not additive. Cold A/A ranged -2,488.57 / +490.81, B/B
-1,514.43 / +1,781.39. Natural cold AB ranged -8,351.25 / +338.67, A/A
-12,147.95 / +13,364.69 and B/B -2,243.25 / +5,304.89. This does not qualify
stable cold-wall improvement. Initial map preparation is a real cost; a lower
CPU counter alone does not override an adverse wall observation.

Hot natural pairs all improved, with range -147.31 / -6.81 and mean -32.09.
Collected hot mean was +14.40 because of its +85.37 tail; A/A ranged
-14.19 / +61.63, B/B -70.94 / +62.21. Reported medians do not establish a
universal hot-tail bound. Collected full-publication mean was -9,266.70, with
A/A range -2,735.56 / +7,886.87 and B/B -6,516.99 / +3,234.21. Natural
publication had five wins/one loss, mean -3,298.15 and range
-12,097.12 / +7,098.32; natural A/A reached +21,637.26.

CHARGED GC + first + complete batch workflow had median -5,197.92, mean
-5,101.55, five wins/one loss and range -12,211.25 / +4,013.90. A/A ranged
-546.79 / +1,558.93 and B/B -438.06 / +720.82. Its disjoint mean wall
contributions were batch -4,420.22, first -683.83 and forced GC +2.49.
Batch non-GC CPU was -2,716.57, GC CPU -1,612.79 and residual -90.85; forced
GC itself added +15.66 residual. Medians must not be summed. Allocation history
contains negative/unavailable counters, so no physical byte-saving claim is made.
Both strategies use the current object representation; this does not measure the
old/new physical byte difference of the additional optional record field.

This accepts the finite source/observation protocol and demonstrates measured
point/full-workflow improvements in the reported regimes. It does not qualify
universal cold, first-call, GC or tail acceleration, nor whole-loader performance.
Raw benchmark data remain outside Git; checks and resource limits are unchanged.

Final local acceptance retained all **150 modules / 1,866 cases**, with no error
markers: module phase **245.29 s**, complete paired collection entry **19.73 s**,
whole `check-built 2 1 4` **265.64 s**. Each phase retained its 300-second limit
and 1 GiB runtime heap; no process split or admission was removed. The seven new
regressions independently passed in 8.23 s. Complete build preparation passed;
final current-artifact phases measured 39.32 / 3.25 / 48.17 seconds, followed by
the standard representations rebuild for the corrected topology-API test. These
build/check wall times are not an old/new cold-build comparison or a whole-check
speedup claim. Focused Lean checks retain 1 GiB/two threads; full gate and remote
CI remain separate acceptance steps.

## Cold-query preparation reuse

The cold path now eliminates two repeat builders while retaining the existing
purity-by-default/registered-source discipline. `prototype-map-merge-first`
ignores empty catalogs, checks existing name positions for a sole distinct root,
and reuses that immutable backend. Multiple roots or duplicate contributions keep
the full ordered first-occurrence projection. This is a keyed-catalog operation,
not method-chain merging. Distinctness costs a bounded small-vector check or a
standard RBTree fold; no additional cached bit, set or object field is introduced.

Large policy-only conversions wrap the existing immutable trees and retain sparse
ordinals/high-water position. Small tree/vector transitions still capture their
finite entry streams. Persistent successors do not mutate either policy view.
`prototype-map-filter` invokes its predicate right-to-left and preserves entry
order. An all-pass result returns the original root; partial filtering keeps the
source policy and rebuilds only its resulting map. Callback errors propagate
unchanged and prior effects are not rolled back. Private pairs never escape.

Public declaration visibility uses this filter and still checks the owner revision
BEFORE publishing its result, including an all-pass shared root. Observed calls
retain the prior ordered reader and the owner-names authentication. Value checks,
visibility getters and their snapshots remain real costs. The all-pass shortcut
is justified by actual filtering/sublist plus equal retained length, not arbitrary
same-cardinality replacement. Source registration, serialized edits and immutable
standard map operations remain premises.

### Cold-query paired receipt (2026-10-28, macOS)

Base `8e2fad9`, compiler `1cfb032.patch618d76f9eb72`. No build/check from this task
overlapped either study. Complete declaration study passed in **75.41 s**, with
**63.58 s** inclusive study. Original cold/hot/missing/observed/workflow phases
remain, with additional isolated directory, full/mixed visibility and single-hot
controls. Width 32, sixteen calls/batch, six AB/BA pairs and four A/A and B/B pairs.
Component descriptors/visibility are warmed only for the component diagnostic;
whole cold actions still build their complete descriptor graph and receiver.

Collected component medians: directory preparation **-21.87 us** (range
-22.56 / -21.07), all-visible preparation **-15.84 us** (-16.81 / -7.32), mixed
visibility **+0.16 us** (-0.94 / +0.82), and single-hot **-1.37 us**
(-4.25 / +1.24). These isolate actual eliminated builders; they are not summed
into an end-to-end latency prediction. Complete study cold collected median was
**+56.66 us**, mean +401.12, one win/five losses and range -8.49 / +1,483.87;
it did not establish cold-wall closure. Full workflow collected median was
-9,774.94 us with six wins/no losses and range -13,123.81 / -4,055.62.

A separate longer confirmation retains the SAME cold/full scan oracle, all regimes
and controls: width 32, thirty-two calls/batch, twelve AB/BA pairs and four A/A/B/B
pairs. It passed in **50.93 s**, inclusive study **45.84 s**. Positive differences
below mean candidate regression; the larger batch is additional evidence, not a
replacement for the shorter adverse samples above.

| Confirmation phase | AB median us | AB mean us | min / max us | wins / losses |
| --- | ---: | ---: | ---: | ---: |
| cold collected | -0.89 | +14.37 | -24.02 / +84.72 | 7 / 5 |
| cold charged GC/first/batch | -8.75 | -1.30 | -59.91 / +73.73 | 7 / 5 |
| full collected | -3,526.77 | -3,726.31 | -6,702.10 / -2,680.96 | 12 / 0 |
| full charged GC/first/batch | -3,238.95 | -3,205.65 | -3,553.91 / -2,530.81 | 12 / 0 |

Cold natural AB was six wins/six losses, mean -93.97 and range
-1,105.46 / +767.91; its A/A max was +754.57 and B/B max +753.86. Cold
collected A/A ranged -124.28 / +4.60, B/B -17.56 / +3.81. The +84.72 AB
tail is retained rather than treated as automatically explained by those tighter
controls. Charged cold A/A ranged -22.22 / +26.41, B/B -23.01 / +57.83.

Charged cold mean components were batch wall +4.05 (non-GC CPU +3.41, GC 0,
residual +0.65), first +1.00 (non-GC +0.75, residual +0.25), forced GC -6.36
(GC CPU -5.77, residual -0.56). Thus forced GC contributes much of the negative
charged cold mean; it does not prove a faster production cold query. Disjoint
means add; medians do not. CPU improvement alone is not cold-wall acceptance.

Full natural confirmation had ten wins/two losses, mean -2,585.88 and range
-5,197.16 / +9,552.44; natural A/A max +869.25, B/B max +774.06. Collected
full A/A ranged -825.12 / +471.00, B/B -202.22 / +53.85. Charged full A/A
ranged -428.97 / +2,872.75, B/B -359.61 / -113.68. Charged full mean components
were batch wall -3,134.59 (non-GC CPU -2,422.57, GC CPU -712.74, residual
+0.72), first -75.96, forced GC +4.90 (GC CPU +6.69, residual -1.82).

The earlier +351 us cold median is not reproduced in the longer confirmation,
and isolated preparation plus complete collected/charged workflows improve.
Cold mean/tails and natural full-workflow outliers remain unqualified; no universal
cold, GC or tail-speedup claim follows. Raw allocation histories contain invalid
negative samples, so no byte-saving claim is inferred. Extra object cache field,
initial descriptors, uniqueness scans, snapshots, value checks, startup and GC
remain paid. Complete logs stay outside Git; resource limits/checks are unchanged.

Final integration preserves upstream `688555b` (bounded executable independent
property build) and `3ba1b34` (standard CI progress level). They do not change
query/benchmark code; paired data above remain the original cohort, not resampled
for a better outcome. Final standard build phases passed in 85.66 / 2.84 /
161.87 seconds. Complete final acceptance passed **150 modules / 1,871 cases**
with no errors: module phase **223.15 s**, complete paired entry **12.91 s**,
whole `check-built 2 1 4` **236.61 s**. The additional upstream case checks the
independent build entry. Per-phase deadlines, frontend/backend heap limits and
full inventory are unchanged. Focused source proofs/examples pass at 1 GiB/two
threads; complete Lean gate and exact-head remote CI are separate evidence.


### Private reverse-fold visibility preparation

The author's `poof.scrbl` representation section (980–1031) distinguishes shared
persistent dictionaries from repeated superclass evaluation. Its cache-invalidation
section (1527–1553) makes purity/explicit invalidation a premise, rather than a
guarantee for arbitrary side effects. This implementation retains that boundary:
receiver revisions invalidate both declaration directories, observed queries
still deliver ordered reads, and concrete Type admission runs on every call.

The remaining visibility preparation exported a complete owned snapshot before
filtering, even when the all-pass result reused its original root. Filtering now
uses the installed standard `rbtree-foldr` or `vector-fold-right/index` directly.
Callbacks receive only names and payloads; private pairs never cross the callback
boundary. Partial results go through the existing capturing constructor, while
public `prototype-map-list` results remain independently owned. No new cache,
registry, layout field or namespace is added. The retained result spine and
partial reconstruction are still real costs; only the input spine/pair export
is eliminated. Right-to-left callback order, exact refusal, prefix effects and
the post-callback revision fence are unchanged.

The complete declaration study adds `declaration-private-filter`, comparing the
previous snapshot/all-pass-sharing filter with direct folding, and an identical
A/A `declaration-construction` phase. The longer cold/full-workflow confirmation
also charges this shared-construction control. Its two sides do the same fresh
Slot graph and receiver instantiation, so its variation is not a query speedup.
These supplement every original phase, first-call sample, AB/BA order, A/A/B/B
control and natural/collected/charged GC regime. Main cold/workflow operations
continue to pay their own fresh constructors and full publication oracle.


#### Paired acceptance and remaining cold-tail uncertainty

The complete unchanged declaration study plus the two new diagnostics passed in
61.82 s outer / 53.54 s inclusive time (width 32, batch 16, six AB/BA pairs and
four A/A plus four B/B per regime). The longer confirmation passed in 77.84 s
outer / 73.78 s inclusive time (batch 32, twelve pairs, the same controls).
Compilation and local checks did not overlap either study. Both keep the full
fresh-construction and publication oracles. The scan baseline is the existing
safe scan, not a historical binary; `declaration-private-filter` separately
isolates the previous snapshot filter with its SAME all-pass root shortcut.

All values below are candidate-minus-reference wall microseconds per operation;
negative values favor the candidate. These are finite samples, not tail bounds.

| Study / collected regime | Mean | Minimum / maximum | Wins / losses |
| --- | ---: | ---: | ---: |
| private filter, six pairs | -0.10 | -0.49 / +0.37 | 3 / 1 (two ties) |
| cold query, six pairs | +5.21 | -8.37 / +19.27 | 3 / 3 |
| complete workflow, six pairs | -4,475.19 | -4,952.12 / -3,995.88 | 6 / 0 |
| identical construction, twelve pairs | +4.02 | -46.28 / +45.13 | 5 / 7 |
| cold query, twelve pairs | +0.55 | -38.34 / +53.13 | 7 / 5 |
| complete workflow, twelve pairs | -4,981.40 | -17,640.81 / +5,447.72 | 10 / 2 |

The longer cold collected median was -4.76 us and p90 +18.90 us. Mean components
were non-GC CPU +0.51 us, GC CPU 0, wall-minus-CPU +0.04 us. Its worst positive
pair was +53.13 us: +42.84 non-GC CPU and +10.29 residual, with no batch GC.
Thus the remaining cold tail cannot simply be called GC cost. Identical fresh
construction itself reached +45.13 us (+44.31 non-GC CPU); construction B/B
reached +113.78 us. These shared controls expose preparation variation but must
NOT be subtracted from candidate results or used to dismiss a positive tail.
Cold-query collected A/A reached +4,350.65 us, including +4,227.59 us residual;
B/B reached -4,189.22 / +99.12 us. A residual is an observation, not proof of an
OS scheduling, compiler, collector or other-process cause.

Natural cold mean was -55.10 us, with -990.38 / +790.18 us range; the worst
positive pair included +758.63 us GC CPU, +27.69 non-GC CPU and +3.87 residual.
Natural workflow retained its +8,423.25 us adverse tail: non-GC CPU -2,757.28 us,
GC CPU -1,186.22 us, residual +12,366.75 us. The collected workflow's +5,447.72 us
adverse pair similarly had lower CPU but +6,895.40 us residual. Neither is
converted to wall-time success merely because CPU fell.

Charged GC/first/batch workflow won all twelve pairs: mean -3,547.48 us, median
-3,446.27 us, range -4,202.46 / -3,182.16 us. Its disjoint means were batch wall
-3,487.07 us (non-GC CPU -2,586.53, GC -820.79, residual -79.75), first call
-73.47 us (non-GC -74.81, residual +1.33), and forced-GC wall +13.06 us (GC CPU
+8.46, residual +4.61). Charged cold mean -896.67 us is NOT accepted as a query
speedup: batch residual alone was -709.60 us and the range remained
-6,806.89 / +1,427.67 us. First-call non-GC CPU still cost +3.52 us on this
inclusive normalization. Identical-construction charged controls also reached
+1,274.98 us. GC-history/first-call and residual controls remain separate.

The earlier +14.37 us mean / +84.72 us maximum were not reproduced at the same
size in this confirmation; +0.55 / +53.13 us is not a causal old/new binary
speedup estimate. Direct folding removes a redundant export and its finite law
is proved, but its isolated sub-microsecond measurement is within same-side
variation. This unit therefore accepts the semantic simplification and retains
favorable complete-workflow evidence WITHOUT claiming universal cold or tail
closure. No retries were selected to improve these receipts, no limits changed,
and invalid raw allocation histories are not physical byte-savings evidence.


Local final admission passed 150 modules / 1,872 cases in the single process
(212.96 s), followed by the complete paired admission (12.63 s). The independent
Lean complete gate passed all 20 phases at automatic 14-worker concurrency after
restoring its already-installed declared Pandoc to PATH; its initial docs-only
failure was a missing executable, not a proof failure. Limits were unchanged.

Remote compiler admission retained one real adverse result: run 40651511529
failed with an unhandled worker-3 Stack overflow before backend cleanup finished
and exit 70. A subsequent diagnostic first hit the shared cache and was NOT
accepted as a cold reproduction. Run 40652682280 explicitly used existing
`just clean` and standard compiler verbosity 9, kept every resource/test limit,
actually executed cold construction, and passed all 53 checks. Its clean/build
step took 298 seconds, including 53.84 seconds of standard cleanup. Production
Scheme sources, package declarations and justfile did not change between these
runs. The original compiler refusal was not reproduced and its exact cause
remains unknown; successful cleanup/cold admission is not a causal compiler fix
or a universal absence-of-overflow proof. Temporary diagnostics are removed:
normal cache admission and verbosity 3 remain the final workflow policy.

The subsequent [root compiler shared-heap admission](performance/build-summary.org)
reproduces a worker failure at the fixed heap ceiling and separates standard
GXC frontend admission from backend capacity. That later experiment, rather than
the earlier clean pass, motivates the bounded frontend policy.
