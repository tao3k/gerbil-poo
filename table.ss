;;; Common declarations and methods for tables

(export methods.table Set<-Table. PreZipping. Zipping. FocusableZipping.
        with-set-tables fold-set/shared-backing iterator-map table-element? validate-table table-for-each-change table-styles set-styles table-indexes
        table-comparer table-comparer-wrapper table-order table-ordered-cursor
        table-key-space table-index-conflict? table-index-conflict-name table-index-conflict-key
        table-index-conflict-existing table-index-conflict-incoming
        table-delta? table-delta-count invert-table-delta table-isomorphism table-fold table-group-fold table-projection table-group-join table-lookup-join set-image set-combination table-combination table-wrapper
        table-projection-compose
        table-isomorphism-failure? table-isomorphism-failure-kind table-isomorphism-failure-value
        table-conflict? table-conflict-key)

(import
  (only-in ./types/variant-validation validate-bindings rebuild-bindings)
  (only-in ./object/slot-observation %slot-read-active?)
  (only-in :gerbil/runtime/thread with-lock)
  :std/interface
  :std/iter
  (only-in :std/list/list-builder with-list-builder)
  (only-in :std/list/list delete-duplicates/hash append-map find)
  (only-in :std/list/alist acons)
  (only-in :std/func compose)
  (only-in :std/number/misc uint?)
  (only-in ./support/option some some? option-ref option-get/default map/option some-value)
  (only-in ./brace @method @@method)
  (only-in ./io marshal)
  (only-in ./mop/prototype define-type Type. Function. Any validate element? raise-type-error TypeError? Lens lens-of-get-set)
  (only-in ./fun Wrapper. Wrap.)
  (only-in ./types/function-signature signature-shape?)
  (only-in ./object .o object<-alist .all-slots .@ .ref .slot? .call .cc .mix .has? object-revision active-object-constructions instantiate-object!)
  (only-in ./type List Pair Sum Unit Bool))

(include "table/iterator.ss")

(include "table/validation.ss")

(include "table/delta.ss")

(include "table/fold.ss")

(include "table/translation.ss")

(include "table/protocol.ss")

;; Set presentation and algebra remain in the existing table module.
(include "table/sets.ss")
(include "table/io.ss")

(include "table/focus.ss")
(include "table/observation.ss")
(include "table/mapping.ss")

;; Derive style ownership in the existing interface; .admit normalizes raw input,
;; whereas .ap and transitions retain admitted Function wrappers and batch ordering.
(include "table/styles.ss")

;; Correlated indexes share the same public table namespace and backend contracts.
(include "table/indexes.ss")

(include "table/order.ss")
