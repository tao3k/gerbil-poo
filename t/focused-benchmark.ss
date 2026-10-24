(export main workload)
(import :std/iter
        ../object
        (runtime: :clan/poo/examples/generalized-checkout)
        (prefix-in (only-in ../examples/generalized-checkout envelope-base
                   envelope-report nested-base prepare-envelope prepare-nested
                   prepare-nested-unfused) checkout.)
        (runtime: :clan/poo/generalized-prototype)
        (prefix-in (only-in ../generalized-prototype Observation. approximate bind-observer
                   observe prepared-protocol step) gp.)
        (prefix-in "focused-cases.ss" study.)
        (only-in "closure-measure.ss" run-child))
;; Lift the real public result oracle through native FUN map, then bind its seed.
(def (checked-action action seed fields expected)
  (def checked ((.@ gp.Observation. .map)
    (lambda (view) (equal? (map view fields) expected)) action))
  (lambda () (checked seed)))
;; Inspect the same raw observations in both controls. This includes the output's
;; actual slot/cache access, not just a synthetic count or discarded construction.
(def (raw-shape raw)
  (def local (.@ raw checkout))
  (list (length (car local)) (length (cadr local)) (caddr local) (.@ raw service)))
;; Both sides share immutable inputs and identical setup. Only the declared phase
;; differs. Duplicate sides are the exact SAME procedure, strengthening A/A control.
(def (workload scenario)
  (def fused (checkout.prepare-nested))
  (def unfused (checkout.prepare-nested-unfused))
  (def base checkout.nested-base)
  (def fused-read (gp.bind-observer fused base 2))
  (def unfused-read (gp.bind-observer unfused base 2))
  (def fields '(price rebate service))
  (def expected '(39 3 billing))
  ;; A declared heap-history perturbation runs before all warmups/timing, equally
  ;; for every child/side. It performs 64 real unfused observations, not forced GC.
  (when (eq? scenario 'nested-history)
    (let (perturb (checked-action unfused-read base fields expected))
      (for (_ (in-range 64)) (unless (perturb) (error "history prefix oracle")))))
  (def actions
    (case scenario
      ((nested nested-history nested-allocation)
       (list (checked-action fused-read base fields expected) (checked-action unfused-read base fields expected)))
      ((cold)
       (map (lambda (factory)
         (checked-action (lambda (seed) (gp.observe (factory) base seed 2)) base fields expected))
         (list checkout.prepare-nested checkout.prepare-nested-unfused)))
      ((construction construction-allocation hook)
       (map (lambda (snapshot)
         (lambda () (equal? (raw-shape (if (eq? scenario 'hook) (gp.step snapshot base base)
           (gp.approximate snapshot base base 2))) '(3 1 audit billing)))) (list fused unfused)))
      ((cooking)
       (let* ((raw (gp.approximate unfused base base 2))
              (cook (.@ (gp.prepared-protocol unfused) cook))
              (action (checked-action (lambda (_) (cook raw)) base fields expected)))
         (list action action)))
      ((binding)
       (list (checked-action fused-read base fields expected)
         (checked-action (lambda (seed) (gp.observe fused base seed 2)) base fields expected)))
      ((envelope envelope-allocation revision)
       (let (raw (if (eq? scenario 'revision) (.cc checkout.envelope-base tenant: 'us) checkout.envelope-base))
         (map (lambda (fused?)
           (if (eq? scenario 'revision)
             (lambda () (equal? (checkout.envelope-report raw fused?) '(45 3 billing us #t)))
             (checked-action (gp.bind-observer (checkout.prepare-envelope fused?) raw 2) raw
               '(price rebate service tenant approved) '(45 3 billing eu #t)))) '(#t #f))))
      (else (error "unknown focused scenario" scenario))))
  (list (car actions) (cadr actions) (car actions) (cadr actions)))
;; Reuse native timing, signed GC-free bytes, fixed heap/process caps and prefix stats.
(def (main scenario-text regime-text side-text)
  (def scenario (string->symbol scenario-text)) (def regime (string->symbol regime-text))
  (def side (string->number side-text))
  (unless (and (memq scenario study.scenarios) (memq regime '(natural collected)) (memv side '(0 1 2 3)))
    (error "invalid focused study request"))
  (run-child scenario regime side (workload scenario) (study.repetitions scenario) 4))
