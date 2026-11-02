#!/usr/bin/env -S gxi -:max-heap=2G,debug=q
;;; Source-only build support; never a POO runtime library dependency.
;;; Retain compiler resource cleanup through its public API; no second scheduler.
(export call-with-build-jobs test-build-spec test-build-partitions build-test-partition)
(import :std/build-script (only-in :std/source this-source-file)
        (only-in :std/list/list append-map)
        (only-in :gerbil/compiler execute-pending-compile-jobs!))
;; Standard make owns normal completion. On refusal, join its existing jobs and
;; retain the original exception, including a distinct cleanup refusal.
(def (call-with-build-jobs thunk)
  (try (thunk)
    (catch (cause)
      (with-catch (lambda (cleanup)
        (unless (eq? cause cleanup) (error "compiler failure and job drain failure" cause cleanup)))
        execute-pending-compile-jobs!)
      (raise cause))))

;; The C harness uses the standard debugging optimization level; library and
;; benchmark optimization levels are unchanged. Gambit expansion and
;; the shared host-size protection stay enabled for every test root.
(def +test-cc-options+ "-Og -D___SINGLE_HOST_LIMIT=4096")

;; Adjacent fixture-free suites share runtime images and retain private helper
;; scopes and export order. Modules with setup/cleanup remain separate.
;; One authoritative standard make declaration serves the complete graph and
;; existing isolated CI packages. These are declarations, not discovered inputs.
;; Fixture-free suites share runtime sections; Gambit's standard multiple-host
;; fallback bounds C optimizer work without changing production module policy.
(def +test-packages+
  '(
    ("backends"
    "fq-test"
    "library-reuse-test"
    (gxc: "number-test" (extra-inputs: ("number/cases.scm" "number/polynomial.scm")))
    "rationaldict-test"
    "trie-test")
    ("closure"
    (gxc: "closure-test" (extra-inputs: ("closure/closure-alignment.scm" "closure/cases.scm" "closure/component-closure.scm"))))
    ("collection-deltas"
    (gxc: "table-batch-test" (extra-inputs: ("table-batch/capture.scm"
      "table-batch/origins.scm" "table-batch/transport.scm"))))
    ("collection-order"
    "rationaldict-order-test"
    "table-cursor-test"
    (gxc: "table-order-test" (extra-inputs: ("table-order/observations.scm")))
    "table-split-test")
    ("collection-styles"
    (gxc: "set-algebra-test" (extra-inputs: ("set-algebra/cases.scm" "set-algebra/set-observation.scm")))
    (gxc: "table-style-test" (extra-inputs: ("table-style/set-style.scm" "table-style/table-receiver.scm" "table-style/cases.scm"))))
    ("collection-updates"
    "table-fold-test"
    "table-index/revisions"
    (gxc: "table-index-test" (extra-inputs: ("table-index/table-group-join.scm" "table-index/table-index-equivalence.scm" "table-index/cases.scm")))
    (gxc: "table-mapping-test" (extra-inputs: ("table-mapping/composition.scm" "table-mapping/retraction.scm")))
    "table-merge-test")
    ("collections"
    (gxc: "table-construction-test" (extra-inputs: ("table-construction/cases.scm" "table-construction/table-focus.scm" "table-construction/table-io.scm" "table-construction/table-normalization.scm")))
    (gxc: "table-validation-test" (extra-inputs: ("table-validation/table-selection.scm" "table-validation/cases.scm")))
    "table-wrapper-test")
    ("components"
    (gxc: "component-membership-test" (extra-inputs: ("component-membership/cases.scm" "component-membership/component-migration.scm" "component-membership/component-requests.scm" "component-membership/component-rounds.scm"))))
    ("construction"
    (gxc: "construction-cache-test" (extra-inputs: ("construction-cache/cases.scm" "construction-cache/construction-workflow.scm" "construction-cache/focused-closure.scm"))))
    ("contracts"
    (gxc: "object-contract-test" (extra-inputs: ("object-contract/class-validation.scm" "object-contract/computed-validation.scm" "object-contract/container-validation.scm" "object-contract/contract-checks.scm" "object-contract/contract-family.scm" "object-contract/contract-publication.scm" "object-contract/evidence-binding.scm" "object-contract/object-contract-flow.scm" "object-contract/cases.scm")))
    (gxc: "object-contract-validation-test" (extra-inputs: ("object-contract-validation/cases.scm" "object-contract-validation/optional-validation.scm" "object-contract-validation/protected-dispatch.scm")))
    (gxc: "recursive-approvals-test" (extra-inputs: ("recursive-approvals/cases.scm" "recursive-approvals/recursive-competition.scm" "recursive-approvals/recursive-coordination.scm" "recursive-approvals/recursive-migration.scm" "recursive-approvals/recursive-publication.scm" "recursive-approvals/recursive-recovery.scm" "recursive-approvals/recursive-restaging.scm" "recursive-approvals/recursive-revision.scm")))
    (gxc: "recursive-validation-test" (extra-inputs: ("recursive-validation/recursive-staging.scm" "recursive-validation/recursive-submissions.scm" "recursive-validation/recursive-topology.scm" "recursive-validation/cases.scm")))
    (gxc: "service-bundle-test" (extra-inputs: ("service-bundle/cases.scm" "service-bundle/service-metadata.scm" "service-bundle/service-revisions.scm" "service-bundle/shared-approvals.scm")))
    "variant-validation-test")
    ("coordination"
    (gxc: "joint-coordination-test" (extra-inputs: ("joint-coordination/coordinator-recovery.scm" "joint-coordination/coordinator-rejoining.scm" "joint-coordination/joint-concurrency.scm" "joint-coordination/cases.scm"))))
    ("declarations"
    (gxc: "generalized-declaration-test" (extra-inputs: ("generalized-declaration/catalog-inference.scm" "generalized-declaration/declarative-metadata.scm" "generalized-declaration/cases.scm" "generalized-declaration/meta-prototype.scm" "generalized-declaration/recursive-declaration.scm"))))
    ("feedback"
    (gxc: "feedback-closure-test" (extra-inputs: ("feedback-closure/cyclic-access.scm" "feedback-closure/feedback-cache.scm" "feedback-closure/cases.scm")))
    "feedback-graph-test"
    "feedback-revision-test")
    ("generalized"
    (gxc: "generalized-prototype-test" (extra-inputs: ("generalized-prototype/binding-benchmark.scm" "generalized-prototype/factory-benchmark.scm" "generalized-prototype/focused-benchmark.scm" "generalized-prototype/generalized-benchmark.scm" "generalized-prototype/generalized-closure.scm" "generalized-prototype/cases.scm"))))
    ("inference"
    (gxc: "candidate-inference-test" (extra-inputs: ("candidate-inference/cases.scm" "candidate-inference/container-inference.scm")))
    (gxc: "descriptor-inference/intrinsic" (extra-inputs: ("descriptor-inference/cases.scm")))
    (gxc: "descriptor-inference-test" (extra-inputs: ( "descriptor-inference/empty-inference.scm" "descriptor-inference/optional-inference.scm" "descriptor-inference/record-inference.scm"))))
    ("methods"
    "inferred-declaration-test"
    (gxc: "method-declaration-test" (extra-inputs: ("method-declaration/method-combination.scm" "method-declaration/cases.scm" "method-declaration/multimethod.scm" "method-declaration/typed-method-declaration.scm"))))
    ("objects"
    "inheritance-hooks-test"
    "issued-read-test"
    (gxc: "object-test" (extra-inputs: ("object/lifecycle.scm" "object/mop.scm" "object/cases.scm" "object/parameters.scm" "object/slot-observation.scm" "object/support.scm"))))
    ("publication"
    (gxc: "joint-publication-test" (extra-inputs: ("joint-publication/approval-revision.scm" "joint-publication/joint-admission.scm" "joint-publication/joint-installation.scm" "joint-publication/cases.scm" "joint-publication/joint-receipts.scm"))))
    ("recovery"
    "coordinator-interleaving-test")
    ("recursion"
    (gxc: "recursive-test" (extra-inputs: ("recursive/recursive-benchmark.scm" "recursive/cases.scm"))))
    ("representations"
    "collection-testing-test"
    "declaration-index-test"
    "function-signature-test"
    "property-testing/preparation"
    (gxc: "property-testing-test" (extra-inputs: ("property-testing/samplers.scm")))
    "prototype-types-test"
    "recursive-generation-test"
    (gxc: "representation-test" (extra-inputs: ("representation/growth.scm" "representation/admission.scm")))
    "row-types-test"
    (gxc: "type-test" (extra-inputs: ("type/tuple-json-performance.scm" "type/tuple-unmarshal-performance.scm" "type/type-performance.scm" "type/cases.scm"))))
    ("revisions"
    "joint-generations-test"
    "joint-restaging-test"
    (gxc: "joint-rounds-test" (extra-inputs: ("joint-rounds/cases.scm" "joint-rounds/joint-topology.scm"))))
    ("scalars"
    (gxc: "scalar-inference/union" (extra-inputs: ("scalar-inference/union-inference.scm")))
    (gxc: "scalar-inference-test" (extra-inputs: ("scalar-inference/range-inference.scm" "scalar-inference/cases.scm"))))
    ("signatures"
    (gxc: "function-coverage-test" (extra-inputs: ("function-coverage/cases.scm" "function-coverage/function-options.scm" "function-coverage/keyword-coverage.scm" "function-coverage/keyword-prefix.scm" "function-coverage/keyword-rest.scm" "function-coverage/keyword-values.scm"))))
    ("tools"
    "cli-test"
    "io-test"
    "fun-test"
    "debug-test"
    "metadata-paired-test"
    "metadata-report-test")
  ))

;; Relocate the closed declaration forms into the parent package, preserving
;; included-source dependencies. Refuse unsupported forms rather than lose inputs.
(def (prefix-test-spec group spec)
  ;; Keep every source and extra input under the same existing package directory.
  (def (path file) (string-append group "/" file))
  (match spec
    ((? string?) (path spec))
    ([gxc: file [extra-inputs: inputs] . options]
     [gxc: (path file) [extra-inputs: (map path inputs)] options ...])
    (else (error "unsupported test build declaration" group spec))))

;; The existing bounded C-host policy applies to every root, not just suites
;; grouped through includes. This file owns both compiler flags and freshness.
;; Attach the shared compiler input, then flatten declarations in package order
;; when requested. Unknown packages never mean an empty or partial build.
(def (test-build-spec (group #f))
  ;; The shared policy is a real standard-make input, including compiler flags.
  ;; Imported build-script code alone is not a freshness dependency of a leaf.
  (def (with-policy spec)
    (match spec
      ((? string?) [gxc: spec [extra-inputs: ["../build.ss"]]
        "-cc-options" +test-cc-options+])
      ([gxc: file [extra-inputs: inputs] . options]
       [gxc: file [extra-inputs: (cons "../build.ss" inputs)]
        "-cc-options" +test-cc-options+ options ...])
      (else (error "unsupported test build declaration" group spec))))
  (if group
    (cond
      ((assoc group +test-packages+) => (lambda (entry) (map with-policy (cdr entry))))
      (else (error "unknown test package" group)))
    (append-map (lambda (entry)
                  (map (cut prefix-test-spec (car entry) <>) (test-build-spec (car entry))))
      +test-packages+)))

;; These compiler-only partitions reuse the original package declarations. They
;; change session lifetime, never the installed test namespaces or test inventory.
;; Signature contracts share the method/contract context instead of extending
;; the already larger inference graph; standard make still owns all four jobs.
(def (test-build-partitions)
  '(("collections" "backends" "collection-deltas" "collection-styles" "collections"
      "coordination" "recovery" "revisions" "publication" "tools")
    ("prototypes" "collection-order" "collection-updates" "closure" "construction" "objects" "generalized"
      "components" "feedback" "recursion")
    ("contracts" "contracts" "methods" "signatures")
    ("types" "declarations" "inference" "representations" "scalars")))

;; Public standard build scripts own parsing, freshness, parallel backend jobs
;; and cleanup. Bound each source-context lifetime by a declared functional part;
;; the explicit prefix is the existing installed test prefix, not a new namespace.
(def (build-test-partition part options)
  (def groups
    (cond
      ((assoc part (test-build-partitions)) => cdr)
      (else (error "unknown test build partition" part))))
  (def spec
    (append-map (lambda (group)
                  (map (cut prefix-test-spec group <>) (test-build-spec group)))
      groups))
  (let (settings (getenv "GAMBOPT" #f))
    (setenv "GAMBOPT" (string-append (if settings (string-append settings ",") "")
      "max-heap=2G,debug=q")))
  (call-with-build-jobs
    (lambda ()
      (defbuild-script spec prefix: "clan/poo/t")
      (apply main options))))
