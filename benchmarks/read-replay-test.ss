;;; POO-only replay comparison on one authenticated projection and read set.
;;; The standard compiler and Just test-file own preparation and execution.
(export read-replay-test)
(import :std/test :std/iter :clan/poo/object :clan/poo/slot-observation
        (only-in :std/list/list take))
(extern namespace: clan/poo/object call-with-issued-reads active-read-replays)

;; Conservative per-record checkpoint on the SAME current topology index.
;; This is a validation oracle only: it defines no owner cache or evaluator.
(def (per-record roots action)
  (without-observation
    (lambda ()
      (call-with-issued-reads roots
        (lambda (reads live! receivers)
          (def (current! read)
            (unless (object-read-issued? read) (error "unissued slot dependency"))
            (live! read))
          (parameterize ((active-read-replays (cons receivers (active-read-replays))))
            (begin0
              (begin (for-each current! reads) (action (length reads)))
              (for-each current! reads))))
        #t #t))))

(def (measure shape phase side thunk)
  (def result #f)
  (def stats (##exec-stats (lambda () (set! result (thunk)))))
  (displayln "READ-REPLAY shape=" shape " phase=" phase " side=" side
    " metrics=" (filter (lambda (entry) (not (eq? (car entry) 'result))) stats))
  result)

(def (measure-root-merge shape roots)
  (call-with-issued-reads roots
    (lambda (reads live! _receivers)
      (for-each live! reads)
      (def shared (take reads 206))
      (def owners (take (list-tail reads 206) 8000))
      (def groups (map (lambda (owner) (cons owner shared)) owners))
      (def expected (cons (car owners) (append shared (cdr owners))))
      (def (collector)
        (defvalues (_ result)
          (%call-with-recorded-slot-reads
            (lambda () (for-each %record-slot-reads! groups)) unique-roots?: #t))
        result)
      (def (verify observed)
        (unless (and (= (length expected) (length observed))
                     (andmap eq? expected observed))
          (error "read root merge changed first-occurrence order")))
      (verify (collector))
      (displayln "READ-ROOT-MERGE-INPUT groups=8000 visits=1656000 unique=8206")
      (for (_ (in-range 4))
        (verify (measure shape 'merge-roots 'collector collector))))
    #t #t))

(def (study count width)
  (def shape (list count width))
  (def keys
    (for/collect (n (in-range width))
      (string->symbol (string-append "slot-" (number->string n)))))
  (def owners
    (measure shape 'construct 'common
      (lambda ()
        (for/collect (n (in-range count))
          (make-object slots:
            (map (lambda (key) (cons key ($constant-slot-spec (if (zero? n) #f n)))) keys))))))
  (.def Root result:
    (for/collect (owner owners)
      (map (lambda (key) (.ref owner key)) keys)))
  (def captured
    (measure shape 'first-demand 'common
      (lambda ()
        (call-with-values
          (lambda () (%call-with-recorded-slot-reads (lambda () (.get Root result))))
          list))))
  (def expected
    (for/collect (n (in-range count)) (make-list width (if (zero? n) #f n))))
  (check-equal? (car captured) expected)
  (def roots (cadr captured))
  (def action (lambda (visits) visits))
  (def records (per-record roots action))
  (check-equal? (call-with-current-slot-reads roots action) records)
  (when (> records 8206) (measure-root-merge shape roots))
  (displayln "READ-REPLAY-INPUT shape=" shape " roots=" (length roots)
    " records=" records " repetitions=12")
  (for (phase '(warm cold-index))
    (for (side '(per-record shared shared per-record per-record shared shared per-record))
      ;; Root-spine copying is setup, not index construction. Both arms use
      ;; the current producer's index, including its cold binding allocations.
      (def inputs
        (if (eq? phase 'warm) (make-list 12 roots)
          (for/collect (_ (in-range 12)) (map values roots))))
      (measure shape phase side
        (lambda ()
          (for (input inputs)
            (check-equal?
              ((if (eq? side 'per-record) per-record call-with-current-slot-reads) input action)
              records)))))))

(def read-replay-test
  (test-suite "POO protected replay with identical authenticated support"
    (test-case "one value per receiver" (study 128 1))
    (test-case "many values per receiver" (study 64 128))))
