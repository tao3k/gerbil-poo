;;; Execute the checked compiled inventory using the released Gerbil test runner.
(export main compiled-tests)
(import (prefix-in :gerbil/tools/gxtest tests.)
        (prefix-in :gerbil/expander x.)
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

;; One call to the standard harness runs every selected module in one process,
;; with its original ordering, fixtures, test cases and typed failure handling.
(def (main target)
  (def files (compiled-tests target))
  (def paths (map path-normalize files))
  (def evaluate (x.current-expander-module-eval))
  ;; The harness evaluates each checked root through this public parameter.
  ;; Report actual initialization work, including dependent bundle loading;
  ;; preserve values and let the original exception propagate on failure.
  (def (observe module)
    (def path (and (x.module-context? module) (x.module-context-path module)))
    (if (and (string? path) (member (path-normalize path) paths))
      (let (start (real-time))
        (displayln "TEST-LOAD-START " path) (force-output)
        (call-with-values (lambda () (evaluate module))
          (lambda result
            (displayln "TEST-LOAD-END " path " wall=" (- (real-time) start))
            (force-output) (apply values result))))
      (evaluate module)))
  (displayln "TEST-MODE compiled modules=" (length files)) (force-output)
  (parameterize ((x.current-expander-module-eval observe))
    (exit (apply tests.main "-v" "5" files))))
