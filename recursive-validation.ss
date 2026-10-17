;;; Finite recursive object graph closure over the existing Type and Slot protocols.
(export close-validation validation-action closed? closed-ref closed-type closed-names
        validation-failure? validation-failure-kind validation-failure-cause)
(import (only-in :std/list/list delete-duplicates/hash)
        (only-in :std/hash/misc hash-ensure-ref)
        ./object (only-in ./mop Type. Type validate raise-type-error)
        (only-in ./value-diagnostics diagnose-structure)
        (only-in ./validation-rebinding prepare-rebinding force-rebinding with-deferred-validation))

;; No partially allocated graph is a public closed value. Runtime provenance is
;; separate from Lean's finite proof; callbacks remain trusted terminating code.
(defstruct closed (names nodes types fresh) final: #t)
;; Preserve both the phase and original cause; no failure is a successful #f node.
(defstruct validation-failure (kind cause) final: #t)

;; Dynamic ownership protects nested closure attempts without a global registry.
(def active-validation-owner (make-parameter #f))

;; A descriptor from another graph cannot cut recursion in this closure attempt.
;; Outside closure, Reference validation uses its own immutable admitted catalog.
(def (check-owner owner)
  (def current (active-validation-owner))
  (when (and current (not (eq? current owner)))
    (raise (make-validation-failure 'owner #f))))

;; Freshness inspects registered object revisions, including propagated ancestor
;; edits. Raw setters/external callback dependencies require separate discipline.
(def (check-stamps stamps)
  (unless (andmap (lambda (entry) (= (object-revision (car entry)) (cdr entry))) stamps)
    (raise (make-validation-failure 'stale #f))))

;; Look up a named node only after the whole graph passed admission and is current.
(def (closed-ref graph name)
  ((closed-fresh graph))
  (hash-ref (closed-nodes graph) name))

;; Reference Types preserve canonical graph identity on later validation. They
;; rerun final graph admission, rather than constructing a different cyclic root.
(def (closed-type graph name)
  ((closed-fresh graph))
  (hash-ref (closed-types graph) name))

;; Allocate all receiver identities before normalizing any link. The builder gets
;; an owner-scoped reference-Type constructor and returns (name descriptor source)
;; triples. Reference fields accept the exact named source or canonical receiver;
;; they cut structural recursion, while every named target is independently
;; normalized and finally admitted. No general coinductive Type rule is asserted.
(def (close-validation build (limit 256))
  (unless (and (exact-integer? limit) (> limit 0)) (error "positive graph limit required"))
  (def owner (gensym 'validation))
  (def sources (make-hash-table-eq))
  (def nodes (make-hash-table-eq))
  (def types (make-hash-table-eq))
  (def phase 'building)
  (def stamps '())
  (def declarations '())
  ;; Admission occurs only after every field batch finishes. Leaf references use
  ;; exact owner/name identity and do not recursively invoke this whole-graph gate.
  (def (admit)
    (check-stamps stamps)
    (for-each (lambda (entry)
                (unless (.call (cadr entry) .element? (hash-ref nodes (car entry)))
                  (raise (make-validation-failure 'admission (car entry))))) declarations)
    (check-stamps stamps))
  ;; A closed reference can be used inside Function/container Types. Ordinary
  ;; membership recognizes identity; explicit validation also checks the graph.
  (def (reference name)
    (unless (symbol? name) (error "reference name must be a symbol"))
    (hash-ensure-ref types name
      (lambda ()
        (.cc Type.
          .element?: (lambda (value)
            (check-owner owner)
            (check-stamps stamps)
            (and (memq phase '(shape allocation normalization admission closed))
                 (hash-key? sources name)
                 (or (eq? value (hash-ref sources name))
                     (and (hash-key? nodes name) (eq? value (hash-ref nodes name))))))
          .validate: (lambda (value)
            (check-owner owner)
            (check-stamps stamps)
            (unless (and (memq phase '(normalization admission closed))
                         (hash-key? sources name) (hash-key? nodes name)
                         (or (eq? value (hash-ref sources name)) (eq? value (hash-ref nodes name))))
              (raise (make-validation-failure 'reference name)))
            (when (eq? phase 'closed) (admit))
            (hash-ref nodes name))))))
  (try
    (parameterize ((active-validation-owner owner))
    (set! declarations (build reference))
    (unless (and (list? declarations) (<= (length declarations) limit)
                 (pair? declarations)
                 (andmap (lambda (entry) (and (list? entry) (= (length entry) 3)
                   (symbol? (car entry)) (object? (cadr entry)) (object? (caddr entry)))) declarations))
      (raise (make-validation-failure 'catalog #f)))
    (def names (map car declarations))
    (unless (= (length names) (length (delete-duplicates/hash names)))
      (raise (make-validation-failure 'duplicate #f)))
    (for-each (lambda (entry) (hash-put! sources (car entry) (caddr entry))) declarations)
    (for-each reference names)
    ;; Missing references fail before any validator; unused declared targets are
    ;; still checked, so no bad node can hide behind an unobserved cyclic edge.
    (unless (andmap (cut hash-key? sources <>) (hash-keys types))
      (raise (make-validation-failure 'missing-reference #f)))
    (set! stamps (map (lambda (source) (cons source (object-revision source)))
                     (append (map cadr declarations) (map caddr declarations) (hash-values types))))
    (set! phase 'shape)
    (for-each (lambda (entry)
                (validate Type (cadr entry))
                (unless (.slot? (cadr entry) '.validation-fields)
                  (raise (make-validation-failure 'protocol (car entry))))
                (def issues (diagnose-structure (cadr entry) (caddr entry) (list (car entry))))
                (unless (null? issues) (raise (make-validation-failure 'shape issues)))) declarations)
    (set! phase 'allocation)
    (def batches (map (lambda (entry)
                       (cons (car entry) (.call (cadr entry) .validation-fields (caddr entry)))) declarations))
    (for-each (lambda (entry batch)
                (hash-put! nodes (car entry) (prepare-rebinding (caddr entry) (cdr batch)))) declarations batches)
    (set! stamps (append stamps (map (lambda (node) (cons node (object-revision node))) (hash-values nodes))))
    (set! phase 'normalization)
    (with-deferred-validation (lambda ()
      (for-each (lambda (batch) (force-rebinding (hash-ref nodes (car batch)) (cdr batch))) batches)))
    (set! phase 'admission)
    (admit)
    ;; Supported direct writes to canonical nodes refuse. Parent/source revisions
    ;; are checked at graph access/Reference validation, not arbitrary retained calls.
    (for-each seal-object! (append (hash-values nodes) (hash-values types)))
    (set! phase 'closed)
    (make-closed names nodes types (lambda () (check-stamps stamps))))
    (catch (cause) (set! phase 'failed) (raise cause))))

;; Reader/FUN-compatible closure action. Build sources for this input, and only
;; return the complete graph; the existing publication action owns state/evidence.
(def (validation-action build (limit 256))
  (lambda (input) (close-validation (lambda (reference) (build reference input)) limit)))
