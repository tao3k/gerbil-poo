;;; Standard TestSuite checks over the existing property-report protocol.
(export check-property define-property)
(import (only-in :std/test do-check!) (only-in :std/test/base TestError)
        (prefix-in ./property property.) (prefix-in ./generator generator.))
;; Every non-passing outcome is a standard TestError with its distinct status and
;; original cause. This is not a falsification or a second execution of the property.
(def (require-passed diagnostics)
  (unless (and (list? diagnostics) (every pair? diagnostics) (assq 'status diagnostics))
    (error "property diagnostics require a status" diagnostics))
  (unless (eq? (cdr (assq 'status diagnostics)) 'passed)
    (raise (TestError "property check did not pass" irritants: diagnostics))))
;; do-check! owns caller location, registration, TestResult and nonlocal failure.
;; Report and formatter expressions are each evaluated once inside that check.
(defrules check-property ()
  ((_ expression) (check-property expression diagnostics: property.report-diagnostics))
  ((_ expression diagnostics: formatter)
   (do-check! expression expression (require-passed (formatter expression)))))
;; Named properties compose dependent generators through their existing bind tree.
;; Specifications are prepared once per check; shrinking reuses captured domains.
(defrule (define-property name ((argument generator specification) ...) body ...)
  (def (name . options)
    ;; The original name syntax preserves the definition location in do-check!.
    (do-check! name name
      (let (domain (property.make-product-specification (list specification ...)))
        (require-passed
          (property.report-diagnostics
            (apply property.check-property
              (generator.bind-generators ((argument generator) ...) (list argument ...))
              (lambda (arguments) (apply (lambda (argument ...) body ...) arguments))
              domain name: 'name options)
            bindings: '(argument ...)))))))
