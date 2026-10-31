(export metadata-report-test test-setup!)
(import :std/test :std/iter (only-in :std/list/list-builder with-list-builder)
        (only-in :gerbil/runtime/loader list-modules) :clan/poo/benchmarks/closure-measure
        (prefix-in (only-in :clan/poo/benchmarks/metadata-report sources phases rounds repetitions) benchmark.) (only-in :clan/poo/benchmarks/metadata-report check-study))
;; Suite-local helpers expand before import; these six module stages are unused.
(def private-helper-owners
  '("clan/poo/t/backends/fq-test" "clan/poo/t/backends/polynomial-test"
    "clan/poo/t/backends/trie-test" "clan/poo/t/objects/parameters-test"
    "clan/poo/t/objects/support-test" "clan/poo/t/representations/type-test"))
;; The complete harness executes this after all imports; focused runs have a
;; smaller inventory. The existing observer checks complete-run order separately.
;; Read the official registry without retaining loader state.
(def (test-setup!)
  (def modules (list-modules))
  ;; Every root is already prepared here; reporting must not demand its workload.
  (when (assoc "clan/poo/benchmarks/metadata-benchmark" modules)
    (error "metadata admission loaded the benchmark workload"))
  (displayln "TEST-IMPORT-INVENTORY "
    (length (filter (lambda (entry) (string? (cdr entry))) modules)) " "
    (length (filter (lambda (owner) (assoc (string-append owner "~1") modules)) private-helper-owners)))
  (force-output)
  (report-process-counters 'prepared))
(def (study rows)
  `(metadata-benchmarks (status complete) (sources ,@(source-digests benchmark.sources))
     (rounds ,benchmark.rounds) (phases ,@benchmark.phases) (rows ,@rows)))
(def metadata-report-test
  (test-suite "metadata study admission"
    (test-case "suite helper image admission matches compiler scope"
      (def modules (list-modules))
      (for-each (lambda (owner)
        (check (and (assoc (string-append owner "~1") modules) #t) => #f)) private-helper-owners))
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
