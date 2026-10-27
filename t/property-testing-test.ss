;;; Generated evidence exercises domains, replay, source invalidation and budgets.
(export property-testing-test property-kernel-test)
(import :std/test :std/error :std/iter :std/io/tempfile
        (only-in :std/misc/process run-process) (only-in :std/misc/ports read-all-as-lines) ../object ../mop ../type ../number
        ../testing/type ../testing/function
        (prefix-in ../examples/signature-service service.)
        (only-in ../examples/property-kernel property-kernel-test))

;; Deterministic fixture isolates shrinking from random trial distribution.
(def (fixed-integer value shrink (measure abs))
  (make-generator Integer (lambda (_random _size) value) shrink measure))
;; Materialize ordinary Gerbil source forms, keeping paths as data rather than shell text.
(def (write-program path forms)
  (call-with-output-file path (lambda (port)
    (for-each (lambda (form) (write form port) (newline port)) forms))))
;; An isolated standard project has only the generic modules and their example.
;; Its official GERBIL_PATH is empty of POO; compiler and runtime keep 1-GiB bounds.
(def (check-independent-library)
  (def source-root (current-directory))
  (def timeout (car (run-process ["sh" "-c" "command -v gtimeout || command -v timeout"]
    coprocess: read-all-as-lines)))
  (call-with-temporary-directory "property-library-" (lambda (project)
    (for-each (lambda (file)
      (copy-file (path-expand (string-append "testing/core/" file) source-root)
        (path-expand file project))) '("generator.ss" "property.ss" "model.ss" "build.ss" "gerbil.pkg"))
    (create-directory* (path-expand "examples" project))
    (copy-file (path-expand "examples/property-kernel.ss" source-root)
      (path-expand "examples/property-kernel.ss" project))
    (write-program (path-expand "test-build.ss" project)
      '((import :std/build-script) (defbuild-script '("examples/property-kernel"))))
    (def package (path-expand "package" project))
    (def artifact (path-expand "lib/clan/property-testing/examples/property-kernel.ssi" package))
    (write-program (path-expand "check.ss" project)
      (list '(import (prefix-in :gerbil/tools/gxtest tests.))
        (list 'exit (list 'tests.main "-v" "5" artifact))))
    ;; Standard process arguments and std/build-script own this isolated build.
    (def (run script)
      (run-process [timeout "--signal=TERM" "--kill-after=3s" "60s" "env"
        (string-append "GERBIL_PATH=" package) "GAMBOPT=max-heap=1G,debug=q"
        "gxi" "-:max-heap=1G,debug=q" script] directory: project stderr-redirection: #t))
    (run "build.ss")
    (run "test-build.ss")
    (check (file-exists? artifact) => #t)
    (check (file-exists? (path-expand "lib/clan/poo" package)) => #f)
    (def lines (string-split (run "check.ss") #\newline))
    ;; gxtest may print HARNESS-OK even with an error module, so require executed
    ;; case receipts and an error-free transcript, not merely process exit zero.
    (unless (= (length (filter (cut string-prefix? "CASE-OK " <>) lines)) 8)
      (error "independent suite did not execute all cases" lines))
    (check (and (member "OK" lines) #t) => #t)
    (check (ormap (cut string-prefix? "ERROR " <>) lines) => #f)
    (displayln "PROPERTY-LIBRARY-OK 8 cases; isolated stdlib-only compiled modules"))))

;; Every outcome is inspected; a test error never substitutes for a false property.
(def property-testing-test
  (test-suite "descriptor-driven finite tests and counterexample shrinking"
    (test-case "generic library builds and runs independently of POO" (check-independent-library))
    (test-case "standard seeded source replays a shrinking failure exactly"
      (let* ((report (check-property Integer (lambda (x) (< (abs x) 4)) seed: 42 cases: 200 size: 100))
             (again (replay-property report)))
        (check-equal? (.get report status) 'failed)
        (check-equal? (abs (.get report counterexample)) 4)
        (check-equal? (.get again original) (.get report original))
        (check-equal? (.get again counterexample) (.get report counterexample))
        (check-equal? (.get again attempts) (.get report attempts))
        (check (.get report minimal?) => #t)))
    (test-case "product and collection generation composes without global randomness"
      (let* ((descriptor (Tuple (List (Pair Integer Bool)) String UInt))
             (report (check-property descriptor (cut element? descriptor <>) seed: 19 cases: 50 size: 8)))
        (check-equal? (.get report status) 'passed)
        (check-equal? (.get report trial) 50)))
    (test-case "list shrinking preserves a valid false witness"
      (let* ((descriptor (List Integer))
             (report (check-property descriptor (lambda (xs) (every zero? xs)) seed: 8 cases: 100 size: 8)))
        (check-equal? (.get report status) 'failed)
        (check-equal? (length (.get report counterexample)) 1)
        (check-equal? (abs (car (.get report counterexample))) 1)))
    (test-case "invalid and nondecreasing proposals still consume finite fuel"
      (let* ((sampler (fixed-integer 10 (lambda (_) '(#f 10 11 0))))
             (report (check-property Integer (lambda (_) #f) sampler: sampler cases: 1 shrink-budget: 3)))
        (check-equal? (.get report status) 'failed)
        (check-equal? (.get report counterexample) 10)
        (check-equal? (.get report attempts) 3)
        (check (.get report minimal?) => #f)))
    (test-case "zero budget keeps the original failure and claims no minimum"
      (let (report (check-property Integer (lambda (_) #f) sampler: (fixed-integer 9 (lambda (_) '(0))) cases: 1 shrink-budget: 0))
        (check-equal? (.get report counterexample) 9)
        (check-equal? (.get report attempts) 0)
        (check (.get report minimal?) => #f)))
    (test-case "a shrink exception is retained as error, never a smaller failure"
      (let* ((cause (Error "shrink property"))
             (report (check-property Integer (lambda (x) (if (= x 0) (raise cause) #f))
                       sampler: (fixed-integer 5 (lambda (_) '(0))) cases: 1)))
        (check-equal? (.get report status) 'error)
        (check (eq? (.get report cause) cause) => #t)
        (check-equal? (.get report original) 5)))
    (test-case "invalid generation, nonboolean properties and invalid measures fail visibly"
      (check-equal? (.get (check-property Integer true sampler: (fixed-integer #f (lambda (_) []))) status) 'error)
      (check-equal? (.get (check-property Integer (lambda (_) 1)) status) 'error)
      (check-equal? (.get (check-property Integer false sampler: (fixed-integer 5 (lambda (_) '(0)) (lambda (_) -1))) status) 'error)
      (check-exception (check-property Integer true cases: 0) Error?)
      (check-exception (generator Any) Error?)
      (check-equal? (.get (check-property (List Integer) null? depth: 1) status) 'passed)
      (check-equal? (.get (check-property (Tuple Integer) true depth: 1) status) 'exhausted))
    (test-case "a later draw exception cannot report the previous successful candidate"
      (let* ((calls 0) (cause (Error "later draw"))
             (sampler (make-generator Integer
               (lambda (_random _size) (set! calls (+ calls 1)) (if (= calls 1) 7 (raise cause)))
               (lambda (_) []) abs))
             (report (check-property Integer true cases: 3 sampler: sampler)))
        (check-equal? (.get report status) 'error)
        (check-equal? (.get report trial) 2)
        (check (.get report original) => #f)
        (check (.get report counterexample) => #f)
        (check (eq? (.get report cause) cause) => #t)))
    (test-case "descriptor revision invalidates results and replay"
      (let* ((descriptor (.o inherit: [Type.] .element?: exact-integer?))
             (sampler (make-generator descriptor (lambda (_random _size) 1) (lambda (_) []) abs))
             (report (check-property descriptor (lambda (_)
                        (.putslot! descriptor 'revision ($constant-slot-spec 1)) #t) sampler: sampler)))
        (check-equal? (.get report status) 'stale)
        (check-exception (replay-property report) Error?)))
    (test-case "property callback dependencies refuse reuse after revision"
      (let* ((rules (.o allowed: #t))
             (report (check-property Integer (lambda (_)
                        (.putslot! rules 'allowed ($constant-slot-spec #f)) #t)
                        dependencies: [rules])))
        (check-equal? (.get report status) 'stale)
        (check-exception (replay-property report) Error?)))
    (test-case "nested child descriptor changes refuse otherwise successful tests"
      (let* ((descriptor (List Integer)) (sampler (generator descriptor))
             (report (check-property descriptor (lambda (_)
                        (.putslot! descriptor 'type ($constant-slot-spec Bool)) #t) sampler: sampler)))
        (check-equal? (.get report status) 'stale)))
    (test-case "generator mutation refuses before the property executes"
      (let* ((calls 0) (descriptor (.o inherit: [Type.] .element?: exact-integer?))
             (sampler (make-generator descriptor
               (lambda (_random _size) (.putslot! descriptor 'revision ($constant-slot-spec 1)) 1)
               (lambda (_) []) abs))
             (report (check-property descriptor (lambda (_) (set! calls (+ calls 1)) #t) sampler: sampler)))
        (check-equal? (.get report status) 'stale)
        (check-equal? calls 0)))
    (test-case "nested callback service composes through Reader/FUN"
      (let* ((consume-count 0)
             (action (service.service-tests (lambda (report) (set! consume-count (+ consume-count 1)) report)))
             (report (action (.o seed: 43 cases: 100 size: 5 shrink-budget: 100))))
        (check-equal? (.get report status) 'passed)
        (check-equal? consume-count 1)))
    (test-case "overlapping clauses draw using actual first-match child types"
      (let* ((signature (CaseFunction (Function [Integer] [Integer] optional: [Integer])
                                     (Function [Bool] [Bool Bool])))
             (arguments (FunctionArguments signature))
             (report (check-property arguments (lambda (args) (every exact-integer? args)) seed: 4 cases: 100)))
        (check-equal? (.get report status) 'passed)))
    (test-case "generated required keywords and rest calls remain well shaped"
      (let* ((signature (Function [Integer] [Integer] optional: [Integer] rest: Integer
                                 keywords: (list (cons scale: Integer)) required-keywords: [scale:]))
             (checked (validate signature (lambda (x (y 0) scale: scale . rest) (+ scale x y (apply + rest)))))
             (report (check-property (FunctionArguments signature)
                       (lambda (args) (exact-integer? (apply checked args))) seed: 9 cases: 100 size: 8)))
        (check-equal? (.get report status) 'passed)))
    (test-case "Function call shrinking retains its selected clause and finds a smaller failure"
      (let* ((signature (CaseFunction (Function [Integer] [Integer]) (Function [Integer] [Integer Integer])))
             (report (check-property (FunctionArguments signature) (lambda (args) (every (lambda (x) (< (abs x) 3)) args))
                       seed: 2 cases: 100 size: 20)))
        (check-equal? (.get report status) 'failed)
        (check (element? (FunctionArguments signature) (.get report counterexample)) => #t)
        (check-equal? (apply max (map abs (.get report counterexample))) 3)))))
