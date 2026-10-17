;;; Native source-bound I/O study; no Lean checkout or custom timing interpreter.
(export main read-study)
(import (prefix-in "metadata-paired-suite.ss" paired.) "factory-cases.ss")
;; Run one fixed complete study and restore the previous driver configuration.
(def (main binary timeout output)
  (paired.with-study specification (lambda () (paired.main binary timeout output))))
;; Re-admit a complete receipt against current source and executable identities.
(def (read-study path)
  (paired.with-study specification (lambda () (paired.read-study path))))
