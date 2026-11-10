(export main point-index-study)

(import
  :gerbil/runtime/gambit
  :std/format
  :std/iter
  :clan/poo/object :clan/poo/prototype-map
  (prefix-in "closure-measure.ss" sample.))

;; Complete cold construction/read operations per observed sample.
(def cold-repetitions 500)
;; Complete persistent-clone operations per observed sample.
(def clone-repetitions 5000)

;; Isolate the source index primitive before receiver binding. Setup is charged
;; once; neither arm constructs/evaluates a receiver. Both consume the SAME
;; immutable source, preserve duplicate order and allocate the same result.
;; These measurements cannot establish first Module EVAL or source certification.
(def (point-index-study)
  (for (size '(10000 100000))
    (defvalues (source setup)
      (sample.measure (lambda ()
        (prototype-map
          (append (list (cons 'selected 1))
            (for/collect (i (in-range size)) (cons (make-symbol "point-spare-" i) i))
            (list (cons 'selected 2) (cons 'selected 3))) policy: 'tree)) 1))
    (def (reference)
      (def result [])
      (prototype-map-for-each source (lambda (key payload)
        (when (eq? key 'selected) (set! result (cons payload result)))))
      result)
    (def (indexed) (prototype-map-fold-key source 'selected cons []))
    (def (checked action)
      (unless (equal? (action) '(3 2 1)) (error "point index duplicate order" size)) #t)
    (displayln "POO_POINT_INDEX_SETUP="
      [unrelated: size contributions: (+ size 3) setup: (sample.qualified-metrics setup)])
    ;; The first sample is one request, then a fixed batch of 64. Preserve all
    ;; AB/BA observations, natural GC and exact denominator in the receipt.
    (for (repetitions '(1 64))
      (def observations [])
      (for (side '(reference indexed indexed reference))
        (def action (if (eq? side 'reference) reference indexed))
        (defvalues (_result timing) (sample.measure (cut checked action) repetitions))
        (set! observations (cons [side: side metrics: (sample.qualified-metrics timing)
          raw-allocation-delta: (vector-ref timing 4)] observations)))
      (displayln "POO_POINT_INDEX_PAIR="
        [unrelated: size repetitions: repetitions order: '(reference indexed indexed reference)
         regime: 'natural observations: (reverse observations)]))
    ;; Work diagnostics follow ALL timing: they must not prewarm either arm's
    ;; first selected query. Every indexed ordinal still pays an RBTree lookup.
    (def enumerated 0) (def selected 0)
    (prototype-map-for-each source (lambda (_key _payload) (set! enumerated (1+ enumerated))))
    (prototype-map-fold-key source 'selected
      (lambda (_payload state) (set! selected (1+ selected)) state) #f)
    (unless (and (= enumerated (+ size 3)) (= selected 3))
      (error "point index work accounting" size enumerated selected))
    (displayln "POO_POINT_INDEX_WORK="
      [unrelated: size enumerated: enumerated selected-contributions: selected]))
  #t)

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
              cold-construct-and-read: (sample.qualified-metrics cold-seconds)
              cold-construct-clone-and-read: (sample.qualified-metrics cold-clone-seconds)
              clone-only: (sample.qualified-metrics clone-seconds)
              clone-and-read: (sample.qualified-metrics clone-read-seconds)
              raw-allocation-deltas: (map (cut vector-ref <> 4)
                [cold-seconds cold-clone-seconds clone-seconds clone-read-seconds])]))

;; Compare both current policies in one standard executable, using ABBA process order.
;; Existing widths/depths remain; boundary widths exercise compact/tree transitions.
(def (main (regime "natural") (policy-name "tree")
           (width-name "all") (depth-name "all"))
  (unless (member regime '("natural" "collected")) (error "unknown GC regime" regime))
  (unless (member policy-name '("tree" "compact")) (error "unknown storage policy" policy-name))
  ;; Select a maintained shape for matched producer comparisons. The default
  ;; retains every original shape and all complete construction/clone phases.
  (def (dimensions name allowed)
    (if (equal? name "all") allowed
      (let (value (string->number name))
        (unless (member value allowed) (error "unknown object shape" name allowed))
        [value])))
  (def widths (dimensions width-name [1 4 8 9 16 64 256]))
  (def depths (dimensions depth-name [1 8 32]))
  (for (width widths)
    (for (depth depths)
      (run-case width depth (equal? regime "collected") (string->symbol policy-name)))))
