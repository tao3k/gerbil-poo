;;; Shared standard build declaration; never an installed runtime module.
;;; The kernel and property examples can exceed the same single-host bound.
;;; Standard make tracks this policy. Only test-registration examples use it;
;;; generic library modules and performance workloads keep production flags.
;; Declare one bounded host graph through standard make, retaining every extra
;; input and invalidating compiled outputs when this shared policy changes.
(def (property-build-spec module inputs)
  [gxc: module [extra-inputs: (cons "testing/property/build.scm" inputs)]
    "-cc-options" "-Og -D___SINGLE_HOST_LIMIT=4096"])

;; The kernel's included body remains an explicit standard make dependency.
(def property-kernel-build-spec
  (property-build-spec "examples/property-kernel" ["examples/property-kernel/cases.scm"]))

;; All seven modules export test-case registration procedures. Share their exact
;; compiler declarations between the root project and isolated library consumer.
(def property-example-build-specs
  (map (lambda (module) (property-build-spec module '()))
    '("examples/property-products" "examples/property-numbers"
      "examples/property-filters" "examples/property-scopes" "examples/property-replay"
      "examples/property-sizes" "examples/property-traces")))
