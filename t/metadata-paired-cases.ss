;;; One fixed native study definition, shared by child, driver and validator.
(export scenarios regimes strategies pairs rounds warmups repetitions sources side-order)
;; Focus on the unresolved Simula workflow: cold child/generic construction,
;; discarded admission probes, first cache transfer and complete joint revision.
;; A fixed one-operation allocation control admits bytes ONLY without collection.
(def scenarios '(simula-configure simula-generics simula-probe simula-transfer simula-cold
                 simula-bind simula-warm simula-stage simula-revision simula-repeated simula-allocation))
;; Natural preserves the child's heap history; collected explicitly collects
;; after the identical warmup prefix. Neither promises identical live heaps.
(def regimes '(natural collected))
;; Fixed same-prefix sides distinguish compilation from explicit nested cache
;; transport and callback compilation. Duplicate sides provide A/A controls.
(def strategies '(reference context-prepared prepared-transport prepared-control
  staged-simula staged-simula-aa compiled-context context-prepared-aa shape-prepared-aa candidate-transport))
;; Direct new/previous, fresh/captured baseline, both A/A controls and preparation
;; control. Pure compiled/staged isolates lifecycle composition. All sides
;; initialize/warm the same complete set before measurement.
(def pairs '((1 4) (2 4) (6 4) (4 5) (1 7) (2 3)))
;; Four independent process pairs per comparison support the ABBA order control.
(def rounds 4)
;; Execute every control this many times before measuring one side, keeping
;; the observable setup prefix independent of which side is selected.
(def warmups 4)
;; Fixed counts separate warm-call micro-costs from bounded complete publications.
;; Configuration includes protected construction; no adaptive best-of timing.
(def (repetitions scenario)
  (case scenario ((simula-warm simula-probe simula-transfer) 1024)
    ((simula-allocation) 1) ((simula-configure) 128) (else 64)))
;; ABBA across four rounds; both sides are separate fresh processes.
;; Balance first/second position over four rounds as ABBA. Adjacent sides always
;; run in separate fresh processes; arbitrary temporal drift is not eliminated.
(def (side-order round pair)
  (if (memv round '(0 3)) pair (reverse pair)))
;; Bind all runtime/example/driver inputs used by this study. Changes make old
;; receipts historical; source identity is checked before and after the complete run.
(def sources '("contract-family.ss" "generic-family.ss" "staged-publication.ss" "cyclic-publication.ss"
  "method-combination.ss" "examples/service-combination.ss" "declarative-metadata.ss" "dispatch-extension.ss" "multimethod.ss" "closure.ss"
  "dependency-analysis.ss" "generalized-graph.ss" "construction-cache.ss"
  "object.ss" "mop.ss" "type.ss" "number.ss" "build.ss" "justfile"
  "examples/shared-contracts.ss" "examples/service-metadata.ss" "examples/service-bundle.ss"
  "examples/construction-workflow.ss" "examples/protected-dispatch.ss" "examples/cyclic-access.ss"
  "t/closure-measure.ss" "t/closure-benchmark-support.ss" "t/metadata-paired-cases.ss"
  "t/metadata-paired-benchmark.ss" "t/metadata-paired-suite.ss"))
