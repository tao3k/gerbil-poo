;; Exercise every real phase, source-study coverage and duplicate procedure identity.
(def factory-benchmark-test
  (test-suite "item representation factory controls"
    (test-case "all phases preserve current public values and raw frames"
      (for (scenario factory-benchmark.study.scenarios)
        (def actions (factory.workload scenario))
        (check (eq? (car actions) (caddr actions)) => #t)
        (check (eq? (cadr actions) (cadddr actions)) => #t)
        (for (action actions) (check (action) => #t))))
    (test-case "complete study restores shared native I/O scope"
      (def before (paired.expected-order))
      (check-equal? (paired.with-study factory-benchmark.study.specification (lambda () (length (paired.expected-order)))) 624)
      (check-equal? (paired.expected-order) before))))

;; Return the original suites from this lexical scope.
(values factory-benchmark-test)
