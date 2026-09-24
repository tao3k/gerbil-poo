(export main)

(import
  :gerbil/runtime/gambit
  :std/format
  :std/iter
  ../object)

(def cold-repetitions 500)
(def clone-repetitions 5000)

(def (slots-of width)
  (for/collect (index (in-range width))
    (cons (string->symbol (format "slot-%d" index)) index)))

(def (make-chain slots depth)
  (def parent
    (for/fold (parent #f) (_ (in-range (1- depth)))
      (if parent (.mix parent) (object<-alist []))))
  (object<-alist slots supers: (if parent [parent] [])))

(def (cold-read slots depth target repetitions)
  (for/fold (sum 0) (_ (in-range repetitions))
    (+ sum (.ref (make-chain slots depth) target))))

(def (clone-only source repetitions)
  (for/fold (last #f) (_ (in-range repetitions))
    (.cc source 'slot-0 -1 'added -2)))

(def (clone-and-read source target repetitions)
  (for/fold (sum 0) (_ (in-range repetitions))
    (+ sum (.ref (.cc source 'slot-0 -1 'added -2) target))))

(def (measure thunk)
  (##gc)
  (def start (cpu-time))
  (def result (thunk))
  (values result (- (cpu-time) start)))

(def (run-case width depth)
  (def slots (slots-of width))
  (def target (string->symbol (format "slot-%d" (1- width))))
  (def source (make-chain slots depth))
  (.ref source target)
  (cold-read slots depth target 10)
  (clone-only source 10)
  (clone-and-read source target 10)

  (defvalues (cold-sum cold-seconds)
    (measure (lambda () (cold-read slots depth target cold-repetitions))))
  (defvalues (last-clone clone-seconds)
    (measure (lambda () (clone-only source clone-repetitions))))
  (defvalues (clone-sum clone-read-seconds)
    (measure (lambda () (clone-and-read source target clone-repetitions))))

  (unless (= cold-sum (* cold-repetitions (1- width)))
    (error "cold object read returned an invalid result" width depth))
  (unless (and (= (.ref last-clone 'slot-0) -1)
               (= (.ref last-clone 'added) -2)
               (= clone-sum (* clone-repetitions (1- width))))
    (error "object clone returned an invalid result" width depth))
  (displayln "POO_OBJECT_SCALE_RUNTIME_RECEIPT="
             [slots: width depth: depth
              cold-repetitions: cold-repetitions
              clone-repetitions: clone-repetitions
              cold-construct-and-read-cpu-seconds: cold-seconds
              clone-only-cpu-seconds: clone-seconds
              clone-and-read-cpu-seconds: clone-read-seconds]))

(def (main)
  (for (width [8 64 256])
    (for (depth [1 8 32])
      (run-case width depth))))
