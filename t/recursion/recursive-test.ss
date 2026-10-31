;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export recursive-benchmark-test recursive-test)
(import
  :std/test
  :std/iter
  (only-in :clan/poo/benchmarks/recursive-benchmark workload)
  (prefix-in :clan/poo/benchmarks/recursive-cases study.)
  (prefix-in :clan/poo/benchmarks/metadata-paired-suite paired.)
  (only-in :std/values first-value)
  :clan/poo/object
  (only-in :clan/poo/mop Any Bool)
  (prefix-in :clan/poo/recursive recursive.)
  (prefix-in :clan/poo/recursive-cache cached.)
  (prefix-in :clan/poo/recursive-handling handling.)
  (prefix-in :clan/poo/examples/cyclic-access access.)
  (prefix-in :clan/poo/examples/recursive-catalog catalog.)
  (prefix-in :clan/poo/cyclic-publication publication.)
  (prefix-in :clan/poo/multimethod dispatch.))

;; Construct once with the original private helper scope and declaration order.
(defvalues (recursive-benchmark-test)
  (let () (include "recursive/recursive-benchmark.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (recursive-test)
  (let () (include "recursive/cases.scm")))
