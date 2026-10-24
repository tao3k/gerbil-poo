;;; Existing Maybe/OrFalse sentinels and dependent TypeValuePair validation.
(export optional-shape validate-optional type-value-shape validate-type-value type-value-catalog
        capture-type-values catalog-type? catalog-current! catalog-descriptor catalog-contract link-catalog-sources!
        call-with-current-catalogs)
(import (only-in ./object .o .cc .ref .get .slot? .all-slots object?
                 depend-on-object! replay-slot-reads! reobserve-slot-reads!)
        (only-in :std/list/list delete-duplicates/hash map-in-order)
        ./slot-observation ./value-diagnostics
        (only-in ./mop Type Class element? validate raise-type-error)
        (only-in ./types/validation validate-container))

;; Absent values bypass even child descriptor lookup. Present values keep the
;; supplied recursive checker, so nested refinements wait until wrapping.
(def (optional-shape absent? type-thunk candidate location check-field)
  (if (absent? candidate) '() (check-field (type-thunk) candidate location)))

;; Lock the present child Type. A bad validator cannot erase a Function by
;; returning an outer sentinel unless that child Type itself accepts the result.
;; Absent source values retain exact identity and do not demand the child Type.
(def (validate-optional descriptor absent? type-thunk candidate)
  (if (absent? candidate) candidate
    (let (child (type-thunk))
      (validate-container descriptor candidate
        (lambda (source)
          (def checked (validate child source))
          (unless (element? child checked) (raise-type-error child checked))
          checked)))))

;; Check the carried Type before inspecting its dependent value. Paths retain
;; car/cdr roles; neither an invalid Type nor a malformed carrier invokes payload checks.
(def (type-value-shape descriptor candidate location check-field)
  (cond
    ((not (pair? candidate)) [(.o kind: 'expected-type-value-pair path: location expected: descriptor)])
    ((not (element? Type (car candidate)))
     [(.o kind: 'invalid-type path: (append location '(car)) expected: Type)])
    (else (check-field (car candidate) (cdr candidate) (append location '(cdr))))))

;; Validate the dependent payload rather than the whole pair. Retain the exact
;; carried Type and original pair when unchanged; otherwise install a checked cdr.
;; Final membership checks that same Type, not an unrelated fallback descriptor.
(def (validate-type-value descriptor candidate)
  (validate-container descriptor candidate
    (lambda (source)
      (def carried-type (car source))
      (validate Type carried-type)
      (def original (cdr source))
      (def checked (validate carried-type original))
      (if (eq? original checked) source (cons carried-type checked)))))

;; Restrict the existing dependent carrier, not a second pair validator. Record
;; actual descriptor reads through the existing observation protocol: edits to
;; inherited sources also make replay refuse. Catalog tags use eq? identities;
;; an unlisted Type cannot run a payload callback by forging public metadata.
(def (type-value-catalog base types syntax (guard void))
  (guard)
  (unless (and (list? types) (<= (length types) 64)) (error "invalid finite Type catalog"))
  ;; Capture membership before Type admission can run a caller-defined getter.
  (def captured (map identity types))
  (validate Type base)
  (for-each (cut validate Type <>) captured)
  ;; Reissuing ordinary reads also exposes every captured source to enclosing
  ;; observers, including catalog members not selected by this payload.
  (def (read-catalog)
    (for-each (lambda (type) (.ref type '.element?)) captured)
    (.ref base '.validate))
  (defvalues (_ reads) (%call-with-recorded-slot-reads read-catalog))
  ;; Replay refuses old sources before getters; final replay also rejects edits
  ;; made by an enclosing observer. This never caches a successful approval.
  (def (current!)
    (guard)
    (replay-slot-reads! reads void)
    (read-catalog)
    (replay-slot-reads! reads void)
    (guard))
  ;; Retain malformed carrier/invalid Type diagnostics before catalog membership;
  ;; the ordinary dependent checker alone owns selected payload traversal.
  (def (shape value location check-field)
    (current!)
    (def result (if (and (pair? value) (element? Type (car value)) (not (memq (car value) captured)))
      [(.o kind: 'type-outside-catalog path: (append location '(car)) expected: descriptor)]
      (type-value-shape descriptor value location check-field)))
    (current!)
    result)
  (def descriptor (.cc base sexp: syntax
    .element?: (lambda (value)
      (current!)
      (def accepted (and (pair? value) (memq (car value) captured) (element? (car value) (cdr value)) #t))
      (current!)
      accepted)
    .diagnose: (lambda (value location) (shape value location diagnose-value))
    .diagnose-shape: (lambda (value location (check-field diagnose-structure))
                       (shape value location check-field))))
  descriptor)

;; Private tokens are immutable, snapshot-local Type identities, not names or
;; public sexp certificates. Aliases within one capture share a token.
(defstruct catalog-type (descriptor name current stable sources) final: #t equal: #f)
;; One request owns its actually admitted directory tokens. Allocate storage only
;; when a dynamic token is observed; intrinsic-only judgments retain no directory.
(def active-catalog-admission (make-parameter #f))
;; Compose existing consumers under one final observer-free source check. Nested
;; compiler/inference/declaration calls reuse the SAME frame and quota. Original
;; callback errors escape unchanged; only successful return receives final checks.
(def (call-with-current-catalogs work consume (fresh? #f))
  (def parent (active-catalog-admission))
  (if (and parent (not fresh?)) (consume)
    (let ((tokens #f) (ordered []))
      ;; Identity keys preserve snapshot-local aliases without replaying observers.
      (def (retain token)
        (when parent (parent token))
        (unless tokens (set! tokens (make-hash-table-eq)))
        (def stable (catalog-type-stable token))
        (unless (hash-key? tokens stable)
          (hash-put! tokens stable #t)
          (set! ordered (cons stable ordered))))
      (parameterize ((active-catalog-admission retain))
        (def result (consume))
        (for-each (lambda (stable) (stable work)) (reverse ordered))
        result))))
;; Recheck the complete captured source set, including unused directory entries.
(def (catalog-current! token (work void))
  ((catalog-type-current token) work)
  (when (active-catalog-admission) ((active-catalog-admission) token)))
;; Resolve only after live admission; callers cannot use a stale raw descriptor.
(def (catalog-descriptor token (work void))
  (catalog-current! token work)
  (catalog-type-descriptor token))

;; Reuse authenticated directory owners for guarded Types AND dependent carriers.
;; No getter runs here; one construction counter meters existing weak graph links.
(def (link-catalog-sources! descriptor token work)
  ((catalog-type-stable token) work)
  (for-each (lambda (owner) (work) (depend-on-object! descriptor owner))
    (catalog-type-sources token)))

;; Materialize an explicit finite directory once. Ordinary object getters own
;; dynamic Class/Schema selection. Extra roots declare otherwise hidden external
;; metadata; no predicate, layout or arbitrary callback implication is inferred.
(def (capture-type-values provider names sources work refuse)
  (unless (and (object? provider) (list? names) (<= (length names) 64)
               (andmap symbol? names) (= (length names) (length (delete-duplicates/hash names)))
               (list? sources) (<= (length sources) 64) (andmap object? sources))
    (refuse 'malformed "invalid finite Type directory"))
  (def keys (map identity names))
  (def roots (map identity sources))
  (def seen (make-hash-table-eq))
  ;; The existing observation frame records actual getter results and their
  ;; dependencies. Metadata preparation runs only during this capture.
  (def (read! thunk) (work) (thunk))
  ;; Class fields reuse effective Slot metadata. Follow finite declared child
  ;; Types once, preserving custom validators instead of translating their sexp.
  (def (visit descriptor)
    (work)
    (unless (hash-key? seen descriptor)
      (when (>= (hash-length seen) 64) (refuse 'unsupported "finite Type directory graph exceeds 64 descriptors"))
      (validate Type descriptor)
      (hash-put! seen descriptor #t)
      (read! (lambda () (.all-slots descriptor)))
      (read! (lambda () (.ref descriptor '.element?)))
      (read! (lambda () (.ref descriptor '.validate)))
      (when (and (.slot? descriptor '.type)
                 (eq? (read! (lambda () (.ref descriptor '.type))) Class))
        ;; Capture declared Slots too: effective composition may copy their
        ;; specifications, so a copied effective Slot alone is not their source.
        (for-each (lambda (key)
          (let* ((slots (read! (lambda () (.ref descriptor key))))
                 (fields (read! (lambda () (.all-slots slots)))))
            (for-each (lambda (name)
              (def slot (read! (lambda () (.ref slots name))))
              (read! (lambda () (.all-slots slot)))
              (when (.slot? slot 'type) (visit (read! (lambda () (.ref slot 'type)))))) fields)))
          '(slots effective-slots)))))
  (defvalues (entries reads) (%call-with-recorded-slot-reads
    (lambda ()
      (for-each (lambda (source) (read! (lambda () (.all-slots source)))) roots)
      (map-in-order (lambda (name)
        (def descriptor (read! (lambda () (.ref provider name))))
        (visit descriptor)
        (cons name descriptor)) keys))))
  (def captured-reads (delete-duplicates/hash reads table: (make-hash-table-eq) from-end?: #t))
  ;; Register exactly the authenticated read owners, once per directory capture.
  ;; The existing weak reverse graph propagates their edits to compiled Types;
  ;; shared/unused entries belong to the same complete directory snapshot.
  (def captured-sources (delete-duplicates/hash (map slot-read-receiver captured-reads)
    table: (make-hash-table-eq)))
  ;; Deliver the same current read records through the ordinary cache-hit path.
  ;; This includes reads made by Type admission, not only explicit metadata
  ;; getters. Both guards prevent observer edits from becoming approvals.
  (def (current! tick)
    (reobserve-slot-reads! captured-reads tick))
  ;; Final construction admission checks the same reads without invoking observers.
  (def (stable! tick)
    (replay-slot-reads! captured-reads (lambda (_receiver _key) (tick))))
  (current! work)
  (def tokens (make-hash-table-eq))
  (map (lambda (entry)
    (def descriptor (cdr entry))
    (cons (car entry) (or (hash-get tokens descriptor)
      (let (token (make-catalog-type descriptor (car entry) current! stable! captured-sources))
        (hash-put! tokens descriptor token) token)))) entries))

;; Wrap the actual Type methods with snapshot admission. Recursive normalization,
;; custom Schema diagnostics and child exceptions keep their original semantics.
;; Only successful callbacks receive a final guard; errors are never replaced.
(def (catalog-contract token work)
  (def source (catalog-descriptor token work))
  ;; One higher-order gate serves recognition, normalization and both diagnostic
  ;; paths, retaining ordinary calls inside outer Slot observation frames.
  (def (guard action)
    (catalog-current! token)
    (def result (action))
    (catalog-current! token)
    result)
  (def descriptor (.cc source sexp: (catalog-type-name token)
    .element?: (lambda (value) (guard (lambda () (element? source value))))
    .validate: (lambda (value) (guard (lambda () (validate source value))))
    .diagnose: (lambda (value location) (guard (lambda () (diagnose-value source value location))))
    .diagnose-shape: (lambda (value location (check-field diagnose-structure))
      (guard (lambda ()
        (if (.slot? source '.diagnose-shape)
          ((.ref source '.diagnose-shape) value location check-field)
          (check-field source value location)))))))
  ;; A retained bound parameter may disappear from residual syntax. Carry the
  ;; already known source edges into its Type revision, without rediscovering
  ;; metadata or caching approval. Meter links with the same construction quota;
  ;; registration invokes no source getter, so it needs no second metadata replay.
  (link-catalog-sources! descriptor token work)
  descriptor)
