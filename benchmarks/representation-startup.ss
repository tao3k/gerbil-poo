;;; Fresh-process downstream entry qualification through standard Gerbil commands.
(export main representation-startup-test check-study check-observation-test)
(import :std/test :std/iter :std/misc/process
        (only-in :gerbil/runtime/loader load-module list-modules)
        (only-in :std/error Error?) (only-in :std/number/misc uint?)
        (only-in :std/test/base test-run! test-result-error? TestResultError? TestResultError
          TestResultErrors? TestResultErrors TestHarness TestModule TestConfig TestSuite)
        (only-in :std/list/list drop-right append-map)
        (only-in :std/crypto/digest sha256) (only-in :std/encoding/hex hex-encode)
        (only-in "closure-measure.ss" measure measure-pair median monotonic-seconds monotonic-ticks monotonic-frequency))

;; Exact tick intervals partition the complete public command. Readiness and
;; post-report windows include pipe/shell/reaping costs, not just dyld or GC.
(def (check-phase-summary started marks finished modules begun passed)
  (unless (and (> modules 0) (> begun 0) (= begun passed))
    (error "incomplete check observation" modules begun passed))
  (def points (append [started]
    (map (lambda (name)
      (cond ((assq name marks) => cdr) (else (error "missing check phase" name))))
      '(test-start harness-start harness-end report test-exit eof)) [finished]))
  (unless (and (andmap uint? points)
    (andmap <= (drop-right points 1) (cdr points)))
    (error "nonmonotone check observation"))
  (map cons '(build prepare tests report cleanup studies reap)
    (map - (cdr points) (drop-right points 1))))

;; Observe `just check`, whose existing recipes invoke only gerbil build/test.
;; Targets, deadlines, failure detection and cleanup remain owned by those tools.
;; No source discovery, loader or result cache is installed by this observer.
(def (check-study prefix (entry "check"))
  (using ((prefix :~ string?) (entry :~ string?))
    ;; Prepared-artifact diagnostics use the existing complete check-built recipe.
    ;; Whitelist public entries; this observer cannot become an arbitrary runner.
    (unless (member entry '("check" "check-built"))
      (error "unknown complete check entry" entry))
    (def clock (make-u64vector 1 0))
    (def marks []) (def suite #f) (def trace [])
    (def modules 0) (def begun 0) (def passed 0)
    (def started (monotonic-ticks clock))
    ;; Keep the first event only; later declaration/study harnesses are separate.
    (def (mark! name)
      (unless (assq name marks)
        (set! marks (cons (cons name (monotonic-ticks clock)) marks))))
    ;; Standard process coprocessing forwards real progress while retaining only
    ;; the ordered suite/case trace, not a second escaped copy of all stdout.
    (def (receive port)
      (read-all port (lambda (input)
        (let (line (read-line input))
          (if (eof-object? line) (begin (mark! 'eof) line)
            (begin
              (displayln line) (force-output)
              (cond
                ((string-prefix? "just _test " line) (mark! 'test-start))
                ((string-prefix? "HARNESS " line) (mark! 'harness-start))
                ((string-prefix? "HARNESS-OK " line) (mark! 'harness-end))
                ((and (assq 'harness-end marks) (equal? line "OK")) (mark! 'report))
                ((and (assq 'report marks) (string-prefix? "real " line)) (mark! 'test-exit)))
              (when (and (assq 'harness-start marks) (not (assq 'harness-end marks)))
                (cond
                  ((string-prefix? "SUITE " line) (set! suite (substring line 6 (string-length line))))
                  ((string-prefix? "CASE " line) (set! begun (+ begun 1)))
                  ((string-prefix? "CASE-OK " line)
                   (set! passed (+ passed 1))
                   (set! trace (cons (list suite (substring line 8 (string-length line))) trace)))
                  ((string-prefix? "MODULE-OK " line) (set! modules (+ modules 1)))))
              (void)))))))
    ;; A nonzero public-command exit propagates through std/process, even when
    ;; an intermediate harness printed OK. Only a reaped successful child qualifies.
    (run-process ["env" (string-append "GERBIL_PATH=" (path-expand prefix))
      "just" entry "2" "1" "4" "600"] stderr-redirection: #t coprocess: receive)
    (def finished (monotonic-ticks clock))
    (def phases (check-phase-summary started marks finished modules begun passed))
    (def digest (hex-encode (sha256 (string->utf8 (object->string (reverse trace))))))
    (write (list 'check-observation (cons 'entry entry) (cons 'frequency monotonic-frequency)
      (cons 'phase-ticks phases) (cons 'modules modules) (cons 'cases passed)
      (cons 'case-trace-sha256 digest) (cons 'total-ticks (- finished started))))
    (newline) (force-output)))

;; These fast controls use the real standard TestHarness, including a failed
;; middle case. Regrouping is admitted only for fixture-free module boundaries.
(def check-observation-test
  (test-suite "check phase observations"
    (test-case "exact phase ticks retain preparation execution and exit windows"
      (check (check-phase-summary 100
        '((test-start . 110) (harness-start . 130) (harness-end . 190)
          (report . 200) (test-exit . 210) (eof . 220)) 230 4 8 8) =>
        '((build . 10) (prepare . 20) (tests . 60) (report . 10)
          (cleanup . 10) (studies . 10) (reap . 10))))
    (test-case "missing nonmonotone and incomplete observations refuse"
      (check-exception (check-study "unused" "unknown") Error?)
      (check-exception (check-phase-summary 0 [] 10 1 1 1) Error?)
      (check-exception (check-phase-summary 0
        '((test-start . 2) (harness-start . 1) (harness-end . 3)
          (report . 4) (test-exit . 5) (eof . 6)) 7 1 1 1) Error?)
      (check-exception (check-phase-summary 0 [] 10 0 0 0) Error?)
      (check-exception (check-phase-summary 0 [] 10 1 2 1) Error?))
    (test-case "standard suite regrouping retains failures identity and later cases"
      ;; New harness objects retain their own private observation state.
      (def (observe grouped?)
        (def seen []) (def cause (gensym 'case-refused))
        ;; A single standard suite factory keeps case construction identical.
        (def suites (map (lambda (name)
          (TestSuite (symbol->string name) (lambda ()
            (test-case "delivery"
              (set! seen (cons name seen))
              (when (eq? name 'middle) (raise cause)))))) '(first middle last)))
        (def modules (if grouped? [(TestModule "group" suites [] void void)]
          (map (lambda (suite) (TestModule "unit" [suite] [] void void)) suites)))
        (def result (test-run! (TestHarness "regrouping"
          (TestConfig verbosity: 0 capture-output?: #t) modules)))
        ;; Read causes through the official result hierarchy, not stdout matching.
        (def (causes result)
          (cond
            ((TestResultError? result) (using (item result :- TestResultError) [item.exn]))
            ((TestResultErrors? result) (using (item result :- TestResultErrors) (append-map causes item.errors)))
            (else [])))
        (def failures (causes result))
        (list (reverse seen) (test-result-error? result)
          (and (= (length failures) 1) (eq? (car failures) cause))))
      (check (observe #f) => '((first middle last) #t #t))
      (check (observe #t) => '((first middle last) #t #t)))))

;; Standard-built programs demand the SAME business
;; module/binding. Each child has a new registry; filesystem caches are NOT reset.
;; Foreground child deadlines stay in the outer guarded process group; the
;; existing outer deadline owns the driver and all startup work.
(def (sample side width access timeout options entry)
  (def module "clan/poo/examples/representation-service")
  (def binding (make-symbol "clan/poo/examples/representation-service#" entry))
  (def arguments
    (case side
        ((linked) [(path-expand "bin/representation-main" (gerbil-path)) options module (symbol->string binding) width access])
        ((dynamic) [(path-expand "bin/representation-startup" (gerbil-path)) options entry width access])
        (else (error "unknown service entry" side))))
  ;; Explicit nesting orders snapshots around IO even in compiled code. The
  ;; stream reader records readiness before EOF/exit, independently of child CPU.
  (let* ((clock (make-u64vector 1 0)) (started (monotonic-seconds clock)) (ready #f))
    ;; Reuse the standard reader; no sample is re-executed to obtain its receipt.
    (def (receive port)
      (read-all port (lambda (input)
        (let (line (read-line input))
          (when (and (string? line) (string-prefix? "MODULE-PROCESS " line))
            (set! ready (- (monotonic-seconds clock) started)))
          line))))
    (let-values (((lines metrics)
      (measure (lambda () (run-process [timeout "--foreground" "--signal=TERM" "--kill-after=3s" "90s"
        "/usr/bin/time" "-p" . arguments] stderr-redirection: #t coprocess: receive)) 1)))
      (let* ((lifetime (- (monotonic-seconds clock) started))
             (prefix (string-append "SERVICE-WORKFLOW-OK " width " " access " "))
             (receipts (filter (cut string-prefix? prefix <>) lines))
             (n (string->number width))
             (totals (vector (+ (* 3 n) (* 3 (/ (* n (1- n)) 2)))
                             (+ (* 3 n) (* 4 (/ (* n (1- n)) 2)))
                             (+ (* 3 n) (* 5 (/ (* n (1- n)) 2))) (* 3 n))))
        ;; Full results, original failures and process/GC receipts remain mandatory.
        (unless (and (= (length receipts) 1)
          (equal? (call-with-input-string
                    (substring (car receipts) (string-length prefix) (string-length (car receipts))) read)
                  (if (equal? entry "main") totals (vector totals '(30 33 3)))))
          (error "missing or incorrect complete service receipt" side lines))
        (let (receipts (filter (cut string-prefix? "MODULE-ENTRY " <>) lines))
          (unless (and (= (length receipts) 1)
            (string-prefix? (if (eq? side 'linked)
              "MODULE-ENTRY #(#f #t " "MODULE-ENTRY #(#f #f ") (car receipts)))
            (error "business module was not cold or common foundation was not linked" side receipts)))
        (let (receipts (filter (cut string-prefix? "MODULE-PROCESS " <>) lines))
          (unless (and (= (length receipts) 1)
            (let (stats (call-with-input-string (substring (car receipts) 15 (string-length (car receipts))) read))
              (and (vector? stats) (= (vector-length stats) 6) (andmap number? (vector->list stats))
                   (<= 0 (vector-ref stats 2) (vector-ref stats 0)))))
            (error "missing complete process/GC counters" side receipts)))
        (unless (and ready (<= 0 ready lifetime)) (error "missing monotonic readiness timestamp" side))
        (vector side
          (vector-ref metrics 1) lines (vector ready lifetime (- lifetime ready)))))))

;; Complete every balanced pair before printing or allocating formatted output.
;; Parent elapsed time includes spawn, registry/dependency loading, initialization,
;; first demand, revisions, refusal/retry and exit; it is not child CPU time.
(def (study timeout options (width "64") (pairs "4") (entry "main"))
  (unless (member entry '("main" "joint-main")) (error "unknown service binding" entry))
  (def count (string->number pairs))
  (using (count :~ (lambda (n) (and (fixnum? n) (>= n 4))))
    (for (access '("symbolic" "indexed"))
      (for (control '(ab aa bb))
        (let ((differences []) (ready-differences []) (exit-differences []))
          (for (index (in-range (if (eq? control 'ab) count 4)))
            (let ((a (if (eq? control 'bb) 'linked 'dynamic))
                  (b (if (eq? control 'aa) 'dynamic 'linked))
                  (samples []))
              (measure-pair (if (even? index) '(a b) '(b a))
                (lambda (slot)
                  (let (result (sample (if (eq? slot 'a) a b) width access timeout options entry))
                    (set! samples (cons (cons slot result) samples)) result))
                (lambda (results)
                  (for-each (lambda (completed)
                    (write (vector 'service-startup entry access control index (car completed) (cdr completed)))
                    (newline)) results) (force-output)))
              (let ((a (cdr (assq 'a samples))) (b (cdr (assq 'b samples))))
                (set! differences (cons (- (vector-ref b 1) (vector-ref a 1)) differences))
                (set! ready-differences (cons (- (vector-ref (vector-ref b 3) 0) (vector-ref (vector-ref a 3) 0)) ready-differences))
                (set! exit-differences (cons (- (vector-ref (vector-ref b 3) 2) (vector-ref (vector-ref a 3) 2)) exit-differences)))))
          (displayln "SERVICE-STARTUP-SUMMARY " entry "/" access "/" control
            " wall-seconds=" (median differences)
            " min=" (apply min differences) " max=" (apply max differences)
            " ready-seconds=" (median ready-differences) " ready-min=" (apply min ready-differences) " ready-max=" (apply max ready-differences)
            " after-ready-seconds=" (median exit-differences) " after-ready-min=" (apply min exit-differences) " after-ready-max=" (apply max exit-differences)) (force-output)))))
  (displayln "SERVICE-STARTUP-OK"))

;; Standard exe main for the unlinked reference: no generated expressions or
;; interpreter subprocess. Observe admission BEFORE loading the existing IO
;; action, then reuse its current-binding/failure/multiple-values semantics.
;; The closed binding inventory is ordinary program code, never a command string.
(def main
  (case-lambda
    ;; The existing standard-built executable owns the observation command too.
    ((prefix) (check-study prefix))
    ((prefix entry) (check-study prefix entry))
    ((entry width access)
  (unless (and (member entry '("main" "joint-main"))
               (member access '("symbolic" "indexed")))
    (error "unknown service entry" entry access))
  (let (before (list-modules))
    (display "MODULE-ENTRY ")
    (write (vector (and (assoc "clan/poo/examples/representation-service" before) #t)
      (andmap (lambda (id) (let (item (assoc id before)) (and item (eq? (cdr item) 'builtin))))
        '("clan/poo/object" "clan/poo/mop" "clan/poo/fun"))
      (length before)))
    (newline) (force-output))
  (load-module "clan/poo/io")
  (((eval 'clan/poo/io#module-action) "clan/poo/examples/representation-service"
    (make-symbol "clan/poo/examples/representation-service#" entry)) (list width access)))))

;; The official gerbil test harness owns suite discovery and failure reporting.
;; Both full bindings retain every AB/BA and A/A/B/B sample. Child programs keep
;; the existing 90-second/1-GiB bounds; the public recipe retains its outer guard.
(def representation-startup-test
  (test-suite "standard-built dynamic module entry pairs"
    (test-case "unknown compiled entry requests retain refusal"
      (for (request '(("unknown" "64" "symbolic") ("main" "64" "unknown")))
        (check-exception
          (run-process [(cond-expand (darwin "gtimeout") (else "timeout"))
            "--foreground" "--signal=TERM" "--kill-after=3s" "90s"
            (path-expand "bin/representation-startup" (gerbil-path))
            "-:max-heap=1G,debug=q" . request] stderr-redirection: #t)
          process-error?)))
    (test-case "complete service entry pairs"
      (study (cond-expand (darwin "gtimeout") (else "timeout"))
        "-:max-heap=1G,debug=q" "64" "4" "main"))
    (test-case "joint service and checkout entry pairs"
      (study (cond-expand (darwin "gtimeout") (else "timeout"))
        "-:max-heap=1G,debug=q" "64" "4" "joint-main"))))
