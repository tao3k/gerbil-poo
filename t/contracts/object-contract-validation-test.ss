;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export object-contract-validation-test optional-validation-test protected-dispatch-test)
(import
  :std/test
  :clan/poo/object
  :clan/poo/mop
  :clan/poo/number
  :clan/poo/object-contract
  (prefix-in :clan/poo/examples/function-publication workflow.)
  (prefix-in :clan/poo/examples/object-contracts service.)
  (prefix-in :clan/poo/examples/contract-publication publication.)
  (prefix-in :clan/poo/declarative-metadata metadata.)
  (only-in :clan/poo/type Maybe Maybe. OrFalse OrFalse. TypeValuePair List Tuple String)
  (prefix-in :clan/poo/examples/optional-publication pipeline.)
  :std/iter
  (only-in :std/values first-value)
  (prefix-in :clan/poo/closure closure.)
  (prefix-in :clan/poo/multimethod multimethod.)
  (prefix-in :clan/poo/dispatch-extension dispatch-extension.)
  (prefix-in :clan/poo/cyclic-publication cyclic-publication.)
  (prefix-in :clan/poo/examples/protected-dispatch protected-dispatch.))

;; Construct once with the original private helper scope and declaration order.
(defvalues (object-contract-validation-test)
  (let () (include "object-contract-validation/cases.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (optional-validation-test)
  (let () (include "object-contract-validation/optional-validation.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (protected-dispatch-test)
  (let () (include "object-contract-validation/protected-dispatch.scm")))
