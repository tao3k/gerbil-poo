;;; Recursive validation of existing Pair, Map, Sum and Union representations.
(export pair-shape map-shape sum-shape union-shape union-diagnostics
        validate-pair validate-map validate-bindings validate-sum validate-union validate-or)
(import :std/iter
        (only-in :std/list/list find append-map map-in-order)
        (only-in ./object .o .get .ref .slot? object? object<-alist)
        (only-in ./mop validate element? raise-type-error)
        (only-in ./value-diagnostics diagnose-value diagnose-structure)
        (only-in ./types/validation validate-container))

;; A Pair may have an improper tail. Both positions retain symbolic paths, and
;; non-pairs refuse before either child recognizer can demand a value.
(def (pair-shape descriptor left right candidate location check-field)
  (if (pair? candidate)
    (append (check-field left (car candidate) (append location '(car)))
            (check-field right (cdr candidate) (append location '(cdr))))
    [(.o kind: 'expected-pair path: location expected: descriptor)]))

;; Validate both children before constructing one replacement cons. The original
;; pair identity survives when both validated values are unchanged.
(def (validate-pair descriptor left right candidate)
  (validate-container descriptor candidate
    (lambda (source)
      (def first (validate left (car source)))
      (def second (validate right (cdr source)))
      (if (and (eq? first (car source)) (eq? second (cdr source))) source
        (cons first second)))))

;; Map traversal uses the table's snapshot order, not a canonical key order.
;; Indexed key/value paths avoid retaining arbitrary keys or procedures in issues.
(def (map-shape descriptor key-type value-type candidate location check-field)
  (if (hash-table? candidate)
    (append-map identity
      (for/collect ((entry (hash->list candidate)) (index (in-range (hash-length candidate))))
        (append (check-field key-type (car entry) (append location [index 'key]))
                (check-field value-type (cdr entry) (append location [index 'value])))))
    [(.o kind: 'expected-map path: location expected: descriptor)]))

;; Normalize one finite backend snapshot, key before value in traversal order.
;; Keep every returned wrapper. Rebuild only after all children succeed, using
;; the backend's own membership/insertion policy to refuse normalized collisions.
;; Empty supplies a private persistent seed (or a fresh mutable hash table).
;; Child/rebuild exceptions propagate; arbitrary callback effects are not rolled back.
(def (validate-bindings descriptor key-type value-type source entries empty contains? insert)
  ;; Gerbil owns ordered traversal; custom Type effects run exactly once per child.
  (def checked (map-in-order
    (lambda (entry)
      (let* ((key (validate key-type (car entry)))
             (value (validate value-type (cdr entry))))
        (cons key value))) entries))
  (if (andmap (lambda (before after)
                (and (eq? (car before) (car after)) (eq? (cdr before) (cdr after)))) entries checked)
    source
    (foldl (lambda (entry target)
             (when (contains? target (car entry))
               (raise-type-error descriptor source 'normalized-key-collision))
             (insert (car entry) (cdr entry) target))
           (empty) checked)))

;; Hash-backed Map retains its comparison/hash policy and never mutates source.
;; The same binding protocol also serves persistent tables and their derived sets.
(def (validate-map descriptor key-type value-type candidate)
  (validate-container descriptor candidate
    (lambda (source)
      (validate-bindings descriptor key-type value-type source (hash->list source)
        (lambda () (hash-new source)) hash-key?
        (lambda (key value target) (hash-put! target key value) target)))))

;; Sum dispatch checks carrier and tag before demanding its payload. Only the
;; selected payload is traversed; extra source slots retain the existing policy.
(def (sum-shape descriptor variants candidate location check-field)
  (cond
    ((not (and (object? candidate) (.slot? candidate 'tag) (.slot? candidate 'value)))
     [(.o kind: 'expected-sum path: location expected: descriptor)])
    ((let (tag (.get candidate tag)) (not (and (symbol? tag) (.slot? variants tag))))
     [(.o kind: 'unknown-tag path: (append location '(tag)) expected: descriptor)])
    (else (check-field (.ref variants (.get candidate tag)) (.get candidate value)
                      (append location '(value))))))

;; Batch payload replacement inherits the original Sum object, retaining tag,
;; extra lazy slots and ancestry. Freeze the chosen tag too: an inherited tag may
;; otherwise recompute from the wrapped payload. Unknown tags gate validators.
(def (validate-sum descriptor variants candidate)
  (validate-container descriptor candidate
    (lambda (source)
      (def selected-tag (.get source tag))
      (def original (.get source value))
      (def checked (validate (.ref variants selected-tag) original))
      (if (eq? original checked) source
        (object<-alist (list (cons 'tag selected-tag) (cons 'value checked)) supers: (list source))))))

;; Choose the first structurally matching branch in declaration order. Never
;; catch a custom recognizer exception or use execution failure as branch search.
(def (select-union types candidate location check-field)
  (find (lambda (type) (null? (check-field type candidate location))) types))

;; Structural admission is existential; it does not normalize any alternative.
(def (union-shape descriptor types candidate location check-field)
  (if (select-union types candidate location check-field) '()
    [(.o kind: 'union-no-branch path: location expected: descriptor)]))

;; Ordinary Union diagnostics retain union membership: a fully recognized branch
;; suffices. Validation has a separate committed structural selection discipline.
(def (union-diagnostics descriptor types candidate location)
  (union-shape descriptor types candidate location diagnose-value))

;; Both existing alternative protocols lock a selected Type before wrapping.
;; Keep its exact child error and require its returned membership; neither
;; protocol retries another branch after normalization failure.
(def (validate-alternative descriptor selected candidate missing)
  (unless selected (raise-type-error descriptor candidate missing))
  (def checked (validate selected candidate))
  (unless (element? selected checked) (raise-type-error selected checked))
  checked)

;; Union commits to its first structurally matching branch, as before.
(def (validate-union descriptor types candidate)
  (validate-alternative descriptor (select-union types candidate '() diagnose-structure)
    candidate 'union-no-branch))

;; Or follows its existing discriminant's first actual membership using Gerbil's
;; ordered find. Recognizer exceptions propagate; wrapping never changes selection.
(def (validate-or descriptor types candidate)
  (validate-alternative descriptor (find (cut element? <> candidate) types)
    candidate 'or-no-branch))
