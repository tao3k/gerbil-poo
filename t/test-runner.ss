;;; Execute the checked compiled inventory using the released Gerbil test runner.
(export main compiled-tests)
;; Import the expander as one standard import set. Prefixing its entire public
;; interface flattens it into individual dependency records for every export.
;; Only the harness entry needs a renamed binding; its module still initializes.
(import (prefix-in (only-in :gerbil/tools/gxtest main) tests.)
        (only-in :std/test/base TestSuite? TestObject-info TestObject-init! TestObject-init!-set!
                 TestObject-subtests TestCase-main TestCase-main-set!)
        :gerbil/expander
        (only-in "test-groups.ss" test-files))

;; Keep source-file selection explicit, but pass compiled interfaces to gxtest.
;; Its ordinary source-file entry expands and retains every module's syntax even
;; when compiled code exists. No source fallback, heap change or forced GC occurs.
;; Standard std/make supplies these files; Actions separately checks source cache
;; identity and the producer revision before running the shared build artifact.
(def (compiled-tests target)
  (def inventory (test-files))
  (def selected (cond ((equal? target "t") inventory)
    ((member target inventory) [target])
    (else (error "test target is not in the checked inventory" target))))
  (map (lambda (source)
    (def compiled (path-expand
      (string-append "lib/clan/poo/" (path-strip-extension source) ".ssi") (gerbil-path)))
    (unless (file-exists? compiled) (error "compiled test missing; run just build" source compiled))
    compiled) selected))

;; Observe actual cases through the standard TestSuite initializer and TestCase
;; entry, after the original initializer has created every case in its own order.
;; dynamic-wind records early failure/continuation exits as well as success; the
;; standard harness still owns setup, cleanup, checks, error reporting and order.
(def (observe-cases! suite statistics)
  (def initialize (TestObject-init! suite))
  (TestObject-init!-set! suite
    (lambda ()
      (initialize)
      (for-each (lambda (case)
        (def body (TestCase-main case))
        (TestCase-main-set! case
          (lambda ()
            (def before #f)
            (dynamic-wind
              (lambda () (set! before (##process-statistics)))
              body
              (lambda ()
                (displayln "TEST-CASE-END " (TestObject-info case) " statistics=" (statistics before))
                (force-output)))))) (TestObject-subtests suite)))))

;; One call to the standard harness runs every selected module in one process,
;; with its original ordering, fixtures, test cases and typed failure handling.
(def (main target)
  (def process-start (##process-statistics))
  (def files (compiled-tests target))
  (def paths (map path-normalize files))
  (def evaluate (current-expander-module-eval))
  ;; Gambit's counters distinguish CPU/GC from loader waits, without collecting,
  ;; warming modules or changing heap policy. The caller times executable startup.
  (def (statistics before)
    (def after (##process-statistics))
    (unless (= (f64vector-length after) 20) (error "unsupported Gambit statistics layout"))
    (def (delta index) (- (f64vector-ref after index) (f64vector-ref before index)))
    (list 'wall (delta 2) 'cpu (+ (delta 0) (delta 1))
      'gc-cpu (+ (delta 3) (delta 4)) 'collections (inexact->exact (delta 6))))
  ;; The harness evaluates each checked root through this public parameter.
  ;; Report actual initialization work, including dependent bundle loading;
  ;; preserve values and let the original exception propagate on failure.
  (def (observe module)
    (def path (and (module-context? module) (module-context-path module)))
    (if (and (string? path) (member (path-normalize path) paths))
      (let ((start (real-time)) (before (##process-statistics)))
        (displayln "TEST-LOAD-START " path) (force-output)
        (call-with-values (lambda () (evaluate module))
          (lambda result
            ;; Reuse the same resolved runtime exports selected by gxtest.
            ;; No source expansion, new test discovery or alternate runner occurs.
            (for-each (lambda (export)
              (when (and (= (module-export-phi export) 0)
                         (string-suffix? "-test" (symbol->string (module-export-name export))))
                (let (suite (eval (binding-id (core-resolve-module-export export))))
                  (when (TestSuite? suite) (observe-cases! suite statistics)))))
              (module-context-export module))
            (displayln "TEST-LOAD-END " path " wall=" (- (real-time) start) " statistics=" (statistics before))
            (force-output) (apply values result))))
      (evaluate module)))
  (displayln "TEST-MODE compiled modules=" (length files)) (force-output)
  (parameterize ((current-expander-module-eval observe))
    (def status (apply tests.main "-v" "5" files))
    (displayln "TEST-HARNESS-END statistics=" (statistics process-start))
    (force-output)
    (exit status)))
