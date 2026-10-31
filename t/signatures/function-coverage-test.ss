;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export function-coverage-test function-options-test keyword-coverage-test keyword-prefix-test keyword-rest-test keyword-values-test)
(import
  :std/test
  :std/error
  :clan/poo/object
  :clan/poo/mop
  :clan/poo/types/relation
  :clan/poo/prototype-types
  :clan/poo/method-declaration
  (prefix-in :clan/poo/examples/polymorphic-services service.)
  (prefix-in :clan/poo/examples/signature-service fixture.)
  (prefix-in :clan/poo/function-signature signature.)
  :std/iter
  :std/list/list-builder
  (only-in :std/list/list delete-duplicates/hash))

;; Construct once with the original private helper scope and declaration order.
(defvalues (function-coverage-test)
  (let () (include "function-coverage/cases.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (function-options-test)
  (let () (include "function-coverage/function-options.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (keyword-coverage-test)
  (let () (include "function-coverage/keyword-coverage.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (keyword-prefix-test)
  (let () (include "function-coverage/keyword-prefix.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (keyword-rest-test)
  (let () (include "function-coverage/keyword-rest.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (keyword-values-test)
  (let () (include "function-coverage/keyword-values.scm")))
