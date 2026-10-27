;;; Standard build/test acceptance: no project dependency parser or test runner.
(export build-test)
(import :std/test :std/io/tempfile :std/iter
  (only-in :std/misc/process run-process process-error?)
  (only-in :std/misc/ports read-all-as-lines)
  (only-in :clan/poo/t/build call-with-build-jobs))

;; Write a fixture declaration verbatim; std/make interprets it, not this test.
(def (write-source root name text)
  (call-with-output-file [path: (path-expand name root) truncate: #t]
    (cut display text <>)))

;; Keep temporary package ownership local to one case and use standard paths.
(def (with-package body)
  (call-with-temporary-directory "poo-standard-build-"
    (lambda (root)
      (write-source root "gerbil.pkg" "(package: build-check)\n")
      (write-source root "unit.ss" "(export value)\n(def value 42)\n")
      (write-source root "unit-test.ss"
        "(import :std/test \"unit.ss\")\n(export unit-test)\n(def unit-test (test-suite \"fixture\" (test-case \"value\" (check-equal? value 42))))\n")
      (write-source root "build.ss"
        "#!/usr/bin/env -S gxi -:max-heap=1G,debug=q\n(import :std/build-script)\n(defbuild-script '(\"unit\" \"unit-test\"))\n")
      (run-process ["chmod" "755" (path-expand "build.ss" root)])
      (body root))))

;; Invoke only the compiler's public package/test commands under a fixture bound.
;; GERBIL_PATH and GERBIL_BUILD_CORES are Gerbil's documented controls.
(def (command root args (cores "0") (deadline "30s"))
  (def timeout (car (run-process ["sh" "-c" "command -v gtimeout || command -v timeout"]
                      coprocess: read-all-as-lines)))
  (run-process (append [timeout "--signal=TERM" "--kill-after=3s" deadline
    "env" (string-append "GERBIL_PATH=" root)
    (string-append "GERBIL_BUILD_CORES=" cores) "gerbil" "-:max-heap=1G,debug=q"] args)
    directory: root stderr-redirection: #t))

;; File timestamps are observed only to test std/make's own no-op decision.
(def (modified file)
  (time->seconds (file-info-last-modification-time (file-info file))))

;; Preserve the original error even when the public executor has no pending jobs.
(def build-test
  (test-suite "standard build and test protocols"
    (test-case "standard package build accepts its default operation"
      (with-package (lambda (root)
        (command root '("build"))
        (check (file-exists? (path-expand "lib/build-check/unit.ssi" root)) => #t)
        (for (module '("testing/type.ss" "testing/function.ss" "testing/generation-graph.ss" "testing/recursive-generation.ss"))
          (check (file-exists? module) => #t))
        (for (old '("property-testing.ss" "function-testing.ss" "generation-graph.ss" "recursive-generation.ss"))
          (check (file-exists? old) => #f)))))
    (test-case "standard build writes importable interfaces"
      (with-package (lambda (root)
        (command root '("build"))
        (check (file-exists? (path-expand "lib/build-check/unit.ssi" root)) => #t))))
    (test-case "unchanged standard build reuses its interface"
      (with-package (lambda (root)
        (command root '("build"))
        (let* ((file (path-expand "lib/build-check/unit.ssi" root)) (before (modified file)))
          (command root '("build")) (check-equal? (modified file) before)))))
    (test-case "source changes are detected by standard make"
      (with-package (lambda (root)
        (command root '("build"))
        (thread-sleep! 1.1)
        (write-source root "unit.ss" "(export value)\n(def value 43)\n")
        (command root '("build"))
        (check (string-contains (command root '("test" "unit-test.ss")) "ERROR") ? integer?))))
    (test-case "dependency changes invalidate an importing test"
      (with-package (lambda (root)
        (command root '("build"))
        (thread-sleep! 1.1)
        (write-source root "unit.ss" "(export value)\n(def value 43)\n")
        (command root '("build"))
        (check (string-contains (command root '("test" "lib/build-check/unit-test.ssi")) "ERROR") ? integer?))))
    (test-case "clean removes generated interfaces and preserves sources"
      (with-package (lambda (root)
        (command root '("build")) (command root '("clean"))
        (check (file-exists? (path-expand "lib/build-check/unit.ssi" root)) => #f)
        (check (file-exists? (path-expand "unit.ss" root)) => #t))))
    (test-case "clean and rebuild restore a refused package"
      (with-package (lambda (root)
        (write-source root "build.ss"
          "#!/usr/bin/env -S gxi -:max-heap=1G,debug=q\n(import :std/build-script)\n(def build (let () (defbuild-script '(\"unit\" \"unit-test\")) main))\n(def (main . args) (if (equal? args '(\"clean\")) (apply build args) (begin (create-directory* \"lib/build-check\") (call-with-output-file \"lib/build-check/unit.ssi\" (cut display \"partial\" <>)) (thread-sleep! 30))))\n")
        (check-exception (command root '("build") "0" "5s") process-error?)
        (check (file-exists? (path-expand "lib/build-check/unit.ssi" root)) => #t)
        (command root '("clean"))
        (check (file-exists? (path-expand "lib/build-check/unit.ssi" root)) => #f)
        (write-source root "build.ss"
          "#!/usr/bin/env -S gxi -:max-heap=1G,debug=q\n(import :std/build-script)\n(defbuild-script '(\"unit\" \"unit-test\"))\n")
        (write-source root "unit.ss" "(this is invalid)\n")
        (check-exception (command root '("build")) process-error?)
        (command root '("clean"))
        (write-source root "unit.ss" "(export value)\n(def value 42)\n")
        (command root '("build"))
        (check (string-contains (command root '("test" "unit-test.ss")) "OK") ? integer?))))
    (test-case "missing declared source is a real build failure"
      (with-package (lambda (root)
        (delete-file (path-expand "unit.ss" root))
        (check-exception (command root '("build")) process-error?))))
    (test-case "duplicate standard make roots are refused"
      (with-package (lambda (root)
        (write-source root "build.ss"
          "#!/usr/bin/env -S gxi -:max-heap=1G,debug=q\n(import :std/build-script)\n(defbuild-script '(\"unit\" \"unit\"))\n")
        (check-exception (command root '("build")) process-error?))))
    (test-case "unknown build flags are refused by the standard parser"
      (with-package (lambda (root)
        (check-exception (command root '("build" "--unknown-poo-option")) process-error?))))
    (test-case "source test discovery runs a real case"
      (with-package (lambda (root)
        (check (string-contains (command root '("test" "-v" "5" "unit-test.ss")) "CASE-OK") ? integer?))))
    (test-case "compiled interfaces use the same official runner"
      (with-package (lambda (root)
        (command root '("build"))
        (check (string-contains (command root '("test" "-v" "5" "lib/build-check/unit-test.ssi")) "CASE-OK") ? integer?))))
    (test-case "missing test modules are failures"
      (with-package (lambda (root)
        (check-exception (command root '("test" "missing-test.ss")) process-error?))))
    (test-case "a failing assertion is a process failure"
      (with-package (lambda (root)
        (write-source root "unit.ss" "(export value)\n(def value 0)\n")
        (check (string-contains (command root '("test" "unit-test.ss")) "ERROR") ? integer?))))
    (test-case "suite initialization failure is preserved"
      (with-package (lambda (root)
        (write-source root "unit-test.ss"
          "(import :std/test)\n(export unit-test)\n(def unit-test (test-suite \"fixture\" (error \"setup refused\")))\n")
        (check (string-contains (command root '("test" "unit-test.ss")) "ERROR") ? integer?))))
    (test-case "case exceptions are preserved"
      (with-package (lambda (root)
        (write-source root "unit-test.ss"
          "(import :std/test)\n(export unit-test)\n(def unit-test (test-suite \"fixture\" (test-case \"refuse\" (error \"case refused\"))))\n")
        (check (string-contains (command root '("test" "unit-test.ss")) "ERROR") ? integer?))))
    (test-case "official discovery finds directory test files"
      (with-package (lambda (root)
        (check (string-contains (command root '("test" "-v" "5" ".")) "CASE-OK") ? integer?))))
    (test-case "an empty suite does not manufacture a case marker"
      (with-package (lambda (root)
        (write-source root "unit-test.ss"
          "(import :std/test)\n(export unit-test)\n(def unit-test (test-suite \"empty\" (void)))\n")
        (check (string-contains (command root '("test" "-v" "5" "unit-test.ss")) "CASE-OK") => #f))))
    (test-case "standard parallel compilation preserves observable results"
      (with-package (lambda (root)
        (command root '("build") "2")
        (check (string-contains (command root '("test" "unit-test.ss")) "OK") ? integer?))))
    (test-case "build-job boundary preserves multiple values"
      (check-equal? (call-with-values (cut call-with-build-jobs (lambda () (values 1 2))) list) '(1 2)))
    (test-case "build-job boundary preserves false exceptions"
      (check-equal? (with-catch (lambda (cause) (list cause))
        (cut call-with-build-jobs (lambda () (raise #f)))) '(#f)))
    (test-case "build-job boundary preserves exception identity"
      (let (cause (cons 'refused []))
        (check-eq? (with-catch identity (cut call-with-build-jobs (lambda () (raise cause)))) cause)))
    (test-case "declared include changes participate in standard freshness"
      (with-package (lambda (root)
        (write-source root "unit.ss" "(export value)\n(include \"value.scm\")\n")
        (write-source root "value.scm" "(def value 42)\n")
        (write-source root "build.ss"
          "#!/usr/bin/env -S gxi -:max-heap=1G,debug=q\n(import :std/build-script)\n(defbuild-script '((gxc: \"unit\" (extra-inputs: (\"value.scm\"))) \"unit-test\"))\n")
        (command root '("build")) (thread-sleep! 1.1)
        (write-source root "value.scm" "(def value 43)\n")
        (command root '("build"))
        (check (string-contains (command root '("test" "lib/build-check/unit-test.ssi")) "ERROR") ? integer?))))
    (test-case "public check recipes retain the standard entry and resource limits"
      (def output (run-process '("just" "--dry-run" "check-built" "2" "1" "4") stderr-redirection: #t))
      (check (string-contains output "_test 300") ? integer?)
      (check (string-contains output "_run-collections") ? integer?)
      (check (string-contains output "gxi") => #f))))
