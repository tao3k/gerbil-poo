;;; Execute the checked compiled inventory using the released Gerbil test runner.
(export main compiled-tests)
(import (prefix-in :gerbil/tools/gxtest tests.)
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
  (displayln "TEST-MODE compiled modules=" (length files)) (force-output)
  (exit (apply tests.main "-v" "5" files)))
