;;; Per-name recovery decisions compose with the existing scoped supervisor.
(export call-with-rejoining-coordinators)
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
