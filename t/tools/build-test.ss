;;; POO-owned build boundaries; Gerbil owns CLI, make and test-runner validation.
(export build-test)
(import :std/test :std/iter
  (only-in :std/misc/process run-process)
  (only-in :clan/poo/t/build call-with-build-jobs))

;; Exercise POO's value/error boundary and public resource policy directly.
;; The standard runner owns fixtures, discovery, case execution and reporting.
(def build-test
  (test-suite "POO build boundaries"
    (test-case "testing modules keep their declared public paths"
      (for (module '("testing/type.ss" "testing/function.ss" "testing/generation-graph.ss" "testing/recursive-generation.ss"))
        (check (file-exists? module) => #t))
      (for (old '("property-testing.ss" "function-testing.ss" "generation-graph.ss" "recursive-generation.ss"))
        (check (file-exists? old) => #f)))
    (test-case "independent property-library build is executable and bounded"
      ;; Check the published entry itself; the official CLI owns its execution.
      (def script "testing/core/build.ss")
      (check (bitwise-and (file-info-mode (file-info script)) #o111) => #o111)
      (check (call-with-input-file script read-line)
        => "#!/usr/bin/env -S gxi -:max-heap=1G,debug=q"))
    (test-case "build-job boundary preserves multiple values"
      (check-equal? (call-with-values (cut call-with-build-jobs (lambda () (values 1 2))) list) '(1 2)))
    (test-case "build-job boundary preserves false exceptions"
      (check-equal? (with-catch (lambda (cause) (list cause))
        (cut call-with-build-jobs (lambda () (raise #f)))) '(#f)))
    (test-case "build-job boundary preserves exception identity"
      (let (cause (cons 'refused []))
        (check-eq? (with-catch identity (cut call-with-build-jobs (lambda () (raise cause)))) cause)))
    (test-case "public check recipes retain the standard entry and resource limits"
      ;; Dry-run POO's recipe only; this does not launch another build or test.
      (def output (run-process '("just" "--dry-run" "check-built" "2" "1" "4") stderr-redirection: #t))
      (check (string-contains output "_test 300") ? integer?)
      (check (string-contains output "_run-collections") ? integer?)
      (check (string-contains output "gxi") => #f))))
