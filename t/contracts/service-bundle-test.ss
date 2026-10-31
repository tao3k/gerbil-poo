;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export service-bundle-test service-metadata-test service-revisions-test shared-approvals-test)
(import
  :std/test
  :std/iter
  (only-in :std/values first-value)
  :clan/poo/object
  (prefix-in :clan/poo/examples/service-bundle bundle.)
  (prefix-in :clan/poo/examples/cyclic-access access.)
  (prefix-in :clan/poo/examples/protected-dispatch protected.)
  (prefix-in :clan/poo/generic-family family.)
  (prefix-in :clan/poo/staged-publication staged.)
  (prefix-in :clan/poo/cyclic-publication service-bundle.publication.)
  (prefix-in :clan/poo/declarative-metadata metadata.)
  (prefix-in :clan/poo/dispatch-extension dispatch.)
  (prefix-in :clan/poo/multimethod multimethod.)
  (prefix-in :clan/poo/examples/service-metadata service-metadata.service.)
  (prefix-in :clan/poo/cyclic-publication service-metadata.publication.)
  :clan/poo/mop
  :clan/poo/brace
  :clan/poo/support/option
  :clan/poo/feedback-graph
  :clan/poo/feedback-cache
  :clan/poo/lens-laws
  (prefix-in :clan/poo/generalized-graph graph.)
  (prefix-in :clan/poo/strong-components scc.)
  (prefix-in :clan/poo/dependency-analysis code.)
  (prefix-in :clan/poo/construction-cache cache.)
  (prefix-in :clan/poo/examples/service-revisions service-revisions.service.)
  (prefix-in (only-in :clan/poo/fun Observation.) fun.)
  :std/sync/channel
  (prefix-in :clan/poo/component-publication shared-approvals.publication.)
  (prefix-in :clan/poo/examples/component-requests single.)
  (prefix-in :clan/poo/examples/shared-approvals shared-approvals.service.))

;; Construct once with the original private helper scope and declaration order.
(defvalues (service-bundle-test)
  (let () (include "service-bundle/cases.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (service-metadata-test)
  (let () (include "service-bundle/service-metadata.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (service-revisions-test)
  (let () (include "service-bundle/service-revisions.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (shared-approvals-test)
  (let () (include "service-bundle/shared-approvals.scm")))
