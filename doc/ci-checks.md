# Standard compilation and complete CI acceptance

The workflow uses a verified precompiled Gerbil release. It builds neither the
compiler nor Bazel. Linux jobs run on `ubuntu-latest`; local macOS results are
reported separately. The setup action uses `gerbil --version` and `pkg-config`
for host dependency identity, without interpreting generated Scheme expressions.

The 25 declared test packages have separate compilation and semantic jobs. Along
with the shared build, representation-entry and full single-process jobs, this
retains 53 checks. Job enumeration lists package declarations; the project does
not parse Scheme imports or reconstruct a dependency graph.

Collection-delta and coordinator-recovery suites share their existing functional
owners through standard multiple TestSuite exports. There are 144 physical test
modules; the Suite names, cases and observed execution order are retained. The
three collection include bodies are explicit `extra-inputs`, so standard make
tracks their freshness. Package and compiler-partition boundaries are unchanged.
This reduces loadable products; it is not a claim of stable wall-clock speedup.

The shared job runs `just build-shared`. The root package builds the shared
libraries and `representation-main`; complete collection acceptance loads its
ordinary module through that entry. The startup benchmark has its own small
standard executable package. It does not relink the complete collection graph.
The root entry keeps its library declarations and the existing foundation
executable in one standard make graph. The released Darwin compiler owns reuse
of runtime machine objects for dynamic and static consumers. No project object
cache or reconstructed dependency graph is installed.
GitHub's `hashFiles` and cache action
own exact-source cross-run lookup; `std/make` owns local dependency freshness.
Cache misses are not accepted as success and tests always execute. No project
source-key files, cache admission executable or revision ledger are generated.
The startup package retains `defbuild-script`'s backend parallelism through
`GERBIL_BUILD_CORES`. Serializing an entire make with `parallelize: #f` would also
disable concurrent backend object compilation. The 90-second startup-program
gate remains separate from the 300-second root-library build.
The complete local entry prints standard `/usr/bin/time -p` wall/user/system observations
for shared preparation, startup preparation, test-package preparation, the whole
test process and the collection study. Existing commands, progress and failure
markers remain intact; phase CPU observations do not isolate GC or loader costs.
The local test-package phase uses six compiler-only standard packages, whose
specifications reuse the 25 public CI package declarations. At 12 physical cores,
Just's existing parallel dependency queue admits four packages, each using two
standard Gerbil backend jobs. This bounds retained compiler contexts without
replacing make's dependency, freshness or backend scheduling. Each real package
start and completion prints its name and wall/user/system times. The root build
uses the machine's standard `GERBIL_BUILD_CORES`; no new concurrency variable is
introduced. See [build-summary.org](performance/build-summary.org) for qualified
local observations; historical cohorts are not interchangeable.
The standard upload/download actions transfer artifacts within the current
workflow run, using commit-specific names and their built-in digest verification.
The shared library/program artifact uses an uncompressed tar in runner temporary
storage to retain executable permissions across ZIP transfer. No benchmark data
or archive is committed. Consumers compare the producer's compiler/host identity
and execute the prepared programs without rebuilding them.

Each compilation job invokes `gerbil build` in its real test package. The
namespace matches that directory. Its artifact contains that package's compiled
interfaces and loadable bodies. Independent test jobs use official directory
discovery; the full job downloads all groups and passes all compiled interfaces
to `gerbil test` in one process, then runs the complete collection paired study.
The representation job runs the paired startup TestSuite, including both unknown
request refusals and the runtime-loaded and linked entries.

Static packaging checks run through `just check-layout` in the shared build and
cached full acceptance. `t/tools` tests actual POO CLI/debug/metadata behavior;
object lifecycle assertions belong to `t/objects`. There is no separate
`tools/build` suite that launches Just or mirrors its recipe text. Gerbil owns
CLI/make/runner validation; POO's compiler failure-drain support is imported as
source during builds, not compiled into the runtime library.

Limits remain 300 seconds per build/group stage, 90 seconds for focused checks,
and 600 seconds for complete-suite imports plus execution. Runtime/test and
isolated CI-package heaps remain 1 GiB; complete compiler contexts, root and
backend heaps retain the approved 2 GiB ceiling. Compiler tracing and module/case/harness
markers remain visible. All POO behavior checks run on cache hits too.
Failures retain their actual build/test status; a queued job or a local pass is
never reported as current-commit remote acceptance.

Cold macOS acceptance uses an initially empty standard `GERBIL_PATH`, followed
by `just check 2 1 4`. It cannot borrow previously generated objects. In the
installed release, `std/make` clean removes declared outputs but can retain
numbered loadable objects; the loader selects the last contiguous numbered
object. A changed interface beside an older higher-numbered body is therefore
not a valid cache cohort. After an interrupted build or compiler/interface
change, do not admit such a directory on the strength of a no-op build alone;
use an empty output prefix for acceptance. Ordinary same-source warm builds
remain owned by `std/make`, without project file scanners or a second loader.

See [test execution](test-execution.md) for the public commands. These controls
validate repository build and test behavior. They do not formally verify the
Gerbil compiler, operating system, artifact service or lower-level scheduler.

## Exact full-entry observations

The existing standard-built `representation-startup` program also accepts one
empty output-prefix argument to observe the unchanged `just check 2 1 4 600`
entry. Build/test ownership remains with Gerbil and Just. Its parent forwards
real progress and records exact monotonic ticks at test invocation, HARNESS
start/end, final OK, standard process-time output, EOF and successful child reap.
A nonzero child exit, missing/nonmonotone boundary or incomplete case delivery
refuses admission; an OK marker alone is insufficient. Prefixes used for cold
comparisons must not already exist. The parent executable and compiler remain
prepared; this is cold project output, not a purged operating-system cache.

Preparation includes wrapper startup, imports, mappings and initialization.
Execution can include deferred loads and independent consumer builds. The
post-report window includes teardown, pipes and wrapper reaping, so these
windows must not be labelled exclusive dyld or GC time. The ordered suite/case
trace digest excludes module filenames to permit fixture-free suite regrouping,
while retaining every suite, case and order. Raw logs and samples remain outside
Git. `check-observation-test` covers missing/reversed boundaries and a real
standard TestHarness with a failing middle case, original cause identity and
continued later-case execution.

## Standard module initialization

The released `gxtest` source calls `import-module file #f #t`: reload is false,
evaluation is requested. Its module evaluator forces the context's existing
promise. The standard runtime loader returns cached builtin/loaded states,
waits for an in-progress load, and rethrows a cached original error until an
explicit reload. This audit found no forced-reload loop in the test entry. It
supports retaining those standard owners rather than adding a project loader
or successful-initialization cache. These source mechanisms do not, by
themselves, assign measured wall time to individual initializers or prove the
compiler/runtime implementation.

## Fixture-free TestSuite composition

The official runner evaluates each compiled test interface and loads its `~0`
code image directly. Its generated loader stub is not a second test-image load.
Adjacent suites without module fixtures now share 62 declared test roots instead
of 144. Standard `let` scopes retain private helpers, each suite is constructed
once, and exports retain the original suite/case order. Modules with setup or
cleanup stay separate. `extra-inputs:` records every included source in the
existing `std/make` declaration; no source scanner or alternate loader is used.
Signature contracts share the existing contract/method build graph, balancing
its work with the inference graph. The four-worker/standard-backend allocation
and every deadline and heap ceiling remain unchanged.

Metadata report admission owns its source/dimension definition. The workload
imports that definition; reading a report no longer imports or initializes the
whole workload. The standard prepared-harness fixture refuses that dependency
if it returns. This removes one additional image, not the entire business
closure: other tests legitimately use those business modules.

The finite Lean model already proves ordered fixture-free regrouping, retained
refusal results and subsequent state (`observeSuiteCases_regroup_between`), and
permutation invariance when repartitioning the resulting compile declarations. See
[BuildPreparation](https://github.com/tao3k/lean-poo/blob/2652a2a531a6eec321f0d0665b5a5647d997cc07/LeanPoo/Prototype/BuildPreparation.lean#L140).
Absence of hooks/context-sensitive effects is a premise, checked here by retaining
fixture modules and the complete execution trace. This does not verify GXC,
Gambit, dyld or macOS library validation.

## Frozen-source cold controls

The read-only 30-second `fs_usage` trace isolated 29.118 seconds in 281 `F_CHECK_LV` calls;
55 calls longer than 10 ms accounted for 29.116 seconds. Compiled private type
metadata and runtime code were among the actual paths. Same-file checks were
usually fast after first validation; the standard module registry was already
deduplicating loads. The changes therefore remove unnecessary physical images,
not validation or loader failure handling. No system security setting changed.

Two A/B controls used the same physical compiler closure (6,875 checked files),
12 automatic cores, previously absent output prefixes, and the unchanged complete
`just check 2 1 4 600` entry. OS/compiler caches were not purged. Temporary SRFI-27
streams 0/1 and one state-restoration control made container inputs replayable in
both variants; those controls were removed afterward. Production retains its
original randomized checks. All completed controlled runs delivered 2,285
cases with trace `cf948e090f0fc361cf09429f54714e022bab4e2c16dc4df9cf6dd59c1ceca7ae`.

| Trial | Result | Complete-entry wall seconds |
| --- | --- | ---: |
| Original A1 | test build hit its 300-second guard; standard clean completed | incomplete (591.09 spent) |
| Candidate B1 | complete, natural exit | 738.84 |
| Original A2 | complete, natural exit | 744.13 |
| Candidate B2 | complete, natural exit | 646.90 |

A2/B2 reduced wall time by 97.23 seconds (13.1%), including conversion/preparation,
all test execution, independent consumer checks, both paired studies and reaping.
Its preparation window fell from 227.09 to 158.92 seconds; observed dynamic module
entries fell from 714 to 631. Test-package compilation increased from 153.28 to
198.99 seconds, and total user CPU increased from 1,328.44 to 1,459.20 seconds.
The CPU/compilation tradeoff is real; fewer images alone is not acceptance.
The failed A1 remains a failure, not a latency sample or a discarded outlier.
Two controls do not establish a tail percentile or a universal wall-time bound.
Raw traces, patches, generated outputs and complete benchmark rows stay outside Git.
