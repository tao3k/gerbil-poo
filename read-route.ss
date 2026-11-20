;;; Record which SlotRead objects POO created and what they contained.
;;; To replay a read of 'port, the object checks its saved record and cached
;;; value for 'port. This module checks the HashTable accessors first, so a
;;; replaced lookup method cannot run during that comparison.
(export require-read-route! make-read-issuer standard-symbol-table-writes? gc-table-route-current?
        %issued-read? %read-issuance)
(import (only-in ./slot-layout slot-value-storage make-slot-values) :std/error ./slot-observation
  (prefix-in (only-in :gerbil/runtime/mop object? object-class make-class-slot-accessor
                      class-slot-offset &class-type-slot-table slot-ref slot-set!) read-runtime.)
  (only-in :gerbil/runtime/table raw-table? &raw-table-table &raw-table-hash &raw-table-test &raw-table-lock &raw-table-seed
           &raw-table-free raw-table-for-each
           symbolic-table-ref symbolic-table-set! symbolic-hash gc-table-ref gc-table-set! gc-table-length)
  (only-in :gerbil/runtime/hash HashTable::interface gc-hash-table::t)
  (only-in :gerbil/runtime/interface &interface-descriptor-type interface-instance-object))

;; Share table checks within one replay pass when casting an existing
;; HashTable wrapper returns that wrapper. With a different descriptor, use
;; the per-record checker. Each receiver's tables still need their own checks.
(defvalues (%pure-read-sweep? %read-index-size-effect-free?)
  (let* ((wrapper (read-runtime.object-class (make-hash-table)))
         (length-offset (read-runtime.class-slot-offset wrapper 'length))
         (length-field (read-runtime.make-class-slot-accessor wrapper 'length)))
    (values
      (lambda () (eq? wrapper (&interface-descriptor-type HashTable::interface)))
      ;; The fixed gc-table-length delegate invokes no author code. Qualify
      ;; its live wrapper and field route BEFORE the interface operation.
      (lambda (table)
        (and (eq? wrapper (&interface-descriptor-type HashTable::interface))
             (read-runtime.object? table)
             (eq? (read-runtime.object-class table) wrapper)
             (eqv? (read-runtime.class-slot-offset wrapper 'length) length-offset)
             (eq? (length-field table) gc-table-length))))))

;; Use SlotRead's generated field accessors. Public inspectors copy some
;; fields, and reflective name lookup can be redirected by a class edit.
(extern
  (record-key-field clan/poo/slot-observation#slot-read-key)
  (record-instance-field clan/poo/slot-observation#slot-read-instance)
  (record-value-field clan/poo/slot-observation#slot-read-value)
  (record-current-field clan/poo/slot-observation#slot-read-current?)
  (record-dependencies-field clan/poo/slot-observation#slot-read-dependencies)
  (record-birth-field clan/poo/slot-observation#slot-read-birth)
  (record-birth-set! clan/poo/slot-observation#slot-read-birth-set!))
(extern namespace: clan/poo/slot-observation %slot-store-snapshot %owned-list-value)

;; Can hash-put! reach Gerbil's symbolic writer without an adapter or callback?
;; Rehashing also uses the backend's hash/test, so check those and its lock.
(def standard-symbol-table-writes?
  (let* ((sample (make-hash-table-symbolic))
         (wrapper (read-runtime.object-class sample))
         (object-field (read-runtime.make-class-slot-accessor wrapper 'object))
         (set-field (read-runtime.make-class-slot-accessor wrapper 'set!))
         (object-offset (read-runtime.class-slot-offset wrapper 'object))
         (set-offset (read-runtime.class-slot-offset wrapper 'set!))
         (backend-class (read-runtime.object-class (object-field sample))))
    (lambda (table)
      (and (eq? wrapper (&interface-descriptor-type HashTable::interface))
           (read-runtime.object? table)
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

;; Existing-key replacements can rehash before lookup. Leave enough free
;; space for every proposed insertion before relying on enumeration order.
(def %fixed-symbol-table-order?
  (let* ((wrapper (&interface-descriptor-type HashTable::interface))
         (offset (read-runtime.class-slot-offset wrapper 'for-each))
         (field (read-runtime.make-class-slot-accessor wrapper 'for-each)))
    (lambda (table insertions)
      (and (standard-symbol-table-writes? table)
           (eq? (&interface-descriptor-type HashTable::interface) wrapper)
           (eqv? (read-runtime.class-slot-offset wrapper 'for-each) offset)
           (eq? (field table) raw-table-for-each)
           (let* ((backend (interface-instance-object table))
                  (buckets (&raw-table-table backend))
                  (free (&raw-table-free backend)))
             (and (vector? buckets) (fixnum? free)
                  (>= (- free insertions) (quotient (vector-length buckets) 4))))))))

;; Callback-free identity-table operations for a private owned key domain.
;; This only checks the LIVE route. The owner must separately retain native
;; origin and retire it before any operation crosses an unknown route.
;; No sample table/adapter is constructed or warmed by this guard.
(def %gc-table-route-backend
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
                  (eq? (read-runtime.object-class backend) gc-hash-table::t)
                  backend))))))

(def (gc-table-route-current? table)
  (and (%gc-table-route-backend table) #t))

;; Expected wrapper class, offsets and methods for hash-ref.
(defstruct route (wrapper ref backend hash test object-field ref-field object-offset ref-offset) final: #t)
;; A vector store also needs the symbol-to-cell index and the missing sentinel.
(defstruct value-route (ref backend shape missing cells-field missing-field shape-field indices-field) final: #t)
;; KEY is the slot name or a structural query such as '(presence port).
;; READS maps keys to SlotRead records. INSTANCE holds cached slot values.
;; Either table may be #f. A bootstrap read checks its constant directly.
;; An owner recording fresh reads also qualifies the read table's writer.
;; Key-only replay checks need neither an absent table pair nor an optional
;; argument dispatcher.
(def (%require-read-key! key)
  (unless (or (symbol? key)
              (and (pair? key)
                   (case (car key)
                     ((preparation names) (null? (cdr key)))
                     ((bootstrap cache-miss presence)
                      (and (pair? (cdr key)) (symbol? (cadr key)) (null? (cddr key))))
                     (else #f))))
    (error "unsupported metadata key")))

(defvalues (%require-read-route! %standard-symbol-table-lookup? %admitted-vector-read-fields!
            %prepared-vector-value %prepared-vector-values)
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
    (def read-sample (make-hash-table))
    (def reads-route (capture read-sample))
    (def read-set-offset (read-runtime.class-slot-offset (route-wrapper reads-route) 'set!))
    (def read-set-field (read-runtime.make-class-slot-accessor (route-wrapper reads-route) 'set!))
    (def read-set (read-set-field read-sample))
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
    ;; Both strict replay and the optional probe check the same live routes.
    (def (wrapper-refusal table expected)
      (cond
       ((not (and (read-runtime.object? table)
                  (eq? (read-runtime.object-class table) (route-wrapper expected))))
        "foreign metadata wrapper")
       ((not (eq? (&interface-descriptor-type HashTable::interface) (route-wrapper expected)))
        "changed HashTable interface")
       ((not (and (raw-table? (read-runtime.&class-type-slot-table (route-wrapper expected)))
                  (eqv? (read-runtime.class-slot-offset (route-wrapper expected) 'object)
                        (route-object-offset expected))))
        "changed metadata object layout")
       (else #f)))
    (def (ref-refusal table expected ref)
      (and (not (and (eqv? (read-runtime.class-slot-offset (route-wrapper expected) 'ref)
                           (route-ref-offset expected))
                     (eq? ((route-ref-field expected) table) ref)))
           "changed metadata ref"))
    (def (backend-refusal backend expected)
      (cond
       ((not (and (read-runtime.object? backend)
                  (eq? (read-runtime.object-class backend) (route-backend expected))))
        "foreign metadata backend")
       ((not (and (vector? (&raw-table-table backend))
                  (eq? (&raw-table-hash backend) (route-hash expected))
                  (eq? (&raw-table-test backend) (route-test expected))
                  (not (&raw-table-lock backend))))
        "changed metadata hash/test")
       (else #f)))
    (def (table-refusal table expected)
      (or (wrapper-refusal table expected)
          (ref-refusal table expected (route-ref expected))
          (backend-refusal ((route-object-field expected) table) expected)))
    (def (check table expected)
      (let (refused (table-refusal table expected))
        (when refused (error refused))))

    (def (vector-backend? backend)
      (and (read-runtime.object? backend)
           (eq? (read-runtime.object-class backend) (value-route-backend vector-route))))
    (def (vector-refusal table backend)
      (or (ref-refusal table instance-route (value-route-ref vector-route))
          (and (not (and (vector? ((value-route-cells-field vector-route) backend))
                         (eq? ((value-route-missing-field vector-route) backend)
                              (value-route-missing vector-route))))
               "changed value cells")
          (let (shape ((value-route-shape-field vector-route) backend))
            (if (and (read-runtime.object? shape)
                     (eq? (read-runtime.object-class shape) (value-route-shape vector-route)))
              (table-refusal ((value-route-indices-field vector-route) shape) instance-route)
              "foreign vector shape"))))
    (def (check-instance table)
      (let (refused
            (or (wrapper-refusal table instance-route)
                (let (backend ((route-object-field instance-route) table))
                  (if (vector-backend? backend)
                    (vector-refusal table backend)
                    (or (ref-refusal table instance-route (route-ref instance-route))
                        (backend-refusal backend instance-route))))))
        (when refused (error refused))))
    (def (require-route! key reads instance write-reads?)
      (%require-read-key! key)
      (unless (and (pair? key) (eq? (car key) 'bootstrap))
        (when reads
          (check reads reads-route)
          (when write-reads?
            (unless (and (eqv? read-set-offset
                               (read-runtime.class-slot-offset (route-wrapper reads-route) 'set!))
                         (eq? (read-set-field reads) read-set))
              (error "changed metadata writer"))))
        (when instance (check-instance instance))))
    (def (standard-lookup? table)
      (and (eq? (read-runtime.object-class table) (route-wrapper instance-route))
           (eq? (&interface-descriptor-type HashTable::interface) (route-wrapper instance-route))
           (= (read-runtime.class-slot-offset (route-wrapper instance-route) 'object)
              (route-object-offset instance-route))
           (= (read-runtime.class-slot-offset (route-wrapper instance-route) 'ref)
              (route-ref-offset instance-route))
           (eq? ((route-ref-field instance-route) table) (route-ref instance-route))
           (let (backend ((route-object-field instance-route) table))
             (and (eq? (read-runtime.object-class backend) (route-backend instance-route))
                  (eq? (&raw-table-hash backend) (route-hash instance-route))
                  (eq? (&raw-table-test backend) (route-test instance-route))
                  (not (&raw-table-lock backend))))))
    ;; The caller has just admitted both tables with require-route!. Borrow
    ;; their native backends for this closed sweep only. Hash-backed receivers
    ;; keep their ordinary lookup, and nothing is retained past the sweep.
    (def (admitted-vector-read-fields! reads instance fields offset)
      (let (backend (and instance ((route-object-field instance-route) instance)))
        (and reads backend
             (eq? (read-runtime.object-class backend) (value-route-backend vector-route))
             (let* ((shape ((value-route-shape-field vector-route) backend))
                    (index ((value-route-indices-field vector-route) shape)))
               (##vector-set! fields (##fx+ offset 1) ((route-object-field instance-route) index))
               (##vector-set! fields (##fx+ offset 2) ((value-route-cells-field vector-route) backend))
               (##vector-set! fields (##fx+ offset 3) (value-route-missing vector-route))
               ((route-object-field reads-route) reads)))))
    ;; The optional probes never call a replacement HashTable lookup. Validate
    ;; the raw directories before using the symbolic primitive.
    (def (probe-directory? table)
      (and (raw-table? table)
           (fixnum? (&raw-table-seed table))
           (let (buckets (&raw-table-table table))
             (and (vector? buckets)
                  (let (length (vector-length buckets))
                    (and (>= length 2) (even? length)))))))
    (def (prepared-vector-backend table)
      (and (probe-directory? (read-runtime.&class-type-slot-table (route-wrapper instance-route)))
           (not (wrapper-refusal table instance-route))
           (let (backend ((route-object-field instance-route) table))
             (and (vector-backend? backend) (not (vector-refusal table backend)) backend))))
    (def (prepared-vector-index backend)
      (let* ((shape ((value-route-shape-field vector-route) backend))
             (directory ((value-route-indices-field vector-route) shape))
             (index ((route-object-field instance-route) directory)))
        (and (probe-directory? index) index)))
    (def (usable-offset? cells offset)
      (or (not offset) (and (fixnum? offset) (<= 0 offset) (< offset (vector-length cells)))))
    (def (prepared-cell-ref cells offset)
      (if offset
        (let (value (vector-ref cells offset))
          (if (eq? value (value-route-missing vector-route)) absent-value value))
        absent-value))
    (def (prepared-vector-value table slot)
      (let* ((backend (prepared-vector-backend table))
             (indices (and backend (prepared-vector-index backend))))
        (if indices
          (let ((cells ((value-route-cells-field vector-route) backend))
                (offset (symbolic-table-ref indices slot #f)))
            (if (usable-offset? cells offset) (prepared-cell-ref cells offset) absent-value))
          absent-value)))
    (def (prepared-vector-values table first second third)
      (def (absent) (values absent-value absent-value absent-value))
      (let* ((backend (prepared-vector-backend table))
             (indices (and backend (prepared-vector-index backend))))
        (if indices
          (let ((cells ((value-route-cells-field vector-route) backend))
                (one (symbolic-table-ref indices first #f))
                (two (symbolic-table-ref indices second #f))
                (three (symbolic-table-ref indices third #f)))
            (if (and (usable-offset? cells one) (usable-offset? cells two)
                     (usable-offset? cells three))
              (values (prepared-cell-ref cells one) (prepared-cell-ref cells two)
                      (prepared-cell-ref cells three))
              (absent)))
          (absent))))
    (values require-route! standard-lookup? admitted-vector-read-fields!
            prepared-vector-value prepared-vector-values)))

(def (require-read-route! key reads instance (write-reads? #f))
  (%require-read-route! key reads instance write-reads?))

;; Each issuer keeps a weak table of the records it created and their original
;; field checkers. Its structural keys are independent copies.
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
    ;; unchanged. The receiver owns the index key. The issuer and record
    ;; retain separate structural spines so neither can rewrite the signature.
    (def (issue self key revision instance value parents checker)
      ;; The producer's name spine is reachable through its ordinary runtime
      ;; metadata. Freeze it before creating the separate exposed presentation.
      (def names (and (equal? key '(names)) value (map values value)))
      (def shown (if names (map values names) value))
      (def signed-key (if (pair? key) (list-copy key) key))
      (def record-key (if (pair? signed-key) (list-copy signed-key) signed-key))
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
                  (vector self (if (pair? signed-key) (list-copy signed-key) signed-key) revision
                    (%slot-store-snapshot instance)
                    (cond (names (list-copy names))
                          ((equal? signed-key '(preparation)) (%slot-store-snapshot value))
                          (else (%owned-list-value value)))
                    (if (vector? parent-copy) (vector->list parent-copy) (list parent-copy)) checker)
                  (and (pair? signed-key) (list-copy signed-key)))
            (and (eq? candidate read)
                 (eq? (slot-read-receiver read) self)
                 (eq? (read-key read) record-key)
                 (or (not (pair? signed-key)) (same-list? record-key signed-key))
                 (= (slot-read-revision read) revision)
                 (eq? (record-instance-field read) instance)
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

