;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export range-inference-test scalar-inference-test union-inference-test)
(import
  :std/test
  :std/error
  :clan/poo/object
  :clan/poo/mop
  :clan/poo/types/relation
  :clan/poo/prototype-types
  :clan/poo/method-declaration
  (prefix-in :clan/poo/examples/polymorphic-services service.)
  (only-in :std/number/misc uint-below?)
  (only-in :gerbil/runtime/gambit string->uninterned-symbol)
  (prefix-in :clan/poo/examples/numeric-services numeric.)
  (only-in :clan/poo/function-signature encode-arguments)
  :clan/poo/type)

;; Construct once with the original private helper scope and declaration order.
(defvalues (range-inference-test)
  (let () (include "scalar-inference/range-inference.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (scalar-inference-test)
  (let () (include "scalar-inference/cases.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (union-inference-test)
  (let () (include "scalar-inference/union-inference.scm")))
