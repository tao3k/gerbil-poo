;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export table-construction-test table-focus-test table-io-test table-normalization-test)
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
  (only-in :clan/poo/trie SimpleTrie SimpleTrieSet)
  (only-in :clan/poo/fun Wrapper.)
  (only-in :clan/poo/t/table-testing box-table alist-table borrowing-table)
  (only-in :clan/poo/support/base number-comparer)
  (prefix-in :clan/poo/examples/service-collection service.)
  (only-in :clan/poo/brace @@method)
  :std/misc/ports
  (only-in :clan/poo/t/table-testing alist-table))

;; Construct once with the original private helper scope and declaration order.
(defvalues (table-construction-test)
  (let () (include "table-construction/cases.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (table-focus-test)
  (let () (include "table-construction/table-focus.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (table-io-test)
  (let () (include "table-construction/table-io.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (table-normalization-test)
  (let () (include "table-construction/table-normalization.scm")))
