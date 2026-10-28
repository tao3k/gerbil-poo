;;; Declaration and reflection reuse the existing Slot / Class metadata protocol.
(export object<-declarations make-declared-instance reflect-slots read-slot write-slot!)
(import :std/iter (only-in :std/list/list delete-duplicates/hash foldr)
        ./object ./mop ./prototype-map
        (only-in ./slot-observation %slot-read-active?) (only-in ./type element? validate))
;; Compile named Slot descriptors through their existing .slot.define method.
;; Validate the whole declaration list before creating any externally visible value.
;; Metadata descriptors are sources too: edits invalidate every declared receiver.
(def (object<-declarations entries supers: (supers []) protocol: (protocol #f))
  (unless (and (list? entries)
      (andmap (lambda (entry) (and (pair? entry) (symbol? (car entry))
                    (element? Slot (cdr entry)))) entries)
      (= (length entries) (length (delete-duplicates/hash (map car entries)))))
    (error "distinct named Slot descriptors required"))
  (def self (make-object supers: supers protocol: protocol declarations: entries))
  (for (([name . descriptor] entries))
    (depend-on-object! self descriptor))
  (instantiate-object! self)
  self)
;; Bridge the existing Class effective-slot catalog and checked constructor to
;; declared reflection. Catalog membership is captured at construction; descriptor
;; contents stay registered sources. New catalog membership needs a fresh instance.
;; Whole-class/cross-field constraints still need explicit instantiate after edits.
(def (make-declared-instance class . plist)
  (def value (apply make-instance class plist))
  (validate class (object<-declarations (.alist (.@ class effective-slots)) supers: [value])))
;; Receiver-local metadata uses the existing persistent map and invalidation
;; boundary. No process registry or additional namespace is introduced. Private
;; maps never escape; descriptor contents remain registered mutable sources.
(defstruct declaration-index (all visible))
;; Metadata callbacks/observers can invalidate an owner. Refuse the old query
;; before publishing a visibility map or returning a stale reflected result.
(def (require-declaration-revision self revision)
  (unless (= revision (object-revision self))
    (error "object changed during declaration reflection")))
;; Merge the effective C3 catalog once, keeping the earliest declaration for each
;; symbol, exactly as standard delete-duplicates/hash from-end does. An observed
;; lookup also authenticates owner membership through the existing names query;
;; descriptor-only reads cannot account for topology/membership changes alone.
(def (effective-declarations self)
  (def revision (object-revision self))
  (instantiate-object! self)
  (when (%slot-read-active?) (.all-slots self))
  (require-declaration-revision self revision)
  (or (object-%declaration-index self)
    (let (index (make-declaration-index
      (prototype-map-merge-first (map object-%declarations (object-%precedence-list self))
        policy: 'compact) #f))
      (require-declaration-revision self revision)
      (set! (object-%declaration-index self) index)
      index)))
;; Preserve the original foldr visibility-read order and exact first exception.
;; The list and its entry pairs belong only to this query. Never publish a partial
;; public index after a getter refusal or a supported edit during observation.
(def (visible-declarations self index)
  (def revision (object-revision self))
  (def entries (foldr (lambda (entry rest)
    (if (.@ (cdr entry) hidden) rest (cons entry rest))) []
    (prototype-map-list (declaration-index-all index))))
  (require-declaration-revision self revision)
  entries)
;; Only unobserved requests reuse visibility. Observed calls still deliver every
;; actual hidden-field read in its original order; successful admission itself is
;; never cached. Empty visible maps are successful values, distinct from #f.
(def (public-declarations self index)
  (or (declaration-index-visible index)
    (let* ((revision (object-revision self))
           (visible (prototype-map-filter (declaration-index-all index)
             (lambda (_name descriptor) (not (.@ descriptor hidden))))))
      (require-declaration-revision self revision)
      (set! (declaration-index-visible index) visible)
      visible)))
;; Reflect metadata without demanding slot VALUES. Hidden-inclusive inspection
;; does not read visibility flags. Every public result owns its list/entry pairs.
(def (reflect-slots self include-hidden?: (include-hidden? #f))
  (def index (effective-declarations self))
  (cond (include-hidden? (prototype-map-list (declaration-index-all index)))
        ((%slot-read-active?) (visible-declarations self index))
        (else (prototype-map-list (public-declarations self index)))))
;; Resolve public metadata by indexed symbol lookup on the unobserved warm path.
;; The observed route retains ordered visibility reads and the same missing/hidden
;; refusal. Both resolve metadata before demanding or checking a concrete value.
(def (public-slot self name)
  (def index (effective-declarations self))
  (or (if (%slot-read-active?)
        (let (entry (assq name (visible-declarations self index))) (and entry (cdr entry)))
        (let (visible (public-declarations self index))
          (and (symbol? name) (prototype-map-ref visible name))))
      (error "slot is hidden or undeclared" name)))
;; Admit a concrete value through the existing Slot checker. The private
;; one-field receiver checks cached assignments and hook-produced values too;
;; the descriptor's predicate never receives the caller's mutable cache table.
(def (validate-slot-value descriptor name value)
  (unless (.call (.@ descriptor .type) .slot.check descriptor name (object<-alist [(cons name value)]))
    (error "declared slot value rejected" name))
  value)
;; Resolve and validate against one source revision. User checks may edit shared\n;; metadata; refuse their stale success without rolling back their own effects.
;; Only raw values are cached: earlier successful admission is never reused.
(def (read-slot self name)
  (def revision (object-revision self))
  (def descriptor (public-slot self name))
  (def value (validate-slot-value descriptor name (.ref self name)))
  (require-declaration-revision self revision)
  value)
;; Validate a proposed value before mutating source. Invalid input neither
;; advances a revision nor clears caches; whole-class constraints are separate.
(def (write-slot! self name value)
  (def revision (object-revision self))
  (validate-slot-value (public-slot self name) name value)
  (require-declaration-revision self revision)
  (.putslot! self name ($constant-slot-spec value)))
