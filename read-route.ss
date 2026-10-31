;;; Read provenance and metadata routes; no receiver getters or user callbacks.
(export require-read-route! make-read-issuer)
(import (only-in ./slot-layout slot-value-storage make-slot-values) :std/error ./slot-observation (only-in :gerbil/runtime/hash HashTable)
  (prefix-in (only-in :gerbil/runtime/mop object-class slot-ref slot-set!) read-runtime.)
  (only-in :gerbil/runtime/table &raw-table-hash &raw-table-test &raw-table-lock))
;; Validate the actual selected metadata route, without calling its methods.
;; This is a serial supported-runtime guard, not a sandbox against raw FFI writes.
(defstruct route (wrapper ref backend hash test) final: #t)
;; Pin only class/method identities, never a receiver, value or validation result.
(defstruct value-route (ref backend shape missing) final: #t)
(def require-read-route!
  (let ()
    ;; Pin the standard wrapper, primitive lookup and hash/test identities once.
    (def (capture table)
      (def backend (read-runtime.slot-ref table 'object))
      (make-route (read-runtime.object-class table) (read-runtime.slot-ref table 'ref)
        (read-runtime.object-class backend) (&raw-table-hash backend) (&raw-table-test backend)))
    (def reads-route (capture (make-hash-table)))
    (def instance-route (capture (make-hash-table-symbolic)))
    (def vector-route
      (parameterize ((slot-value-storage 'vector))
        (let* ((table (make-slot-values [] #f [] absent-value))
               (backend (read-runtime.slot-ref table 'object))
               (shape (read-runtime.slot-ref backend 'shape)))
          (make-value-route (read-runtime.slot-ref table 'ref)
            (read-runtime.object-class backend) (read-runtime.object-class shape)
            (read-runtime.slot-ref backend 'missing)))))
    ;; Refuse changed metadata without dispatching its mutable public methods.
    (def (check table expected)
      (unless (eq? (read-runtime.object-class table) (route-wrapper expected))
        (error "foreign metadata wrapper"))
      (unless (eq? (read-runtime.slot-ref table 'ref) (route-ref expected))
        (error "changed metadata ref"))
      (let (backend (read-runtime.slot-ref table 'object))
        (unless (eq? (read-runtime.object-class backend) (route-backend expected))
          (error "foreign metadata backend"))
        (unless (and (eq? (&raw-table-hash backend) (route-hash expected))
                     (eq? (&raw-table-test backend) (route-test expected))
                     (not (&raw-table-lock backend)))
          (error "changed metadata hash/test"))))
    ;; Authenticate the vector route before any HashTable/index method can run.
    ;; Index metadata uses the same pinned standard symbolic hash/test implementation.
    (def (check-instance table)
      (unless (eq? (read-runtime.object-class table) (route-wrapper instance-route))
        (error "foreign metadata wrapper"))
      (let (backend (read-runtime.slot-ref table 'object))
        (if (eq? (read-runtime.object-class backend) (value-route-backend vector-route))
          (begin
            (unless (eq? (read-runtime.slot-ref table 'ref) (value-route-ref vector-route))
              (error "changed metadata ref"))
            (unless (and (vector? (read-runtime.slot-ref backend 'cells))
                         (eq? (read-runtime.slot-ref backend 'missing) (value-route-missing vector-route)))
              (error "changed value cells"))
            (let (shape (read-runtime.slot-ref backend 'shape))
              (unless (eq? (read-runtime.object-class shape) (value-route-shape vector-route))
                (error "foreign vector shape"))
              (check (read-runtime.slot-ref shape 'indices) instance-route)))
          (check table instance-route))))
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
;; Its caller owns finite private canonical names. Only issued copies are exposed;
;; another factory's records cannot be authenticated by this authority.
(def (make-read-issuer)
  (let ()
    ;; Both sides are weak: the registry is not a root for records, receivers or
    ;; birth closures. A live record itself keeps its original closure alive.
    (def issued (HashTable (make-table test: eq? weak-keys: #t weak-values: #t)))
    (def record-class
      (read-runtime.object-class (make-slot-read #f #f 0 #f #f '() values)))
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
    ;; unchanged. Only a structural names record owns a separate list spine.
    (def (issue self key revision instance value parents checker)
      (def names (and (equal? key '(names)) value))
      (def shown (if names (map values names) value))
      (def key-copy (and (pair? key) (map values key)))
      (def parent-copy
        (cond ((null? parents) '#())
              ((and (null? (cdr parents)) (not (vector? (car parents)))) (car parents))
              (else (list->vector parents))))
      (def read (make-slot-read self key revision instance shown parents checker))
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
                  (vector self key revision instance value
                    (if (vector? parent-copy) (vector->list parent-copy) (list parent-copy)) checker)
                  (and key-copy (map values key-copy)))
            (and (eq? candidate read)
                 (eq? (slot-read-receiver read) self)
                 (eq? (slot-read-key read) key)
                 (or (not key-copy) (same-list? key key-copy))
                 (= (slot-read-revision read) revision)
                 (eq? (slot-read-instance read) instance)
                 (eq? (slot-read-value read) value)
                 (eq? (read-runtime.slot-ref read 'current?) checker)
                 (same-dependencies? (slot-read-dependencies read) parent-copy))))))
      ;; Ordinary values use the original predicate alone. A names record alone
      ;; adds a guard comparing its exposed spine to the private canonical names.
      (def birth
        (if names
          (lambda (candidate)
            (if (not candidate) (base-birth #f)
              (and (base-birth candidate) (same-list? (slot-read-value candidate) names))))
          base-birth))
      (read-runtime.slot-set! read 'birth birth)
      (hash-put! issued read birth)
      read)
    ;; Authenticate class and registered procedure identity BEFORE invoking it.
    (def (issued? read)
      (and (eq? (read-runtime.object-class read) record-class)
        (let (birth (read-runtime.slot-ref read 'birth))
          (and (procedure? birth) (eq? birth (hash-get issued read)) (birth read)))))
    ;; Inspect the actual private association, not a caller's alleged birth.
    ;; Only the registered closure is invoked, and only in copy mode.
    (def (inspect read)
      (unless (eq? (read-runtime.object-class read) record-class)
        (error "foreign slot-read type"))
      (def presented (read-runtime.slot-ref read 'birth))
      (def original (hash-get issued read))
      (if original
        (let-values (((signed snapshot shape) (original #f)))
          (values presented original signed snapshot shape))
        (values presented #f #f #f #f)))
    (values issue issued? inspect)))

