;;; Preparation and invocation use the same binary and fixed control prefix.
(export specification scenarios repetitions)
(import :clan/poo/object
        (runtime: :clan/poo/benchmarks/metadata-paired-cases)
        (prefix-in (only-in "metadata-paired-cases.ss" sources) base.))
;; Keep construction and reused calls distinct; both include a result oracle.
(def scenarios '(registration-admission registration-construction registration-family registration-complete
  prepare-inner call-inner prepare-simula call-simula generic-allocation generic-hot generic-workflow generic-construction generic-factory-allocation generic-construction-allocation generic-transport generic-hot-conditioned generic-workflow-conditioned generic-construction-conditioned generic-factory generic-account generic-workflow-allocation))
;; Fixed counts, chosen before measurement; no adaptive best-of selection.
(def (repetitions scenario)
  (case scenario
    ((registration-family registration-complete) 64)
    ((registration-construction) 1024)
    ((generic-allocation generic-factory-allocation generic-construction-allocation generic-workflow-allocation) 1) ((generic-hot generic-hot-conditioned generic-transport) 131072)
    ((generic-workflow generic-construction generic-workflow-conditioned generic-construction-conditioned) 1024) ((generic-account prepare-inner prepare-simula) 1024) (else 16384)))
;; Balance adjacent fresh process sides; duplicate controls expose residual noise.
(def (side-order round pair) (if (memv round '(0 3)) pair (reverse pair)))
;; Reuse the existing strict bounded runner, source admission and signed GC metrics.
(def specification (.cc (.o) kind: 'combination-paired label: "COMBINATION-PAIRED-OK"
  scenarios: scenarios regimes: '(natural collected)
  strategies: '(control production control-aa production-aa) pairs: '((1 0) (0 2) (1 3))
  rounds: 4 warmups: 4 repetitions: repetitions side-order: side-order
  sources: (append base.sources '("benchmarks/combination-cases.ss" "benchmarks/combination-benchmark.ss" "benchmarks/combination-suite.ss" "support/syntax.ss"))))
