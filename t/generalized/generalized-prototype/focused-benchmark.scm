;; Verify every timed control through its actual API; no expected result is injected.
(def focused-benchmark-test
  (test-suite "focused construction native controls"
    (test-case "all phases preserve public values and raw audit frames"
      (for (scenario focused-benchmark.study.scenarios)
        (def actions (focused.workload scenario))
        (check (eq? (car actions) (caddr actions)) => #t)
        (check (eq? (cadr actions) (cadddr actions)) => #t)
        (for (action actions) (check (action) => #t))))
    (test-case "complete study has fixed coverage and restores shared driver scope"
      (def before (paired.expected-order))
      (check-equal? (paired.with-study focused-benchmark.study.specification (lambda () (length (paired.expected-order)))) 576)
      (check-equal? (paired.expected-order) before))))

;; Return the original suites from this lexical scope.
(values focused-benchmark-test)
