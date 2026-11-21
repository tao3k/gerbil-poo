;;; Same-process ABBA field-only study; the ordinary test tool owns execution.
;;; Full replay correctness remains in t/objects/issued-read-test.ss.
(export read-field-test)
(import :std/test :std/iter :clan/poo/object :clan/poo/slot-observation
        (prefix-in (only-in :gerbil/runtime/mop slot-ref) runtime.))
(extern namespace: clan/poo/object object-read-key)
(def read-field-test
  (test-suite "authenticated live read key access"
    (test-case "interleaved named and fixed access on identical issued records"
      (.def Owner value: #f other: 2)
      (def reads '())
      (call-with-slot-read-observer
        (lambda (read) (set! reads (cons read reads)))
        (lambda () (.get Owner value) (.get Owner other) (.all-slots Owner)
                   (.ref/cached Owner 'missing (lambda () #f))))
      (check (pair? reads) => #t)
      (for (read reads) (check (object-read-issued? read) => #t))
      (def expected (map (lambda (read) (runtime.slot-ref read 'key)) reads))
      (def (named read) (runtime.slot-ref read 'key))
      (def (fixed read) (object-read-key read))
      (def (work getter repetitions)
        (let loop ((left repetitions))
          (unless (zero? left)
            (for-each (lambda (read key)
                        (unless (eq? (getter read) key) (error "changed live key")))
                      reads expected)
            (loop (- left 1)))))
      ;; Both paths receive the same warmup. No collection is forced and no
      ;; sample is discarded. This isolates access, not whole replay or EVAL.
      (work named 2000)
      (work fixed 2000)
      (for (side '(named fixed fixed named named fixed fixed named))
        (def stats (##exec-stats
          (lambda () (work (if (eq? side 'named) named fixed) 100000))))
        (displayln "READ-FIELD side=" side " records=" (length reads)
                   " repetitions=100000 metrics="
                   (filter (lambda (entry)
                             (memq (car entry) '(user-time sys-time real-time
                               gc-user-time gc-sys-time gc-real-time nb-gcs))) stats))))))
