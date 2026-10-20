;;; Bounded package compilation from checked shared interfaces and test groups.
(import :std/misc/ports :std/misc/process :std/io/tempfile :std/iter :std/sync/channel
        :std/sync/threads :std/os/signal :std/os/signal-handler :std/os/error
        :std/os/flock (only-in :std/os/device device-close)
        "test-groups.ss" "build-artifacts.ss")
(export main)
;; Measure completed preparation work, preserving values and original failures.
;; These are real operation boundaries, never periodic heartbeat messages.
(def (observe-build label thunk)
  (def start (real-time))
  (def ok? #f)
  (try (call-with-values thunk (lambda result (set! ok? #t) (apply values result)))
    (finally
      (displayln "BUILD-PREPARE operation=" label " success=" ok? " wall=" (- (real-time) start))
      (force-output))))
;; Bind the admitted release and its configured backend without a fixed opt path.
(def (build-compiler-key)
  (def config (run-process [(path-expand "~~bin/gambuild-C")]))
  (def first (car (string-split config #\newline)))
  (unless (string-prefix? "C_COMPILER=" first) (error "unknown released backend metadata"))
  (def configured (call-with-input-string (substring first 11 (string-length first)) read))
  (def compiler (if (and (string? configured) (string-prefix? "/" configured)) configured
    (car (string-split (run-process ["/usr/bin/which" configured]) #\newline))))
  (unless (string? compiler) (error "backend compiler path must be a string"))
  (list (gerbil-version-string) (system-version-string)
    (map cdr (build-digests "/" (map path-normalize ["~~bin/gxi" "~~bin/gsc" "~~bin/gambuild-C" compiler])))
    (map (lambda (name) (cons name (getenv name #f)))
      '("CFLAGS" "CPPFLAGS" "LDFLAGS" "GERBIL_GSC" "GERBIL_GCC" "GERBIL_AR"
        "BUILD_OBJ_CC_PARAM" "BUILD_DYN_CC_PARAM" "BUILD_EXE_CC_PARAM"))))
;; Copy source bytes and admitted interfaces into a disposable standard SSI-first view.
;; Actual test roots remain .ss files; no runtime import procedure is replaced.
(def (with-build-project root thunk)
  (def inputs (build-input-files root))
  (def before (build-digests root inputs))
  (def lib (path-expand "lib/" (build-root)))
  (call-with-temporary-directory "poo-build-project-"
    (lambda (project)
      (def start (real-time))
      (for-each (lambda (file)
        (def output (path-expand file project))
        (create-directory* (path-directory output))
        (copy-build-input (path-expand file root) output)) inputs)
      (for-each (lambda (file)
        (when (string-suffix? ".ssi" file)
          (let* ((relative (substring file 9 (string-length file)))
                 (output (path-expand relative project)))
          (when (file-exists? output) (error "source snapshot already contains compiled interface" output))
          (create-directory* (path-directory output))
          (copy-build-input (path-expand file lib) output)))) (build-output-files #t))
      (unless (equal? before (build-digests project inputs))
        (error "source snapshot differs from its admitted bytes"))
      (displayln "BUILD-PREPARE operation=snapshot-copy-and-verify success=#t wall=" (- (real-time) start))
      (force-output)
      (def result (thunk project))
      (unless (equal? before (build-digests project inputs))
        (error "source snapshot changed during compilation"))
      (unless (equal? before (build-digests root (build-input-files root)))
        (error "build sources changed during compilation")) result)))
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
(def (run-build-stage root scope cores (group #f) (action #f) (batch #f))
  (when build-stopping? (error "build admission stopped after cleanup failure"))
  (def timeout (getenv "POO_BUILD_TIMEOUT" #f))
  (unless timeout (error "bounded build requires POO_BUILD_TIMEOUT"))
  (def started (real-time))
  (def trace (getenv "POO_BUILD_IMPORT_TRACE" #f))
  (def script
    (if trace
      (begin
        (create-directory* trace)
        ["t/build-benchmark.ss" "--worker" "build.ss"
          (path-expand (string-append scope "-" (or group "all") "-"
            (if batch (number->string batch) "none") "-" (or action "build") ".scm") trace)])
      ["build.ss"]))
  (displayln "BUILD-STAGE-START scope=" scope " group=" group " batch=" batch " cores=" cores " at=" started) (force-output)
  (def command (append [timeout "--signal=TERM" "--kill-after=3s" "300s" "env"
    "-u" "GERBIL_BUILD_TEST_GROUP" "-u" "GERBIL_BUILD_TEST_BATCH"
    (string-append "GERBIL_BUILD_SCOPE=" scope)
    (string-append "GERBIL_BUILD_CORES=" (number->string cores))]
    (if group [(string-append "GERBIL_BUILD_TEST_GROUP=" group)] [])
    (if batch [(string-append "GERBIL_BUILD_TEST_BATCH=" (number->string batch))] [])
    [(path-expand "~~bin/gxi")
      (string-append "-:max-heap=" (getenv "GERBIL_TEST_MAX_HEAP" "1G")
        ",debug=" (getenv "GERBIL_TEST_DEBUG" "q"))] script (if action [action] [])))
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
  (displayln "BUILD-STAGE-END scope=" scope " group=" group " batch=" batch " wall=" (- (real-time) started))
  (force-output))
;; Remove byte-identified changed roots before standard make schedules their
;; dependent closure. Source timestamps alone never authorize a cache hit.
(def (invalidate-build-sources! sources shared?)
  (def outputs (build-output-files shared?))
  (for-each (lambda (source)
    (for-each (lambda (file)
      (def path (path-expand file (path-expand "lib/" (build-root))))
      (check-compiled-tree! path)
      (delete-file path)) (build-source-outputs source outputs))) sources))
;; Preserve a trusted prior generation for standard dependency scheduling.
;; Changed policy/inventory/compiler/output bytes retain the complete clean path.
(def (ensure-shared-build root cores compiler)
  (def receipt (path-expand "poo-build-shared.scm" (build-root)))
  (if (observe-build "cache-library" (lambda () (build-current? receipt root #t compiler)))
    (begin (displayln "BUILD-CACHE-HIT scope=library") (force-output))
    (let (before (build-digests root (filter (lambda (file) (not (string-suffix? "-test.ss" file)))
                    (build-input-files root))))
      (def changed (build-changed-sources receipt root #t compiler))
      (if changed
        (begin
          (displayln "BUILD-INCREMENTAL scope=library changed=" changed) (force-output)
          (invalidate-build-sources! changed #t))
        (begin
          ;; Empty owned output has nothing to clean. Loading make solely for
          ;; cleanup would repeat release metadata preparation on a cold build.
          (unless (null? (build-output-files #f))
            (run-build-stage root "library" cores #f "clean")
            (reclaim-build-outputs!))))
      (run-build-stage root "library" cores)
      (unless (equal? before (build-digests root (filter (lambda (file) (not (string-suffix? "-test.ss" file)))
                              (build-input-files root)))) (error "shared sources changed"))
      (save-build-generation receipt root #t compiler))))
;; At most two channel workers compile the complete, disjoint local batches.
;; Fresh processes release expansion contexts; all failures are retained.
(def (build-test-groups project cores)
  (def batches (string->number (getenv "GERBIL_BUILD_TEST_BATCHES" "4")))
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
        (lambda () (run-build-stage project "tests" budget #f #f batch))))))))
  (for (batch (in-range batches)) (channel-put jobs batch))
  (channel-close jobs)
  (for-each thread-join!/error workers)
  (unless (null? failures) (error "test compilation failures retained" failures)))
;; Compose shared compilation, generation admission and every existing test group.
;; A warm hit skips only compilation; just test still runs all semantic checks.
(def (build-package)
  (def root (path-expand "" (current-directory)))
  (def cores (string->number (getenv "GERBIL_BUILD_CORES" "1")))
  (unless (and (exact-integer? cores) (> cores 0)) (error "invalid build core budget" cores))
  (create-directory* (build-root))
  (claim-build-root!)
  (def compiler (observe-build "compiler-metadata" build-compiler-key))
  (def scope (getenv "GERBIL_BUILD_SCOPE" "all"))
  (when (equal? scope "all")
    (test-batch 0 (string->number (getenv "GERBIL_BUILD_TEST_BATCHES" "4"))))
  (def all-receipt (path-expand "poo-build-all.scm" (build-root)))
  (add-signal-handler! SIGTERM (lambda () (cancel-build 143)))
  (add-signal-handler! SIGINT (lambda () (cancel-build 130)))
  (try
    (cond
      ((equal? scope "library") (ensure-shared-build root cores compiler))
      ((equal? scope "all")
        (if (observe-build "cache-all" (lambda () (build-current? all-receipt root #f compiler)))
          (displayln "BUILD-CACHE-HIT scope=all")
          (begin
            ;; A test-only edit reuses the admitted shared generation. Invalidated
            ;; roots rebuild even if an editor preserved their old modification time.
            (let (changed (build-changed-sources all-receipt root #f compiler))
              (when (and changed (andmap (lambda (source) (string-suffix? "-test.ss" source)) changed))
                (invalidate-build-sources! changed #f)))
            (ensure-shared-build root cores compiler)
            (let (before (build-generation root #t compiler))
            (with-build-project root (lambda (project) (build-test-groups project cores)))
            (unless (equal? before (build-generation root #t compiler)) (error "shared generation changed"))
            (for-each (lambda (file)
              (unless (file-exists? (path-expand (string-append "lib/clan/poo/" (path-strip-extension file) ".ssi") (build-root)))
                (error "compiled test is missing" file))) (test-files))
            (save-build-generation all-receipt root #f compiler)))))
      ((equal? scope "tests")
        (let ((before (build-generation root #t compiler)) (group (getenv "GERBIL_BUILD_TEST_GROUP")))
        (unless (build-current? (path-expand "poo-build-shared.scm" (build-root)) root #t compiler)
          (error "shared source/artifact generation is not admitted"))
        (test-files group)
        (with-build-project root (lambda (project) (run-build-stage project "tests" cores group)))
        (unless (equal? before (build-generation root #t compiler)) (error "shared generation changed"))))
      (else (run-build-stage root scope cores)))
    (finally (remove-signal-handler! SIGTERM) (remove-signal-handler! SIGINT))))

;; Standard OS locking prevents a local producer from replacing shared bytes
;; while another invocation prepares or compiles against them. Waiting is bounded.
;; Semantic tests remain separate and are never skipped by compilation receipts.
(def (main)
  (create-directory* (build-root))
  (def lock (open-output-file/lock (path-expand "poo-build.lock" (build-root)) 5))
  (try (build-package) (finally (device-close lock))))

;; A fresh project cache may be adopted; existing unclaimed package outputs are
;; never removed. Explicit foreign/global Gerbil paths require an admitted owner.
(def (claim-build-root!)
  (def receipt (path-expand "poo-build-owner.scm" (build-root)))
  (def owner '(package-build clan/poo))
  (if (file-exists? receipt)
    (unless (equal? (read-one-file receipt) owner) (error "build cache owner differs"))
    (begin
      (unless (null? (build-output-files #f))
        (error "existing package outputs are unclaimed; use an empty GERBIL_PATH"))
      (call-with-output-file receipt (lambda (port) (write owner port))))))
;; Only regular generated compiler files may be reclaimed; links and source files
;; refuse cleanup before deletion, preventing a package alias from hiding a checkout.
(def (check-compiled-tree! path)
  (when (file-exists? path)
    (let (kind (file-info-type (file-info path #f)))
      (cond
        ((eq? kind 'directory)
          (for-each (lambda (name) (check-compiled-tree! (path-expand name path))) (directory-files path)))
        ((and (eq? kind 'regular)
           (or (string-suffix? ".ssxi.ss" path)
               (ormap (lambda (suffix) (string-suffix? suffix path)) '(".ssi" ".scm" ".o1" ".o" ".c" ".a"))))
          (void))
        (else (error "refuse cleanup of non-compiler package data" path kind))))))
;; Reclaim only the declared package namespace after ordinary make-clean. This
;; also removes compiled modules deleted from the source inventory, not other packages.
(def (reclaim-build-outputs!)
  (def lib (path-expand "lib/" (build-root)))
  (def namespace (path-expand "clan/poo/" lib))
  (check-compiled-tree! namespace)
  (def static (if (file-exists? (path-expand "static/" lib))
    (filter (lambda (name) (string-prefix? "clan__poo__" name)) (directory-files (path-expand "static/" lib))) []))
  (for-each (lambda (name) (check-compiled-tree! (path-expand (string-append "static/" name) lib))) static)
  (when (file-exists? namespace) (delete-file-or-directory namespace #t))
  (for-each (lambda (name) (delete-file (path-expand (string-append "static/" name) lib))) static))
