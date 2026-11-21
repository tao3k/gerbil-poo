;;; Rational dictionary and trie representation workloads.
(export representation-workload representation-work)
(import :std/iter :clan/poo/object
        :clan/poo/mop :clan/poo/number :clan/poo/type :clan/poo/table :clan/poo/rationaldict
        :clan/poo/support/option
        (only-in :clan/poo/fun Wrapper.)
        (only-in :clan/poo/trie SimpleTrie))

;; Gerbil's host carrier retains the persistent backend and shared Function leaves.
(defstruct representation-snapshot (tree) transparent: #t final: #t)

;; Compare a source backend with its explicit derived representation. Both routes
;; include their own fresh protocol preparation in cold, capture/install/undo in
;; workflow, and conflict/refusal plus explicit retry in retry. Warm sides share
;; only the admitted source fixture; cold creates fresh protocols. The raw source
;; is a cost reference, not a replacement for guards.
(def (representation-workload size scenario (counts #f))
  (def callback (Fun Integer <- Integer))
  (def raw-value (Tuple Integer callback))
  (def cooked-value (Pair callback Integer))
  (def checked (validate callback (lambda (x) (+ x 1))))
  (def trie? (string-prefix? "backend-trie-" (symbol->string scenario)))
  (def shape? (memq scenario '(backend-trie-shape-cold backend-trie-shape-workflow backend-trie-shape-retry)))
  ;; Diagnostic counters run separately from timed observations. Backend reads,
  ;; writes and folds are distinct from carrier, key and payload conversions.
  (def (observe index f)
    (if counts (lambda args
      (vector-set! counts index (+ 1 (vector-ref counts index))) (apply f args)) f))
  ;; Fresh receivers have independent metadata and normal standard-library storage.
  (def (make-source (preserves? #t))
    (def backend (if trie? (SimpleTrie UInt raw-value) (.cc (RationalDict raw-value) Key: UInt)))
    ;; Both diagnostic sides own equivalent protocols, differing only in the
    ;; existing explicit law. No GC-regime switch enters the library.
    (def source (if shape? (.cc backend .shape-preserving?: preserves?) backend))
    (.cc source
      .ref: (observe 6 (.@ source .ref)) .acons: (observe 7 (.@ source .acons))
      .foldl: (observe 8 (.@ source .foldl))))
  (def source (make-source))
  (def rows (for/collect (k (in-range size)) (cons k (vector k checked))))
  (def base (.call source .<-list rows))
  (def replacement (vector (+ size 10) checked))
  ;; Construct the complete generated protocol; callbacks preserve Function identity.
  (def (derive source)
    (def raw (.cc Type. Key: UInt Value: cooked-value .element?: representation-snapshot?))
    (def carrier (.cc Wrapper. Domain: source Codomain: raw
      .ap: (observe 0 make-representation-snapshot) .unap: (observe 1 representation-snapshot-tree)))
    (def keys (.cc Wrapper. Domain: UInt Codomain: UInt
      .ap: (observe 2 (cut bitwise-xor <> 1)) .unap: (observe 3 (cut bitwise-xor <> 1))))
    (def payloads (.cc Wrapper. Domain: raw-value Codomain: cooked-value
      .ap: (observe 4 (lambda (v) (cons (vector-ref v 1) (vector-ref v 0))))
      .unap: (observe 5 (lambda (v) (vector (cdr v) (car v))))))
    (table-wrapper source carrier keys payloads))
  ;; Both routes observe all rows, the exact total, callback identity and behavior.
  ;; This full observation is charged, rather than replaced with a last-key probe.
  (def (consume table snapshot derived? total)
    (def seen 0)
    (def sum (.call table .foldl (lambda (k v acc)
      (def f (if derived? (car v) (vector-ref v 1)))
      (def source-key (if derived? (bitwise-xor k 1) k))
      (def amount (if derived? (cdr v) (vector-ref v 0)))
      (unless (and (<= 0 source-key) (< source-key size)
                   (= amount (if (= source-key 0)
                     (- total (quotient (* size (- size 1)) 2)) source-key)))
        (error "backend binding oracle" k amount))
      (unless (and (eq? f checked) (= (f 7) 8)) (error "backend Function oracle"))
      (set! seen (+ seen 1)) (+ acc amount)) 0 snapshot))
    (unless (and (= seen size) (= sum total)) (error "backend total oracle" seen sum total)) #t)
  (def total (quotient (* size (- size 1)) 2))
  ;; The same captured callback runs once; installation never reruns it. A stale
  ;; snapshot must fail before successful retry and inverse restoration.
  (def (publish table initial derived? retry?)
    (def key (if derived? 1 0))
    (def value (if derived? (cons checked (+ size 10)) replacement))
    (def calls 0)
    (def current initial)
    (def delta (.call table .delta/opt key (lambda (_) (set! calls (+ calls 1)) (some value)) current))
    (when retry?
      (set! current (.call table .acons key (if derived? (cons checked -1) (vector -1 checked)) initial))
      (unless (try (.call table .apply-delta current delta) #f (catch (e) (table-conflict? e)))
        (error "backend conflict oracle"))
      (set! delta (.call table .delta/opt key (lambda (_) (set! calls (+ calls 1)) (some value)) current)))
    (def next (.call table .apply-delta current delta))
    (consume table next derived? (+ total size 10))
    (unless (= calls (if retry? 2 1)) (error "backend capture oracle" calls))
    (consume table (.call table .apply-delta next (invert-table-delta delta)) derived? (if retry? (- total 1) total)))
  (def cold? (string-suffix? "-cold" (symbol->string scenario)))
  (def retry? (string-suffix? "-retry" (symbol->string scenario)))
  ;; Setup is common and recorded separately; only cold constructs within timing.
  (def generated (derive source))
  (def target (.call generated .wrap base))
  ;; Independent same-process reference keeps every derived inverse/Function
  ;; check; disabling the declaration restores output-shape admission.
  (def reference (and shape? (derive (make-source #f))))
  (def reference-target (and reference (.call reference .wrap base)))
  ;; Structural equality is measured directly on fresh, equal/unequal Tuple/Pair
  ;; fixtures. This is an independent control, not a subtraction-based attribution
  ;; of equality CPU inside the full workflow. No conversion occurs in this slice.
  (def (equality-fixture derived?)
    (for/collect (k (in-range size))
      (if derived?
        (vector (cons checked k) (cons checked k) (cons checked (+ k 1)))
        (vector (vector k checked) (vector k checked) (vector (+ k 1) checked)))))
  ;; Slice selection occurs during reported setup; complete publication still
  ;; retains all metadata, conversion, equality, callback and inverse work.
  (def (action derived?)
    (cond
      ((string-suffix? "-prepare" (symbol->string scenario))
        (lambda ()
          (unless (.has? (if derived? (derive (make-source)) (make-source)) .apply-delta)
            (error "backend preparation oracle")) #t))
      ((string-suffix? "-observe" (symbol->string scenario))
        (if derived? (cut consume generated target #t total) (cut consume source base #f total)))
      ((string-suffix? "-equality" (symbol->string scenario))
        (let (entries (equality-fixture derived?))
          (lambda ()
            (for (entry entries)
              (unless (and (equal? (vector-ref entry 0) (vector-ref entry 1))
                           (not (equal? (vector-ref entry 0) (vector-ref entry 2))))
                (error "backend equality oracle"))) #t)))
      ((or derived? shape?)
        (lambda ()
          (def selected-source (if cold? (make-source derived?) source))
          (def selected (if cold? (derive selected-source) (if derived? generated reference)))
          (publish selected
            (if cold? (.call selected .wrap (.call selected-source .<-list rows))
              (if derived? target reference-target)) #t retry?)))
      (else
        (lambda ()
          (def selected (if cold? (make-source) source))
          (publish selected (if cold? (.call selected .<-list rows) base) #f retry?)))))
  (values (action #f) (action #t)))

;; Keep attribution outside timing. Actual equality CPU is included in complete
;; wall/CPU samples; these counts are invocations, never unit-time assumptions.
(def (representation-work size scenario)
  (for (side '(0 1))
    (def counts (make-vector 9 0))
    (def actions (call-with-values (cut representation-workload size scenario counts) vector))
    ;; Retain setup work separately; removing apparently unused cold fixtures
    ;; changed subsequent cold-call tails in paired controls and was withdrawn.
    (displayln "COLLECTION-BACKEND-SETUP-WORK " (vector scenario side counts))
    (vector-fill! counts 0)
    ((vector-ref actions side))
    (displayln "COLLECTION-BACKEND-WORK " (vector scenario side counts))))
