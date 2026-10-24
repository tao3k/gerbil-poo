;;; Per-name recovery decisions compose with the existing scoped supervisor.
(export call-with-rejoining-coordinators rejoin-after rejoin-checked)
(import (prefix-in ./joint-coordination coordination.))
;; recover receives a completed name and its original outcome thunk. It handles
;; that outcome and returns an operation to run as a fresh instance, or #f.
;; Decisions are private to each name and consumed once by live supervision.
;; The underlying supervisor cleans/joins old workers, closes old replies, and
;; never restarts during final joins. Callback errors retain whole-scope cleanup.
(def (call-with-rejoining-coordinators operations observe recover)
  (def replacements (make-hash-table-eq))
  (coordination.call-with-coordinators operations observe
    on-exit: (lambda (name outcome)
      (def operation (recover name outcome))
      (unless (or (not operation) (procedure? operation))
        (error "coordinator recovery must return an operation or #f"))
      (hash-put! replacements name operation))
    restart: (lambda (name)
      (def operation (hash-ref replacements name #f))
      (hash-remove! replacements name) operation)))

;; Run recovery preparation inside the new coordinator's own scoped operation.
;; Only success invokes continue with exchange followed by all prepared values.
;; Exceptions retain their identity and follow the supervisor's ordinary exit/
;; recovery path; no fallback, publication, retry or exception wrapping is added.
(def (rejoin-after prepare continue)
  (lambda (exchange)
    (call-with-values (lambda () (prepare exchange))
      (lambda prepared (apply continue exchange prepared)))))

;; Revalidate successful preparation before entering the service continuation.
;; validate receives exchange and the original prepared values, and raises its
;; original refusal on staleness. It may rendezvous with peers before checking.
;; No snapshot is rebound, no retry is implicit, and installation checks remain
;; necessary because another publisher can win after this observation.
(def (rejoin-checked prepare validate continue)
  (rejoin-after prepare
    (lambda (exchange . prepared)
      (apply validate exchange prepared)
      (apply continue exchange prepared))))
