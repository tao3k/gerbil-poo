;;; Related fixture-free suites share one standard runtime section.
;;; Static record definitions retain their original module-level type bindings.
(export number-test polynomial-test)
(import
  :std/assert
  :std/format
  :std/iter
  :std/test
  :clan/poo/support/base
  :clan/poo/support/debug
  :clan/poo/support/testing
  :clan/poo/object
  :clan/poo/mop
  :clan/poo/number
  :clan/poo/type
  :clan/poo/brace
  :std/debug/DBG
  :clan/poo/number/finite-field
  :clan/poo/number/polynomial)

;; Construct once with the original private helper scope and declaration order.
(defvalues (number-test)
  (let () (include "number/cases.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (polynomial-test)
  (let () (include "number/polynomial.ss")))
