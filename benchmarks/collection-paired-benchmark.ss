;;; Matched full/reused fold transport, with fixed prefixes, AB/BA and A/A controls.
(export main run-slot-index-study run-values-study run-offset-study run-shape-study run-shape-revision-study run-map-study run-names-study run-chain-study run-traversal-study run-composition-study run-catalog-study run-declaration-study run-cold-query-study run-dependency-study)
(import :std/iter
        (only-in :clan/poo/benchmarks/prototype-map-benchmark
          +slot-index-phases+ slot-index-workload +slot-value-phases+ slot-values-workload
          +traversal-phases+ traversal-workload +catalog-phases+ catalog-workload
          +declaration-phases+ declaration-workload declaration-preparation-workload
          layout-admission-workload dependency-workload shape-workload)
        "collection-paired-slots.ss"
        "collection-paired-order.ss"
        "collection-paired-backends.ss"
        (only-in "closure-measure.ss" measure measure-pair median mean))

;; One inventory drives diagnostic setup and the full measured suite.
(def +backend-phases+
  '(backend-rational-prepare backend-rational-cold backend-rational-observe backend-rational-equality
    backend-rational-workflow backend-rational-retry
    backend-trie-prepare backend-trie-cold backend-trie-observe backend-trie-equality
    backend-trie-workflow backend-trie-retry
    backend-trie-shape-cold backend-trie-shape-workflow backend-trie-shape-retry))

;; Ordered diagnostics retain the existing complete publication and ownership phases.
(def +order-phases+
  '(order-factory order-prepare order-cold order-seek order-range order-diff order-stage
    order-owner order-workflow order-publication))

;; Cold preparation, lazy evaluation and switched/tracked hot access all remain
;; visible. The module phase measures a standard cached load, not a fresh import.
;; One finite inventory serves complete acceptance and focused timing.
(def +slot-offset-phases+ '(slot-offset-prepare slot-offset-hot slot-offset-switch
  slot-offset-churn slot-offset-workflow))
(def +slot-phases+ (append +slot-value-phases+ '(slot-prepare slot-cold slot-hot slot-switch slot-tracked slot-revision slot-load-workflow
    slot-seeding-prepare slot-seeding-workflow slot-seeding-all
    slot-shape-prepare slot-shape-grow slot-shape-workflow slot-shape-change slot-shape-prune slot-shape-retire slot-shape-batch slot-shape-batch-workflow
    slot-cycle-report slot-cycle-workflow slot-layout-admission slot-dependencies-new slot-dependencies-hot slot-dependencies-workflow
    slot-dependencies-capture slot-dependencies-check slot-dependencies-register) +slot-offset-phases+))

;; Raw signed allocation remains visible. Only GC-free, nonnegative samples have
;; an attributable allocation value; GC CPU is reported separately from core CPU.
(def (allocation metrics)
  (and (= (vector-ref metrics 3) 0) (>= (vector-ref metrics 4) 0) (vector-ref metrics 4)))

;; Gambit history fields: cumulative collections/allocation, then the last GC's
;; wall time, heap size and live bytes. Interval fields are GC wall/minor/major
;; faults, followed by the independent monotonic duration. Slot 9 is statistics-structure overhead, never a live-heap estimate.
(def (measurement-history before after elapsed)
  ;; Keep cumulative history separate from this observation's interval deltas.
  (def (prefix stats)
    (vector (f64vector-ref stats 6) (f64vector-ref stats 7)
      (f64vector-ref stats 14) (f64vector-ref stats 15) (f64vector-ref stats 17)))
  (vector (prefix before) (prefix after)
    (- (f64vector-ref after 5) (f64vector-ref before 5))
    (- (f64vector-ref after 10) (f64vector-ref before 10))
    (- (f64vector-ref after 11) (f64vector-ref before 11)) elapsed))

;; Capture the same bounded observation protocol for a batch, forced collection,
;; or first post-GC call. The diagnostic charges preparation instead of hiding it.
(def (measure-collection-action action repetitions regime)
  ;; The observer allocates only after the measured interval has ended.
  (def (capture thunk count)
    (def history #f)
    (defvalues (ok metrics) (measure thunk count #f
      (lambda (before after elapsed) (set! history (measurement-history before after elapsed)))))
    (unless ok (error "collection measured oracle"))
    (vector metrics history))
  (def preparation (and (eq? regime 'post-gc)
    (capture (lambda () (##gc) #t) 1)))
  (def first (and preparation (capture action 1)))
  (when (eq? regime 'collected) (##gc))
  (vector (capture action repetitions) first preparation))

;; Describe every retained pair, including loss count and empirical upper tail.
;; A small sample quantile is diagnostic, never a future latency guarantee.
(def (report-collection-tail label differences)
  (def ordered (list-sort < differences))
  (def n (length ordered))
  (displayln "COLLECTION-TAIL " label " n=" n
    " wins=" (length (filter negative? differences))
    " losses=" (length (filter positive? differences))
    " mean-us=" (mean differences)
    " p90-us=" (list-ref ordered (- (quotient (+ (* 9 n) 9) 10) 1))
    " min=" (car ordered) " max=" (list-ref ordered (- n 1))))

;; Every regime uses fresh matched fixtures per pair and the same fixed prefix.
;; A/A and B/B retain both prefix histories and alternate measurement slots. The
;; candidate control distinguishes its own noise from the slower reference's noise.
;; No natural-regime GC is forced.
;; Full observations go to stdout, never a versioned data file or archive.
(def (run-collection-study width count rounds (phases #f))
  (def n (string->number width)) (def repetitions (string->number count))
  (def pairs (string->number rounds))
  (unless (and (exact-integer? n) (<= 2 n 1024) (exact-integer? repetitions) (<= 1 repetitions 100)
               (exact-integer? pairs) (<= 4 pairs 12) (even? pairs))
    (error "invalid bounded collection study"))
  (displayln "COLLECTION-CLOCKS wall=system-realtime history-last=runtime-monotonic")
  (displayln "COLLECTION-RUNTIME gerbil=" (gerbil-version-string) " gambit=" (system-version-string))
  (let (startup (##process-statistics))
    (displayln "COLLECTION-STARTUP cpu=" (+ (f64vector-ref startup 0) (f64vector-ref startup 1))
      " wall=" (f64vector-ref startup 2) " gc-cpu=" (+ (f64vector-ref startup 3) (f64vector-ref startup 4))
      " gc-wall=" (f64vector-ref startup 5) " history=" (measurement-history startup startup 0.0)))
  (order-shape-work n #f)
  (order-shape-work n #t)
  (displayln "COLLECTION-BACKEND-COLUMNS #(carrier-ap carrier-unap key-ap key-unap value-ap value-unap read write fold)")
  (for (scenario +backend-phases+)
    (representation-work n scenario))
  (displayln "COLLECTION-PAIRED size=" n " count=" repetitions " rounds=" pairs " prefix=2")
  (displayln "COLLECTION-SLOT-BASELINES symbolic-ref/current-inline module-load=cached")
  (displayln "COLLECTION-SEEDING constructor=seeded/demand workflows=same-current-storage")
  (displayln "COLLECTION-SLOT-CHAINS baseline=opaque-computed candidate=explicit-override both=current-engine")
  (for* ((scenario (or phases (append +backend-phases+ '(factory cold hit revision workflow retry) +order-phases+ +slot-phases+ +map-phases+ +names-phases+ +chain-phases+ +traversal-phases+ +catalog-phases+ +declaration-phases+))) (regime (if (or (eq? scenario 'slot-index-update) (memq scenario '(backend-rational-workflow backend-rational-retry backend-trie-workflow backend-trie-retry backend-trie-shape-workflow backend-trie-shape-retry order-diff order-stage order-owner order-workflow order-publication slot-cycle-report slot-cycle-workflow slot-layout-admission slot-dependencies-new slot-dependencies-hot slot-dependencies-workflow slot-values-newshape slot-values-cold slot-values-workflow slot-values-retry slot-values-observation slot-values-seed slot-values-grow slot-values-guard slot-values-redemand slot-cold slot-revision slot-load-workflow slot-shape-grow slot-shape-change slot-shape-prune slot-shape-retire slot-shape-batch slot-shape-batch-workflow slot-offset-workflow map-remove-workflow map-remove-cold names-cold names-workflow chain-single chain-cold chain-workflow map-compose map-compose-single map-compose-workflow c3-hot c3-workflow catalog-empty catalog-single catalog-cold catalog-clone catalog-workflow declaration-construction declaration-empty declaration-single declaration-cold declaration-workflow declaration-workflow-shared declaration-directory declaration-directory-shared declaration-visibility declaration-visibility-mixed declaration-private-filter)))
      '(natural collected post-gc) '(natural collected))) (control? '(#f #t candidate)))
    (def observations [])
    (for (round (in-range (if control? 4 pairs)))
      (def setup-history #f)
      (defvalues (actions setup-metrics)
        (measure (lambda () (call-with-values
          (cond
            ((memq scenario +backend-phases+)
             (cut representation-workload n scenario))
            ((memq scenario +order-phases+)
             (cut order-workload n scenario))
            ((memq scenario +slot-offset-phases+)
             (cut offset-workload n scenario))
            ((memq scenario +map-phases+)
             (cut map-workload n scenario))
            ((memq scenario +names-phases+)
             (cut names-workload n scenario))
            ((memq scenario +chain-phases+)
             (cut chain-workload n scenario))
            ((memq scenario '(declaration-directory declaration-directory-shared declaration-visibility declaration-visibility-mixed declaration-private-filter))
             (cut declaration-preparation-workload n scenario))
            ((memq scenario +declaration-phases+)
             (cut declaration-workload n scenario))
            ((memq scenario +catalog-phases+)
             (cut catalog-workload n scenario))
            ((memq scenario +traversal-phases+)
             (cut traversal-workload n scenario))
            ((memq scenario '(slot-seeding-prepare slot-seeding-workflow slot-seeding-all))
             (cut seeding-workload n scenario))
            ((memq scenario '(slot-shape-prepare slot-shape-grow slot-shape-workflow slot-shape-change slot-shape-prune slot-shape-retire slot-shape-batch slot-shape-batch-workflow))
             (cut shape-workload n scenario))
            ((memq scenario +slot-index-phases+) (cut slot-index-workload n scenario))
            ((memq scenario +slot-value-phases+) (cut slot-values-workload n scenario))
            ((eq? scenario 'slot-cycle-report) (cut cycle-report-workload n))
            ((eq? scenario 'slot-cycle-workflow) (cut cycle-workflow n))
            ((eq? scenario 'slot-layout-admission) (cut layout-admission-workload n))
            ((memq scenario '(slot-dependencies-new slot-dependencies-hot slot-dependencies-workflow slot-dependencies-capture slot-dependencies-check slot-dependencies-register))
              (cut dependency-workload n scenario))
            ((memq scenario +slot-phases+) (cut slot-workload n scenario))
            (else (cut workload n scenario))) vector)) 1 #f
          (lambda (before after elapsed) (set! setup-history (measurement-history before after elapsed)))))
      (def baseline (vector-ref actions 0))
      (def candidate (vector-ref actions 1))
      (displayln "COLLECTION-SETUP " (vector scenario regime control? round setup-metrics setup-history))
      (def order (if (even? round) '(baseline candidate) '(candidate baseline)))
      ;; Fixed-prefix execution is part of entry cost, not unexplained overhead.
      ;; Preserve both calls and order while measuring through the shared helper.
      (let ((history #f))
        (defvalues (_ metrics) (measure (lambda ()
          (for* ((_ (in-range 2)) (side order)) ((if (eq? side 'baseline) baseline candidate)))
          #t) 1 #f (lambda (before after elapsed) (set! history (measurement-history before after elapsed)))))
        (displayln "COLLECTION-PREFIX " (vector scenario regime control? round metrics history)))
      ;; Report after both sides, so serialization cannot perturb the second
      ;; sample's natural GC history. The whole entry still charges every write;
      ;; finally retains partial diagnostics on refusal and one flush per pair.
      (let ((results (measure-pair order
        (lambda (side)
          (def action (cond ((eq? control? 'candidate) candidate) ((or control? (eq? side 'baseline)) baseline) (else candidate)))
          (measure-collection-action action repetitions regime))
        (lambda (completed)
          (for (([side . measured] completed))
            (def batch (vector-ref measured 0))
            (def metrics (vector-ref batch 0))
            (def history (vector-ref batch 1))
            (when (eq? regime 'post-gc)
              (write (vector 'collection-preparation scenario control? round side
                (vector-ref measured 2) (vector-ref measured 1)))
              (newline))
            (write (vector 'collection-pair scenario regime control? round side metrics (allocation metrics) history))
            (newline))
          (force-output)))))
      ;; Read observations after both measured actions; internal definitions are
      ;; expanded ahead of expressions by Gerbil and must not snapshot results.
      (let ((a (cdr (assq 'baseline results))) (b (cdr (assq 'candidate results))))
        (set! observations (cons (vector (vector-ref (vector-ref a 0) 0) (vector-ref (vector-ref b 0) 0)
          (vector-ref (vector-ref a 0) 1) (vector-ref (vector-ref b 0) 1) a b) observations)))))
    ;; Positive signed differences mean regression; controls and ranges remain visible.
    (def (deltas index)
      (map (lambda (pair) (* (/ 1e6 repetitions)
        (- (vector-ref (vector-ref pair 1) index) (vector-ref (vector-ref pair 0) index)))) observations))
    ;; Signed residuals distinguish CPU work and GC wall from elapsed time; a
    ;; wall-minus-CPU difference is not automatically an OS scheduling diagnosis.
    (def (derived-deltas select)
      (map (lambda (pair) (* (/ 1e6 repetitions)
        (- (select (vector-ref pair 1) (vector-ref pair 3))
           (select (vector-ref pair 0) (vector-ref pair 2))))) observations))
    ;; Inclusive diagnostic cost charges one forced collection, the first call and
    ;; every batch call. This is a synthetic control, never the production policy.
    (when (eq? regime 'post-gc)
      (let (charged (map (lambda (pair)
        (def (wall side)
          (apply + (map (lambda (record) (vector-ref (vector-ref record 0) 1))
            (vector->list side))))
        (* (/ 1e6 (+ repetitions 1)) (- (wall (vector-ref pair 5)) (wall (vector-ref pair 4))))) observations))
        (displayln "COLLECTION-CHARGED " scenario "/" control?
          " wall-us=" (median charged) " min=" (apply min charged) " max=" (apply max charged))
        (report-collection-tail (list scenario 'inclusive control?) charged)
        ;; Means of disjoint components add to the inclusive mean; medians do not.
        (for (component '(0 1 2))
          (def (component-deltas select)
            (map (lambda (pair)
              (def (amount side)
                (select (vector-ref (vector-ref (vector-ref side component) 0) 0)
                        (vector-ref (vector-ref (vector-ref side component) 0) 1)
                        (vector-ref (vector-ref (vector-ref side component) 0) 2)))
              (* (/ 1e6 (+ repetitions 1))
                (- (amount (vector-ref pair 5)) (amount (vector-ref pair 4))))) observations))
          (displayln "COLLECTION-COMPONENT " (list scenario control? (list-ref '(batch first forced-gc) component))
            " wall-mean-us=" (mean (component-deltas (lambda (_cpu wall _gc) wall)))
            " non-gc-mean-us=" (mean (component-deltas (lambda (cpu _wall gc) (- cpu gc))))
            " gc-mean-us=" (mean (component-deltas (lambda (_cpu _wall gc) gc)))
            " residual-mean-us=" (mean (component-deltas (lambda (cpu wall _gc) (- wall cpu))))))))
    (let (wall (deltas 1))
      (report-collection-tail (list scenario regime control?) wall)
      (displayln "COLLECTION-SUMMARY " scenario "/" regime "/" (cond ((eq? control? 'candidate) 'bb) (control? 'aa) (else 'ab))
        " wall-us=" (median wall) " min=" (apply min wall) " max=" (apply max wall)
        " cpu-us=" (median (deltas 0)) " gc-us=" (median (deltas 2))
        " non-gc-cpu-us=" (median (derived-deltas (lambda (m _) (- (vector-ref m 0) (vector-ref m 2)))))
        " wall-minus-cpu-us=" (median (derived-deltas (lambda (m _) (- (vector-ref m 1) (vector-ref m 0)))))
        " gc-wall-us=" (median (derived-deltas (lambda (_ h) (vector-ref h 2)))))))
  #t)

;; Charge diagnostics, setup, prefixes, GC and output through the same clock.
;; Startup remains visible in process statistics and the outer command timer.
(def (report-study action label)
  (def history #f)
  (defvalues (ok metrics) (measure action 1 #f
    (lambda (before after elapsed) (set! history (measurement-history before after elapsed)))))
  (unless ok (error "collection entry oracle"))
  (displayln label "-ENTRY " (vector metrics history))
  (displayln label "-PAIRED-OK"))

;; Complete acceptance retains every phase, bound and paired control.
(def (main (width "64") (count "3") (rounds "6"))
  (report-study (cut run-collection-study width count rounds) "COLLECTION"))

;; Use the common timing engine and controls at a declared Slot width.
(def (run-slot-index-study width)
  (report-study (cut run-collection-study width "8" "6" +slot-index-phases+) "SLOT-INDEX")
  #t)

;; Higher-resolution timing runs all five offset phases using the same engine;
;; it never changes the complete acceptance inventory or its default entry.
(def (run-offset-study)
  (report-study (cut run-collection-study "32" "64" "6" +slot-offset-phases+) "SLOT-OFFSET")
  #t)

;; Reuse the complete pairing, setup, GC and tail machinery at a fixed workload.
(def (run-map-study)
  (report-study (cut run-collection-study "64" "16" "6" +map-phases+) "MAP-REMOVE")
  #t)

;; Fixed complete names matrix uses the existing clocks, controls and tail reports.
(def (run-names-study)
  (report-study (cut run-collection-study "64" "16" "6" +names-phases+) "NAMES")
  #t)

;; The standard paired runner retains every cold/hot/workflow and same-side control.
(def (run-chain-study)
  (report-study (cut run-collection-study "64" "16" "6" +chain-phases+) "CHAINS")
  #t)

;; Matched snapshot/direct controls use the ordinary fixed paired study entry.
(def (run-traversal-study)
  (report-study (cut run-collection-study "64" "16" "6" +traversal-phases+) "TRAVERSAL")
  #t)

;; Resolve the full-workflow uncertainty with more paired observations, retaining
;; all three regimes and both same-side controls rather than selecting good runs.
(def (run-composition-study)
  (report-study (cut run-collection-study "64" "32" "12" '(map-compose-workflow)) "COMPOSITION")
  #t)

;; Finite catalogs use the unchanged AB/BA, A/A, B/B and charged-GC study runner.
(def (run-catalog-study)
  (report-study (cut run-collection-study "64" "16" "6" +catalog-phases+) "CATALOG")
  #t)

;; All declaration-index phases retain the established controls, budgets and clocks.
(def (run-declaration-study)
  (report-study (cut run-collection-study "32" "16" "6" +declaration-phases+) "DECLARATION")
  #t)

;; Confirm the cold/full-workflow wall and tails with longer matched batches.
;; Keep the same safe scan oracle, all GC regimes and both same-side controls.
(def (run-cold-query-study)
  (report-study (cut run-collection-study "32" "32" "12" '(declaration-construction declaration-cold declaration-workflow)) "COLD-QUERY")
  #t)

;; Fixed full-workflow pairs retain AB/BA, A/A/B/B, charged GC and tail reports.
(def (run-values-study)
  (report-study (cut run-collection-study "16" "16" "6" +slot-value-phases+) "SLOT-VALUES")
  #t)

;; Hinted growth/narrowing and complete revision/refusal/recovery workflows
;; share the existing AB/BA, A/A/B/B, GC accounting and tail-reporting engine.
(def (run-shape-study)
  (report-study (cut run-collection-study "64" "32" "6"
    '(slot-shape-prepare slot-shape-grow slot-shape-workflow slot-shape-change slot-shape-prune slot-shape-retire slot-shape-batch slot-shape-batch-workflow)) "SHAPE")
  #t)

;; One standard paired entry charges setup, GC, first calls and same-side tails.
;; Boundary phases diagnose costs; only workflow pairs compare complete policies.
(def (run-dependency-study)
  (report-study (cut run-collection-study "2" "8" "12"
    '(slot-dependencies-new slot-dependencies-hot slot-dependencies-workflow
      slot-dependencies-capture slot-dependencies-check slot-dependencies-register)) "SLOT-DEPENDENCY")
  #t)

;; The existing engine charges setup, GC, first calls, AB/BA and A/A/B/B tails.
;; Batch preparation is diagnostic; the service phase includes complete factories.
(def (run-shape-revision-study)
  (report-study (cut run-collection-study "128" "4" "6"
    '(slot-shape-batch slot-shape-batch-workflow)) "SHAPE-REVISION")
  #t)
