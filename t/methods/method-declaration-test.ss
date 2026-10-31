;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export method-combination-test method-declaration-test multimethod-test typed-method-declaration-test)
(import
  :std/test
  :std/iter
  (only-in :std/values first-value)
  :clan/poo/object
  :clan/poo/support/option
  (only-in :clan/poo/number Integer)
  (prefix-in :clan/poo/method-combination combination.)
  (prefix-in :clan/poo/multimethod dispatch.)
  (prefix-in :clan/poo/dispatch-extension extension.)
  (prefix-in :clan/poo/declarative-metadata metadata.)
  (prefix-in :clan/poo/cyclic-publication publication.)
  (prefix-in :clan/poo/generic-family family.)
  (prefix-in :clan/poo/examples/service-combination combined.)
  (prefix-in :clan/poo/examples/service-bundle bundle.)
  :std/error
  :clan/poo/mop
  :clan/poo/brace
  :clan/poo/declaration
  :clan/poo/method-declaration
  :clan/poo/reflection
  :clan/poo/recursive-declaration
  (prefix-in :clan/poo/proto proto.)
  (prefix-in :clan/poo/examples/declared-methods service.)
  (only-in :std/list/list-builder with-list-builder)
  (prefix-in :clan/poo/multimethod multimethod.)
  (prefix-in :clan/poo/dispatch-extension dispatch-extension.))

;; Construct once with the original private helper scope and declaration order.
(defvalues (method-combination-test)
  (let () (include "method-declaration/method-combination.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (method-declaration-test)
  (let () (include "method-declaration/cases.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (multimethod-test)
  (let () (include "method-declaration/multimethod.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (typed-method-declaration-test)
  (let () (include "method-declaration/typed-method-declaration.scm")))
