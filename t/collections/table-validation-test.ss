;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export table-selection-test table-validation-test)
(import
  :std/test
  :std/error
  :std/iter
  (only-in :clan/poo/brace @@method)
  (only-in :clan/poo/fun Wrapper.)
  :clan/poo/object
  :clan/poo/mop
  :clan/poo/type
  :clan/poo/number
  :clan/poo/table
  :clan/poo/table/rationaldict
  :clan/poo/support/option
  (only-in :clan/poo/trie SimpleTrie SimpleTrieSet Branch Leaf)
  (only-in :clan/poo/t/table-testing alist-table box-table)
  (prefix-in :clan/poo/t/fixtures/service-collection service.)
  (only-in :gerbil/runtime/mop slot-ref slot-set!)
  (only-in :std/list/alist aset arem alist?)
  (only-in :clan/poo/types/object-contract checked-action))

;; Construct once with the original private helper scope and declaration order.
(defvalues (table-selection-test)
  (let () (include "table-validation/table-selection.ss")))

;; Validation helpers remain private to this test module.
(include "table-validation/cases.ss")
