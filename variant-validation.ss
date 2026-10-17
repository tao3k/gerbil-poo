;;; Recursive validation of existing Pair, Map, Sum and Union representations.
(export pair-shape map-shape sum-shape union-shape union-diagnostics
        validate-pair validate-map validate-sum validate-union)
(import :std/iter
        (only-in :std/list/list append-map map-in-order)
        (only-in ./object .o .get .ref .slot? object? object<-alist)
        (only-in ./mop validate element? raise-type-error)
        (only-in ./value-diagnostics diagnose-value diagnose-structure)
        (only-in ./type-validation validate-container))

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

;; Normalize keys then values in each snapshot entry. Reuse hash-new to preserve
;; the source table's comparison/hash policy. Reject normalized-key collisions
;; before any private table escapes; the source table is never mutated.
(def (validate-map descriptor key-type value-type candidate)
  (validate-container descriptor candidate
    (lambda (source)
      (def entries (hash->list source))
      (def checked (map-in-order
        (lambda (entry)
          (def key (validate key-type (car entry)))
          (def value (validate value-type (cdr entry)))
          (cons key value)) entries))
      (if (andmap (lambda (before after)
                    (and (eq? (car before) (car after)) (eq? (cdr before) (cdr after)))) entries checked)
        source
        (let (target (hash-new source))
          (for-each (lambda (entry)
                      (when (hash-key? target (car entry))
                        (raise-type-error descriptor source 'normalized-key-collision))
                      (hash-put! target (car entry) (cdr entry))) checked)
          target)))))

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
  (let/cc return
    (for-each (lambda (type)
                (when (null? (check-field type candidate location)) (return type))) types)
    #f))

;; Structural admission is existential; it does not normalize any alternative.
(def (union-shape descriptor types candidate location check-field)
  (if (select-union types candidate location check-field) '()
    [(.o kind: 'union-no-branch path: location expected: descriptor)]))

;; Ordinary Union diagnostics retain union membership: a fully recognized branch
;; suffices. Validation has a separate committed structural selection discipline.
(def (union-diagnostics descriptor types candidate location)
  (union-shape descriptor types candidate location diagnose-value))

;; Lock the first structural branch, validate it once, then check THAT branch's
;; returned value. A failure must not fall through to Any or another alternative.
;; Membership alone cannot promise which normalization a future validation uses.
(def (validate-union descriptor types candidate)
  (def selected (select-union types candidate '() diagnose-structure))
  (unless selected (raise-type-error descriptor candidate 'union-no-branch))
  (def checked (validate selected candidate))
  (unless (element? selected checked) (raise-type-error selected checked))
  checked)
