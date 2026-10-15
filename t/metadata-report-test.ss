(export metadata-report-test)
(import :std/test :std/iter (only-in :std/list/list-builder with-list-builder) "closure-measure.ss"
        (prefix-in "metadata-benchmark.ss" benchmark.) (only-in "metadata-report.ss" check-study))
(def (study rows)
  `(metadata-benchmarks (status complete) (sources ,@(source-digests benchmark.sources))
     (rounds ,benchmark.rounds) (phases ,@benchmark.phases) (rows ,@rows)))
(def metadata-report-test
  (test-suite "native metadata study admission"
    (test-case "missing duplicate stale and invalid allocation controls"
      (def rows (with-list-builder (add)
        (for* ((gc '(natural collected)) (round (in-range benchmark.rounds)) (phase benchmark.phases))
          (add (vector gc round phase (benchmark.repetitions phase) (vector 1.0 1.0 0.0 0 7) 7)))))
      (check-equal? (length (check-study (study rows))) (* 2 benchmark.rounds (length benchmark.phases)))
      (check-exception (check-study (study (cdr rows))) true)
      (check-exception (check-study (study (cons (car rows) rows))) true)
      (check-exception (check-study '(metadata-benchmarks (status incomplete))) true)
      (def first (car rows))
      (def gc-row (vector (vector-ref first 0) (vector-ref first 1) (vector-ref first 2) (vector-ref first 3) (vector 1.0 1.0 0.0 1 #f) -7))
      (check-equal? (length (check-study (study (cons gc-row (cdr rows))))) (* 2 benchmark.rounds (length benchmark.phases)))
      (vector-set! (vector-ref gc-row 4) 4 0)
      (check-exception (check-study (study (cons gc-row (cdr rows)))) true))))
