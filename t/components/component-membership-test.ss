;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export component-membership-test component-migration-test component-requests-test component-rounds-test)
(import
  :std/test
  :clan/poo/object
  :clan/poo/mop
  :clan/poo/brace
  :clan/poo/support/option
  :clan/poo/feedback-graph
  :clan/poo/feedback-cache
  (prefix-in :clan/poo/construction-cache cache.)
  (prefix-in :clan/poo/strong-components scc.)
  (prefix-in :clan/poo/generalized-graph graph.)
  (prefix-in :clan/poo/dependency-analysis code.)
  (prefix-in :clan/poo/examples/component-membership component-membership.service.)
  (prefix-in :clan/poo/component-revision revision.)
  (prefix-in :clan/poo/examples/component-membership initial.)
  (prefix-in :clan/poo/examples/component-migration component-migration.service.)
  :std/sync/channel
  :clan/poo/lens-laws
  (prefix-in :clan/poo/component-publication publication.)
  (prefix-in :clan/poo/examples/component-requests component-requests.service.)
  (prefix-in :clan/poo/examples/component-rounds rounds.)
  (only-in :std/list/list foldl find filter)
  (prefix-in :clan/poo/examples/component-rounds component-rounds.service.))

;; Construct once with the original private helper scope and declaration order.
(defvalues (component-membership-test)
  (let () (include "component-membership/cases.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (component-migration-test)
  (let () (include "component-membership/component-migration.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (component-requests-test)
  (let () (include "component-membership/component-requests.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (component-rounds-test)
  (let () (include "component-membership/component-rounds.scm")))
