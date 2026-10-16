;;; One fixed native study definition, shared by child, driver and validator.
(export scenarios regimes strategies pairs rounds warmups repetitions sources side-order)
;; Focus this study on preparation, cold checked entry, warm checked invocation,
;; joint revision with one call, and joint revision with eight calls. Historical
;; selector studies retain their own source identities; timings are not additive.
(def scenarios '(forwarding-configure forwarding-cold forwarding-warm forwarding-revision forwarding-repeated
                 simula-configure simula-cold simula-warm simula-revision simula-repeated))
;; Natural preserves the child's heap history; collected explicitly collects
;; after the identical warmup prefix. Neither promises identical live heaps.
(def regimes '(natural collected))
;; Fixed same-prefix sides distinguish compilation from explicit nested cache
;; transport. Duplicate sides provide two A/A controls; every child builds all ten.
(def strategies '(reference reference-control compiled-discard compiled-discard-control
  prepared-transport prepared-transport-control prepared-transport-aa prepared-transport-aa-control
  candidate-transport candidate-transport-control))
;; Direct pairs isolate compilation-only, transport after compilation, their
;; combined workflow, and transport with/without compilation; retain two A/A pairs.
;; Each pair is measured directly; marginal medians are not a transitive cost proof.
(def pairs '((0 1) (0 2) (2 4) (0 4) (4 6) (4 8)))
;; Four independent process pairs per comparison support the ABBA order control.
(def rounds 4)
;; Execute every control this many times before measuring one side, keeping
;; the observable setup prefix independent of which side is selected.
(def warmups 4)
;; Fixed counts separate warm-call micro-costs from bounded complete publications.
;; Configuration includes protected construction; no adaptive best-of timing.
(def (repetitions scenario)
  (case scenario ((forwarding-warm simula-warm) 1024)
    ((forwarding-configure simula-configure) 128) (else 64)))
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
