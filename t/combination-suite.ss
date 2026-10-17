;;; The existing paired runner owns bounds, complete coverage and source identity.
(export main)
(import (prefix-in "metadata-paired-suite.ss" paired.) "combination-cases.ss")
;; Every raw observation remains in the caller's local output, never a git asset.
(def (main binary timeout output)
  (paired.with-study specification (lambda () (paired.main binary timeout output))))
