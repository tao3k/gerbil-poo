;;; Fresh-process factory/publication phases; no approval or result is cached.
(export main compare)
(import :clan/poo/object
        :clan/poo/mop
        :clan/poo/prototype-types
        (runtime: :clan/poo/declarative-metadata)
        (prefix-in (only-in :clan/poo/declarative-metadata bind-evidence contract predicate
                   truth) metadata.)
        (runtime: :clan/poo/examples/polymorphic-services)
        (prefix-in (only-in :clan/poo/examples/polymorphic-services DescriptorServiceType
                   SignatureServiceType catalog-service-action
                   descriptor-service-action infer-descriptor-service
                   infer-signature-service signature-service-declarations) service.)
        :std/iter
        "closure-benchmark-support.ss")
;; Both installed implementations initialize the same semantic cases and prefix.
;; Artifact roots select baseline/candidate externally; the workload is identical.
(def (workload scenario)
  (def context (.o approved: #t))
  (def bytes (make-u8vector 32 7))
  (def byte-calls '((() (Bytes) ((BytesN 32) (Function ((BytesN 32)) (Bytes))))))
  ;; A real optional/keyword/rest target returns a recursively checked callback.
  (def (rich-target value (bonus value) scale: (scale 1) . rest)
    (values (abs (* scale (+ value bonus (apply + rest)))) abs))
  ;; Keep callback identity common while factories still compile fresh descriptors.
  (def target (if (eq? scenario 'bytes) (lambda (value) (values value identity)) rich-target))
  ;; Ground construction isolates descriptor compilation/binding from inference.
  (def schema (specialize-prototype-type
    (if (eq? scenario 'bytes) service.DescriptorServiceType service.SignatureServiceType)
    (if (eq? scenario 'bytes) '(Bytes) '(UInt))))
  (def arguments (if (eq? scenario 'bytes) '((BytesN 32)) '(Integer)))
  ;; Leaf Types/caches stay in their usual library state; complete factories are fresh.
  (def (factory)
    (if (eq? scenario 'bytes)
      (.get (service.infer-descriptor-service '(Bytes) '((BytesN 16) (BytesN 32)) byte-calls
              target) instance)
      (.get (service.infer-signature-service service.SignatureServiceType '(UInt) '(Integer UInt)
              '((Integer Super)) target) instance)))
  (def instance (factory))
  ;; Prepare the entire refinement/publication action without invoking its method.
  (def (action selected)
    (if (eq? scenario 'bytes)
      (service.descriptor-service-action selected bytes context void)
      (service.catalog-service-action selected -7 context void)))
  (def prepared (action instance))
  ;; Evidence and state identity are semantic oracles inside every measured call.
  (def (invoke program)
    (defvalues (evidence next issue) (program context))
    (unless (and (not issue) (eq? next context) (eq? (.get evidence context) context)
                 (if (eq? scenario 'bytes) (eq? (.get evidence subject answer) bytes)
                   (= (.get evidence subject answer) 14)))
      (error "factory/publication measurement oracle"))
    #t)
  (def subject (.o)) (def descriptor (.o))
  (def invocation (metadata.contract (metadata.predicate "in" object?)
    (metadata.predicate "out" object?) (lambda _ #t) metadata.truth))
  (list (lambda () (factory))
        (lambda () (action instance))
        (lambda () (invoke prepared))
        (lambda () (invoke (action (factory))))
        (lambda () (metadata.bind-evidence invocation subject descriptor context identity))
        (lambda () (service.signature-service-declarations instance target void))
        (lambda () (instantiate-prototype schema arguments))))
;; run-child retains current raw signed allocation and common fixed warmups.
;; Collected and natural regimes separate a cleared heap from optimization history.
(def (main scenario regime phase (count "100"))
  (def selected (string->symbol scenario))
  (unless (memq selected '(bytes rich)) (error "unknown factory case"))
  (run-child selected (string->symbol regime) (string->number phase)
    (workload selected) (string->number count) 2))

;; Compare isolated released-compiler libraries in fresh bounded processes.
;; AB/BA alternation and baseline A/A controls use the same fixed semantic prefix;
;; every phase includes all seven prefix controls before measuring only that phase.
;; Full local receipts retain adverse samples and signed unavailable allocation.
(def (compare baseline candidate baseline-source timeout output (count "100") (phases '(0 1 2 3 4 5 6)))
  ;; Longer fixed horizons run one phase per bounded study, retaining the full
  ;; case/regime/ABBA/AA matrix across shards without extending any deadline.
  (def repetitions (string->number count))
  (unless (and (exact-integer? repetitions) (<= 1 repetitions 1000)
    (or (equal? phases '(0 1 2 3 4 5 6))
      (and (list? phases) (= (length phases) 1) (memq (car phases) '(0 1 2 3 4 5 6)))))
    (error "invalid fixed factory horizon or phase"))
  (def expected (* 4 (length phases) 9))
  (def sources '("prototype-types.ss" "method-declaration.ss" "declarative-metadata.ss" "examples/polymorphic-services.ss"))
  (def current (source-digests (append sources '("benchmarks/factory-paired-benchmark.ss" "benchmarks/closure-measure.ss"))))
  (def original (source-digests sources baseline-source))
  (def binaries (source-digests (list baseline candidate)))
  (def rows [])
  (call-with-output-file (list path: output truncate: #t)
    (lambda (port)
      ;; Flush each completed observation so interruption never resembles completion.
      (def (emit datum) (write datum port) (newline port) (force-output port))
      (emit `(factory-paired (candidate ,candidate) (baseline ,baseline)
        (binaries ,binaries) (sources ,current) (original ,original) (rounds 6) (controls 3)
        (warmups 2) (repetitions ,repetitions) (phases ,phases) (deadline 20) (heap "1G")))
      (for* ((scenario '(bytes rich)) (regime '(natural collected)) (phase phases)
             (control? '(#f #t)) (round (in-range (if control? 3 6))))
        (def pair [])
        (for (side (if (odd? round) '(candidate baseline) '(baseline candidate)))
          (def binary (if (or control? (eq? side 'baseline)) baseline candidate))
          (defvalues (status stdout) (run-bounded timeout
            (list binary "-:max-heap=1G,debug=q" (symbol->string scenario)
              (symbol->string regime) (number->string phase) count)))
          (unless (= status 0) (emit `(failed ,scenario ,regime ,phase ,round ,side ,status ,stdout))
            (error "factory child failed" status))
          (def datum (call-with-input-string stdout read-one))
          (unless (and (vector? datum) (= (vector-length datum) 7)
                       (eq? (vector-ref datum 0) scenario) (eq? (vector-ref datum 1) regime)
                       (= (vector-ref datum 2) phase) (= (vector-ref datum 3) repetitions))
            (error "factory child identity" datum))
          (def metrics (vector-ref datum 4))
          (def raw (vector-ref datum 5))
          (unless (and (vector? metrics) (= (vector-length metrics) 5)
            (andmap (lambda (value) (and (real? value) (<= 0 value) (< value +inf.0)))
              (map (cut vector-ref metrics <>) '(0 1 2 3)))
            (exact-integer? (vector-ref metrics 3)) (exact-integer? raw)
            (equal? (vector-ref metrics 4) (and (= (vector-ref metrics 3) 0) (>= raw 0) raw)))
            (error "factory child metrics" datum))
          (emit (vector scenario regime phase control? round side datum))
          (set! pair (cons (cons side datum) pair)))
        (set! rows (cons (vector scenario regime phase control? pair) rows))
        (displayln "FACTORY-PAIR " scenario "/" regime "/" phase
          " " (if control? 'aa 'ab) " round=" round) (force-output))
      (check-sources! current) (check-sources! original baseline-source)
      (check-sources! binaries)
      (unless (= (length rows) expected) (error "incomplete factory study"))
      (emit `(complete ,(* 2 expected)))))
  (for* ((scenario '(bytes rich)) (regime '(natural collected)) (phase phases) (control? '(#f #t)))
    (def selected (filter (lambda (row) (and (eq? scenario (vector-ref row 0))
      (eq? regime (vector-ref row 1)) (= phase (vector-ref row 2)) (eq? control? (vector-ref row 3)))) rows))
    ;; Subtract matched processes before summarizing; residual excludes measured GC CPU.
    (def (deltas metric)
      (map (lambda (row)
        (def pair (vector-ref row 4))
        ;; Normalize one selected child metric to microseconds per complete operation.
        (def (value side)
          (def metrics (vector-ref (cdr (assq side pair)) 4))
          (* (/ 1e6 repetitions) (if (eq? metric 'core) (- (vector-ref metrics 0) (vector-ref metrics 2))
            (vector-ref metrics metric))))
        (- (value 'candidate) (value 'baseline))) selected))
    (def cpu (deltas 0))
    (displayln "FACTORY-SUMMARY " scenario "/" regime "/" phase " " (if control? 'aa 'ab)
      " cpu-delta-us=" (median cpu) " core-delta-us=" (median (deltas 'core))
      " gc-delta-us=" (median (deltas 2)) " min=" (apply min cpu) " max=" (apply max cpu)))
  (displayln "FACTORY-PAIRED-OK children=" (* 2 expected)))
