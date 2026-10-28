;;; Downstream PBT workflows use records, ordinary ports and the standard TestSuite.
(export property-workflows-test main)
(import :std/test :std/error :std/iter :std/io/tempfile
        (only-in :std/misc/process run-process) (only-in :std/misc/ports read-all-as-lines)
        (prefix-in :clan/property-testing/generator g.)
        (prefix-in :clan/property-testing/property p.)
        (prefix-in :clan/property-testing/replay r.))
;; The same explicit domain is used before and after serializing a counterexample.
(def integer-domain (p.make-specification exact-integer? abs))
;; Portable identity names the application's format, specification and generator.
(def (ledger-codec (identity 'ledger-v1)) (r.make-codec identity values values))
;; This property intentionally exposes a small, replayable ledger error.
(def (ledger-property value) (< value 3))
;; The standard module-action loader can execute this in a fresh process.
(def (main file (identity "ledger-v1"))
  (unless (eq? (call-with-input-file file
    (lambda (port) (r.read-counterexample (ledger-codec (string->symbol identity))
      port integer-domain ledger-property))) #f) (error "expected a failing ledger witness"))
  (displayln "REPLAY-FAILED"))
;; Named syntax expands into the existing runner, preserving property identity.
(p.define-property (named-ledger value) (g.generator-unit 2) integer-domain (< value 3))
;; One workflow owns source revisions, so stale generators and retained functions agree.
(def property-workflows-test
  (test-suite "coverage portable replay and finite functions"
    (test-case "effective trials classify once and reject unmet coverage"
      (def policy (p.make-policy name: 'ledger
        labels: (lambda (value) (if (even? value) '(even even) '(odd))) required: '((even . 3))))
      (def good (p.check-property (g.generator-unit 2) ledger-property integer-domain cases: 3 policy: policy))
      (check-eq? (p.report-status good) 'passed)
      (check-equal? (p.report-labels good) '((even . 3)))
      (check-equal? (list (p.report-accepted good) (p.report-discarded good)) '(3 0))
      (check-eq? (p.report-name (named-ledger cases: 1)) 'named-ledger)
      (check-eq? (p.report-status (p.check-property (g.generator-unit 1) ledger-property integer-domain
        cases: 3 policy: policy)) 'coverage))
    (test-case "discard exhaustion never becomes successful coverage"
      (def calls 0)
      (def report (p.check-property (g.generator-unit 2)
        (lambda (_) (set! calls (1+ calls)) #t) integer-domain cases: 2
        policy: (p.make-policy precondition: (lambda (_) #f) discard-budget: 3)))
      (check-eq? (p.report-status report) 'exhausted)
      (check-equal? calls 0)
      (check-equal? (p.report-discarded report) 4)
      (check-equal? (p.report-accepted report) 0))
    (test-case "shrinks preserve preconditions without inflating labels"
      (def labels 0)
      (def report (p.check-property (g.make-generator (lambda (_random _size) 8) g.integer-shrinks)
        (lambda (_) #f) integer-domain cases: 5
        policy: (p.make-policy precondition: positive?
          labels: (lambda (_) (set! labels (1+ labels)) '(retry)) required: '((retry . 5)))))
      (check-eq? (p.report-status report) 'failed)
      (check-equal? (p.report-counterexample report) 1)
      (check-equal? labels 1)
      (check-equal? (p.report-labels report) '((retry . 1)))
      (check-eq? (p.replay-counterexample report) #f)
      (check-eq? (p.report-status (p.replay-property report)) 'failed))
    (test-case "classification errors and invalid policies retain refusal"
      (check-exception (p.make-policy required: '((retry . -1))) Error?)
      (check-eq? (p.report-status (p.check-property (g.generator-unit 1) ledger-property integer-domain
        policy: (p.make-policy labels: (lambda (_) #f)))) 'error))
    (test-case "portable data replay refuses identity before any decoder or fixture"
      (def report (p.check-property (g.generator-unit 4) ledger-property integer-domain cases: 1))
      (def output (open-output-string))
      (r.write-counterexample report (ledger-codec) output)
      (def text (get-output-string output))
      (check-eq? (r.read-counterexample (ledger-codec) (open-input-string text) integer-domain ledger-property) #f)
      (def cause (cons 'callback 'refusal))
      (check-eq? (with-catch values (lambda ()
        (r.read-counterexample (ledger-codec) (open-input-string text) integer-domain
          (lambda (_) (raise cause))))) cause)
      (def calls 0)
      (check-exception (r.read-counterexample
        (r.make-codec 'changed values (lambda (value) (set! calls (1+ calls)) value))
        (open-input-string text) integer-domain ledger-property) Error?)
      (check-equal? calls 0)
      (check-exception (r.read-counterexample (ledger-codec)
        (open-input-string (string-append text " extra")) integer-domain ledger-property) Error?))
    (test-case "codec failures are atomic before writes and stale sources refuse"
      (def report (p.check-property (g.generator-unit 4) ledger-property integer-domain cases: 1))
      (def output (open-output-string))
      (check-exception (r.write-counterexample report (r.make-codec 'bad (lambda (_) values) values) output) Error?)
      (check-equal? (get-output-string output) "")
      (check-exception (r.write-counterexample report
        (r.make-codec 'bad values values current?: (lambda () #f)) output) Error?)
      (check-exception (r.write-counterexample report
        (r.make-codec 'bad (lambda (_) '(1 2 3)) values nodes: 2) output) Error?))
    (test-case "a fresh process restores the concrete counterexample"
      (call-with-temporary-directory "property-replay-" (lambda (directory)
        (def file (path-expand "witness.scm" directory))
        (def report (p.check-property (g.generator-unit 4) ledger-property integer-domain cases: 1))
        (call-with-output-file file (cut r.write-counterexample report (ledger-codec) <>))
        (def timeout (car (run-process '("sh" "-c" "command -v gtimeout || command -v timeout") coprocess: read-all-as-lines)))
        (def lines (run-process (list timeout "--signal=TERM" "--kill-after=3s" "30s"
          (path-expand "bin/representation-main" (getenv "GERBIL_PATH")) "-:max-heap=1G,debug=q"
          "clan/poo/examples/property-workflows" "clan/poo/examples/property-workflows#main" file)
          coprocess: read-all-as-lines))
        (check (and (member "REPLAY-FAILED" lines) #t) => #t))))
    (test-case "finite function tuples shrink with repeatable multi-value calls"
      (def results (g.make-generator (lambda (_random _size) '(8 8))
        (lambda (tuple) (if (zero? (car tuple)) [] (list '(0 0) (map (cut quotient <> 2) tuple))))))
      (def functions (g.generator-function '((1) (2) (1 scale: 2)) results))
      (def tree (g.generate functions (g.random-at 42) 10))
      (def value (g.sample-value tree))
      (check-equal? (g.function-apply value '(1)) '(8 8))
      (check-equal? (call-with-values (cut (g.function-procedure value) 1 scale: 2) list) '(8 8))
      (check-exception ((g.function-procedure value) 99) Error?)
      (check-exception (g.generator-function '((1) (1)) results) Error?)
      (check-exception (g.generator-function '((1)) results domain-limit: 0) Error?)
      (def domain (p.make-specification g.function-value?
        (lambda (function) (apply + (g.function-apply function '(1))))))
      (def report (p.check-property functions (lambda (function) (< (car (g.function-apply function '(1))) 3)) domain cases: 1))
      (check-eq? (p.report-status report) 'failed)
      (check-equal? (car (g.function-apply (p.report-counterexample report) '(1))) 4)
      (check-eq? (p.replay-counterexample report) #f))
    (test-case "function counterexamples restore from finite tables without closures"
      (def generator (g.generator-function '((1) (2)) (g.generator-unit '(4 5))))
      (def domain (p.make-specification g.function-value? (lambda (_) 0)))
      (def property (lambda (function) (< (car (g.function-apply function '(1))) 3)))
      (def report (p.check-property generator property domain cases: 1))
      (def codec (r.make-codec '(function-table 1) g.function-table g.function-from-table))
      (def port (open-output-string))
      (r.write-counterexample report codec port)
      (check (r.read-counterexample codec (open-input-string (get-output-string port)) domain property) => #f)
      (check-exception (g.function-from-table '(((1) . (4)) ((1) . (5)))) Error?))
    (test-case "retained function calls and replay reject stale branch sources"
      (def live #t)
      (def functions (g.generator-function '((1)) (g.generator-unit '(2)) current?: (lambda () live)))
      (def value (g.sample-value (g.generate functions (g.random-at 1) 0)))
      (set! live #f)
      (check-exception ((g.function-procedure value) 1) g.stale-generation?))))
