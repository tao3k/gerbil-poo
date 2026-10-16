;;; Source-bound focused-assembly driver; all process and I/O machinery is shared.
(export main read-study)
(import (prefix-in "metadata-paired-suite.ss" paired.) "focused-cases.ss")
;; Execute one complete fixed descriptor without leaking its dynamic configuration.
(def (main binary timeout output)
  (paired.with-study specification (lambda () (paired.main binary timeout output))))
;; Re-admit a full receipt against current native source and executable identities.
(def (read-study path)
  (paired.with-study specification (lambda () (paired.read-study path))))
