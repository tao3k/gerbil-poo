;;; Finite recursive object graph closure over the existing Type and Slot protocols.
(export close-validation validation-action closed? closed-ref closed-type closed-names
        validation-failure? validation-failure-kind validation-failure-cause
        validation-node revise-validation revision-action closed-evaluated closed-reused
        reconfigure-validation reconfiguration-action closed-reads validation-checkpoint)
(import (only-in :std/list/list delete-duplicates/hash filter find)
        (only-in :std/hash/misc hash-ensure-ref)
        ./object (only-in ./mop Type. Type validate raise-type-error)
        (only-in ./value-diagnostics diagnose-structure)
        (only-in ./validation-rebinding prepare-rebinding force-rebinding with-deferred-validation))

;; No partially allocated graph is a public closed value. Runtime provenance is
;; separate from Lean's finite proof; callbacks remain trusted terminating code.
(defstruct closed (names nodes types fresh owner entries local-stamps dependencies
                   revoked retired specifications evaluated reused) final: #t)
;; Immutable recipe identity is the change token. Watches cover external POO
;; inputs; dependencies must include links, computed reads and local obligations.
(defstruct node-spec (name dependencies watches build) final: #t)

;; Declare a finite node recipe; no source, descriptor or normalizer is built here.
(def (validation-node name dependencies watches build)
  (unless (and (symbol? name) (list? dependencies) (andmap symbol? dependencies)
               (list? watches) (andmap object? watches) (procedure? build))
    (error "invalid recursive validation node"))
  (make-node-spec name (delete-duplicates/hash dependencies) watches build))

;; Snapshot supported POO mutation, including revision propagation from ancestors.
(def (snapshot objects)
  (map (lambda (value) (cons value (object-revision value))) objects))

;; Reuse never ignores a changed source merely because a recipe kept its identity.
(def (stamps-current? stamps)
  (andmap (lambda (entry) (= (object-revision (car entry)) (cdr entry))) stamps))

;; Finite reachability terminates on shared nodes and SCCs without unfolding Types.
(def (reachable dependencies root)
  (let loop ((todo (list root)) (seen []))
    (if (null? todo) seen
      (if (memq (car todo) seen) (loop (cdr todo) seen)
        (loop (append (hash-ref dependencies (car todo)) (cdr todo)) (cons (car todo) seen))))))
;; Preserve both the phase and original cause; no failure is a successful #f node.
(defstruct validation-failure (kind cause) final: #t)

;; Dynamic ownership protects nested closure attempts without a global registry.
(def active-validation-owner (make-parameter #f))
;; A revision family shares ownership, but each target must still use the exact
;; Reference Type selected for this attempt. Old dirty Types cannot sneak in via
;; a custom descriptor returned by an otherwise freshly invoked recipe.
(def active-validation-types (make-parameter #f))

;; A descriptor from another graph cannot cut recursion in this closure attempt.
;; Outside closure, Reference validation uses its own immutable admitted catalog.
(def (check-owner owner)
  (def current (active-validation-owner))
  (when (and current (not (eq? current owner)))
    (raise (make-validation-failure 'owner #f))))

;; Freshness inspects registered object revisions, including propagated ancestor
;; edits. Raw setters/external callback dependencies require separate discipline.
(def (check-stamps stamps)
  (unless (stamps-current? stamps)
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
  (close-catalog build limit #f #f [] #f #f))

;; Shared closure engine: revision callers may retain only dependency-closed clean
;; nodes. Ordinary callers keep the original whole-graph Reference discipline.
(def (close-catalog build limit previous dependencies dirty specifications watches)
  (unless (and (exact-integer? limit) (> limit 0)) (error "positive graph limit required"))
  (def owner (if previous (closed-owner previous) (gensym 'validation)))
  (def sources (make-hash-table-eq))
  (def nodes (make-hash-table-eq))
  (def types (make-hash-table-eq))
  (def phase 'building)
  (def stamps '())
  (def declarations '())
  (def local-stamps (make-hash-table-eq))
  (def revoked (make-hash-table-eq))
  (def retired (vector #f))
  (def reused (if previous (filter (lambda (name) (not (memq name dirty)))
                                  (hash-keys dependencies)) []))
  (when previous
    (for-each (lambda (name)
      (hash-put! nodes name (hash-ref (closed-nodes previous) name))
      (hash-put! types name (hash-ref (closed-types previous) name))
      (hash-put! revoked name (hash-ref (closed-revoked previous) name))) reused))
  ;; An unaffected reference reads only its declared reachable subgraph. Whole
  ;; graph access still checks every node; an installed revision retires its old
  ;; snapshot while invalidated old Reference capabilities explicitly refuse.
  (def (reference-fresh name)
    (def current (active-validation-types))
    (when (and current (or (not (hash-key? current name))
                          (not (eq? (hash-ref current name) (hash-ref types name)))))
      (raise (make-validation-failure 'reference name)))
    (when (and (hash-key? revoked name) (vector-ref (hash-ref revoked name) 0)) (raise (make-validation-failure 'stale name)))
    (if (and dependencies (hash-key? local-stamps name))
      (for-each (lambda (key) (check-stamps (hash-ref local-stamps key)))
                (reachable dependencies name))
      (check-stamps stamps)))
  ;; Scoped final checks permit a clean reference to survive unrelated revisions.
  ;; Every new graph nevertheless passes the complete admission gate below.
  (def (admit-reference name)
    (reference-fresh name)
    (for-each (lambda (key)
      (def entry (assq key declarations))
      (unless (.call (cadr entry) .element? (hash-ref nodes key))
        (raise (make-validation-failure 'admission key)))) (reachable dependencies name))
    (reference-fresh name))
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
    (unless (hash-key? revoked name) (hash-put! revoked name (vector #f)))
    (hash-ensure-ref types name
      (lambda ()
        (.cc Type.
          ;; Raw identities are for source checking; final recognition requires
          ;; the canonical target even when a custom Slot supplies the value.
          .element?: (lambda (value)
            (check-owner owner)
            (reference-fresh name)
            (and (memq phase '(shape allocation normalization admission closed))
                 (hash-key? sources name)
                 (or (and (memq phase '(shape allocation normalization))
                          (eq? value (hash-ref sources name)))
                     (and (hash-key? nodes name) (eq? value (hash-ref nodes name))))))
          .validate: (lambda (value)
            (check-owner owner)
            (reference-fresh name)
            (unless (and (memq phase '(normalization admission closed))
                         (hash-key? sources name) (hash-key? nodes name)
                         (or (eq? value (hash-ref sources name)) (eq? value (hash-ref nodes name))))
              (raise (make-validation-failure 'reference name)))
            (when (eq? phase 'closed) (if dependencies (admit-reference name) (admit)))
            (hash-ref nodes name))))))
  (try
    (parameterize ((active-validation-owner owner) (active-validation-types types))
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
    (when dependencies
      (for-each (lambda (entry)
        (def name (car entry))
        ;; Retention preserves the OLD evidence stamps. A callback cannot edit a
        ;; clean source during build and have its stale cache silently re-stamped.
        (hash-put! local-stamps name
          (if (memq name reused) (hash-ref (closed-local-stamps previous) name)
            (append (snapshot (list (cadr entry) (caddr entry) (hash-ref types name)))
                    (hash-ref watches name))))) declarations)
      (set! stamps (append stamps (apply append
        (map (cut hash-ref local-stamps <>) reused)))))
    (when watches (set! stamps (append stamps (apply append (hash-values watches)))))
    (check-stamps stamps)
    (set! phase 'shape)
    (for-each (lambda (entry)
                (validate Type (cadr entry))
                (unless (.slot? (cadr entry) '.validation-fields)
                  (raise (make-validation-failure 'protocol (car entry))))
                (def issues (diagnose-structure (cadr entry) (caddr entry) (list (car entry))))
                (unless (null? issues) (raise (make-validation-failure 'shape issues))))
              (filter (lambda (entry) (not (memq (car entry) reused))) declarations))
    (set! phase 'allocation)
    (def batches (map (lambda (entry)
                       (cons (car entry) (.call (cadr entry) .validation-fields (caddr entry))))
                     (filter (lambda (entry) (not (memq (car entry) reused))) declarations)))
    (for-each (lambda (batch)
                (hash-put! nodes (car batch) (prepare-rebinding (caddr (assq (car batch) declarations)) (cdr batch)))) batches)
    (set! stamps (append stamps (map (lambda (node) (cons node (object-revision node))) (hash-values nodes))))
    (when dependencies
      (for-each (lambda (name)
        (unless (memq name reused)
          (hash-put! local-stamps name (append (hash-ref local-stamps name)
                                             (snapshot (list (hash-ref nodes name))))))) names))
    (set! phase 'normalization)
    (with-deferred-validation (lambda ()
      (for-each (lambda (batch) (force-rebinding (hash-ref nodes (car batch)) (cdr batch))) batches)
      ;; Deferred checks must reject unnormalized raw links too.
      (set! phase 'admission)))
    (admit)
    ;; Supported direct writes to canonical nodes refuse. Parent/source revisions
    ;; are checked at graph access/Reference validation, not arbitrary retained calls.
    (for-each seal-object! (append (hash-values nodes) (hash-values types)))
    (set! phase 'closed)
    (make-closed names nodes types (lambda ()
      (when (vector-ref retired 0) (raise (make-validation-failure 'stale #f)))
      (check-stamps stamps)
      (when watches (for-each (lambda (name) (check-stamps (hash-ref watches name))) names)))
      owner declarations local-stamps dependencies revoked retired specifications
      (filter (lambda (name) (not (memq name reused))) names) reused))
    (catch (cause) (set! phase 'failed) (raise cause))))

;; Reader/FUN-compatible closure action. Build sources for this input, and only
;; return the complete graph; the existing publication action owns state/evidence.
(def (validation-action build (limit 256))
  (lambda (input) (close-validation (lambda (reference) (build reference input)) limit)))


;; Reclose one linear revision family. New/changed recipes, source/descriptor
;; revisions and watched-input edits seed invalidation; readers transitively join
;; it, including complete cycles. Unaffected canonical receivers and cached fields
;; survive. Final admission is never reused, and failure does not retire the old
;; snapshot. This is an in-process sequential publication protocol, not a lock.
(def (revise-validation previous specifications (limit 256))
  (unless (and (list? specifications) (pair? specifications)
               (andmap node-spec? specifications) (<= (length specifications) limit))
    (raise (make-validation-failure 'catalog #f)))
  (when (and previous (or (not (closed? previous)) (not (closed-dependencies previous))
                          (vector-ref (closed-retired previous) 0)))
    (raise (make-validation-failure 'stale #f)))
  (def names (map node-spec-name specifications))
  (unless (= (length names) (length (delete-duplicates/hash names)))
    (raise (make-validation-failure 'duplicate #f)))
  (def dependencies (make-hash-table-eq))
  (def watches (make-hash-table-eq))
  (for-each (lambda (spec)
    (unless (andmap (cut memq <> names) (node-spec-dependencies spec))
      (raise (make-validation-failure 'missing-reference (node-spec-name spec))))
    (hash-put! dependencies (node-spec-name spec) (node-spec-dependencies spec))
    (hash-put! watches (node-spec-name spec) (snapshot (node-spec-watches spec)))) specifications)
  ;; Recipe identity, not equal outputs, licenses reuse. Current local stamps also
  ;; include generated descriptors/sources/receivers, so edits cannot hide there.
  (def dirty (filter (lambda (name)
    (or (not previous) (not (memq name (closed-names previous)))
        (not (eq? (find (lambda (spec) (eq? (node-spec-name spec) name)) specifications)
                  (find (lambda (spec) (eq? (node-spec-name spec) name)) (closed-specifications previous))))
        (not (stamps-current? (hash-ref (closed-local-stamps previous) name))))) names))
  ;; Saturate reverse dependencies. Each productive pass adds a finite name; SCC
  ;; membership needs no separate eager computed evaluation or successful #f memo.
  (let loop ()
    (def more (filter (lambda (name) (and (not (memq name dirty))
      (ormap (cut memq <> dirty) (hash-ref dependencies name)))) names))
    (unless (null? more) (set! dirty (append dirty more)) (loop)))
  (def sources (make-hash-table-eq))
  (when previous
    (for-each (lambda (entry) (hash-put! sources (car entry)
      (if (memq (car entry) dirty) (caddr entry)
          (hash-ref (closed-nodes previous) (car entry))))) (closed-entries previous)))
  (def result (close-catalog (lambda (reference)
    (map (lambda (spec)
      (def name (node-spec-name spec))
      ;; These accessors reject undeclared reference/raw-source requests. Arbitrary
      ;; callback reads still obey the explicit complete-dependency premise.
      (def (allowed target)
        (unless (memq target (node-spec-dependencies spec))
          (raise (make-validation-failure 'dependency (list name target)))))
      (if (not (memq name dirty)) (assq name (closed-entries previous))
        (let (pair ((node-spec-build spec)
                     (lambda (target) (allowed target) (reference target))
                     (lambda (target) (allowed target) (hash-ref sources target))))
          (unless (and (list? pair) (= (length pair) 2) (andmap object? pair))
            (raise (make-validation-failure 'catalog name)))
          (hash-put! sources name (cadr pair))
          (cons name pair)))) specifications))
    limit previous dependencies dirty specifications watches))
  ;; Commit only after normalization and every final obligation. Reentrant callers
  ;; may have retired this snapshot during a callback: refuse instead of installing.
  (when previous
    (when (vector-ref (closed-retired previous) 0) (raise (make-validation-failure 'stale #f)))
    (for-each (lambda (name) (unless (memq name (closed-reused result))
      (vector-set! (hash-ref (closed-revoked previous) name) 0 #t))) (closed-names previous))
    (vector-set! (closed-retired previous) 0 #t))
  result)

;; FUN Reader action: thread the current graph through one complete revision.
(def (revision-action specifications (limit 256))
  (lambda (current) (revise-validation current specifications limit)))

;; Reconfigure final catalog membership and recipes in one checked batch. Additions
;; cannot overwrite an existing name; replacements target surviving names only.
;; Remove/re-add is a later-round operation, so no ambiguous same-batch revival
;; can bypass reference retirement. All edit checks precede every builder, and
;; revise-validation checks final dependency support before rebuilding anything.
(def (reconfigure-validation previous added removed replacements (limit 256))
  (unless (and (closed? previous) (closed-dependencies previous)
               (not (vector-ref (closed-retired previous) 0)))
    (raise (make-validation-failure 'stale #f)))
  (unless (and (list? added) (andmap node-spec? added)
               (list? replacements) (andmap node-spec? replacements)
               (list? removed) (andmap symbol? removed))
    (raise (make-validation-failure 'edit #f)))
  (def old (closed-specifications previous))
  (def names (closed-names previous))
  (def additions (map node-spec-name added))
  (def updates (map node-spec-name replacements))
  ;; Distinct writes and surviving targets are validated together; equal recipes
  ;; do not excuse duplicate contributions from separate services.
  (def (distinct? keys) (= (length keys) (length (delete-duplicates/hash keys))))
  (unless (and (distinct? (append additions updates)) (distinct? removed)
               (andmap (lambda (name) (not (memq name names))) additions)
               (andmap (cut memq <> names) removed)
               (andmap (lambda (name) (and (memq name names) (not (memq name removed)))) updates)
               (andmap (lambda (name) (not (memq name removed))) additions))
    (raise (make-validation-failure 'edit #f)))
  (def survivors (filter (lambda (spec) (not (memq (node-spec-name spec) removed))) old))
  (revise-validation previous
    (append (map (lambda (spec)
      (or (find (lambda (replacement) (eq? (node-spec-name spec) (node-spec-name replacement))) replacements)
          spec)) survivors) added) limit))

;; FUN Reader action from the actual current snapshot to the complete final graph.
;; Publication/evidence effects remain the existing caller-owned next action.
(def (reconfiguration-action added removed replacements (limit 256))
  (lambda (current) (reconfigure-validation current added removed replacements limit)))

;; Capture a current declared graph and proposed recipe watches without building
;; anything. Invocation requires the exact same current graph AND unchanged input
;; versions. Even an unrelated successful revision invalidates this request;
;; selective Reference survival does not grant whole-snapshot publication rights.
;; Complete watches and immutable recipe metadata remain caller obligations.
(def (validation-checkpoint previous specifications)
  (unless (and (closed? previous) (closed-dependencies previous)
               (list? specifications) (andmap node-spec? specifications))
    (raise (make-validation-failure 'protocol #f)))
  ((closed-fresh previous))
  (def watched (snapshot (apply append (map node-spec-watches specifications))))
  (lambda (current)
    (unless (eq? previous current) (raise (make-validation-failure 'stale #f)))
    ((closed-fresh previous))
    (check-stamps watched)))

;; Reflect only the explicitly declared footprint of a current revision catalog.
;; Copy the list spine: editing the returned metadata cannot rewrite this graph's
;; invalidation directory. Ordinary fresh-owner closure has no declared footprint.
(def (closed-reads graph name)
  ((closed-fresh graph))
  (unless (closed-dependencies graph) (raise (make-validation-failure 'protocol name)))
  (append (hash-ref (closed-dependencies graph) name) []))
