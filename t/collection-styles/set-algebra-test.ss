;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export set-algebra-test set-observation-test)
(import
  :std/test
  :std/error
  :std/iter
  (only-in :clan/poo/brace @@method)
  :clan/poo/object
  :clan/poo/mop
  :clan/poo/fun
  :clan/poo/number
  :clan/poo/type
  :clan/poo/table
  :clan/poo/rationaldict
  :clan/poo/support/option
  (only-in :clan/poo/trie SimpleTrie SimpleTrieSet)
  (only-in :clan/poo/t/table-testing alist-table box-table)
  (prefix-in :clan/poo/examples/service-collection service.)
  (prefix-in (only-in :clan/poo/examples/contract-publication publication-action) publication.)
  (prefix-in :clan/poo/declarative-metadata metadata.))

;; Construct once with the original private helper scope and declaration order.
(defvalues (set-algebra-test)
  (let () (include "set-algebra/cases.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (set-observation-test)
  (let () (include "set-algebra/set-observation.scm")))
