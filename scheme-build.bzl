"""Consume this CI run's compiled project without recompiling on test runners."""

load("@gerbil_bazel//gerbil:project.bzl", "GerbilProjectInfo")

def _shared_library_impl(ctx):
    # CI checks the producer revision before analysis. All downloaded bytes are
    # declared inputs; Bazel still invalidates extraction when the artifact changes.
    if len(ctx.files.bundle) != 1:
        fail("shared_library requires this run's .ci-library/library.tar")
    root = ctx.actions.declare_directory("ci-library.project")
    ctx.actions.run(
        executable = "/usr/bin/tar",
        arguments = ["-xf", ctx.files.bundle[0].path, "-C", root.dirname],
        inputs = ctx.files.bundle,
        outputs = [root],
        mnemonic = "RestoreSchemeLibrary",
        progress_message = "Restoring this run's compiled Scheme library",
    )
    return [
        DefaultInfo(files = depset([root])),
        GerbilProjectInfo(
            project_root = root,
            receipt = ctx.file.receipt,
            log = ctx.file.log,
            source_root_marker = ctx.file.build_script,
            dependency_roots = depset(),
            source_resolution_receipts = depset(),
        ),
    ]

shared_library = rule(
    implementation = _shared_library_impl,
    attrs = {
        "bundle": attr.label_list(allow_files = [".tar"]),
        "receipt": attr.label(allow_single_file = True),
        "log": attr.label(allow_single_file = True),
        "build_script": attr.label(allow_single_file = True, mandatory = True),
    },
)
