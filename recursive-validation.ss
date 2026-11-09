;;; Finite recursive object graph closure over the existing Type and Slot protocols.
(export close-validation validation-action closed? closed-ref closed-type closed-names
        validation-failure? validation-failure-kind validation-failure-cause
        validation-node revise-validation revision-action closed-evaluated closed-reused
        reconfigure-validation reconfiguration-action closed-reads validation-checkpoint)
(import (only-in :gerbil/runtime/interface interface-instance-object)
        (only-in :gerbil/runtime/hash symbol-hash-table?)
        (only-in :gerbil/runtime/table symbolic-table-ref symbolic-table-set!)
        (only-in :std/list/list delete-duplicates/hash filter)
        (only-in :std/hash/misc hash-ensure-ref)
        (only-in ./strong-components capture-reachability-procedure)
        ./object (only-in ./mop Type. Type validate raise-type-error)
        (only-in ./value-diagnostics diagnose-structure)
        (only-in ./validation-rebinding prepare-rebinding force-rebinding with-deferred-validation))

;; No partially allocated graph is a public closed value. Runtime provenance is
;; separate from Lean's finite proof; callbacks remain trusted terminating code.
(defstruct %closed (names nodes types fresh owner entries local-stamps dependencies
                   revoked retired specifications evaluated reused directory) final: #t)
(defstruct %catalog (recipes reverse) final: #t)
(defstruct %directory (recipes reverse entries reused) final: #t)
;; Lists are observations, never mutable authority over private graph state.
(def closed? %closed?)
(def (closed-names graph) (append (%closed-names graph) []))
(def (closed-evaluated graph) (append (%closed-evaluated graph) []))
(def (closed-reused graph) (append (%closed-reused graph) []))
;; Immutable recipe identity is the change token. Watches cover external POO
;; inputs; dependencies must include links, computed reads and local obligations.
(defstruct node-spec (name dependencies watches build) final: #t)

;; Declare a finite node recipe; no source, descriptor or normalizer is built here.
(def (validation-node name dependencies watches build)
  (unless (and (symbol? name) (list? dependencies) (andmap symbol? dependencies)
               (list? watches) (andmap object? watches) (procedure? build))
    (error "invalid recursive validation node"))
  (make-node-spec name (delete-duplicates/hash dependencies) (append watches []) build))

;; Snapshot supported POO mutation, including revision propagation from ancestors.
(def (snapshot objects)
  (map (lambda (value) (cons value (object-revision value))) objects))

;; Reuse never ignores a changed source merely because a recipe kept its identity.
(def (stamps-current? stamps)
  (andmap (lambda (entry) (= (object-revision (car entry)) (cdr entry))) stamps))

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
  ((%closed-fresh graph))
  (hash-ref (%closed-nodes graph) name))

;; Reference Types preserve canonical graph identity on later validation. They
;; rerun final graph admission, rather than constructing a different cyclic root.
(def (closed-type graph name)
  ((%closed-fresh graph))
  (hash-ref (%closed-types graph) name))

;; Allocate all receiver identities before normalizing any link. The builder gets
;; an owner-scoped reference-Type constructor and returns (name descriptor source)
;; triples. Reference fields accept the exact named source or canonical receiver;
;; they cut structural recursion, while every named target is independently
;; normalized and finally admitted. No general coinductive Type rule is asserted.
(def (close-validation build (limit 256))
  (close-catalog build limit #f #f #f #f #f #f))

;; Shared closure engine: revision callers may retain only dependency-closed clean
;; nodes. Ordinary callers keep the original whole-graph Reference discipline.
(def (close-catalog build limit previous dependencies dirty specifications watches catalog
                    (admit-result (lambda (_) #t)))
  (unless (and (exact-integer? limit) (> limit 0)) (error "positive graph limit required"))
  (def owner (if previous (%closed-owner previous) (gensym 'validation)))
  (def sources (make-hash-table-eq))
  (def nodes (make-hash-table-eq))
  (def types (make-hash-table-eq))
  (def phase 'building)
  (def stamps '())
  (def declarations '())
  (def entry-index (make-hash-table-symbolic))
  (def reused-index (make-hash-table-symbolic))
  (def local-stamps (make-hash-table-eq))
  (def revoked (make-hash-table-eq))
  (def retired (vector #f))
  (def reused (if previous (filter (lambda (name) (not (hash-key? dirty name)))
                                  (hash-keys dependencies)) []))
  (for-each (lambda (name) (hash-put! reused-index name #t)) reused)
  (when previous
    (for-each (lambda (name)
      (hash-put! nodes name (hash-ref (%closed-nodes previous) name))
      (hash-put! types name (hash-ref (%closed-types previous) name))
      (hash-put! revoked name (hash-ref (%closed-revoked previous) name))) reused))
  ;; This graph owns ONE structural footprint index. No source or approval is
  ;; memoized; effect-side freshness still runs independently before/after use.
  (def reachable
    (and dependencies
      (capture-reachability-procedure (map node-spec-name specifications)
        (lambda (key) (hash-ref dependencies key)))))
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
                (reachable name))
      (check-stamps stamps)))
  ;; Scoped final checks permit a clean reference to survive unrelated revisions.
  ;; Every new graph nevertheless passes the complete admission gate below.
  (def (admit-reference name)
    (reference-fresh name)
    (for-each (lambda (key)
      (def entry (hash-ref entry-index key))
      (unless (.call (cadr entry) .element? (hash-ref nodes key))
        (raise (make-validation-failure 'admission key)))) (reachable name))
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
    ;; Own both list levels; builders retain their caller-facing containers.
    ;; Payload object identities are preserved and remain revision-watched.
    (set! declarations (map (lambda (entry) (list (car entry) (cadr entry) (caddr entry))) declarations))
    (for-each (lambda (entry)
      (hash-put! entry-index (car entry) entry)
      (hash-put! sources (car entry) (caddr entry))) declarations)
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
          (if (hash-key? reused-index name) (hash-ref (%closed-local-stamps previous) name)
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
              (filter (lambda (entry) (not (hash-key? reused-index (car entry)))) declarations))
    (set! phase 'allocation)
    (def batches (map (lambda (entry)
                       (cons (car entry) (.call (cadr entry) .validation-fields (caddr entry))))
                     (filter (lambda (entry) (not (hash-key? reused-index (car entry)))) declarations)))
    (for-each (lambda (batch)
                (hash-put! nodes (car batch) (prepare-rebinding (caddr (hash-ref entry-index (car batch))) (cdr batch)))) batches)
    (set! stamps (append stamps (map (lambda (node) (cons node (object-revision node))) (hash-values nodes))))
    (when dependencies
      (for-each (lambda (name)
        (unless (hash-key? reused-index name)
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
    ;; Joint graph/metadata obligations run before this attempt becomes a closed
    ;; graph or retires its predecessor. Failed-attempt References stay unusable
    ;; through the existing phase guard; clean predecessor References still work.
    (def directory (make-%directory (and catalog (%catalog-recipes catalog))
      (and catalog (%catalog-reverse catalog)) entry-index reused-index))
    (def result (make-%closed names nodes types (lambda ()
      (unless (memq phase '(admission closed)) (raise (make-validation-failure 'stale #f)))
      (when (vector-ref retired 0) (raise (make-validation-failure 'stale #f)))
      (check-stamps stamps)
      (when watches (for-each (lambda (name) (check-stamps (hash-ref watches name))) names)))
      owner declarations local-stamps dependencies revoked retired specifications
      (filter (lambda (name) (not (hash-key? reused-index name))) names) reused directory))
    (unless (eq? (admit-result result) #t) (raise (make-validation-failure 'joint-admission #f)))
    ;; Admission may inspect watched inputs: recheck every captured source/version
    ;; before retiring the predecessor, even when the callback returned true.
    ((%closed-fresh result))
    (set! phase 'closed)
    result)
    (catch (cause) (set! phase 'failed) (raise cause))))

;; Reader/FUN-compatible closure action. Build sources for this input, and only
;; return the complete graph; the existing publication action owns state/evidence.
(def (validation-action build (limit 256))
  (lambda (input) (close-validation (lambda (reference) (build reference input)) limit)))


;; Frames borrow immutable index rows. The sentinel is the append point for
;; new roots, even while an older frame is partly consumed. Only this work
;; owns the frame cells and visited table.
(defstruct affected-work (readers marked raw-marked frames tail receipt) final: #t)
(def (start-affected-work readers (receipt #f))
  (def marked (make-hash-table-symbolic))
  (def raw-readers (interface-instance-object readers))
  (def raw-marked (interface-instance-object marked))
  (unless (and (symbol-hash-table? raw-readers) (symbol-hash-table? raw-marked))
    (error "symbolic inverse index required"))
  (def tail (list []))
  (make-affected-work raw-readers marked raw-marked tail tail receipt))

;; Fuel counts popped occurrences, including already visited owners. A pause
;; preserves the rest of that row and every older root. New roots enter after
;; them. Only a first visit opens a bucket, regardless of the number of resumes.
(def (advance-affected-work! work roots (fuel #f))
  (unless (and (or (not fuel) (and (fixnum? fuel) (fx>= fuel 0)))
               (list? roots) (andmap symbol? roots))
    (error "invalid inverse work extension"))
  (when (pair? roots)
    (let ((old-tail (affected-work-tail work)) (new-tail (list [])))
      (set-car! old-tail (append roots []))
      (set-cdr! old-tail new-tail)
      (affected-work-tail-set! work new-tail)))
  (def tail (affected-work-tail work))
  (def readers (affected-work-readers work))
  (def marked (affected-work-raw-marked work))
  (def receipt (affected-work-receipt work))
  (let walk ((frames (affected-work-frames work)) (remaining fuel))
    (cond ((eq? frames tail) (affected-work-frames-set! work tail) #t)
          ((null? (car frames)) (walk (cdr frames) remaining))
          ((and remaining (fx= remaining 0))
           (affected-work-frames-set! work frames) #f)
          (else
           (let ((name (caar frames)) (next (and remaining (fx- remaining 1))))
             (set-car! frames (cdar frames))
             (if (symbolic-table-ref marked name #f) (walk frames next)
               (let (row (symbolic-table-ref readers name []))
                 (symbolic-table-set! marked name #t)
                 (when receipt
                   (vector-set! receipt 0 (1+ (vector-ref receipt 0)))
                   (vector-set! receipt 1 (+ (vector-ref receipt 1) (length row))))
                 (walk (cons row frames) next))))))))

(def (affected-owners readers roots (receipt #f) (removed []))
  (def work (start-affected-work readers receipt))
  (advance-affected-work! work roots)
  (when (pair? removed) (advance-affected-work! work removed))
  (affected-work-marked work))

;; Reclose one linear revision family. New/changed recipes, source/descriptor
;; revisions and watched-input edits seed invalidation; readers transitively join
;; it, including complete cycles. Unaffected canonical receivers and cached fields
;; survive. Final admission is never reused, and failure does not retire the old
;; snapshot. This is an in-process sequential publication protocol, not a lock.
(def (revise-validation previous specifications (limit 256) admit: (admit-result (lambda (_) #t)))
  (unless (and (list? specifications) (pair? specifications)
               (andmap node-spec? specifications) (<= (length specifications) limit))
    (raise (make-validation-failure 'catalog #f)))
  (when (and previous (or (not (%closed? previous)) (not (%closed-dependencies previous))
                          (vector-ref (%closed-retired previous) 0)))
    (raise (make-validation-failure 'stale #f)))
  ;; Snapshot command containers before any builder or admission callback.
  (def frozen-specs (append specifications []))
  (def names (map node-spec-name frozen-specs))
  (unless (= (length names) (length (delete-duplicates/hash names)))
    (raise (make-validation-failure 'duplicate #f)))
  (def recipes (make-hash-table-symbolic size: (length names)))
  (for-each (lambda (spec) (hash-put! recipes (node-spec-name spec) spec)) frozen-specs)
  (def dependencies (make-hash-table-eq))
  (def watches (make-hash-table-eq))
  (def reverse-index (make-hash-table-symbolic size: (length names)))
  (for-each (lambda (name) (hash-put! reverse-index name [])) names)
  (for-each (lambda (spec)
    (def name (node-spec-name spec))
    (def deps (node-spec-dependencies spec))
    (unless (andmap (cut hash-key? recipes <>) deps)
      (raise (make-validation-failure 'missing-reference name)))
    (hash-put! dependencies name deps)
    (hash-put! watches name (snapshot (node-spec-watches spec)))
    (for-each (lambda (dep)
      (hash-put! reverse-index dep (cons name (hash-ref reverse-index dep)))) deps)) frozen-specs)
  (def old-directory (and previous (%closed-directory previous)))
  (def prior-recipes (and old-directory (%directory-recipes old-directory)))
  ;; Exact recipe identity and old stamps still govern reuse, in source order.
  (def roots (filter (lambda (name)
    (or (not previous) (not (hash-key? prior-recipes name))
        (not (eq? (hash-ref recipes name) (hash-ref prior-recipes name)))
        (not (stamps-current? (hash-ref (%closed-local-stamps previous) name))))) names))
  (def removed (if previous (filter (lambda (name) (not (hash-key? recipes name)))
                              (%closed-names previous)) []))
  ;; All changed/added/removed declarations are roots. Unchanged consumer rows
  ;; are identical, so the OLD immutable inverse gives the same affected set.
  (def dirty (if previous
               (affected-owners (%directory-reverse old-directory) roots #f removed)
               (let (index (make-hash-table-symbolic size: (length names)))
                 (for-each (lambda (name) (hash-put! index name #t)) names) index)))
  (def recipe-index recipes)
  (def catalog (make-%catalog recipe-index reverse-index))
  (def sources (make-hash-table-eq))
  (when previous
    (for-each (lambda (entry) (hash-put! sources (car entry)
      (if (hash-key? dirty (car entry)) (caddr entry)
          (hash-ref (%closed-nodes previous) (car entry))))) (%closed-entries previous)))
  (def result (close-catalog (lambda (reference)
    (map (lambda (spec)
      (def name (node-spec-name spec))
      ;; These accessors reject undeclared reference/raw-source requests. Arbitrary
      ;; callback reads still obey the explicit complete-dependency premise.
      (def (allowed target)
        (unless (memq target (node-spec-dependencies spec))
          (raise (make-validation-failure 'dependency (list name target)))))
      (if (not (hash-key? dirty name)) (hash-ref (%directory-entries old-directory) name)
        (let (pair ((node-spec-build spec)
                     (lambda (target) (allowed target) (reference target))
                     (lambda (target) (allowed target) (hash-ref sources target))))
          (unless (and (list? pair) (= (length pair) 2) (andmap object? pair))
            (raise (make-validation-failure 'catalog name)))
          (hash-put! sources name (cadr pair))
          (cons name pair)))) frozen-specs))
    limit previous dependencies dirty frozen-specs watches catalog admit-result))
  ;; Commit only after normalization and every final obligation. Reentrant callers
  ;; may have retired this snapshot during a callback: refuse instead of installing.
  (when previous
    (let (retained (%directory-reused (%closed-directory result)))
      (when (vector-ref (%closed-retired previous) 0) (raise (make-validation-failure 'stale #f)))
      (for-each (lambda (name) (unless (hash-key? retained name)
        (vector-set! (hash-ref (%closed-revoked previous) name) 0 #t))) (%closed-names previous))
      (vector-set! (%closed-retired previous) 0 #t)))
  result)

;; FUN Reader action: thread the current graph through one complete revision.
(def (revision-action specifications (limit 256))
  (lambda (current) (revise-validation current specifications limit)))

;; Reconfigure final catalog membership and recipes in one checked batch. Additions
;; cannot overwrite an existing name; replacements target surviving names only.
;; Remove/re-add is a later-round operation, so no ambiguous same-batch revival
;; can bypass reference retirement. All edit checks precede every builder, and
;; revise-validation checks final dependency support before rebuilding anything.
(def (reconfigure-validation previous added removed replacements (limit 256)
                            admit: (admit-result (lambda (_) #t)))
  (unless (and (%closed? previous) (%closed-dependencies previous)
               (not (vector-ref (%closed-retired previous) 0)))
    (raise (make-validation-failure 'stale #f)))
  (unless (and (list? added) (andmap node-spec? added)
               (list? replacements) (andmap node-spec? replacements)
               (list? removed) (andmap symbol? removed))
    (raise (make-validation-failure 'edit #f)))
  (def old (%closed-specifications previous))
  (def known (%directory-recipes (%closed-directory previous)))
  (def additions (map node-spec-name added))
  (def updates (map node-spec-name replacements))
  ;; Validate exact writes before constructing a candidate. Indices select the
  ;; same unique recipe tokens; they do not authorize outputs or skip admission.
  (def (distinct? keys) (= (length keys) (length (delete-duplicates/hash keys))))
  (unless (and (distinct? (append additions updates)) (distinct? removed))
    (raise (make-validation-failure 'edit #f)))
  (def removed-index (make-hash-table-symbolic size: (length removed)))
  (def replacement-index (make-hash-table-symbolic size: (length replacements)))
  (for-each (lambda (name) (hash-put! removed-index name #t)) removed)
  (for-each (lambda (spec) (hash-put! replacement-index (node-spec-name spec) spec)) replacements)
  (unless (and (andmap (lambda (name) (not (hash-key? known name))) additions)
               (andmap (cut hash-key? known <>) removed)
               (andmap (lambda (name) (and (hash-key? known name) (not (hash-key? removed-index name)))) updates)
               (andmap (lambda (name) (not (hash-key? removed-index name))) additions))
    (raise (make-validation-failure 'edit #f)))
  (def survivors (filter (lambda (spec) (not (hash-key? removed-index (node-spec-name spec)))) old))
  (revise-validation previous
    (append (map (lambda (spec) (or (hash-get replacement-index (node-spec-name spec)) spec)) survivors)
            added) limit admit: admit-result))

;; FUN Reader action from the actual current snapshot to the complete final graph.
;; Publication/evidence effects remain the existing caller-owned next action.
(def (reconfiguration-action added removed replacements (limit 256) admit: (admit-result (lambda (_) #t)))
  (lambda (current) (reconfigure-validation current added removed replacements limit admit: admit-result)))

;; Capture a current declared graph and proposed recipe watches without building
;; anything. Invocation requires the exact same current graph AND unchanged input
;; versions. Even an unrelated successful revision invalidates this request;
;; selective Reference survival does not grant whole-snapshot publication rights.
;; Complete watches and immutable recipe metadata remain caller obligations.
(def (validation-checkpoint previous specifications)
  (unless (and (%closed? previous) (%closed-dependencies previous)
               (list? specifications) (andmap node-spec? specifications))
    (raise (make-validation-failure 'protocol #f)))
  ((%closed-fresh previous))
  (def watched (snapshot (apply append (map node-spec-watches specifications))))
  (lambda (current)
    (unless (eq? previous current) (raise (make-validation-failure 'stale #f)))
    ((%closed-fresh previous))
    (check-stamps watched)))

;; Reflect only the explicitly declared footprint of a current revision catalog.
;; Copy the list spine: editing the returned metadata cannot rewrite this graph's
;; invalidation directory. Ordinary fresh-owner closure has no declared footprint.
(def (closed-reads graph name)
  ((%closed-fresh graph))
  (unless (%closed-dependencies graph) (raise (make-validation-failure 'protocol name)))
  (append (hash-ref (%closed-dependencies graph) name) []))
