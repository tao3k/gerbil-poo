;;; Preparation and invocation use the same binary and fixed control prefix.
(export specification scenarios repetitions)
(import ../object (prefix-in "metadata-paired-cases.ss" base.))
;; Keep construction and reused calls distinct; both include a result oracle.
(def scenarios '(prepare-inner call-inner prepare-simula call-simula))
;; Fixed counts, chosen before measurement; no adaptive best-of selection.
(def (repetitions scenario) (if (memq scenario '(prepare-inner prepare-simula)) 1024 16384))
;; Balance adjacent fresh process sides; duplicate controls expose residual noise.
(def (side-order round pair) (if (memv round '(0 3)) pair (reverse pair)))
;; Reuse the existing strict bounded runner, source admission and signed GC metrics.
(def specification (.cc (.o) kind: 'combination-paired label: "COMBINATION-PAIRED-OK"
  scenarios: scenarios regimes: '(natural collected)
  strategies: '(composed fold composed-aa fold-aa) pairs: '((1 0) (0 2) (1 3))
  rounds: 4 warmups: 4 repetitions: repetitions side-order: side-order
  sources: (append base.sources '("t/combination-cases.ss" "t/combination-benchmark.ss" "t/combination-suite.ss"))))
