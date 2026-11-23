;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export recursive-approvals-test recursive-competition-test recursive-coordination-test recursive-migration-test recursive-publication-test recursive-recovery-test recursive-restaging-test recursive-revision-test)
(import
  :std/test
  :std/error
  :clan/poo/object
  :clan/poo/mop
  :clan/poo/number
  (only-in :clan/poo/type Record validate TypeError?)
  (prefix-in :clan/poo/recursive/validation graph.)
  (prefix-in :clan/poo/recursive/staging staging.)
  (prefix-in :clan/poo/recursive/publication recursive-approvals.publication.)
  (prefix-in :clan/poo/recursive/approvals approvals.)
  (prefix-in :clan/poo/t/fixtures/recursive-approvals recursive-approvals.service.)
  (prefix-in :clan/poo/t/fixtures/recursive-topology recursive-approvals.topology.)
  (prefix-in :clan/poo/mop/declarative-metadata metadata.)
  (only-in :std/list/list take drop)
  (prefix-in :clan/poo/recursive/publication recursive-competition.publication.)
  (prefix-in :clan/poo/t/fixtures/recursive-approvals recursive-competition.service.)
  (prefix-in :clan/poo/t/fixtures/recursive-competition recursive-competition.workflow.)
  (prefix-in :clan/poo/t/fixtures/recursive-topology recursive-competition.topology.)
  (prefix-in :clan/poo/recursive/coordination coordination.)
  (prefix-in :clan/poo/recursive/publication recursive-coordination.publication.)
  (prefix-in :clan/poo/t/fixtures/recursive-topology recursive-coordination.topology.)
  (prefix-in :clan/poo/t/fixtures/recursive-approvals recursive-coordination.service.)
  (prefix-in :clan/poo/t/fixtures/recursive-competition competition.)
  (prefix-in :clan/poo/t/fixtures/recursive-coordination recursive-coordination.workflow.)
  (prefix-in :clan/poo/t/fixtures/recursive-migration recursive-migration.service.)
  (prefix-in :clan/poo/benchmarks/workloads/contract-publication recursive-migration.publication.)
  (prefix-in :clan/poo/recursive/publication recursive-publication.publication.)
  (prefix-in :clan/poo/t/fixtures/recursive-restaging restaging.)
  (prefix-in :clan/poo/t/fixtures/recursive-publication entry.)
  (prefix-in :clan/poo/t/fixtures/recursive-topology recursive-publication.service.)
  (prefix-in :clan/poo/benchmarks/workloads/contract-publication contract.)
  (prefix-in :clan/poo/recursive/publication recursive-recovery.publication.)
  (prefix-in :clan/poo/t/fixtures/recursive-topology recursive-recovery.topology.)
  (prefix-in :clan/poo/t/fixtures/recursive-approvals recursive-recovery.service.)
  (prefix-in :clan/poo/t/fixtures/recursive-recovery recursive-recovery.workflow.)
  (prefix-in :clan/poo/recursive/topology recursive-restaging.topology.)
  (prefix-in :clan/poo/t/fixtures/recursive-topology recursive-restaging.service.)
  (prefix-in :clan/poo/t/fixtures/recursive-staging recursive-restaging.workflow.)
  :clan/poo/types/object-contract
  (prefix-in :clan/poo/t/fixtures/recursive-revision recursive-revision.service.)
  (prefix-in :clan/poo/benchmarks/workloads/contract-publication recursive-revision.publication.))

;; Construct once with the original private helper scope and declaration order.
(defvalues (recursive-approvals-test)
  (let () (include "recursive-approvals/cases.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (recursive-competition-test)
  (let () (include "recursive-approvals/recursive-competition.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (recursive-coordination-test)
  (let () (include "recursive-approvals/recursive-coordination.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (recursive-migration-test)
  (let () (include "recursive-approvals/recursive-migration.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (recursive-publication-test)
  (let () (include "recursive-approvals/recursive-publication.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (recursive-recovery-test)
  (let () (include "recursive-approvals/recursive-recovery.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (recursive-restaging-test)
  (let () (include "recursive-approvals/recursive-restaging.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (recursive-revision-test)
  (let () (include "recursive-approvals/recursive-revision.ss")))
