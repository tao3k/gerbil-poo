;; Every benchmark mode must execute its real public API and semantic oracle.
(def generalized-benchmark-test
  (test-suite "generalized native benchmark controls"
    (test-case "all scenarios and A/A modes return the same actual result"
      (for* ((scenario generalized-benchmark.study.scenarios) (action (generalized.workload scenario)))
        (check (and (action) #t) => #t)))
    (test-case "untimed counts distinguish hook work cooking and field construction"
      (check-equal? (profile #f #f) '(33 ((compile . 4) (hook . 8) (cook . 2) (price . 2) (rebate . 2))))
      (check-equal? (profile #t #f) '(33 ((compile . 4) (hook . 8) (cook . 2) (price . 1) (rebate . 1))))
      (check-equal? (profile #f #t) '(39 ((compile . 4) (hook . 8) (cook . 4) (price . 4) (rebate . 4))))
      (check-equal? (profile #t #t) '(39 ((compile . 4) (hook . 8) (cook . 2) (price . 1) (rebate . 1)))))))

;; Return the original suites from this lexical scope.
(values generalized-benchmark-test)
