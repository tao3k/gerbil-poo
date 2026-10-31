;;; Shared standard build declaration; never an installed runtime module.
;;; The measured kernel had 5,044 Gambit labels. Limit its single C host graph
;;; with Gambit's existing policy rather than disabling optimization or tests.
;;; Tracking this declaration as an input prevents stale compiler-option reuse.
(def property-kernel-build-spec
  '(gxc: "examples/property-kernel"
    (extra-inputs: ("testing/property/build.scm" "examples/property-kernel/cases.scm"))
    "-cc-options" "-D___SINGLE_HOST_LIMIT=4096"))
