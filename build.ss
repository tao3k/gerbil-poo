#!/usr/bin/env -S gxi -:max-heap=2G,debug=q
;;; Standard package declaration; Gerbil owns inputs, dependencies and freshness.
(export main project-build-source)
(import :std/build-script (only-in :std/source this-source-file)
        (only-in :std/make include-gambit-sharp append-options)
        (only-in "t/build.ss" call-with-build-jobs))
;; Preserve the established compiler backend bound in the official entry.
(let (options (getenv "GAMBOPT" #f))
  (setenv "GAMBOPT" (string-append (if options (string-append options ",") "") "max-heap=2G,debug=q")))
;; Use the package root for benchmark build specs that include sibling modules.
(def project-build-file (this-source-file))
(defrules project-build-source () ((_ . _) project-build-file))
;; Declare one production C policy through standard make. Explicit inputs keep
;; compiler policy and each module's existing included sources in freshness checks.
(def (production-module name (inputs []) (cc-options "") . options)
  [gxc: name [extra-inputs: (cons "build.ss" inputs)]
    "-cc-options" (append-options "-O2" cc-options) options ...])

(def (production-spec spec)
  (if (string? spec) (production-module spec) spec))

;; Keep the established backend split bound for the table implementation.
(def +gerbil-poo-cc-options+ "-D___SINGLE_HOST_LIMIT=10000")

;; Declare the existing platform-specific linkage for dynamic math symbols.
(def +gerbil-poo-fq-spec+
  (cond-expand
   (darwin
    ;; Gambit loads this AOT module as a Mach-O bundle. Math symbols such as
    ;; pow are resolved from the host runtime when the bundle is loaded.
    (production-module "fq" [] "" "-ld-options" "-Wl,-undefined,dynamic_lookup"))
   (else "fq")))

(def +gerbil-poo-build-spec+
  `("brace"
    "support/base"
    "support/index"
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
    "graph/closure"
    "graph/cyclic-publication"
    "cli"
    "debug"
    ,+gerbil-poo-fq-spec+
    "recursive/evaluation"
    "recursive/cache"
    "recursive/handling"
    "fun"
    ,(apply production-module "io"
      ["io/bytes.ss" "io/representation.ss" "io/serialization.ss" "io/gambit-writer.ss"]
      "" (include-gambit-sharp))
    "types/validation-rebinding"
    "types/value-diagnostics"
    "types/class-validation"
    "types/function-signature"
    "mop/prototype"
    "object/read-projection"
    "clos/class-declaration-ir"
    "clos/classes"
    "clos/declaration-ir"
    "clos/declaration-ir-core"
    "clos/dispatch"
    "clos/evolution"
    "clos/funcs"
    "clos/generic-evolution"
    "clos/generic-syntax"
    "clos/instance-state"
    "clos/lambda-list"
    "clos/lifecycle"
    "clos/load-form"
    "clos/method-bundle-syntax"
    "clos/method-combination"
    "clos/method-combination-declaration-ir"
    "clos/model"
    "clos/mop"
    "clos/objects"
    "clos/reflection"
    "clos/syntax"
    "clos/types"
    "mop"
    "types/parameters"
    "types/syntax"
    "types/relation"
    "types/prototype-types"
    "mop/methods/combination"
    "mop/methods/dispatch"
    "mop/methods/extension"
    "mop/declarative-metadata"
    "types/validation"
    "types/variant-validation"
    "types/optional-validation"
    "types/object-contract"
    "recursive/validation"
    "recursive/topology"
    "recursive/staging"
    "recursive/publication"
    "recursive/approvals"
    "recursive/coordination"
    "mop/generic-family"
    "mop/contract-family"
    "graph/computation"
    "graph/schedule"
    "graph/component/revision"
    "graph/component/publication"
    "graph/component/joint"
    "mop/generalized-prototype"
    "graph/construction"
    "graph/staged-publication"
    ,(production-module "number" ["number/modular.ss" "number/exponentiation.ss"])
    "object/prototype-map"
    ,(apply production-module "object/slot-layout" [] "" (include-gambit-sharp))
    "object/read-route"
    "object/slot-observation"
    "object/state"
    "mop/meta-prototype"
    "object/declaration"
    "recursive/declaration"
    "mop/methods/declaration"
    "mop/generalized-declaration"
    "mop/lens-laws"
    "mop/generalized-closure"
    "mop/focused-closure"
    "graph/feedback/closure"
    "graph/feedback/cache"
    "graph/feedback/builder"
    "graph/scc"
    "graph/feedback"
    "object/reflection"
    ,(production-module "object" ["object/representation.ss" "object/construction.ss" "object/slot-values.ss" "object/observation.ss" "object/slot-access.ss" "object/operations.ss" "object/syntax.ss" "object/mutation.ss"])
    "polynomial"
    "proto"
    "table/rationaldict"
    ;; std/make tracks the standard include as an explicit compiler input.
    ;; Gambit's built-in host limit splits large generated C procedures instead
    ;; of making GCC optimize the entire collection module as one label graph.
    ;; Standard compiler inputs, object caching and all stage limits remain owned
    ;; by std/make; this is a code-generation choice, not a larger resource budget.
    ,(production-module "table"
      ["table/observation.ss" "table/io.ss" "table/validation.ss"
       "table/delta.ss" "table/fold.ss" "table/translation.ss"
       "table/protocol.ss" "table/focus.ss" "table/mapping.ss" "table/styles.ss" "table/sets.ss" "table/indexes.ss" "table/order.ss"]
      +gerbil-poo-cc-options+)
    ,(production-module "trie" ["trie/changes.ss" "trie/protocol.ss"])
    ,(production-module "type"
      ["types/sequences.ss" "types/scalar-codecs.ss" "types/combinations.ss"
       "types/pairs.ss" "types/optional.ss" "types/associative.ss" "types/sum.ss"])
    "testing/generation-graph"
    "testing/recursive-generation"
    "testing/property/generator"
    "testing/property"
    "testing/property/model"
    "testing/property/replay"
    "testing/property/test"
    "testing/type"
    "testing/function"))

(def build
  (let ()
    (defbuild-script (map production-spec +gerbil-poo-build-spec+))
    main))

(def (main . options)
  (when (or (null? options) (equal? (car options) "compile"))
    (displayln "BUILD-CONCURRENCY root-configured-cores=" (getenv "GERBIL_BUILD_CORES" "0")))
  (call-with-build-jobs (cut apply build options)))
