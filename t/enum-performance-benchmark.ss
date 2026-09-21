(export main)

(import
  :gerbil/runtime/gambit
  :std/iter
  ../object
  ../type)

(def E
  (Enum 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15
        16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31
        32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47
        48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63))

(def target 63)
(def warmup-repetitions 10000)
(def measured-repetitions 200000)

(def (lookup-sum repetitions)
  (for/fold (sum 0) (_ (in-range repetitions))
    (+ sum (.call E .uint<- target))))

(def (main)
  ;; Loading, Enum construction, and warmup are outside the runtime interval.
  (lookup-sum warmup-repetitions)
  (##gc)
  (def started (cpu-time))
  (def result (lookup-sum measured-repetitions))
  (def runtime-cpu-seconds (- (cpu-time) started))

  ;; Correctness stays outside the measured interval.
  (unless (= result (* target measured-repetitions))
    (error "Enum lookup benchmark produced an invalid result"))
  (displayln
   "ENUM_LOOKUP_RUNTIME_RECEIPT="
   [variants: 64
    target-index: target
    warmup-repetitions: warmup-repetitions
    measured-repetitions: measured-repetitions
    runtime-cpu-seconds: runtime-cpu-seconds]))
