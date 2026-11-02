;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export lifecycle-test mop-test object-test parameters-test slot-observation-test support-test)
(import
  :std/test
  :clan/poo/object
  :clan/poo/mop
  :clan/poo/number
  :clan/poo/brace
  (prefix-in :clan/poo/examples/lifecycle lifecycle.)
  :std/assert
  :std/format
  (except-in :clan/poo/support/base ignore-errors)
  :clan/poo/support/debug
  :clan/poo/support/testing
  :clan/poo/type
  :clan/poo/io
  (only-in :clan/poo/object-state make-object-state object-state-revision depend-on-state! invalidate-state!)
  (rename-in (only-in :clan/poo/object with-prefixed-slots def-prefixed-slots) (with-prefixed-slots renamed-fields) (def-prefixed-slots renamed-snapshots))
  :std/error
  (for-syntax :gerbil/expander)
  (prefix-in :clan/poo/parameters parameters.)
  (prefix-in :clan/poo/examples/parameter-service service.)
  (prefix-in :clan/poo/method-declaration methods.)
  (prefix-in :clan/poo/method-combination combination.)
  :clan/poo/slot-observation
  :clan/poo/slot-layout
  (only-in :clan/poo/meta-prototype bootstrap-protocol)
  (only-in :clan/poo/support/object-syntax deduplicate-slot-identifiers)
  (for-syntax (only-in :std/list/list delete-duplicates/hash))
  :clan/poo/support/io
  :clan/poo/support/repr)

;; Construct once with the original private helper scope and declaration order.
(defvalues (lifecycle-test)
  (let () (include "object/lifecycle.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (mop-test)
  (let () (include "object/mop.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (object-test)
  (let () (include "object/cases.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (parameters-test)
  (let () (include "object/parameters.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (slot-observation-test)
  (let () (include "object/slot-observation.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (support-test)
  (let () (include "object/support.scm")))
