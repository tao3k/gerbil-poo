(export binding-benchmark-test)
(import :std/test :std/iter (only-in "binding-benchmark.ss" workload)
  (prefix-in "binding-cases.ss" study.) (prefix-in "metadata-paired-suite.ss" paired.))
;; Verify real controls, duplicate identity and fixed complete coverage before AOT.
(def binding-benchmark-test
  (test-suite "context binding native controls"
    (test-case "all phases execute real current public observations"
      (for (scenario study.scenarios)
        (def actions (workload scenario))
        (check (eq? (car actions) (caddr actions)) => #t)
        (check (eq? (cadr actions) (cadddr actions)) => #t)
        (for (action actions) (check (action) => #t))))
    (test-case "fixed complete study restores the native driver configuration"
      (def before (paired.expected-order))
      (check-equal? (paired.with-study study.specification (lambda () (length (paired.expected-order)))) 576)
      (check-equal? (paired.expected-order) before))))
