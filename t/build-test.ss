;;; Standard build declarations and resolved imports; no requested runtime evaluation.
(export build-test)
(import (only-in :gerbil/expander import-module expander-context-id module-context-import
          module-context? module-import? module-import-source module-export-context
          import-set? import-set-source)
        :std/test :std/error (only-in :std/misc/process run-process)
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :std/misc/ports read-all-as-string)
        (only-in :std/encoding/json string->json JSONReadOptions) (only-in :std/list/list delete-duplicates/hash) (only-in "build.ss" test-build-spec test-build-partitions call-with-build-jobs))

(def build-test
  (test-suite "standard test package declarations"
    (test-case "kernel host policy is a tracked standard compiler input"
      (def policy (path-expand "testing/property/build.scm"))
      (def policy-source (call-with-input-file policy read-all-as-string))
      (call-with-temporary-directory "kernel-input-" (lambda (project)
        (create-directory* (path-expand "examples/property-kernel" project))
        (create-directory* (path-expand "testing/property" project))
        (copy-file policy (path-expand "testing/property/build.scm" project))
        (call-with-output-file (path-expand "gerbil.pkg" project)
          (lambda (port) (write '(package: clan/poo/testing) port)))
        (call-with-output-file (path-expand "examples/property-kernel.ss" project)
          (lambda (port) (write '(export value) port) (newline port)
            (write '(include "property-kernel/cases.scm") port) (newline port)))
        (call-with-output-file (path-expand "examples/property-kernel/cases.scm" project)
          (lambda (port) (write '(def value 7) port) (newline port)))
        (call-with-output-file (path-expand "build.ss" project)
          (lambda (port)
            (display "#!/usr/bin/env -S gxi -:max-heap=1G,debug=q\n" port)
            (for-each (lambda (form) (write form port) (newline port))
              '((import :std/build-script) (include "testing/property/build.scm")
                (defbuild-script (list property-kernel-build-spec))))))
        (run-process ["chmod" "755" (path-expand "build.ss" project)])
        (def options (getenv "GAMBOPT" ""))
        (def bounded (string-append "GAMBOPT=" options
          (if (equal? options "") "" ",") "max-heap=1G,debug=q"))
        ;; Standard fresh build processes own expansion and pending-job cleanup.
        ;; Existing worker settings and the outer source-test watchdog apply.
        (def (build)
          (run-process ["env" (string-append "GERBIL_PATH=" (path-expand "package" project)) bounded
                        "gerbil" "-:max-heap=1G,debug=q" "build"]
            directory: project stdout-redirection: #f stderr-redirection: #f))
        (def target (path-expand "package/lib/clan/poo/testing/examples/property-kernel.ssi" project))
        (build)
        (def before (file-info-last-modification-time (file-info target)))
        (build)
        (check (time->seconds (file-info-last-modification-time (file-info target))) => (time->seconds before))
        (call-with-output-file (path-expand "testing/property/build.scm" project)
          (lambda (port) (display policy-source port) (display "\n;; changed compiler-policy source\n" port)))
        (build)
        (check (> (time->seconds (file-info-last-modification-time (file-info target)))
                   (time->seconds before)) => #t))))
    (test-case "shared graph preserves included-source dependencies and package order"
      (let (complete (test-build-spec))
        (check (and (member '(gxc: "collection-order/table-cursor-test"
          (extra-inputs: ("collection-order/../build.ss"))) complete) #t) => #t)
        (check (and (member '(gxc: "collection-order/table-order-test"
          (extra-inputs: ("collection-order/../build.ss"
                          "collection-order/table-order/observations.scm"))) complete) #t) => #t)
        (check (and (member '(gxc: "collection-updates/table-mapping-test"
          (extra-inputs: ("collection-updates/../build.ss"
                          "collection-updates/table-mapping/composition.scm"
                          "collection-updates/table-mapping/retraction.scm"))) complete) #t) => #t))
      (check (test-build-spec "collection-order") =>
        '((gxc: "rationaldict-order-test" (extra-inputs: ("../build.ss")))
          (gxc: "table-cursor-test" (extra-inputs: ("../build.ss")))
          (gxc: "table-order-test" (extra-inputs: ("../build.ss" "table-order/observations.scm")))
          (gxc: "table-split-test" (extra-inputs: ("../build.ss"))))))
    (test-case "compiler partitions cover every existing package exactly once"
      (let* ((parts (test-build-partitions))
             (groups (apply append (map cdr parts)))
             (all (test-build-spec)))
        (check (test-build-spec "collection-deltas") =>
          '((gxc: "table-batch-test" (extra-inputs: ("../build.ss" "table-batch/capture.scm"
            "table-batch/origins.scm" "table-batch/transport.scm")))))
        (check (test-build-spec "recovery") =>
          '((gxc: "coordinator-interleaving-test" (extra-inputs: ("../build.ss")))))
        (check (length parts) => 4)
        (check (length all) => 62)
        (check (length groups) => 25)
        (check (length (delete-duplicates/hash groups)) => (length groups))
        (check (apply + (map (lambda (group) (length (test-build-spec group))) groups)) => (length all))))
    (test-case "standard Just dependencies share four bounded graphs for build and cleanup"
      (def graph (string->json (run-process ["just" "--dump" "--dump-format" "json"])
        (JSONReadOptions key-as-symbol: #f array-as-vector: #f object-as-hash: #t)))
      (def recipes (hash-ref graph "recipes"))
      (def entry (hash-ref recipes "_build-test-packages"))
      (check (hash-ref entry "attributes") => '("parallel"))
      (check (map (cut hash-ref <> "recipe") (hash-ref entry "dependencies")) =>
        '("_build-test-package" "_build-test-package" "_build-test-package" "_build-test-package"))
      ;; Build and failure cleanup share this one standard dependency graph.
      (check (map (cut hash-ref <> "arguments") (hash-ref entry "dependencies")) =>
        '(("contracts" ("variable" "action")) ("types" ("variable" "action"))
          ("prototypes" ("variable" "action")) ("collections" ("variable" "action"))))
      (check (hash-key? recipes "_build-test-prototypes") => #f)
      (check (hash-key? recipes "_build-test-publication") => #f))
    (test-case "shared build cleanup retains values failure identity and single evaluation"
      (check (call-with-values (lambda () (call-with-build-jobs (lambda () (values 1 #f)))) list) => '(1 #f))
      (def calls 0) (def cause (with-catch values (lambda () (error "original build refusal"))))
      (def caught (with-catch values (lambda ()
        (call-with-build-jobs (lambda () (set! calls (+ calls 1)) (raise cause))))))
      (check-eq? caught cause)
      (check calls => 1))
    (test-case "compiler observations identify shared IO and typed property imports"
      ;; Observe already-resolved public descriptors only. There is no source
      ;; scan, recursive resolver, loader substitution or private compiler entry.
      (def (source entry)
        (cond ((module-context? entry) entry)
              ((import-set? entry) (import-set-source entry))
              ((module-import? entry) (module-export-context (module-import-source entry)))
              (else (error "unexpected resolved import descriptor" entry))))
      (for-each (lambda (owner)
        (def dependencies (map (lambda (entry) (expander-context-id (source entry)))
          (module-context-import (import-module (car owner) #f #f))))
        (check (and (memq (cdr owner) dependencies) #t) => #t)
        (check (and (memq 'clan/poo/testing/type dependencies) #t) => #f))
        '((:clan/poo/debug . clan/poo/io)
          (:clan/poo/support/testing . clan/poo/support/io))))
    (test-case "unknown package refuses instead of silently dropping checks"
      (check-exception (test-build-spec "not-a-declared-package") Error?))
    (test-case "shared test compiler policy invalidates outputs without source edits"
      (call-with-temporary-directory "test-policy-input-" (lambda (project)
        (def directory (path-expand "t/recovery" project))
        (def policy (path-expand "t/build.ss" project))
        (create-directory* directory)
        (copy-file "t/build.ss" policy)
        (copy-file "t/recovery/build.ss" (path-expand "build.ss" directory))
        (run-process ["chmod" "755" (path-expand "build.ss" directory)])
        (call-with-output-file (path-expand "gerbil.pkg" directory)
          (lambda (port) (write '(package: clan/poo/t/recovery) port)))
        (call-with-output-file (path-expand "coordinator-interleaving-test.ss" directory)
          (lambda (port) (write '(export value) port) (newline port)
            (write '(def value 7) port) (newline port)))
        ;; Use the unchanged package script and its ordinary compiler cleanup.
        (def (build)
          (run-process ["env" (string-append "GERBIL_PATH=" (path-expand "package" project))
                        "gerbil" "-:max-heap=1G,debug=q" "build"]
            directory: directory stdout-redirection: #f stderr-redirection: #f))
        (def target (path-expand "package/lib/clan/poo/t/recovery/coordinator-interleaving-test.ssi" project))
        (build)
        (def before (time->seconds (file-info-last-modification-time (file-info target))))
        (build)
        (check-equal? (time->seconds (file-info-last-modification-time (file-info target))) before)
        (call-with-output-file [path: policy append: #t]
          (lambda (port) (display "\n;; changed shared test compiler policy\n" port)))
        (build)
        (check (> (time->seconds (file-info-last-modification-time (file-info target))) before) => #t))))
))
