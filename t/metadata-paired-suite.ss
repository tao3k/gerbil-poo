;;; Adjacent fresh-process controls, ABBA side order, complete lossless receipts.
(export main read-study check-study report expected-order)
(import :gerbil/runtime/gambit :std/iter (only-in :std/list/list-builder with-list-builder) "closure-benchmark-support.ss"
        (prefix-in "metadata-paired-cases.ss" study.))
;; Enumerate complete deterministic study keys: scenario/regime/round/pair/side.
;; Rotate pair positions by round; validation uses the same exact coverage/order.
(def (expected-order)
  (with-list-builder (add)
    (for* ((scenario study.scenarios) (regime study.regimes) (round (in-range study.rounds))
           (pair-position (in-range (length study.pairs))) (position '(0 1)))
      (add (list scenario regime round (modulo (+ round pair-position) (length study.pairs)) position)))))
;; Admit finite real metrics only; comparisons also reject NaN and infinities.
(def (finite? value) (and (real? value) (< -inf.0 value +inf.0)))
;; Validate dimensions, source/binary identity, exact pair coverage/order, side
;; meaning, repetitions, finite metrics and allocation admission. Raise on stale,
;; incomplete or malformed input; valid unavailable allocation is not a gain.
;; Return the original rows only after the complete receipt passes every guard.
(def (check-study header rows complete)
  ;; Read one required header field; missing identities/limits must reject admission.
  (def (field key) (cdr (or (assq key (cdr header)) (error "missing paired field" key))))
  (unless (and (pair? header) (eq? (car header) 'metadata-paired)
               (equal? (field 'scenarios) study.scenarios) (equal? (field 'regimes) study.regimes)
               (equal? (field 'strategies) study.strategies) (equal? (field 'pairs) study.pairs)
               (equal? (field 'rounds) (list study.rounds)) (equal? (field 'warmups) (list study.warmups))
               (equal? (field 'prefix) '(all-controls-in-fixed-order fresh-process-per-side))
               (equal? (field 'deadline) '(20)) (equal? (field 'heap) '("1G"))
               (equal? (field 'sources) (source-digests study.sources))
               (= (length (field 'binary)) 1)
               (equal? (field 'binary) (source-digests (map car (field 'binary))))
               (equal? complete (list 'complete (length (expected-order)))))
    (error "incomplete/stale paired study"))
  (unless (equal? (map (lambda (row)
    (unless (and (vector? row) (= (vector-length row) 6)) (error "invalid paired row"))
    (for/collect (index (in-range 5)) (vector-ref row index))) rows) (expected-order))
    (error "missing/duplicate/reordered pair"))
  (for (row rows)
    (def scenario (vector-ref row 0)) (def regime (vector-ref row 1))
    (def round (vector-ref row 2)) (def pair (list-ref study.pairs (vector-ref row 3)))
    (def position (vector-ref row 4)) (def datum (vector-ref row 5))
    (unless (and (vector? datum) (= (vector-length datum) 7)
                 (eq? (vector-ref datum 0) scenario) (eq? (vector-ref datum 1) regime)
                 (= (vector-ref datum 2) (list-ref (study.side-order round pair) position))
                 (= (vector-ref datum 3) (study.repetitions scenario))) (error "wrong paired child"))
    (def metrics (vector-ref datum 4)) (def raw (vector-ref datum 5)) (def prefix (vector-ref datum 6))
    (unless (and (vector? metrics) (= (vector-length metrics) 5) (exact-integer? raw)
                 (vector? prefix) (= (vector-length prefix) 3)
                 (andmap finite? (vector->list prefix)) (>= (vector-ref prefix 0) 0)
                 (andmap (lambda (n) (and (finite? n) (>= n 0)))
                         (for/collect (index (in-range 4)) (vector-ref metrics index)))
                 (exact-integer? (vector-ref metrics 3))
                 (equal? (vector-ref metrics 4) (and (= (vector-ref metrics 3) 0) (>= raw 0) raw)))
      (error "invalid paired metrics/allocation")))
  rows)
;; Read a complete native S-expression receipt and validate it against current
;; source/binary identities. Require one completion marker and EOF; failures and
;; trailing material are refused, never silently summarized as valid results.
(def (read-study path)
  (call-with-input-file path
    (lambda (port)
      (def header (read port))
      (let loop ((rows []))
        (def datum (read port))
        (cond ((vector? datum) (loop (cons datum rows)))
              ((and (pair? datum) (eq? (car datum) 'complete) (eof-object? (read port)))
               (values header (check-study header (reverse rows) datum)))
              (else (error "failed/incomplete/extra paired data" datum)))))))
;; Summarize already validated rows using per-operation side medians and medians
;; of within-pair CPU/GC/residual deltas. Compute subtraction before median; these
;; independent median columns need not add. Prefix GC-count matches are diagnostic
;; only and do not establish identical allocation history or heap contents.
(def (report rows)
  (def indices (for/collect (round (in-range study.rounds)) round))
  (for* ((scenario study.scenarios) (regime study.regimes) (pair-index (in-range (length study.pairs))))
    (def pair (list-ref study.pairs pair-index))
    (def samples (filter (lambda (row) (and (eq? (vector-ref row 0) scenario)
      (eq? (vector-ref row 1) regime) (= (vector-ref row 3) pair-index))) rows))
    ;; Find this side within its exact adjacent pair, never a sample from another pair.
    (def (sample round side)
      (vector-ref (car (filter (lambda (row) (and (= (vector-ref row 2) round) (= (vector-ref (vector-ref row 5) 2) side))) samples)) 5))
    ;; Normalize one metric by its fixed operation count before comparing processes.
    (def (per-op datum index) (/ (vector-ref (vector-ref datum 4) index) (vector-ref datum 3)))
    ;; Summarize this side only; do not substitute its marginal median for a paired delta.
    (def (med side index) (median (map (lambda (round) (per-op (sample round side) index)) indices)))
    ;; Subtract the directly matched sides in every round before taking the median.
    (def (delta index)
      (median (map (lambda (round) (- (per-op (sample round (cadr pair)) index)
                                      (per-op (sample round (car pair)) index))) indices)))
    ;; Preserve spread and direction across actual pairs, including adverse samples.
    ;; CPU and GC medians are separate summaries and cannot be added together.
    (def differences (map (lambda (round)
      (* 1e6 (- (per-op (sample round (cadr pair)) 0) (per-op (sample round (car pair)) 0)))) indices))
    ;; Only pair byte counts admitted independently on BOTH collection-free sides.
    ;; This is allocated work, not retained heap, and unavailable samples stay #f.
    (def byte-differences (filter identity (map (lambda (round)
      (and (vector-ref (vector-ref (sample round (car pair)) 4) 4)
           (vector-ref (vector-ref (sample round (cadr pair)) 4) 4)
           (- (per-op (sample round (cadr pair)) 4) (per-op (sample round (car pair)) 4)))) indices)))
    (displayln scenario "/" regime " " (map (cut list-ref study.strategies <>) pair)
      " cpu-us=" (* 1e6 (med (car pair) 0)) "/" (* 1e6 (med (cadr pair) 0))
      " paired-delta-us=" (* 1e6 (delta 0)) " paired-gc-delta-us=" (* 1e6 (delta 2))
      " paired-core-delta-us=" (* 1e6 (median (map (lambda (round)
        (- (- (per-op (sample round (cadr pair)) 0) (per-op (sample round (cadr pair)) 2))
           (- (per-op (sample round (car pair)) 0) (per-op (sample round (car pair)) 2)))) indices)))
      " paired-min-us=" (apply min differences) " paired-max-us=" (apply max differences)
      " faster-pairs=" (length (filter (cut < <> 0) differences))
      " gc-excess-pairs=" (length (filter (lambda (round)
        (> (per-op (sample round (cadr pair)) 3) (per-op (sample round (car pair)) 3))) indices))
      " allocation-pairs=" (length (filter (lambda (round)
        (and (vector-ref (vector-ref (sample round (car pair)) 4) 4)
             (vector-ref (vector-ref (sample round (cadr pair)) 4) 4))) indices))
      " paired-bytes-delta=" (and (pair? byte-differences) (median byte-differences))
      " prefix-full-mismatch=" (length (filter (lambda (round)
        (not (equal? (vector-ref (sample round (car pair)) 6)
                     (vector-ref (sample round (cadr pair)) 6)))) indices))
      " prefix-gc-mismatch=" (length (filter (lambda (round)
        (not (= (vector-ref (vector-ref (sample round (car pair)) 6) 0)
                (vector-ref (vector-ref (sample round (cadr pair)) 6) 0)))) indices)))))
;; Run adjacent fresh native children with bounded process execution. timeout is
;; the timeout executable path, not a duration; the fixed child limit is 20s/1GiB.
;; Stream every raw row/failure locally, recheck identities and complete coverage,
;; then report. Any child/oracle/identity failure aborts without a success receipt.
(def (main binary timeout output)
  (def identities (source-digests study.sources))
  (def binaries (source-digests (list binary)))
  (call-with-output-file (list path: output truncate: #t)
    (lambda (port)
      ;; Flush each complete record so an interrupted child leaves an incomplete receipt.
      (def (emit value) (write value port) (newline port) (force-output port))
      (emit `(metadata-paired (scenarios ,@study.scenarios) (regimes ,@study.regimes)
        (strategies ,@study.strategies) (pairs ,@study.pairs) (rounds ,study.rounds) (warmups ,study.warmups)
        (prefix all-controls-in-fixed-order fresh-process-per-side)
        (sources ,@identities) (binary ,@binaries) (deadline 20) (heap "1G")
        (columns scenario regime round pair position child)
        (child scenario regime side repetitions metrics raw-allocation prefix)
        (metrics cpu wall gc-cpu collections bytes-or-false) (prefix-metrics collections allocation-counter post-gc-counter)
        (toolchain ,(gerbil-version-string) ,(system-version-string))))
      (for (key (expected-order))
        (match key ([scenario regime round pair-index position]
          (def side (list-ref (study.side-order round (list-ref study.pairs pair-index)) position))
          (try
            (defvalues (status stdout) (run-bounded timeout (list binary "-:max-heap=1G"
              (symbol->string scenario) (symbol->string regime) (number->string side))))
            (unless (= status 0) (error "paired child failed" status stdout))
            (def datum (call-with-input-string stdout read-one))
            (emit (list->vector (append key (list datum))))
            (catch (cause) (emit `(failed ,key ,(object->string cause))) (raise cause))))))
      (check-sources! identities)
      (unless (equal? binaries (source-digests (list binary))) (error "paired binary changed"))
      (emit `(complete ,(length (expected-order))))))
  (defvalues (_ rows) (read-study output))
  (report rows)
  (displayln "METADATA-PAIRED-OK children=" (length rows)))
