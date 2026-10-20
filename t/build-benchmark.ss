;;; Observe one complete released-compiler build; keep raw receipts outside Git.
(import :std/misc/process :std/misc/ports :std/iter
        (only-in "build-artifacts.ss" build-input-files build-digests))
(export main)

;; Read only PID, parent PID and executable name; retain this build's descendants.
(def (process-rows)
  (call-with-input-string (run-process ["/bin/ps" "-ax" "-o" "pid=,ppid=,comm="])
    (lambda (port)
      (let loop ((rows []))
        (let (line (read-line port))
          (if (eof-object? line) rows
            (loop (cons (call-with-input-string line
              (lambda (p) (vector (read p) (read p) (read-line p)))) rows))))))))

;; Dependency closure uses process parentage, never unrelated compiler names.
(def (descendants rows root)
  (let loop ((ids [root]))
    (let (next (foldl (lambda (row ids)
      (if (and (member (vector-ref row 1) ids) (not (member (vector-ref row 0) ids)))
        (cons (vector-ref row 0) ids) ids)) ids rows))
      (if (= (length next) (length ids))
        (filter (lambda (row) (member (vector-ref row 0) ids)) rows)
        (loop next)))))

;; Classify sampled compiler executables without treating a worker limit as overlap.
(def (backend? row)
  (let (name (vector-ref row 2))
    (string-contains name "gsc")))

;; Preserve a complete datum atomically when output and sampler threads overlap.
(def (writer port)
  (let (lock (make-mutex 'build-receipt))
    (lambda (datum)
      (with-lock lock (lambda () (write datum port) (newline port) (force-output port))))))

;; Run the exact package build with an isolated output, unchanged heap and inventory.
;; The caller must own the existing 300-second process-group deadline.
(def (main source output cores (sample? "yes") (scope "all") (script "build.ss"))
  (cond-expand (darwin (void)) (else (error "this collector measures macOS only")))
  (unless (and (exact-integer? (string->number cores)) (> (string->number cores) 0))
    (error "positive build core count required" cores))
  (unless (member sample? '("yes" "no")) (error "sampling must be yes or no"))
  (create-directory* output)
  (def source-key (build-digests source (build-input-files source)))
  (def start (real-time))
  (def emit (writer (open-output-file (list path: (path-expand "events.scm" output) truncate: #t))))
  (def command ["/usr/bin/time" "-l" "/usr/bin/env"
    "-u" "SDKROOT" "-u" "CPATH" "-u" "LIBRARY_PATH" "-u" "C_INCLUDE_PATH"
    "-u" "CPLUS_INCLUDE_PATH" "-u" "MACOSX_DEPLOYMENT_TARGET" "COMPILER_PATH=/usr/bin"
    (string-append "GERBIL_BUILD_CORES=" cores) (string-append "GERBIL_BUILD_VERBOSE=" (getenv "GERBIL_BUILD_VERBOSE" "3"))
    (string-append "GERBIL_BUILD_LIBDIR=" (path-expand "lib" output))
    (string-append "GERBIL_PATH=" output) (string-append "GERBIL_BUILD_SCOPE=" scope) "gxi" "-:max-heap=1G" script])
  (emit `(build-study (platform macos) (toolchain ,(gerbil-version-string) ,(system-version-string))
    (source ,source) (source-key ,source-key) (scope ,scope) (cores ,cores) (heap "1G") (sample-period .25) (command ,command)))
  (def status #f)
  (def peak 0)
  (def modules 0)
  (def jobs 0)
  (run-process command directory: source stderr-redirection: #t check-status: #f
    coprocess:
    (lambda (process)
      (def running? #t)
      (def sampler
        (and (equal? sample? "yes")
          (spawn (lambda ()
            (let loop ()
              (when running?
                (let* ((rows (descendants (process-rows) (process-pid process)))
                       (count (length (filter backend? rows))))
                  (set! peak (max peak count))
                  (emit `(processes ,(- (real-time) start) ,rows)))
                (thread-sleep! .25)
                (loop)))))))
      (try
        (let loop ()
          (let (line (read-line process))
            (unless (eof-object? line)
              (emit `(line ,(- (real-time) start) ,line))
              (when (string-prefix? "... compile " line) (set! modules (+ modules 1)))
              (when (string-prefix? "... execute compile job " line) (set! jobs (+ jobs 1)))
              (when (or (string-prefix? "... compile " line)
                        (string-prefix? "... execute compile job " line))
                (displayln "BUILD-PROGRESS wall=" (- (real-time) start)
                  " modules=" modules " jobs=" jobs " observed-gsc-processes=" peak)
                (force-output))
              (loop))))
        (set! status (process-status process))
        (finally (set! running? #f) (when sampler (thread-join! sampler))))))
  (unless (equal? source-key (build-digests source (build-input-files source)))
    (error "build study source changed"))
  (emit `(complete (wait-status ,status) (wall ,(- (real-time) start))
    (compile-lines ,modules) (backend-jobs ,jobs) (sampled-peak ,peak)))
  (displayln "BUILD-END exit=" status " wall=" (- (real-time) start)
    " modules=" modules " jobs=" jobs " observed-gsc-processes=" peak)
  (unless (zero? status) (error "complete build failed; receipt retained" output status)))
