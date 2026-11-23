;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export class-validation-test computed-validation-test container-validation-test contract-checks-test contract-family-test contract-publication-test evidence-binding-test object-contract-flow-test object-contract-test)
(import
  :std/test
  :clan/poo/object
  :clan/poo/mop
  :clan/poo/number
  :clan/poo/types/object-contract
  (only-in :clan/poo/type Record List Tuple Maybe TypeValuePair String Json
           Any Bool Object Function CaseFunction Fun Type Type. define-type element? validate TypeError?)
  (prefix-in :clan/poo/t/fixtures/class-publication class-validation.service.)
  (prefix-in :clan/poo/mop/declarative-metadata metadata.)
  (prefix-in :clan/poo/benchmarks/workloads/contract-publication class-validation.publication.)
  (prefix-in :clan/poo/benchmarks/workloads/object-contracts config.)
  (prefix-in :clan/poo/recursive/validation graph.)
  (prefix-in :clan/poo/t/fixtures/computed-publication pipeline.)
  (prefix-in :clan/poo/benchmarks/workloads/contract-publication computed-validation.publication.)
  (prefix-in :clan/poo/t/fixtures/container-publication batch.)
  (prefix-in :clan/poo/benchmarks/workloads/contract-publication container-validation.publication.)
  (prefix-in :clan/poo/benchmarks/workloads/object-contracts container-validation.service.)
  :std/error
  :clan/poo/types/relation
  :clan/poo/types/syntax
  :clan/poo/types/prototype-types
  (only-in :clan/poo/support/base require-value)
  (prefix-in :clan/poo/types/function-signature signatures.)
  (prefix-in :clan/poo/t/fixtures/row-services rows.)
  (prefix-in :clan/poo/t/fixtures/contract-interop interop.)
  :std/iter
  (only-in :std/values first-value)
  (prefix-in :clan/poo/mop/contract-family family.)
  (prefix-in :clan/poo/benchmarks/workloads/service-metadata contract-family.service.)
  (prefix-in :clan/poo/benchmarks/workloads/service-bundle bundle.)
  (prefix-in :clan/poo/benchmarks/workloads/cyclic-access access.)
  (prefix-in :clan/poo/benchmarks/workloads/shared-contracts shared.)
  (prefix-in :clan/poo/graph/staged-publication staged.)
  (prefix-in :clan/poo/graph/cyclic-publication contract-family.publication.)
  (prefix-in :clan/poo/benchmarks/workloads/object-contracts contract-publication.service.)
  (prefix-in :clan/poo/benchmarks/workloads/contract-publication contract-publication.publication.)
  :clan/poo/brace
  :clan/poo/io
  (prefix-in :clan/poo/benchmarks/workloads/object-contracts object-contract-flow.service.)
  (only-in :clan/poo/type String))

;; Construct once with the original private helper scope and declaration order.
(defvalues (class-validation-test)
  (let () (include "object-contract/class-validation.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (computed-validation-test)
  (let () (include "object-contract/computed-validation.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (container-validation-test)
  (let () (include "object-contract/container-validation.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (contract-checks-test)
  (let () (include "object-contract/contract-checks.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (contract-family-test)
  (let () (include "object-contract/contract-family.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (contract-publication-test)
  (let () (include "object-contract/contract-publication.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (evidence-binding-test)
  (let () (include "object-contract/evidence-binding.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (object-contract-flow-test)
  (let () (include "object-contract/object-contract-flow.ss")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (object-contract-test)
  (let () (include "object-contract/cases.ss")))
