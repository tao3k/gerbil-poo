;;; Resource boundaries around the standard defbuild-script entry.
(import :std/misc/process :std/io/tempfile :std/iter :std/sync/channel
        :std/sync/threads :std/os/signal :std/os/signal-handler :std/os/error
        "test-groups.ss")
(export main)

;; Preserve ordinary make freshness hints without a second cache protocol.
(def (copy-input source target)
  (def info (file-info source))
  (copy-file source target)
  (file-last-access-and-modification-times-set! target
    (file-info-last-access-time info) (file-info-last-modification-time info)))

;; Copy project resources or completed SSI metadata using standard file primitives.
;; Test roots remain source files and shared imports resolve through their SSI.
(def (copy-tree source target (interfaces? #f))
  (when (file-exists? source)
    (if (eq? (file-info-type (file-info source)) 'directory)
      (for-each (lambda (name) (copy-tree (path-expand name source) (path-expand name target) interfaces?))
        (directory-files source))
      (when (or (not interfaces?)
                (and (string-suffix? ".ssi" source) (not (string-suffix? "-test.ssi" source))))
        (create-directory* (path-directory target))
        (copy-input source target)))))

;; A standard temporary directory bounds the SSI-first view's lifetime.
;; This is a compiler input view, not another source or artifact cache.
(def (with-test-project root thunk)
  (call-with-temporary-directory "poo-tests-"
    (lambda (project)
      (for-each (lambda (file) (copy-input (path-expand file root) (path-expand file project)))
        (filter (lambda (name) (or (string-suffix? ".ss" name) (equal? name "gerbil.pkg")))
          (directory-files root)))
      (for-each (lambda (name) (copy-tree (path-expand name root) (path-expand name project)))
        '("support" "types" "table" "trie" "examples" "t"))
      (copy-tree (path-expand "lib/clan/poo/" (gerbil-path)) project #t)
      (thunk project))))
;; The registry owns only timeout-created process groups from this invocation.
(def build-processes [])
;; A refused cleanup prevents subsequent compiler admission.
(def build-stopping? #f)
;; Serialize ownership changes independently of the compiler's import mutex.
(def build-process-lock (make-mutex 'build-processes))
;; ESRCH means an owned group has completed; every other cleanup error propagates.
(def (stop-build-group pid)
  (with-catch (lambda (cause)
    (unless (and (os-error? cause) (= (OSError-errno cause) ESRCH)) (set! build-stopping? #t) (raise cause)))
    (lambda () (kill (- pid) SIGKILL))))
;; Cancellation kills every owned compiler group before exiting nonzero.
(def (cancel-build status)
  (with-lock build-process-lock
    (lambda () (for-each stop-build-group build-processes))) (exit status))
;; GNU timeout retains the existing 300-second stage bound and three-second cleanup.
;; Normal stdout is inherited, so every standard make progress line remains visible.
(def (run-build-stage root timeout runtime cores args)
  (when build-stopping? (error "build admission stopped after cleanup failure"))
  (def started (real-time))
  (displayln "BUILD-STAGE-START command=" args " cores=" cores) (force-output)
  (def command (append [timeout "--signal=TERM" "--kill-after=3s" "300s" "env"
    (string-append "GERBIL_BUILD_CORES=" (number->string cores))
    (path-expand "~~bin/gxi") runtime "build.ss"] args))
  (run-process command directory: root stdout-redirection: #f
    coprocess: (lambda (process)
      (def pid (process-pid process))
      (with-lock build-process-lock (lambda () (set! build-processes (cons pid build-processes))))
      (close-output-port process)
      (try (process-status process)
        (finally
          (stop-build-group pid)
          (with-lock build-process-lock
            (lambda () (set! build-processes (filter (lambda (active) (not (= active pid))) build-processes))))))))
  (displayln "BUILD-STAGE-END command=" args " wall=" (- (real-time) started))
  (force-output))
;; At most two channel workers compile the complete, disjoint local batches.
;; Fresh processes release expansion contexts; all failures are retained.
(def (build-test-groups project timeout runtime cores)
  (def batches 4)
  (test-batch 0 batches)
  (def count (min 2 cores batches))
  (def jobs (make-channel))
  (def failures [])
  (def lock (make-mutex 'build-failures))
  (displayln "BUILD-TEST-INVENTORY modules=" (length (test-files)) " batches=" batches " workers=" count)
  (force-output)
  (def workers (for/collect (worker (in-range count))
    ;; Allocate the remainder too, without exceeding the caller's core budget.
    (def budget (+ (quotient cores count) (if (< worker (modulo cores count)) 1 0)))
    (spawn (lambda () (for (batch jobs)
      (with-catch (lambda (cause) (with-lock lock (lambda () (set! failures (cons (cons batch cause) failures)))))
        (lambda () (run-build-stage project timeout runtime budget ["batch" (number->string batch)]))))))))
  (for (batch (in-range batches)) (channel-put jobs batch))
  (channel-close jobs)
  (for-each thread-join!/error workers)
  (unless (null? failures) (error "test compilation failures retained" failures)))
;; std/make owns dependencies, incremental compilation and backend workers.
;; The outer boundary releases expansion heaps between complete test batches.
(def (main timeout runtime . request)
  (def root (path-expand "" (current-directory)))
  (def cores (string->number (getenv "GERBIL_BUILD_CORES" "1")))
  (unless (and (exact-integer? cores) (> cores 0)) (error "invalid standard worker budget" cores))
  (add-signal-handler! SIGTERM (lambda () (cancel-build 143)))
  (add-signal-handler! SIGINT (lambda () (cancel-build 130)))
  (try
    (match request
      ([]
        (run-build-stage root timeout runtime cores '("library"))
        (with-test-project root (lambda (project) (build-test-groups project timeout runtime cores)))
        (run-build-stage root timeout runtime cores '("test-program")))
      (["tests" group output]
        (test-files group)
        (with-test-project root (lambda (project)
          (run-build-stage project timeout runtime cores ["tests" group output]))))
      (else (run-build-stage root timeout runtime cores request)))
    (finally (remove-signal-handler! SIGTERM) (remove-signal-handler! SIGINT))))
