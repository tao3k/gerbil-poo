# Standard build and test entrypoints

Use `gerbil build`, `gerbil clean` and `gerbil test`. Each `build.ss` declares its
inputs with `defbuild-script`; `std/make` owns dependency order, timestamps,
compilation and artifact reuse. There is no additional source scanner, hash
ledger, manifest parser, copied source view or test runner.

`just build` prepares the root library, the required benchmark programs and all
declared functional test packages. `GERBIL_BUILD_CORES` is the standard backend
budget and defaults to the machine's physical core count. Just's standard parallel dependency queue
shares the existing process/heap envelope between package frontends and backend
workers; `BUILD-CONCURRENCY` reports the effective allocation. No additional
scheduler or load-path variable is introduced. Compiler phases retain their
300-second deadline and 2 GiB package frontend/backend/root heaps.
Program builds retain their 90-second bound. Aggregate package compilation has
one owning timeout.
On compiler failure the small build boundary drains the compiler's public
`execute-pending-compile-jobs!` executor; it does not track or signal PIDs itself.

`just test` runs every compiled `*-test.ssi` through four concurrent official
`gerbil test` invocations. These reuse the existing compiler partitions, rather
than launching 25 separate module-loading contexts. `GERBIL_BUILD_CORES` is also
the local test-worker budget, capped by the four existing partitions (8 GiB of
aggregate Scheme heap ceilings). A zero budget retains one worker. Just owns
the dependency queue; the released runner itself has no parallel-thread option.
No TestCase, TestSuite or fixture procedure is replaced. The declaration check
compares the Just partitions with the authoritative Scheme declarations.

`just check` is the complete cold-build and parallel-test entry. It retains every
suite, declaration regression, isolated-library acceptance and both paired
studies. The whole parallel test phase has one 600-second watchdog, including
queued work, imports and execution; `just test 300` selects the shorter bound.
Group/focused bounds remain 300/90 seconds. All official test invocations now
use 2 GiB, explicitly requested on 2026-11-01. This changes the memory budget;
it is not presented as an optimization under the historical 1-GiB constraint.

`just test-single-process` and `just check-single-process` retain full shared-state
admission. CI still requires the complete single-process `just check-built`, in
addition to every independent functional-group job. Parallel throughput therefore
does not replace the cross-module shared-state check. The ordered full-entry
observer explicitly selects `check-single-process`/`check-built`; it cannot
interpret interleaved parallel output as one ordered harness or one VM counter.

Explicit compiled interfaces prevent re-expanding all source ASTs. The historical
`gerbil test t/*/*-test.ss` negative control overflowed its 1-GiB heap before any
case; it is not a measurement of the compiled 2-GiB path. No source fallback is
introduced. Serial and parallel execution share the same result boundary, and
each owning deadline covers its entire process group without nested watchdogs.
After `just build-group signatures`, `just test-group signatures` passes the
compiled interfaces in `$GERBIL_PATH/lib/clan/poo/t/signatures` to the official
runner. CI consumes its downloaded artifacts without expanding source bodies. `just test-file t/contracts/object-contract-test.ss` selects
a source file with the existing 90-second focused bound. Tests export suites
ending in `-test`, as required by the official runner.

`just check-layout` owns static packaging assertions: public testing-module paths,
retired paths, and the executable bounded core build entry. Both local builds and
cached CI acceptance require it. Recipe-string matching and generic Scheme
value/exception forwarding self-tests have been removed from `t/tools/build-test`;
they did not exercise POO behavior or pending compiler cleanup. No replacement
Scheme orchestration suite is introduced.

`t/tools` retains POO CLI, debug and metadata-admission behavior tests. Object
lifecycle assertions live in `t/objects/object/lifecycle.scm`, unchanged in scope.
The failure-drain helper `t/build.ss` is source-only build support and is no
longer compiled as a runtime library. Actual startup execution, every POO
behavior suite and both paired studies remain required.

The thin recipe retains verbose module/case/harness progress, the runner's exit
status and its success markers. An empty run without a case is refused. It does
not rewrite TestCase/TestSuite procedures, reimplement fixtures, evaluate export
bindings or launch generated `gxi -e` expressions.

`just check` adds the complete paired collection study after all suites.
`just check-built` is the same acceptance against artifacts already built by CI.
Standalone studies are ordinary packages built only when requested. They use
`exe:` declarations and tiny main modules that bind the workload's exported procedure. Libraries remain importable `gxc:`
modules; workload implementations are shared rather than copied into a custom
consumer. All generated outputs remain under the official `GERBIL_PATH`.

After a failed or inconsistent build use `gerbil clean` followed by
`gerbil build` in the affected package (or `just clean`, then `just build`).
Do not install source fallbacks or manufacture successful cache receipts.
