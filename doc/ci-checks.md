# Standard compilation and complete CI acceptance

The workflow uses a verified precompiled Gerbil release. It builds neither the
compiler nor Bazel. Linux jobs run on `ubuntu-latest`; local macOS results are
reported separately. The setup action uses `gerbil --version` and `pkg-config`
for host dependency identity, without interpreting generated Scheme expressions.

The 25 declared test packages have separate compilation and semantic jobs. Along
with the shared build, representation-entry and full single-process jobs, this
retains 53 checks. Job enumeration lists package declarations; the project does
not parse Scheme imports or reconstruct a dependency graph.

The shared job runs `just build-shared`, preparing only the two programs needed
by the complete acceptance and representation checks. GitHub's `hashFiles` and cache action
own exact-source cross-run lookup; `std/make` owns local dependency freshness.
Cache misses are not accepted as success and tests always execute. No project
source-key files, cache admission executable or revision ledger are generated.
The standard upload/download actions transfer artifacts within the current
workflow run, using commit-specific names and their built-in digest verification.

Each compilation job invokes `gerbil build` in its real test package. The
namespace matches that directory. Its artifact contains that package's compiled
interfaces and loadable bodies. Independent test jobs use official directory
discovery; the full job downloads all groups and passes all compiled interfaces
to `gerbil test` in one process, then runs the complete collection paired study.
The representation job runs the paired startup TestSuite, including both unknown
request refusals and the runtime-loaded and linked entries.

Limits remain 300 seconds per build/whole-suite stage, 90 seconds for a focused
case, 1 GiB frontend/test heaps and 2 GiB backend heaps. Compiler tracing and
module/case/harness markers remain visible. No checks are removed for cache hits.
Failures retain their actual build/test status; a queued job or a local pass is
never reported as current-commit remote acceptance.

See [test execution](test-execution.md) for the public commands. These controls
validate repository build and test behavior. They do not formally verify the
Gerbil compiler, operating system, artifact service or lower-level scheduler.
