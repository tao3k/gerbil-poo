;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export class-validation-test computed-validation-test container-validation-test contract-checks-test contract-family-test contract-publication-test evidence-binding-test object-contract-flow-test object-contract-test)
(import
  :std/test
  :clan/poo/object
  :clan/poo/mop
  :clan/poo/number
  :clan/poo/object-contract
  (only-in :clan/poo/type Record List Tuple Maybe TypeValuePair String Json)
  (prefix-in :clan/poo/examples/class-publication class-validation.service.)
  (prefix-in :clan/poo/declarative-metadata metadata.)
  (prefix-in :clan/poo/examples/contract-publication class-validation.publication.)
  (prefix-in :clan/poo/examples/object-contracts config.)
  (prefix-in :clan/poo/recursive-validation graph.)
  (prefix-in :clan/poo/examples/computed-publication pipeline.)
  (prefix-in :clan/poo/examples/contract-publication computed-validation.publication.)
  (prefix-in :clan/poo/examples/container-publication batch.)
  (prefix-in :clan/poo/examples/contract-publication container-validation.publication.)
  (prefix-in :clan/poo/examples/object-contracts container-validation.service.)
  :std/error
  :clan/poo/types/relation
  :clan/poo/types/syntax
  :clan/poo/prototype-types
  (only-in :clan/poo/support/base require-value)
  (prefix-in :clan/poo/function-signature signatures.)
  (prefix-in :clan/poo/examples/row-services rows.)
  (prefix-in :clan/poo/examples/contract-interop interop.)
  :std/iter
  (only-in :std/values first-value)
  (prefix-in :clan/poo/contract-family family.)
  (prefix-in :clan/poo/examples/service-metadata contract-family.service.)
  (prefix-in :clan/poo/examples/service-bundle bundle.)
  (prefix-in :clan/poo/examples/cyclic-access access.)
  (prefix-in :clan/poo/examples/shared-contracts shared.)
  (prefix-in :clan/poo/staged-publication staged.)
  (prefix-in :clan/poo/cyclic-publication contract-family.publication.)
  (prefix-in :clan/poo/examples/object-contracts contract-publication.service.)
  (prefix-in :clan/poo/examples/contract-publication contract-publication.publication.)
  :clan/poo/brace
  :clan/poo/io
  (prefix-in :clan/poo/examples/object-contracts object-contract-flow.service.)
  (only-in :clan/poo/type String))

;; Construct once with the original private helper scope and declaration order.
(defvalues (class-validation-test)
  (let () (include "object-contract/class-validation.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (computed-validation-test)
  (let () (include "object-contract/computed-validation.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (container-validation-test)
  (let () (include "object-contract/container-validation.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (contract-checks-test)
  (let () (include "object-contract/contract-checks.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (contract-family-test)
  (let () (include "object-contract/contract-family.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (contract-publication-test)
  (let () (include "object-contract/contract-publication.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (evidence-binding-test)
  (let () (include "object-contract/evidence-binding.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (object-contract-flow-test)
  (let () (include "object-contract/object-contract-flow.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (object-contract-test)
  (let () (include "object-contract/cases.scm")))
