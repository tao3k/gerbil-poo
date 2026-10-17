;;; Ordered diagnostic accumulation and phase boundaries for value contracts.
(export checked-issues diagnostic-all diagnostic-then)
(import (only-in ./support/base require-value) (only-in :std/list/list append-map)
        (only-in ./object object? .slot? .get))
;; Reject malformed callback results as programming errors, preserving exceptions.
;; A diagnostic records a symbolic kind and a path, without copying user values.
(def (checked-issues failures)
  (require-value failures
    (list-of? (lambda (failure)
                (and (object? failure) (.slot? failure 'kind) (.slot? failure 'path)
                     (symbol? (.get failure kind)) (list? (.get failure path)))))
    (lambda () (error "Expected a list of POO diagnostics with kind and path" failures))))
;; Prepare an ordered conjunction once. All checks see the same value/path;
;; ordinary rejection accumulates, while callback exceptions stop and propagate.
(def (diagnostic-all checks)
  (require-value checks (list-of? procedure?)
    (lambda () (error "Diagnostic checks must be a list of procedures")))
  (lambda (value path)
    (append-map (lambda (check) (checked-issues (check value path))) checks)))
;; Prepare a phase boundary once. Never invoke the next phase on a nonempty
;; refusal; pass the exact same value/path on success, without rebasing/coercion.
(def (diagnostic-then first next)
  (require-value first procedure? (lambda () (error "Diagnostic phases must be procedures")))
  (require-value next procedure? (lambda () (error "Diagnostic phases must be procedures")))
  (lambda (value path)
    (def failures (checked-issues (first value path)))
    (if (null? failures) (checked-issues (next value path)) failures)))
