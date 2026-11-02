;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export construction-cache-test construction-workflow-test focused-closure-test)
(import
  :std/test
  :std/iter
  (only-in :std/list/list delete-duplicates/hash)
  :clan/poo/object
  :clan/poo/support/option
  (prefix-in :clan/poo/dependency-analysis code.)
  (prefix-in :clan/poo/generalized-graph graph.)
  (prefix-in :clan/poo/construction-cache cache.)
  (only-in :std/values first-value)
  (prefix-in :clan/poo/examples/construction-workflow workflow.)
  (prefix-in :clan/poo/examples/service-bundle bundle.)
  (prefix-in :clan/poo/examples/shared-contracts shared.)
  (prefix-in :clan/poo/contract-family contracts.)
  (prefix-in :clan/poo/staged-publication staged.)
  (prefix-in :clan/poo/examples/protected-dispatch protected.)
  (prefix-in :clan/poo/cyclic-publication publication.)
  (prefix-in :clan/poo/dispatch-extension dispatch.)
  (prefix-in :clan/poo/multimethod multimethod.)
  :clan/poo/mop
  :clan/poo/brace
  :clan/poo/lens-laws
  :clan/poo/focused-closure
  :clan/poo/generalized-closure
  :clan/poo/generalized-declaration
  (prefix-in :clan/poo/examples/closed-declarations service.)
  (prefix-in :clan/poo/examples/focused-services family.)
  (prefix-in (only-in :clan/poo/fun Observation.) fun.))

;; Construct once with the original private helper scope and declaration order.
(defvalues (construction-cache-test)
  (let () (include "construction-cache/cases.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (construction-workflow-test)
  (let () (include "construction-cache/construction-workflow.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (focused-closure-test)
  (let () (include "construction-cache/focused-closure.scm")))
