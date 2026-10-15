# Closure construction, native measurements and publication alignment

The current implementation and open interface gaps are mapped in
[alignment.md](alignment.md). The active benchmark tools now use fixed Scheme
case/column definitions and native `read`/`write` data. Common metadata appears
once, followed by result vectors and a completion marker. No new JSON format or
version series is introduced; historical JSON records below remain unchanged.

## Measured construction changes

Diamond's cold path skips adaptive degree preparation. The remaining construction
walk is specialized with `defrule` into indexed and copy-only visitors using a
private compiler-style typed context. It no longer creates a read callback for
each equation. Direct checked tag dispatch avoids the pattern continuations seen
in the previous generated walker. Input copying/validation, depth/node caps and
fixnum-priced range admission remain. Shape-growing revisions recheck the new
size bound. Native CPU, wall, GC CPU/count and allocated-byte measurements are
recorded per phase; GC CPU is included in CPU, not added to it again.

`prepare-closure` is idempotent on an already admitted adaptive plan, including
retained revisions: it returns the identical plan without rescanning degrees or
allocating another plan. `closure-plan-selector-visits` describes construction of
that plan; it is not another visit count for repeated cached preparation calls.

`reconfigure-closure` now accepts equal ordered read occurrences even when Boolean
operators or association change. It first takes the no-allocation same-topology
fast path, then uses linear dependency collection for reshapes. Changed occurrence
order/multiplicity/range is refused; the solution is always recomputed from bottom.
The old published facts never bootstrap an unsupported new cycle.

## Unified construction/publication operations

`cyclic-publication.ss` stages least closure, cooked view, heterogeneous named
procedures and candidate admission as one bundle. Duplicate/invalid services,
cooking exceptions or admission refusal preserve the identical old bundle. A
fresh compile is explicit when topology changes. Published views are immutable by
contract: callbacks and clients must not mutate them. Arbitrary external effects
are not rolled back. Method indexes and raw fact storage are private.

`examples/cyclic-access.ss` ports the exact ten CyclicAccess equations and cooked
view (including active indices), with two different service signatures, consent,
revocation and admission refusal. All 32 source configurations are tested through
real `.o` objects. The callback family does not implement Lean's arbitrary typed
multi-dispatch, negative watches, logical metadata or certified recursive memo;
those remaining gaps are explicit in the alignment map.

Lean proves the fused exact index and core preservation, dependency-equal reshape
canonicality, conditional construction allocation savings, cached preparation
idempotence and retained publication/refusal. These are finite source/model
properties; native timing/GC counters are separate measurements.

## Reproduction

```
GERBIL_PATH=<package-env> just benchmark-closure-phases
GERBIL_PATH=<package-env> just benchmark-closure-paired
GERBIL_PATH=<package-env> just benchmark-closure
GERBIL_PATH=<package-env> gxi t/closure-report.ss .build/closure/closure-benchmarks.scm
```

The matrix driver runs Scheme alone using the declared case definition,
records every failure, and verifies Scheme source identities before/after
measurement. Each child checks its result against an independent scalar oracle.
Cross-project counter comparison lives in the Lean repository as an optional
tool with explicit executable and checkout arguments. Its reader rejects incomplete, duplicated, changed-source
or counter-mismatched studies. Data is read without evaluation. Every child keeps
the 20s deadline and Scheme's 1GiB heap bound; compile jobs keep 90s.

---

# Earlier lifecycle implementation (historical v4)

# Closure lifecycle and standard-library implementation (v4)

This advances the paper's generalized-protocol future work for finite positive
Boolean equations. `closure.ss` now uses Gerbil's `for/fold`, `in-vector`, `iota`,
pattern matching and compiler-style private typed `using` contexts. Benchmark
helpers share standard JSON, hash literals, `list->hash-table`, `map`, `cut`,
`list-sort`, ports, digest and process libraries. Both native benchmark programs
emit JSON; the duplicated record constructor and hand-written field parser are
gone. Solver queue loops remain specialized where the operation model needs them.

## Construction, preparation and reuse

`compile-closure equations` prepares the reference adaptive strategy once;
`compile-closure equations 'cold` skips degree selector preparation and chooses
append or chunked from `4E` and `32V`. Explicit `'append`, `'chunked`, `'hybrid`
compile modes also skip that preparation. `construct-closure equations` is the
cold compile+solve convenience function. `prepare-closure plan` adds adaptive
metadata later, sharing the private code and reverse index. The chosen engine is
cached; default `solve-closure` dispatches it directly. Adaptive selection now
also considers fixed chunked: min(4E,32V,V+4*sum(min(degree,8))). Dense 64 chooses
hybrid, dense 256 chooses chunked; cold selection uses only the first two bounds.

`reconfigure-closure` still copies, validates and compares revised descriptors;
it shares the admitted reverse index/queue metadata only with identical tag/read
topology, reports zero new selector visits and solves from bottom. Published
snapshots remain separate. One compilation context tracks descriptor visits;
node counting no longer invokes an accounting callback per descriptor. A read
visitor remains per equation during initial reverse-index construction.

Lean's `ClosureLifecycle` proves exact core/canonical closure, three candidate
ceilings, cold/retained zero preparation and explicit construction/preparation/
publication costs. Repeated construction and revision have separate batch bounds.
The adaptive surcharge remains explicit; no theorem says it is always repaid or
that this reference profile minimizes native latency. Backend prices must cover
actual descriptor validation, topology comparison and representation work.

## Native evidence

`just benchmark-closure` runs 960 bounded rows across cold, warm and retained-index
refresh, both seeds and four rotated independent-process trials. Setup time is
reported separately and included in `lifecycle_seconds`. `just benchmark-closure-paired`
runs 480 balanced same-process observations with one untimed warmup per engine.
`gxi t/closure-report.ss <receipt>` reports CPU query and amortized lifecycle times.
Native parity checks 23 fields/row (22,080 assertions), including selector visits
and construction/index counts. Children retain a 20-second deadline and 1 GiB heap.
All helpers and clocks are native Scheme; no Python benchmark driver is added.

The v4 raw receipts below supplement preserved v1–v3 results. Compare timings
within a runtime: Scheme workload generation occurs before the query clock,
whereas Lean materializes its equation function during compilation. Operation
proofs do not verify the Scheme compiler, GC, allocator or machine execution.
Historical slowdowns are not erased by changing the selector.

---

## Historical v1–v3 design and measurements

# Finite positive cyclic construction

This module advances generalized-prototype/MOP **future work**. It is an explicit
finite Boolean equation utility for constructing a completed public object. It
does not change ordinary prototype demand recursion or make arbitrary cycles
terminate. There is no general reflective MOP, arbitrary effect handling or
compiler/runtime verification claim.

```scheme
(import :clan/poo/closure)
(def source (vector (literal #t) (either (fact 0) (fact 2)) (fact 1)))
(def plan (compile-closure source))
(def active (solve-closure plan))
;; => (#t #t #t)
(closure->list active)
(def revoked-plan
  (reconfigure-closure plan (vector (literal #f) (either (fact 0) (fact 2)) (fact 1))))
;; => (#f #f #f); the old snapshot is still true.
(closure->list (solve-closure revoked-plan))
```

`literal`, `fact`, `both`, `either` describe constants, bounded fact reads,
conjunction and disjunction. Positive source syntax gives a monotone finite
system. Compilation validates and privately copies descriptors and builds reverse
read-occurrence lists with cached degrees; duplicate operands count separately.
The descriptors are strict expression trees: both children are evaluated. Scalar
Boolean results avoid evaluator result pairs. No input callback runs in the solver.

Every solve owns a fresh zeroed bytevector and computes the **least** solution.
A fact becomes true at most once; only its dependents are scheduled. Completed
false authority cannot survive in a self-supporting cycle after revocation.
The existing result is never reused as a seed. Public results copy the scratch
bytes; exported observations cannot mutate stored bytes or counters. This is API
privacy and disciplined ownership, not a sandbox against reflective mutation.

`reconfigure-closure` validates/copies new descriptors and shares the old reverse
index only if tags/read indices agree recursively; literal values may change.
This is a sufficient subset of dependency equality, without allocating temporary
dependency lists. General equivalent reshaping requires recompilation. Rejection
throws before returning a new plan, and cannot mutate the old plan or snapshot.

Compilation rejects invalid literals/tags/indices and fact-range changes. Input
validation has explicit limits: depth 4096 and one million descriptor occurrences;
cyclic host descriptor graphs hit the depth limit and are rejected. These are input
resource refusals, not proofs of operational divergence. A generic-integer check
also admits only declarations whose conservative operation cap fits fixnums.
The bounded solve fuel is derived from V+E, not caller-selected. Exhaustion is an
internal invariant failure, never a returned partial solution.

## Cached automatic strategy (current default)

The default is now `auto`. Compilation computes A=4*E and
H=V+4*sum(min(degree,8)), then caches append when A<=H and hybrid otherwise.
The choice uses topology only. It includes a relative decision charge per
potential hybrid write; `(4,16,16,1)` are reference copy/suspend/resume/decision
prices, not hardware calibration. They preserve the existing degree-eight hybrid
threshold. A sparse hub among many singletons is distinguished from repeated
bursts. Every degree <=8 guarantees append. Explicit queue modes remain available.
`auto` admits the reference profile; explicit `hybrid` supports custom prices.

The common automatic entry path recognizes the immutable admitted reference
policy and avoids repeating generic price-range multiplication. All engines load
a successful write's degree once and reuse it. Append now directly constructs
zero/one/two-watcher spines; wider spines use generic append. The Lean executed
append helper has an exact append equality proof, and selected execution retains
the same store, least solution and five core counters (pops, evaluations, AST
nodes, writes, pushes). Frame/allocation counters vary by selected engine.

`reconfigure-closure` shares the cached hybrid ceiling and engine with the exact
retained topology; it still solves fresh from bottom. `closure-plan-queue` and
`closure-plan-hybrid-ceiling` expose immutable scalar metadata. Scheme preparation
scans cached degrees once; warm solves do not scan the graph or select an engine
inside propagation. Cold benchmarks include this extra metadata preparation for
all variants. Selecting append can request more pairs than chunking; the general
selected queue bound is V+E, with headers/snapshot words separately priced.

Lean's per-fact credit proof bounds actual hybrid copying/frame fees plus
per-write decisions by H. The selected actual declared charge is <= both A and H,
and explicit common setup costs can be added. These are ceilings over possible
writes: the choice does not claim to minimize actual alternate costs on a
partially active/unseeded source, machine CPU time, GC or peak memory.

### Reproduction and evidence

- `just benchmark-closure`: 640 rows, ten size/shape settings, both seeds,
  cold/warm, four engines, four trials. Rotate engines through all four process
  positions and report middle-pair medians. Fixed 20-second/1-GiB child bounds.
- `just benchmark-closure-paired`: five targeted workloads, same process and
  compiled plan, eight rotations, 200 fresh-bottom solves per candidate/rotation.
  The 160 raw observations include GC and instrumentation. Report means across
  balanced rounds, distinct from the separate-process medians.
- Both workflows use Scheme/Gerbil timers, process/JSON/hash libraries and the
  existing external timeout. Failures/timeouts remain in checkpointed receipts.
- The existing native runner also drives Lean. The v3 parity checker compares
  640 matching observations and 10880 fields, including engine and both ceilings.

Current files: [independent processes](performance/closure-selection-v3.json),
[same-process controls](performance/closure-selection-paired-v3.json) and
[cross-runtime checks](performance/closure-selection-parity-v3.json).
The [initial development diagnostic](performance/closure-selection-initial-v3.json)
retains a negative hub-chain auto result before the final fast paths. Its source
hashes identify that earlier development snapshot; it is not a current-source
pass. Existing v1/v2 receipts and timing tables above remain historical.

The final same-process seeded means (CPU ms/solve, eight rotations) are:

| Shape | append | chunked | hybrid | auto |
|---|---:|---:|---:|---:|
| diamond, 1024 | 0.09511 | 0.10077 | 0.10313 | 0.09167 |
| hubchain, 1024 | 0.06709 | 0.07538 | 0.07756 | 0.06622 |
| ring, 1024 | 0.06908 | 0.07930 | 0.07907 | 0.06831 |
| bursts, 1024 | 0.06212 | 0.07229 | 0.04946 | 0.04919 |
| dense, 256 | 1.15188 | 0.73271 | 0.74428 | 0.76070 |

Auto selects append for the first three shapes and hybrid for bursts/dense.
Relative to hybrid these local matched means are about 11%, 15%, 14% lower for
the target shapes. Dense remains slower than chunked/hybrid. Independent-process
results can disagree; the initial negative receipt is retained. These data do
not establish stable universal speedups or price calibration.

## Earlier v2 implementation and measurements

The following records the earlier default, three-trial tooling and historical
v2 observations. The current automatic strategy and v3 controls above supersede
those default and matrix descriptions. The original raw receipts are preserved.

### Representations and allocation tradeoffs

`solve-closure` accepts optional queue, state and price arguments:

```scheme
(solve-closure plan 'hybrid 'owned (closure-policy 1 4 4))
```

- Queue `hybrid` (the v2 default; now explicit): skip empty watcher lists, share directly when the
  current tail is empty, otherwise copy when degree * copy <= suspend + resume;
  suspend the tail otherwise. Singletons use a direct `cons` on the copy path.
  The default prices `(1,4,4)` are a declared reference profile, not calibrated
  hardware timings. `closure-policy` accepts nonnegative fixnum prices, including
  zero, and solve validates the multiplication range before entering the loop.
- Queue `minimum-allocation`: append when E <= V, chunked otherwise. This remains
  an explicit option minimizing two declared worst-case queue-cell bounds.
- Queue `append`: copy watcher spines, requesting V + actual pushes <= V+E pairs.
- Queue `chunked`: share watchers and suspend one tail per write, requesting
  V + actual writes <= 2V pairs. Empty/small watchers can make it slower.
- State `owned` (default): exclusively held scratch bytes, no propagation copies.
  State `copied`: copy the complete bytevector before each write.
- Every strategy starts from bottom and publishes a private copy of V bytes.
  Immutable compiled watchers can be shared; published snapshots never alias
  scratch bytes. Initial storage, headers and alignment are additional.

Macros generate separate append, chunked and hybrid engines; public dispatch is
once per solve. Existing controls do not acquire a per-write queue-mode branch.
Prices affect queue scheduling and preserve exactly the same work order, store
and original counters. For C copied cells, F frames, P actual pushes and W writes,
Lean proves copy*C + (suspend+resume)*F <= both copy*P and (suspend+resume)*W,
C+F <= P <= E and F <= W <= V. Under the default prices, requested queue pairs
are at most V+min(E,8V). Shared/empty shortcuts cost zero in this differential
ledger. Price comparisons, common dispatch and instrumentation are outside it.
These are not minimum machine-time or global allocation theorems.

`closure-counts` returns a copied vector with the original thirteen positions:
pops, evaluations, AST nodes, writes, pushes, frame allocations, frame pops,
fact reads, joins, literals, queue pairs, propagated state-copy bytes, peak frames.
Four appended positions are hybrid copied watcher cells, empty schedules, direct
shares and inline schedules. Legacy append has no hybrid copied-cell counter;
benchmark receipts normalize its copied cells to actual pushes. Snapshot copying
and initialization remain separate from propagation-copy bytes.

The Lean companion retains its byte representation/write laws, V+E work bound,
layout/rounding ledger, explicit copying and weighted primitive ceilings. The new
hybrid proofs refine that same finite positive solver. Actual allocator headers,
GC, CPU latency and compiler correctness are not proved. A backend must justify
layout, ownership, scalar return and its primitive prices. This advances the
paper's generalized-protocol future work, within concrete positive equations.

### Checks and complex workloads

- `t/closure-test.ss`: 512 three-fact equation combinations, independently solved
  by synchronous scalar truth tables, checked across four representations and four price profiles;
  private source copies, retained topology, revocation, malformed input, cyclic
  input refusal, empty systems, dense allocation, singleton/empty shortcuts,
  invalid prices and counter partition.
- `t/cyclic-access-test.ss`: actual POO public slots for membership, quorum,
  shared approval/team cycles, compliance join and source revocation across 32
  configurations. Old public snapshots survive refused reconfiguration.
- Native benchmark families: multilevel diamonds, dense shared dependencies,
  seeded/unseeded rings, skewed ASTs, partial gates, quorum chains, hub chains
  and successive fan-out bursts. Ten size/shape settings, both seeds, cold/warm
  scopes, three queue engines and three independent trials produce 360 rows.
  Cold has five compile/solve/publication iterations; warm has 400 solves with
  retained immutable compilation. Input AST creation precedes the CPU clock.

### Scheme-native performance tooling

Use the commands in [Reproduction](#reproduction). `just benchmark-closure`
requires no Lean checkout and writes `.build/closure/closure-benchmarks.scm`.
The driver uses `:std/misc/process`, SHA-256, and native Scheme `read`/`write`.
It retains failed launches/checks/timeouts and rejects incomplete or duplicated
matrices. `t/closure-parity.ss` validates the standalone study, including its
fixed cases and row shapes; the benchmark child owns scalar-oracle checks.
`closure-report.ss` reports Scheme CPU and allocation medians.

The observations below are historical receipts, tied to their recorded sources
and the drivers at those commits. Their old JSON commands and cross-project
layout are superseded by the standalone native commands above.

[Current raw observations](performance/closure-hybrid-v2.json) and
[4680 matching count assertions](performance/closure-hybrid-parity-v2.json)
cover 360 matched runs in each runtime. The v1 raw/parity files remain historical
receipts of their recorded sources, including the earlier removed Python driver.
They are not receipts for current source identities.

Compare CPU timing only within Scheme and within the same scope. Lean measures
monotonic elapsed time and includes source construction in cold runs, so there
is no cross-runtime speed ratio. Instrumentation and GC remain in measurements.
The raw results retain cases where a fixed engine is faster than the hybrid;
explicit queue policies remain useful. No universally fastest engine is claimed.

### Recorded local timing, including regressions

The v2 seeded warm medians below are CPU milliseconds per solve (three separate
processes, 400 solves each). They qualify this local executable and machine;
small differences are not evidence of stable acceleration.

| Shape | append | chunked | hybrid |
|---|---:|---:|---:|
| bursts, 1024 | 0.05585 | 0.05872 | 0.04379 |
| gated, 1024 | 0.12112 | 0.09433 | 0.08140 |
| dense, 256 | 1.10238 | 0.73042 | 0.73861 |
| ring, 1024 | 0.05765 | 0.05862 | 0.06047 |
| hubchain, 1024 | 0.06096 | 0.06155 | 0.07120 |
| diamond, 1024 | 0.09079 | 0.08928 | 0.10952 |

Bursts reduced suspension requests from 1024 to 32 and total queue pairs from
2048 to 1087. Gated reduced them from 512 to 1 and 1536 to 1025. Ring eliminated
frames without reducing total pairs; diamond copied more cells than chunking.
These negative latency controls show why a declared local fee minimum cannot
establish minimum CPU time. Keep explicit engines and calibrate backend prices
against the intended workload before making deployment performance claims.

## v4 matched observations

Eight-rotation same-process means, milliseconds per request:

| family / scope | append | chunked | auto |
|---|---:|---:|---:|
| dense 256 cold | 3.572 | 2.613 | 2.845 |
| dense 256 warm | 1.204 | 0.846 | 0.852 |
| dense 256 refresh | 3.602 | 2.909 | 3.135 |
| diamond 1024 cold | 0.125 | 0.268 | 0.239 |
| bursts 1024 warm | 0.059 | 0.069 | 0.052 |

Auto is not uniformly fastest. Fixed chunked remains faster in dense cold/refresh;
diamond cold still regresses relative to append. Independent-process receipts
also retain noisy/negative outcomes and include initial setup separately. The
initial Lean v4 run had 19 launch failures during relinking; its raw receipt is
retained in Lean and excluded from accepted parity/performance evidence.
