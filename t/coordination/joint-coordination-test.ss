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
  (prefix-in :clan/poo/graph/component/joint joint.)
  (prefix-in :clan/poo/graph/construction cache.)
  (prefix-in :clan/poo/benchmarks/workloads/joint-topology service.)
  (prefix-in :clan/poo/benchmarks/workloads/joint-receipts receipts.)
  (prefix-in :clan/poo/benchmarks/workloads/joint-coordination coordination.)
  :clan/poo/benchmarks/workloads/joint-coordination-rounds
  :clan/poo/t/joint-coordination-cases
  (prefix-in :clan/poo/benchmarks/workloads/joint-workers workers.)
  (only-in :std/list/list foldl filter)
  :clan/poo/graph/feedback
  (prefix-in :clan/poo/benchmarks/workloads/joint-concurrency concurrent.))

;; Construct once with the original private helper scope and declaration order.
(defvalues (coordinator-recovery-test)
  (let () (include "joint-coordination/coordinator-recovery.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (coordinator-rejoining-test)
  (let () (include "joint-coordination/coordinator-rejoining.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (joint-concurrency-test)
  (let () (include "joint-coordination/joint-concurrency.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (joint-coordination-test)
  (let () (include "joint-coordination/cases.ss")))
