;;; Fixture-free ordered collection suites share one standard module image.
;;; Export order retains the original gxtest suite delivery order; private
;;; helpers stay in this existing functional owner, without wrapper closures.
(export rationaldict-order-test table-cursor-test table-order-test table-split-test)
(import :std/test :std/error :std/iter
        :clan/poo/object :clan/poo/mop :clan/poo/type :clan/poo/number
        :clan/poo/table :clan/poo/rationaldict :clan/poo/support/option
        (only-in :clan/poo/support/base number-comparer)
        (only-in :std/list/list-builder with-list-builder)
        (only-in :clan/poo/brace @@method)
        (only-in :clan/poo/t/table-testing alist-table box-table)
        (only-in :clan/poo/fun Wrapper. IdWrap)
        (only-in :clan/poo/trie SimpleTrie Trie. Branch Leaf trie-for-each-change)
        (prefix-in :clan/poo/examples/service-collection service.))

;; Match only the precise protocol refusal; arbitrary callback causes propagate.
(def (message? text)
  (lambda (cause) (and (Error? cause) (equal? (Error-message cause) text))))

(include "table-order/rationaldict.scm")
(include "table-order/cursors.scm")
(include "table-order/queries.scm")
(include "table-order/decomposition.scm")
