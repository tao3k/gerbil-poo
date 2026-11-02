;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export approval-revision-test joint-admission-test joint-installation-test joint-publication-test joint-receipts-test)
(import
  :std/test
  :std/sync/channel
  (only-in :std/list/list foldl)
  :clan/poo/object
  :clan/poo/mop
  :clan/poo/brace
  :clan/poo/support/option
  :clan/poo/feedback-graph
  (prefix-in :clan/poo/construction-cache cache.)
  (prefix-in :clan/poo/component-publication publication.)
  (prefix-in :clan/poo/dependency-analysis code.)
  (prefix-in :clan/poo/examples/component-requests approval-revision.service.)
  (prefix-in :clan/poo/joint-publication joint.)
  (prefix-in :clan/poo/examples/component-rounds rounds.)
  (prefix-in :clan/poo/examples/joint-topology joint-admission.service.)
  (prefix-in :clan/poo/examples/joint-topology joint-installation.service.)
  :clan/poo/lens-laws
  (prefix-in :clan/poo/examples/joint-services joint-publication.service.)
  (prefix-in :clan/poo/examples/joint-topology joint-receipts.service.)
  (prefix-in :clan/poo/examples/joint-receipts receipts.))

;; Construct once with the original private helper scope and declaration order.
(defvalues (approval-revision-test)
  (let () (include "joint-publication/approval-revision.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (joint-admission-test)
  (let () (include "joint-publication/joint-admission.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (joint-installation-test)
  (let () (include "joint-publication/joint-installation.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (joint-publication-test)
  (let () (include "joint-publication/cases.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (joint-receipts-test)
  (let () (include "joint-publication/joint-receipts.scm")))
