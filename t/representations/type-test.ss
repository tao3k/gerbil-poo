;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export tuple-json-performance-test tuple-unmarshal-performance-test type-performance-test type-test)
(import
  :std/iter
  :std/test
  (only-in :std/error Error? Error-message)
  (only-in :gerbil/expander current-expander-context make-top-context
           core-import-module module-context-export module-export-name eval-syntax)
  (only-in :gerbil/runtime/gambit unbound-global-exception?)
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
  (let () (include "type/tuple-json-performance.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (tuple-unmarshal-performance-test)
  (let () (include "type/tuple-unmarshal-performance.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (type-performance-test)
  (let () (include "type/type-performance.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (type-test)
  (let () (include "type/cases.ss")))
