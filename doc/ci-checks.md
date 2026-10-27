# Shared compilation and disjoint test artifacts

The preceding complete Scheme CI run built 281 distinct modules and executed 627 distinct
backend jobs. No repeated module or backend job was found. In the timestamped
log, compilation spent about 42 seconds before the first module, 36 seconds
lowering modules, then 168 seconds executing backend jobs. The released Linux
compiler drains backend jobs after graph construction, so those phases did not
overlap. The complete build job took 262 seconds; its compilation step took about
246 seconds. These are different timing boundaries.

The repository consumes the verified, already compiled Gerbil release. It neither
builds that compiler nor adds Bazel. `std/make` continues to own dependency order,
module compilation and backend scheduling. This change splits the existing work:

1. Compile the full shared non-test graph once and publish the current run's
   source-bound artifact.
2. Compile each disjoint functional test group on a separate CI runner against
   that shared graph. Each writes only its own test roots to a separate output
   directory. All previous source inputs and all tests remain covered.
3. Publish the completed group artifacts, then start independent semantic test
   jobs and the complete single-process job concurrently. A failed semantic
   group never prevents the complete single-process check from being attempted.
4. Require the complete group inventory and current revision stamps before
   merging outputs for the single-process run.

Shared compilation has an exact cache key for the release, host compiler/linker,
platform and every non-test/build input. Test-only changes preserve this key.
Group caches additionally bind the exact shared-library byte generation, the
complete test-source snapshot and group source key. Gerbil generates timestamped
internal binding identities, so a rebuild of identical source is not assumed to
match an older compiled group. This deliberately invalidates all test groups on any test edit, covering
possible cross-group macro dependencies without assuming independence of source
semantics. Compilation ownership is disjoint; semantic dependencies need not be.
No prefix fallback, timestamp repair or approval based only on producer SHA is
used. A hit skips compilation, never test execution. Original producer and current
admitted revision remain distinct.

`Functional/BuildCache.lean`, in the existing ConstructionCache namespace, proves
source/revision admission, test/shared identity separation, complete and unique
assembly, and a symbolic parallel critical-path inequality. `Examples/BuildCache.lean`
is in the top-level example inventory. Identities are supplied exact-source keys;
these laws do not establish hash collision resistance, Actions storage trust,
compiler correctness, actual worker overlap, memory bounds or measured speed.
Queueing, artifact transfer and process startup must be measured separately.

Scheme controls exercise group coverage, changed source identities,
malformed receipts, missing interfaces, stale run stamps and unexpected artifact
groups. Temporary admission fixtures are not executable artifacts. Full cold and
warm CI receipts, rather than a subset build's duration alone, qualify any speedup.

## Commands and limits

`just build` still builds the entire original inventory. CI uses
`just build qualification`, then `just build-group GROUP` with an explicit output
directory. Qualification includes every example, test helper and benchmark support
root. Group specifications contain exactly their checked test roots, retaining
declared included-case inputs. Standard Gerbil interfaces and load paths reuse the
qualified support outputs; those modules must not be declared for compilation into
each group's separate output again. Regressions check this ownership for every
group and keep all support roots in qualification. A cold group build and the
complete single-process suite run under the original heap and deadline limits.
`test-files` rejects unknown groups and validates complete, duplicate-free source
coverage before the ephemeral Actions matrix is emitted. No matrix JSON is
source-controlled.

Twenty compilation jobs own disjoint test roots. Twenty semantic test jobs retain `xargs -P 2`, separate module processes,
90-second deadlines, 1 GiB test heaps, real harness progress and typed failure
markers. `fail-fast: false` attempts all groups. The complete single-process gate
retains its 300-second deadline and 1 GiB heap, after group compilation artifacts are available. It is attempted even if an
independent semantic test fails; missing compilation artifacts refuse assembly. Existing
20/10-minute CI job ceilings remain unchanged. Compilation emits standard make
progress and cache hits emit actual source-admission records. No synthetic
heartbeat is used.

All compiler archives, caches, full logs and generated artifacts remain ignored
or in Actions storage. Local development does not depend on a Lean checkout.

Independent group compilers may reload shared expansion metadata; this is
additional runner work, not another source-module/backend compilation. Cold
end-to-end time and warm cache reuse must be reported separately from the
shared job alone. The symbolic cost inequality assumes the same supplied costs.

Every test-compilation runner checks its host C/linker/architecture identity
against the shared producer before restoring or producing a group cache. This
keeps the cache key tied to the backend that actually compiled its bytes, even
though the runner label remains `ubuntu-latest`.

## Compiler-heavy families

The previous mixed methods group overflowed the existing 1 GiB compiler heap
while retaining inference/signature expansion state. It is now four disjoint
functional families: methods (5 modules), inference (6), signatures (6) and
scalars (3). The Actions matrix is still emitted by the same checked Scheme
inventory; all 121 modules remain covered once and all run again in the complete
single-process suite. Each family has its own process/artifact/cache admission.
No heap/deadline increase, skipped test, custom scheduler or compiler rebuild is
introduced. The build regression checks inventory equality/disjointness and the
six-module cap on these compiler-heavy families. The cap is an operational guard,
not a formal upper bound on compiler memory or an end-to-end speedup claim.


## Worker budgets and cache freshness

`GERBIL_BUILD_CORES` is the existing std/make backend-worker budget. The Just
entrypoint selects physical cores unless the caller supplies it; this does not
change the compiler heap or the complete single-process deadline. Functional
compile groups are independent Actions jobs. Semantic groups retain two module
processes and the complete single-process suite remains a separate mandatory job.
A declared worker count, actual worker overlap, process startup and whole-run
elapsed time are distinct measurements.

The companion Lean checks now share ordinary file slots and compile only the
selected workflow import closure for evaluator reuse. Their cache fallback is
followed by Lake's content/options/dependency trace validation. That rule cannot
be copied into std/make admission: this package retains exact source/toolchain/
byte-generation keys, disjoint group ownership and current-run stamps. A source
prefix or repaired timestamp alone cannot admit Scheme compiled outputs. Every
cache hit still executes all semantic groups and the complete single-process
suite. The two projects share admission requirements, not compiler cache formats;
this package has no Lean checkout dependency.

Complete-flow performance comparisons must keep those checks and limits, reverse
variant order and report wall time including preparation/transfer. Existing
source-bound grouping and artifact controls remain mandatory. Full payloads and
compiler archives stay outside Git; neither lower CPU nor fewer bytes establish
an end-to-end improvement on their own.

## Standard build entry and resource boundaries

`build.ss` selects the project inventory and invokes Gerbil's `defbuild-script`.
`gerbil clean` followed by `gerbil build` is the usual package recovery path;
manual selection/deletion of numbered compiled modules is not the workflow.
The SDK object-format migration below requires a fresh generated package root.
The default specification is the shared package graph, so the official package
command does not expand all test roots in the same compiler heap. `just test`
still compiles all disjoint test batches and runs all 148 modules in one process.
Its standard `compile`, `clean`, `spec`, `meta`, `--release`, `--optimized` and
`--debug` options pass through unchanged. `std/make` owns dependency checks,
incremental compilation and backend scheduling. There is no second local build
cache, compiler fingerprint, generation receipt or cleanup algorithm.

Use `just build library` for shared modules and `just build-group GROUP` for an
explicit functional group/output directory. `gxi build.ss library spec` and
`gxi build.ss tests objects /tmp/poo-tests spec` inspect those standard specs.
Selection is expressed in arguments, rather than project-specific environment
variables. Gerbil's own `GERBIL_PATH`, `GERBIL_BUILD_CORES` and
`GERBIL_BUILD_VERBOSE` retain their standard meanings.
Libraries and executables use Gerbil's default `lib` and `bin` under that
installation; only CI group artifacts pass an explicit library output directory.
After library preparation, benchmark executables share
`gxi build.ss benchmark TARGET` and the standard
`pkg-config-libs` linker discovery. Result directories contain measurements only;
there are no separate executable installations or custom linker environment switches.
Standalone study specifications contain their own roots. On Darwin, the test
program instead shares one graph with its complete library/example prerequisites,
so the SDK can emit shared/static objects in the same compilation.
Source tests use the released harness after shared compilation, without a
fabricated source symlink tree or changes to `GERBIL_LOADPATH`.

`just build` keeps the complete local inventory. Darwin first constructs the
shared library and test program together, then compiles all eight disjoint test
batches through at most two fresh interpreters. Other platforms retain their
qualified library, test batches and final program construction. The
small `t/build.ss` boundary maintains the 1 GiB heap, 300-second stage deadline,
1200-second whole deadline, owned process-group cleanup and actual make progress.
The temporary SSI-first view retains source mtimes and releases expansion state;
it does not implement caching or replace compiler functions. CI retains every independent compile/semantic group and the complete
single-process suite. Actions source/revision admission remains independent of std/make.

The default package output remains `.build/package`; `GERBIL_PATH` explicitly
selects another installation. Just settings can tighten heap/runtime options
without adding environment switches. Full payloads remain outside Git. See
`performance/build-summary.org` for historical macOS receipts and unresolved
cold-build acceptance; they are not current Linux performance controls.


## Single-process test linkage

`test-program` uses the existing `defbuild-script` entry and Gerbil executable
linker. On Darwin its single graph includes the complete qualification inventory
and resolves normal source dependencies before interfaces exist. Other platforms
consume qualified interfaces through the existing standalone consumer path.
The original runner still loads and prepares every test module. Code freshness follows
std/make dependencies and CI's existing source/revision admission. At startup it
checks the complete test inventory against its captured filenames and requires
each selected shared library to be a linked builtin in the standard runtime loader.

`just _test t 300` executes the standard linked program directly with the 1 GiB heap and
300-second deadline, including launcher and executable initialization. The timeout
owns the process group so cancellation also reaches the test child. No toolchain
paths or environment variables are synthesized. The original released
gxtest runner still owns export discovery, preparation, setup/cleanup, module and
case order, assertions and failure status. Individual-file checks use the same
released runner through gxi and retain their existing 90-second boundary.

`TEST-LOAD-END` now reports Gambit's CPU, elapsed, GC CPU and collection counters
without forcing GC. In the linked program, data initialization occurs before the
runner starts; complete startup comparisons therefore include external process
wall time. Raw measurements remain outside Git. See
[the loading study](performance/test-loading-summary.org) for the cold-path
controls, first-link cost and the boundaries of the performance evidence.


## Joint Darwin object construction

The SDK's `std/make` enables shared/static runtime object production when its
build graph contains an executable. Separate qualification and executable graphs
miss that opportunity: the former compiles runtime module bodies, while the
latter regenerates and compiles their static counterparts. Counting distinct job
labels or output paths alone cannot detect this repeated source work.

The Darwin `test-program` request now appends its standard executable to the
complete qualification graph. Its metadata inspection uses ordinary source
imports in that graph, allowing a clean build without pre-existing SSI files.
The SDK owns dependency order, shared/static object emission and linking. The
full driver constructs the program once before all eight test compilation
batches; runtime execution still waits for every batch. The collection entry
also drops its redundant standalone library preparation. Package-only builds
and the dynamically loaded runtime path on other platforms retain their scope.

Local standard-clean controls used the same source, 12-worker
budget, 1 GiB compiler heap and 300-second stage limit, in joint/split/split/joint
order. Only the existing build entry's graph selection changed:

| Construction path | Stage wall seconds | User CPU seconds |
| --- | --- | --- |
| Separate qualification/consumer | 111.62, 108.28 | 359.08, 354.87 |
| Joint graph | 74.50, 78.99 | 271.07, 275.07 |

Compiler invocation traces confirm the mechanism: the separated path compiles
`table`'s runtime body and later its static body; the joint path generates C and
compiles one static object used for both outputs. Queued job names alone are not
used as compiler invocation evidence. The complete standard-clean `just build`
then compiled all 148 test modules in eight batches in 270.91 seconds. Runtime
execution was timed separately: all 1,734 cases passed, the harness took 135.70
seconds, and the complete test-plus-paired-study entry took 157.70 seconds.
The 300-second limits apply per stage; whole-entry wall time is recorded
separately. These local observations do not establish a portable speedup ratio.
Raw traces and program comparison artifacts remain outside Git.

Regressions retain the complete qualification inventory exactly once, one
executable, option forwarding, standalone ownership and clean ownership. The
interrupted-producer fixture now retries a real library-plus-executable graph
from absent interfaces and executes its linked program. Heap limits, runtime
checks, timeout refusal and owned process-group recovery remain unchanged.


Runtime price remains a separate acceptance dimension. Preserved split and joint
programs ran the unchanged Scheme collection study at width 8, count 2,
four balanced rounds, in BAAB then ABBA process order (four runs per program).
All eight semantic oracles passed. Whole-process wall ranges were 6.72–7.94 s
(split) and 6.75–8.21 s (joint); their means were 7.125 and 7.210 s. Loaded-entry
CPU means were 6.8516 and 6.9138 s, with non-GC CPU means 4.7058 and 4.7596 s.
Thus these controls retain a measured +1.2% whole-process wall and +0.9% loaded
CPU difference for the test executable; they are not evidence of runtime cost
equivalence. The construction change uses the SDK's shared object representation
rather than separately compiled static objects. Runtime representation pricing
remains distinct from the verified reduction in compiler work. Production POO
algorithms and the Lean semantic model are unchanged. No timing threshold or
failure check was loosened; raw histories and binaries remain outside Git.


An unchanged-source repeat of the complete final build passed in 38.30 seconds.
Verbose compiler tracing contained zero actual GSC/GCC invocations. This confirms
standard artifact reuse for this source snapshot; dependency inspection, metadata
loading and process startup still contribute to that whole-entry time.

### Dynamic object format migration

A later Set admission regression exposed a separate migration hazard in this
released Darwin SDK. The shared/static reuse branch in compiler `driver.ss`
emits a fixed runtime `.o1`, while the loader can select an older higher-numbered
dynamic object left by ordinary split compilation. The observed module paths were
the current `table.o104` stub followed by the old `table~0.o84` body, despite the
current generated body and `.o1` containing the repair. A bounded recursion probe
therefore still ran the old recognizer. This is not evidence against the generated
repair, and successful compilation alone is not evidence of current dynamic loading.

Standard `gerbil clean` delegates to `std/make` declared outputs; it removes SSI
and static outputs but does not erase those numbered dynamic versions. The earlier
controls above are consequently standard-clean construction receipts, not proof
that every dynamic artifact was absent. Migrating this existing local output from
split compilation to shared/static reuse requires a fresh generated package root.
For the current acceptance the old project-owned output is moved outside Git for
diagnosis, and the SAME standard `.build/package` path is reconstructed. No runtime
load-path override, versioned receipt, permanent cleanup engine or SDK patch is added.
CI's source-keyed Linux builds remain a separate platform qualification. Arbitrary
mixing of old/new SDK object formats is not certified by the collection proofs.

### Native dependency installation

The package build entry uses the ordinary `gxi` interpreter directly. A fixed
180-second shebang deadline incorrectly terminated cold macOS dependency builds
with status124 while native make still had pending compiler jobs. CI and caller
process supervision retain their own deadlines. This removes no Suite, target,
worker limit or heap limit and introduces no retry/build fallback. Gerbil and
`std/make` still own compilation, failures and incremental recovery.

The demand-filled-cell acceptance reproduced that recorded Darwin migration
hazard on an interface change: current object~0.o1 defined object-layout__%, while
an older object~0.o2 exposed only object-layout and was selected by the standard
loader. Declared std/make clean did not remove that numbered body. Retiring the
project-generated package output outside Git and rebuilding the SAME standard
root resolved it; no load-path override or permanent cleanup engine was added.
The full public checks are rerun against that coherent output. This is local
output-cohort recovery, not qualification of mixed SDK compilation formats or a
claim that std/make clean removes every dynamic version.

Package compilation establishes its 2 GiB Gambit heap bound in the native
`build.ss` interpreter invocation. Package-manager indexing uses the compiler
distribution default; callers must not globally apply compiler heap options to
all tools. The package entry has no elapsed-time cutoff.
