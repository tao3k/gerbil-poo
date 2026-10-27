;;; Fresh-process downstream entry qualification through standard Gerbil commands.
(export main)
(import :std/iter :std/misc/process (only-in :std/misc/ports read-all-as-lines)
        (only-in "closure-measure.ss" measure measure-pair median))

;; Ordinary module imports and the standard exe call exactly the same exported
;; main. Each child has its own module registry; filesystem caches are NOT reset.
;; Foreground child deadlines stay in the outer guarded process group; the
;; existing outer deadline owns the driver and all startup work.
(def (sample side width access timeout options)
  (def arguments
    (case side
      ((linked) [(path-expand "bin/representation-main" (gerbil-path)) options width access])
      ((import) ["gxi" options "-e" "(import :clan/poo/examples/representation-service)"
        "-e" (object->string `(main ,width ,access))])
      ((runtime) ["gxi" options "-e"
        (object->string '(load-module "clan/poo/examples/representation-service"))
        "-e" (object->string `((eval 'clan/poo/examples/representation-service#main) ,width ,access))])
      (else (error "unknown service entry" side))))
  (defvalues (lines metrics)
    (measure (lambda () (run-process [timeout "--foreground" "--signal=TERM" "--kill-after=3s" "90s" "/usr/bin/time" "-p" . arguments]
      stderr-redirection: #t coprocess: read-all-as-lines)) 1))
  ;; Refusal/nonzero exit and a missing or duplicated successful workflow marker
  ;; remain fatal. Portable time -p retains total child CPU/startup; the main time
  ;; form separately retains business evaluation/GC. Output waits until pair end.
  (unless (= 1 (length (filter (cut string-prefix? "SERVICE-WORKFLOW-OK " <>) lines)))
    (error "missing service workflow receipt" side lines))
  (vector side (vector-ref metrics 1) lines))

;; Complete every balanced pair before printing or allocating formatted output.
;; Parent elapsed time includes spawn, registry/dependency loading, initialization,
;; first demand, revisions, refusal/retry and exit; it is not child CPU time.
(def (main timeout options (width "64") (pairs "4") (reference "runtime"))
  (def count (string->number pairs))
  (def baseline (cond ((equal? reference "runtime") 'runtime)
                       ((equal? reference "import") 'import)
                       (else (error "unknown service reference" reference))))
  (using (count :~ (lambda (n) (and (fixnum? n) (>= n 4))))
    (for (access '("symbolic" "indexed"))
      (for (control '(ab aa bb))
        (let (differences [])
          (for (index (in-range (if (eq? control 'ab) count 4)))
            (let ((a (if (eq? control 'bb) 'linked baseline))
                  (b (if (eq? control 'aa) baseline 'linked))
                  (samples []))
              (measure-pair (if (even? index) '(a b) '(b a))
                (lambda (slot)
                  (let (result (sample (if (eq? slot 'a) a b) width access timeout options))
                    (set! samples (cons (cons slot result) samples)) result))
                (lambda (results)
                  (for-each (lambda (entry)
                    (write (vector 'service-startup access control index (car entry) (cdr entry)))
                    (newline)) results) (force-output)))
              (set! differences (cons (- (vector-ref (cdr (assq 'b samples)) 1)
                                        (vector-ref (cdr (assq 'a samples)) 1)) differences))))
          (displayln "SERVICE-STARTUP-SUMMARY " access "/" control
            " wall-seconds=" (median differences)
            " min=" (apply min differences) " max=" (apply max differences)) (force-output)))))
  (displayln "SERVICE-STARTUP-OK"))
