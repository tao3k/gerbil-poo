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
300-second deadline, 1 GiB package frontend and 2 GiB backend/root heaps.
Program builds retain their 90-second bound. Aggregate package compilation has
one owning timeout.
On compiler failure the small build boundary drains the compiler's public
`execute-pending-compile-jobs!` executor; it does not track or signal PIDs itself.

`just test` runs every compiled `*-test.ssi` under the standard test runner in
one process. Explicit compiled interfaces prevent the expander from retaining
all source ASTs before the first case. `gerbil test t/*/*-test.ss` instead expands
all source bodies into one retained context and overflowed the same 1-GiB bound
before any case in the recorded negative control. Full compiled testing is one
process with every case, not a sequence of smaller source-test processes. The complete-suite deadline defaults to
600 seconds, including eager module imports; `just test 300` explicitly selects the shorter bound. The heap remains
1 GiB and group/focused bounds remain 300/90 seconds.
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
