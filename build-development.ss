#!/usr/bin/env -S gxi -:max-heap=2G,debug=q
;;; Explicit development build for examples, benchmarks and shared test fixtures.
(export main)
(import :std/build-script (only-in :std/source this-source-file)
        (only-in "build.ss" +gerbil-poo-build-spec+ production-spec)
        (only-in "t/build.ss" call-with-build-jobs test-build-spec prefix-test-spec)
        (only-in :std/list/list filter)
        (prefix-in "examples/build.ss" entry-build.))
(include "testing/property/build.scm")

(def +gerbil-poo-development-spec+
  `("examples/polymorphic-services"
    "examples/numeric-services"
    "examples/row-services"
    "examples/contract-interop"
    "examples/service-collection"
    "examples/recursive-catalog"
    "examples/generalized-checkout"
    "examples/object-contracts"
    "examples/contract-publication"
    "examples/function-publication"
    "examples/container-publication"
    "examples/variant-publication"
    "examples/optional-publication"
    "examples/class-publication"
    "examples/computed-publication"
    "examples/recursive-validation"
    "examples/recursive-revision"
    "examples/recursive-migration"
    "examples/recursive-topology"
    "examples/recursive-staging"
    "examples/recursive-restaging"
    "examples/recursive-publication"
    "examples/recursive-approvals"
    "examples/recursive-competition"
    "examples/recursive-submissions"
    "examples/recursive-recovery"
    "examples/recursive-coordination"
    "examples/byte-io"
    "examples/lifecycle"
    "examples/parameter-service"
    "examples/representation-service"
    "examples/signature-service"
    "examples/collection-testing"
    "examples/collection-properties"
    ,@property-example-build-specs
    ,property-kernel-build-spec
    "examples/property-workflows"
    "examples/property-refusals"
    ;; Bound the independent registration groups in separate C host functions.
    (gxc: "examples/generated-batches"
      (extra-inputs: ("build.ss" "build-development.ss"))
      "-cc-options" "-O2 -D___SINGLE_HOST_LIMIT=4096")
    "examples/generated-traces"
    (gxc: "examples/generated-products"
      (extra-inputs: ("build.ss" "build-development.ss"))
      "-cc-options" "-O2 -D___SINGLE_HOST_LIMIT=4096")
    "examples/recursive-trees"
    "examples/inherited-services"
    "examples/metaprotocol-services"
    "examples/recursive-metaprotocol"
    "examples/declared-methods"
    "examples/generalized-declarations"
    "examples/closed-declarations"
    "examples/focused-services"
    "examples/feedback-services"
    "examples/shared-feedback"
    "examples/cached-feedback"
    "examples/component-services"
    "examples/service-revisions"
    "examples/component-membership"
    "examples/component-migration"
    "examples/component-rounds"
    "examples/component-requests"
    "examples/shared-approvals"
    "examples/joint-services"
    "examples/joint-topology"
    "examples/joint-receipts"
    "examples/joint-coordination"
    "examples/coordinator-rejoining"
    "examples/joint-coordination-rounds"
    "examples/joint-workers"
    "examples/joint-concurrency"
    "examples/cyclic-access"
    "examples/protected-dispatch"
    "examples/service-metadata"
    "examples/service-bundle"
    "examples/construction-workflow"
    "examples/shared-contracts"
    "examples/service-combination"
    (gxc: "t/joint-coordination-cases")
    (gxc: "t/table-testing")
    "benchmarks/binding-benchmark"
    "benchmarks/binding-cases"
    "benchmarks/binding-suite"
    "benchmarks/class-proto-benchmark"
    "benchmarks/closure-benchmark-support"
    "benchmarks/closure-cases"
    "benchmarks/closure-measure"
    "benchmarks/read-field-test"
    "benchmarks/read-replay-test"
    "benchmarks/cold-handoff-test"
    "benchmarks/dense-repair-test"
    "benchmarks/ordered-scc-study"
    "benchmarks/closure-paired-benchmark"
    "benchmarks/closure-paired-suite"
    "benchmarks/closure-parity"
    "benchmarks/closure-phases"
    "benchmarks/closure-report"
    "benchmarks/closure-scale-benchmark"
    "benchmarks/closure-suite"
    "benchmarks/prototype-map-benchmark"
    "benchmarks/collection-paired-benchmark"
    "benchmarks/generation-benchmark"
    "benchmarks/combination-benchmark"
    "benchmarks/combination-cases"
    "benchmarks/combination-suite"
    "benchmarks/count-performance-benchmark"
    "benchmarks/dispatch-benchmark"
    "benchmarks/dispatch-report"
    "benchmarks/enum-performance-benchmark"
    "benchmarks/factory-benchmark"
    "benchmarks/factory-cases"
    "benchmarks/factory-paired-benchmark"
    "benchmarks/factory-suite"
    "benchmarks/focused-benchmark"
    "benchmarks/focused-cases"
    "benchmarks/focused-suite"
    "benchmarks/generalized-benchmark"
    "benchmarks/generalized-cases"
    "benchmarks/generalized-observation-reference"
    "benchmarks/generalized-suite"
    "benchmarks/iterator-performance-benchmark"
    "benchmarks/metadata-benchmark"
    "benchmarks/metadata-paired-benchmark"
    "benchmarks/metadata-paired-cases"
    "benchmarks/metadata-paired-suite"
    "benchmarks/metadata-report"
    "benchmarks/object-performance-benchmark"
    "benchmarks/object-scale-benchmark"
    "benchmarks/rationaldict-performance-benchmark"
    "benchmarks/recursive-benchmark"
    "benchmarks/recursive-cases"
    "benchmarks/recursive-suite"
    "benchmarks/representation-startup"
))

(def build
  (let ()
    (def modules
      (map production-spec (append +gerbil-poo-build-spec+ +gerbil-poo-development-spec+)))
    ;; On Darwin the program shares the static objects of the library graph.
    (defbuild-script
      (cond-expand
        (darwin (append modules
                   (entry-build.representation-build-spec "examples/representation-main")))
        (else modules)))
    main))

;; Project the same native declarations without unrelated executable studies.
(def graph-build
  (let ()
    (def libraries
      (filter (lambda (entry)
                (and (string? entry)
                  (member entry '("examples/closed-declarations"
                                  "examples/component-services"
                                  "examples/service-revisions"
                                  "examples/component-membership"
                                  "examples/component-migration"
                                  "examples/component-rounds"
                                  "examples/component-requests"
                                  "benchmarks/closure-measure"
                                  "benchmarks/dense-repair-test"
                                  "benchmarks/ordered-scc-study"
                                  "examples/object-contracts"
                                  "examples/contract-publication"
                                  "examples/recursive-validation"
                                  "examples/recursive-revision"
                                  "examples/recursive-migration"
                                  "examples/recursive-topology"
                                  "examples/recursive-staging"
                                  "examples/recursive-restaging"
                                  "examples/recursive-publication"
                                  "examples/recursive-approvals"
                                  "examples/recursive-competition"
                                  "examples/recursive-submissions"
                                  "examples/recursive-recovery"
                                  "examples/recursive-coordination"))))
        +gerbil-poo-development-spec+))
    (unless (= (length libraries) 24) (error "missing Graph study library declaration"))
    (def (tests group names)
      (def selected (filter (lambda (entry) (member (cadr entry) names))
                       (test-build-spec group)))
      (unless (= (length selected) (length names))
        (error "missing Graph study test declaration" group names))
      (map (cut prefix-test-spec (string-append "t/" group) <>) selected))
    (defbuild-script
      (append (map production-spec (append +gerbil-poo-build-spec+ libraries))
        (tests "feedback" '("graph-algorithms-test" "feedback-graph-test"))
        (tests "components" '("component-membership-test"))
        (tests "construction" '("graph-order-repair-test"))
        (tests "contracts" '("recursive-validation-test" "recursive-approvals-test"))))
    main))

(def (main . options)
  (call-with-build-jobs
    (lambda ()
      (match options
        (["graph" . rest] (apply graph-build rest))
        (else (apply build options))))))
