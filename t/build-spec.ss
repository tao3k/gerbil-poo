;;; Shared build inventories and explicit project target selection.
(export build-request consumer-request build-consumer library-modules clean-request)

(import
  (only-in :std/make include-gambit-sharp pkg-config-libs)
  (only-in :std/build-script defbuild-script)
  (only-in :std/source this-source-file)
  (only-in :std/list/list take)
  (only-in "test-groups.ss" test-files test-batch))

;; Gambit's supported large-procedure limit applies to shared AND executable
;; compilation: consumers do not inherit a dependency's gsc options. Keep one
;; setting while std/make owns all dependency, cache and scheduling decisions.
(def +gerbil-poo-cc-options+ "-D___SINGLE_HOST_LIMIT=10000")

;; Declare the existing platform-specific linkage for dynamic math symbols.
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
    "types/syntax"
    "recursive-types"
    "types/relation"
    "prototype-types"
    "examples/polymorphic-services"
    "examples/numeric-services"
    "examples/row-services"
    "examples/contract-interop"
    "examples/service-collection"
    "method-combination"
    "multimethod"
    "dispatch-extension"
    "declarative-metadata"
    "types/validation"
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
    "read-route"
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
    ;; std/make tracks the standard include as an explicit compiler input.
    ;; Gambit's built-in host limit splits large generated C procedures instead
    ;; of making GCC optimize the entire collection module as one label graph.
    ;; Standard compiler inputs, object caching and all stage limits remain owned
    ;; by std/make; this is a code-generation choice, not a larger resource budget.
    (gxc: "table" (extra-inputs: ("table/fold.scm" "table/focus.scm" "table/mapping.scm" "table/styles.scm" "table/sets.scm" "table/indexes.scm" "table/order.scm"))
      "-cc-options" ,+gerbil-poo-cc-options+)
    (gxc: "trie" (extra-inputs: ("trie/changes.scm")))
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
    "t/factory-paired-benchmark"
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
    "t/build-spec"
    "t/build"
    "t/test-groups"
    "t/test-matrix"
    "t/test-runner"))

;; Shared runtime roots come from the authoritative package specification.
;; Examples and test tools retain their ordinary delayed loading; macro-only
;; roots are filtered by interface metadata in the test program's declaration.
(def (library-modules)
  (filter (lambda (file)
    (not (or (string-prefix? "examples/" file) (string-prefix? "t/" file))))
    (map (lambda (spec)
      (match spec
        ((? string?) spec)
        ([gxc: file . _] file)
        (else (error "unsupported library root" spec)))) +gerbil-poo-build-spec+)))

;; Reuse the existing runtime-root classification. Package installation owns
;; the reusable library; explicit qualification retains every former target.
(def (library-build-spec)
  (def roots (library-modules))
  (filter (lambda (spec)
            (member (match spec
                      ((? string?) spec)
                      ([gxc: file . _] file)) roots))
          +gerbil-poo-build-spec+))
;; Standard make must see included test cases just like the library's table includes.
;; Qualification already compiles every support module. The SSI-first test view
;; and standard loader reuse those outputs; declaring them again here recompiles
;; the entire benchmark graph into every group's distinct output directory.
;; Keep only this group's checked roots; extra-inputs owns included-case freshness.
(def (test-build-spec files)
  (map (lambda (file)
      (def root (path-strip-extension file))
      (if (equal? root "t/table-mapping-test")
        `(gxc: ,root (extra-inputs: ("t/table-mapping/composition.scm"))) root)) files))

;; Keep selection explicit. Standard compile/clean/spec/meta arguments pass
;; unchanged to defbuild-script; only project inventories are selected here.
(def (build-request args)
  (match args
    (["library" . options] [(library-build-spec) #f options])
    (["qualification" . options] [+gerbil-poo-build-spec+ #f options])
    (["tests" group output . options]
      [(test-build-spec (test-files group)) output options])
    (["batch" index . options]
      [(test-build-spec (test-batch (string->number index))) #f options])
    ;; gerbil build/clean select the package graph. The complete checked test
    ;; inventory remains explicit in tests/batch and the bounded full-test driver.
    (else [(library-build-spec) #f args])))


;; The linked test program and studies consume the same checked package interfaces.
;; Keep their standard source directory at t/ so make resolves shared imports
;; through GERBIL_PATH interfaces instead of expanding the entire source library.
(def (consumer-request args)
  (match args
    (["test-program" . options]
      [`((exe: "test-program" "-cc-options" ,+gerbil-poo-cc-options+
          "-ld-options" ,(pkg-config-libs "openssl"))) #f options])
    (["benchmark" target . options]
      (unless (member target '("closure-scale-benchmark" "closure-paired-benchmark"
                "closure-phases" "dispatch-benchmark" "metadata-benchmark"
                "metadata-paired-benchmark" "combination-benchmark"
                "factory-paired-benchmark" "collection-paired-benchmark" "object-scale-benchmark"))
        (error "unknown benchmark target" target))
      ;; Collections reuse test-program's already linked shared runtime. Standard
      ;; make compiles this workload once as a loadable module, without relinking
      ;; every shared C object. Other standalone studies retain their exe targets.
      [(if (equal? target "collection-paired-benchmark")
         '("collection-paired-benchmark")
         `((exe: ,target "-cc-options" ,+gerbil-poo-cc-options+
             "-ld-options" ,(pkg-config-libs "openssl"))))
       #f options])
    (else (error "consumer target required" args))))

;; Retain the selected standard target/output while replacing all compiler options
;; with clean. Reuse request parsing so debug/release flags never survive recovery.
(def (clean-request args)
  (def request (if (and (pair? args) (member (car args) '("benchmark" "test-program")))
    (consumer-request args) (build-request args)))
  (append (take args (- (length args) (length (caddr request)))) '("clean")))

;; defbuild-script owns freshness, dependencies, options and compiler scheduling.
;; This is the package's existing module prefix, with its standard t/ source root.
(def (build-consumer . args)
  (def request (consumer-request args))
  (defbuild-script (car request) prefix: "clan/poo/t")
  (apply main (caddr request)))
