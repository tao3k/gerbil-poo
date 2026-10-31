;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export table-group-join-test table-index-equivalence-test table-index-test)
(import
  :std/test
  :std/error
  :std/iter
  :clan/poo/object
  :clan/poo/mop
  :clan/poo/type
  :clan/poo/number
  :clan/poo/table
  :clan/poo/rationaldict
  :clan/poo/support/option
  (only-in :clan/poo/trie SimpleTrie)
  (only-in :clan/poo/t/table-testing alist-table borrowing-table box-table)
  (prefix-in :clan/poo/examples/service-collection service.)
  (only-in :clan/poo/fun Wrapper.)
  (only-in :clan/poo/t/table-testing alist-table))

;; Construct once with the original private helper scope and declaration order.
(defvalues (table-group-join-test)
  (let () (include "table-index/table-group-join.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (table-index-equivalence-test)
  (let () (include "table-index/table-index-equivalence.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (table-index-test)
  (let () (include "table-index/cases.scm")))
