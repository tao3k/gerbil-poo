;;; Standard executable entry for metadata-paired-suite; the workload remains an importable module.
(export main)
(import (prefix-in (only-in :clan/poo/benchmarks/metadata-paired-suite main) entry.))
;; Bind the original procedure directly, preserving its row, results and errors.
(def main entry.main)
