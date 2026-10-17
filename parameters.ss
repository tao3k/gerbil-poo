;;; Persistent positional prefix specialization reuses ordinary receiver cloning.
(export parameters specialize)
(import (only-in :std/list/list take drop delete-duplicates/hash)
        ./object)

;; Snapshot and check the remaining positional names before allocating a receiver.
;; Metadata is explicit: names are unique symbols and cannot replace .parameters.
(def (parameters prototype)
  (def names (.ref prototype '.parameters))
  (unless (and (list? names) (andmap symbol? names)
               (not (memq '.parameters names))
               (= (length names) (length (delete-duplicates/hash names))))
    (error "invalid positional parameter declaration" names))
  (map identity names))

;; Bind an ordered prefix, retaining all other formulas and metadata through .cc.
;; Zero arguments preserve identity; excess arguments refuse before cloning.
;; Remaining names are copied, so later mutation of the declaration list spine
;; cannot alter the derived object's arity. Parameter values keep their identity.
;; No result/approval is memoized: computed slots use the new receiver, and Type
;; validation or FUN effects remain the consumer's existing checked boundary.
(def (specialize prototype . arguments)
  (def names (parameters prototype))
  (def count (length arguments))
  (when (> count (length names)) (error "too many positional arguments" arguments names))
  (if (zero? count) prototype
    (apply .cc prototype '.parameters (drop names count)
      (apply append (map list (take names count) arguments)))))
