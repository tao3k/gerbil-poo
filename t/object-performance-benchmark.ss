(export main)

(import
  :gerbil/runtime/gambit
  :std/format
  :std/iter
  :clan/poo/object)

(def slot-count 64)
(def hot-repetitions 1000000)
(def structural-repetitions 5000)
(def warmup-repetitions 100)
(def target-slot 'slot-63)

(def slots
  (for/collect (index (in-range slot-count))
    (cons (string->symbol (format "slot-%d" index)) index)))

(def base (object<-alist slots))

(def (hot-lookup repetitions object)
  (for/fold (sum 0) (_ (in-range repetitions))
    (+ sum (.ref object target-slot))))

(def (cold-lookup repetitions)
  (for/fold (sum 0) (_ (in-range repetitions))
    (+ sum (.ref (object<-alist slots) target-slot))))

(def (collect-inherited-slots repetitions)
  (for/fold (count 0) (_ (in-range repetitions))
    (+ count (length (.all-slots (object<-alist [] supers: [base]))))))

(def (clone-objects repetitions)
  (for/fold (result #f) (_ (in-range repetitions))
    (.cc base slot-0: 100 slot-7: 107 slot-15: 115 slot-31: 131
              slot-47: 147 slot-63: 163 added-0: 200 added-1: 201)))

(def (measure-runtime thunk)
  (def started (cpu-time))
  (def result (thunk))
  (values result (- (cpu-time) started)))

(def (main)
  ;; Construct and instantiate the shared object before every runtime interval.
  (.ref base target-slot)
  (hot-lookup warmup-repetitions base)
  (cold-lookup warmup-repetitions)
  (collect-inherited-slots warmup-repetitions)
  (clone-objects warmup-repetitions)

  (##gc)
  (defvalues (hot-result hot-lookup-runtime-cpu-seconds)
    (measure-runtime (lambda () (hot-lookup hot-repetitions base))))
  (##gc)
  (defvalues (cold-result cold-lookup-runtime-cpu-seconds)
    (measure-runtime (lambda () (cold-lookup structural-repetitions))))
  (##gc)
  (defvalues (all-slots-result all-slots-runtime-cpu-seconds)
    (measure-runtime
     (lambda () (collect-inherited-slots structural-repetitions))))
  (##gc)
  (defvalues (clone-result clone-runtime-cpu-seconds)
    (measure-runtime (lambda () (clone-objects structural-repetitions))))

  ;; Correctness checks stay outside the measured intervals.
  (unless (= hot-result (* 63 hot-repetitions))
    (error "hot POO lookup produced an invalid result"))
  (unless (= cold-result (* 63 structural-repetitions))
    (error "cold POO lookup produced an invalid result"))
  (unless (= all-slots-result (* slot-count structural-repetitions))
    (error "POO all-slots produced an invalid result"))
  (unless (= (.ref clone-result 'slot-63) 163)
    (error "POO clone lost an override"))
  (unless (= (.ref clone-result 'added-1) 201)
    (error "POO clone lost an added slot"))
  (displayln
   "POO_OBJECT_AOT_RUNTIME_RECEIPT="
   [slots: slot-count
    hot-repetitions: hot-repetitions
    structural-repetitions: structural-repetitions
    hot-lookup-runtime-cpu-seconds: hot-lookup-runtime-cpu-seconds
    cold-lookup-runtime-cpu-seconds: cold-lookup-runtime-cpu-seconds
    all-slots-runtime-cpu-seconds: all-slots-runtime-cpu-seconds
    clone-runtime-cpu-seconds: clone-runtime-cpu-seconds]))
