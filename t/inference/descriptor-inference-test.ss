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
  :clan/poo/types/prototype-types
  (only-in :clan/poo/types/optional-validation type-value-catalog)
  (only-in :clan/poo/types/object-contract ObjectContract. refine)
  (only-in :clan/poo/object/slot-observation call-with-slot-read-observer slot-read-receiver slot-read-key)
  :clan/poo/mop/methods/declaration
  (prefix-in :clan/poo/examples/signature-service signature.)
  (prefix-in :clan/poo/examples/polymorphic-services service.)
  :clan/poo/number)
(import (only-in "descriptor-inference/intrinsic.ss" descriptor-inference-test))



;; Construct once with the original private helper scope and declaration order.
(defvalues (empty-inference-test)
  (let () (include "descriptor-inference/empty-inference.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (optional-inference-test)
  (let () (include "descriptor-inference/optional-inference.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (record-inference-test)
  (let () (include "descriptor-inference/record-inference.ss")))
