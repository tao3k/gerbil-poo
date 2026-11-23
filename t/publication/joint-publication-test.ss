;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export approval-revision-test joint-admission-test joint-installation-test joint-publication-test joint-receipts-test)
(import
  :std/test
  :std/sync/channel
  (only-in :gerbil/expander current-expander-context make-top-context eval-syntax)
  (only-in :gerbil/runtime/gambit unbound-global-exception?)
  (only-in :std/error Error? Error-message)
  (only-in :std/list/list foldl)
  :clan/poo/object
  :clan/poo/mop
  :clan/poo/brace
  :clan/poo/support/option
  :clan/poo/graph/feedback
  (prefix-in :clan/poo/graph/construction cache.)
  (prefix-in :clan/poo/graph/component/publication publication.)
  (prefix-in :clan/poo/graph/component/revision revision.)
  (prefix-in :clan/poo/graph/computation code.)
  (prefix-in :clan/poo/benchmarks/workloads/component-requests approval-revision.service.)
  (prefix-in :clan/poo/graph/component/joint joint.)
  (prefix-in :clan/poo/benchmarks/workloads/component-rounds rounds.)
  (prefix-in :clan/poo/benchmarks/workloads/joint-topology joint-admission.service.)
  (prefix-in :clan/poo/benchmarks/workloads/joint-topology joint-installation.service.)
  :clan/poo/mop/lens-laws
  (prefix-in :clan/poo/benchmarks/workloads/joint-services joint-publication.service.)
  (prefix-in :clan/poo/benchmarks/workloads/joint-topology joint-receipts.service.)
  (prefix-in :clan/poo/benchmarks/workloads/joint-receipts receipts.))

;; Construct once with the original private helper scope and declaration order.
(defvalues (approval-revision-test)
  (let () (include "joint-publication/approval-revision.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (joint-admission-test)
  (let () (include "joint-publication/joint-admission.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (joint-installation-test)
  (let () (include "joint-publication/joint-installation.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (joint-publication-test)
  (let () (include "joint-publication/cases.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (joint-receipts-test)
  (let () (include "joint-publication/joint-receipts.ss")))
