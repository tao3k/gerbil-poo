;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export set-style-test table-receiver-test table-style-test)
(import
  :std/test
  :std/error
  :std/iter
  :std/interface
  (only-in :clan/poo/brace @@method)
  :clan/poo/object
  :clan/poo/mop
  :clan/poo/type
  :clan/poo/number
  :clan/poo/table
  :clan/poo/rationaldict
  :clan/poo/support/option
  (only-in :clan/poo/trie SimpleTrie SimpleTrieSet TrieSet.)
  (only-in :clan/poo/t/table-testing alist-table)
  (prefix-in :clan/poo/examples/service-collection service.)
  :std/sync/channel)

;; Construct once with the original private helper scope and declaration order.
(defvalues (set-style-test)
  (let () (include "table-style/set-style.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (table-receiver-test)
  (let () (include "table-style/table-receiver.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (table-style-test)
  (let () (include "table-style/cases.scm")))
