;;; Native data/standard process helpers shared by the fixed benchmark driver.
(export (import: "closure-measure.ss") run-bounded read-one check-sources!)
(import :std/misc/process
        "closure-measure.ss")
(def (read-one port)
  (def datum (read port))
  (when (eof-object? datum) (error "missing benchmark datum"))
  (unless (eof-object? (read port)) (error "extra benchmark datum"))
  datum)
(def (run-bounded timeout arguments)
  (def status 0)
  (def output (run-process (append (list timeout "--signal=TERM" "--kill-after=3s" "20s") arguments)
                 stdin-redirection: #f stderr-redirection: #t
                 check-status: (lambda (value _) (set! status value))))
  (values status output))
(def (check-sources! recorded (root "."))
  (unless (equal? recorded (source-digests (map car recorded) root)) (error "benchmark source changed")))
