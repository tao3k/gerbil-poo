;;; Full output of a dense owned schedule revision.
(export dense-repair-natural-test dense-repair-collected-test)
(import :std/test :clan/poo/object
        (prefix-in :clan/poo/generalized-graph graph.)
        (prefix-in :clan/poo/dependency-analysis code.)
        (only-in ./closure-measure measure qualified-metrics))

(def (verify-dense-repair collect?)
  (def size 1000000)
  (def names (make-vector size))
  (do ((at 0 (fx+ at 1))) ((fx= at size))
    (vector-set! names at (gensym 'reader)))
  (def (cold)
    (def keys '(last))
    (def codes [])
    (def program (code.need 'hub identity))
    (do ((at (fx- size 1) (fx- at 1))) ((fx< at 0))
      (let (key (vector-ref names at))
        (set! keys (cons key keys))
        (set! codes (cons (cons key program) codes))))
    (graph.schedule-owned (cons 'hub keys) codes))
  (def old (cold))
  (def edits [(cons 'hub (code.need 'last identity)) (cons (vector-ref names 0) #f)])
  (def ticket (graph.schedule-revision old edits))
  (defvalues (next clocks)
    (measure (lambda () (graph.apply-schedule-revision old ticket)) 1 collect?))
  (def work (graph.schedule-work next))
  (check-equal? (.get work search-edges) (1- size))
  (check-equal? (.get work search-buckets) (1+ size))
  (check-equal? (.get work rank-writes) (1+ size))
  (def (verify-order scheduled successor?)
    (let loop ((pending (graph.schedule-order scheduled)) (label 0))
      (if (fx= label (fx+ size 2))
        (unless (null? pending) (error "extra order entries"))
        (let (expected
              (if successor?
                (case label
                  ((0) 'last)
                  ((1) (vector-ref names 0))
                  ((2) 'hub)
                  (else (vector-ref names (fx- label 2))))
                (cond ((fx= label 0) 'hub)
                      ((fx= label (fx+ size 1)) 'last)
                      (else (vector-ref names (fx- label 1))))))
          (unless (and (pair? pending) (eq? expected (car pending)))
            (error "incorrect order entry" label))
          (loop (cdr pending) (fx+ label 1))))))
  (verify-order old #f)
  (verify-order next #t)
  (displayln (list 'REPAIR-SCALE size (qualified-metrics clocks))))

(def dense-repair-natural-test
  (test-suite "dense repair with natural GC"
    (test-case "million-reader complete predecessor and successor order"
      (verify-dense-repair #f))))

(def dense-repair-collected-test
  (test-suite "dense repair after collection"
    (test-case "million-reader complete predecessor and successor order"
      (verify-dense-repair #t))))
