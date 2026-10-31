;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export binding-benchmark-test factory-benchmark-test focused-benchmark-test generalized-benchmark-test generalized-closure-test generalized-prototype-test)
(import
  :std/test
  :std/iter
  (prefix-in (only-in :clan/poo/benchmarks/binding-benchmark workload) binding.)
  (only-in :clan/poo/benchmarks/closure-measure measure-pair)
  (prefix-in :clan/poo/benchmarks/binding-cases binding-benchmark.study.)
  (prefix-in :clan/poo/benchmarks/metadata-paired-suite paired.)
  (prefix-in (only-in :clan/poo/benchmarks/factory-benchmark workload) factory.)
  (prefix-in :clan/poo/benchmarks/factory-cases factory-benchmark.study.)
  (prefix-in (only-in :clan/poo/benchmarks/focused-benchmark workload) focused.)
  (prefix-in :clan/poo/benchmarks/focused-cases focused-benchmark.study.)
  (prefix-in (only-in :clan/poo/benchmarks/generalized-benchmark workload) generalized.)
  (prefix-in :clan/poo/benchmarks/generalized-cases generalized-benchmark.study.)
  (only-in :clan/poo/benchmarks/generalized-observation-reference profile)
  :clan/poo/object
  :clan/poo/mop
  :clan/poo/brace
  :clan/poo/lens-laws
  :clan/poo/generalized-declaration
  :clan/poo/generalized-closure
  (prefix-in :clan/poo/examples/closed-declarations service.)
  (prefix-in :clan/poo/examples/generalized-declarations finite.)
  (prefix-in (only-in :clan/poo/fun Observation.) fun.)
  (prefix-in :clan/poo/generalized-prototype gp.)
  (prefix-in :clan/poo/examples/generalized-checkout checkout.))

;; Construct once with the original private helper scope and declaration order.
(defvalues (binding-benchmark-test)
  (let () (include "generalized-prototype/binding-benchmark.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (factory-benchmark-test)
  (let () (include "generalized-prototype/factory-benchmark.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (focused-benchmark-test)
  (let () (include "generalized-prototype/focused-benchmark.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (generalized-benchmark-test)
  (let () (include "generalized-prototype/generalized-benchmark.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (generalized-closure-test)
  (let () (include "generalized-prototype/generalized-closure.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (generalized-prototype-test)
  (let () (include "generalized-prototype/cases.scm")))
