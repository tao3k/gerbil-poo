(export debug-test)

(import
  :std/test
  ../debug
  (only-in ../object .o .ref)
  (only-in ../mop Type))

(def (capture-ddt type value)
  (with-output-to-string
    (lambda ()
      (parameterize ((current-error-port (current-output-port)))
        (DDT-helper 'tag '() '() '() 'value type (lambda () value))))))

(def debug-test
  (test-suite "test suite for clan/poo/debug"
    (test-case "tracing retains inherited object slots"
      (def prototype (.o (sexp 'sample) (answer 42)))
      (def traced (trace-poo prototype 'sample))
      (check (.ref traced 'sexp) => 'sample)
      (check (.ref traced 'answer) => 42))
    (test-case "conversion errors use the standard written representation"
      (check (capture-ddt (lambda (_) (error "conversion failed")) '(a 1))
             => "tag\n  value => [CONVERSION ERROR] (a 1)\n"))
    (test-case "type errors use the standard written representation"
      (check (capture-ddt Type '(a 1))
             => "tag\n  value => [TYPE ERROR: not a Type] (a 1)\n"))))
