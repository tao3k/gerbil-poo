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
`just build library`, then `just build-group GROUP` with an explicit output directory. Standard Gerbil load paths supply shared imports.
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
Benchmark executables share `gxi build.ss benchmark TARGET` and the standard
`pkg-config-libs` linker discovery. Result directories contain measurements only;
there are no separate executable installations or custom linker environment switches.
Source tests use the released harness after shared compilation, without a
fabricated source symlink tree or changes to `GERBIL_LOADPATH`.

`just build` keeps the existing complete local inventory: shared compilation,
then four disjoint test batches through at most two fresh interpreters. The
small `t/build.ss` boundary maintains the 1 GiB heap, 300-second stage deadline,
1200-second whole deadline, owned process-group cleanup and actual make progress.
The temporary SSI-first view retains source mtimes and releases expansion state;
it does not implement caching or replace compiler functions. CI still runs the
20 independent compile groups, 20 semantic groups and complete single-process
suite. Actions source/revision admission remains independent of std/make.

The default package output remains `.build/package`; `GERBIL_PATH` explicitly
selects another installation. Just settings can tighten heap/runtime options
without adding environment switches. Full payloads remain outside Git. See
`performance/build-summary.org` for historical macOS receipts and unresolved
cold-build acceptance; they are not current Linux performance controls.
