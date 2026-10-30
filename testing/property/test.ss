;;; Standard TestSuite checks over the existing property-report protocol.
(export check-property define-property require-passed)
(import :std/error (only-in :std/test do-check!) (only-in :std/test/base TestError)
        (prefix-in ../property property.) (only-in ./generator with-sources with-generation-check)
        (prefix-in ./generator generator.))

;; Both formatter fields and preparation receipts are finite symbolic alists.
;; This uses standard list admission before traversal, including cyclic rejection.
(def (diagnostic-fields? fields)
  (and (list? fields) (every (lambda (field) (and (pair? field) (symbol? (car field)))) fields)))

;; Formatting is a checked action, never admission authority. A formerly passed
;; report protects nested work and normal return; non-passing historical reports
;; remain readable. Original report failures outrank secondary rendering errors.
(def (checked-diagnostics report formatter status)
  (let/cc obsolete
    ;; Refusal interrupts a renderer before any later checked nested operation.
    (def (check!)
      (unless (property.report-current? report) (obsolete 'stale #f #f)))
    ;; A formatter returns only ordinary symbolic fields, not an executable verdict.
    (def (render)
      (def fields (formatter report))
      (unless (diagnostic-fields? fields)
        (error "property formatter must return diagnostic fields" fields))
      (values status fields #f))
    (with-catch (lambda (cause)
        (if (eq? status 'passed) (raise cause)
          (values status #f (cons 'diagnostic-cause cause))))
      (lambda ()
        (with-sources []
          (if (eq? status 'passed)
            (begin
              (check!)
              (with-generation-check check! (begin0 (render) (check!))))
            (render)))))))

;; Only an actual, current kernel report can authorize success. #f represents
;; typed preparation refusal: its diagnostics explain failure but cannot pass.
;; Status/cause come from the report; currentness is rechecked after rendering.
;; Duplicate formatter fields cannot hide the original outcome or exception.
(def (require-passed report diagnostics: (formatter property.report-diagnostics) refusal: (refusal #f))
  (unless (and (or (not report) (property.report? report)) (procedure? formatter)
    (or (not refusal) (and (not report) (diagnostic-fields? refusal))))
    (error "property report and diagnostic formatter required"))
  (def fallback (and (not report) (or refusal
    (list (cons 'status 'error) (cons 'cause (Error "property report has no execution"))))))
  (def declared (and fallback (assq 'status fallback)))
  (def refused? (and declared (memq (cdr declared) '(failed error stale exhausted unsupported coverage))))
  (def original (if report (property.report-status report) (if refused? (cdr declared) 'error)))
  (def original-cause (if report (property.report-cause report)
    (let (cause (and refused? (assq 'cause fallback)))
      (if cause (cdr cause) (Error "property report has no execution")))))
  (let-values (((status output fault) (checked-diagnostics report formatter original)))
    (def fields (or output fallback (and report (property.report-diagnostics report)) []))
    (unless (and report (eq? status 'passed))
      (raise (TestError "property check did not pass" irritants:
        (append (list (cons 'status status) (cons 'cause original-cause))
          (filter (lambda (field) (not (memq (car field) '(status cause diagnostic-cause)))) fields)
          (if fault (list fault) [])))))))

;; do-check! owns caller location, registration, TestResult and nonlocal failure.
;; Report and formatter expressions are each evaluated once inside that check.
(defrules check-property ()
  ((_ expression) (check-property expression diagnostics: property.report-diagnostics))
  ((_ expression diagnostics: formatter)
   (do-check! expression expression
     (require-passed expression diagnostics: (lambda (report) (formatter report))))))

;; Named properties compose dependent generators through their existing bind tree.
;; Specifications are prepared once per check; formatting names cannot change truth.
(defrule (define-property name ((argument generator specification) ...) body ...)
  (def (name . options)
    (do-check! name name
      (let (domain (property.make-product-specification (list specification ...)))
        (require-passed
          (apply property.check-property
            (generator.bind-generators ((argument generator) ...) (list argument ...))
            (lambda (arguments) (apply (lambda (argument ...) body ...) arguments))
            domain name: 'name options)
          diagnostics: (lambda (report)
            (property.report-diagnostics report bindings: '(argument ...))))))))
