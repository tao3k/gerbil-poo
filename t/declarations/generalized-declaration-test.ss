;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export catalog-inference-test declarative-metadata-test generalized-declaration-test meta-prototype-test recursive-declaration-test)
(import
  :std/test
  :std/error
  :clan/poo/object
  :clan/poo/mop
  :clan/poo/number
  :clan/poo/prototype-types
  :clan/poo/types/relation
  :clan/poo/method-declaration
  (only-in :clan/poo/type RecordSlot)
  (only-in :clan/poo/optional-validation call-with-current-catalogs)
  (only-in :clan/poo/slot-observation call-with-slot-read-observer slot-read-receiver slot-read-key)
  (prefix-in :clan/poo/examples/signature-service signature.)
  :std/iter
  (only-in :std/values first-value)
  (prefix-in :clan/poo/declarative-metadata metadata.)
  (prefix-in :clan/poo/multimethod multimethod.)
  (prefix-in :clan/poo/dispatch-extension dispatch-extension.)
  :clan/poo/brace
  :clan/poo/declaration
  :clan/poo/generalized-declaration
  (prefix-in :clan/poo/generalized-prototype gp.)
  (prefix-in :clan/poo/examples/generalized-declarations generalized-declaration.service.)
  :clan/poo/meta-prototype
  :clan/poo/reflection
  (prefix-in :clan/poo/examples/metaprotocol-services meta-prototype.service.)
  :clan/poo/closure
  :clan/poo/recursive-declaration
  (prefix-in :clan/poo/recursive recursive.)
  (prefix-in :clan/poo/examples/recursive-metaprotocol recursive-declaration.service.))

;; Construct once with the original private helper scope and declaration order.
(defvalues (catalog-inference-test)
  (let () (include "generalized-declaration/catalog-inference.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (declarative-metadata-test)
  (let () (include "generalized-declaration/declarative-metadata.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (generalized-declaration-test)
  (let () (include "generalized-declaration/cases.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (meta-prototype-test)
  (let () (include "generalized-declaration/meta-prototype.scm")))

;; Construct once with the original private helper scope and declaration order.
(defvalues (recursive-declaration-test)
  (let () (include "generalized-declaration/recursive-declaration.scm")))
