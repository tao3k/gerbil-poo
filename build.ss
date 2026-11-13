#!/usr/bin/env -S gxi -:max-heap=2G,debug=q
;;; Standard package declaration; Gerbil owns inputs, dependencies and freshness.
(export main +gerbil-poo-build-spec+ production-spec)
(import :std/build-script (only-in :std/source this-source-file)
        (only-in :std/make include-gambit-sharp append-options)
        (only-in "t/build.ss" call-with-build-jobs))
;; Preserve the established compiler backend bound in the official entry.
(let (options (getenv "GAMBOPT" #f))
  (setenv "GAMBOPT" (string-append (if options (string-append options ",") "") "max-heap=2G,debug=q")))
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
    "closure"
    "cyclic-publication"
    "cli"
    "debug"
    ,+gerbil-poo-fq-spec+
    "recursive"
    "recursive-cache"
    "recursive-handling"
    "fun"
    ,(apply production-module "io" [] "" (include-gambit-sharp))
    "validation-rebinding"
    "value-diagnostics"
    "class-validation"
    "function-signature"
    "mop"
    "read-projection"
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
    "clos"
    "parameters"
    "types/syntax"
    "types/relation"
    "prototype-types"
    "method-combination"
    "multimethod"
    "dispatch-extension"
    "declarative-metadata"
    "types/validation"
    "variant-validation"
    "optional-validation"
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
    ,(apply production-module "slot-layout" [] "" (include-gambit-sharp))
    "read-route"
    "slot-observation"
    "object-state"
    "meta-prototype"
    "declaration"
    "recursive-declaration"
    "method-declaration"
    "generalized-declaration"
    "lens-laws"
    "generalized-closure"
    "focused-closure"
    "feedback-closure"
    "feedback-cache"
    "component-closure"
    "strong-components"
    "feedback-graph"
    "reflection"
    ,(production-module "object" ["object/observation.ss"])
    "polynomial"
    "proto"
    "rationaldict"
    ;; std/make tracks the standard include as an explicit compiler input.
    ;; Gambit's built-in host limit splits large generated C procedures instead
    ;; of making GCC optimize the entire collection module as one label graph.
    ;; Standard compiler inputs, object caching and all stage limits remain owned
    ;; by std/make; this is a code-generation choice, not a larger resource budget.
    ,(production-module "table"
      ["table/observation.scm" "table/io.scm" "table/fold.scm" "table/focus.scm"
       "table/mapping.scm" "table/styles.scm" "table/sets.scm" "table/indexes.scm" "table/order.scm"]
      +gerbil-poo-cc-options+)
    ,(production-module "trie" ["trie/changes.scm"])
    "type"
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
