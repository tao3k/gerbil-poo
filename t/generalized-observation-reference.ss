;;; Test-only control for the pre-optimization b14c15d finite-observation algorithm.
(export prepare observe step eager-cook eager-service profile)
(import ../object
        (runtime: :clan/poo/generalized-prototype)
        (prefix-in (only-in ../generalized-prototype assemble bind-observer cook-fields
                   prepare-inheritance) gp.)
        (runtime: :clan/poo/method-combination)
        (prefix-in (only-in ../method-combination prepare-simple sum) combination.)
        (runtime: :clan/poo/examples/generalized-checkout)
        (prefix-in (only-in ../examples/generalized-checkout base declarations
                   nested-base nested-declarations nested-protocol nested-root
                   protocol root) checkout.))
;; Keep the original three-field prepared representation private to the control.
(defstruct snapshot (protocol fragments program) final: #t)
;; Match the preceding eager preparation of both method groups before slot selection.
(def (eager-cook raw)
  (def price (combination.prepare-simple combination.sum (car raw)))
  (def rebate (combination.prepare-simple combination.sum (cadr raw)))
  (lambda (slot) (case slot ((price) (price [])) ((rebate) (rebate []))
    (else (error "unknown checkout observation" slot)))))
;; The nested control uses exactly the same service carrier and slot interface.
(def (eager-service raw)
  (def checkout (eager-cook (.@ raw checkout)))
  (lambda (slot) (case slot ((price rebate) (checkout slot))
    ((service) (.@ raw service)) (else (error "unknown service view" slot)))))
;; Native C3/declaration/compilation work is included once per reference preparation.
(def (prepare protocol root declarations)
  (def fragments (apply append (map declarations (compute-precedence-list! root))))
  (make-snapshot protocol fragments (gp.assemble protocol fragments)))
;; Preserve b14c15d's per-demand cooked-self closure and per-step descriptor access.
;; Current compiler bodies are identical for the flat case, not an invented loop.
(def (step prepared final base)
  ((snapshot-program prepared)
    (lambda () ((.@ (snapshot-protocol prepared) cook) final)) (lambda () base)))
;; Preserve its finite loop, validation and final cooking, without caching observations.
(def (observe prepared base seed depth)
  (unless (and (exact-integer? depth) (>= depth 0)) (error "invalid observation depth"))
  (def raw (let loop ((remaining depth) (raw seed))
    (if (zero? remaining) raw (loop (- remaining 1) (step prepared raw base)))))
  ((.@ (snapshot-protocol prepared) cook) raw))

;; Count semantic operations outside timed children. Instrumentation intentionally
;; has effects and is not a purity proof or a predictor of allocator/GC behavior.
(def (profile optimized? nested?)
  (def counts (make-hash-table-eq))
  ;; Decorate one callback without changing its arguments or returned native value.
  (def (counted key callback)
    (lambda args (hash-put! counts key (+ 1 (hash-ref counts key 0))) (apply callback args)))
  (def original (if nested? checkout.nested-protocol checkout.protocol))
  (def source (if nested? checkout.nested-root checkout.root))
  (def declarations (if nested? checkout.nested-declarations checkout.declarations))
  (def base (if nested? checkout.nested-base checkout.base))
  ;; Count effective-method preparation separately from cooking the public interface.
  (def (field key getter)
    (counted key (lambda (raw)
      (def effective (combination.prepare-simple combination.sum (getter raw)))
      (lambda () (effective [])))))
  (def fields (list (cons 'price (field 'price car)) (cons 'rebate (field 'rebate cadr))))
  (def build-fields (if optimized? (gp.cook-fields fields)
    (lambda (raw)
      (def ready (map (lambda (field) (cons (car field) ((cdr field) raw))) fields))
      (lambda (slot) (cdr (assq slot ready))))))
  (def cook (counted 'cook (lambda (raw)
    (def cooked (build-fields (if nested? (.@ raw checkout) raw)))
    (lambda (slot) (if (eq? slot 'service) (.@ raw service) ((cooked slot)))))))
  (def protocol (.cc original cook: cook compile: (counted 'compile
    (lambda (fragment) (counted 'hook ((.@ original compile) fragment))))))
  (def prepared (if optimized? (gp.prepare-inheritance protocol source declarations)
    (prepare protocol source declarations)))
  (def view (if optimized? ((gp.bind-observer prepared base 2) base) (observe prepared base base 2)))
  (def result (view 'price))
  (list result (map (lambda (key) (cons key (hash-ref counts key 0))) '(compile hook cook price rebate))))
