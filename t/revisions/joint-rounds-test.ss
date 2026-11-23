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
  :clan/poo/graph/feedback
  (prefix-in :clan/poo/graph/component/joint joint.)
  (prefix-in :clan/poo/graph/construction cache.)
  (prefix-in :clan/poo/examples/component-rounds rounds.)
  (prefix-in :clan/poo/examples/joint-services joint-rounds.service.)
  :clan/poo/support/option
  (prefix-in :clan/poo/graph/computation code.)
  (prefix-in :clan/poo/graph/scc scc.)
  (prefix-in :clan/poo/examples/joint-topology joint-topology.service.))

;; Construct once with the original private helper scope and declaration order.
(defvalues (joint-rounds-test)
  (let () (include "joint-rounds/cases.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (joint-topology-test)
  (let () (include "joint-rounds/joint-topology.ss")))
