;;; One fixed native study definition, shared by child, driver and validator.
(export scenarios regimes strategies pairs rounds warmups repetitions sources side-order)
;; Separate selector overhead from real family construction, joint publication
;; and the existing 15-node shared-dependency workflow.
(def scenarios '(selector family joint workflow))
;; Natural preserves the child's heap history; collected explicitly collects
;; after the identical warmup prefix. Neither promises identical live heaps.
(def regimes '(natural collected))
;; Fixed side numbering shared by child, driver and validator. Uncaptured is a
;; benchmark-only previous callback; cached is the optional SelectionCache variant.
(def strategies '(independent uncaptured dynamic cached))
;; Adjacent controls isolate preparation choice, function capture and choice reuse.
;; Each pair is measured directly; marginal medians are not a transitive cost proof.
(def pairs '((0 1) (1 2) (2 3)))
;; Four independent process pairs per comparison support the ABBA order control.
(def rounds 4)
;; Execute every control this many times before measuring one side, keeping
;; the observable setup prefix independent of which side is selected.
(def warmups 4)
;; Return fixed operation counts: enough selector calls for micro-cost visibility,
;; fewer full publications for bounded native children. Not adaptive best-of timing.
(def (repetitions scenario) (if (eq? scenario 'selector) 4096 128))
;; ABBA across four rounds; both sides are separate fresh processes.
;; Balance first/second position over four rounds as ABBA. Adjacent sides always
;; run in separate fresh processes; arbitrary temporal drift is not eliminated.
(def (side-order round pair)
  (if (memv round '(0 3)) pair (reverse pair)))
;; Bind all runtime/example/driver inputs used by this study. Changes make old
;; receipts historical; source identity is checked before and after the complete run.
(def sources '("contract-family.ss" "generic-family.ss" "staged-publication.ss" "cyclic-publication.ss"
  "declarative-metadata.ss" "dispatch-extension.ss" "multimethod.ss" "closure.ss"
  "dependency-analysis.ss" "generalized-graph.ss" "construction-cache.ss"
  "object.ss" "mop.ss" "type.ss" "number.ss" "build.ss" "justfile"
  "examples/shared-contracts.ss" "examples/service-metadata.ss" "examples/service-bundle.ss"
  "examples/construction-workflow.ss" "examples/protected-dispatch.ss" "examples/cyclic-access.ss"
  "t/closure-measure.ss" "t/closure-benchmark-support.ss" "t/metadata-paired-cases.ss"
  "t/metadata-paired-benchmark.ss" "t/metadata-paired-suite.ss"))
