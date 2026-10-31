;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export descriptor-inference-test empty-inference-test optional-inference-test record-inference-test)
(import
  :std/test
  :std/error
  :clan/poo/object
  :clan/poo/mop
  :clan/poo/type
  :clan/poo/types/relation
  :clan/poo/prototype-types
  (only-in :clan/poo/optional-validation type-value-catalog)
  (only-in :clan/poo/object-contract ObjectContract. refine)
  (only-in :clan/poo/slot-observation call-with-slot-read-observer slot-read-receiver slot-read-key)
  :clan/poo/method-declaration
  (prefix-in :clan/poo/examples/signature-service signature.)
  (prefix-in :clan/poo/examples/polymorphic-services service.)
  :clan/poo/number)

;; Construct once with the original private helper scope and declaration order.
(defvalues (descriptor-inference-test)
  (let () (include "descriptor-inference/cases.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (empty-inference-test)
  (let () (include "descriptor-inference/empty-inference.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (optional-inference-test)
  (let () (include "descriptor-inference/optional-inference.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (record-inference-test)
  (let () (include "descriptor-inference/record-inference.scm")))
