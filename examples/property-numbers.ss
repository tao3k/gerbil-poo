;;; Numeric profiles reuse ordinary products, source scopes and replay codecs.
(export rational-test-cases!)
(import :std/test :std/error :std/iter
  (prefix-in :clan/poo/testing/property/generator g.)
  (prefix-in :clan/poo/testing/property p.)
  (prefix-in :clan/poo/testing/property/replay r.))

;; A ratio is a numeric value; its normalized numerator/denominator supply one
;; natural rank and one value-shrink policy, not a floating representation oracle.
(def (rational-test-cases!)
  (def domain (p.make-specification rational? g.rational-weight))
  (test-case "exact ratios respect size positive denominators and explicit caps"
    (def generation (g.generator-rational max-denominator: 7))
    (for (seed (in-range 30))
      (def size (list-ref '(0 1 8 20) (modulo seed 4)))
      (def value (g.sample-value (g.generate generation (g.random-at seed) size)))
      (check (and (rational? value) (exact? value)) => #t)
      (check (<= (abs (numerator value)) size) => #t)
      (check (<= 1 (denominator value) (min 7 (1+ size))) => #t))
    (check-equal? (g.sample-value (g.generate generation (g.random-at 8) 0)) 0))
  (test-case "ratio configuration and nonrational values refuse without fallback"
    (for (limit '(0 -1 #f 1.5))
      (check-exception (g.generator-rational max-denominator: limit) Error?))
    (for (value (list 'invalid +inf.0 -inf.0 +nan.0))
      (check-exception (g.rational-weight value) Error?)
      (check-exception (g.rational-shrinks value) Error?)))
  (test-case "canonical ratio shrinking is strict and normalizes equivalent values"
    (check-equal? (g.rational-weight 2/4) 2)
    (check-equal? (g.rational-weight 0.5) 2)
    (check-equal? (g.rational-shrinks 1/2) '(0 1))
    (check-equal? (g.rational-shrinks 0) [])
    (for (value '(0 1 -1 1/2 -2/3 22/7 0.5))
      (for (smaller (g.rational-shrinks value))
        (check (and (rational? smaller) (exact? smaller) (> (denominator smaller) 0)) => #t)
        (check (< (g.rational-weight smaller) (g.rational-weight value)) => #t)))
    (check-equal? (g.rational-shrinks 2/4) (g.rational-shrinks 1/2)))
  (test-case "ratio profiles replay seeds and denominator one stays integral"
    (for (seed (in-range 20))
      (check-equal? (g.sample-value (g.generate (g.generator-rational) (g.random-at seed) 8))
        (g.sample-value (g.generate (g.generator-rational) (g.random-at seed) 8)))
      (check (integer? (g.sample-value (g.generate
        (g.generator-rational max-denominator: 1) (g.random-at seed) 8))) => #t)))
  (test-case "fractional failures shrink to a canonical boundary with both replay forms"
    (def report (p.check-property (g.generator-rational) integer? domain
      seed: 42 cases: 40 size: 8 shrink-budget: 128))
    (check-eq? (p.report-status report) 'failed)
    (check-equal? (abs (p.report-counterexample report)) 1/2)
    (check (p.report-minimal? report) => #t)
    (def again (p.replay-property report))
    (check-equal? (p.report-counterexample again) (p.report-counterexample report))
    (check-equal? (p.report-attempts again) (p.report-attempts report))
    (check (p.replay-counterexample report) => #f))
  (test-case "ratio corpus stores existing integer pairs and refuses zero before properties"
    (def draws 0) (def properties 0)
    (def report (p.check-property (g.generator-map (g.generator-rational)
      (lambda (value) (set! draws (1+ draws)) value)) integer? domain
      seed: 42 cases: 40 size: 8 shrink-budget: 128))
    (def codec (r.make-codec '(exact-ratio 1)
      (lambda (value) (cons (numerator value) (denominator value)))
      (lambda (parts) (/ (car parts) (cdr parts)))))
    (def output (open-output-string))
    (let (before draws)
      (r.write-counterexample report codec output)
      (check (r.read-counterexample codec (open-input-string (get-output-string output)) domain integer?) => #f)
      (check-equal? draws before))
    (def invalid (open-output-string))
    (write #(property-counterexample 1 (exact-ratio 1) (1 . 0)) invalid)
    (check-exception (r.read-counterexample codec (open-input-string (get-output-string invalid)) domain
      (lambda (_) (set! properties (1+ properties)) #f))
      (lambda (cause) (and (RuntimeException? cause)
        (using (cause : RuntimeException) (divide-by-zero-exception? cause.exception)))))
    (check-equal? properties 0))
  (test-case "ratio composition keeps old sources retired after fresh preparation"
    (def epoch 0)
    (def old (g.generator-map (g.generator-rational) identity current?: (lambda () (= epoch 0))))
    (def report (p.check-property old integer? domain seed: 42 cases: 40 size: 8 shrink-budget: 128))
    (set! epoch 1)
    (check-exception (p.replay-property report) Error?)
    (check-exception (p.replay-counterexample report) Error?)
    (def fresh (g.generator-map (g.generator-rational) identity current?: (lambda () (= epoch 1))))
    (check-eq? (p.report-status (p.check-property fresh rational? domain cases: 4)) 'passed)
    (check (p.report-current? report) => #f)))
