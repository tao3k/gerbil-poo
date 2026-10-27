;;; Standard executable entry for object-scale-benchmark; the workload remains an importable module.
(export main)
(import (prefix-in (only-in :clan/poo/benchmarks/object-scale-benchmark main) entry.))
;; Bind the original procedure directly, preserving its row, results and errors.
(def main entry.main)
