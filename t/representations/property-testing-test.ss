;;; Generated evidence exercises domains, replay, source invalidation and budgets.
(export inspection-request-test failure-preparation-test signature-preparation-test trace-snapshot-test trace-request-test handoff-test product-row-test trace-tree-test request-preparation-test bridge-preparation-test snapshot-admission-test assertion-admission-test product-preparation-test trace-preparation-test sampler-binding-test sampler-scope-test call-admission-test property-testing-test property-kernel-test property-workflows-test generated-batches-test generated-traces-test generated-products-test)
(import (prefix-in (only-in :clan/poo/support/testing require-property-passed) standard.)
        (prefix-in :clan/poo/testing/property/test assertion.)
        (prefix-in :clan/poo/testing/property/generator core.)
        (prefix-in :clan/poo/testing/property property.)
        (prefix-in :clan/poo/testing/property/replay replay.) :std/test :std/error :std/iter :std/io/tempfile
        (only-in :std/misc/process run-process) (only-in :std/misc/ports read-all-as-lines read-all-as-string) :clan/poo/object :clan/poo/mop :clan/poo/type :clan/poo/number
        :clan/poo/testing/type :clan/poo/testing/function
        (only-in :clan/poo/function-signature encode-arguments)
        (only-in :clan/poo/testing/generation-graph generation-refusal? generation-refusal-kind graph-sources-current?)
        (only-in :clan/poo/support/option some)
        (only-in :clan/poo/examples/signature-service signature-preparation-test failure-preparation-test inspection-request-test)
        (prefix-in :clan/poo/examples/signature-service service.)
        (only-in :clan/poo/examples/representation-service slot-revision-workflow)
        (prefix-in (only-in :clan/poo/examples/collection-properties map-service-tests map-service-action service-value-generator service-batch-action service-factory-action) collection.)
        (only-in :clan/poo/examples/property-kernel property-kernel-test)
        (only-in :clan/poo/examples/property-workflows property-workflows-test)
        (only-in :clan/poo/examples/generated-batches generated-batches-test)
        (only-in :clan/poo/examples/generated-traces trace-snapshot-test trace-request-test generated-traces-test)
        (only-in :clan/poo/examples/generated-products generated-products-test product-row-test handoff-test))

(import (only-in "property-testing/preparation.ss" make-preparation-suites))

;; Deterministic fixture isolates shrinking from random trial distribution.
(def (fixed-integer value shrink (measure abs))
  (make-generator Integer (lambda (_random _size) value) shrink measure))
;; Each observation owns fresh declarations; the fixture is the only effectful side.
(def (integer-trace-model)
  (make-instance TraceModel Command: Integer State: Integer Result: Integer Observation: Integer
    initial: (lambda () 0) enabled?: (lambda (_state _command) #t)
    advance: (lambda (state command) (values (+ state command) (+ state command))) observe: values))
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
    (create-directory* (path-expand "property" project))
    (for-each (lambda (file)
      (copy-file (path-expand (string-append "testing/" file) source-root)
        (path-expand file project)))
      '("property.ss" "property/generator.ss" "property/model.ss" "property/replay.ss" "property/test.ss"))
    (write-program (path-expand "gerbil.pkg" project) '((package: clan/poo/testing)))
    ;; Use the same source-only standard compiler declaration as the root build.
    ;; No POO module, compiler checkout or runtime registry enters the package.
    (create-directory* (path-expand "testing/property" project))
    (copy-file (path-expand "testing/property/build.scm" source-root)
      (path-expand "testing/property/build.scm" project))
    (create-directory* (path-expand "examples" project))
    (for-each (lambda (file)
      (copy-file (path-expand file source-root) (path-expand file project)))
      '("examples/property-products.ss" "examples/property-numbers.ss" "examples/property-filters.ss" "examples/property-scopes.ss" "examples/property-replay.ss" "examples/property-sizes.ss" "examples/property-traces.ss" "examples/property-kernel.ss"))
    (create-directory* (path-expand "examples/property-kernel" project))
    (copy-file (path-expand "examples/property-kernel/cases.scm" source-root)
      (path-expand "examples/property-kernel/cases.scm" project))
    (write-program (path-expand "build.ss" project)
      '((import :std/build-script)
        (include "testing/property/build.scm")
        (defbuild-script `("property/generator" "property" "property/model" "property/replay" "property/test"
                          ,@property-example-build-specs ,property-kernel-build-spec))))
    ;; The package manager executes build.ss; the standard script owns its argv.
    (let (file (path-expand "build.ss" project))
      (def text (call-with-input-file file read-all-as-string))
      (call-with-output-file [path: file truncate: #t]
        (lambda (port) (display "#!/usr/bin/env -S gxi -:max-heap=1G,debug=q\n" port) (display text port)))
      (run-process ["chmod" "755" file]))
    (def package (path-expand "package" project))
    (def artifact (path-expand "lib/clan/poo/testing/examples/property-kernel.ssi" package))
    ;; Released compilers carry relocation options in GAMBOPT. Append the same
    ;; heap bound without replacing their standard bin/library/include mappings.
    (def options (getenv "GAMBOPT" ""))
    (def runtime-options (string-append "GAMBOPT=" options
      (if (equal? options "") "" ",") "max-heap=1G,debug=q"))
    ;; Standard process arguments and std/build-script own this isolated build.
    ;; Inherit machine concurrency and wait for compilation's natural completion.
    ;; Zero retains group signal forwarding without a compiler wall deadline;
    ;; the isolated heap and full-case admission remain unchanged.
    (def (run . arguments)
      (displayln "PROPERTY-LIBRARY-START " (time->seconds (current-time)) " " arguments
        " cores=" (getenv "GERBIL_BUILD_CORES" "compiler-default") " directory=" project) (force-output)
      (def result
        (run-process ["/usr/bin/time" "-p"
          (if (equal? (car arguments) "build")
            [timeout "--signal=TERM" "--kill-after=3s" "0"] []) ...
          "env" (string-append "GERBIL_PATH=" package) runtime-options
          "gerbil" "-:max-heap=1G,debug=q" arguments ...] directory: project stderr-redirection: #t
          coprocess: (lambda (port)
            (call-with-output-string
              (lambda (capture)
                ;; Match std/misc/ports' line-reading discipline. Keep separators
                ;; in the captured receipt; prefixes prevent counting child cases twice.
                (let loop ()
                  (let (line (read-line port #\newline #t))
                    (when (string? line)
                      (display line capture)
                      (display "PROPERTY-LIBRARY ") (display line) (force-output)
                      (loop)))))))))
      (displayln "PROPERTY-LIBRARY-END " (time->seconds (current-time)) " " arguments) (force-output)
      result)
    (displayln "PROPERTY-LIBRARY-BUILD stdlib-only empty package") (force-output)
    (run "build")
    (check (file-exists? artifact) => #t)
    ;; The module path does not load parent modules: no POO runtime is installed.
    (for-each (lambda (file)
      (check (file-exists? (path-expand file package)) => #f))
      '("lib/clan/poo/object.ssi" "lib/clan/poo/mop.ssi" "lib/clan/poo/testing/type.ssi"))
    (displayln "PROPERTY-LIBRARY-RUN compiled independent suite") (force-output)
    (def lines (string-split (run "test" "-v" "5" artifact) #\newline))
    ;; gxtest may print HARNESS-OK even with an error module, so require executed
    ;; case receipts and an error-free transcript, not merely process exit zero.
    (unless (= (length (filter (cut string-prefix? "CASE-OK " <>) lines)) 260)
      (error "independent suite did not execute all cases" lines))
    (check (and (member "OK" lines) #t) => #t)
    (check (ormap (cut string-prefix? "ERROR " <>) lines) => #f)
    (displayln "PROPERTY-LIBRARY-OK 260 cases; isolated stdlib-only compiled modules"))))

;; Keep the public replay variants in one small test dispatcher; each API still
;; owns its actual admission/error semantics and return shape.
(def (typed-replay-operation operation report codec output)
  (case operation
    ((seed) (replay-property report)) ((concrete) (replay-counterexample report))
    ((export) (write-counterexample report codec output))))

;; Every outcome is inspected; a test error never substitutes for a false property.
(def property-testing-test
  (test-suite "descriptor-driven finite tests and counterexample shrinking"
    (test-case "generated source revisions retire all bound descendants before rebinding"
      (standard.require-property-passed
        (check-property (Tuple (List Integer) Bool)
          (lambda (row)
            (slot-revision-workflow (append (vector-ref row 0) '(#f))
              (if (vector-ref row 1) 2 1)))
          seed: 41 cases: 32 size: 8)))
    (test-case "typed replay retains explicit owners before computed execution handoff"
      (for (operation '(seed concrete export))
        (def owner (.o epoch: 0)) (def calls 0) (def encoded 0)
        (def base (check-property Integer (lambda (_) (set! calls (1+ calls)) #f)
          cases: 1 shrink-budget: 0))
        (def execution (.get base execution))
        (def row (cons (cons owner (object-revision owner)) (.get base sources)))
        (def report (.o bind-these: #f inherit: [base] sources: row
          execution: (begin (.set! owner epoch 1) execution)))
        (def codec (replay.make-codec 'typed-owner
          (lambda (value) (set! encoded (1+ encoded)) value) values))
        (def output (open-output-string)) (set! calls 0)
        (check-exception (typed-replay-operation operation report codec output)
          (lambda (cause) (and (Error? cause) (equal? (Error-message cause) "stale property replay"))))
        (check-equal? (list calls encoded (string-length (get-output-string output))) '(0 0 0))))
    (test-case "typed replay owns source pairs before sampler metadata and transient report revision"
      (for* ((operation '(seed concrete export)) (fault '(row report sampler)))
        (def owner (.o epoch: 0)) (def calls 0)
        (def base (check-property Integer (lambda (_) (set! calls (1+ calls)) #f)
          cases: 1 shrink-budget: 0))
        (def row (cons (cons owner (object-revision owner)) (.get base sources)))
        (def supplied (.o bind-these: #f inherit: [(.get base sampler)] .current?: (lambda () #t)))
        (def execution (.get base execution))
        (def report #f)
        (set! report (.o bind-these: #f inherit: [base] sources: row
          sampler: (begin
            (case fault
              ((row) (.set! owner epoch 1) (set-cdr! (car row) (object-revision owner)))
              ((report) (.set! report changed #t)))
            (if (eq? fault 'sampler) supplied (.get base sampler)))
          execution: (begin (when (eq? fault 'sampler) (.set! supplied changed #t)) execution)))
        (set! calls 0)
        (check-exception (typed-replay-operation operation report (replay.make-codec 'v1 values values)
          (open-output-string)) Error?)
        (check-equal? calls 0)))
    (test-case "typed replay preserves raw getter and callback causes without late stale replacement"
      (for* ((operation '(seed concrete export)) (stage '(getter property))
             (cause (list #f (cons 'original 'cause))))
        (def owner (.o epoch: 0)) (def armed #f)
        (def base (check-property Integer
          (lambda (_)
            (when (and armed (eq? stage 'property)) (.set! owner epoch 1) (raise cause)) #f)
          cases: 1 shrink-budget: 0))
        (def execution (.get base execution))
        (def row (cons (cons owner (object-revision owner)) (.get base sources)))
        (def report (.o bind-these: #f inherit: [base] sources: row
          execution: (begin
            (when (eq? stage 'getter) (.set! owner epoch 1) (raise cause)) execution)))
        (set! armed #t)
        (def returned (with-catch values (lambda ()
          (typed-replay-operation operation report (replay.make-codec 'v1 values values) (open-output-string)))))
        (if (and (eq? operation 'seed) (eq? stage 'property))
          (begin (check-eq? (.get returned status) 'stale) (check-eq? (.get returned cause) cause))
          (check-eq? returned cause))))
    (test-case "seed replay publishes detached declared epochs without retaining report chains"
      (def owner (.o epoch: 0)) (def reads 0) (def checks 0)
      (def base (check-property Integer (lambda (_) #f) cases: 1 shrink-budget: 0))
      (def bound (.get base sampler))
      (def sampler (.o bind-these: #f inherit: [bound]
        .current?: (begin (set! reads (1+ reads)) (lambda () (set! checks (1+ checks)) #t))))
      (def row (cons (cons owner (object-revision owner)) (.get base sources)))
      (def report (.o bind-these: #f inherit: [base] sources: row sampler: sampler))
      (def again (replay-property report))
      (check-equal? reads 1)
      (check-equal? (length (.get again sources)) (length row))
      (check-eq? (car (car (.get again sources))) owner)
      (check-equal? (cdr (car (.get again sources))) 0)
      (check (eq? (car (.get again sources)) (car row)) => #f)
      (set-cdr! (car row) 1)
      (def before checks)
      (for (_ (in-range 3))
        (set! again (replay-property again))
        (check-eq? (.get again status) 'failed)
        (check-equal? (length (.get again sources)) (length row)))
      ;; The POO slot stays memoized; source judgments are still per invocation.
      (check-equal? reads 1)
      (check (> checks before) => #t)
      (.set! owner epoch 1)
      (check-exception (replay-property again) Error?)
      (check-exception (replay-counterexample again) Error?))
    (test-case "portable import rejects a retiring true hook before consuming caller input"
      (def owner (.o epoch: 0)) (def decoded 0) (def properties 0)
      (def sampler (.cc (make-generator UInt (lambda (_r _s) 4) (lambda (_) []) identity dependencies: [owner])
        .current?: (lambda () (.set! owner epoch 1) #t)))
      (def codec (replay.make-codec 'v1 values (lambda (value) (set! decoded (1+ decoded)) value)))
      (def input (open-input-string "#(property-counterexample 1 v1 4)"))
      (check-exception (read-counterexample sampler codec input
        (lambda (_) (set! properties (1+ properties)) #f)) Error?)
      (check-eq? (peek-char input) #\#)
      (check-equal? (list decoded properties) '(0 0)))
    (test-case "typed replay hooks retain invocation report and sampler epochs before output"
      (for* ((operation '(seed concrete export)) (retired '(report sampler dependency)))
        (def owner (.o epoch: 0)) (def armed #f) (def calls 0) (def encoded 0) (def view #f)
        (def sampler (.cc (make-generator UInt (lambda (_r _s) 4) (lambda (_) []) identity dependencies: [owner])
          .current?: (lambda () (when armed (set! armed #f)
            (.set! (case retired ((report) view) ((sampler) sampler) (else owner)) epoch 1)) #t)))
        (def report (check-property UInt (lambda (_) (set! calls (1+ calls)) #f)
          sampler: sampler cases: 1 shrink-budget: 0))
        (set! view (.cc report))
        (def codec (replay.make-codec 'v1 (lambda (v) (set! encoded (1+ encoded)) v) values))
        (def output (open-output-string))
        ;; Force initial preparation before measuring the refused operation in
        ;; both source and compiled TestSuite execution. Keep its call separate.
        (check-eq? (.get view status) 'failed)
        (let (before calls)
          (set! armed #t)
          (check-exception (case operation ((seed) (replay-property view))
            ((concrete) (replay-counterexample view)) (else (write-counterexample view codec output))) Error?)
          (check-equal? (list calls encoded (get-output-string output)) (list before 0 "")))))
    (test-case "finite shrink batches are owned before returning observers across typed paths"
      (for* ((path '(bridge product recursive)) (edit '(replace improper cycle)))
        (def Leaf (.cc UInt)) (def row (list 0)) (def armed #f) (def changed #f)
        (def child (make-generator Leaf (lambda (_r _s) 2) (lambda (_) (set! armed #t) row) identity))
        (.putslot! Leaf '.generator ($constant-slot-spec (lambda () child)))
        (def sampler (case path ((bridge) child)
          ((product) (product-generator (Tuple Leaf) [child] vector->list list->vector))
          ((recursive) (generator (Tuple Leaf)))))
        (def tree (and (eq? path 'bridge) (core.generate (generator-core sampler) (core.random-at 0) 2)))
        (def result (core.with-generation-check (lambda ()
          (when (and armed (not changed))
            (set! changed #t)
            (case edit ((replace) (set-car! row 1))
              ((improper) (set-cdr! row 'tail)) ((cycle) (set-cdr! row row)))))
          (if tree (for/collect (child ((core.sample-children tree))) (core.sample-value child))
            (.call sampler shrink '#(2)))))
        (check changed => #t)
        (check-equal? result (if tree '(0) '(#(0))))))
    (test-case "finite shrink batches keep malformed input and exact callback causes"
      (for* ((path '(bridge product recursive)) (mode '(empty payload malformed false object)))
        (def Leaf (.cc UInt)) (def cause (if (eq? mode 'false) #f (cons 'shrink 'cause)))
        (def child (make-generator Leaf (lambda (_r _s) 2)
          (lambda (_) (case mode ((empty) []) ((payload) [#f]) ((malformed) '(0 . tail)) (else (raise cause)))) identity))
        (.putslot! Leaf '.generator ($constant-slot-spec (lambda () child)))
        (def sampler (case path ((bridge) child)
          ((product) (product-generator (Tuple Leaf) [child] vector->list list->vector))
          ((recursive) (generator (Tuple Leaf)))))
        ;; Force only this immediate finite batch, leaving descendant trees lazy.
        (def (run)
          (if (eq? path 'bridge)
            (let (tree (core.generate (generator-core sampler) (core.random-at 0) 2))
              (for/collect (child ((core.sample-children tree))) (core.sample-value child)))
            (.call sampler shrink '#(2))))
        (case mode
          ((empty) (check-equal? (run) []))
          ((payload) (check-equal? (run) (if (eq? path 'bridge) '(#f) '(#(#f)))))
          ((malformed) (check-exception (run) (lambda (error)
            (and (Error? error) (equal? (Error-message error) "shrinker must return a finite proper list")))))
          (else (check-eq? (with-catch values run) cause)))))
    (test-case "malformed shrink batches retain stale and observer exception priority"
      (for (fault '(stale observer))
        (def owner (.o epoch: 0)) (def armed #f) (def cause (cons 'observer 'cause))
        (def child (make-generator UInt (lambda (_r _s) 2)
          (lambda (_) (set! armed #t) (when (eq? fault 'stale) (.set! owner epoch 1)) '(0 . tail))
          identity dependencies: [owner]))
        (def sampler (product-generator (Tuple UInt) [child] vector->list list->vector))
        (def (run)
          (core.with-generation-check (lambda () (when (and armed (eq? fault 'observer)) (raise cause)))
            (.call sampler shrink '#(2))))
        (if (eq? fault 'stale) (check-exception (run) generation-refusal?)
          (check-eq? (with-catch values run) cause))))
    (test-case "finite shrink capture still refuses retirement before invocation or packing"
      (for (fault '(body getter))
        (def owner (.o epoch: 0)) (def invoked 0) (def packed 0) (def later 0)
        (def first (make-generator UInt (lambda (_r _s) 2)
          (lambda (_) (set! invoked (1+ invoked))
            (when (eq? fault 'body) (.set! owner epoch 1)) '(0)) identity dependencies: [owner]))
        (when (eq? fault 'getter)
          (.putslot! first 'shrink ($self-slot-spec (lambda (_)
            (.set! owner epoch 1) (lambda (_) (set! invoked (1+ invoked)) '(0))))))
        (def last (make-generator UInt (lambda (_r _s) 2)
          (lambda (_) (set! later (1+ later)) '(0)) identity))
        (def sampler (product-generator (Tuple UInt UInt) [first last] vector->list
          (lambda (row) (set! packed (1+ packed)) (list->vector row))))
        (check-exception (.call sampler shrink '#(2 2)) generation-refusal?)
        (check-equal? (list invoked packed later) (if (eq? fault 'getter) '(0 0 0) '(1 0 0)))))
    (test-case "typed product measures stop before a later field after any owner revision"
      (for (dimension '(parent child))
        (def source (.o epoch: 0)) (def descriptor (.cc (Tuple Integer Integer) epoch: 0))
        (def later 0) (def calls 0)
        (def first (make-generator Integer (lambda (_random _size) 2) (lambda (_) '(0))
          (lambda (value) (.set! (if (eq? dimension 'parent) descriptor source) epoch 1) (abs value))))
        (def last (make-generator Integer (lambda (_random _size) 3) (lambda (_) [])
          (lambda (value) (set! later (1+ later)) (abs value)) dependencies: (list source)))
        (def sampler (product-generator descriptor (list first last) vector->list list->vector))
        (def report (check-property descriptor (lambda (_) (set! calls (1+ calls)) #f)
          sampler: sampler cases: 1 shrink-budget: 2))
        (check-eq? (.get report status) 'stale)
        (check-equal? (list later calls (.get report attempts) (.get report steps)) '(0 1 1 0))
        (check-equal? (.get report counterexample) '#(2 3))
        (check-exception (replay-property report) Error?)))
    (test-case "value-only product shrinking shares refusal before packing and later children"
      (def source (.o epoch: 0)) (def revise? #t) (def packed 0) (def later 0)
      (def descriptor (Tuple Integer Integer))
      (def first (make-generator Integer (lambda (_random _size) 2)
        (lambda (_) (when revise? (.set! source epoch 1)) '(0)) abs))
      (def last (make-generator Integer (lambda (_random _size) 3)
        (lambda (_) (set! later (1+ later)) '(0)) abs dependencies: (list source)))
      ;; Fresh construction owns fresh epochs; it never repairs the old sampler.
      (def (prepare)
        (product-generator descriptor (list first last) vector->list
          (lambda (row) (set! packed (1+ packed)) (list->vector row))))
      (def old (prepare))
      (check-exception (.call old shrink '#(2 3)) generation-refusal?)
      (check-equal? (list packed later) '(0 0))
      (set! revise? #f)
      (def current (prepare))
      (check-equal? (.call current shrink '#(2 3)) '(#(0 3) #(2 0)))
      (check-equal? (list packed later) '(2 1))
      (check (.call old .current?) => #f))
    (test-case "product child topology is captured consistently across draw measure and shrink"
      (def replaced 0)
      (def children (list (fixed-integer 2 (lambda (_) '(0))) (fixed-integer 3 (lambda (_) '(0)))))
      (def sampler (product-generator (Tuple Integer Integer) children vector->list list->vector))
      (set-car! children (make-generator Integer
        (lambda (_random _size) (set! replaced (1+ replaced)) 99) (lambda (_) [])
        (lambda (_) (set! replaced (1+ replaced)) 99)))
      (set-cdr! children [])
      (check-equal? (.call sampler draw (core.random-at 0) 0) '#(2 3))
      (check-equal? (.call sampler measure '#(2 3)) 5)
      (check-equal? (.call sampler shrink '#(2 3)) '(#(0 3) #(2 0)))
      (check-equal? replaced 0))
    (test-case "empty typed products retain descriptor ownership"
      (def descriptor (.cc (Tuple) epoch: 0))
      (def sampler (product-generator descriptor [] vector->list list->vector))
      (check-equal? (.call sampler measure '#()) 0)
      (check-equal? (.call sampler shrink '#()) [])
      (.set! descriptor epoch 1)
      (check-exception (.call sampler measure '#()) generation-refusal?)
      (check-exception (.call sampler shrink '#()) generation-refusal?)
      (check-exception (.call sampler draw (core.random-at 0) 0) core.stale-generation?))
    (test-case "trace declaration revisions stop every scoped execution boundary"
      (for (phase '(open observe compare step type return))
        (def observation (.cc Integer epoch: 0))
        (def model (.cc (integer-trace-model) Observation: observation)) (def steps 0) (def closed 0)
        (def schema (TraceSystem Integer))
        ;; Reassigning the same callback is still a declaration revision.
        (def (revise at) (when (eq? phase at)
          (if (eq? at 'type) (.set! observation epoch 1) (.set! model observe values))))
        (check-exception
          (check-trace model '(1 2)
            (lambda (use)
              (try
                (revise 'open)
                (let (report (use (make-instance schema initial: 0
                  step: (lambda (state command)
                    (set! steps (1+ steps)) (revise 'step) (revise 'type)
                    (values (+ state command) (+ state command)))
                  observe: (lambda (state) (revise 'observe) state))))
                  (revise 'return) report)
                (finally (set! closed (1+ closed)))))
            same?: (lambda (left right) (revise 'compare) (equal? left right)))
          generation-refusal?)
        (check-equal? steps (case phase ((step type) 1) ((return) 2) (else 0)))
        (check-equal? closed 1)))
    (test-case "nested generation inherits direct trace preparation declarations"
      (def model (integer-trace-model)) (def mapped 0) (def opened 0)
      (.set! model advance (lambda (state command)
        (.set! model observe values)
        (core.generate (core.generator-map (core.generator-unit command)
          (lambda (value) (set! mapped (1+ mapped)) value)) (core.random-at 0) 0)
        (values (+ state command) (+ state command))))
      (check-exception (check-trace model '(1) (lambda (_) (set! opened (1+ opened))))
        generation-refusal?)
      (check-equal? (list mapped opened) '(0 0))
      ;; An unrelated action after unwinding has no retired local checker.
      (check-equal? (core.sample-value (core.generate (core.generator-unit 7) (core.random-at 0) 0)) 7))
    (test-case "active fixture Type revisions suppress nested work before callback return"
      (for (phase '(step observe compare))
        (def state-type (.cc Integer epoch: 0)) (def mapped 0) (def closed 0) (def steps 0)
        ;; The actual State declaration is distinct from the reference declaration.
        (def (nested at)
          (when (eq? at phase)
            (.set! state-type epoch 1)
            (core.generate (core.generator-map (core.generator-unit 1)
              (lambda (value) (set! mapped (1+ mapped)) value)) (core.random-at 0) 0)))
        (check-exception (check-trace (integer-trace-model) '(1 2) (lambda (use)
          (try (use (make-instance (TraceSystem state-type) initial: 0
            step: (lambda (state command) (set! steps (1+ steps)) (nested 'step)
              (values (+ state command) (+ state command)))
            observe: (lambda (state) (nested 'observe) state)))
            (finally (set! closed (1+ closed)))))
          same?: (lambda (left right) (nested 'compare) (equal? left right))) generation-refusal?)
        (check-equal? (list mapped closed steps) (list 0 1 (if (eq? phase 'step) 1 0)))))
    (test-case "fixture teardown drops only fixture declarations from inherited scope"
      (def state-type (.cc Integer epoch: 0)) (def mapped 0)
      (def report (check-trace (integer-trace-model) '(1) (lambda (use)
        (try (use (make-instance (TraceSystem state-type) initial: 0
          step: (lambda (state command) (values (+ state command) (+ state command))) observe: values))
          (finally
            (.set! state-type epoch 1)
            (core.generate (core.generator-map (core.generator-unit 1)
              (lambda (value) (set! mapped (1+ mapped)) value)) (core.random-at 0) 0))))))
      (check (.get report matched?) => #t)
      (check-equal? mapped 1))
    (test-case "teardown cannot drop model authority before nested work"
      (def model (integer-trace-model)) (def mapped 0)
      (check-exception (check-trace model [] (lambda (use)
        (try (use (make-instance (TraceSystem Integer) initial: 0
          step: (lambda (state command) (values state command)) observe: values))
          (finally
            (.set! model observe values)
            (core.generate (core.generator-map (core.generator-unit 1)
              (lambda (value) (set! mapped (1+ mapped)) value)) (core.random-at 0) 0)))))
        generation-refusal?)
      (check-equal? mapped 0))
    (test-case "fixture declaration changes reject later observations and preserve cleanup"
      (def model (integer-trace-model)) (def steps 0) (def observed 0) (def closed 0)
      (def fixture #f)
      (set! fixture (make-instance (TraceSystem Integer) initial: 0
        step: (lambda (state command)
          (set! steps (1+ steps)) (.set! fixture observe values)
          (values (+ state command) (+ state command)))
        observe: (lambda (state) (set! observed (1+ observed)) state)))
      (check-exception (check-trace model '(1 2) (lambda (use)
        (try (use fixture) (finally (set! closed (1+ closed)))))) generation-refusal?)
      (check-equal? (list steps observed closed) '(1 1 1)))
    (test-case "a step exception after revision retains the original cause"
      (def model (integer-trace-model)) (def cause (cons 'step 'failure)) (def closed 0)
      (def found (with-catch identity (lambda ()
        (check-trace model '(1 2) (lambda (use)
          (try (use (make-instance (TraceSystem Integer) initial: 0
            step: (lambda (_state _command) (.set! model observe values) (raise cause))
            observe: values))
            (finally (set! closed (1+ closed)))))))))
      (check-eq? found cause)
      (check-equal? closed 1))
    (test-case "unchanged trace declarations retain first-difference diagnostics"
      (check-exception (check-trace #f [] (lambda (_) (error "fixture must not open"))) TypeError?)
      (def steps 0) (def closed 0)
      (def report (check-trace (integer-trace-model) '(1 2) (lambda (use)
        (try (use (make-instance (TraceSystem Integer) initial: 0
          step: (lambda (state command) (set! steps (1+ steps)) (values (+ state command) 99))
          observe: values)) (finally (set! closed (1+ closed)))))))
      (check-equal? (list (.get report matched?) (.get report phase) (.get report index)
        (.get report expected) (.get report actual) steps closed) '(#f result 0 1 99 1 1)))
    (test-case "normal teardown can retire the fixture after scoped use"
      (def fixture (make-instance (TraceSystem Integer) initial: 0
        step: (lambda (state command) (values (+ state command) (+ state command))) observe: values))
      (def report (check-trace (integer-trace-model) '(1 2) (lambda (use)
        (try (use fixture)
          (finally (.set! fixture step (lambda (_state _command) (error "closed fixture"))))))))
      (check (.get report matched?) => #t)
      (check-equal? (.get report index) 2))
    (test-case "typed inspections share recursive sampler domains and source epochs"
      (def descriptor (Tuple (List (BytesN 3)) Symbol))
      (def sampler (generator descriptor))
      (def result (inspect-generator sampler seed: 42 count: 3 size: 4 depth: 2 proposal-budget: 20))
      (check-eq? (property.inspection-status result) 'complete)
      (for (event (property.inspection-events result))
        (when (memq (vector-ref event 1) '(root value))
          (check (element? descriptor (vector-ref event 2)) => #t)))
      (.put! sampler 'diagnostic-epoch 1)
      (check-eq? (property.inspection-current? result) #f))
    (test-case "standard scalar data Types share generic generation and shrinking"
      (for (descriptor (list String Symbol Keyword Bytes (BytesN 4)))
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
      (standard.require-property-passed (check-property descriptor (cut element? descriptor <>)
        seed: 19 cases: 20 size: 4)))
    (test-case "typed reports use the standard assertion and existing source guard"
      (standard.require-property-passed
        (check-property (Tuple Integer UInt) (lambda (row) (= (vector-length row) 2)) cases: 5))
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
    (test-case "shadowed call inputs never construct their generators but retain revision ownership"
      (def calls 0)
      (define-type Dormant (.cc Type. marker: 0 .element?: exact-integer?
        .generator: (lambda () (set! calls (1+ calls)) (error "shadowed generator was forced"))))
      (def signature (CaseFunction
        (Function [Integer] [Integer] optional: [Integer] rest: Integer keywords: (list (cons scale: Integer)))
        (Function [Integer] [Dormant] optional: [Dormant] rest: Dormant keywords: (list (cons scale: Dormant)))))
      (def arguments (FunctionArguments signature))
      (def report (check-property arguments (cut element? arguments <>) seed: 4 cases: 40 size: 5))
      (check-eq? (.get report status) 'passed)
      (check-equal? calls 0)
      ;; Unused metadata still owns the declaration; demand does not erase stamps.
      (.set! Dormant marker 1)
      (check-exception (replay-property report) Error?)
      (check-eq? (.get (check-property arguments (cut element? arguments <>) cases: 3) status) 'passed)
      (check-equal? calls 0))
    (test-case "an omitted rest input requires no generator while a selected input keeps its exact error"
      (def calls 0) (def observed 0) (def cause (cons 'selected 'generator))
      (define-type Refused (.cc Type. .element?: exact-integer?
        .generator: (lambda () (set! calls (1+ calls)) (raise cause))))
      (def omitted (check-property (FunctionArguments (Function [Integer] [] rest: Refused))
        null? size: 0 cases: 4))
      (check-eq? (.get omitted status) 'passed)
      (check-equal? calls 0)
      (def selected (check-property (FunctionArguments (Function [Integer] [Refused]))
        (lambda (_) (set! observed (1+ observed)) #t) cases: 1))
      (check-eq? (.get selected status) 'error)
      (check-eq? (.get selected cause) cause)
      (check-equal? calls 1)
      (check-equal? observed 0))
    (test-case "a fresh call sampler retries a failed selected generator without a fallback type"
      (def ready? #f) (def calls 0) (def cause (cons 'prepare 'input))
      (def input (.o self: domain inherit: [Type.] .element?: exact-integer?
        .generator: (lambda ()
          (set! calls (1+ calls))
          (unless ready? (raise cause))
          (make-generator domain (lambda (_random _size) 7) core.integer-shrinks abs))))
      (def arguments (FunctionArguments (Function [Integer] [input])))
      (def first (check-property arguments (lambda (_) #f) cases: 1))
      (check-eq? (.get first status) 'error)
      (check-eq? (.get first cause) cause)
      (set! ready? #t)
      (def retried (check-property arguments (lambda (_) #f) cases: 1 shrink-budget: 16))
      (check-eq? (.get retried status) 'failed)
      (check-equal? (.get retried counterexample) '(0))
      (check-equal? calls 2)
      (check (replay-counterexample retried) => #f)
      (check-equal? calls 2))
    (test-case "input preparation is ordered and retains successful promises after a later failure"
      (def events []) (def cause (cons 'middle 'constructor))
      ;; Distinct input hooks expose demand order without invoking the target.
      (def (input name refuse?)
        (.o self: domain inherit: [Type.] .element?: exact-integer?
          .generator: (lambda ()
            (set! events (append events (list name)))
            (when refuse? (raise cause))
            (make-generator domain (lambda (_random _size) 1) (lambda (_) []) abs))))
      (def arguments (FunctionArguments (Function [Integer]
        (list (input 'first #f) (input 'middle #t) (input 'last #f)))))
      (def report (check-property arguments (lambda (_) (error "property must not run")) cases: 1))
      (check-eq? (.get report status) 'error)
      (check-eq? (.get report cause) cause)
      (check-equal? events '(first middle))
      (def replayed (replay-property report))
      (check-eq? (.get replayed status) 'error)
      (check-eq? (.get replayed cause) cause)
      (check-equal? (length (filter (cut eq? 'first <>) events)) 1)
      (check (memq 'last events) => #f))
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

;; The standard CLI can select this suite for focused admission checks. Complete
;; package acceptance still discovers it alongside every pre-existing suite.
(def call-admission-test
  (test-suite "call-row admission"
    (test-case "prepared call layouts retain sources but never retain argument values"
      (def signature (Function [Integer] [Integer] keywords: (list (cons scale: Integer))
        required-keywords: [scale:]))
      (def sampler (generator (FunctionArguments signature)))
      (def generation (generator-core sampler))
      (def first (core.generate generation (core.random-at 1) 0))
      (def second (core.generate generation (core.random-at 2) 0))
      (check ((core.sample-current first)) => #t)
      (check ((core.sample-current second)) => #t)
      (check (< (.call sampler measure '(1 scale: 2)) (.call sampler measure '(7 scale: 9))) => #t)
      (for (proposal (.call sampler shrink '(7 scale: 9)))
        (check (element? (FunctionArguments signature) proposal) => #t)
        (check (< (.call sampler measure proposal) (.call sampler measure '(7 scale: 9))) => #t))
      (.set! signature epoch 1)
      (check-exception (core.generate generation (core.random-at 3) 0) true)
      (check ((core.sample-current first)) => #f)
      (check ((core.sample-current second)) => #f)
      (check (core.generator-current? generation) => #f))
    (test-case "positional optional and rest refusal skips later predicates and agrees with wrapping"
      (for (kind '(fixed optional rest))
        (def rejected 0) (def later 0) (def targets 0)
        (def Reject (.cc Type. .element?: (lambda (_) (set! rejected (1+ rejected)) #f)))
        (def Later (.cc Type. .element?: (lambda (_) (set! later (1+ later)) (error "unreachable later input"))))
        (def signature (case kind
          ((fixed) (Function [Integer] (list Reject Later)))
          ((optional) (Function [Integer] [Integer] optional: (list Reject Later)))
          ((rest) (Function [Integer] (list Reject) rest: Later))))
        (def row (if (eq? kind 'optional) '(0 1 2) '(1 2)))
        (check (element? (FunctionArguments signature) row) => #f)
        (check-exception (apply (validate signature (lambda _ (set! targets (1+ targets)) 0)) row) TypeError?)
        (check-equal? (list rejected later targets) '(2 0 0)))
      (def visits [])
      (def Rest (.cc Type. .element?: (lambda (value)
        (set! visits (cons value visits)) (not (= value 1)))))
      (check (element? (FunctionArguments (Function [Integer] [Integer] rest: Rest)) '(0 1 2 3)) => #f)
      (check-equal? visits '(1)))
    (test-case "keyword refusal and escaped literals preserve supplied order and omission"
      (def rejected 0) (def later 0)
      (def Reject (.cc Type. .element?: (lambda (_) (set! rejected (1+ rejected)) #f)))
      (def Later (.cc Type. .element?: (lambda (_) (set! later (1+ later)) (error "unreachable keyword"))))
      (def signature (Function [Integer] [(Exactly route:)] optional: (list Later)
        keywords: (list (cons later: Later) (cons stop: Reject)) required-keywords: [stop: later:]))
      (def row (encode-arguments (list route:) (list (cons stop: 1) (cons later: 2)) #t))
      (check (element? (FunctionArguments signature) row) => #f)
      (check-equal? (list rejected later) '(1 0))
      (check (element? (FunctionArguments signature) (encode-arguments (list route:) [] #t)) => #f)
      (check-equal? (list rejected later) '(1 0)))
    (test-case "every supplied field inherits active producer sources"
      (for (kind '(fixed optional rest keyword))
        (def live #t) (def probes 0) (def later 0)
        (def Probe (.cc Type. .element?: (lambda (value)
          (set! probes (1+ probes)) (set! live #f) (exact-integer? value))))
        (def Later (.cc Type. .element?: (lambda (value) (set! later (1+ later)) (exact-integer? value))))
        (def signature (case kind
          ((fixed) (Function [Integer] (list Probe Later)))
          ((optional) (Function [Integer] [Integer] optional: (list Probe Later)))
          ((rest) (Function [Integer] [Integer] rest: Probe))
          ((keyword) (Function [Integer] [Integer] keywords: (list (cons first: Probe) (cons later: Later))))))
        (def row (case kind ((fixed) '(1 2)) ((optional rest) '(0 1 2)) ((keyword) '(0 first: 1 later: 2))))
        (def generation (core.make-generator (lambda (_random _size) (element? (FunctionArguments signature) row))
          (lambda (_) []) current?: (lambda () live)))
        (check-exception (core.generate generation (core.random-at 1) 0) core.stale-generation?)
        (check-equal? (list probes later) '(1 0))))
    (test-case "ordered clauses do not backtrack on values and original predicate errors propagate"
      (def fallback 0) (def later 0)
      (def Reject (.cc Type. .element?: (lambda (_) #f)))
      (def Later (.cc Type. .element?: (lambda (_) (set! later (1+ later)) #t)))
      (def Fallback (.cc Type. .element?: (lambda (_) (set! fallback (1+ fallback)) #t)))
      (def signature (CaseFunction (Function [Integer] (list Reject Later))
        (Function [Integer] (list Fallback Fallback))))
      (check (element? (FunctionArguments signature) '(1 2)) => #f)
      (check-equal? (list later fallback) '(0 0))
      (def cause (cons 'input 'predicate))
      (def Broken (.cc Type. .element?: (lambda (_) (raise cause))))
      (check-eq? (with-catch identity (lambda ()
        (element? (FunctionArguments (Function [Integer] (list Broken Later))) '(1 2)))) cause)
      (check-equal? later 0))
    (test-case "invalid generated call rows are domain errors before the property executes"
      (def later 0) (def properties 0)
      (def Reject (.cc Type. .element?: (lambda (_) #f)))
      (def Later (.cc Type. .element?: (lambda (_) (set! later (1+ later)) #t)))
      (def descriptor (FunctionArguments (Function [Integer] (list Reject Later))))
      (def sampler (make-generator descriptor (lambda (_random _size) '(1 2)) (lambda (_) []) length))
      (def report (check-property descriptor (lambda (_) (set! properties (1+ properties)) #f)
        sampler: sampler cases: 1))
      (check-eq? (.get report status) 'error)
      (check-equal? (list later properties (.get report attempts) (.get report steps)) '(0 0 0 0))
      (check (and (.get report cause) #t) => #t))
    (test-case "specialized service inputs compose callbacks defaults FUN shrinking and replay"
      (def input-checks 0) (def callback-checks 0)
      (define-type Input (.cc Integer .element?: (lambda (value)
        (set! input-checks (1+ input-checks)) (element? Integer value))
        .generator: (lambda () (from-generator Input (generator-core (generator Integer)) abs))))
      (def callbacks (List service.Callback))
      (define-type Callbacks (.cc callbacks .element?: (lambda (value)
        (set! callback-checks (1+ callback-checks)) (element? callbacks value))
        .generator: (lambda () (from-generator Callbacks (generator-core (generator callbacks)) length))))
      (def configuration (make-instance PropertyConfiguration seed: 43 cases: 20 size: 5 shrink-budget: 60))
      (def correct ((service.service-admission-tests Input Callbacks Integer service.service identity) configuration))
      (check-eq? (.get correct status) 'passed)
      ;; A real host implementation fault leaves call shape/contract admission intact.
      (def (faulty value (callbacks []) scale: (scale 1) offset: (offset 0))
        (1+ (service.service value callbacks scale: scale offset: offset)))
      (def failed ((service.service-admission-tests Input Callbacks Integer faulty identity) configuration))
      (check-eq? (.get failed status) 'failed)
      (check (replay-counterexample failed) => #f)
      (check-eq? (.get (replay-property failed) status) 'failed)
      (check (> input-checks 0) => #t)
      (check (> callback-checks 0) => #t))))

;; Keep sampler preparation controls together without another module or runner.
(include "property-testing/samplers.scm")

;; Constructor declaration bindings and required sources are checked once at
;; preparation, before draw/diagnostic/portable consumers can use inherited hooks.
;; Retain the original fixture procedures and ordered exported suite identities.
(defvalues (sampler-binding-test trace-preparation-test product-preparation-test assertion-admission-test)
  (make-preparation-suites fixed-integer integer-trace-model))
