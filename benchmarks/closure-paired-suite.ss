(export main)
(import :gerbil/runtime/gambit :std/iter "closure-cases.ss" "closure-benchmark-support.ss")
(def (main binary timeout output)
  (def identities (source-digests '("closure.ss" "benchmarks/closure-cases.ss" "benchmarks/closure-measure.ss"
                                    "benchmarks/closure-paired-benchmark.ss" "benchmarks/closure-paired-suite.ss"
                                    "benchmarks/closure-scale-benchmark.ss" "benchmarks/closure-benchmark-support.ss")))
  (def failed #f)
  (call-with-output-file (list path: output truncate: #t)
    (lambda (port)
      (def (emit datum) (write datum port) (newline port) (force-output port))
      (emit `(closure-paired (cases ,@focus-cases) (sources ,@identities) (binary ,@(source-digests (list binary)))
                (columns case scope round queue repetitions costs) (metrics cpu wall gc-cpu collections bytes)
                (rounds 8) (toolchain ,(gerbil-version-string) ,(system-version-string)) (deadline 20) (heap "1G")))
      (for (index (in-range (length focus-cases)))
        (match (list-ref focus-cases index) ([family size width]
          (try
            (defvalues (status stdout) (run-bounded timeout
              (list binary "-:max-heap=1G" family (number->string size) (number->string width))))
            (unless (= status 0) (error "paired child failed" status stdout))
            (def rows (call-with-input-string stdout read-one))
            (unless (= (length rows) (* (length scopes) 8 (length queues))) (error "paired coverage"))
            (for (row rows) (emit (list->vector (cons index (vector->list row)))))
            (for* ((scope scopes) (queue queues))
              (def selected (filter (lambda (row) (and (eq? (vector-ref row 0) scope) (eq? (vector-ref row 2) queue))) rows))
              (displayln family "/" scope "/" queue " us="
                (* 1e6 (median (map (lambda (row) (/ (vector-ref (vector-ref row 4) 0) (vector-ref row 3))) selected)))
                " bytes=" (median (map (lambda (row) (/ (vector-ref (vector-ref row 4) 4) (vector-ref row 3))) selected))))
            (catch (cause) (set! failed #t) (emit `(failed ,index ,(object->string cause))))))))
      (check-sources! identities)
      (when failed (error "paired failures retained" output))
      (emit `(complete ,(* (length focus-cases) (length scopes) 8 (length queues))))))
  (displayln "CLOSURE-PAIRED-OK observations=480"))
