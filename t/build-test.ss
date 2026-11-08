;;; Standard build declarations and resolved imports; no requested runtime evaluation.
(export build-test)
(import (only-in :gerbil/expander import-module expander-context-id module-context-import
          module-context? module-import? module-import-source module-export-context
          import-set? import-set-source)
        :std/test :std/error :std/iter (only-in :std/text/pregexp pregexp-match) (only-in :std/make make) (only-in :std/misc/process run-process)
        (only-in :std/io/tempfile call-with-temporary-directory)
        (only-in :std/misc/ports read-all-as-string)
        (prefix-in (only-in "../build.ss" main) root.)
        (prefix-in (only-in "../build-development.ss" main) development.)
        (only-in :std/encoding/json string->json JSONReadOptions) (only-in :std/list/list delete-duplicates/hash take drop) (only-in "build.ss" test-build-spec test-build-partitions call-with-build-jobs))

;; Preserve the declaration/input projection independently of backend flags;
;; a separate assertion checks each root has one tracked compiler policy.
(def (build-inputs specs) (map (cut take <> 3) specs))

(include "../testing/property/build.scm")

;; Re-enter standard make after the fixture's CLI build. Bound its backend
;; children and drain them before restoring the caller's options, on success
;; and refusal; the test process retains its existing heap ceiling.
(def (make-fixture spec directory libdir heap)
  (def options (getenv "GAMBOPT" #f))
  (try
    (setenv "GAMBOPT" (string-append (or options "")
      (if (or (not options) (equal? options "")) "" ",") "max-heap=" heap ",debug=q"))
    (call-with-build-jobs
      (lambda () (make spec srcdir: directory libdir: libdir)))
    (finally (setenv "GAMBOPT" options))))

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
        (def options (getenv "GAMBOPT" #f))
        (def bounded (string-append (or options "")
          (if (or (not options) (equal? options "")) "" ",") "max-heap=1G,debug=q"))
        ;; Qualify the public build entry once, then reuse its standard owner
        ;; for the same unchanged-input and revised-input checks.
        (run-process ["env" (string-append "GERBIL_PATH=" (path-expand "package" project))
                      (string-append "GAMBOPT=" bounded) "gerbil" "-:max-heap=1G,debug=q" "build"]
          directory: project stdout-redirection: #f stderr-redirection: #f)
        ;; Preserve the original backend bound while reusing prepared outputs.
        (def build (cut make-fixture [property-kernel-build-spec]
          project (path-expand "package/lib" project) "1G"))
        (def target (path-expand "package/lib/clan/poo/testing/examples/property-kernel.ssi" project))
        (def before (file-info-last-modification-time (file-info target)))
        (build)
        (check (time->seconds (file-info-last-modification-time (file-info target))) => (time->seconds before))
        ;; Fast reuse may finish within a filesystem tick. Wait relatively:
        ;; a filesystem timestamp is not an absolute VM sleep deadline. The
        ;; strict timestamp assertion below still admits the actual ordering.
        (thread-sleep! 1.1)
        (call-with-output-file (path-expand "testing/property/build.scm" project)
          (lambda (port) (display policy-source port) (display "\n;; changed compiler-policy source\n" port)))
        (check (> (time->seconds (file-info-last-modification-time
          (file-info (path-expand "testing/property/build.scm" project))))
          (time->seconds before)) => #t)
        (build)
        (check (> (time->seconds (file-info-last-modification-time (file-info target)))
                   (time->seconds before)) => #t))))
    (test-case "standard build metadata exclude progress output"
      ;; Consume one datum from the generated build protocol; never evaluate it
      ;; or reconstruct the compiler's dependency graph.
      (def (metadata entry . commands)
        (call-with-input-string (with-output-to-string (lambda () (apply entry commands)))
          (lambda (port)
            (def value (read port))
            (check (eof-object? (read port)) => #t)
            value)))
      (def (executables spec)
        (map cadr (filter (lambda (entry)
          (and (pair? entry) (eq? (car entry) exe:))) spec)))
      (for-each (lambda (entry)
        (check-equal? (metadata entry "meta") '("spec" "compile" "clean")))
        (list root.main development.main))
      (def core (metadata root.main "spec"))
      (def development (metadata development.main "spec"))
      (def graph-study (metadata development.main "graph" "spec"))
      ;; The focused study retains the entire core/compiler policy, and selects
      ;; only these declared study inputs. It never builds a representation exe.
      (check-equal? (take graph-study (length core)) core)
      (check-equal? (executables graph-study) '())
      (check-equal? (map cadr (drop graph-study (length core)))
        '("examples/object-contracts" "examples/contract-publication"
          "examples/recursive-validation" "examples/recursive-revision"
          "examples/recursive-migration" "examples/recursive-topology"
          "examples/recursive-staging" "examples/recursive-restaging"
          "examples/recursive-publication" "examples/recursive-approvals"
          "examples/recursive-competition" "examples/recursive-submissions"
          "examples/recursive-recovery" "examples/recursive-coordination"
          "examples/closed-declarations" "examples/component-services"
          "benchmarks/closure-measure" "t/feedback/graph-algorithms-test"
          "t/feedback/feedback-graph-test" "t/construction/graph-order-repair-test"
          "t/contracts/recursive-approvals-test" "t/contracts/recursive-validation-test"))
      (check (list? core) => #t)
      (check (list? development) => #t)
      (check-equal? (executables core) '())
      ;; Darwin shares the executable's static objects in the development graph.
      (check (executables development)
        => (cond-expand (darwin '("examples/representation-main")) (else '())))
      (check (member "examples/generated-batches" (map cadr core)) => #f)
      (check (and (member "examples/generated-batches" (map cadr development)) #t) => #t))
    (test-case "shared graph preserves included-source dependencies and package order"
      (let (complete (build-inputs (test-build-spec)))
        (check (and (member '(gxc: "collection-order/table-cursor-test"
          (extra-inputs: ("collection-order/../build.ss"))) complete) #t) => #t)
        (check (and (member '(gxc: "collection-order/table-order-test"
          (extra-inputs: ("collection-order/../build.ss"
                          "collection-order/table-order/observations.scm"))) complete) #t) => #t)
        (check (and (member '(gxc: "collection-updates/table-mapping-test"
          (extra-inputs: ("collection-updates/../build.ss"
                          "collection-updates/table-mapping/composition.scm"
                          "collection-updates/table-mapping/retraction.scm"))) complete) #t) => #t))
      (check (build-inputs (test-build-spec "collection-order")) =>
        '((gxc: "rationaldict-order-test" (extra-inputs: ("../build.ss")))
          (gxc: "table-cursor-test" (extra-inputs: ("../build.ss")))
          (gxc: "table-order-test" (extra-inputs: ("../build.ss" "table-order/observations.scm")))
          (gxc: "table-split-test" (extra-inputs: ("../build.ss"))))))
    (test-case "compiler partitions cover every existing package exactly once"
      (let* ((parts (test-build-partitions))
             (groups (apply append (map cdr parts)))
             (all (test-build-spec)))
        (check (build-inputs (test-build-spec "collection-deltas")) =>
          '((gxc: "table-batch-test" (extra-inputs: ("../build.ss" "table-batch/capture.scm"
            "table-batch/origins.scm" "table-batch/transport.scm")))))
        (check (build-inputs (test-build-spec "recovery")) =>
          '((gxc: "coordinator-interleaving-test" (extra-inputs: ("../build.ss")))))
        (check (length parts) => 4)
        (check (length all) => 70)
        ;; Original roots, byte-I/O, FUN and the two Graph acceptance roots.
        (check (length (filter (lambda (spec) (string-suffix? "-test" (cadr spec))) all)) => 66)
        (for (name '("construction/graph-order-repair-test" "feedback/graph-algorithms-test"))
          (check (and (member name (map cadr all)) #t) => #t))
        ;; Grouping cannot leave any root unbounded or duplicate its policy.
        (for (spec all)
          (check-equal? (length (filter (cut equal? <> "-cc-options") (drop spec 3))) 1)
          (check-equal? (drop spec 3)
            (if (equal? (cadr spec) "feedback/graph-algorithms-test")
              '("-cc-options" "-O2 -D___SINGLE_HOST_LIMIT=4096")
              '("-cc-options" "-Og -D___SINGLE_HOST_LIMIT=4096"))))
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
      ;; The parallel runner uses the identical declared partitions, with every
      ;; existing suite exactly once and no independently maintained inventory.
      (def tests (hash-ref recipes "_test-packages"))
      (check (hash-ref tests "attributes") => '("parallel"))
      (check (map (cut hash-ref <> "recipe") (hash-ref tests "dependencies")) =>
        '("_test-groups" "_test-groups" "_test-groups" "_test-groups"))
      (check (map (cut hash-ref <> "arguments") (hash-ref tests "dependencies")) =>
        (map cdr (test-build-partitions)))
      ;; Sharing import contexts changes no package membership or suite coverage.
      (def shared (hash-ref recipes "_test-shared-packages"))
      (check (hash-ref shared "attributes") => '("parallel"))
      (check (map (cut hash-ref <> "arguments") (hash-ref shared "dependencies")) =>
        (let (parts (map cdr (test-build-partitions)))
          (list (append (list-ref parts 0)
                  (map (lambda (group)
                         (if (equal? group "representations") "representations/!collection-testing" group))
                       (list-ref parts 3)))
                (append (list-ref parts 1) (list-ref parts 2) '("representations/collection-testing")))))
      (check (hash-key? recipes "_build-test-prototypes") => #f)
      (check (hash-key? recipes "_build-test-publication") => #f))
    (test-case "failed root builds clear partial standard make markers before retry"
      (def task-file (path-expand "justfile"))
      (call-with-temporary-directory "root-refusal-" (lambda (project)
        ;; Keep the actual layout preflight inputs, not empty stand-ins. Only
        ;; the tiny standard fixture below belongs to this build declaration.
        (for (file '("testing/type.ss" "testing/function.ss" "testing/generation-graph.ss"
                     "testing/recursive-generation.ss" "testing/property.ss"
                     "testing/property/generator.ss" "testing/property/model.ss"
                     "testing/property/replay.ss" "testing/property/test.ss"))
          (def target (path-expand file project))
          (create-directory* (path-directory target)) (copy-file file target))
        (call-with-output-file (path-expand "gerbil.pkg" project)
          (lambda (port) (write '(package: clan/poo/testing) port)))
        (call-with-output-file (path-expand "build.ss" project)
          (lambda (port)
            (display "#!/usr/bin/env -S gxi -:max-heap=2G,debug=q\n" port)
            (write '(import :std/build-script) port) (newline port)
            (write '(defbuild-script ["broken"]) port) (newline port)))
        (run-process ["chmod" "755" (path-expand "build.ss" project)])
        (call-with-output-file (path-expand "broken.ss" project)
          (lambda (port)
            (write '(export value) port) (newline port)
            (write '(begin-foreign (c-declare "#error expected-backend-refusal")) port) (newline port)
            (write '(def value #f) port) (newline port)))
        ;; An interrupted Gerbil invocation can leave this compiler-owned
        ;; marker. The public build must refuse before starting another compiler.
        (let* ((static (path-expand "package/lib/static" project))
               (lock (path-expand "clan__poo__testing__broken.o.lock" static))
               (status #f))
          (create-directory* static)
          (call-with-output-file lock void)
          (let (output (run-process
            ["env" (string-append "GERBIL_PATH=" (path-expand "package" project))
             "just" "--justfile" task-file "--working-directory" project "build-core"]
            directory: project stderr-redirection: #t
            check-status: (lambda (code _settings) (set! status code))))
            (check (and (exact-integer? status) (not (zero? status))) => #t)
            (check (and (pregexp-match "BUILD-LOCK" output) #t) => #t)
            (check (pregexp-match "BUILD-CONCURRENCY" output) => #f)
            (check (file-exists? lock) => #t))
          (delete-file lock))
        (for (_ (in-range 2))
          (def status #f)
          ;; The real public compiler must fail BOTH attempts, never admit
          ;; the first attempt's early .ssi/static Scheme files as completion.
          (def output (run-process
            ["env" (string-append "GERBIL_PATH=" (path-expand "package" project))
             "just" "--justfile" task-file "--working-directory" project "build-core"]
            directory: project stderr-redirection: #t
            check-status: (lambda (code _settings) (set! status code))))
          (check (and (exact-integer? status) (not (zero? status))) => #t)
          (check (and (pregexp-match "expected-backend-refusal" output) #t) => #t)
          (check (file-exists? (path-expand "package/lib/clan/poo/testing/broken.ssi" project)) => #f)
          (check (file-exists? (path-expand "package/lib/static/clan__poo__testing__broken.scm" project)) => #f)
          (check (and (pregexp-match "BUILD-CLEANUP root-preparation status=" output) #t) => #t)))))
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
        ;; Qualify the unchanged package script once, including its cleanup.
        (run-process ["env" (string-append "GERBIL_PATH=" (path-expand "package" project))
                      "gerbil" "-:max-heap=1G,debug=q" "build"]
          directory: directory stdout-redirection: #f stderr-redirection: #f)
        ;; Preserve its two-GiB backend policy for the same freshness checks.
        (def build (cut make-fixture (test-build-spec "recovery")
          directory (path-expand "package/lib" project) "2G"))
        (def target (path-expand "package/lib/clan/poo/t/recovery/coordinator-interleaving-test.ssi" project))
        (def before (time->seconds (file-info-last-modification-time (file-info target))))
        (build)
        (check-equal? (time->seconds (file-info-last-modification-time (file-info target))) before)
        ;; Cross a filesystem tick with a relative wait, then require make's
        ;; strict timestamp premise instead of trusting the wait itself.
        (thread-sleep! 1.1)
        (call-with-output-file [path: policy append: #t]
          (lambda (port) (display "\n;; changed shared test compiler policy\n" port)))
        (check (> (time->seconds (file-info-last-modification-time (file-info policy))) before) => #t)
        (build)
        (check (> (time->seconds (file-info-last-modification-time (file-info target))) before) => #t))))
))
