# Super-independent SlotSpec construction

This advances the author's implementation future work; it does not claim the
Racket paper already implements this construction strategy or all of the MOP.


The Data representation TODO explicitly requests efficient treatment of methods
that ignore super (lossy/K-style composition). Existing constant, thunk and self
SlotSpecs make that fact explicit. The original assembly constructed effective
thunks for the entire source stream before later overrides discarded them.
`compute-slot-funs!` now uses its SAME temporary hash to retain only the chain
since the last explicit super-independent contribution. Standard reverse/foldl
then calls the ORIGINAL `apply-slot-spec`; no second declaration evaluator,
loader, lookup registry or cache is added. Computed bodies stay opaque.

All specifications are still admitted in chronological source order, including
malformed shadowed prefixes. Defaults use constant SlotSpecs. Every retained
field is compiled before any compute-slot hook, preserving cross-field payload
capture time. The effective table is published only after all hooks succeed.
Existing inheritance, explicit invalidation, static layouts, observed reads,
body refusal and retry remain responsible for their own semantics.
Declaration preparation and dependency registration are not truncated: a later
invalid descriptor still has to invalidate and refuse construction, even when
its valid earlier body was shadowed. Builder savings never grant permission to
reuse an unchecked source or skip refinement/bind-evidence.

`override-workflow` supplies contributions to the existing shared-service
reflection/refinement/FUN pipeline. Six regression cases compare the original
chronological fold, tree/compact carriers, final self, false and Function values,
malformed-prefix refusal before hooks, cross-field capture, lazy missing-super
and exact refusal/retry. The full module-action lifecycle includes live revisions
and business rejection with no consumer effect.

The companion existing Lean SlotSpec module proves compilation/fold equality,
reset-suffix behavior, first validation error, unchanged final self, opaque
computed retention and bounded preparation/builder requests. Source visits and
retained-list reversal cost remain linear and paid; defaults, descriptor/C3
preparation, list cells, hashes, hooks, allocator and GC are not erased by the
builder-count theorem. Serialized supported execution and the existing host
constructor interpretation are premises; arbitrary raw mutation and compiler
correctness are not proved.

`just benchmark-slot-construction` uses the standard `gerbil test` paired runner.
Both sides use the CURRENT engine: opaque computed is the safe reference encoding
and explicit self the candidate. Their fresh metadata, preparation, static access
and full observations are charged in cold phases. This is not a previous-revision
constructor benchmark. Single-contribution and hot-cache controls remain beside
64-prefix cold construction and complete module/refinement/publication/retry.
AB/BA, A/A/B/B and natural/collected/inclusive post-GC regimes are retained.

### Local paired construction receipt

macOS, Gerbil 1cfb032 / Gambit ea114fc, 64-prefix study, 16 operations per batch,
six cross-side pairs; candidate minus reference, wall microseconds:

| Complete operation | Natural median | Collected median | Post-GC batch median |
| --- | ---: | ---: | ---: |
| Single contribution | +0.92 | +0.75 | +1.37 |
| 64-prefix cold construction and observation | -2.04 | -5.38 | -1.01 |
| Warmed cache and complete observation | -0.03 | -0.24 | n/a |
| Module/refinement/publication/retry workflow | -769.44 | -30.03 | -35.13 |

Collected single-contribution pairs have +8.26 mean, spanning -4.23 to +47.04;
there is no single-field improvement claim. Cold collected pairs have -4.71 mean,
spanning -11.00 to +2.73; post-GC cold pairs include a +3.43 adverse tail.
Collected workflow pairs all improve (-53.99 to -13.68; mean -30.96), with zero
GC CPU in measured batches and -29.87 median CPU. Post-GC workflow batch
pairs all improve (-60.19 to -6.30; mean -33.56). The separately inclusive
CHARGED workflow includes forced collection and first invocation: four wins and
two losses, median -33.76, mean -18.13, range -95.59 to +138.06. Its additive mean components
are -31.10 batch non-GC CPU, -2.85 first-call non-GC CPU, +15.19 forced-GC CPU,
with wall-minus-CPU residuals charged separately. No median sum is presented as
an additive decomposition.

Natural workflow GC history dominates the much larger median saving: -723.22
microseconds median GC CPU beside -50.16 non-GC CPU. Natural A/A spans -1,491.62
to +1,461.64 and B/B -6.63 to +1,486.69. Collected A/A spans -21.17 to +31.87
and B/B -39.56 to +6.12; post-GC batch B/B retains a +258.61 tail. Inclusive
A/A and B/B retain +129.01 and +178.11 tails respectively. Small
sample wins do not establish universal tail acceleration. Both encodings use the
current engine, so none of these numbers proves a previous-revision speedup.

The full command took 15.53 wall seconds, while the inner study took 7.49;
startup reported 5.34 wall / 1.63 CPU seconds. These distinct boundaries do not
prove faster module discovery or initialization. Signed allocation counters
remain diagnostic unless their existing zero-GC/nonnegative validity guard holds.
Raw samples remain outside Git; no versioned benchmark data or archive is added.

The CHARGED inclusive cold control spans -36.13 to +23.53 microseconds
(mean -6.28; three wins, three losses); inclusive single-contribution spans
-181.06 to +45.58 (mean -17.58; two wins, four losses). Thus batch gains
do not erase initialization or collector history.
