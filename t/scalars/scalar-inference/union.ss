;;; Separate C compilation preserves the original private fixture scope.
(export union-inference-test)
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

;; Construct the same exported suite once; cases and callback scopes are unchanged.
(defvalues (union-inference-test)
  (let () (include "union-inference.scm")))
