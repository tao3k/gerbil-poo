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
  :clan/poo/fq
  :clan/poo/polynomial)

;; Construct once with the original private helper scope and declaration order.
(defvalues (number-test)
  (let () (include "number/cases.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (polynomial-test)
  (let () (include "number/polynomial.scm")))
