;;; Matched warm controls: same process/plan, rotate first position each round.
(export main)
(import :gerbil/runtime/gambit :std/iter :std/encoding/json :std/crypto/digest
        :std/encoding/hex :std/misc/ports :std/misc/process :std/string/misc
        ../closure (only-in "closure-scale-benchmark.ss" workload))
(def (record . values)
  (let ((table (make-hash-table)))
    (let loop ((values values))
      (unless (null? values)
        (hash-put! table (car values) (cadr values)) (loop (cddr values)))) table))
(def (file-sha path)
  (hex-encode (sha256 (call-with-input-file path read-all-as-u8vector))))
(def (main family size-text width-text output)
  (let* ((size (string->number size-text)) (width (string->number width-text))
         (valid (unless (and (exact-integer? size) (> size 0) (exact-integer? width) (> width 0)
                              (member family '("diamond" "hubchain" "ring" "bursts" "dense")))
                  (error "paired workload parameters")))
         (source (workload family size width #t)) (plan (compile-closure source))
         (rows '()) (repetitions 200) (last #f)
         (sources (record))
         (receipt (record "schema" 1 "scope" "warm_same_process" "rounds" 8
                    "family" family "n" size "width" width "seed" "true"
                    "toolchain" (list (gerbil-version-string) (system-version-string))
                    "platform" (string-trim (run-process '("uname" "-srm")))
                    "source_sha256" sources)))
    (for (path '("closure.ss" "t/closure-scale-benchmark.ss" "t/closure-paired-benchmark.ss"))
      (hash-put! sources path (file-sha path)))
    ;; Each candidate gets a warm-up solve outside the timer; initial heap state
    ;; is shared. Rotation balances GC and cache order; neither is excluded.
    (for (queue '(append chunked hybrid auto)) (solve-closure plan queue))
    (for* ((round (in-range 8)) (position (in-range 4)))
      (let* ((queue (list-ref '(append chunked hybrid auto) (modulo (+ round position) 4)))
             (begin (cpu-time)))
        (let loop ((remaining repetitions))
          (unless (= remaining 0)
            (set! last (solve-closure plan queue)) (loop (- remaining 1))))
        (let ((seconds (- (cpu-time) begin)))
          (for (index (in-range size))
            (unless (closure-ref last index) (error "independent seeded oracle" index)))
          (set! rows (cons (record "queue" (symbol->string queue) "round" round
                            "position" position "cpu_seconds" seconds
                            "repetitions" repetitions "oracle_parity" #t) rows)))))
    (hash-put! receipt "rows" (reverse rows))
    (call-with-output-file (list path: output truncate: #t)
      (lambda (port) (write-json port receipt) (newline port)))
    (displayln "CLOSURE-PAIRED-OK family=" family " observations=" (length rows))))
