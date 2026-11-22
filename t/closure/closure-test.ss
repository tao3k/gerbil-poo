;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export closure-alignment-test closure-test component-closure-test)
(import
  (only-in :std/values first-value)
  :std/test
  :std/iter
  :clan/poo/graph/closure
  :clan/poo/object
  (prefix-in :clan/poo/cyclic-publication cyclic-publication.)
  (prefix-in :clan/poo/examples/cyclic-access access.)
  :clan/poo/mop
  :clan/poo/brace
  :clan/poo/support/option
  :clan/poo/graph/feedback/builder
  :clan/poo/graph/feedback
  (prefix-in :clan/poo/graph/schedule graph.)
  (prefix-in :clan/poo/graph/computation code.)
  (prefix-in :clan/poo/graph/construction cache.))

;; Construct once with the original private helper scope and declaration order.
(defvalues (closure-alignment-test)
  (let () (include "closure/closure-alignment.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (closure-test)
  (let () (include "closure/cases.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (component-closure-test)
  (let () (include "closure/component-closure.scm")))
