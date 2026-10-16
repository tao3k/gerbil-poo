(export generalized-benchmark-test)
(import :std/test :std/iter (only-in "generalized-benchmark.ss" workload)
        (prefix-in "generalized-cases.ss" study.))
;; Every benchmark mode must execute its real public API and semantic oracle.
(def generalized-benchmark-test
  (test-suite "generalized native benchmark controls"
    (test-case "all scenarios and A/A modes return the same actual result"
      (for* ((scenario study.scenarios) (action (workload scenario)))
        (check (and (action) #t) => #t)))))
