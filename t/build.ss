;;; Resource boundaries around the standard defbuild-script entry.
(import :std/misc/process :std/io/tempfile :std/iter :std/sync/channel
        :std/sync/threads :std/os/signal :std/os/signal-handler :std/os/error
        (only-in :std/misc/ports read-all-as-lines)
        "test-groups.ss" (only-in "build-spec.ss" clean-request))
(export main run-build-stage reap-build-group build-group-states)

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
;; Read a strict standard ps snapshot only after a group signal is refused.
;; Darwin excludes zombie members from killpg's permission/recipient count.
;; No executing group is retired on EPERM; absent snapshots require ESRCH too.
(def (build-group-states pid (lines (run-process '("ps" "-e" "-o" "pgid=" "-o" "state=")
                                      coprocess: read-all-as-lines)))
  (foldr (lambda (line states)
    (call-with-input-string line (lambda (port)
      (def group (read port)) (def state (read port))
      (unless (and (exact-integer? group) (>= group 0) (symbol? state)
                   (eof-object? (read port)))
        (error "invalid build process group snapshot" line))
      (if (= group pid) (cons state states) states)))) [] lines))
;; Standard signal delivery remains authoritative. Inspect EPERM instead of
;; ignoring it: only a verified all-zombie group is terminal; a missing group
;; must also pass the kernel's ESRCH probe. Optional procedures isolate OS cases
;; in regressions without changing production commands or resource limits.
(def (reap-build-group pid (send kill) (members build-group-states))
  (unless (and (exact-integer? pid) (> pid 1)) (error "invalid owned build process" pid))
  (with-catch (lambda (cause)
    (cond
      ((and (os-error? cause) (= (OSError-errno cause) ESRCH)) (void))
      ((and (os-error? cause) (= (OSError-errno cause) EPERM))
        (def states (with-catch (lambda (inspection)
          (error "build process group inspection failed" pid cause inspection))
          (lambda () (members pid))))
        (cond
          ((and (pair? states) (andmap (lambda (state) (string-prefix? "Z" (symbol->string state))) states))
            (displayln "BUILD-GROUP-TERMINAL pid=" pid " states=" states " signal-errno=" EPERM)
            (force-output))
          ((null? states)
            (with-catch (lambda (probe)
              (unless (and (os-error? probe) (= (OSError-errno probe) ESRCH)) (raise cause)))
              (lambda () (send (- pid) 0) (raise cause))))
          (else (raise cause))))
      (else (raise cause))))
    (lambda () (send (- pid) SIGKILL))))
;; A real cleanup refusal closes admission and retains the original cause.
(def (stop-build-group pid)
  (with-catch (lambda (cause) (set! build-stopping? #t) (raise cause))
    (lambda () (reap-build-group pid))))
;; Cancellation visits every owned group even if one cleanup refuses, then exits
;; nonzero. Snapshot under the existing mutex; never hold it while workers reap.
(def (cancel-build status)
  (set! build-stopping? #t)
  (def groups (with-lock build-process-lock (lambda () build-processes)))
  (for-each (lambda (pid)
    (with-catch (lambda (cause)
      (displayln "BUILD-CANCEL-CLEANUP-ERROR pid=" pid " cause=" cause) (force-output))
      (lambda () (stop-build-group pid)))) groups)
  (exit status))
;; GNU timeout retains each caller's existing 90/300-second bound and three-second cleanup.
;; Normal stdout is inherited, so every standard make progress line remains visible.
(def (run-build-stage root timeout runtime cores args (seconds 300))
  (when build-stopping? (error "build admission stopped after cleanup failure"))
  (def started (real-time))
  (displayln "BUILD-STAGE-START command=" args " cores=" cores) (force-output)
  ;; Use the public Gerbil launcher, as just does: a linked binary's ~~bin can
  ;; retain the release producer's path and bypass relocation/runtime activation.
  ;; Both compilation and recovery use the same bounded process-group ownership.
  ;; Standard clean runs only after the failed compiler group has been reaped.
  (def (invoke request)
    (def command (append [timeout "--signal=TERM" "--kill-after=3s" (string-append (number->string seconds) "s") "env"
      (string-append "GERBIL_BUILD_CORES=" (number->string cores))
      "gxi" runtime "build.ss"] request))
    (run-process command directory: root stdout-redirection: #f
      coprocess: (lambda (process)
        (def pid (process-pid process))
        (with-lock build-process-lock (lambda () (set! build-processes (cons pid build-processes))))
        (close-output-port process)
        (try
          (let (status (process-status process))
            ;; Report the standard raw wait status before cleanup can fail.
            (displayln "BUILD-PROCESS-END command=" request " pid=" pid " status=" status)
            (force-output)
            status)
          (finally
            (with-catch (lambda (cause)
              (error "build process group cleanup failed" request pid (process-status process) cause))
              (lambda () (stop-build-group pid)))
            (with-lock build-process-lock
              (lambda () (set! build-processes
                (filter (lambda (active) (not (= active pid))) build-processes)))))))))
  (try (invoke args)
    (catch (cause)
      ;; Never clean artifacts while a refused group might still be executing.
      (when build-stopping? (raise cause))
      (with-catch (lambda (cleanup-cause)
        (set! build-stopping? #t)
        (error "build failed and standard clean failed" cause cleanup-cause))
        (lambda ()
          (def cleanup (clean-request args))
          (displayln "BUILD-STAGE-CLEAN command=" cleanup) (force-output)
          (invoke cleanup)))
      (raise cause)))
  (displayln "BUILD-STAGE-END command=" args " wall=" (- (real-time) started))
  (force-output))
;; At most two channel workers compile the complete, disjoint local batches.
;; Fresh processes release expansion contexts; all failures are retained.
(def (build-test-groups project timeout runtime cores (seconds 300))
  ;; Bound retained macro-expansion contexts under the unchanged 1 GiB VM cap.
  ;; This changes compilation groups only; the full test program stays one VM.
  (def batches 8)
  (test-batch 0 batches)
  (def count (min 2 (max 1 cores) batches))
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
        (lambda () (run-build-stage project timeout runtime budget ["batch" (number->string batch)] seconds))))))))
  (for (batch (in-range batches)) (channel-put jobs batch))
  (channel-close jobs)
  (for-each thread-join!/error workers)
  (unless (null? failures) (error "test compilation failures retained" failures)))
;; std/make owns dependencies, incremental compilation and backend workers.
;; The outer boundary releases expansion heaps between complete test batches.
(def (main timeout runtime limit . request)
  (def seconds (string->number limit))
  (unless (and (exact-integer? seconds) (> seconds 0) (<= seconds 300))
    (error "invalid compiler stage deadline" limit))
  (def root (path-expand "" (current-directory)))
  (def cores (string->number (getenv "GERBIL_BUILD_CORES" "1")))
  ;; Standard zero disables parallel compilation; it still executes one worker.
  (unless (and (exact-integer? cores) (>= cores 0)) (error "invalid standard worker budget" cores))
  (add-signal-handler! SIGTERM (lambda () (cancel-build 143)))
  (add-signal-handler! SIGINT (lambda () (cancel-build 130)))
  (try
    (match request
      ([]
        ;; One Darwin make graph emits shared/static library objects and links
        ;; the program. The complete test groups still compile before execution.
        (run-build-stage root timeout runtime cores
          (cond-expand (darwin '("test-program")) (else '("qualification"))) seconds)
        (with-test-project root (lambda (project) (build-test-groups project timeout runtime cores seconds)))
        (cond-expand
          (darwin (void))
          (else (run-build-stage root timeout runtime cores '("test-program") seconds))))
      (["tests" group output]
        (test-files group)
        (with-test-project root (lambda (project)
          (run-build-stage project timeout runtime cores ["tests" group output] seconds))))
      (else (run-build-stage root timeout runtime cores request seconds)))
    (finally (remove-signal-handler! SIGTERM) (remove-signal-handler! SIGINT))))
