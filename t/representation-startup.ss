;;; Fresh-process downstream entry qualification through standard Gerbil commands.
(export main)
(import :std/iter :std/misc/process
        (only-in "closure-measure.ss" measure measure-pair median monotonic-seconds))

;; Runtime-only loading and the shared-foundation exe demand the SAME business
;; module/binding. Each child has a new registry; filesystem caches are NOT reset.
;; Foreground child deadlines stay in the outer guarded process group; the
;; existing outer deadline owns the driver and all startup work.
(def (sample side width access timeout options entry)
  (def module "clan/poo/examples/representation-service")
  (def binding (make-symbol "clan/poo/examples/representation-service#" entry))
  ;; No POO import executes before the dynamic reference's cold admission.
  ;; This reports existing standard-loader state, without another module map.
  (def before
    `(let ((before (list-modules)))
      (display "MODULE-ENTRY ")
      (write (vector (and (assoc ,module before) #t)
        (andmap (lambda (id) (let ((entry (assoc id before))) (and entry (eq? (cdr entry) 'builtin))))
          '("clan/poo/object" "clan/poo/mop" "clan/poo/generalized-prototype"))
        (length before)))
      (newline) (force-output)))
  (def arguments
    (case side
      ((linked) [(path-expand "bin/representation-main" (gerbil-path)) options module (symbol->string binding) width access])
      ((import) ["gxi" options "-e" (object->string before) "-e" "(import :clan/poo/examples/representation-service)"
        "-e" (object->string `(,(string->symbol entry) ,width ,access))])
      ((runtime) ["gxi" options "-e" (object->string before) "-e"
        (object->string `(load-module ,module))
        "-e" (object->string `((eval ',binding) ,width ,access))])
      (else (error "unknown service entry" side))))
  (def clock (make-u64vector 1 0))
  (def started (monotonic-seconds clock))
  (def ready #f)
  ;; The standard reader streams every line. Timestamp the successful receipt
  ;; BEFORE waiting for EOF/exit, rather than inferring readiness from child CPU.
  (def (receive port)
    (read-all port (lambda (input)
      (let (line (read-line input))
        (when (and (string? line) (string-prefix? "MODULE-PROCESS " line))
          (set! ready (- (monotonic-seconds clock) started)))
        line))))
  (defvalues (lines metrics)
    (measure (lambda () (run-process [timeout "--foreground" "--signal=TERM" "--kill-after=3s" "90s" "/usr/bin/time" "-p" . arguments]
      stderr-redirection: #t coprocess: receive)) 1))
  (def lifetime (- (monotonic-seconds clock) started))
  ;; Refusal/nonzero exit and a missing or duplicated successful workflow marker
  ;; remain fatal. Portable time -p retains total child CPU/startup; the main time
  ;; form separately retains business evaluation/GC. Output waits until pair end.
  (let* ((prefix (string-append "SERVICE-WORKFLOW-OK " width " " access " "))
         (receipts (filter (cut string-prefix? prefix <>) lines))
         (n (string->number width))
         (totals (vector (+ (* 3 n) (* 3 (/ (* n (1- n)) 2)))
                         (+ (* 3 n) (* 4 (/ (* n (1- n)) 2)))
                         (+ (* 3 n) (* 5 (/ (* n (1- n)) 2))) (* 3 n))))
    (unless (and (= (length receipts) 1)
      (equal? (call-with-input-string (substring (car receipts) (string-length prefix) (string-length (car receipts))) read)
              (if (equal? entry "main") totals (vector totals '(30 33 3)))))
      (error "missing or incorrect complete service receipt" side lines)))
  (let (receipts (filter (cut string-prefix? "MODULE-ENTRY " <>) lines))
    (unless (and (= (length receipts) 1)
                 (string-prefix? (if (eq? side 'linked) "MODULE-ENTRY #(#f #t " "MODULE-ENTRY #(#f #f ") (car receipts)))
      (error "business module was not cold or common foundation was not linked" side receipts)))
  (let (receipts (filter (cut string-prefix? "MODULE-PROCESS " <>) lines))
    (unless (and (= (length receipts) 1)
      (let (stats (call-with-input-string (substring (car receipts) 15 (string-length (car receipts))) read))
        (and (vector? stats) (= (vector-length stats) 6) (andmap number? (vector->list stats))
             (<= 0 (vector-ref stats 2) (vector-ref stats 0)))))
      (error "missing complete process/GC counters" side receipts)))
  (unless (and ready (<= 0 ready lifetime)) (error "missing monotonic readiness timestamp" side))
  (vector side (vector-ref metrics 1) lines (vector ready lifetime (- lifetime ready))))

;; Complete every balanced pair before printing or allocating formatted output.
;; Parent elapsed time includes spawn, registry/dependency loading, initialization,
;; first demand, revisions, refusal/retry and exit; it is not child CPU time.
(def (main timeout options (width "64") (pairs "4") (reference "runtime") (entry "main"))
  (unless (member entry '("main" "joint-main")) (error "unknown service binding" entry))
  (def count (string->number pairs))
  (def baseline (cond ((equal? reference "runtime") 'runtime)
                       ((equal? reference "import") 'import)
                       (else (error "unknown service reference" reference))))
  (using (count :~ (lambda (n) (and (fixnum? n) (>= n 4))))
    (for (access '("symbolic" "indexed"))
      (for (control '(ab aa bb))
        (let ((differences []) (ready-differences []) (exit-differences []))
          (for (index (in-range (if (eq? control 'ab) count 4)))
            (let ((a (if (eq? control 'bb) 'linked baseline))
                  (b (if (eq? control 'aa) baseline 'linked))
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
