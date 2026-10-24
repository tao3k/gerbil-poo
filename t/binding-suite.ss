;;; Native I/O composition over the shared strict paired-study interpreter.
(export main read-study)
(import (prefix-in "metadata-paired-suite.ss" paired.) "binding-cases.ss")
;; Run one complete descriptor while restoring the surrounding dynamic scope.
(def (main binary timeout output)
  (paired.with-study specification (lambda () (paired.main binary timeout output))))
;; Admit a complete receipt against the current source and executable identities.
(def (read-study path)
  (paired.with-study specification (lambda () (paired.read-study path))))
