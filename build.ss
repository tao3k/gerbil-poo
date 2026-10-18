#!/usr/bin/env gxi
;;; -*- Gerbil -*-
;;; Gerbil v0.19 package build for Gerbil POO.

(import
  (only-in :std/build-script defbuild-script)
  (only-in :std/make include-gambit-sharp)
  (only-in :gerbil/runtime/system gerbil-path)
  (only-in "t/test-groups.ss" test-files))

;; Keep the package build graph explicit. V19 std/make owns dependency
;; scheduling and native compilation; this file only declares package inputs.
(def +gerbil-poo-fq-spec+
  (cond-expand
   (darwin
    ;; Gambit loads this AOT module as a Mach-O bundle. Math symbols such as
    ;; pow are resolved from the host runtime when the bundle is loaded.
    '(gxc: "fq" "-ld-options" "-Wl,-undefined,dynamic_lookup"))
   (else "fq")))

(def +gerbil-poo-build-spec+
  `("brace"
    "support/base"
    "support/debug"
    "support/io"
    "support/json"
    "support/list"
    "support/option"
    "support/rationaldict"
    "support/repr"
    "support/syntax"
    "support/object-syntax"
    "support/testing"
    "closure"
    "cyclic-publication"
    "cli"
    "debug"
    ,+gerbil-poo-fq-spec+
    "recursive"
    "recursive-cache"
    "recursive-handling"
    "fun"
    (gxc: "io" ,@(include-gambit-sharp))
    "validation-rebinding"
    "value-diagnostics"
    "class-validation"
    "function-signature"
    "mop"
    "parameters"
    "type-syntax"
    "recursive-types"
    "type-relation"
    "prototype-types"
    "examples/polymorphic-services"
    "examples/row-services"
    "examples/contract-interop"
    "examples/service-collection"
    "method-combination"
    "multimethod"
    "dispatch-extension"
    "declarative-metadata"
    "type-validation"
    "variant-validation"
    "optional-validation"
    "object-diagnostics"
    "object-contract-validation"
    "object-contract"
    "recursive-validation"
    "recursive-topology"
    "recursive-staging"
    "recursive-publication"
    "recursive-approvals"
    "recursive-coordination"
    "generic-family"
    "contract-family"
    "dependency-analysis"
    "generalized-graph"
    "component-revision"
    "component-publication"
    "joint-publication"
    "generalized-prototype"
    "construction-cache"
    "staged-publication"
    "number"
    "prototype-map"
    "slot-layout"
    "slot-observation"
    "object-state"
    "inheritance-hooks"
    "meta-prototype"
    "declaration"
    "recursive-declaration"
    "method-declaration"
    "generalized-declaration"
    "lens-laws"
    "generalized-closure"
    "focused-closure"
    "feedback-closure"
    "feedback-revision"
    "feedback-cache"
    "component-closure"
    "strong-components"
    "feedback-graph"
    "reflection"
    "object"
    "polynomial"
    "proto"
    "rationaldict"
    "table"
    "trie"
    "type"
    "generation-graph"
    "recursive-generation"
    "property-testing"
    "function-testing"
    "examples/recursive-catalog"
    "examples/generalized-checkout"
    "object-contract-flow"
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
    "examples/lifecycle"
    "examples/parameter-service"
    "examples/representation-service"
    "examples/signature-service"
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
    "t/closure-measure"
    "t/metadata-paired-cases"
    "t/joint-coordination-cases"
    "t/metadata-paired-benchmark"
    "t/recursive-cases"
    "t/generalized-cases"
    "t/focused-cases"
    "t/combination-cases"
    "t/combination-benchmark"
    "t/combination-suite"
    "t/binding-cases"
    "t/factory-cases"
    "t/generalized-observation-reference"
    "t/closure-cases"
    "t/closure-benchmark-support"
    "t/closure-scale-benchmark"
    "t/table-testing"
    "t/recursive-benchmark"
    "t/metadata-benchmark"
    "t/metadata-report"
    "t/metadata-paired-suite"
    "t/generalized-benchmark"
    "t/focused-benchmark"
    "t/factory-benchmark"
    "t/binding-benchmark"
    "t/build-artifacts"
    "t/test-groups"
    "t/test-runner"))

;; The default local build retains the complete inventory. CI builds the shared
;; graph once, then each functional group compiles only its disjoint test roots.
;; std/make still owns import dependencies and compiler jobs within each process.
(def scope (getenv "GERBIL_BUILD_SCOPE" "all"))
(unless (member scope '("all" "library" "tests" "combination")) (error "unknown build scope" scope))
(def selected-tests
  (cond ((member scope '("library" "combination")) [])
    ((equal? scope "tests")
      (test-files (or (getenv "GERBIL_BUILD_TEST_GROUP" #f) (error "test group required"))))
    (else (test-files))))
;; std/make also owns executable dependency scheduling and its bounded compiler
;; pool. The benchmark scope reuses compiled modules instead of a serial gxc link
;; path; all functional test scopes and their complete inventories stay unchanged.
(defbuild-script
  (if (equal? scope "combination")
    `((exe: "t/combination-benchmark"
        "-ld-options" ,(getenv "GERBIL_CLOSURE_LD_OPTIONS"
          (cond-expand (darwin "-L/opt/homebrew/opt/openssl@3/lib") (else "")))))
    (append (if (equal? scope "tests") [] +gerbil-poo-build-spec+)
      (map path-strip-extension selected-tests)))
  bindir: (path-expand ".build/combination")
  libdir: (or (getenv "GERBIL_BUILD_LIBDIR" #f) (path-expand "lib" (gerbil-path))))
