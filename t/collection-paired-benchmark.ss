;;; Matched full/reused fold transport, with fixed prefixes, AB/BA and A/A controls.
(export main)
(import :std/iter ../object ../mop ../number ../type ../table ../rationaldict
        (only-in ../support/base number-comparer) ../support/option (only-in ../fun Wrapper.) (only-in ../trie SimpleTrie Trie.) (only-in ../fun IdWrap)
        (only-in "closure-measure.ss" measure median))

;; Every variant consumes the same admitted source, delta and exact sum oracle.
;; Factory setup is measured in cold; other phases retain their declared setup.
(def (workload size scenario)
  (def source (.cc (RationalDict Integer) Key: UInt))
  (def target (SimpleTrie UInt Integer))
  (def failure (list 'conversion-refused))
  (def refuse? #f)
  (def replacement 1000000)
  (def keys (.cc Wrapper. Domain: UInt Codomain: UInt
    .ap: (cut bitwise-xor <> 1) .unap: (cut bitwise-xor <> 1)))
  (def payloads (.cc Wrapper. Domain: Integer Codomain: Integer
    .ap: (lambda (v) (when (and refuse? (= v replacement)) (raise failure)) (- v)) .unap: -))
  ;; Both source and target contributions implement the same exact pullback.
  (def (score k v) (+ (* 2 k) v))
  (def (target-score k v) (score (bitwise-xor k 1) (- v)))
  (def source-fold (table-fold source Integer score))
  (def base (.call source .<-list (for/collect (k (in-range 1 (+ size 1))) (cons k k))))
  (def original (.call source-fold .ap base))
  (def total (/ (* 3 size (+ size 1)) 2))
  (def next-total (+ total (- replacement 1)))
  (def mapping (table-isomorphism source target keys payloads))
  (def target-fold (table-fold target Integer target-score))
  (def mapped (.call mapping .ap base))
  (def bstate original)
  (def btarget (.call target-fold .ap mapped))
  (def bridge (.call source-fold .isomorphism target keys payloads))
  (def cstate original)
  (def ctarget (.call bridge .ap original))
  (def derived (.@ bridge Codomain))
  (def delta (.call source .diff base (.call source .acons 1 replacement base)))
  ;; Oracles run inside each measured complete operation, never only its setup.
  (def (consume folding state expected)
    (unless (= (.call folding .get state) expected) (error "collection fold oracle")) #t)
  ;; The prior path updates source, maps both snapshots, then updates target's fold.
  (def (baseline-update edit)
    (def before (.call source-fold .unap bstate))
    (def next (.call source-fold .apply-delta bstate edit))
    (def staged (.call (.@ mapping Delta) .ap (cons before edit)))
    (def changed (.call target-fold .apply-delta btarget (cdr staged)))
    (consume source-fold next next-total) (consume target-fold changed next-total)
    (set! bstate (.call source-fold .apply-delta next (invert-table-delta edit)))
    (set! btarget (.call target-fold .apply-delta changed (invert-table-delta (cdr staged))))
    (consume source-fold bstate total) (consume target-fold btarget total))
  ;; Reused transport updates source once, writes mapped edits, and retains totals.
  (def (candidate-update edit)
    (def changed (.call bridge .apply-delta cstate edit))
    (def next (.call bridge .unap changed))
    (consume source-fold next next-total) (consume derived changed next-total)
    (set! ctarget (.call bridge .apply-delta next (invert-table-delta edit)))
    (set! cstate (.call bridge .unap ctarget))
    (consume source-fold cstate total) (consume derived ctarget total))
  ;; Failure is expected, preserves its identity, and precedes an identical retry.
  (def (retry action)
    (set! refuse? #t)
    (let (cause (try (action delta) #f (catch (cause) cause)))
      (unless (eq? cause failure) (error "collection retry oracle" cause)))
    (set! refuse? #f)
    (action delta))
  (case scenario
    ;; Factory isolates checked metadata/closure construction from any snapshot.
    ((factory)
      (values
        (lambda ()
          (def m (table-isomorphism source target keys payloads))
          (def f (table-fold target Integer target-score))
          (unless (and (eq? (.@ m Domain) source) (eq? (.@ f Value) Integer))
            (error "baseline factory oracle")) #t)
        (lambda ()
          (def m (.call source-fold .isomorphism target keys payloads))
          (unless (and (eq? (.@ m Domain) source-fold) (eq? (.@ (.@ m Codomain) Value) Integer))
            (error "derived factory oracle")) #t)))
    ((cold)
      (values
        (lambda ()
          (def m (table-isomorphism source target keys payloads))
          (def f (table-fold target Integer target-score))
          (consume f (.call f .ap (.call m .ap base)) total))
        (lambda ()
          (def m (.call source-fold .isomorphism target keys payloads))
          (consume (.@ m Codomain) (.call m .ap original) total))))
    ((hit)
      (values (lambda () (consume target-fold (.call target-fold .ap (.call mapping .ap base)) total))
        (lambda () (consume derived (.call bridge .ap cstate) total))))
    ((revision) (values (cut baseline-update delta) (cut candidate-update delta)))
    ((workflow)
      (values
        (lambda ()
          (def before (.call source-fold .unap bstate))
          (baseline-update (.call source .diff before (.call source .acons 1 replacement before))))
        (lambda ()
          (def before (.call source-fold .unap cstate))
          (candidate-update (.call source .diff before (.call source .acons 1 replacement before))))))
    ((retry) (values (cut retry baseline-update) (cut retry candidate-update)))
    (else (error "unknown collection phase" scenario))))

;; Matched ordered-index workload: both sides keep the same source, projections,
;; admission and ownership work. Cold/workflow compare full successor validation
;; with shape-preserving output reuse, using identical positioned comparers. Seek/range
;; retain the separate positioned-versus-sorted comparison.
;; Cold includes factories/caches; workflow includes diff, install, ownership and undo.
(def (order-workload size scenario)
  (def source (SimpleTrie UInt UInt))
  ;; Both descriptors use the same backend/order; only output-admission reuse differs.
  (def backend (.cc (.mix Trie. IdWrap) Key: UInt Value: UInt .shape-preserving?: #t))
  (def reference-backend (.cc (.mix Trie. IdWrap) Key: UInt Value: UInt .shape-preserving?: #f))
  (def base (.call source .<-list (for/collect (k (in-range size)) (cons k k))))
  (def lower (max 0 (- size 4)))
  (def expected (for/collect (k (in-range lower size)) (cons k k)))
  (def preparation? (memq scenario '(order-factory order-prepare order-cold order-workflow)))
  ;; Preparation compares only admission reuse. Query-only phases separately force
  ;; the sorting reference with an extensionally equal but distinct procedure.
  (def (factory optimized?)
    (def compare (if optimized? number-comparer (lambda (a b) (number-comparer a b))))
    (def ordered (table-order
      (if (or optimized? (not preparation?)) backend reference-backend)
      (table-comparer UInt (if preparation? number-comparer compare))))
    (table-indexes source (list (.cc Type. name: 'value table: ordered unique?: #t
      project: (lambda (_ row) row)))))
  ;; Validate actual results inside every timed complete operation.
  (def (consume indexed state rows)
    (unless (equal? (.call indexed .index-range state 'value (some lower) (some (1- size))) rows)
      (error "ordered collection range oracle")) #t)
  ;; Each side owns its prepared state and style, sharing only immutable input rows.
  (def (action optimized?)
    (def indexed (factory optimized?))
    (def state (.call indexed .wrap base))
    (def linear (.@ (table-styles indexed) Linear))
    (case scenario
      ((order-factory) (lambda ()
        (unless (.has? (factory optimized?) .index-range) (error "ordered factory oracle")) #t))
      ((order-prepare) (lambda ()
        (unless (eq? (.call indexed .unwrap (.call indexed .wrap base)) base)
          (error "ordered preparation identity oracle")) #t))
      ((order-cold) (lambda ()
        (def fresh (factory optimized?))
        (consume fresh (.call fresh .wrap base) expected)))
      ((order-seek)
        (let (ordered (table-order source (table-comparer UInt
          (if optimized? number-comparer (lambda (a b) (number-comparer a b))))))
          (lambda ()
            (unless (equal? (.call ordered .seek base (some lower)) (some (cons lower lower)))
              (error "ordered collection seek oracle")) #t)))
      ((order-range) (lambda () (consume indexed state expected)))
      ((order-workflow) (lambda ()
        (def after (.call source .acons lower (+ size 1) base))
        (def delta (.call source .diff base after))
        (def next (.call linear .apply-delta (.call linear .ap state) delta))
        (def pure (.call linear .convert next 'pure))
        (consume indexed pure (cdr expected))
        (consume indexed (.call indexed .apply-delta pure (invert-table-delta delta)) expected)))
      (else (error "unknown ordered collection phase" scenario))))
  (values (action #f) (action #t)))


;; Attribute work outside every timed interval. The instrumented backend counts
;; full-shape traversal separately from lookup/update traversal and projection work;
;; dynamic-wind restores the diagnostic scope even if shape recognition refuses.
(def (order-shape-work size preserves?)
  (def visits 0) (def shape-visits 0) (def shape-calls 0) (def projections 0)
  (def checking? #f)
  (def source (SimpleTrie UInt UInt))
  (def raw (.cc (.mix Trie. IdWrap) Key: UInt Value: UInt
    .unwrap: (lambda (tree)
      (set! visits (+ visits 1))
      (when checking? (set! shape-visits (+ shape-visits 1))) tree)))
  (def backend (.cc raw .shape-preserving?: preserves?
    .validate-shape: (lambda (tree)
      (set! shape-calls (+ shape-calls 1))
      (dynamic-wind (lambda () (set! checking? #t))
        (lambda () (.call raw .validate-shape tree))
        (lambda () (set! checking? #f))))))
  (def ordered (table-order backend (.@ backend Comparer)))
  (def indexed (table-indexes source (list (.cc Type. name: 'value table: ordered unique?: #t
    project: (lambda (_ row) (set! projections (+ projections 1)) row)))))
  (def base (.call source .<-list (for/collect (key (in-range size)) (cons key key))))
  (set! visits 0) (set! shape-visits 0) (set! shape-calls 0) (set! projections 0)
  (.call indexed .wrap base)
  (displayln "COLLECTION-SHAPE-WORK " (vector size preserves? visits shape-visits shape-calls projections)))

;; Raw signed allocation remains visible. Only GC-free, nonnegative samples have
;; an attributable allocation value; GC CPU is reported separately from core CPU.
(def (allocation metrics)
  (and (= (vector-ref metrics 3) 0) (>= (vector-ref metrics 4) 0) (vector-ref metrics 4)))

;; Gambit history fields: cumulative collections/allocation, then the last GC's
;; wall time, heap size and live bytes. Interval fields are GC wall/minor/major
;; faults. Slot 9 is statistics-structure overhead, never a live-heap estimate.
(def (measurement-history before after)
  ;; Keep cumulative history separate from this observation's interval deltas.
  (def (prefix stats)
    (vector (f64vector-ref stats 6) (f64vector-ref stats 7)
      (f64vector-ref stats 14) (f64vector-ref stats 15) (f64vector-ref stats 17)))
  (vector (prefix before) (prefix after)
    (- (f64vector-ref after 5) (f64vector-ref before 5))
    (- (f64vector-ref after 10) (f64vector-ref before 10))
    (- (f64vector-ref after 11) (f64vector-ref before 11))))

;; Both regimes use fresh matched fixtures per pair and the same fixed prefix.
;; A/A and B/B retain both prefix histories and alternate measurement slots. The
;; candidate control distinguishes its own noise from the slower reference's noise.
;; No natural-regime GC is forced.
;; Full observations go to stdout, never a versioned data file or archive.
(def (main (width "64") (count "3") (rounds "6"))
  (def n (string->number width)) (def repetitions (string->number count))
  (def pairs (string->number rounds))
  (unless (and (exact-integer? n) (<= 2 n 1024) (exact-integer? repetitions) (<= 1 repetitions 100)
               (exact-integer? pairs) (<= 4 pairs 12) (even? pairs))
    (error "invalid bounded collection study"))
  (displayln "COLLECTION-RUNTIME gerbil=" (gerbil-version-string) " gambit=" (system-version-string))
  (let (startup (##process-statistics))
    (displayln "COLLECTION-STARTUP cpu=" (+ (f64vector-ref startup 0) (f64vector-ref startup 1))
      " wall=" (f64vector-ref startup 2) " gc-cpu=" (+ (f64vector-ref startup 3) (f64vector-ref startup 4))
      " gc-wall=" (f64vector-ref startup 5) " history=" (measurement-history startup startup)))
  (order-shape-work n #f)
  (order-shape-work n #t)
  (displayln "COLLECTION-PAIRED size=" n " count=" repetitions " rounds=" pairs " prefix=2")
  (for* ((scenario '(factory cold hit revision workflow retry order-factory order-prepare order-cold order-seek order-range order-workflow)) (regime '(natural collected)) (control? '(#f #t candidate)))
    (def observations [])
    (for (round (in-range (if control? 4 pairs)))
      (def setup-history #f)
      (defvalues (actions setup-metrics)
        (measure (lambda () (call-with-values
          (if (memq scenario '(order-factory order-prepare order-cold order-seek order-range order-workflow))
            (cut order-workload n scenario) (cut workload n scenario)) vector)) 1 #f
          (lambda (before after) (set! setup-history (measurement-history before after)))))
      (def baseline (vector-ref actions 0))
      (def candidate (vector-ref actions 1))
      (displayln "COLLECTION-SETUP " (vector scenario regime control? round setup-metrics setup-history))
      (def order (if (even? round) '(baseline candidate) '(candidate baseline)))
      (for* ((_ (in-range 2)) (side order)) ((if (eq? side 'baseline) baseline candidate)))
      (def results [])
      (for (side order)
        (def action (cond ((eq? control? 'candidate) candidate) ((or control? (eq? side 'baseline)) baseline) (else candidate)))
        (def history #f)
        (defvalues (ok metrics) (measure action repetitions (eq? regime 'collected)
          (lambda (before after) (set! history (measurement-history before after)))))
        (unless ok (error "collection measured oracle"))
        (write (vector 'collection-pair scenario regime control? round side metrics (allocation metrics) history))
        (newline) (force-output)
        (set! results (cons (cons side metrics) results)))
      ;; Read observations after both measured actions; internal definitions are
      ;; expanded ahead of expressions by Gerbil and must not snapshot results.
      (let ((a (cdr (assq 'baseline results))) (b (cdr (assq 'candidate results))))
        (set! observations (cons (vector a b) observations))))
    ;; Positive signed differences mean regression; controls and ranges remain visible.
    (def (deltas index)
      (map (lambda (pair) (* (/ 1e6 repetitions)
        (- (vector-ref (vector-ref pair 1) index) (vector-ref (vector-ref pair 0) index)))) observations))
    (let (wall (deltas 1))
      (displayln "COLLECTION-SUMMARY " scenario "/" regime "/" (cond ((eq? control? 'candidate) 'bb) (control? 'aa) (else 'ab))
        " wall-us=" (median wall) " min=" (apply min wall) " max=" (apply max wall)
        " cpu-us=" (median (deltas 0)) " gc-us=" (median (deltas 2)))))
  (displayln "COLLECTION-PAIRED-OK"))
