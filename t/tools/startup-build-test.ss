;;; Standard startup-program protocol, including metadata and object reuse.
(export startup-build-test)
(import :std/test :std/iter
  (only-in :std/misc/process run-process)
  (only-in :std/misc/ports read-all-as-lines)
  (only-in ./build-test with-package command write-source modified))

;; Exercise the real program declarations through standard script/package calls.
(def startup-build-test
  (test-suite "startup executable package"
    (test-case "metadata parallel backends clean and warm reuse keep standard semantics"
      (with-package (lambda (root)
        (def checks (path-expand "benchmarks/representation-startup" root))
        (def timeout (car (run-process ["sh" "-c" "command -v gtimeout || command -v timeout"]
          coprocess: read-all-as-lines)))
        ;; defbuild-script metadata is a script operation, not a package name.
        (def (description mode)
          (call-with-input-string
            (run-process [timeout "--signal=TERM" "--kill-after=3s" "30s" "env"
              (string-append "GERBIL_PATH=" root) "GERBIL_BUILD_CORES=2"
              "gxi" "-:max-heap=1G,debug=q" "build.ss" mode] directory: checks stderr-redirection: #t)
            read))
        (command root '("build"))
        (create-directory* checks)
        (create-directory* (path-expand "t" root))
        (copy-file "t/build.ss" (path-expand "t/build.ss" root))
        (copy-file "benchmarks/representation-startup/build.ss" (path-expand "build.ss" checks))
        (write-source checks "gerbil.pkg" "(package: build-check/benchmarks/representation-startup)\n")
        ;; The actual program declaration links an ordinary shared producer.
        (write-source checks "main.ss"
          "(export main)\n(import ../../unit)\n(def (main . arguments) (write value) (newline))\n")
        (check-equal? (description "meta") '("spec" "compile" "clean"))
        (check-equal? (length (description "spec")) 1)
        (command checks '("build") "2" "30s" root)
        (let* ((binary (path-expand "bin/representation-startup" root)) (before (modified binary)))
          (check (string-contains (run-process [timeout "--signal=TERM" "--kill-after=3s"
            "10s" binary "-:max-heap=1G,debug=q"]) "42") ? integer?)
          (command checks '("build") "2" "30s" root)
          (check-equal? (modified binary) before)
          (command checks '("clean") "2" "30s" root)
          (check (file-exists? binary) => #f)))))))
