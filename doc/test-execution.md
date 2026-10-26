# Bounded single-process test execution

`just test` builds with Gerbil's standard `std/make`, then runs the complete
checked inventory in **one** process through the released `gxtest` harness.
The heap remains 1G and the deadline remains 300 seconds. No tests are dropped,
no GC is inserted by the runner and no interpreter registry is modified.
`just test-file t/class-validation-test.ss` selects the same compiled test module.
Run `just build` first when invoking individual files after source changes.

## Cause of the Class failure

The former full-suite command passed every source pathname to `gxtest`.
The released expander's `core-import-module` treats those as source imports:
it expands them and retains their module code in its registry. Existing compiled
files do not replace those explicit source imports. The harness prepares all
modules before running the first test. Thus the single process retains the
expanded forms of all 85 test modules, in addition to their runtime fixtures.

The failing natural-GC control reported 926,825,088 bytes of latest-GC live data
before the first test, and up to 952,490,760 at observed module boundaries. The
1G limit was already almost occupied. Failures moved between Class multiple
inheritance/diamond checks and the dense closure check, and appeared as either
stack or heap overflow. All-module import with only Class execution passed;
1,000 independent repetitions passed both with natural and controlled GC.
These controls do not support attributing the failure to leaked Class validation
state. They identify retained source expansion as the dominant avoidable load.

The compiled-interface control started at 117,419,768 bytes and observed at most
153,762,800 bytes of latest-GC live data. These are local observations at module
boundaries, not peak RSS, allocation bounds or an end-to-end speed claim. Raw
negative controls remain outside Git. Cumulative allocation counters on this
runtime can wrap and are not used to draw this conclusion.

## Fix and regression gates

The shared checked inventory supplies build inputs, independent CI groups and
whole-suite selection. Standard build dependencies now include the previously
source-only test helpers. `test-runner.ss` passes compiled `.ssi` interfaces to
**the original harness**, retaining its cases, fixtures, order and refusal checks.
It refuses missing compiled modules rather than silently expanding source.
CI's source cache key includes test sources; the exact producer revision is
checked before both independent tests and the additional single-process job.
Every job consumes the same compiled artifact; the integration job does not build.

Compilation also exposed four existing test cases that used internal
`def` bindings to snapshot mutable counters or traces. Those snapshots now use
explicit lexical sequencing after the measured calls and before reset/replay.
Their expectations and negative checks are unchanged.

Class regression cases reuse warmed parent/diamond metadata through sixteen
failed recursive closures and successful retries in each GC regime. They check
Function wrapping/refusal, canonical cyclic identity, unchanged parent metadata
and inherited defaults. The collected control follows all original Class cases;
forced GC is not used to make the formerly failing cases pass.

This is a test-loading/resource repair. It does not change inheritance order,
recursive admission, FUN/IO semantics, or the scope of the Lean proofs.

A final matched control uses the same revised 85 modules / 558 cases in both
processes, with natural GC and the same 1G cap. Only source versus compiled
interface loading differs:

| Observation | Source interfaces | Compiled interfaces |
| --- | ---: | ---: |
| Latest-GC live bytes before first test | 926,850,176 | 117,312,264 |
| Maximum observed at module boundaries | 939,018,968 | 153,040,272 |
| Outcome | Heap overflow in dense closure; exit 70 | All 85 modules / 558 cases; exit 0 |

The earlier failing source run and the final failing control remain negative
receipts. The compiled run neither skips the dense closure nor lowers its size.
The Class regression also passes through the original source-file runner when
executed standalone. This identifies a bounded full-harness loading failure;
it is not a general claim about all Class callbacks or GC implementations.

## Failed compiler recovery

Every `just build` target uses the existing bounded process-group boundary.
A failed stage is reaped before standard cleanup of its selected target/output;
its original failure is rethrown. This prevents early `.ssi`/static outputs from
turning a killed backend into a false incremental hit. Compiler flags are removed
from the cleanup request. A recovery failure stops subsequent admission and
retains both causes. Standard make still owns the dependency graph, worker pool
and successful cache reuse. The production stage remains 300 seconds / 1 GiB,
and the complete build remains 1200 seconds.

The build regression performs an actual short timeout in a temporary fixture,
verifies both partial outputs disappeared, then compiles the same module through
`defbuild-script`. No production deadline is shortened for that control. See
[the build study](performance/build-summary.org) for cold/warm measurements and
supervisor-interruption boundaries.

The boundary invokes the public `gxi` launcher used by `just`, rather than the
linked executable's `~~bin` alias, which can retain the SDK producer's path.
Release relocation and runtime activation stay with the SDK. The compiled
recovery fixture verifies a produced-output marker and the standard runner's
representation of exit 124 before testing cleanup and serial-mode rebuild.

The benchmark wrapper now uses the same boundary with its existing 90-second
argument (300 for its existing explicit override). Ordinary compiler stages still
receive 300. These bounds are passed explicitly and validated at the boundary;
the 1200-second supervisor does not lend additional time to a compiler stage.
Recovery uses the same stage bound and always retains the original failed result.
Consumer cleanup also cleans its owned `qualification` prerequisites: their
metadata may have been produced before consumer construction was reached.

## Process-group cleanup on macOS

The stage now logs `BUILD-PROCESS-END` with its direct child's raw standard wait
status before cleanup. A compiler error or timeout therefore remains distinguishable
from a later cleanup refusal. Cleanup errors retain the request, PID, wait status
and original cause; a refused group stops admission and prevents standard clean
from racing a potentially executing compiler.

Darwin's [`killpg1` implementation](https://github.com/apple-oss-distributions/xnu/blob/main/bsd/kern/kern_sig.c#L1612-L1621)
excludes zombie members from its recipient iteration. An existing group containing
only zombies can therefore return `EPERM`, although it has no executing members.
A bounded local reproducer retained one exited child with `waitid(WNOWAIT)`:
group SIGKILL returned EPERM, and reaping that child changed the group probe to
ESRCH. This is an OS cleanup observation, not a claim about POO or its proof model.

On EPERM, the supervisor reads the standard `ps` group/state snapshot. It retires
only an explicitly nonempty all-zombie group, recording `BUILD-GROUP-TERMINAL`.
An empty snapshot also requires the kernel's ESRCH response. Any active/unknown
member, malformed or failed snapshot, or genuine permission refusal remains an
error. Non-child zombie entries are reclaimed by their OS reaper; this check does
not claim that the supervisor can wait for another parent's children. Ordinary
success/ESRCH takes no snapshot. No extra callback contract or business namespace
is introduced.

Cancellation snapshots the existing registry under its mutex, visits every group
without holding that mutex, records cleanup failures, and exits nonzero even if
one cleanup refuses. Regression cases cover zombie flags, active/unrelated groups,
invalid owner IDs, disappearing groups, refused probes and malformed snapshots;
the existing actual interrupted-build/clean/retry test remains intact. The 1 GiB
heap, 300-second stage/runtime deadlines, three-second timeout kill grace and
1200-second complete build deadline are unchanged.

### Distinguishing an abandoned SDK object lock

The same investigation exposed a separate, real timeout: the executable object
compiler waited on `lib/static/clan__poo__table.o.lock`. The SDK's `compile-obj`
waits for an existing lock file; SIGKILL cannot run its Scheme unwind cleanup.
Standard `make-clean` removes declared outputs, which do not include this lock.
Re-running clean/build without investigating that file repeats the wait.

For the observed local failure, process inspection and `lsof` confirmed no live
owner; the one orphan was moved outside the checkout as diagnostic evidence.
Do not delete locks based on age or suppress the stage timeout. Confirm that no
producer is running and that the exact lock has no open owner before recovering
it, then use the normal Gerbil clean/build entry. The project does not introduce
a competing lock registry or change the released SDK's locking implementation.
A file-existence lock still requires explicit orphan recovery after an external
hard kill; this is a toolchain lifecycle limitation, not a collection algorithm
or a paper/formal-model gap.

Local acceptance after this recovery: the unchanged `just test` entry passed all
148 modules / 1,715 cases in one process, with zero case/check errors and final
`HARNESS-OK` / `OK`. All compiler stages and the runtime stayed within their
existing bounds. The 21-case supervisor suite also passed its real timeout,
standard-clean and retry control. A second bounded Darwin reproducer invoked the
production Scheme cleanup on a retained zombie group, observed its terminal
record, then reaped the child and confirmed ESRCH. These are local functional
and lifecycle checks, not a cold-cache throughput or compiler-verification claim.
