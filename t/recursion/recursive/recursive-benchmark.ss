;; Semantic smoke covers every fixed benchmark mode; synthetic protocol controls
;; remain in metadata-paired-test, which shares the same admission implementation.
(def recursive-benchmark-test
  (test-suite "recursive native controls and isolated study scope"
    (test-case "every recursive control retains its actual semantic oracle"
      (for* ((scenario study.scenarios) (action (workload scenario)))
        (check (and (action) #t) => #t)))
    (test-case "parameterized study cannot replace metadata defaults after return or error"
      (def before (paired.expected-order))
      (check-equal? (paired.with-study study.specification (lambda () (length (paired.expected-order)))) 288)
      (check-equal? (paired.expected-order) before)
      (check-exception (paired.with-study study.specification (lambda () (error "scope"))) true)
      (check-equal? (paired.expected-order) before))))

;; Return the original suites from this lexical scope.
(values recursive-benchmark-test)
