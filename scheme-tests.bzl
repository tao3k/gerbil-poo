"""Independent Scheme harness processes grouped by existing module responsibility."""

load("@gerbil_bazel//gerbil:defs.bzl", "gerbil_project_test")

def _entry_impl(ctx):
    # Use the standard harness and explicitly forward its status. Each process
    # imports only its selected test module; no all-suite importer runs first.
    entry = ctx.actions.declare_file(ctx.label.name + ".ss")
    ctx.actions.write(
        output = entry,
        content = """;;; Generated test entry; the standard harness owns checks and reporting.
(import (prefix-in :gerbil/tools/gxtest runner.))
;; Forward the standard harness status, including assertion/import failures.
(def (main) (exit (runner.main "-v" "5" {case})))
(main)
""".format(case = json.encode(ctx.file.case.short_path)),
    )
    return [DefaultInfo(files = depset([entry]))]

_entry = rule(
    implementation = _entry_impl,
    attrs = {"case": attr.label(allow_single_file = [".ss"], mandatory = True)},
)

def scheme_test_groups(groups, cases, project, srcs):
    """Require an exact partition, then expose each module and each functional group."""
    declared = ["t/" + case + "-test.ss" for members in groups.values() for case in members]
    if sorted(declared) != sorted(cases):
        fail("Scheme CI groups must cover every *-test.ss exactly once")
    for group, members in groups.items():
        targets = []
        for case in members:
            name = case + "_test"
            entry = name + "_entry"
            _entry(name = entry, case = "t/" + case + "-test.ss")
            gerbil_project_test(
                name = name,
                project = project,
                tests = [":" + entry],
                srcs = srcs,
                test_args = ["-v", "5"],
                size = "small",
                timeout = "short",
            )
            targets.append(":" + name)
        native.test_suite(name = group, tests = targets)
    native.test_suite(name = "test", tests = [":" + group for group in groups])
