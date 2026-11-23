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
(def sources '("recursive/evaluation.ss" "recursive/cache.ss" "fun.ss" "proto.ss" "mop/contract-family.ss" "mop/generic-family.ss" "graph/staged-publication.ss" "graph/cyclic-publication.ss"
  "mop/methods/combination.ss" "mop/methods/declaration.ss" "mop/generalized-declaration.ss" "mop/generalized-closure.ss" "mop/focused-closure.ss" "graph/feedback/closure.ss" "graph/feedback/cache.ss" "graph/feedback.ss" "graph/scc.ss" "benchmarks/workloads/component-services.ss" "graph/feedback/builder.ss" "benchmarks/workloads/service-revisions.ss" "benchmarks/workloads/component-membership.ss" "graph/component/revision.ss" "graph/component/publication.ss" "graph/component/joint.ss" "benchmarks/workloads/component-migration.ss" "benchmarks/workloads/component-rounds.ss" "benchmarks/workloads/component-requests.ss" "benchmarks/workloads/shared-approvals.ss" "benchmarks/workloads/joint-services.ss" "benchmarks/workloads/joint-topology.ss" "benchmarks/workloads/joint-receipts.ss" "benchmarks/workloads/joint-coordination.ss" "benchmarks/workloads/coordinator-rejoining.ss" "benchmarks/workloads/joint-coordination-rounds.ss" "benchmarks/workloads/joint-workers.ss" "benchmarks/workloads/joint-concurrency.ss" "mop/lens-laws.ss" "benchmarks/workloads/feedback-services.ss" "benchmarks/workloads/shared-feedback.ss" "benchmarks/workloads/cached-feedback.ss" "benchmarks/workloads/focused-services.ss" "benchmarks/workloads/closed-declarations.ss" "benchmarks/workloads/generalized-declarations.ss" "benchmarks/workloads/service-combination.ss" "benchmarks/workloads/declared-methods.ss" "mop/declarative-metadata.ss" "mop/methods/extension.ss" "mop/methods/dispatch.ss" "graph/closure.ss"
  "graph/computation.ss" "graph/schedule.ss" "graph/construction.ss"
  "object.ss" "object/representation.ss" "object/construction.ss" "object/slot-values.ss" "object/observation.ss" "object/slot-access.ss" "object/operations.ss" "object/syntax.ss" "object/mutation.ss" "object/slot-observation.ss" "object/state.ss" "object/reflection.ss" "mop/meta-prototype.ss" "object/declaration.ss" "recursive/declaration.ss" "mop.ss" "type.ss" "number.ss" "build.ss" "justfile"
  "benchmarks/workloads/shared-contracts.ss" "benchmarks/workloads/service-metadata.ss" "benchmarks/workloads/service-bundle.ss"
  "benchmarks/workloads/construction-workflow.ss" "benchmarks/workloads/protected-dispatch.ss" "benchmarks/workloads/cyclic-access.ss"
  "benchmarks/closure-measure.ss" "benchmarks/closure-benchmark-support.ss" "benchmarks/metadata-paired-cases.ss"
  "benchmarks/metadata-paired-benchmark.ss" "benchmarks/metadata-paired-suite.ss"))
