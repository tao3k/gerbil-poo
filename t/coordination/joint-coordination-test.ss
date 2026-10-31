;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export coordinator-recovery-test coordinator-rejoining-test joint-concurrency-test joint-coordination-test)
(import
  :std/test
  :std/sync/channel
  :std/sync/threads
  :clan/poo/object
  :clan/poo/mop
  :clan/poo/brace
  (prefix-in :clan/poo/joint-publication joint.)
  (prefix-in :clan/poo/construction-cache cache.)
  (prefix-in :clan/poo/examples/joint-topology service.)
  (prefix-in :clan/poo/examples/joint-receipts receipts.)
  (prefix-in :clan/poo/examples/joint-coordination coordination.)
  :clan/poo/examples/joint-coordination-rounds
  :clan/poo/t/joint-coordination-cases
  (prefix-in :clan/poo/examples/joint-workers workers.)
  (only-in :std/list/list foldl filter)
  :clan/poo/feedback-graph
  (prefix-in :clan/poo/examples/joint-concurrency concurrent.))

;; Construct once with the original private helper scope and declaration order.
(defvalues (coordinator-recovery-test)
  (let () (include "joint-coordination/coordinator-recovery.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (coordinator-rejoining-test)
  (let () (include "joint-coordination/coordinator-rejoining.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (joint-concurrency-test)
  (let () (include "joint-coordination/joint-concurrency.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (joint-coordination-test)
  (let () (include "joint-coordination/cases.scm")))
