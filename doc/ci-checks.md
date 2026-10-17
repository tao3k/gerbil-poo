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

Native Scheme controls exercise group coverage, changed source identities,
malformed receipts, missing interfaces, stale run stamps and unexpected artifact
groups. Temporary admission fixtures are not executable artifacts. Full cold and
warm CI receipts, rather than a subset build's duration alone, qualify any speedup.

## Commands and limits

`just build` still builds the entire original inventory. CI uses
`GERBIL_BUILD_SCOPE=library just build`, then `just build-group GROUP` with an
isolated `GERBIL_BUILD_LIBDIR`. Standard Gerbil load paths supply shared imports.
`test-files` rejects unknown groups and validates complete, duplicate-free source
coverage before the ephemeral Actions matrix is emitted. No matrix JSON is
source-controlled.

Seventeen compilation jobs own disjoint test roots. The existing seventeen
semantic test jobs retain `xargs -P 2`, separate module processes,
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
