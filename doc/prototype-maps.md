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
