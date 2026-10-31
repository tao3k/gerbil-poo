;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export recursive-staging-test recursive-submissions-test recursive-topology-test recursive-validation-test)
(import
  :std/test
  :clan/poo/object
  :clan/poo/mop
  :clan/poo/number
  (only-in :clan/poo/type Record List)
  (prefix-in :clan/poo/recursive-validation graph.)
  (prefix-in :clan/poo/recursive-staging staging.)
  (prefix-in :clan/poo/recursive-topology recursive-staging.topology.)
  (prefix-in :clan/poo/examples/recursive-topology recursive-staging.service.)
  (prefix-in :clan/poo/examples/recursive-staging recursive-staging.workflow.)
  (prefix-in :clan/poo/examples/recursive-migration migration.)
  (prefix-in :clan/poo/declarative-metadata metadata.)
  (prefix-in :clan/poo/examples/contract-publication recursive-staging.publication.)
  :std/error
  (prefix-in :clan/poo/recursive-approvals approvals.)
  (prefix-in :clan/poo/recursive-publication recursive-submissions.publication.)
  (prefix-in :clan/poo/examples/recursive-topology recursive-submissions.topology.)
  (prefix-in :clan/poo/examples/recursive-approvals recursive-submissions.service.)
  (prefix-in :clan/poo/examples/recursive-competition competition.)
  (prefix-in :clan/poo/examples/recursive-submissions recursive-submissions.workflow.)
  (only-in :std/list/list filter)
  (prefix-in :clan/poo/recursive-topology recursive-topology.topology.)
  (prefix-in :clan/poo/strong-components scc.)
  (prefix-in :clan/poo/examples/recursive-topology recursive-topology.service.)
  (prefix-in :clan/poo/examples/contract-publication recursive-topology.publication.)
  :clan/poo/object-contract
  (prefix-in :clan/poo/examples/recursive-validation recursive-validation.service.)
  (prefix-in :clan/poo/examples/object-contracts config.)
  (prefix-in :clan/poo/examples/contract-publication recursive-validation.publication.)
  (prefix-in :clan/poo/recursive-handling handling.)
  (prefix-in :clan/poo/recursive-cache cached.))

;; Construct once with the original private helper scope and declaration order.
(defvalues (recursive-staging-test)
  (let () (include "recursive-validation/recursive-staging.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (recursive-submissions-test)
  (let () (include "recursive-validation/recursive-submissions.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (recursive-topology-test)
  (let () (include "recursive-validation/recursive-topology.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (recursive-validation-test)
  (let () (include "recursive-validation/cases.scm")))
