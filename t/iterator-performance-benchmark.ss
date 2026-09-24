(export main)

;; Runtime A/B for iterator mapping; compilation time is outside the measurement.

(import
  :gerbil/runtime/gambit
  :std/iter
  ../object
  ../number
  ../type
  ../table
  ../trie)

(def (coroutine-map transform source)
  (in-coroutine
   (lambda (yield)
     (for (value source)
       (yield (transform value))))))

(def entry-count 4096)
(def repetitions 50)
(def T (SimpleTrie UInt UInt))

(def (sum-keys mapper tree times)
  (for/fold (sum 0) (_ (in-range times))
    (+ sum
       (for/fold (partial 0) (key (mapper car (.call T .iter<- tree)))
         (+ partial key)))))

(def (measure mapper tree)
  (##gc)
  (def start (cpu-time))
  (def result (sum-keys mapper tree repetitions))
  (values result (- (cpu-time) start)))

(def (measure-result mapper tree)
  (let-values (((result seconds) (measure mapper tree)))
    (cons result seconds)))

(def (main)
  (def entries
    (for/collect (key (in-range entry-count))
      (cons key key)))
  (def tree (.call T .<-list entries))
  (def expected (* repetitions (quotient (* entry-count (1- entry-count)) 2)))
  (unless (= (sum-keys coroutine-map tree 1)
             (sum-keys iterator-map tree 1))
    (error "iterator mapping changed the result"))
  (sum-keys coroutine-map tree 2)
  (sum-keys iterator-map tree 2)
  (def samples
    (for/collect (sample-index (in-range 6))
      ;; Alternate execution order to avoid favoring the second measurement.
      (def results
        (if (even? sample-index)
          (list (measure-result coroutine-map tree)
                (measure-result iterator-map tree))
          (let* ((direct (measure-result iterator-map tree))
                 (coroutine (measure-result coroutine-map tree)))
            (list coroutine direct))))
      (def coroutine-result (car results))
      (def direct-result (cadr results))
      (unless (and (= (car coroutine-result) expected)
                   (= (car direct-result) expected))
        (error "iterator benchmark returned an invalid sum"))
      (cons (cdr coroutine-result) (cdr direct-result))))
  (displayln "TRIE_ITERATOR_RUNTIME_AB_RECEIPT="
             [entries: entry-count repetitions: repetitions samples: samples]))
