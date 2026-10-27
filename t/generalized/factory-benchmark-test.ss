(export factory-benchmark-test)
(import :std/test :std/iter (only-in :clan/poo/benchmarks/factory-benchmark workload)
  (prefix-in :clan/poo/benchmarks/factory-cases study.) (prefix-in :clan/poo/benchmarks/metadata-paired-suite paired.))
;; Exercise every real phase, source-study coverage and duplicate procedure identity.
(def factory-benchmark-test
  (test-suite "item representation factory controls"
    (test-case "all phases preserve current public values and raw frames"
      (for (scenario study.scenarios)
        (def actions (workload scenario))
        (check (eq? (car actions) (caddr actions)) => #t)
        (check (eq? (cadr actions) (cadddr actions)) => #t)
        (for (action actions) (check (action) => #t))))
    (test-case "complete study restores shared native I/O scope"
      (def before (paired.expected-order))
      (check-equal? (paired.with-study study.specification (lambda () (length (paired.expected-order)))) 624)
      (check-equal? (paired.expected-order) before))))
