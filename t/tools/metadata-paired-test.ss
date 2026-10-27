(export metadata-paired-test)
(import :std/test :std/iter :clan/poo/benchmarks/closure-measure
        (prefix-in :clan/poo/benchmarks/metadata-paired-cases study.)
        (only-in :clan/poo/benchmarks/metadata-paired-suite check-study expected-order)
        (only-in :clan/poo/benchmarks/metadata-paired-benchmark workload))
;; Synthetic admission controls only; these are never published measurements.
;; Synthetic current-identity admission fixture, never native performance evidence.
;; Its binary identity intentionally points to a small source file used only in tests.
(def (header)
  `(metadata-paired (scenarios ,@study.scenarios) (regimes ,@study.regimes)
    (strategies ,@study.strategies) (pairs ,@study.pairs) (rounds ,study.rounds) (warmups ,study.warmups)
    (prefix all-controls-in-fixed-order fresh-process-per-side)
    (deadline 20) (heap "1G") (sources ,@(source-digests study.sources))
    (binary ,@(source-digests '("benchmarks/metadata-paired-cases.ss")))))
;; Construct deterministic synthetic rows with valid sides, counters and metrics
;; so each rejection test changes exactly one receipt premise.
(def (rows)
  (map (match <> ([scenario regime round pair-index position]
    (def side (list-ref (study.side-order round (list-ref study.pairs pair-index)) position))
    (vector scenario regime round pair-index position
      (vector scenario regime side (study.repetitions scenario) (vector 1.0 1.0 0.0 0 7) 7 (vector 0 0 0))))) (expected-order)))
;; Execute every workload control semantically, then verify malformed/stale/order
;; and allocation refusals. Synthetic samples test admission only, never speed.
(def metadata-paired-test
  (test-suite "fresh-process paired protocol admission"
    (test-case "measurement observers run after actions and preserve five result columns"
      (def calls 0) (def observed #f)
      (def initial (##process-statistics))
      (defvalues (result metrics)
        (measure (lambda () (set! calls (+ calls 1)) calls) 3 #t
          (lambda (before after elapsed)
            (check-equal? calls 3)
            (check (> elapsed 0.0) => #t)
            (check-equal? (f64vector-length before) 20)
            (check-equal? (f64vector-length after) 20)
            ;; Collected mode performs its explicit GC BEFORE the timed boundary.
            (check (>= (f64vector-ref before 6) (+ 1 (f64vector-ref initial 6))) => #t)
            (check (>= (f64vector-ref after 6) (f64vector-ref before 6)) => #t)
            (set! observed #t))))
      (check-equal? result 3)
      (check-equal? (vector-length metrics) 5)
      (check observed => #t)
      (def failure (list 'measurement-refused))
      (set! observed #f)
      (def caught (try
        (measure (lambda () (raise failure)) 1 #f (lambda (_before _after _elapsed) (set! observed #t)))
        #f (catch (cause) cause)))
      (check (eq? caught failure) => #t)
      (check observed => #f))
    (test-case "all semantic controls implement the same public observations"
      (for* ((scenario study.scenarios) (action (workload scenario))) (check (action) => #t)))
    (test-case "missing duplicate swapped side stale and invalid metrics refuse"
      (def data (rows))
      (def complete (list 'complete (length data)))
      (check-equal? (length (check-study (header) data complete)) (length (expected-order)))
      (check-exception (check-study (header) (cdr data) complete) true)
      (check-exception (check-study (header) (cons (car data) data) complete) true)
      (check-exception (check-study (header) (reverse data) complete) true)
      (check-exception (check-study (header) data '(incomplete)) true)
      (def stale (header))
      (set-cdr! (assq 'sources (cdr stale)) [])
      (check-exception (check-study stale data complete) true)
      (def first (car data))
      (def child (vector-ref first 5))
      (def original-side (vector-ref child 2))
      (vector-set! child 2 -1)
      (check-exception (check-study (header) data complete) true)
      (vector-set! child 2 original-side)
      (def metrics (vector-ref child 4))
      (vector-set! metrics 0 +inf.0)
      (check-exception (check-study (header) data complete) true)
      (vector-set! metrics 0 1.0)
      ;; A signed/reset allocation counter never becomes a claimed byte saving.
      (vector-set! child 5 -1)
      (check-exception (check-study (header) data complete) true)
      (vector-set! child 5 7)
      (vector-set! metrics 3 1)
      (check-exception (check-study (header) data complete) true)
      (vector-set! metrics 4 #f)
      (check-equal? (length (check-study (header) data complete)) (length (expected-order))))))
