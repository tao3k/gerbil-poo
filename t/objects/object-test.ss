;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export lifecycle-test mop-test object-test parameters-test slot-observation-test support-test)
(import
  :std/test
  :std/iter
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

;; Give lifecycle-test its own compiler function and private fixture scope.
(def (make-lifecycle-test)
  (include "object/lifecycle.scm"))

(def lifecycle-test (make-lifecycle-test))

;; Give mop-test its own compiler function and private fixture scope.
(def (make-mop-test)
  (include "object/mop.scm"))

(def mop-test (make-mop-test))

;; Give object-test its own compiler function and private fixture scope.
(def (make-object-test)
  (include "object/cases.scm"))

(def object-test (make-object-test))

;; Give parameters-test its own compiler function and private fixture scope.
(def (make-parameters-test)
  (include "object/parameters.scm"))

(def parameters-test (make-parameters-test))

;; Give slot-observation-test its own compiler function and private fixture scope.
(def (make-slot-observation-test)
  (include "object/slot-observation.scm"))

(def slot-observation-test (make-slot-observation-test))

;; Give support-test its own compiler function and private fixture scope.
(def (make-support-test)
  (include "object/support.scm"))

(def support-test (make-support-test))
