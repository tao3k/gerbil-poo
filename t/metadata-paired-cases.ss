;;; One fixed native study definition, shared by child, driver and validator.
(export scenarios regimes strategies pairs rounds warmups repetitions sources side-order)
(def scenarios '(selector family joint workflow))
(def regimes '(natural collected))
(def strategies '(independent uncaptured dynamic cached))
(def pairs '((0 1) (1 2) (2 3)))
(def rounds 4)
(def warmups 4)
(def (repetitions scenario) (if (eq? scenario 'selector) 4096 128))
;; ABBA across four rounds; both sides are separate fresh processes.
(def (side-order round pair)
  (if (memv round '(0 3)) pair (reverse pair)))
(def sources '("contract-family.ss" "generic-family.ss" "staged-publication.ss" "cyclic-publication.ss"
  "declarative-metadata.ss" "dispatch-extension.ss" "multimethod.ss" "closure.ss"
  "dependency-analysis.ss" "generalized-graph.ss" "construction-cache.ss"
  "object.ss" "mop.ss" "type.ss" "number.ss" "build.ss" "justfile"
  "examples/shared-contracts.ss" "examples/service-metadata.ss" "examples/service-bundle.ss"
  "examples/construction-workflow.ss" "examples/protected-dispatch.ss" "examples/cyclic-access.ss"
  "t/closure-measure.ss" "t/closure-benchmark-support.ss" "t/metadata-paired-cases.ss"
  "t/metadata-paired-benchmark.ss" "t/metadata-paired-suite.ss"))
