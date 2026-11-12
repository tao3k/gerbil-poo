;;; Read provenance and metadata routes; no receiver getters or user callbacks.
(export require-read-route! make-read-issuer symbolic-write-route-current? gc-table-route-current?
        %issued-read? %read-issuance)
(import (only-in ./slot-layout slot-value-storage make-slot-values) :std/error ./slot-observation
  (prefix-in (only-in :gerbil/runtime/mop object? object-class make-class-slot-accessor
                      class-slot-offset slot-ref slot-set!) read-runtime.)
  (only-in :gerbil/runtime/table &raw-table-hash &raw-table-test &raw-table-lock
           symbolic-table-set! symbolic-hash gc-table-ref gc-table-set!)
  (only-in :gerbil/runtime/hash HashTable::interface gc-hash-table::t)
  (only-in :gerbil/runtime/interface &interface-descriptor-type))

;; Private admission for a single callback-free replay sweep. An identity
;; HashTable conversion cannot reify another interface or invoke author code.
;; Unsupported descriptors retain the original per-record protocol. The
;; receiver route itself still has to pass require-read-route! on first use.
;; As with the existing route guard, this is a serial supported-runtime law,
;; not protection against concurrent raw writes to runtime implementation data.
(def %pure-read-sweep?
  (let (wrapper (read-runtime.object-class (make-hash-table)))
    (lambda () (eq? wrapper (&interface-descriptor-type HashTable::interface)))))

;; These are the final record owner's generated physical-field operations,
;; not the public copying inspectors or a new lookup through mutable class
;; display metadata. Every issuer captures the SAME declared field meanings.
(extern
  (record-key-field clan/poo/slot-observation#slot-read-key)
  (record-value-field clan/poo/slot-observation#slot-read-value)
  (record-current-field clan/poo/slot-observation#slot-read-current?)
  (record-dependencies-field clan/poo/slot-observation#slot-read-dependencies)
  (record-birth-field clan/poo/slot-observation#slot-read-birth)
  (record-birth-set! clan/poo/slot-observation#slot-read-birth-set!))

;; A method installation interval may omit repeated protocol selection only
;; when its actual writes cannot dispatch an author effect. Inspect the selected
;; wrapper fields without invoking them; changed routes use the ordinary loop.
;; Rehash also uses the backend hash/test, so checking set! alone is insufficient.
(def symbolic-write-route-current?
  (let* ((sample (make-hash-table-symbolic))
         (wrapper (read-runtime.object-class sample))
         (object-field (read-runtime.make-class-slot-accessor wrapper 'object))
         (set-field (read-runtime.make-class-slot-accessor wrapper 'set!))
         (object-offset (read-runtime.class-slot-offset wrapper 'object))
         (set-offset (read-runtime.class-slot-offset wrapper 'set!))
         (backend-class (read-runtime.object-class (object-field sample))))
    (lambda (table)
      (and (read-runtime.object? table)
           (eq? (read-runtime.object-class table) wrapper)
           ;; A shared class can keep its identity while its field map moves.
           (eqv? (read-runtime.class-slot-offset wrapper 'object) object-offset)
           (eqv? (read-runtime.class-slot-offset wrapper 'set!) set-offset)
           (eq? (set-field table) symbolic-table-set!)
           (let (backend (object-field table))
             (and (read-runtime.object? backend)
                  (eq? (read-runtime.object-class backend) backend-class)
                  (eq? (&raw-table-hash backend) symbolic-hash)
                  (eq? (&raw-table-test backend) eq?)
                  (not (&raw-table-lock backend))))))))

;; Callback-free identity-table operations for a private owned key domain.
;; This only checks the LIVE route. The owner must separately retain native
;; origin and retire it before any operation crosses an unknown route.
;; No sample table/adapter is constructed or warmed by this guard.
(def gc-table-route-current?
  (let* ((wrapper (&interface-descriptor-type HashTable::interface))
         (object-offset (read-runtime.class-slot-offset wrapper 'object))
         (ref-offset (read-runtime.class-slot-offset wrapper 'ref))
         (set-offset (read-runtime.class-slot-offset wrapper 'set!))
         (object-field (read-runtime.make-class-slot-accessor wrapper 'object))
         (ref-field (read-runtime.make-class-slot-accessor wrapper 'ref))
         (set-field (read-runtime.make-class-slot-accessor wrapper 'set!)))
    (lambda (table)
      (and (eq? wrapper (&interface-descriptor-type HashTable::interface))
           (read-runtime.object? table)
           (eq? (read-runtime.object-class table) wrapper)
           (eqv? (read-runtime.class-slot-offset wrapper 'object) object-offset)
           (eqv? (read-runtime.class-slot-offset wrapper 'ref) ref-offset)
           (eqv? (read-runtime.class-slot-offset wrapper 'set!) set-offset)
           (eq? (ref-field table) gc-table-ref)
           (eq? (set-field table) gc-table-set!)
           (let (backend (object-field table))
             (and (read-runtime.object? backend)
                  (eq? (read-runtime.object-class backend) gc-hash-table::t)))))))

;; Validate the actual selected metadata route, without calling its methods.
;; This is a serial supported-runtime guard, not a sandbox against raw FFI writes.
(defstruct route (wrapper ref backend hash test object-field ref-field object-offset ref-offset) final: #t)
;; Pin only class/method identities, never a receiver, value or validation result.
(defstruct value-route (ref backend shape missing cells-field missing-field shape-field indices-field) final: #t)
(def require-read-route!
  (let ()
    ;; Pin the standard wrapper, primitive lookup and hash/test identities once.
    (def (capture table)
      (def wrapper (read-runtime.object-class table))
      (def object-field (read-runtime.make-class-slot-accessor wrapper 'object))
      (def ref-field (read-runtime.make-class-slot-accessor wrapper 'ref))
      (def backend (object-field table))
      (make-route wrapper (ref-field table) (read-runtime.object-class backend)
        (&raw-table-hash backend) (&raw-table-test backend) object-field ref-field
        (read-runtime.class-slot-offset wrapper 'object)
        (read-runtime.class-slot-offset wrapper 'ref)))
    (def reads-route (capture (make-hash-table)))
    (def instance-route (capture (make-hash-table-symbolic)))
    (def vector-route
      (parameterize ((slot-value-storage 'vector))
        (let* ((table (make-slot-values [] #f [] absent-value))
               (backend (read-runtime.slot-ref table 'object))
               (shape (read-runtime.slot-ref backend 'shape))
               (backend-class (read-runtime.object-class backend))
               (shape-class (read-runtime.object-class shape)))
          (make-value-route (read-runtime.slot-ref table 'ref) backend-class shape-class
            (read-runtime.slot-ref backend 'missing)
            (read-runtime.make-class-slot-accessor backend-class 'cells)
            (read-runtime.make-class-slot-accessor backend-class 'missing)
            (read-runtime.make-class-slot-accessor backend-class 'shape)
            (read-runtime.make-class-slot-accessor shape-class 'indices)))))
    ;; Refuse changed metadata without dispatching its mutable public methods.
    (def (check-wrapper table expected)
      (unless (eq? (read-runtime.object-class table) (route-wrapper expected))
        (error "foreign metadata wrapper"))
      ;; Class identity alone does not freeze Gerbil's mutable field map.
      ;; Authenticate the live layout before invoking a pinned field accessor.
      (unless (= (read-runtime.class-slot-offset (route-wrapper expected) 'object)
                 (route-object-offset expected))
        (error "changed metadata object layout")))
    (def (check-ref table expected ref)
      (unless (= (read-runtime.class-slot-offset (route-wrapper expected) 'ref)
                 (route-ref-offset expected))
        (error "changed metadata ref"))
      (unless (eq? ((route-ref-field expected) table) ref)
        (error "changed metadata ref")))
    (def (check-backend backend expected)
      (unless (eq? (read-runtime.object-class backend) (route-backend expected))
        (error "foreign metadata backend"))
      (unless (and (eq? (&raw-table-hash backend) (route-hash expected))
                   (eq? (&raw-table-test backend) (route-test expected))
                   (not (&raw-table-lock backend)))
        (error "changed metadata hash/test")))
    (def (check table expected)
      (check-wrapper table expected)
      (check-ref table expected (route-ref expected))
      (check-backend ((route-object-field expected) table) expected))
    ;; Authenticate the vector route before any HashTable/index method can run.
    ;; Index metadata uses the same pinned standard symbolic hash/test implementation.
    (def (check-instance table)
      (check-wrapper table instance-route)
      (let (backend ((route-object-field instance-route) table))
        (if (eq? (read-runtime.object-class backend) (value-route-backend vector-route))
          (begin
            (check-ref table instance-route (value-route-ref vector-route))
            (unless (and (vector? ((value-route-cells-field vector-route) backend))
                         (eq? ((value-route-missing-field vector-route) backend)
                              (value-route-missing vector-route)))
              (error "changed value cells"))
            (let (shape ((value-route-shape-field vector-route) backend))
              (unless (eq? (read-runtime.object-class shape) (value-route-shape vector-route))
                (error "foreign vector shape"))
              (check ((value-route-indices-field vector-route) shape) instance-route)))
          (begin
            (check-ref table instance-route (route-ref instance-route))
            (check-backend backend instance-route)))))
    (lambda (key reads instance)
      (unless (or (symbol? key)
                  (and (pair? key)
                    (case (car key)
                      ((preparation names) (null? (cdr key)))
                      ((bootstrap cache-miss presence)
                       (and (pair? (cdr key)) (symbol? (cadr key)) (null? (cddr key))))
                      (else #f))))
        (error "unsupported metadata key"))
      (unless (and (pair? key) (eq? (car key) 'bootstrap))
        (when reads (check reads reads-route))
        (when instance (check-instance instance))))))


;; One authority owns the original weak table and authenticated birth closures.
;; The issuer owns canonical names separately from the producer's cache and
;; public record. Another factory's records cannot authenticate here.
(def (make-read-issuer)
  (let ()
    ;; Both sides are weak: the registry is not a root for records, receivers or
    ;; birth closures. A live record itself keeps its original closure alive.
    (def issued (make-table test: eq? weak-keys: #t weak-values: #t))
    (def record-class
      (read-runtime.object-class (make-slot-read #f #f 0 #f #f '() values)))
    ;; The exact final record class is admitted before any of these accessors.
    ;; Each invocation reads live fields rather than retaining a verdict.
    (def read-key record-key-field)
    (def read-value record-value-field)
    (def read-current? record-current-field)
    (def read-dependencies record-dependencies-field)
    (def read-birth record-birth-field)
    (def write-birth! record-birth-set!)
    ;; Recurse over the private finite sequence: a cyclic or improper presented
    ;; spine cannot extend the comparison past the saved sequence's length.
    (def (same-list? current saved)
      (if (null? saved) (null? current)
        (and (pair? current) (eq? (car current) (car saved))
             (same-list? (cdr current) (cdr saved)))))
    ;; A single non-vector identity needs no separate private vector. The
    ;; dense fallback also handles unusual vector-valued parents without an
    ;; ambiguous tag. Public spines, repeated occurrences and delivery stay
    ;; unchanged; neither representation caches an authentication result.
    (def (same-dependencies? current saved)
      (if (vector? saved)
        (let loop ((current current) (index 0))
          (if (= index (##vector-length saved)) (null? current)
            (and (pair? current) (eq? (car current) (##vector-ref saved index))
                 (loop (cdr current) (1+ index)))))
        (and (pair? current) (eq? (car current) saved) (null? (cdr current)))))
    ;; Receiver state is captured by the caller; ordinary payload identities stay
    ;; unchanged. The receiver owns the index key; the record owns a separate
    ;; structural key spine so even a raw edit cannot damage hash placement.
    (def (issue self key revision instance value parents checker)
      ;; The producer's name spine is reachable through its ordinary runtime
      ;; metadata. Freeze it before creating the separate exposed presentation.
      (def names (and (equal? key '(names)) value (map values value)))
      (def shown (if names (map values names) value))
      (def record-key (if (pair? key) (list-copy key) key))
      (def parent-copy
        (cond ((null? parents) '#())
              ((and (null? (cdr parents)) (not (vector? (car parents)))) (car parents))
              (else (list->vector parents))))
      (def read (make-slot-read self record-key revision instance shown parents checker))
      ;; Captured payload is not a public struct whose fields can be rewritten
      ;; through runtime.slot-set!. The registry authenticates this procedure
      ;; before it is invoked, so replacing birth with a true-returning closure
      ;; does not turn another arbitrary callback into a trusted checker.
      (def base-birth
        (let (value shown)
          ;; RTD-checked records are truthy. False is the private copy request;
          ;; the public inspector still obtains ONLY the registered procedure.
          ;; A fixed lane captures this payload once, rather than retaining two
          ;; payload closures and a rest-argument case-lambda dispatcher per read.
          (lambda (candidate)
            ;; Copy primitive metadata; do not dispatch a mutable class constructor.
            (if (not candidate)
                (values read
                  (vector self (if (pair? key) (list-copy key) key) revision instance
                    (if names (list-copy names) value)
                    (if (vector? parent-copy) (vector->list parent-copy) (list parent-copy)) checker)
                  (and (pair? key) (list-copy key)))
            (and (eq? candidate read)
                 (eq? (slot-read-receiver read) self)
                 (eq? (read-key read) record-key)
                 (or (not (pair? key)) (same-list? record-key key))
                 (= (slot-read-revision read) revision)
                 (eq? (slot-read-instance read) instance)
                 (eq? (read-value read) value)
                 (eq? (read-current? read) checker)
                 (same-dependencies? (read-dependencies read) parent-copy))))))
      ;; Ordinary values use the original predicate alone. A names record alone
      ;; adds a guard comparing its exposed spine to the private canonical names.
      (def birth
        (if names
          (lambda (candidate)
            (if (not candidate) (base-birth #f)
              (and (base-birth candidate) (same-list? (read-value candidate) names))))
          base-birth))
      (write-birth! read birth)
      (table-set! issued read birth)
      read)
    ;; Authenticate class and registered procedure identity BEFORE invoking it.
    (def (issued? read)
      (and (eq? (read-runtime.object-class read) record-class)
        (let (birth (read-birth read))
          (and (procedure? birth) (eq? birth (table-ref issued read #f)) (birth read)))))
    ;; Inspect the actual private association, not a caller's alleged birth.
    ;; Only the registered closure is invoked, and only in copy mode.
    (def (inspect read)
      (unless (eq? (read-runtime.object-class read) record-class)
        (error "foreign slot-read type"))
      (def presented (read-birth read))
      (def original (table-ref issued read #f))
      (if original
        (let-values (((signed snapshot shape) (original #f)))
          (values presented original signed snapshot shape))
        (values presented #f #f #f #f)))
    (values issue issued? inspect)))

;; The existing live authority belongs below object preparation, so structural
;; source views can authenticate the same evidence without importing object.ss.
;; Keep its writer private. This replaces the former object-local allocation;
;; it does not add another registry. Foreign make-read-issuer factories still
;; cannot authenticate this authority's records, or vice versa.
(defvalues (%issue-read %issued-read? %read-issuance) (make-read-issuer))

