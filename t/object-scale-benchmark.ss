(export main)

(import
  :gerbil/runtime/gambit
  :std/format
  :std/iter
  ../object ../prototype-map
  (prefix-in "closure-measure.ss" sample.))

;; Complete cold construction/read operations per observed sample.
(def cold-repetitions 500)
;; Complete persistent-clone operations per observed sample.
(def clone-repetitions 5000)

;; Predeclare constant SlotSpecs once, matching the public prototype recipe API.
;; Both policies time factory construction from these identical existing recipes.
(def (slots-of width)
  (for/collect (index (in-range width))
    (cons (string->symbol (format "slot-%d" index)) ($constant-slot-spec index))))

;; Include every inherited layer in cold factory cost, including empty metadata.
(def (make-chain slots depth policy)
  (def parent
    (for/fold (parent #f) (_ (in-range (1- depth)))
      (make-object slots: (prototype-map [] policy: policy) defaults: (prototype-map [] policy: policy) supers: (if parent [parent] []))))
  (make-object slots: (prototype-map slots policy: policy) defaults: (prototype-map [] policy: policy) supers: (if parent [parent] [])))

;; Force the same final field on each fresh hierarchy; sum is the result oracle.
(def (cold-read slots depth target repetitions policy)
  (for/fold (sum 0) (_ (in-range repetitions))
    (+ sum (.ref (make-chain slots depth policy) target))))

;; Measure persistent override plus insertion and retain the final clone.
(def (clone-only source repetitions)
  (for/fold (last #f) (_ (in-range repetitions))
    (.cc source 'slot-0 -1 'added -2)))

;; Include binding and first field demand after each persistent revision.
(def (clone-and-read source target repetitions)
  (for/fold (sum 0) (_ (in-range repetitions))
    (+ sum (.ref (.cc source 'slot-0 -1 'added -2) target))))

;; Include factory construction AND the first override/insertion before reading.
;; This prevents deferred promotion/preparation from hiding outside measured work.
(def (cold-clone-read slots depth target repetitions policy)
  (for/fold (sum 0) (_ (in-range repetitions))
    (+ sum (.ref (.cc (make-chain slots depth policy) 'slot-0 -1 'added -2) target))))

;; Retain complete CPU/wall/GC/allocation observations under both GC regimes.
;; The shared sampler times the same complete workload; no result is discarded.
(def (measure thunk collected?)
  (sample.measure thunk 1 collected?))

;; Warm each complete workload equally before measuring the retained snapshot.
(def (run-case width depth collected? policy)
  (def slots (slots-of width))
  (def target (string->symbol (format "slot-%d" (1- width))))
  (def source (make-chain slots depth policy))
  (.ref source target)
  (cold-read slots depth target 10 policy)
  (cold-clone-read slots depth target 10 policy)
  (clone-only source 10)
  (clone-and-read source target 10)

  (defvalues (cold-sum cold-seconds)
    (measure (lambda () (cold-read slots depth target cold-repetitions policy)) collected?))
  (defvalues (cold-clone-sum cold-clone-seconds)
    (measure (lambda () (cold-clone-read slots depth target cold-repetitions policy)) collected?))
  (defvalues (last-clone clone-seconds)
    (measure (lambda () (clone-only source clone-repetitions)) collected?))
  (defvalues (clone-sum clone-read-seconds)
    (measure (lambda () (clone-and-read source target clone-repetitions)) collected?))

  (unless (= cold-sum (* cold-repetitions (1- width)))
    (error "cold object read returned an invalid result" width depth))
  (unless (and (= cold-clone-sum (* cold-repetitions (if (= width 1) -1 (1- width))))
               (= (.ref last-clone 'slot-0) -1)
               (= (.ref last-clone 'added) -2)
               (= clone-sum (* clone-repetitions (if (= width 1) -1 (1- width)))))
    (error "object clone returned an invalid result" width depth))
  (displayln "POO_OBJECT_SCALE_RUNTIME_RECEIPT="
             [slots: width depth: depth
              cold-repetitions: cold-repetitions
              clone-repetitions: clone-repetitions
              policy: policy
              regime: (if collected? 'collected 'natural)
              metric-order: '(cpu wall gc-cpu collections allocated-bytes)
              cold-construct-and-read: cold-seconds
              cold-construct-clone-and-read: cold-clone-seconds
              clone-only: clone-seconds
              clone-and-read: clone-read-seconds]))

;; Compare both current policies in one standard executable, using ABBA process order.
;; Existing widths/depths remain; boundary widths exercise compact/tree transitions.
(def (main (regime "natural") (policy-name "tree"))
  (unless (member regime '("natural" "collected")) (error "unknown GC regime" regime))
  (unless (member policy-name '("tree" "compact")) (error "unknown storage policy" policy-name))
  (for (width [1 4 8 9 16 64 256])
    (for (depth [1 8 32])
      (run-case width depth (equal? regime "collected") (string->symbol policy-name)))))
