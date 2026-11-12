;;; Optional cold Graph phase study; absent from default build and CI.
(export cold-topology-test cold-inverse-test)
(import :std/test :std/iter
        (only-in :std/list/list-builder with-list-builder)
        (only-in :clan/poo/benchmarks/closure-measure measure qualified-metrics)
        (only-in :gerbil/runtime/gambit default-random-source))
(extern namespace: #f random-source-state-ref random-source-state-set!)

;; Frozen former schedule-rows traversal, with admitted zero-edge inputs.
;; Native constructors are prepared equally on both arms before phase timing.
(def (full-order keys reads supported states)
  (with-list-builder (add)
    (def (visit key)
      (unless (hash-key? supported key) (error "unsupported cold fixture" key))
      (case (hash-get states key)
        ((done) (void))
        ((active) (error "cyclic cold fixture" key))
        (else (hash-put! states key 'active)
          (for-each visit (hash-ref reads key))
          (hash-put! states key 'done) (add key))))
    (for-each visit keys)))

(def cold-topology-test
  (test-suite "admitted empty Graph topology phase"
    (test-case "full traversal versus unique-roster copy"
      (for (size '(100000 1000000))
        (def keys (for/collect (_ (in-range size)) (gensym 'cold-owner)))
        (def supported (make-hash-table-symbolic))
        (def reads (make-hash-table-symbolic))
        (for (key keys) (hash-put! supported key #t) (hash-put! reads key []))
        (for* ((schedule '((paired full copy copy full copy full full copy)
                          (aa full full) (bb copy copy)))
               (side (cdr schedule)))
          (def states (make-hash-table-eq))
          (defvalues (result clocks)
            (measure (lambda ()
              (if (eq? side 'full) (full-order keys reads supported states) (list-copy keys))) 1))
          (check-equal? result keys)
          (check-equal? (hash-length states) (if (eq? side 'full) size 0))
          ;; The private result spine is fresh on both arms.
          (check-eq? (eq? result keys) #f)
          (displayln (list 'COLD-TOPOLOGY size (car schedule) side
            (qualified-metrics clocks) 'states (hash-length states)
            'raw-allocation (vector-ref clocks 4))))))))

;; Same insertion order as indexed-schedule; this helper is a study only.
(def (inverse keys reads dense?)
  (def readers (make-hash-table-symbolic))
  (when dense? (for (key keys) (hash-put! readers key [])))
  (for (key keys)
    (for (dep (hash-ref reads key))
      (hash-put! readers dep (cons key (hash-ref readers dep [])))))
  readers)

(def cold-inverse-test
  (test-suite "owned inverse construction phase"
    (test-case "empty chain hub retain rows native RNG and sparse bucket counts"
      (for (size '(100000 1000000))
        (def keys (for/collect (_ (in-range size)) (gensym 'inverse-owner)))
        (def positions (list->vector keys))
        (for (shape '(empty chain hub))
          (def reads (make-hash-table-symbolic))
          (for ((key keys) (i (in-range size)))
            (hash-put! reads key
              (cond ((or (zero? i) (eq? shape 'empty)) [])
                    ((eq? shape 'chain) (list (vector-ref positions (1- i))))
                    (else (list (car keys))))))
          (def state (random-source-state-ref default-random-source))
          (def expected (inverse keys reads #t))
          (def after (random-source-state-ref default-random-source))
          (random-source-state-set! default-random-source state)
          (def initial (inverse keys reads #f))
          (check-equal? (random-source-state-ref default-random-source) after)
          (def width (case shape ((empty) 0) ((chain) (1- size)) (else 1)))
          (check-equal? (hash-length initial) width)
          (for* ((schedule '((paired dense sparse sparse dense sparse dense dense sparse)
                            (aa dense dense) (bb sparse sparse)))
                 (side (cdr schedule)))
            (defvalues (result clocks)
              (measure (lambda () (inverse keys reads (eq? side 'dense))) 1))
            (check-equal? (hash-length result) (if (eq? side 'dense) size width))
            ;; Full ordered oracle outside timing, without per-owner harness IO.
            (for (key keys)
              (unless (equal? (hash-ref result key []) (hash-ref expected key []))
                (error "inverse row differs" shape key)))
            (check-equal? (hash-ref result 'unknown-cold-owner []) [])
            (displayln (list 'COLD-INVERSE size shape (car schedule) side
              (qualified-metrics clocks) 'buckets (hash-length result)
              'raw-allocation (vector-ref clocks 4)))))))))
