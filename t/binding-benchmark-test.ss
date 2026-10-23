(export binding-benchmark-test)
(import :std/test :std/iter (only-in "binding-benchmark.ss" workload)
  (only-in "closure-measure.ss" measure-pair)
  (prefix-in "binding-cases.ss" study.) (prefix-in "metadata-paired-suite.ss" paired.))
;; Verify real controls, duplicate identity and fixed complete coverage before AOT.
(def binding-benchmark-test
  (test-suite "context binding paired controls"
    (test-case "paired reporting follows both samples in either order without replay"
      (for (order '((a b) (b a)))
        (def events [])
        (def result (measure-pair order
          (lambda (side) (set! events (cons side events)) side)
          (lambda (completed)
            (check-equal? (reverse events) order)
            (check-equal? (map car completed) order)
            (set! events (cons 'report events)))))
        (check-equal? (reverse events) (append order '(report)))
        (check-equal? (reverse result) (map (lambda (side) (cons side side)) order))))
    (test-case "pair refusal reports its successful prefix once and preserves the exact cause"
      (for (fail-at '(a b))
        (def cause (list 'pair-refused fail-at)) (def events []) (def reports 0)
        (def completed #f)
        (check-exception (measure-pair '(a b)
          (lambda (side)
            (set! events (cons side events))
            (when (eq? side fail-at) (raise cause)) side)
          (lambda (prefix) (set! reports (+ reports 1)) (set! completed prefix)))
          (lambda (actual) (eq? cause actual)))
        (check-equal? reports 1)
        (check-equal? (reverse events) (if (eq? fail-at 'a) '(a) '(a b)))
        (check-equal? completed (if (eq? fail-at 'a) [] '((a . a))))))
    (test-case "reporting failure remains fatal without replaying either measured action"
      (def cause (list 'report-refused)) (def calls [])
      (check-exception (measure-pair '(a b)
        (lambda (side) (set! calls (cons side calls)) side)
        (lambda (_) (raise cause))) (lambda (actual) (eq? cause actual)))
      (check-equal? (reverse calls) '(a b)))
    (test-case "all phases execute real current public observations"
      (for (scenario study.scenarios)
        (def actions (workload scenario))
        (check (eq? (car actions) (caddr actions)) => #t)
        (check (eq? (cadr actions) (cadddr actions)) => #t)
        (for (action actions) (check (action) => #t))))
    (test-case "fixed complete study restores the driver configuration"
      (def before (paired.expected-order))
      (check-equal? (paired.with-study study.specification (lambda () (length (paired.expected-order)))) 576)
      (check-equal? (paired.expected-order) before))))
