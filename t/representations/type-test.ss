;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export tuple-json-performance-test tuple-unmarshal-performance-test type-performance-test type-test)
(import
  :std/iter
  :std/test
  :clan/poo/object
  :clan/poo/number
  :clan/poo/type
  :std/format
  :std/assert
  :std/misc/ports
  :std/text/pregexp
  :clan/poo/support/base
  :clan/poo/support/testing
  :clan/poo/mop)

;; Construct once with the original private helper scope and declaration order.
(defvalues (tuple-json-performance-test)
  (let () (include "type/tuple-json-performance.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (tuple-unmarshal-performance-test)
  (let () (include "type/tuple-unmarshal-performance.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (type-performance-test)
  (let () (include "type/type-performance.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (type-test)
  (let () (include "type/cases.scm")))
