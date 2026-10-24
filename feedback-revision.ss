;;; Re-close revised shared feedback, then admit the complete service publication.
(export feedback-revision-action publish-feedback-revision
        feedback-approval-failure? feedback-approval-failure-kind)
(import ./object ./generalized-declaration ./generalized-closure ./feedback-closure ./lens-laws
        (prefix-in ./generalized-prototype gp.))
;; Approval refusal carries no speculative raw/cooked candidate. Non-Boolean
;; results are distinct from an actual Boolean refusal; neither authorizes publication.
(defstruct feedback-approval-failure (kind) final: #t)
;; Reader input is the old receipt (or #f initially). Its immutable raw is only a
;; search seed: every revised fixed point/residual and joint approval runs afresh.
;; Register approval dependencies in the preparation or supplied lens-check sources.
;; All such sources remain guarded until approval has consumed the exact candidate.
(def (feedback-revision-action prepared base budget admit checks: (checks []))
  (unless (procedure? admit) (error "joint feedback admission procedure required"))
  (lambda (old)
    (unless (or (not old) (closed-fragments? old)) (error "old feedback receipt or #f required"))
    (with-fragment-sources prepared (lambda () (with-lens-checks checks (lambda ()
      ((.call gp.Observation. .map (lambda (candidate)
        (def accepted (admit old candidate))
        (unless (eq? accepted #t)
          (raise (make-feedback-approval-failure (if (boolean? accepted) 'refused 'non-boolean))))
        candidate)
        (feedback-closure-action prepared base budget checks: checks))
        (if old (closed-raw old) base))))))))
;; Publish the exact new receipt only after closure, every component residual and
;; current joint approval. Any failure retains the exact old receipt and exception.
;; Supported source writes refuse before mutation; external I/O is not rolled back.
(def (publish-feedback-revision old prepared base budget admit checks: (checks []))
  (try (values ((feedback-revision-action prepared base budget admit checks: checks) old) #f)
    (catch (failure) (values old failure))))
