;;-*- Gerbil -*-
;; Prototype Object Orientation Functionally, in Gerbil Scheme.
;;
;; Next version of poo, with multiple inheritance and a budding meta-object protocol.
;; See doc/poo.md for documentation

;; Reexport renamed version of core things we shadow
(export (except-out #t object-record-read object-read-query object-read-bootstrap
                    %call-with-fresh-slot-read-group %admitted-vector-read-fields!
                    object-deliver-value require-object-read-route! object-issued-read-current?
                    call-with-issued-reads %call-with-current-slot-reads %replay-fresh-slot-reads! replay-read-list!
                    active-read-replays issue-object-read %issue-read object-slot-names object-slot-present?
                    object-read-key object-read-dependencies object-read-value
                    require-current-read-sweep! %projection-read-visit-index %pure-read-sweep? %read-index-size-effect-free?
                    record-key-field record-dependencies-field record-value-field
                    slot-spec-discards-super? compile-slot-specs prepare-declaration-specifications compute-object-precedence!
                    %prepared-vector-slot-ref %prepared-vector-slots-ref %registered-field-reader
                    %bind-current-slot-reads %prepared-slot-present?
                    %register-slot-dependencies!
                    %with-slot-edit-protection %publish-slot-edits!
                    %put-assigned-slot! %depend-on-object-except-slot!
                    %owned-list-slot-spec %ref-owned-list define-slot-ref
                    instance-storage-info instance-native-table
                    %live-object-instance %live-object-layout
                    instantiate-for-demand! compile-slot-funs-for-demand!
                    current-constant-method? instantiate-with-preparation!
                    prepare-slot-values publish-preparation! compile-slot-funs-with!) @object? @make-object)

(import
  (prefix-in (only-in Runtime object? make-object) @) ;; Rename them before we shadow them
  (only-in ./support/object-syntax parse-object-options
           deduplicate-slot-identifiers prepare-shared-slot-specs
           normalize-slot-specs normalize-slot-specs-for-match)
  (for-syntax :std/iter
              (only-in :std/list/list push! delete-duplicates/hash)
              (only-in :std/list/list-builder with-list-builder))
  (only-in :std/error deferror-class Exception)
  (only-in :std/hash/misc hash->list/sort hash-ref/default hash-ensure-modify!)
  :std/iter
  ./slot-observation
  (prefix-in (only-in :gerbil/runtime/mop object-class find-method) read-runtime.)
  (only-in ./read-route standard-symbol-table-writes?
           %issued-read? %read-issuance)
  ./object/state
  ./object/prototype-map
  ./object/slot-layout
  (only-in :std/list/list-builder with-list-builder)
  (only-in :std/list/list flatten delete-duplicates/hash map-in-order)
  (only-in :std/string/symbol symbol<?)
  :std/stxparam
  (only-in :std/values first-value)
  (only-in :gerbil/runtime/c3 c4-linearize*)
  (only-in :gerbil/runtime/table symbolic-hash raw-table-ref symbolic-table-ref)
  (only-in :gerbil/runtime/interface interface-instance? interface-instance-object)
  (only-in :gerbil/runtime/table raw-table? raw-table-for-each &raw-table-count &raw-table-table)
  (only-in ./support/base λ let-id-rule defonce awhen %graph-table-seed))

(include "object/representation.scm")
(include "object/construction.scm")

(include "object/slot-values.scm")
;; Receiver-bound observations share this module's object/Slot authority.
(include "object/observation.ss")

(include "object/slot-access.scm")

(include "object/operations.scm")

(include "object/syntax.scm")

(include "object/mutation.scm")
