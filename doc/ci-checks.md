# Independent Scheme checks

CI downloads the already compiled Linux Gerbil release from gerbil-bazel, checks
its pinned SHA-256, and uses the release's activation entry point. The downloaded
archive is cached; its bytes are verified again before every extraction. The
project uses `build.ss` and `just` directly.

The build job compiles into the isolated `GERBIL_PATH=.ci-library`. A
short-lived Actions artifact transfers that output to each test group. Before
testing, each runner checks the recorded producer revision against its actual
checkout. Compiler version, platform and source revision agree within this run;
this does not qualify cross-version or cross-platform binary reuse.

The library cache requires an exact key: compiler release checksum, host C/linker
identity, platform, Scheme source and build/configuration inputs. There is no
prefix fallback. Standalone test bodies are not compilation inputs and remain
freshly executed. A hit reuses identical compiled source, checks the stored source
key, and retains the original producer revision separately from this run's checked
revision. A source or build-input change recompiles. This avoids pretending that
std/make's timestamp-based checks can safely accept a different source snapshot.
All inventory, harness, semantic and error-path tests run on every CI attempt.

`t/test-groups.ss` owns the functional groups as Scheme data and emits only the
ephemeral matrix required by Actions. Missing classified tests and duplicate
registrations fail preparation. Every new `*-test.ss` module is also included,
in an additional group until classified. No generated matrix is committed.

The existing seventeen groups run independently; within each group, standard
`xargs -P 2` starts a separate `just test-file` process for every module. Each
keeps its 90-second deadline, standard harness, error-marker checks and exit
status. A failure does not cancel sibling groups, and xargs still attempts
the other modules before returning failure. Test jobs never invoke `build.ss`.

The downloaded `.ci-library/` directory is ignored. Generated artifacts, compiler
archives and full logs remain outside Git. Local development uses the same
`just build`, `just test`, and `just test-file` commands with its installed Gerbil.
