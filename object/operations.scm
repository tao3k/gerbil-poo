;; : (Object A) <- (IndexedList ? ((Pair s (A s)) <- s:Symbol)) \
;;     supers: ? (ConsTreeOf (Object ?)) defaults: ? (Table ? Symbol)
(def (object<-alist a supers: (supers '()) defaults: (defaults '()))
  (make-object slots: (for/collect (([k . v] a)) (cons k ($constant-slot-spec v)))
               supers: supers defaults: defaults))

(def (object<-hash h supers: (supers '()) defaults: (defaults '()))
  (object<-alist (hash->list/sort h symbol<?) supers: supers defaults: defaults))

(extern namespace: clan/poo/prototype-map %stock-struct-construction? %bulk-generated-prototype-map)
(def (object<-fun f keys: (keys '()) supers: (supers '()) defaults: (defaults '()))
  (def rows (map (lambda (key) (cons key ($thunk-slot-spec (cut f key)))) keys))
  ;; Custom constructors still receive the original generated list.
  (def slots
    (or (and (pair? rows) (null? supers) (null? defaults)
             (%stock-struct-construction? object::t 15 object:::init!)
             (%bulk-generated-prototype-map rows))
        rows))
  (make-object slots: slots
               supers: supers defaults: defaults))

(def (.mix slots: (slots '()) defaults: (defaults '()) . supers)
  (make-object supers: supers slots: slots defaults: defaults))
(def (.extend self defaults: (defaults '()) . slots)
  (make-object slots: slots supers: [self] defaults: defaults))
;; Merge direct specifications together with their direct protocol/declarations.
;; Declaration compilation registers copied metadata sources before any cache exists.
;; Immutable direct maps retain their policy and sharing; receiver caches and
;; explicit instance assignments are never inherited from the override object.
(def (.+ base override)
  (make-object slots: (object-%slots override)
               supers: [(object-%supers override)... base] defaults: (object-%defaults override)
               protocol: (object-%protocol override) declarations: (object-%declarations override)))

;; Structural presence admits its Symbol before bootstrap, observation or MOP
;; preparation, just like ordinary reads. Absence is a successful false result.
(def (.slot? self (slot :~ symbol?))
  (if (bootstrap-anchor self slot)
    (begin (object-read-bootstrap self slot (bootstrap-anchor self slot)) #t)
    (object-read-query self (list 'presence slot)
      (cut object-slot-present? self slot) presence: slot)))

(extern namespace: clan/poo/read-route %standard-symbol-table-lookup?)

;; A positive prepared lookup calls neither a getter nor a reflection hook.
;; The caller owns key admission, observation and any fallback on a miss.
(def (%prepared-slot-present? self slot)
  (and (object? self)
       (object-%instance self)
       (not (object-%bootstrap self))
       (let (table (object-%slot-funs self))
         (and table (%standard-symbol-table-lookup? table) (hash-key? table slot)))))
;; Private query continuation: its public owner already admitted the name.
;; Recheck bootstrap after observer prechecks, which may edit the protocol.
;; Reflection hooks are direct declarations on the selected protocol. A
;; reflective probe on that protocol could enter its own metalevel hooks.
(def (object-slot-present? self slot)
  (if (bootstrap-anchor self slot) #t
    (begin
      (instantiate-object! self)
      (or (hash-key? (object-%slot-funs self) slot)
          (let (protocol (object-protocol self))
            (and protocol (prototype-map-ref (object-%slots protocol) 'fallback-slot-present?)
                 (.call protocol fallback-slot-present? self slot)))))))

(defrules .has? ()
  ((_ x) #t)
  ((_ x slot) (.slot? x 'slot))
  ((_ x slot1 slot2 slot3 ...) (and (.has? x slot1) (.has? x slot2 slot3 ...))))

;; Public structural reflection owns its finite list spine. Symbols are shared;
;; callers can edit their result without changing the cached directory or shapes.
(def (.all-slots self)
  (map values (object-slot-names self)))
;; Private borrowed directory for enumerators that never expose its spine. The
;; same query still delivers the original preparation/observation dependencies.
(def (object-slot-names self)
  (object-read-query self '(names) (lambda ()
    (instantiate-object! self)
    (def names
      (or (object-%all-slots self)
        (let (esl (merge-super-slots
                 (map (lambda (super) (append (prototype-map-keys (object-%slots super))
                   (prototype-map-keys (object-%defaults super)) (prototype-map-keys (object-%declarations super))))
                      (object-%precedence-list self))))
        (def defined (filter (lambda (slot) (hash-key? (object-%slot-funs self) slot)) esl))
        (set! (object-%all-slots self) defined)
          defined)))
    (def protocol (object-protocol self))
    (if (and protocol (prototype-map-ref (object-%slots protocol) 'fallback-slot-names))
      (.call protocol fallback-slot-names self names)
      names))))

;; : Unit <- (Object A) (Fun _ <- s:Symbol (A s))
(def (.for-each! self fun)
  (for-each (lambda (slot) (fun slot (.ref self slot))) (object-slot-names self)))

;; : (Listof Symbol) <- (Object _)
(def (.all-slots/sort object) (list-sort symbol<? (.all-slots object)))

;; : (Listof (Pair s:Symbol (A s))) <- (Object A)
(def (.alist self)
  (map (λ (slot) (cons slot (.ref self slot))) (object-slot-names self)))

;; : (Listof (Pair s:Symbol (A s))) <- (Object A)
(def (.alist/sort self)
  (map (λ (slot) (cons slot (.ref self slot))) (.all-slots/sort self)))

;; Force the lazy computation of all slots in an object
;; : (Object A) <- (Object A)
(def (force-object self) (for-each (cut .ref self <>) (object-slot-names self)) self)

;; : (Table (A s) <- s:Symbol) <- (Object A)
(def (hash<-object self)
  (object-instance (force-object self)))

;; For (? test :: proc => pattern),
;;   test = (o?/slots ks)
;;   proc = (.refs/slots ks)
;; : Bool <- (Object _) <- (Listof Symbol)
(def ((o?/slots slots) o) (and (object? o) (andmap (cut .slot? o <>) slots)))
;; : (IndexedList ss A) <- (Object A) <- ss:(Listof Symbol)
(def ((.refs/slots slots) o) (map (cut .ref o <>) slots))
