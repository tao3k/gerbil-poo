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

;; Give method-combination-test its own compiler function and private fixture scope.
(def (make-method-combination-test)
  (include "method-declaration/method-combination.scm"))

(def method-combination-test (make-method-combination-test))

;; Give method-declaration-test its own compiler function and private fixture scope.
(def (make-method-declaration-test)
  (include "method-declaration/cases.scm"))

(def method-declaration-test (make-method-declaration-test))

;; Give multimethod-test its own compiler function and private fixture scope.
(def (make-multimethod-test)
  (include "method-declaration/multimethod.scm"))

(def multimethod-test (make-multimethod-test))

;; Give typed-method-declaration-test its own compiler function and private fixture scope.
(def (make-typed-method-declaration-test)
  (include "method-declaration/typed-method-declaration.scm"))

(def typed-method-declaration-test (make-typed-method-declaration-test))
