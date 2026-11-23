;; Install a direct specification; all retained descendants lose derived caches.
;; : Unit <- (Object A) s:Symbol (SlotSpec A s)
(def (.putslot! self slot slot-spec)
  (def next (prototype-map-put (object-%slots self) slot slot-spec))
  (before-object-edit! self)
  (set! (object-%slots self) next))
;; Change a default persistently through the same descendant invalidation protocol.
(def (.putdefault! self slot default)
  (def next (prototype-map-put (object-%defaults self) slot default))
  (before-object-edit! self)
  (set! (object-%defaults self) next))
;; Remove every direct method contribution; inherited methods/defaults can reappear.
(def (.removeslot! self slot)
  (def next (prototype-map-remove (object-%slots self) slot))
  (before-object-edit! self)
  (set! (object-%slots self) next))
;; Remove a direct fallback without removing inherited or explicit instance values.
(def (.removedefault! self slot)
  (def next (prototype-map-remove (object-%defaults self) slot))
  (before-object-edit! self)
  (set! (object-%defaults self) next))

(defrules .setslot! () ((_ object. slot slot-spec) (.putslot! object. 'slot slot-spec)))

(defrules .def! ()
  ((_ object slot (:: self _ slots ...) slotspec ...)
   (.putslot! object 'slot
              (object/slot-spec %with-direct-slots #f self
                                (slot slots ...) slot slotspec ...)))
  ((_ object slot (:: self) slotspec ...)
   (.def! object slot (:: self []) slotspec ...))
  ((_ object slot (slots ...) slotspec ...)
   (.def! object slot (:: self [] slots ...) slotspec ...)))

;; Admit the symbolic key before invalidation, then install an explicit value.
;; Bad keys retain all source/cache generations; argument evaluation is not undone.
;; Assumes the top-object-proto was used.
;; : Unit <- (Object A) s:Symbol (A s)
(defrule (put-object-slot! self slot value edited-slot)
  (using (slot :~ symbol?)
    (set! value (own-assigned-slot-value self slot value))
    (before-object-edit! self edited-slot)
    (unless (object-%overrides self)
      (set! (object-%overrides self) (make-hash-table test: eq? hash: symbolic-hash seed: (%graph-table-seed))))
    (hash-put! (object-%overrides self) slot value)
    (hash-put! (%live-object-instance self) slot value)))

(def (.put! self slot value) (put-object-slot! self slot value #f))
(def (%put-assigned-slot! self slot value) (put-object-slot! self slot value slot))

;; Protect the selected receivers while checking an edit that may run hooks.
(def (%with-slot-edit-protection owners action)
  (def protected (make-hash-table-eq))
  (for-each (lambda (owner) (hash-put! protected owner #t)) owners)
  (parameterize ((active-read-replays (cons protected (active-read-replays))))
    (action)))

;; Each row is (receiver . ((slot . value) ...)), with distinct receivers.
;; Prepare replacement overrides and check the entire invalidation closure
;; before advancing any revision. Reconstruct value stores on demand.
(def (%publish-slot-edits! edits (scope-direct-assignments? #f))
  (def replacements
    (%with-slot-edit-protection (map car edits)
      (lambda ()
        (map-in-order
          (lambda (edit)
            (def owner (car edit))
            (def old (object-%overrides owner))
            (def overrides (if old (hash-copy old) (make-hash-table-symbolic)))
            (for-each (lambda (entry) (hash-put! overrides (car entry) (cdr entry)))
                      (cdr edit))
            (cons owner overrides))
          edits))))
  (def roots
    (map (lambda (edit)
           (def owner (car edit))
           (def state (object-%state owner))
           (when (object-state-sealed? state) (error "sealed prototype"))
           (cons owner state))
         replacements))
  (def edited-slot
    (and scope-direct-assignments?
         (let (single-slots (make-hash-table-eq))
           (for-each
             (lambda (edit)
               (when (and (pair? (cdr edit)) (null? (cddr edit)))
                 (hash-put! single-slots (car edit) (caadr edit))))
             edits)
           (lambda (owner) (hash-get single-slots owner)))))
  (def invalidate!
    (prepare-invalidation roots check-object-edit clear-object-cache! edited-slot))
  (invalidate!)
  (for-each (lambda (entry) (set! (object-%overrides (car entry)) (cdr entry)))
            replacements))

(defrules .set! () ((_ object. slot value) (.put! object. 'slot value)))

;; carbon copy / clone c...
;; : (Object A') <- (Object A) <<TODO: type for overrides from A to A' ...>>
(def (.cc self . overrides)
  (def added-hash (make-hash-table test: eq? hash: symbolic-hash seed: (%graph-table-seed)))
  (def added
    (with-list-builder (c)
      (def (add-slot! slot value)
        (when (hash-key? added-hash slot) (error "Cannot override slot twice" self slot))
        (hash-put! added-hash slot ($constant-slot-spec value))
        (c slot))
      (let loop ((l overrides))
        (match l
          ([] (void))
          ([(? symbol? s) v . r] (add-slot! s v) (loop r))
          ([(? keyword? k) v . r] (add-slot! (make-symbol k) v) (loop r))
          (else (error "invalid object overrides" overrides))))))
  ;; Persistent path copies preserve direct contribution order and share all
  ;; unaffected tree branches. No evaluated receiver or cache is inherited.
  (def slots (foldl (lambda (slot source)
    (prototype-map-put source slot (hash-ref added-hash slot))) (object-%slots self) added))
  ;; Clone direct metadata with direct formulas; .cc does not inherit SELF.
  (make-object slots: slots supers: (object-%supers self) defaults: (object-%defaults self)
               protocol: (object-%protocol self) declarations: (object-%declarations self)))

;; Persistent direct overrides now copy balanced-tree paths; allocation and end-to-end
;; workflow performance still require measurement before selecting a faster policy.
;; TODO: maybe have explicitly distinct variants of stateful vs pure object?
;; Could one convert from the other, with some freezing and thawing or copying operations?
;; When overriding a field, should we invalidate all the cached values for all fields?
;; Should we keep an indefinitely growing list of the super formulas?
;; Should we maintain flags as to which formulas do or don't use the super and/or self references,
;; so we know what to invalidate or not?

;; TODO: For type validation,
;; 1. cache which types an instance was tested to be part of,
;; which allows for fast checking of types for recursive data structures,
;; maybe even with cycles.
;; 2. have a mechanism to extend the above to non-instances.
