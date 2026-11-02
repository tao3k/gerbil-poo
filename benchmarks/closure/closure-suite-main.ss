;;; Standard executable entry for closure-suite; the workload remains an importable module.
(export main)
(import (prefix-in (only-in :clan/poo/benchmarks/closure-suite main) entry.))
;; Bind the original procedure directly, preserving its row, results and errors.
(def main entry.main)
