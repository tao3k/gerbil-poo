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

`solve-closure` accepts optional queue and state choices:

- Queue `minimum-allocation` (default): append when E <= V, chunked otherwise.
  This minimizes the two declared worst-case queue-cell bounds, not measured CPU.
- Queue `append`: copy watcher list spines into the worklist, requesting
  V + actual pushes <= V+E queue pair cells.
- Queue `chunked`: share immutable watcher lists; suspend one tail per actual
  write, requesting V + actual writes <= 2V queue pair cells. Draining suspended
  frames adds control work. It is not uniformly faster or smaller on every input.
- State `owned` (default): mutate exclusively held scratch bytes; no state copies
  during propagation. State `copied`: copy the complete bytevector before each
  write, explicitly requesting V times actual writes copied bytes.
- Both publish by copying V bytes once at completion. Initial scratch storage,
  final snapshot headers and alignment are additional. No old snapshots alias
  scratch storage; immutable watcher lists can be shared between solves.

`closure-counts` returns a copied vector containing, in order: pops, expression
evaluations, AST nodes, writes, pushes, frame allocations, frame pops, fact reads,
joins, literals, queue pair cells, copied state bytes, peak suspended frames. The final copied bytes
counter covers propagation copies only, not initialization/publication. Counter
instrumentation is included in benchmark time and excluded from the semantic
primitive ledger. Allocator headers, instrumentation allocations, GC time and RSS
are not equated with requested pair/byte counts.

The LeanPoo companion PR #13 proves byte representation/write correspondence,
chunk/append exact array and work-counter refinement, V+E pops/evaluations, V
writes, <=V frame allocation and peak suspension depth. Its explicit layout ledger
prices headers, rounded byte payloads, queue cells, persistent state copies,
boxed/scalar evaluator returns and publication copies. It proves policy-dependent
allocation and weighted primitive ceilings, and a finite minimum among two queue
bounds. Applying these abstract costs to machine time still requires justified
primitive prices, exclusive ownership, scalar return and layout assumptions. There
is no formal translation proof of this Scheme source or a Scheme compiler.

## Checks and complex workloads

- `t/closure-test.ss`: 512 three-fact equation combinations, independently solved
  by synchronous scalar truth tables, checked across three representations;
  private source copies, retained topology, revocation, malformed input, cyclic
  input refusal, empty systems, dense exact queue allocation and counter partition.
- `t/closure-workflow-test.ss`: actual POO public slots for membership, quorum,
  shared approval/team cycles, compliance join and source revocation across 32
  configurations. Old public snapshots survive refused reconfiguration.
- Native benchmark families: multilevel diamonds, dense shared dependencies,
  seeded/unseeded rings, skewed expression trees, partial gates and quorum chains.
  Eight size/shape settings, both seeds, three variants and three independent
  processes produce 144 rows. Each row includes five cold private compilations,
  solves and publication copies. Input AST construction precedes CPU timing;
  process wall time is separately recorded. Each process has a 20-second deadline.

Build and check using the normal package commands (`just build`, `just test`).
For isolated local runs, set `GERBIL_PATH` to a temporary package environment.
`just benchmark-closure` builds the package, compiles the native benchmark and
writes `.build/closure/receipt.json`. Darwin linker search paths can be overridden
with `GERBIL_CLOSURE_LD_OPTIONS`; the default adds Homebrew's stable OpenSSL opt
path to compensate for stale Cellar paths in the installed compiler configuration.

The [raw receipt](performance/closure-layout-v1.json) records source/binary hashes,
all rows and any timeouts/failures. [Companion count parity](performance/closure-parity-v1.json)
identifies both raw receipts and records 672 matching count observations. Compare
CPU variants within Scheme; the Lean monotonic-clock measurements include a
different source-generation scope and do not support cross-runtime speed ratios.
The initial receipt is a local bounded measurement, not a universal performance
claim, peak heap measurement or formal machine-time proof.
