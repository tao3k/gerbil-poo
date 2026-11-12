;;; Optional prepared-family membership study; not Module loading or full EVAL.
(export component-family-index-test)
(import :std/test :std/iter :clan/poo/object :clan/poo/mop
        (only-in :gerbil/runtime/gambit default-random-source)
        (only-in :clan/poo/benchmarks/closure-measure measure qualified-metrics))
(extern namespace: #f random-source-state-ref)
(def (list-accepts? keys members)
  (and (andmap (lambda (key) (memq key keys)) members) #t))
(def (index-accepts? lenses members)
  (and (andmap (lambda (key) (and (symbol? key) (hash-key? lenses key))) members) #t))
(def component-family-index-test
  (test-suite "prepared family uses its existing lens index"
    (test-case "domain presence and symbol identity including false focus value"
      (def first (gensym 'family)) (def second (gensym 'family))
      (def keys (list first second 'a))
      (def lenses (make-hash-table-eq))
      (for (key keys) (hash-put! lenses key #f))
      (for (members (list [] (list first) (list second first second) '(a)
                         '(missing) '(a missing) '(#f) '(1) '("a")))
        (def state (random-source-state-ref default-random-source))
        (check-eq? (index-accepts? lenses members) (list-accepts? keys members))
        (check-equal? (random-source-state-ref default-random-source) state)))
    (test-case "100K and 1M prepared names, same fixed queries and native index"
      (for (size '(100000 1000000))
        (def keys (for/collect (i (in-range size))
          (string->symbol (string-append "family-index-owner-" (number->string i)))))
        ;; Preparation excluded on BOTH arms: production already owns this
        ;; index for focus lookup. This is not a cold index-construction claim.
        (def lenses (make-hash-table-eq))
        (def focus (.lens))
        (for (key keys) (hash-put! lenses key focus))
        (check-equal? (hash-length lenses) size)
        (for (key keys)
          (unless (hash-key? lenses key) (error "prepared family domain lost" key)))
        (check-eq? (hash-key? lenses 'missing-family-owner) #f)
        (def names (list->vector keys))
        (def members (for/collect (i (in-range 32))
          (vector-ref names (quotient (* i (- size 1)) 31))))
        (for* ((schedule '((paired list indexed indexed list indexed list list indexed)
                          (aa list list) (bb indexed indexed)))
               (side (cdr schedule)))
          (defvalues (accepted clocks)
            (measure (lambda ()
              (if (eq? side 'list) (list-accepts? keys members)
                (index-accepts? lenses members))) 8))
          (check-eq? accepted #t)
          (displayln (list 'COMPONENT-FAMILY-INDEX size (car schedule) side
            'queries 256 (qualified-metrics clocks) 'raw-allocation (vector-ref clocks 4))))))))
