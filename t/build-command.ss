;;; Observe backend commands through GCC's wrapper interface, preserving pipes.
(export main parse-command-timing)
(import :std/misc/process :std/misc/ports :std/os/pid)

;; Accept only the complete POSIX time footer. Missing/invalid metrics are not
;; zero-cost observations, and compiler diagnostics remain ordinary stderr.
(def (parse-command-timing lines)
  (and (= (length lines) 3)
    (with-catch (lambda (_) #f)
      (lambda ()
        (def fields (map (lambda (line expected)
          (call-with-input-string line (lambda (port)
            (let* ((name (read port)) (value (read port)) (end (read port)))
              (and (eq? name expected) (real? value) (>= value 0) (< value +inf.0)
                (eof-object? end) (cons name value)))))) lines '(real user sys)))
        (and (andmap values fields) fields)))))

;; Each process owns one Scheme trace. Standard process redirection inherits
;; stdin/stdout so GCC -pipe still passes assembler input without interception.
;; Only the time footer is recorded; compiler diagnostics are forwarded once.
(def (observe-command role command)
  (def directory (getenv "POO_BUILD_COMMAND_TRACE"))
  (create-directory* directory)
  ;; Delay at most three stderr lines to recognize time's final footer. Long
  ;; compiler diagnostics stream to the caller instead of growing the heap.
  (def (forward line) (display line (current-error-port)) (newline (current-error-port)))
  (def (read-footer process)
    (let loop ((tail []))
      (let (line (read-line process))
        (if (eof-object? line) tail
          (let (next (append tail [line]))
            (if (> (length next) 3)
              (begin (forward (car next)) (loop (cdr next)))
              (loop next)))))))
  (def status (call-with-output-file (path-expand (string-append (number->string (getpid)) ".scm") directory)
    (lambda (port)
      ;; Complete records permit pairing nested inclusive command intervals.
      (def (emit datum) (write datum port) (newline port) (force-output port))
      (def waited #f)
      (emit `(begin ,(time->seconds (current-time)) ,(getppid) ,role ,(current-directory) ,command))
      (def lines (run-process (cons "/usr/bin/time" (cons "-p" command))
        stdin-redirection: #f stdout-redirection: #f stderr-redirection: #t
        coprocess: read-footer check-status: (lambda (value _) (set! waited value))))
      (def timing (parse-command-timing lines))
      (unless timing (for-each forward lines))
      (emit `(end ,(time->seconds (current-time)) (wait-status ,waited) (timing ,timing)))
      (force-output (current-error-port))
      waited)))
  (exit (if (zero? (bitwise-and status 255)) (arithmetic-shift status -8)
    (+ 128 (bitwise-and status 127)))))

;; GCC receives an explicit cc mode and invokes tool mode for cc1/as/collect2.
;; All other arguments pass unchanged to the explicitly selected release GSC.
(def (main . args)
  (cond-expand (darwin (void)) (else (error "this observer measures macOS only")))
  (match args
    (["cc" . options]
      (observe-command 'cc
        (append [(getenv "POO_BUILD_CC") "-wrapper"
          (string-append (path-normalize (car (command-line))) ",tool")] options)))
    (["tool" . command] (observe-command 'tool command))
    (else (observe-command 'gsc (cons (getenv "POO_BUILD_GSC") args)))))
