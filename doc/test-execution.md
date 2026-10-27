# Standard build and test entrypoints

Use `gerbil build`, `gerbil clean` and `gerbil test`. Each `build.ss` declares its
inputs with `defbuild-script`; `std/make` owns dependency order, timestamps,
compilation and artifact reuse. There is no additional source scanner, hash
ledger, manifest parser, copied source view or test runner.

`just build` prepares the root library, the required benchmark programs and all
25 functional test packages. `GERBIL_BUILD_CORES` is the compiler's
standard backend budget. Package frontends share that budget through ordinary
`xargs`. On six or more cores, one backend slot is traded for a third frontend;
rounding down the per-frontend backend budget keeps the total process and heap
envelopes no larger than the preceding two-frontend profile. No project scheduler or load-path variable is
introduced. Compiler phases retain their 300-second deadline, 1 GiB frontend
heap and 2 GiB backend heap. Program builds retain their 90-second bound.
Aggregate package compilation has one owning timeout.
On compiler failure the small build boundary drains the compiler's public
`execute-pending-compile-jobs!` executor; it does not track or signal PIDs itself.

`just test` runs every compiled `*-test.ssi` under the standard test runner in
one process. Explicit compiled interfaces prevent the expander from retaining
all source ASTs before the first case. The deadline remains 300 seconds and the
heap remains 1 GiB. `just test-group signatures` instead uses official discovery
on `t/signatures`. `just test-file t/contracts/class-validation-test.ss` selects
a source file with the existing 90-second focused bound. Tests export suites
ending in `-test`, as required by the official runner.

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
