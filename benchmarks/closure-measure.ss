;;; Gambit's own process statistics, as used by its time form. Data only IO.
(export run-child measure measure-pair read-datum write-datum source-digests median mean monotonic-seconds monotonic-ticks monotonic-frequency)
(import :gerbil/runtime/gambit :std/iter :std/misc/ports :std/crypto/digest :std/encoding/hex)
;; Use the released runtime clock, without replacing process-statistics wall
;; time. mach_absolute_time and system time can disagree across suspension or
;; clock correction; neither disagreement is attributed to workload execution.
(def monotonic-frequency
  (let (clock (make-u64vector 1 0))
    (##get-monotonic-time-frequency! clock 0)
    (let (frequency (u64vector-ref clock 0))
      (unless (> frequency 0) (error "unsupported monotonic clock"))
      (exact->inexact frequency))))
;; Stream observers reuse one scratch cell and the SAME clock as paired timing.
;; Exact hardware ticks are independent of child CPU or GC accounting.
(def (monotonic-ticks (clock (make-u64vector 1 0)))
  (##get-monotonic-time! clock 0)
  (u64vector-ref clock 0))
;; Convert the same exact clock sample for existing seconds-based studies.
(def (monotonic-seconds (clock (make-u64vector 1 0)))
  (/ (monotonic-ticks clock) monotonic-frequency))
;; Result columns stay CPU, wall, GC CPU, collections, allocated bytes.
;; The optional observer receives raw snapshots and an independent monotonic
;; duration after timing. Its scratch storage is prepared before the boundary;
;; diagnostics never force natural-regime GC or replace the original wall field.
(def (measure thunk repetitions (collect? #f) (observe #f))
  (def clock (and observe (make-u64vector 2 0)))
  (when collect? (##gc))
  (let (before (##process-statistics))
    (when clock (##get-monotonic-time! clock 0))
    (let (result (for/fold (last #f) (_ (in-range repetitions)) (thunk)))
      (when clock (##get-monotonic-time! clock 1))
      (let (after (##process-statistics))
        (unless (= (f64vector-length after) 20) (error "unsupported Gambit statistics layout"))
        (def (delta index) (- (f64vector-ref after index) (f64vector-ref before index)))
        (def metrics (vector (+ (delta 0) (delta 1)) (delta 2) (+ (delta 3) (delta 4))
          (inexact->exact (delta 6)) (inexact->exact (- (delta 7) (f64vector-ref after 9)))))
        (when observe (observe before after
          (/ (- (u64vector-ref clock 1) (u64vector-ref clock 0)) monotonic-frequency)))
        (values result metrics)))))

;; Complete the ordered pair before reporting, keeping formatting/flush allocation
;; outside the gap between samples. On refusal report every completed sample once
;; before propagating the original cause, provided report succeeds. Reporting
;; failures are fatal too; report must not mutate actions.
;; A reporter may expose partial progress but never re-executes a sample.
(def (measure-pair order sample report)
  (def results [])
  (try
    (for (side order) (set! results (cons (cons side (sample side)) results)))
    (finally (report (reverse results))))
  results)

(def (read-datum path)
  (call-with-input-file path
    (lambda (port)
      (def datum (read port))
      (unless (eof-object? (read port)) (error "extra benchmark data" path))
      datum)))
(def (write-datum path datum)
  (call-with-output-file (list path: path truncate: #t)
    (lambda (port)
      ;; Machine-readable fields occur once; each observation stays on one line.
      (if (list? datum)
        (begin
          (display "(" port)
          (for ((field datum) (index (in-range (length datum))))
            (when (> index 0) (newline port))
            (if (and (pair? field) (eq? (car field) 'rows))
              (begin (display "(rows" port)
                (for (row (cdr field)) (newline port) (write row port))
                (display ")" port))
              (write field port)))
          (display ")" port))
        (write datum port))
      (newline port))))
(def (source-digests paths (root "."))
  (map (lambda (path) (cons path (hex-encode (sha256 (call-with-input-file
                  (path-expand path (string-append root "/")) read-all-as-u8vector))))) paths))
(def (median values)
  (unless (pair? values) (error "empty median"))
  (def sorted (list-sort < values))
  (def middle (quotient (length sorted) 2))
  (if (odd? (length sorted)) (list-ref sorted middle)
      (/ (+ (list-ref sorted (1- middle)) (list-ref sorted middle)) 2)))
(def (mean values) (/ (apply + values) (length values)))

;; Shared fixed-prefix native measurement, parameterized by semantic workload only.
;; Both metadata and recursive studies retain identical signed allocation/GC rules.
(def (run-child scenario regime side actions count warmups)
  (for* ((_ (in-range warmups)) (action actions)) (unless (action) (error "paired prefix oracle")))
  (when (eq? regime 'collected) (##gc))
  (def prefix (##process-statistics))
  (unless (= (f64vector-length prefix) 20) (error "unsupported statistics"))
  (defvalues (ok metrics) (measure (list-ref actions side) count))
  (unless ok (error "paired measured oracle"))
  (def raw (vector-ref metrics 4))
  (unless (and (= (vector-ref metrics 3) 0) (>= raw 0)) (vector-set! metrics 4 #f))
  (write (vector scenario regime side count metrics raw
    (vector (f64vector-ref prefix 6) (f64vector-ref prefix 7) (f64vector-ref prefix 9))))
  (newline))
