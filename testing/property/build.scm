;;; Shared standard build declaration; never an installed runtime module.
;;; The kernel and property examples can exceed the same single-host bound.
;;; Standard make tracks this policy as an input; product optimization stays on.
;; Declare one bounded host graph through standard make, retaining every extra
;; input and invalidating compiled outputs when this shared policy changes.
(def (property-build-spec module inputs)
  [gxc: module [extra-inputs: (cons "testing/property/build.scm" inputs)]
    "-cc-options" "-D___SINGLE_HOST_LIMIT=4096"])

;; The kernel's included body remains an explicit standard make dependency.
(def property-kernel-build-spec
  (property-build-spec "examples/property-kernel" ["examples/property-kernel/cases.scm"]))
