# Standard compilation and complete CI acceptance

The workflow uses a verified precompiled Gerbil release. It builds neither the
compiler nor Bazel. Linux jobs run on `ubuntu-latest`; local macOS results are
reported separately. The setup action uses `gerbil --version` and `pkg-config`
for host dependency identity, without interpreting generated Scheme expressions.

The 25 declared test packages have separate compilation and semantic jobs. Along
with the shared build, representation-entry and full single-process jobs, this
retains 53 checks. Job enumeration lists package declarations; the project does
not parse Scheme imports or reconstruct a dependency graph.

The shared job runs `just build-shared`. The root package builds the shared
libraries and `representation-main`; complete collection acceptance loads its
ordinary module through that entry. The startup benchmark has its own small
standard executable package. It does not relink the complete collection graph.
The root entry composes the independent property library, the POO library-only
declaration and `examples/build.ss`, in that order, within the same 300-second
guard. The examples package declares the existing executable with its existing
module identity. This separation matters: the released `std/make` requests static
runtime objects for every library in a declaration containing an `exe:`. Keeping
the library declaration free of executables lets the executable compiler prepare
only its actual static dependency closure. Standard freshness and parallel jobs
remain responsible for those objects; there is no project object cache.
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
The local test-package phase runs the 25 ordinary package declarations using
the existing `xargs` with `max(1, floor(GERBIL_BUILD_CORES / 2))` concurrent
`gerbil build` commands and one backend slot per command. Each package prints
`BUILD-PACKAGE` and its directory before invoking the CLI. Its phase duration
includes every package's import/expansion and freshness checking, even when no
backend compilation is needed; it is not the delay to the first log message.
This policy changes the allocation of compiler work slots, not any heap/deadline
limit. The shared build and the separate CI package jobs keep their standard
backend settings. See the paired whole-entry observations in
[build-summary.org](performance/build-summary.org).
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

The tools job first runs the complete POO build-boundary module through
`just test-atomic build`, enforcing its separate 90-second limit. It then runs
the ordinary tools package; the full single-process job also remains required.
The module directly checks POO's value/error boundary, testing-module paths and
resource recipes. Gerbil's package CLI, make and test-runner self-tests belong
to Gerbil's own validation. POO tests use `:std/test` without nesting another
Gerbil build/test process or recreating dummy packages. The actual POO library
and startup programs still build and execute through the top-level standard CLI.

Limits remain 300 seconds per build/whole-suite stage, 90 seconds for a focused
case, 1 GiB frontend/test heaps and 2 GiB backend heaps. Compiler tracing and
module/case/harness markers remain visible. No checks are removed for cache hits.
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
