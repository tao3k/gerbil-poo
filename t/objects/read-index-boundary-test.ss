;;; Index sizing is an effect boundary unless its live delegate is stock.
(import :std/test :clan/poo/object
        (only-in :clan/poo/slot-observation %call-with-recorded-slot-reads slot-read-key)
        (only-in :std/error Error? Error-message)
        (prefix-in (only-in :gerbil/runtime/mop slot-ref slot-set!) runtime.))
(export read-index-boundary-test)
(extern namespace: clan/poo/object call-with-issued-reads)

(def (with-index action)
  (def owner (object<-alist '((port . 17))))
  (defvalues (_ roots) (%call-with-recorded-slot-reads (lambda () (.ref owner 'port))))
  (def read (car (filter (lambda (read) (eq? (slot-read-key read) 'port)) roots)))
  ;; The outer checkpoint retains the cached projection through its return
  ;; check. A GC cannot silently replace the injected index in the nested call.
  (call-with-issued-reads roots
    (lambda (_reads _current! index)
      (def checker (runtime.slot-ref read 'current?))
      (def original (runtime.slot-ref index 'length))
      (try (action roots read index original)
        (finally
          (runtime.slot-set! read 'current? checker)
          (runtime.slot-set! index 'length original)))) #t))

(def read-index-boundary-test
  (test-suite "read index sizing effect boundary"
    (test-case "an unchanged foreign delegate runs once and remains accepted"
      (with-index (lambda (roots _read index original)
        (def called 0)
        (runtime.slot-set! index 'length
          (lambda (backend) (set! called (+ 1 called)) (original backend)))
        (replay-slot-reads! roots void)
        (check-equal? called 1))))
    (test-case "changed issuance during sizing refuses before live consumption"
      (with-index (lambda (roots read index original)
        (def called 0)
        (runtime.slot-set! index 'length
          (lambda (backend)
            (set! called (+ 1 called))
            (runtime.slot-set! read 'current? (lambda (_) #t))
            (original backend)))
        (def cause (with-catch values (lambda () (replay-slot-reads! roots void) #f)))
        (check (Error? cause) => #t)
        (check-equal? (Error-message cause) "unissued slot dependency")
        (check-equal? called 1))))
    (test-case "a sizing exception retains its original cause"
      (with-index (lambda (roots _read index _original)
        (runtime.slot-set! index 'length (lambda (_) (error "length interrupted")))
        (def cause (with-catch values (lambda () (replay-slot-reads! roots void) #f)))
        (check (Error? cause) => #t)
        (check-equal? (Error-message cause) "length interrupted"))))
    (test-case "preflight refusal precedes any sizing callback"
      (with-index (lambda (roots read index original)
        (def called 0)
        (runtime.slot-set! index 'length
          (lambda (backend) (set! called (+ 1 called)) (original backend)))
        (runtime.slot-set! read 'current? (lambda (_) #t))
        (def cause (with-catch values (lambda () (replay-slot-reads! roots void) #f)))
        (check (Error? cause) => #t)
        (check-equal? (Error-message cause) "unissued slot dependency")
        (check-equal? called 0))))))
