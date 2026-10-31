;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export candidate-inference-test container-inference-test)
(import
  :std/test
  :std/error
  :clan/poo/object
  :clan/poo/mop
  :clan/poo/prototype-types
  :clan/poo/types/relation
  (only-in :clan/poo/types/syntax map-type-children)
  :clan/poo/declaration
  (only-in :clan/poo/slot-observation call-with-slot-read-observer slot-read-key slot-read-receiver)
  (prefix-in :clan/poo/multimethod dispatch.)
  (prefix-in :clan/poo/declarative-metadata metadata.)
  (prefix-in :clan/poo/dispatch-extension extension.)
  (prefix-in :clan/poo/method-combination combination.)
  :clan/poo/method-declaration
  (prefix-in :clan/poo/examples/polymorphic-services service.)
  (prefix-in :clan/poo/examples/signature-service selected.)
  (only-in :clan/poo/type Map))

;; Construct once with the original private helper scope and declaration order.
(defvalues (candidate-inference-test)
  (let () (include "candidate-inference/cases.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (container-inference-test)
  (let () (include "candidate-inference/container-inference.scm")))
