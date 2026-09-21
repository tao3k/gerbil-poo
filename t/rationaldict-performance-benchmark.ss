(export main)

(import
  :gerbil/runtime/gambit
  :std/iter
  ../object
  ../rationaldict
  ../type)

(def T (RationalDict String))
(def entry-count 4096)
(def warmup-repetitions 3)
(def measured-repetitions 50)

(def (build-tables repetitions entries)
  (for/fold (result #f) (_ (in-range repetitions))
    (.call T .<-list entries)))

(def (compare-tables repetitions left right)
  (for/fold (result #f) (_ (in-range repetitions))
    (.call T .=? left right)))

(def (measure-runtime thunk)
  (def started (cpu-time))
  (def result (thunk))
  (values result (- (cpu-time) started)))

(def (main)
  ;; Loading and fixture construction are outside every runtime interval.
  (def entries
    (for/collect (key (in-range entry-count))
      (cons key (number->string key))))
  (def same-entries (map (lambda (entry) (cons (car entry) (cdr entry))) entries))
  (def different-entries
    (cons (cons 0 "different") (cdr same-entries)))
  (def left (.call T .<-list entries))
  (def same (.call T .<-list same-entries))
  (def different-first (.call T .<-list different-entries))

  (build-tables warmup-repetitions entries)
  (compare-tables warmup-repetitions left same)
  (compare-tables warmup-repetitions left different-first)

  (##gc)
  (defvalues (built builder-runtime-cpu-seconds)
    (measure-runtime (lambda () (build-tables measured-repetitions entries))))
  (##gc)
  (defvalues (equal-result equal-runtime-cpu-seconds)
    (measure-runtime (lambda () (compare-tables measured-repetitions left same))))
  (##gc)
  (defvalues (different-result first-difference-runtime-cpu-seconds)
    (measure-runtime
     (lambda () (compare-tables measured-repetitions left different-first))))

  ;; Correctness checks remain outside the measured intervals.
  (unless (= (.call T .count built) entry-count)
    (error "RationalDict builder produced the wrong size"))
  (unless equal-result
    (error "equal RationalDict values compared unequal"))
  (when different-result
    (error "different RationalDict values compared equal"))
  (displayln
   "RATIONALDICT_RUNTIME_RECEIPT="
   [entries: entry-count
    warmup-repetitions: warmup-repetitions
    measured-repetitions: measured-repetitions
    builder-runtime-cpu-seconds: builder-runtime-cpu-seconds
    equal-runtime-cpu-seconds: equal-runtime-cpu-seconds
    first-difference-runtime-cpu-seconds: first-difference-runtime-cpu-seconds]))
