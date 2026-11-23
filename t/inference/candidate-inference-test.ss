;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export candidate-inference-test container-inference-test)
(import
  :std/test
  :std/error
  :clan/poo/object
  :clan/poo/mop
  :clan/poo/types/prototype-types
  :clan/poo/types/relation
  (only-in :clan/poo/types/syntax map-type-children)
  :clan/poo/object/declaration
  (only-in :clan/poo/object/slot-observation call-with-slot-read-observer slot-read-key slot-read-receiver)
  (prefix-in :clan/poo/mop/methods/dispatch dispatch.)
  (prefix-in :clan/poo/mop/declarative-metadata metadata.)
  (prefix-in :clan/poo/mop/methods/extension extension.)
  (prefix-in :clan/poo/mop/methods/combination combination.)
  :clan/poo/mop/methods/declaration
  (prefix-in :clan/poo/examples/polymorphic-services service.)
  (prefix-in :clan/poo/examples/signature-service selected.)
  (only-in :clan/poo/type Map Any Bool Object Function CaseFunction Type. element? validate TypeError?))

;; Construct once with the original private helper scope and declaration order.
(defvalues (candidate-inference-test)
  (let () (include "candidate-inference/cases.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (container-inference-test)
  (let () (include "candidate-inference/container-inference.ss")))
