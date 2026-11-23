;;; Optional compiled attribution of the original owned Graph capture.
(import :std/test :std/iter
        (only-in :std/list/list delete-duplicates/hash)
        (only-in :clan/poo/object .cc .get call-with-current-slot-reads)
        (only-in :clan/poo/graph/computation Computation.)
        (only-in :clan/poo/object/slot-observation %call-with-recorded-slot-reads %record-slot-reads!)
        (only-in :clan/poo/support/base %graph-table-seed)
        (only-in :clan/poo/support/index %index)
        (only-in "./closure-measure.ss" measure qualified-metrics)
        (prefix-in :clan/poo/graph/schedule graph.))
(export graph-capture-test)
(extern namespace: clan/poo/object %bind-current-slot-reads)
(extern namespace: clan/poo/graph/schedule capture-program capture-program-batch keys! table
        check-edit-targets make-%program program-row make-%owned-source owned-declaration schedule-rows)

(def (clock-phase totals name action)
  (defvalues (result clocks) (measure action 1))
  (def saved (or (hash-get totals name) (make-vector 5 0)))
  (for (i (in-range 5)) (vector-set! saved i (+ (vector-ref saved i) (vector-ref clocks i))))
  (hash-put! totals name saved)
  result)

(def (capture-index code-keys programs)
  ;; Exact original compiled loop; retain every captured program in its original
  ;; table. Discarding bound carriers would change both live data and GC cost.
  (capture-program-batch
    (lambda ()
      (for (key code-keys)
        (hash-put! programs key (capture-program (hash-ref programs key))))))
  programs)

(def (attributed code-keys programs totals)
  ;; Same callees, ordering, unique outer capture and retained output as above.
  ;; Per-operation clocks add overhead, so only the uninstrumented arm is a
  ;; performance comparison. The fields below locate work, not a speedup.
  (defvalues (_ support)
    (%call-with-recorded-slot-reads
      (lambda ()
        (for (key code-keys)
          (def program (hash-ref programs key))
          (def captured
            (clock-phase totals 'getter-and-normalization
              (lambda ()
                (call-with-values
                  (lambda ()
                    (%call-with-recorded-slot-reads
                      (lambda ()
                        (let* ((reads (clock-phase totals 'slot-demand (lambda () (.get program reads))))
                               (row (clock-phase totals 'row-normalization (lambda () (keys! reads)))))
                          (clock-phase totals 'row-snapshot (lambda () (list-copy row))))))) list))))
          (def bound
            (clock-phase totals 'bind-evidence
              (lambda () (%bind-current-slot-reads (cadr captured)))))
          (clock-phase totals 'merge-roots (lambda () (%record-slot-reads! (cadr captured))))
          (hash-put! programs key (make-%program program (car captured) bound)))) unique-roots?: #t))
  (clock-phase totals 'batch-currentness
    (lambda () (call-with-current-slot-reads support values)))
  programs)

(def graph-capture-test
  (test-suite "owned Graph program capture attribution"
    (test-case "compiled 10000-program star retains the production source graph"
      (def keys (for/collect (i (in-range 10000))
        (string->symbol (string-append "capture-owner-" (number->string i)))))
      (for (side '(production attributed attributed production))
        ;; Match schedule-owned/rows preparation, outside capture timing.
        (def codes (map (lambda (key) (cons key (.cc Computation. reads: (list (car keys))))) (cdr keys)))
        (def supported (make-hash-table-symbolic seed: (%graph-table-seed)))
        (def names (delete-duplicates/hash keys table: supported from-end?: #t))
        (def programs (table codes))
        (def bases (table [] (make-hash-table-symbolic seed: (%graph-table-seed))))
        (def code-keys (map car codes))
        (check-edit-targets (cut hash-key? supported <>) code-keys [] bases)
        (def totals (make-hash-table-eq))
        (defvalues (result clocks)
          (measure (lambda ()
            (if (eq? side 'production) (capture-index code-keys programs)
                (attributed code-keys programs totals))) 1))
        (displayln (list 'GRAPH-CAPTURE side 'total (qualified-metrics clocks)))
        (for (name '(getter-and-normalization slot-demand row-normalization row-snapshot
                    bind-evidence merge-roots batch-currentness))
          (let (entry (hash-get totals name))
            (when entry (displayln (list 'GRAPH-CAPTURE side name (qualified-metrics entry))))))
        (check-eq? result programs)
        (check-equal? (hash-length result) 9999)
        ;; Continue through the original post-capture callees. This keeps the
        ;; captured bindings alive through public order/row validation as in
        ;; schedule-owned; none of the output becomes a discarded timing proxy.
        (def source (make-%owned-source names (%index result) (%index bases)))
        (def scheduled (schedule-rows (owned-declaration source) names
          (lambda (key) (program-row (hash-get result key))) source supported #f #t))
        (check-equal? (graph.schedule-order scheduled) names)
        (check-equal? ((graph.schedule-reads scheduled) (cadr names)) (list (car names)))))))
