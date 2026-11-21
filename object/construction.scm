;; Instantiate atomically with respect to Gerbil exceptions. Mutating callbacks and
;; concurrent reads/writes are outside the sequential protocol, and are rejected
;; for actively evaluated receivers rather than returning a partially built value.
(defrule (instantiate-with-preparation! self (result dependencies) prepare finish)
  (begin
    (unless (object? self) (error "Not an object"))
    (unless (object-%instance self)
      (when (memq self (active-object-constructions)) (error "recursive object construction"))
      (parameterize ((active-object-constructions (cons self (active-object-constructions))))
        (try
          (defvalues (result dependencies)
            (%call-with-recorded-slot-reads
              (lambda ()
                (compute-object-precedence! self)
                prepare)))
          finish
          (catch (cause) (clear-object-cache! self) (raise cause)))))))

(defrule (prepare-slot-values self previous)
  (make-slot-values (hash-keys (object-%slot-funs self)) (object-%overrides self)
    (if (eq? (object-%protocol self) self) (or (object-%bootstrap self) []) [])
    absent-value previous: previous state: (object-%state self)))

(defrule (publish-preparation! self instance dependencies)
  (begin
    (set! (object-%instance self) instance)
    (hash-put! (object-read-table self) '(preparation)
      (object-record-read self '(preparation) instance dependencies))))

(def (instantiate-object! self previous: (previous #f))
  (instantiate-with-preparation! self (instance dependencies)
    (begin
      (compute-slot-funs! self)
      (prepare-slot-values self previous))
    (publish-preparation! self instance dependencies)))

;; Only first demand carries a compiled method across instance preparation.
;; An ordinary HashTable result needs no pair or extra recording state.
(def (instantiate-for-demand! self previous requested)
  (instantiate-with-preparation! self (prepared dependencies)
    (let* ((constant (compile-slot-funs-for-demand! self requested))
           (instance (prepare-slot-values self previous)))
      (if constant (cons instance constant) instance))
    (let (instance (if (pair? prepared) (car prepared) prepared))
      (publish-preparation! self instance dependencies)
      (and (pair? prepared) (cdr prepared)))))

(defclass (InvalidObject Exception) (slots) transparent: #t)
(def (invalid-object-summary self)
  (InvalidObject slots: (append (prototype-map-keys (object-%slots self))
    (prototype-map-keys (object-%defaults self)) (prototype-map-keys (object-%declarations self)))))

;; A hook can see its candidate order internally before it has been admitted.
;; Readiness is conservative during construction and never invokes a hook.
(def (object-precedence-ready? self)
  (and (object? self) (object-%precedence-list self)
       (not (memq self (active-object-constructions)))))

;; Visit an admitted order without exposing the cached list. The selector
;; sees one prototype at a time, and its first true result ends the search.
(def (object-find-in-precedence self select)
  (and (object-precedence-ready? self)
       (ormap select (object-%precedence-list self))))

;; Public inspection owns its spine; mutating it cannot edit cached C3 membership.
;; Internal construction borrows the private result without per-call snapshot copies.
(def (compute-precedence-list! self (heads '()))
  (list-copy (compute-object-precedence! self heads)))
(extern namespace: clan/poo/read-route %gc-scratch-routes-current?)
;; Delegate ordering to core C4. Hook continuations receive independent snapshots;
;; compare against the private canonical order and retain only that canonical order.
;; Hook errors and changed/improper orders clear the candidate cache before escape.
(def (compute-object-precedence! self (heads '()))
  ;; Default warm queries need neither traversal state nor a second admission.
  ;; Explicit diagnostic heads retain their original preparation and error order.
  (or (and (null? heads) (object-%precedence-list self))
      ;; C4 returns the head itself when there are no parents. Skip the
      ;; temporary active set only when none of its delegates can call out.
      (and (null? heads) (null? (object-%supers self)) (not (object-%protocol self))
           (%gc-scratch-routes-current?)
           (let (order (list self))
             (set! (object-%precedence-list self) order)
             order))
      (let ()
      (def active (make-hash-table-eq))
      (for-each (lambda (head) (hash-put! active head #t)) heads)
      (let compute ((object self) (heads heads))
        (cond
         ((object-%precedence-list object))
         ((hash-key? active object)
          (error "Circular precedence graph" (member object heads)))
         (else
          (hash-put! active object #t)
          (parameterize ((active-object-constructions (cons object (active-object-constructions))))
            (let (precedence-list
                (first-value
                 (c4-linearize*
                  [object] (list (object-%supers object)) suffix: (lambda (_) #f)
                  get-precedence-list:
                  (lambda (super) (compute super [object . heads]))
                  eq: eq?
                  get-name: invalid-object-summary)))
            (hash-remove! active object)
            (set! (object-%precedence-list object) precedence-list)
            (try
              (let (chosen (invoke-object-hook object 'compute-precedence-list (lambda () (list-copy precedence-list))))
                (unless (and (list? chosen) (= (length chosen) (length precedence-list))
                             (andmap eq? chosen precedence-list))
                  (error "inheritance hook must preserve checked C3 order"))
                precedence-list)
              (catch (cause) (clear-object-cache! object) (raise cause)))))))))))

;; Resolve/register each finite catalog before running ANY definition hook in C3.
;; The one-shot private action retains actual type identities, never a validation
;; verdict. Empty catalogs allocate neither scratch receivers nor pending actions.
(def (prepare-declaration-specifications self)
  (and (positive? (prototype-map-length (object-%declarations self)))
    (let (definitions (with-list-builder (add)
      (prototype-map-for-each (object-%declarations self)
        (lambda (name descriptor)
          (def type (.@ descriptor .type))
          (depend-on-object! self type)
          (add (lambda (scratch) (.call type .slot.define descriptor name scratch)))))))
      (lambda ()
        (let (scratch (make-object))
          (for-each (lambda (define-slot) (define-slot scratch)) definitions)
          (cons (object-%slots scratch) (object-%defaults scratch)))))))
(extern namespace: clan/poo/prototype-map specifications-entries)
(extern namespace: clan/poo/read-route %fixed-symbol-table-order?)

(def (plain-root-slot-entries self)
  (def precedence (object-%precedence-list self))
  (and (not (object-%protocol self))
       (pair? precedence) (eq? (car precedence) self) (null? (cdr precedence))
       (zero? (prototype-map-length (object-%defaults self)))
       (zero? (prototype-map-length (object-%declarations self)))
       (let (entries (specifications-entries (object-%slots self)))
         (and (vector? entries) (<= (vector-length entries) 4)
              (let loop ((index 0))
                (if (= index (vector-length entries)) entries
                  (let (spec (cdr (vector-ref entries index)))
                    (and (or ($constant-slot-spec? spec) ($self-slot-spec? spec))
                         (loop (1+ index))))))))))

(defrule (compile-slot-funs-with! self (table entries) compile-direct)
  ;; support/base.ss binds the private graph seed. Ordinary preparation uses
  ;; Gerbil's default random seed and retains the same symbolic table order.
  (let* ((table (make-hash-table test: eq? hash: symbolic-hash seed: (%graph-table-seed)))
         (entries (plain-root-slot-entries self))
         (result (if (and entries (%fixed-symbol-table-order? table (vector-length entries)))
                   compile-direct
                   (begin (assemble-slot-funs! self table) #f))))
    (set! (object-%slot-funs self) table)
    result))

(def (compute-slot-funs! self)
  (compile-slot-funs-with! self (table entries)
    (for (entry (in-vector entries))
      (hash-put! table (car entry) (apply-slot-spec self (cdr entry) #f))))
  (void))

(def (compile-slot-funs-for-demand! self requested)
  (compile-slot-funs-with! self (table entries)
    (for/fold (constant #f) (entry (in-vector entries))
      (let* ((name (car entry))
             (spec (cdr entry))
             (thunk (apply-slot-spec self spec #f)))
        (hash-put! table name thunk)
        (if (and (eq? name requested) ($constant-slot-spec? spec))
          thunk constant)))))

;; Capture the whole C3 family first, then define each source in its original order.
;; Incremental scratch visibility remains local to each catalog; nothing pending
;; escapes or survives a failed build. Direct specifications still override declarations.
(def (assemble-slot-funs! self h)
  (def prepared (map-in-order (lambda (super) (cons super (prepare-declaration-specifications super)))
                             (reverse (object-%precedence-list self))))
  (def sources (map-in-order (lambda (entry)
    (cons (car entry) (and (cdr entry) ((cdr entry))))) prepared))
  ;; The same consumers handle normalized declarations and persistent maps;
  ;; no private entry pair escapes and no direct-map snapshot is materialized.
  (def (default! slot value) (hash-put! h slot (list ($constant-slot-spec value))))
  ;; Keep original admission order and diagnostics even for shadowed input.
  (def (contribution! slot spec)
    (def discards? (slot-spec-discards-super? spec))
    (unless (or discards? ($computed-slot-spec? spec)) (apply-slot-spec self spec #f))
    (if discards? (hash-put! h slot (list spec))
      (hash-ensure-modify! h slot (lambda () []) (cut cons spec <>))))
  (for (([super . declarations] sources))
    (when declarations (prototype-map-for-each (cdr declarations) default!))
    (prototype-map-for-each (object-%defaults super) default!))
  (for (([super . declarations] sources))
    (when declarations (prototype-map-for-each (car declarations) contribution!))
    (prototype-map-for-each (object-%slots super) contribution!))
  ;; Compile every surviving chain BEFORE invoking any user hook. A hook cannot
  ;; change the payload capture time of another field's SlotSpec.
  (for (([slot . specs] (hash->list h)))
    (hash-put! h slot (compile-slot-specs self slot specs)))
  ;; A standard symbolic-table write cannot install a protocol between slots.
  ;; In that case one check for an inherited protocol suffices. A custom writer
  ;; or an installed protocol requires a fresh hook lookup on each iteration.
  (def entries (hash->list h))
  (def skip-hook-lookup? (and (pair? entries) (pair? (cdr entries)) (standard-symbol-table-writes? h)
                    (not (object-protocol self))))
  (for (([slot . standard] entries))
    ;; Pinned hook definitions are the terminating base of self-description.
    (def compiled (if (or skip-hook-lookup? (bootstrap-anchor self slot)) standard
      (invoke-object-hook self 'compute-slot (lambda () standard) slot)))
    (unless (procedure? compiled) (error "compute-slot must return a thunk" slot))
    (hash-put! h slot compiled)))

;; SUPER-SLOTS contains one ordered list of names per prototype, most specific
;; first. Visit the lists least specific first and keep the first occurrence
;; of each name. Effective slot values still follow prototype precedence.
(def (merge-super-slots super-slots)
  (delete-duplicates/hash (apply append (reverse super-slots))
    table: (make-hash-table test: eq? hash: symbolic-hash seed: (%graph-table-seed)) from-end?: #t))
