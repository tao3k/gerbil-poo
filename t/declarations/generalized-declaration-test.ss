;;; Related fixture-free suites share one standard runtime section.
;;; Gerbil retains export discovery, case order and all fixture boundaries.
(export catalog-inference-test declarative-metadata-test generalized-declaration-test meta-prototype-test recursive-declaration-test)
(import
  :std/test
  :std/error
  :clan/poo/object
  :clan/poo/mop
  :clan/poo/number
  :clan/poo/types/prototype-types
  :clan/poo/types/relation
  :clan/poo/mop/methods/declaration
  (only-in :clan/poo/type RecordSlot Bool Function Type Type. element? validate TypeError?)
  (only-in :clan/poo/types/optional-validation call-with-current-catalogs)
  (only-in :clan/poo/slot-observation call-with-slot-read-observer slot-read-receiver slot-read-key)
  (prefix-in :clan/poo/examples/signature-service signature.)
  :std/iter
  (only-in :std/values first-value)
  (prefix-in :clan/poo/declarative-metadata metadata.)
  (prefix-in :clan/poo/mop/methods/dispatch multimethod.)
  (prefix-in :clan/poo/mop/methods/extension dispatch-extension.)
  :clan/poo/brace
  :clan/poo/object/declaration
  :clan/poo/mop/generalized-declaration
  (prefix-in :clan/poo/mop/generalized-prototype gp.)
  (prefix-in :clan/poo/examples/generalized-declarations generalized-declaration.service.)
  :clan/poo/mop/meta-prototype
  :clan/poo/object/reflection
  (prefix-in :clan/poo/examples/metaprotocol-services meta-prototype.service.)
  :clan/poo/graph/closure
  :clan/poo/recursive/declaration
  (prefix-in :clan/poo/recursive/evaluation recursive.)
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
