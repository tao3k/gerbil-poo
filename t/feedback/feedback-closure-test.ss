;;; Related fixture-free suites share one standard runtime section.
;;; Static record definitions retain their original module-level type bindings.
(export cyclic-access-test feedback-cache-test feedback-closure-test)
(import
  :std/test
  :std/iter
  :clan/poo/graph/closure
  :clan/poo/object
  :clan/poo/mop
  :clan/poo/brace
  :clan/poo/support/option
  :clan/poo/graph/feedback/cache
  :clan/poo/mop/generalized-declaration
  :clan/poo/lens-laws
  (prefix-in :clan/poo/graph/computation code.)
  (prefix-in :clan/poo/graph/construction cache.)
  (prefix-in :clan/poo/graph/schedule graph.)
  (prefix-in :clan/poo/examples/cached-feedback service.)
  (prefix-in (only-in :clan/poo/fun Observation.) fun.)
  :clan/poo/mop/generalized-closure
  :clan/poo/graph/feedback/closure
  (prefix-in :clan/poo/examples/feedback-services services.))

;; Construct once with the original private helper scope and declaration order.
(defvalues (cyclic-access-test)
  (let () (include "feedback-closure/cyclic-access.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (feedback-cache-test)
  (let () (include "feedback-closure/feedback-cache.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (feedback-closure-test)
  (let () (include "feedback-closure/cases.ss")))
