#!/usr/bin/env -S gxi -:max-heap=2G,debug=q
;;; Source-only build support; never a POO runtime library dependency.
;;; Retain compiler resource cleanup through its public API; no second scheduler.
(export call-with-build-jobs test-build-spec test-build-partitions build-test-partition prefix-test-spec)
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

;; The C harness defaults to the debugging optimization level. Timed frozen
;; Graph kernels explicitly match production -O2; library policy is unchanged.
;; Gambit expansion and host-size protection remain enabled for every root.
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
    (gxc: "number-test" (extra-inputs: ("number/cases.ss" "number/polynomial.ss")))
    "rationaldict-test"
    "trie-test")
    ("closure"
    (gxc: "closure-test" (extra-inputs: ("closure/closure-alignment.ss" "closure/cases.ss" "closure/component-closure.ss"))))
    ("collection-deltas"
    (gxc: "table-batch-test" (extra-inputs: ("table-batch/capture.ss"
      "table-batch/origins.ss" "table-batch/transport.ss"))))
    ("collection-order"
    "rationaldict-order-test"
    "table-cursor-test"
    (gxc: "table-order-test" (extra-inputs: ("table-order/observations.ss")))
    "table-split-test")
    ("collection-styles"
    (gxc: "set-algebra-test" (extra-inputs: ("set-algebra/cases.ss" "set-algebra/set-observation.ss")))
    (gxc: "table-style-test" (extra-inputs: ("table-style/set-style.ss" "table-style/table-receiver.ss" "table-style/cases.ss")))
    "uint-trie-set-admission-test")
    ("collection-updates"
    "table-fold-test"
    "table-index/revisions"
    (gxc: "table-index-test" (extra-inputs: ("table-index/table-group-join.ss" "table-index/table-index-equivalence.ss" "table-index/cases.ss")))
    (gxc: "table-mapping-test" (extra-inputs: ("table-mapping/composition.ss" "table-mapping/retraction.ss")))
    "table-merge-test")
    ("collections"
    (gxc: "table-construction-test" (extra-inputs: ("table-construction/cases.ss" "table-construction/table-focus.ss" "table-construction/table-io.ss" "table-construction/table-normalization.ss")))
    (gxc: "table-validation-test" (extra-inputs: ("table-validation/table-selection.ss" "table-validation/cases.ss")))
    "table-wrapper-test")
    ("components"
    (gxc: "component-membership-test" (extra-inputs: ("component-membership/cases.ss" "component-membership/component-migration.ss" "component-membership/component-requests.ss" "component-membership/component-rounds.ss"))))
    ("construction"
    ;; The owned inverse study imports this kernel through the standard root.
    (gxc: "graph-order-repair-test" (extra-inputs: ())
      "-cc-options" "-O2 -D___SINGLE_HOST_LIMIT=4096")
    (gxc: "construction-cache-test" (extra-inputs: ("construction-cache/cases.ss" "construction-cache/construction-workflow.ss" "construction-cache/focused-closure.ss"))))
    ("contracts"
    (gxc: "object-contract-test" (extra-inputs: ("object-contract/class-validation.ss" "object-contract/computed-validation.ss" "object-contract/container-validation.ss" "object-contract/contract-checks.ss" "object-contract/contract-family.ss" "object-contract/contract-publication.ss" "object-contract/evidence-binding.ss" "object-contract/object-contract-flow.ss" "object-contract/cases.ss")))
    (gxc: "object-contract-validation-test" (extra-inputs: ("object-contract-validation/cases.ss" "object-contract-validation/optional-validation.ss" "object-contract-validation/protected-dispatch.ss")))
    (gxc: "recursive-approvals-test" (extra-inputs: ("recursive-approvals/cases.ss" "recursive-approvals/recursive-competition.ss" "recursive-approvals/recursive-coordination.ss" "recursive-approvals/recursive-migration.ss" "recursive-approvals/recursive-publication.ss" "recursive-approvals/recursive-recovery.ss" "recursive-approvals/recursive-restaging.ss" "recursive-approvals/recursive-revision.ss")))
    (gxc: "recursive-validation-test" (extra-inputs: ("recursive-validation/recursive-staging.ss" "recursive-validation/recursive-submissions.ss" "recursive-validation/recursive-topology.ss" "recursive-validation/cases.ss")))
    (gxc: "service-bundle-test" (extra-inputs: ("service-bundle/cases.ss" "service-bundle/service-metadata.ss" "service-bundle/service-revisions.ss" "service-bundle/shared-approvals.ss")))
    "variant-validation-test")
    ("coordination"
    (gxc: "joint-coordination-test" (extra-inputs: ("joint-coordination/coordinator-recovery.ss" "joint-coordination/coordinator-rejoining.ss" "joint-coordination/joint-concurrency.ss" "joint-coordination/cases.ss"))))
    ("declarations"
    (gxc: "generalized-declaration-test" (extra-inputs: ("generalized-declaration/catalog-inference.ss" "generalized-declaration/declarative-metadata.ss" "generalized-declaration/cases.ss" "generalized-declaration/meta-prototype.ss" "generalized-declaration/recursive-declaration.ss"))))
    ("feedback"
    (gxc: "graph-algorithms-test" (extra-inputs: ("graph-algorithms/baseline.ss"
      "graph-algorithms/discovery-study.ss"
      "graph-algorithms/compact.ss"))
      ;; This root contains frozen kernels used for timed production comparisons.
      "-cc-options" "-O2 -D___SINGLE_HOST_LIMIT=4096")
    (gxc: "feedback-closure-test" (extra-inputs: ("feedback-closure/cyclic-access.ss" "feedback-closure/feedback-cache.ss" "feedback-closure/cases.ss")))
    "feedback-graph-test"
    "feedback-revision-test")
    ("generalized"
    (gxc: "generalized-prototype-test" (extra-inputs: ("generalized-prototype/binding-benchmark.ss" "generalized-prototype/factory-benchmark.ss" "generalized-prototype/focused-benchmark.ss" "generalized-prototype/generalized-benchmark.ss" "generalized-prototype/generalized-closure.ss" "generalized-prototype/cases.ss"))))
    ("inference"
    (gxc: "candidate-inference-test" (extra-inputs: ("candidate-inference/cases.ss" "candidate-inference/container-inference.ss")))
    (gxc: "descriptor-inference/intrinsic" (extra-inputs: ("descriptor-inference/cases.ss")))
    (gxc: "descriptor-inference-test" (extra-inputs: ( "descriptor-inference/empty-inference.ss" "descriptor-inference/optional-inference.ss" "descriptor-inference/record-inference.ss"))))
    ("methods"
    "clause-ledger"
    "duim-pane"
    "duim-pane-test"
    "clos-clause-ledger-test"
    "clos-dispatch-test"
    "clos-evolution-test"
    "clos-funcs-test"
    "clos-generic-evolution-test"
    "clos-lifecycle-test"
    "clos-load-form-test"
    "clos-method-bundle-test"
    "clos-method-combination-test"
    "clos-model-test"
    "clos-syntax-test"
    "generic-dispatch-test"
    "inferred-declaration-test"
    (gxc: "method-declaration-test" (extra-inputs: ("method-declaration/method-combination.ss" "method-declaration/cases.ss" "method-declaration/multimethod.ss" "method-declaration/typed-method-declaration.ss"))))
    ("objects"
    "shape-admission-test"
    "class-diagnostics-test"
    "inheritance-hooks-test"
    "issued-read-test"
    (gxc: "object-test" (extra-inputs: ("object/lifecycle.ss" "object/mop.ss" "object/cases.ss" "object/parameters.ss" "object/slot-observation.ss" "object/support.ss"))))
    ("property"
    "generated-traces-test"
    "property-workflows-test"
    "public-api-test")

    ("publication"
    (gxc: "joint-publication-test" (extra-inputs: ("joint-publication/approval-revision.ss" "joint-publication/joint-admission.ss" "joint-publication/joint-installation.ss" "joint-publication/cases.ss" "joint-publication/joint-receipts.ss"))))
    ("recovery"
    "coordinator-interleaving-test")
    ("recursion"
    (gxc: "recursive-test" (extra-inputs: ("recursive/recursive-benchmark.ss" "recursive/cases.ss"))))
    ("representations"
    "collection-testing-test"
    "declaration-index-test"
    "function-signature-test"
    "property-testing/preparation"
    (gxc: "property-testing-test" (extra-inputs: ("property-testing/samplers.ss")))
    "prototype-types-test"
    "recursive-generation-test"
    (gxc: "representation-test" (extra-inputs: ("representation/growth.ss" "representation/admission.ss" "representation/seed.ss")))
    "row-types-test"
    (gxc: "type-test" (extra-inputs: ("type/tuple-json-performance.ss" "type/tuple-unmarshal-performance.ss" "type/type-performance.ss" "type/cases.ss"))))
    ("revisions"
    "joint-generations-test"
    "joint-restaging-test"
    (gxc: "joint-rounds-test" (extra-inputs: ("joint-rounds/cases.ss" "joint-rounds/joint-topology.ss"))))
    ("scalars"
    (gxc: "scalar-inference/union" (extra-inputs: ("scalar-inference/union-inference.ss")))
    (gxc: "scalar-inference-test" (extra-inputs: ("scalar-inference/range-inference.ss" "scalar-inference/cases.ss"))))
    ("signatures"
    (gxc: "function-coverage-test" (extra-inputs: ("function-coverage/cases.ss" "function-coverage/function-options.ss" "function-coverage/keyword-coverage.ss" "function-coverage/keyword-prefix.ss" "function-coverage/keyword-rest.ss" "function-coverage/keyword-values.ss"))))
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
       ;; A timed owner may declare its standard compiler policy explicitly.
       ;; Retain exactly one -cc-options pair, rather than append conflicting
       ;; debug/production optimization flags and depend on argument order.
       (let (configured (if (member "-cc-options" options) options
                         (cons "-cc-options" (cons +test-cc-options+ options))))
         [gxc: file [extra-inputs: (cons "../build.ss" inputs)] configured ...]))
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
    ("contracts" "contracts" "methods" "signatures" "property")
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
