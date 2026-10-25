;;; Cache admission and complete, disjoint compilation ownership.
(export build-test)
(import (only-in :gerbil/runtime/loader load-module)
  (only-in :std/misc/process run-process process-error?) (only-in :std/misc/ports read-all-as-lines) :gerbil/expander (only-in :gerbil/compiler/compile apply-generate-loader) :std/test :std/io/tempfile :std/iter (only-in :std/list/list append-map delete-duplicates/hash take find)
  (only-in :std/error Error-irritants)
  (only-in "build.ss" run-build-stage)
  (only-in "test-groups.ss" test-files test-batch checked-groups compiled-library-module?)
  (only-in "build-artifacts.ss" artifact-key-valid? artifact-root group-root check-all
    group-source-key test-inventory-key)
  (only-in "build-spec.ss" build-request consumer-request library-modules clean-request))
;; Exercise source/group boundaries independently of the Actions cache backend.
(def build-test
  (test-suite "compiled group source admission"
    (test-case "collection case includes participate in standard make freshness"
      (def spec (car (build-request '("tests" "collections" "/tmp/poo-test-output"))))
      (check (and (member '(gxc: "t/table-mapping-test"
        (extra-inputs: ("t/table-mapping/composition.scm"))) spec) #t) => #t))
    (test-case "collection IO includes participate in standard library freshness"
      (for (mode '("library" "qualification"))
        (def spec (car (build-request (list mode))))
        (def table (find (lambda (entry)
          (and (pair? entry) (eq? (car entry) 'gxc:) (equal? (cadr entry) "table"))) spec))
        (match table
          ([gxc: "table" [extra-inputs: inputs] . _]
            (check (and (member "table/io.scm" inputs) #t) => #t)))))
    (test-case "runtime reuse requires the exact compiled library object"
      (def root "/tmp/poo-compiled-admission/")
      (check (compiled-library-module? "object" "/tmp/poo-compiled-admission/lib/clan/poo/object.o1" root) => #t)
      (check (compiled-library-module? "types/relation" "/tmp/poo-compiled-admission/lib/clan/poo/types/relation.o12" root) => #t)
      (for-each (lambda (loaded)
        (check (compiled-library-module? "object" loaded root) => #f))
        '(builtin #f "/tmp/other/lib/clan/poo/object.o1"
          "/tmp/poo-compiled-admission/lib/clan/poo/object.scm"
          "/tmp/poo-compiled-admission/lib/clan/poo/object.o"
          "/tmp/poo-compiled-admission/lib/clan/poo/object.o0"
          "/tmp/poo-compiled-admission/lib/clan/poo/object.o1x"
          "/tmp/poo-compiled-admission/lib/clan/poo/other.o1"))
      ;; A real Linux acceptance run must reuse the initialized library bundle;
      ;; Darwin's executable intentionally registers that same module as builtin.
      (cond-expand
        (darwin (void))
        (else
         (check (compiled-library-module? "types/relation"
                  (load-module "clan/poo/types/relation") (gerbil-path)) => #t))))
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
      (for (spec (car (build-request '("qualification"))))
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
      (for (count '(1 2 4 8))
        (def batches (for/collect (index (in-range count)) (test-batch index count)))
        (def files (append-map values batches))
        (check-equal? (list-sort string<? files) (test-files))
        (check-equal? (length files) (length (delete-duplicates/hash files))))
      (for-each (lambda (index) (check-exception (test-batch index) true))
        '(-1 8 0.5 #f "0"))
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
      (def tests (car (build-request '("tests" "objects" "/tmp/poo-test-output"))))
      (for (file (test-files "objects"))
        (check (and (member (path-strip-extension file) tests) #t) => #t))
      (def batch (car (build-request '("batch" "2"))))
      ;; Standard gxc specifications retain extra inputs; compare module roots
      ;; independently of which numbered batch receives that declaration.
      (def (name item) (if (string? item) item (cadr item)))
      (for (file (test-batch 2))
        (check (and (member (path-strip-extension file) (map name batch)) #t) => #t))
      (def complete (car (build-request '("qualification" "spec"))))
      (check-equal? (map name library) (library-modules))
      (for (item complete)
        (check (and (or (member item library)
                        (string-prefix? "examples/" (name item))
                        (string-prefix? "t/" (name item))) #t) => #t))
      (for (item library)
        (check (and (member item complete) #t) => #t))
      (check-equal? (length tests) (length (delete-duplicates/hash tests)))
      ;; Shared support retains complete qualification, without a second compile
      ;; into every isolated group. The ordinary loader still resolves its SSI.
      (for (support '("t/test-runner" "t/table-testing" "t/factory-benchmark"))
        (check (and (member support complete) #t) => #t)
        (check (and (member support tests) #t) => #f)
        (check (and (member support batch) #t) => #f))
      (for (group (checked-groups))
        (def selected (map name (car (build-request ["tests" (car group) "/tmp/poo-test-output"]))))
        (check-equal? selected (map path-strip-extension (test-files (car group)))))
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
      (check-exception (build-request '("batch" "8")) true)
      (check-exception (build-request '("tests" "missing" "/tmp/poo-test-output")) true))
    (test-case "a timed-out producer is cleaned before a standard build retry"
      (call-with-temporary-directory "poo-build-recovery-" (lambda (root)
        (def lib (path-expand "lib/" root))
        (def metadata (path-expand "build-recovery/unit.ssi" lib))
        (def static (path-expand "static/build-recovery__unit.scm" lib))
        (def marker (path-expand "interrupt" root))
        (def ready (path-expand "produced" root))
        (def wrapper (path-expand "timeout" root))
        ;; Let the standard runner expose this runtime's exit-status representation.
        (def timeout-status (run-process ["sh" "-c" "exit 124"]
          check-status: #f coprocess: process-status))
        (def timeout (car (run-process ["sh" "-c" "command -v gtimeout || command -v timeout"] coprocess: read-all-as-lines)))
        ;; Fixture code uses the ordinary build macro; only its interrupted branch
        ;; creates early outputs, exactly the metadata-before-backend failure shape.
        (def (write-forms name forms)
          (call-with-output-file (path-expand name root) (lambda (port)
            (for-each (lambda (form) (write form port) (newline port)) forms))))
        (write-forms "gerbil.pkg" '((package: build-recovery)))
        (write-forms "unit.ss" '((export value) (def value 42)))
        (write-forms "interrupt" '(#t))
        (write-forms "build.ss"
          `((import :std/build-script)
            (def (build . args)
              (defbuild-script '("unit") libdir: ,lib) (apply main args))
            (def (main . args)
              (if (or (equal? args '("clean")) (not (file-exists? ,marker)))
                (apply build args)
                (begin
                  (for-each (lambda (file)
                    (create-directory* (path-directory file))
                    (call-with-output-file file (lambda (port) (display "partial" port))))
                    (list ,metadata ,static))
                  (call-with-output-file ,ready (lambda (port) (write #t port)))
                  (displayln "PARTIAL-BUILD-READY") (force-output)
                  (thread-sleep! 30))))))
        ;; Shorten only the fixture timeout executable; the production boundary
        ;; still sends its unchanged 300s argument. No test sleeps for five minutes.
        (call-with-output-file wrapper (lambda (port)
          (display "#!/bin/sh\nshift 3\nexec " port) (write timeout port)
          (display " --signal=TERM --kill-after=3s 5s \"$@\"\n" port)))
        (run-process ["chmod" "755" wrapper])
        (check-exception (run-build-stage root wrapper "-:max-heap=1G,debug=q" 1 [])
          (lambda (cause) (and (process-error? cause) (= (cadr (Error-irritants cause)) timeout-status))))
        (check (file-exists? ready) => #t)
        (check (file-exists? metadata) => #f)
        (check (file-exists? static) => #f)
        (delete-file marker)
        (run-build-stage root timeout "-:max-heap=1G,debug=q" 0 [])
        (check (file-exists? metadata) => #t)
        (check (file-exists? static) => #t))))
    (test-case "failure recovery retains the standard target and strips compiler flags"
      (for-each (lambda (request expected) (check-equal? (clean-request request) expected))
        '(() ("compile" "--debug") ("library" "compile" "--release")
          ("qualification") ("tests" "collections" "/tmp/recovery-output" "compile" "--debug")
          ("batch" "2") ("test-program" "compile" "--debug")
          ("benchmark" "collection-paired-benchmark" "compile" "--release"))
        '(("clean") ("clean") ("library" "clean") ("qualification" "clean")
          ("tests" "collections" "/tmp/recovery-output" "clean")
          ("batch" "2" "clean") ("test-program" "clean")
          ("benchmark" "collection-paired-benchmark" "clean"))))
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
      (def linked (commands "_check-linked-collections"))
      ;; Observe actual bounded build invocations, rather than the old shell's
      ;; incidental set-- syntax. Construction count/target admission is unchanged.
      (def (targets lines)
        (map (lambda (line)
          (cond ((string-suffix? " test-program" line) 'test-program)
                ((string-suffix? " library" line) 'library)
                ((string-suffix? " benchmark \"collection-paired-benchmark\"" line) 'study)
                (else 'unexpected)))
          (filter (cut string-contains <> " t/build.ss ") lines)))
      (check-equal? (targets admitted) '(test-program study))
      (check-equal? (targets standalone) '(library test-program study))
      (check-equal? (targets linked) '(study))
      (for (lines (list admitted standalone linked))
        (check-equal? (length (filter
          (cut string-suffix? "\"90\" benchmark \"collection-paired-benchmark\"" <>) lines)) 1)
        (check-equal? (length (filter
          (cut string-suffix? "benchmark collection-paired-benchmark \"2\" \"1\" \"4\"" <>) lines)) 1))
      ;; Cache hits retain exactly the same bounded complete harness as misses.
      (for (lines (list admitted linked))
        (check-equal? (length (filter
          (cut string-suffix? "test_command=(\"$GERBIL_PATH/bin/test-program\" \"-:max-heap=1G,debug=q\" \"t\")" <>) lines)) 1)
        (check-equal? (length (filter
          (cut string-suffix? "300s \"${test_command[@]}\" 2>&1 | tee \"$test_log\"" <>) lines)) 1)))
    (test-case "consumer inventory reuse never replaces test-body or group admission"
      (def files (test-files))
      (def expected (test-inventory-key))
      (def group (caar (filter (lambda (group) (member (car files) (cdr group))) (checked-groups))))
      (call-with-temporary-directory "poo-linked-inventory-"
        (lambda (directory)
          (create-directory (path-expand "t/" directory))
          (parameterize ((current-directory directory))
            (for-each (lambda (file) (call-with-output-file file void)) files)
            (let (bodies (group-source-key group))
              (check-equal? (test-inventory-key) expected)
              (call-with-output-file (list path: (car files) truncate: #t)
                (lambda (port) (display ";; changed test body" port)))
              (check-equal? (test-inventory-key) expected)
              (check (not (equal? (group-source-key group) bodies)) => #t)
              (call-with-output-file "t/added-test.ss" void)
              (check (not (equal? (test-inventory-key) expected)) => #t)
              (delete-file "t/added-test.ss")
              (delete-file (car files))
              (check-exception (test-inventory-key) true))))))
    (test-case "source keys cover each full group and preserve the checked inventory"
      (for-each (lambda (group)
        (def key (group-source-key (car group)))
        (check-equal? (string-length key) 64)
        (check-equal? key (group-source-key (car group)))) (checked-groups)))))
