;;; Same-binary parent-algorithm controls, not a runtime compatibility layer.
(export main workload)
(import :std/iter ../object (prefix-in ../generalized-prototype gp.)
  (prefix-in ../examples/generalized-checkout checkout.)
  (prefix-in "binding-cases.ss" study.) (only-in "metadata-paired-benchmark.ss" run-child))
;; Parent Reader map used bind/pure: allocate a reader around each projected value.
;; Keep the actual algorithm available to AOT; do not force artificial allocation.
(def (reference-map transform action)
  ((.@ gp.Observation. .bind) action
    (lambda (value) ((.@ gp.Observation. .ap) (transform value)))))
;; Observe the real public interface, including lazy price dependencies and policy.
(def (fields view)
  (list (view 'price) (view 'rebate) (view 'service) (view 'tenant) (view 'approved)))
;; The parent algorithm creates a fresh fixed-base reader on each context call.
(def (reference-context snapshot raw) ((gp.bind-observer snapshot raw 2) raw))
;; Fully execute each action; all four sides share setup and public-value oracles.
(def (workload scenario)
  (def snapshot (checkout.prepare-envelope))
  (def base checkout.envelope-base)
  (def revised (.cc base tenant: 'us))
  (def current (gp.bind-context-observer snapshot 2 identity identity))
  (def previous (lambda (raw) (reference-context snapshot raw)))
  (def project (lambda (view) (equal? (fields view) '(45 3 billing eu #t))))
  (when (eq? scenario 'nested-history)
    (for (_ (in-range 64))
      (unless (project (previous base)) (error "binding history oracle"))))
  (def actions
    (case scenario
      ((map map-allocation)
       (map (lambda (mapper)
         (def action (mapper (lambda (value) (= value 8)) (lambda (value) (+ value 1))))
         (lambda () (action 7))) (list (.@ gp.Observation. .map) reference-map)))
      ((binding binding-allocation)
       (let* ((empty (gp.prepare (.cc gp.Protocol. cook: identity compile: identity) []))
              (direct (lambda () (= (gp.observe empty 7 8 0) 8)))
              (bound (lambda () (= ((gp.bind-observer empty 7 0) 8) 8))))
         (list direct bound)))
      ((nested nested-history nested-allocation)
       (map (lambda (mapper)
         (def checked (mapper project (gp.bind-observer snapshot base 2)))
         (lambda () (checked base))) (list (.@ gp.Observation. .map) reference-map)))
      ((revision revision-allocation)
       (map (lambda (reader)
         (lambda () (and (equal? (fields (reader base)) '(45 3 billing eu #t))
           (equal? (fields (reader revised)) '(45 3 billing us #t))))) (list current previous)))
      ((factory factory-allocation)
       (list
         (lambda () (equal? ((checkout.bind-envelope-report) base) '(45 3 billing eu #t)))
         (lambda () (fields-reference (checkout.prepare-envelope) base))))
      ((preparation)
       ;; Identical complete descriptor/slot-cache preparation isolates its noise;
       ;; it is included in factory, excluded from reused revision and nested calls.
       (let (action (lambda () (gp.Prepared? (checkout.prepare-envelope))))
         (list action action)))
      (else (error "unknown binding scenario" scenario))))
  (list (car actions) (cadr actions) (car actions) (cadr actions)))
;; Parent complete factory includes the original Reader map and fresh fixed base.
(def (fields-reference snapshot base)
  (def report (reference-map fields (gp.bind-observer snapshot base 2)))
  (equal? (report base) '(45 3 billing eu #t)))
;; Validate requests before entering the shared native measurement protocol.
(def (main scenario-text regime-text side-text)
  (def scenario (string->symbol scenario-text)) (def regime (string->symbol regime-text))
  (def side (string->number side-text))
  (unless (and (memq scenario study.scenarios) (memq regime '(natural collected)) (memv side '(0 1 2 3)))
    (error "invalid binding study request"))
  (run-child scenario regime side (workload scenario) (study.repetitions scenario) 4))
