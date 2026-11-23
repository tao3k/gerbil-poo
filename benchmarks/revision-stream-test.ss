;;; Optional pure revision comparison study; no default workload or observer.
(export revision-stream-test)
(import :std/test :std/iter :clan/poo/object
        (only-in :clan/poo/benchmarks/closure-measure measure qualified-metrics))
(def (original-current? sources versions)
  (equal? versions (map object-revision sources)))
(def revision-stream-test
  (test-suite "fixed revision fields without intermediate lists"
    (test-case "exact source domains and actual revision invalidation"
      (def a (.o)) (def b (.o))
      (def sources (list a b))
      (def versions (map object-revision sources))
      (check-eq? (%object-revisions-current? [] []) #t)
      (check-eq? (%object-revisions-current? sources []) #f)
      (check-eq? (%object-revisions-current? [] versions) #f)
      (check-eq? (%object-revisions-current? sources versions) #t)
      (uninstantiate-object! b)
      (check-eq? (%object-revisions-current? sources versions) #f)
      (check-eq? (original-current? sources versions) #f))
    (test-case "same-process current and early/late stale comparisons"
      ;; Distinct real POO sources. Setup is outside BOTH arms; these are not
      ;; module-loading or source-discovery measurements.
      (for (size '(8 64 1024))
        (def sources (for/collect (_ (in-range size)) (.o)))
        (def versions (map object-revision sources))
        (for (scenario '(current head-stale tail-stale))
          (def captured (case scenario
            ((head-stale) (cons (1+ (car versions)) (cdr versions)))
            ((tail-stale) (append (reverse (cdr (reverse versions)))
                                  (list (1+ (car (reverse versions))))))
            (else versions)))
          (def expected (eq? scenario 'current))
          (for* ((schedule '((paired original streamed streamed original
                                      streamed original original streamed)
                            (aa original original) (bb streamed streamed)))
                 (side (cdr schedule)))
            (defvalues (answer clocks)
              (measure (lambda ()
                (if (eq? side 'original) (original-current? sources captured)
                  (%object-revisions-current? sources captured))) 1024))
            (check-eq? answer expected)
            (displayln (list 'REVISION-STREAM size scenario (car schedule) side
              'checks 1024 (qualified-metrics clocks)
              'raw-allocation (vector-ref clocks 4)))))))))
