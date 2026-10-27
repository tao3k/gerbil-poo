;;; Reuse the strict source-bound paired driver, including EOF and failure admission.
(export main read-study)
(import (prefix-in "metadata-paired-suite.ss" paired.) "generalized-cases.ss")
;; Execute the fixed generalized descriptor; dynamic scope cannot leak into metadata.
(def (main binary timeout output)
  (paired.with-study specification (lambda () (paired.main binary timeout output))))
;; Re-admit the complete native receipt against current source/binary identities.
(def (read-study path)
  (paired.with-study specification (lambda () (paired.read-study path))))
