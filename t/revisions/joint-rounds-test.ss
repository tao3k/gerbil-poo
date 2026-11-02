;;; Related fixture-free suites share one standard runtime section.
;;; Static record definitions retain their original module-level type bindings.
(export joint-rounds-test joint-topology-test)
(import
  :std/test
  :std/sync/channel
  (only-in :std/list/list foldl)
  :clan/poo/object
  :clan/poo/mop
  :clan/poo/brace
  :clan/poo/feedback-graph
  (prefix-in :clan/poo/joint-publication joint.)
  (prefix-in :clan/poo/construction-cache cache.)
  (prefix-in :clan/poo/examples/component-rounds rounds.)
  (prefix-in :clan/poo/examples/joint-services joint-rounds.service.)
  :clan/poo/support/option
  (prefix-in :clan/poo/dependency-analysis code.)
  (prefix-in :clan/poo/strong-components scc.)
  (prefix-in :clan/poo/examples/joint-topology joint-topology.service.))

;; Construct once with the original private helper scope and declaration order.
(defvalues (joint-rounds-test)
  (let () (include "joint-rounds/cases.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (joint-topology-test)
  (let () (include "joint-rounds/joint-topology.scm")))
