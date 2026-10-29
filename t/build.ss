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

;; One authoritative standard make declaration serves the complete graph and
;; existing isolated CI packages. These are declarations, not discovered inputs.
(def +test-packages+
  '(
    ("backends" "fq-test"
    "library-reuse-test"
    "number-test"
    "polynomial-test"
    "rationaldict-test"
    "trie-test")
    ("closure" "closure-alignment-test"
    "closure-test"
    "component-closure-test")
    ("collection-deltas" "table-batch-test"
    "table-capture-test"
    "table-origins-test"
    "table-transport-test")
    ("collection-order" "rationaldict-order-test"
    "table-cursor-test"
    (gxc: "table-order-test" (extra-inputs: ("table-order/observations.scm")))
    "table-split-test")
    ("collection-styles" "set-algebra-test"
    "set-observation-test"
    "set-style-test"
    "table-receiver-test"
    "table-style-test")
    ("collection-updates" "table-fold-test"
    "table-group-join-test"
    "table-index-equivalence-test"
    "table-index-test"
    (gxc: "table-mapping-test" (extra-inputs: ("table-mapping/composition.scm" "table-mapping/retraction.scm")))
    "table-merge-test")
    ("collections" "table-construction-test"
    "table-focus-test"
    "table-io-test"
    "table-normalization-test"
    "table-selection-test"
    "table-validation-test"
    "table-wrapper-test")
    ("components" "component-membership-test"
    "component-migration-test"
    "component-requests-test"
    "component-rounds-test")
    ("construction" "construction-cache-test"
    "construction-workflow-test"
    "focused-closure-test")
    ("contracts" "class-validation-test"
    "computed-validation-test"
    "container-validation-test"
    "contract-checks-test"
    "contract-family-test"
    "contract-publication-test"
    "evidence-binding-test"
    "object-contract-flow-test"
    "object-contract-test"
    "object-contract-validation-test"
    "optional-validation-test"
    "protected-dispatch-test"
    "recursive-approvals-test"
    "recursive-competition-test"
    "recursive-coordination-test"
    "recursive-migration-test"
    "recursive-publication-test"
    "recursive-recovery-test"
    "recursive-restaging-test"
    "recursive-revision-test"
    "recursive-staging-test"
    "recursive-submissions-test"
    "recursive-topology-test"
    "recursive-validation-test"
    "service-bundle-test"
    "service-metadata-test"
    "service-revisions-test"
    "shared-approvals-test"
    "variant-validation-test")
    ("coordination" "coordinator-recovery-test"
    "coordinator-rejoining-test"
    "joint-concurrency-test"
    "joint-coordination-test")
    ("declarations" "catalog-inference-test"
    "declarative-metadata-test"
    "generalized-declaration-test"
    "meta-prototype-test"
    "recursive-declaration-test")
    ("feedback" "cyclic-access-test"
    "feedback-cache-test"
    "feedback-closure-test"
    "feedback-graph-test"
    "feedback-revision-test")
    ("generalized" "binding-benchmark-test"
    "factory-benchmark-test"
    "focused-benchmark-test"
    "generalized-benchmark-test"
    "generalized-closure-test"
    "generalized-prototype-test")
    ("inference" "candidate-inference-test"
    "container-inference-test"
    "descriptor-inference-test"
    "empty-inference-test"
    "optional-inference-test"
    "record-inference-test")
    ("methods" "inferred-declaration-test"
    "method-combination-test"
    "method-declaration-test"
    "multimethod-test"
    "typed-method-declaration-test")
    ("objects" "inheritance-hooks-test"
    "issued-read-test"
    "lifecycle-test"
    "mop-test"
    "object-test"
    "parameters-test"
    "slot-observation-test"
    "support-test")
    ("publication" "approval-revision-test"
    "joint-admission-test"
    "joint-installation-test"
    "joint-publication-test"
    "joint-receipts-test")
    ("recovery" "coordinator-interleaving-test"
    "coordinator-prepared-test"
    "coordinator-retry-test")
    ("recursion" "recursive-benchmark-test"
    "recursive-test")
    ("representations" "collection-testing-test"
    "declaration-index-test"
    "function-signature-test"
    "property-testing-test"
    "prototype-types-test"
    "recursive-generation-test"
    "representation-test"
    "row-types-test"
    "tuple-json-performance-test"
    "tuple-unmarshal-performance-test"
    "type-performance-test"
    "type-test")
    ("revisions" "joint-generations-test"
    "joint-restaging-test"
    "joint-rounds-test"
    "joint-topology-test")
    ("scalars" "range-inference-test"
    "scalar-inference-test"
    "union-inference-test")
    ("signatures" "function-coverage-test"
    "function-options-test"
    "keyword-coverage-test"
    "keyword-prefix-test"
    "keyword-rest-test"
    "keyword-values-test")
    ("tools" "cli-test"
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
    ([gxc: file [extra-inputs: inputs]]
     [gxc: (path file) [extra-inputs: (map path inputs)]])
    (else (error "unsupported test build declaration" group spec))))

;; Select the existing package verbatim, or flatten every package in declaration
;; order for a single standard make/import cache. Unknown packages never mean empty.
(def (test-build-spec (group #f))
  (if group
    (cond
      ((assoc group +test-packages+) => cdr)
      (else (error "unknown test package" group)))
    (append-map (lambda (entry)
                  (map (cut prefix-test-spec (car entry) <>) (cdr entry)))
      +test-packages+)))

;; These compiler-only partitions reuse the original package declarations. They
;; change session lifetime, never the installed test namespaces or test inventory.
(def (test-build-partitions)
  '(("collections" "backends" "collection-deltas" "collection-styles" "collections")
    ("indexes" "collection-order" "collection-updates")
    ("prototypes" "closure" "construction" "objects" "generalized"
      "components" "feedback" "recursion")
    ("contracts" "contracts" "methods")
    ("types" "declarations" "inference" "representations" "scalars" "signatures")
    ("publication" "coordination" "recovery" "revisions" "publication" "tools")))

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
