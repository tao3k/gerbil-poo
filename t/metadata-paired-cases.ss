;;; One fixed native study definition, shared by child, driver and validator.
(export scenarios regimes strategies pairs rounds warmups repetitions sources side-order)
;; Focus on the unresolved Simula workflow: cold child/generic construction,
;; discarded admission probes, first cache transfer and complete joint revision.
;; A fixed one-operation allocation control admits bytes ONLY without collection.
(def scenarios '(simula-bind-allocation simula-next-generics-allocation simula-generics-allocation simula-contracts-allocation simula-handoff simula-revision simula-burst simula-post-warm
  simula-next simula-unchanged simula-allocation simula-next-allocation simula-post-allocation))
;; Identical full setup/warmup in natural and explicitly collected processes.
(def regimes '(natural collected))
;; Compare the preceding bound owner with standard empty storage, the original
;; staged owner and pure compiled context. Exact duplicates supply A/A controls.
(def strategies '(staged empty-storage bound bound-aa staged-aa empty-storage-aa
  compiled-context prepared-transport shape-prepared candidate-transport))
;; Every comparison is direct in the same binary; no transitive timing inference.
(def pairs '((2 1) (0 1) (6 1) (1 5) (2 3) (0 4)))
;; Four independent process pairs per comparison support the ABBA order control.
(def rounds 4)
;; Execute every control this many times before measuring one side, keeping
;; the observable setup prefix independent of which side is selected.
(def warmups 4)
;; Fixed counts separate warm-call micro-costs from bounded complete publications.
;; Configuration includes protected construction; no adaptive best-of timing.
(def (repetitions scenario)
  (case scenario ((simula-burst) 16) ((simula-post-warm simula-post-probe) 1024)
    ((simula-allocation simula-next-allocation simula-post-allocation simula-generics-allocation simula-next-generics-allocation simula-bind-allocation simula-contracts-allocation) 1) (else 64)))
;; ABBA across four rounds; both sides are separate fresh processes.
;; Balance first/second position over four rounds as ABBA. Adjacent sides always
;; run in separate fresh processes; arbitrary temporal drift is not eliminated.
(def (side-order round pair)
  (if (memv round '(0 3)) pair (reverse pair)))
;; Bind all runtime/example/driver inputs used by this study. Changes make old
;; receipts historical; source identity is checked before and after the complete run.
(def sources '("recursive.ss" "recursive-cache.ss" "fun.ss" "proto.ss" "contract-family.ss" "generic-family.ss" "staged-publication.ss" "cyclic-publication.ss"
  "method-combination.ss" "method-declaration.ss" "generalized-declaration.ss" "generalized-closure.ss" "focused-closure.ss" "feedback-closure.ss" "feedback-revision.ss" "feedback-cache.ss" "lens-laws.ss" "examples/feedback-services.ss" "examples/shared-feedback.ss" "examples/cached-feedback.ss" "examples/focused-services.ss" "examples/closed-declarations.ss" "examples/generalized-declarations.ss" "examples/service-combination.ss" "examples/declared-methods.ss" "declarative-metadata.ss" "dispatch-extension.ss" "multimethod.ss" "closure.ss"
  "dependency-analysis.ss" "generalized-graph.ss" "construction-cache.ss"
  "object.ss" "object-state.ss" "inheritance-hooks.ss" "reflection.ss" "meta-prototype.ss" "declaration.ss" "recursive-declaration.ss" "mop.ss" "type.ss" "number.ss" "build.ss" "justfile"
  "examples/shared-contracts.ss" "examples/service-metadata.ss" "examples/service-bundle.ss"
  "examples/construction-workflow.ss" "examples/protected-dispatch.ss" "examples/cyclic-access.ss"
  "t/closure-measure.ss" "t/closure-benchmark-support.ss" "t/metadata-paired-cases.ss"
  "t/metadata-paired-benchmark.ss" "t/metadata-paired-suite.ss"))
