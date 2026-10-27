;;; Standard executable entry for iterator-performance-benchmark; the workload remains an importable module.
(export main)
(import (prefix-in (only-in :clan/poo/benchmarks/iterator-performance-benchmark main) entry.))
;; Bind the original procedure directly, preserving its row, results and errors.
(def main entry.main)
