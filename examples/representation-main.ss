;;; Standard executable entry; the workflow itself remains an importable module.
(export main)
(import (prefix-in (only-in ./representation-service main) service.))
;; Preserve the exact module procedure instead of adding a second command parser.
(def main service.main)
