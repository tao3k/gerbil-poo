;;; Cache admission and complete, disjoint compilation ownership.
(export build-test)
(import (only-in :std/misc/process run-process) (only-in :std/misc/ports read-all-as-lines) :gerbil/expander (only-in :gerbil/compiler/compile apply-generate-loader) :std/test :std/io/tempfile :std/iter (only-in :std/list/list append-map delete-duplicates/hash take)
  (only-in "test-groups.ss" test-files test-batch checked-groups)
  (only-in "build-artifacts.ss" artifact-key-valid? artifact-root group-root check-all
    group-source-key)
  (only-in "build-spec.ss" build-request consumer-request library-modules))
;; Exercise source/group boundaries independently of the Actions cache backend.
(def build-test
  (test-suite "compiled group source admission"
    (test-case "runner retains the complete standard expander dependency and harness identity"
      (def runner (import-module (path-expand "lib/clan/poo/t/test-runner.ssi" (gerbil-path)) #f #f))
      (def imports (module-context-import runner))
      (def grouped (filter (lambda (entry) (and (import-set? entry)
        (eq? (expander-context-id (import-set-source entry)) 'gerbil/expander))) imports))
      ;; Grouping must keep the entire facade as a dependency, not just used leaves.
      (check-equal? (length grouped) 1)
      (check (eq? (import-set-source (car grouped)) (import-module ':gerbil/expander #f #f)) => #t)
      (def harness (filter (lambda (entry) (and (module-import? entry)
        (eq? (module-import-name entry) 'tests.main))) imports))
      (check-equal? (length harness) 1)
      (def entry (module-import-source (car harness)))
      (check (eq? (module-export-context entry) (import-module ':gerbil/tools/gxtest #f #f)) => #t)
      (check-equal? (module-export-name entry) 'main))
    (test-case "selected aliases retain facade dependencies and exact public exports"
      (def checked 0)
      (for (spec (car (build-request '("library"))))
        (when (and (string? spec) (or (string-prefix? "examples/" spec) (string-prefix? "t/" spec)))
          (let* ((path (path-expand (string-append "lib/clan/poo/" spec ".ssi") (gerbil-path)))
                 (context (import-module path #f #f)) (imports (module-context-import context)))
            (for (facade (filter module-context? imports))
              ;; The runtime-only import retains initialization and whole-module freshness.
              (def aliases (filter (lambda (entry) (and (module-import? entry)
                (eq? (module-export-context (module-import-source entry)) facade)
                (not (eq? (module-import-name entry) (module-export-name (module-import-source entry)))))) imports))
              (when (pair? aliases)
                ;; The official loader emits the same initialization for a full
                ;; prefixed interface and a retained facade with selected aliases.
                (check-equal?
                  (apply-generate-loader (cons '%#import
                    (map core-module-export->import (module-context-export facade))))
                  (apply-generate-loader (cons '%#import (cons facade aliases)))))
              (for (entry aliases)
                (check (and (memq (module-import-source entry) (module-context-export facade)) #t) => #t)
                (set! checked (+ checked 1)))))))
      (check (> checked 0) => #t))
    (test-case "local compiler batches cover the unchanged CI inventory exactly once"
      (for (count '(1 2 4))
        (def batches (for/collect (index (in-range count)) (test-batch index count)))
        (def files (append-map values batches))
        (check-equal? (list-sort string<? files) (test-files))
        (check-equal? (length files) (length (delete-duplicates/hash files))))
      (for-each (lambda (index) (check-exception (test-batch index) true))
        '(-1 4 0.5 #f "0"))
      (for-each (lambda (count) (check-exception (test-batch 0 count) true))
        '(0 -1 0.5 #f "4" 10000)))
    (test-case "standard build options and explicit output flow through inventory selection"
      (def library (car (build-request '("library" "spec"))))
      (check-equal? (car (build-request '("spec"))) library)
      (check-equal? (car (build-request '("compile"))) library)
      (check-equal? (car (build-request '("clean"))) library)
      (check-equal? (caddr (build-request '("compile" "--release"))) '("compile" "--release"))
      (check-equal? (cdr (build-request '("tests" "objects" "/tmp/poo-test-output" "compile" "--debug")))
        '("/tmp/poo-test-output" ("compile" "--debug")))
      (check-equal? (car (build-request '("tests" "objects" "/tmp/poo-test-output")))
        (map path-strip-extension (test-files "objects")))
      (check-equal? (car (build-request '("batch" "2"))) (map path-strip-extension (test-batch 2)))
      (check (and (member "object" (library-modules)) #t) => #t)
      (check (andmap (lambda (file) (not (or (string-prefix? "examples/" file)
        (string-prefix? "t/" file)))) (library-modules)) => #t)
      (check-equal? (take (caar (consumer-request '("test-program" "spec"))) 2) '(exe: "test-program"))
      (check-equal? (caddr (consumer-request '("test-program" "compile" "--debug"))) '("compile" "--debug"))
      (check-equal? (car (consumer-request '("benchmark" "collection-paired-benchmark")))
        '("collection-paired-benchmark"))
      (check-equal? (caddr (consumer-request '("benchmark" "collection-paired-benchmark" "compile" "--debug")))
        '("compile" "--debug"))
      (check-equal? (take (caar (consumer-request '("benchmark" "factory-paired-benchmark"))) 2)
        '(exe: "factory-paired-benchmark"))
      (check-exception (consumer-request '("benchmark" "../outside")) true)
      (check-exception (build-request '("batch" "4")) true)
      (check-exception (build-request '("tests" "missing" "/tmp/poo-test-output")) true))
    (test-case "every test belongs to exactly one compilation group"
      (def files (append-map (lambda (group) (test-files (car group))) (checked-groups)))
      (check-equal? (length files) (length (delete-duplicates/hash files)))
      (check-equal? (list-sort string<? files) (test-files))
      (check-exception (test-files "not-a-test-group") true))
    (test-case "compiler-heavy protocols retain independent bounded groups"
      ;; Bound each known compiler-heavy family while the inventory test above
      ;; separately proves that no module was omitted or duplicated by grouping.
      (for-each (lambda (name)
        (def files (test-files name))
        (check (and (pair? files) (<= (length files) 6)) => #t))
        '("methods" "inference" "signatures" "scalars"))
      (check (and (member "t/container-inference-test.ss" (test-files "inference")) #t) => #t)
      (check (and (member "t/union-inference-test.ss" (test-files "scalars")) #t) => #t))
    (test-case "matching bytes permit reuse while all changed identity axes refuse"
      (def record '(test-group "objects" "compiler-and-library" "tests" "original-producer"))
      (check (artifact-key-valid? record "objects" "compiler-and-library" "tests") => #t)
      (check (artifact-key-valid? record "methods" "compiler-and-library" "tests") => #f)
      (check (artifact-key-valid? record "objects" "different-library" "tests") => #f)
      (check (artifact-key-valid? record "objects" "compiler-and-library" "revised-tests") => #f)
      (check (artifact-key-valid? '(test-group "objects" "compiler-and-library" "tests")
        "objects" "compiler-and-library" "tests") => #f)
      (check (artifact-key-valid? '(test-group "objects" "compiler-and-library" "tests" #f)
        "objects" "compiler-and-library" "tests") => #f))
    (test-case "assembly rejects missing interfaces stale revisions and extra group directories"
      ;; Empty interfaces exercise admission only; they are never executed as code.
      (call-with-temporary-directory "poo-build-admission-"
        (lambda (directory)
          (parameterize ((artifact-root (string-append directory "/")))
            ;; Write exactly one complete datum and close the standard file port.
            (def (save path value)
              (call-with-output-file (list path: path truncate: #t)
                (lambda (port) (write value port))))
            (for-each (lambda (group)
              (def name (car group)) (def root (group-root name))
              (for-each (lambda (file)
                (def path (path-expand
                  (string-append "lib/clan/poo/" (path-strip-extension file) ".ssi") root))
                (create-directory* (path-directory path)) (save path 'interface-fixture)) (cdr group))
              (save (path-expand "source.scm" root) (list 'test-group name "base" (group-source-key name) "producer"))
              (save (path-expand "revision.scm" root) "current")) (checked-groups))
            (check (begin (check-all "base" "current") #t) => #t)
            (def root (group-root "objects"))
            (save (path-expand "revision.scm" root) "old")
            (check-exception (check-all "base" "current") true)
            (save (path-expand "revision.scm" root) "current")
            (delete-file (path-expand "lib/clan/poo/t/object-test.ssi" root))
            (check-exception (check-all "base" "current") true)
            (save (path-expand "lib/clan/poo/t/object-test.ssi" root) 'interface-fixture)
            (create-directory (group-root "unexpected"))
            (check-exception (check-all "base" "current") true)))))
    (test-case "admitted collection entry constructs one consumer and retains the full study"
      ;; Ask Just to resolve the real recipe graph, without starting compilers.
      (def (commands recipe)
        (call-with-input-string
          (run-process ["just" "--dry-run" recipe "2" "1" "4"] stderr-redirection: #t)
          read-all-as-lines))
      (def admitted (commands "_check-collections"))
      (def standalone (commands "benchmark-collections"))
      ;; The producer owns library freshness; the admitted entry owns one consumer.
      (check-equal? (filter (cut string-prefix? "set -- " <>) admitted) '("set -- test-program"))
      (check-equal? (filter (cut string-prefix? "set -- " <>) standalone)
        '("set -- library" "set -- test-program"))
      (for (lines (list admitted standalone))
        (check-equal? (length (filter
          (cut string-suffix? "build.ss benchmark \"collection-paired-benchmark\"" <>) lines)) 1)
        (check-equal? (length (filter
          (cut string-suffix? "benchmark collection-paired-benchmark \"2\" \"1\" \"4\"" <>) lines)) 1))
      ;; All modules still run through the existing bounded single-process harness.
      (check-equal? (length (filter
        (cut string-suffix? "test_command=(\"$GERBIL_PATH/bin/test-program\" \"-:max-heap=1G,debug=q\" \"t\")" <>) admitted)) 1)
      (check-equal? (length (filter
        (cut string-suffix? "300s \"${test_command[@]}\" 2>&1 | tee \"$test_log\"" <>) admitted)) 1))
    (test-case "source keys cover each full group and preserve the checked inventory"
      (for-each (lambda (group)
        (def key (group-source-key (car group)))
        (check-equal? (string-length key) 64)
        (check-equal? key (group-source-key (car group)))) (checked-groups)))))
