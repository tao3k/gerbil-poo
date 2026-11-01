;;; Separate C compilation preserves the original private fixture scope.
(export descriptor-inference-test)
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

;; Construct the same exported suite once; cases and callback scopes are unchanged.
(defvalues (descriptor-inference-test)
  (let () (include "cases.scm")))
