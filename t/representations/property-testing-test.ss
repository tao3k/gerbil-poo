;;; Generated evidence exercises domains, replay, source invalidation and budgets.
(export property-testing-test property-kernel-test property-workflows-test generated-batches-test)
(import (prefix-in :clan/property-testing/test assertion.)
        (prefix-in :clan/property-testing/generator core.)
        (prefix-in :clan/property-testing/property property.) :std/test :std/error :std/iter :std/io/tempfile
        (only-in :std/misc/process run-process) (only-in :std/misc/ports read-all-as-lines read-all-as-string) :clan/poo/object :clan/poo/mop :clan/poo/type :clan/poo/number
        :clan/poo/testing/type :clan/poo/testing/function
        (prefix-in :clan/poo/examples/signature-service service.)
        (only-in :clan/poo/examples/property-kernel property-kernel-test)
        (only-in :clan/poo/examples/property-workflows property-workflows-test)
        (only-in :clan/poo/examples/generated-batches generated-batches-test))

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
        (path-expand file project))) '("generator.ss" "property.ss" "model.ss" "replay.ss" "test.ss" "build.ss" "gerbil.pkg"))
    (create-directory* (path-expand "examples" project))
    (copy-file (path-expand "examples/property-kernel.ss" source-root)
      (path-expand "examples/property-kernel.ss" project))
    (write-program (path-expand "build.ss" project)
      '((import :std/build-script)
        (defbuild-script '("generator" "property" "model" "replay" "test" "examples/property-kernel"))))
    ;; The package manager executes build.ss; the standard script owns its argv.
    (let (file (path-expand "build.ss" project))
      (def text (call-with-input-file file read-all-as-string))
      (call-with-output-file [path: file truncate: #t]
        (lambda (port) (display "#!/usr/bin/env -S gxi -:max-heap=1G,debug=q\n" port) (display text port)))
      (run-process ["chmod" "755" file]))
    (def package (path-expand "package" project))
    (def artifact (path-expand "lib/clan/property-testing/examples/property-kernel.ssi" package))
    ;; Released compilers carry relocation options in GAMBOPT. Append the same
    ;; heap bound without replacing their standard bin/library/include mappings.
    (def options (getenv "GAMBOPT" ""))
    (def runtime-options (string-append "GAMBOPT=" options
      (if (equal? options "") "" ",") "max-heap=1G,debug=q"))
    ;; Standard process arguments and std/build-script own this isolated build.
    ;; Print captured compiler diagnostics on failure, then preserve its cause.
    (def (run . arguments)
      (def output "")
      (with-catch (lambda (cause) (display output) (force-output) (raise cause))
        (lambda ()
          (run-process [timeout "--signal=TERM" "--kill-after=3s" "60s" "env"
            (string-append "GERBIL_PATH=" package) runtime-options
            "gerbil" "-:max-heap=1G,debug=q" arguments ...] directory: project stderr-redirection: #t
            coprocess: (lambda (port) (set! output (read-all-as-string port)) output)))))
    (run "build")
    (check (file-exists? artifact) => #t)
    (check (file-exists? (path-expand "lib/clan/poo" package)) => #f)
    (def lines (string-split (run "test" "-v" "5" artifact) #\newline))
    ;; gxtest may print HARNESS-OK even with an error module, so require executed
    ;; case receipts and an error-free transcript, not merely process exit zero.
    (unless (= (length (filter (cut string-prefix? "CASE-OK " <>) lines)) 28)
      (error "independent suite did not execute all cases" lines))
    (check (and (member "OK" lines) #t) => #t)
    (check (ormap (cut string-prefix? "ERROR " <>) lines) => #f)
    (displayln "PROPERTY-LIBRARY-OK 28 cases; isolated stdlib-only compiled modules"))))

;; Every outcome is inspected; a test error never substitutes for a false property.
(def property-testing-test
  (test-suite "descriptor-driven finite tests and counterexample shrinking"
    (test-case "standard scalar data Types share generic generation and shrinking"
      (for (descriptor (list String Symbol Bytes (BytesN 4)))
        (def sampler (generator descriptor))
        (def report (check-property descriptor (lambda (_) #f) sampler: sampler
          seed: 42 cases: 1 size: 6 shrink-budget: 100))
        (check-eq? (.get report status) 'failed)
        (check (element? descriptor (.get report counterexample)) => #t)
        (check-equal? (.get (replay-property report) counterexample) (.get report counterexample)))
      (def zero-width (generator (BytesN 0)))
      (check-equal? (core.sample-value (core.generate (generator-core zero-width) (core.random-at 4) 0)) #u8()))
    (test-case "nested data containers keep Type admission and fixed-byte widths"
      (def descriptor (Tuple (List (BytesN 3)) Symbol String))
      (assertion.check-property (check-property descriptor (cut element? descriptor <>)
        seed: 19 cases: 20 size: 4) diagnostics: report-diagnostics))
    (test-case "typed reports use the standard assertion and existing source guard"
      (assertion.check-property
        (check-property (Tuple Integer UInt) (lambda (row) (= (vector-length row) 2)) cases: 5)
        diagnostics: report-diagnostics)
      (def source (.o epoch: 0))
      (def passed (check-property Integer positive? sampler: (fixed-integer 1 core.integer-shrinks)
        dependencies: (list source) cases: 1))
      (.set! source epoch 1)
      (check-eq? (cdr (assq 'status (report-diagnostics passed))) 'stale)
      (def cause (cons 'type 'preparation))
      (define-type Refused (.cc Type. .element?: exact-integer? .generator: (lambda () (raise cause))))
      (def refused (check-property Refused positive? cases: 1))
      (check-eq? (cdr (assq 'phase (report-diagnostics refused))) 'preparation)
      (check-eq? (cdr (assq 'cause (report-diagnostics refused))) cause))
    (test-case "finite Function values retain typed wrapping and coverage policies"
      (def signature (Function [(Exactly 1)] [Integer Integer]
        keywords: (list (cons scale: (Exactly 2))) required-keywords: [scale:]))
      (def functions (core.generator-map
        (core.generator-function '((1 scale: 2)) (core.generator-unit '(4 5))) core.function-procedure))
      (def sampler (from-generator signature functions (lambda (_) 0)))
      ;; The Function contract exposes exactly the finite generated observation domain.
      (def checked (validate signature (core.sample-value (core.generate functions (core.random-at 1) 0))))
      (check-exception (checked 2 scale: 2) TypeError?)
      (check-exception (checked 1 scale: 3) TypeError?)
      (def report (check-property signature
        (lambda (function) (equal? (call-with-values (cut function 1 scale: 2) list) '(4 5)))
        sampler: sampler cases: 3 policy: (property.make-policy name: 'typed-function
          labels: (lambda (_) '(keyword)) required: '((keyword . 3)))))
      (check-eq? (.get report status) 'passed)
      (check-equal? (.get report accepted) 3)
      (check-equal? (.get report labels) '((keyword . 3)))
      (check-eq? (.get report name) 'typed-function))
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
    (test-case "Record interruptions retain progress through the Reader FUN boundary"
      (def Value (Record count: [UInt]))
      (def cause (Error "record callback refused"))
      (def deliveries 0)
      ;; Typed construction and projection stay in the existing Record layer.
      (def sampler (make-generator Value (lambda (_random _size) (make-instance Value count: 9))
        (lambda (value) (map (lambda (count) (make-instance Value count: count))
          (if (= (.get value count) 9) '(8) '(8 7)))) (lambda (value) (.get value count))))
      ;; FUN delivers the original error report once, retaining the last admitted
      ;; witness rather than the candidate whose callback failed.
      (def action (property-action Value
        (lambda (value) (when (= (.get value count) 7) (raise cause)) #f)
        (lambda (report) (set! deliveries (1+ deliveries)) report) sampler: sampler))
      (def report (action (.o seed: 17 cases: 1 size: 8 shrink-budget: 8)))
      (check-equal? (list (.get report status) (.get (.get report original) count)
        (.get (.get report counterexample) count) (.get report attempts) (.get report steps)
        (.get report minimal?)) '(error 9 8 3 1 #f))
      (check (eq? (.get report cause) cause) => #t)
      (check-equal? deliveries 1)
      (check-exception (replay-counterexample report) Error?)
      (def again (replay-property report))
      (check-equal? (list (.get again status) (.get (.get again counterexample) count)
        (.get again attempts) (.get again steps)) '(error 8 3 1)))
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
