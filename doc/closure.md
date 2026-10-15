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

## Representations and allocation tradeoffs

`solve-closure` accepts optional queue, state and price arguments:

```scheme
(solve-closure plan 'hybrid 'owned (closure-policy 1 4 4))
```

- Queue `hybrid` (default): skip empty watcher lists, share directly when the
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

## Checks and complex workloads

- `t/closure-test.ss`: 512 three-fact equation combinations, independently solved
  by synchronous scalar truth tables, checked across four representations and four price profiles;
  private source copies, retained topology, revocation, malformed input, cyclic
  input refusal, empty systems, dense allocation, singleton/empty shortcuts,
  invalid prices and counter partition.
- `t/closure-workflow-test.ss`: actual POO public slots for membership, quorum,
  shared approval/team cycles, compliance join and source revocation across 32
  configurations. Old public snapshots survive refused reconfiguration.
- Native benchmark families: multilevel diamonds, dense shared dependencies,
  seeded/unseeded rings, skewed ASTs, partial gates, quorum chains, hub chains
  and successive fan-out bursts. Ten size/shape settings, both seeds, cold/warm
  scopes, three queue engines and three independent trials produce 360 rows.
  Cold has five compile/solve/publication iterations; warm has 400 solves with
  retained immutable compilation. Input AST creation precedes the CPU clock.

## Scheme-native performance tooling

`just build` and `just test` use the normal package environment. For isolation,
set `GERBIL_PATH` to a temporary environment. `just benchmark-closure` builds the
native executable and writes `.build/closure/receipt.json`. No Python is needed:

- `t/closure-scale-benchmark.ss`: Gambit `cpu-time`, full result forcing and
  independent scalar oracle plus queue/cost assertions.
- `t/closure-suite.ss`: Gerbil `:std/misc/process`, JSON and SHA-256 libraries;
  source/binary/driver identities, toolchain, platform and per-row checkpoints.
  Failed launches, checks and timeout rows remain in the receipt and fail the
  suite. Existing external `timeout` enforces 20 seconds per child, with the
  unchanged 1 GiB Scheme heap limit.
- `t/closure-report.ss`: Scheme median-of-three CPU summaries.
- `t/closure-parity.ss`: Scheme cross-runtime checker, rejecting nonpassing rows,
  duplicates, incomplete matrices, stale local sources and mismatched counts.

```sh
just benchmark-closure
gxi t/closure-report.ss .build/closure/receipt.json
# After building hybridClosureScale in the Lean companion:
gxi t/closure-suite.ss /absolute/lean-poo/.lake/build/bin/hybridClosureScale \
  /absolute/timeout /tmp/lean-hybrid.json lean /absolute/lean-poo
gxi t/closure-parity.ss /tmp/lean-hybrid.json .build/closure/receipt.json \
  /tmp/parity.json /absolute/lean-poo
```

The same native Scheme runner supervises both binaries. Lean children have the
20-second deadline; no native Lean heap limit is asserted. Darwin linker search
paths can be overridden with `GERBIL_CLOSURE_LD_OPTIONS`; the default uses the
stable Homebrew OpenSSL opt path.

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
