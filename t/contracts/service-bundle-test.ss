;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export service-bundle-test service-metadata-test service-revisions-test shared-approvals-test)
(import
  :std/test
  :std/iter
  (only-in :std/values first-value)
  :clan/poo/object
  (prefix-in :clan/poo/benchmarks/workloads/service-bundle bundle.)
  (prefix-in :clan/poo/benchmarks/workloads/cyclic-access access.)
  (prefix-in :clan/poo/benchmarks/workloads/protected-dispatch protected.)
  (prefix-in :clan/poo/mop/generic-family family.)
  (prefix-in :clan/poo/graph/staged-publication staged.)
  (prefix-in :clan/poo/graph/cyclic-publication service-bundle.publication.)
  (prefix-in :clan/poo/mop/declarative-metadata metadata.)
  (prefix-in :clan/poo/mop/methods/extension dispatch.)
  (prefix-in :clan/poo/mop/methods/dispatch multimethod.)
  (prefix-in :clan/poo/benchmarks/workloads/service-metadata service-metadata.service.)
  (prefix-in :clan/poo/graph/cyclic-publication service-metadata.publication.)
  :clan/poo/mop
  :clan/poo/brace
  :clan/poo/support/option
  :clan/poo/graph/feedback
  :clan/poo/graph/feedback/cache
  :clan/poo/mop/lens-laws
  (prefix-in :clan/poo/graph/schedule graph.)
  (prefix-in :clan/poo/graph/scc scc.)
  (prefix-in :clan/poo/graph/computation code.)
  (prefix-in :clan/poo/graph/construction cache.)
  (prefix-in :clan/poo/benchmarks/workloads/service-revisions service-revisions.service.)
  (prefix-in (only-in :clan/poo/fun Observation.) fun.)
  :std/sync/channel
  (prefix-in :clan/poo/graph/component/publication shared-approvals.publication.)
  (prefix-in :clan/poo/benchmarks/workloads/component-requests single.)
  (prefix-in :clan/poo/benchmarks/workloads/shared-approvals shared-approvals.service.))

;; Construct once with the original private helper scope and declaration order.
(defvalues (service-bundle-test)
  (let () (include "service-bundle/cases.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (service-metadata-test)
  (let () (include "service-bundle/service-metadata.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (service-revisions-test)
  (let () (include "service-bundle/service-revisions.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (shared-approvals-test)
  (let () (include "service-bundle/shared-approvals.ss")))
