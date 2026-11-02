;;; Standard executable entry for binding-suite; the workload remains an importable module.
(export main)
(import (prefix-in (only-in :clan/poo/benchmarks/binding-suite main) entry.))
;; Bind the original procedure directly, preserving its row, results and errors.
(def main entry.main)
