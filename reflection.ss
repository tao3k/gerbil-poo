;;; Declaration and reflection reuse the existing Slot / Class metadata protocol.
(export object<-declarations make-declared-instance reflect-slots read-slot write-slot!)
(import :std/iter (only-in :std/list/list delete-duplicates/hash foldr)
        ./object ./mop (only-in ./type element? validate))
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
;; Reflect effective metadata without demanding slot VALUES. Most-specific declared
;; metadata wins; undeclared slots are not silently given a public declaration.
;; The explicit full view is for trusted inspection, not a capability boundary.
(def (reflect-slots self include-hidden?: (include-hidden? #f))
  (instantiate-object! self)
  (def seen (make-hash-table-symbolic))
  (foldr (lambda (entry rest)
    (def descriptor (cdr entry))
    (if (or include-hidden? (not (.@ descriptor hidden))) (cons entry rest) rest)) []
    (filter (lambda (entry)
      (if (hash-key? seen (car entry)) #f
        (begin (hash-put! seen (car entry) #t) #t)))
      (apply append (map object-%declarations (object-%precedence-list self))))))
;; Resolve a PUBLIC declaration before reading or writing. Raw .ref is a trusted
;; low-level operation and is not claimed to enforce access control by itself.
(def (public-slot self name)
  (or (assq name (reflect-slots self)) (error "slot is hidden or undeclared" name)))
;; Read through the declared public surface, preserving ordinary lazy slot behavior.
(def (read-slot self name)
  (public-slot self name) (.ref self name))
;; Validate a proposed value using the existing Slot checker before mutating source.
;; An invalid value neither advances the source revision nor clears dependent caches.
(def (write-slot! self name value)
  (def descriptor (cdr (public-slot self name)))
  (unless (.call (.@ descriptor .type) .slot.check descriptor name (object<-alist [(cons name value)]))
    (error "declared slot value rejected" name))
  (.putslot! self name ($constant-slot-spec value)))
