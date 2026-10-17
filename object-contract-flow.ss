;;; Value admission composed through the existing Reader/FUN observation protocol.
(export checked-action)
(import (only-in ./support/base require-value) (only-in ./object .call)
        (only-in ./mop Type validate)
        (prefix-in ./generalized-prototype observation.))
;; Bind one value validator before the consumer. Each invocation checks its own
;; current candidate; successful normalization (including a Function wrapper)
;; reaches the consumer once. Refusal preserves the original exception and never
;; runs that consumer. Multiple consumer return values remain unchanged.
(def (checked-action descriptor consume)
  (validate Type descriptor)
  (require-value consume procedure? (lambda () (error "Contract consumer must be a procedure")))
  (.call observation.Observation. .bind
    (lambda (candidate) (validate descriptor candidate))
    (lambda (checked) (lambda (_candidate) (consume checked)))))
