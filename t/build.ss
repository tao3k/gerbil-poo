;;; Retain compiler resource cleanup through its public API; no second scheduler.
(export call-with-build-jobs)
(import (only-in :gerbil/compiler execute-pending-compile-jobs!))
;; Standard make owns normal completion. On refusal, join its existing jobs and
;; retain the original exception, including a distinct cleanup refusal.
(def (call-with-build-jobs thunk)
  (try (thunk)
    (catch (cause)
      (with-catch (lambda (cleanup)
        (unless (eq? cause cleanup) (error "compiler failure and job drain failure" cause cleanup)))
        execute-pending-compile-jobs!)
      (raise cause))))
