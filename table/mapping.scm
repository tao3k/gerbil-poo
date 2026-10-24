;;; Checked key-preserving maps reuse persistent folds and declared Trie traversal.

;; Visit the original snapshot once in backend order. Optional callbacks return
;; #f or (some value); required callbacks return Value, including stored false.
;; Only admitted leaves are accepted, never normalized or silently coerced.
(def (map-table-bindings descriptor transform input optional?)
  (using (transform :~ procedure?)
    (def sources (table-sources descriptor))
    (with-table-sources sources (lambda ()
      (require-table descriptor input)
      (def changed? #f)
      ;; Snapshot the callback-owned Option shell before recognizing its payload.
      ;; A later callback may reuse/mutate that shell without rewriting prior rows.
      (def (project key value)
        (def response (transform key value))
        (def next (require-table-option (.@ descriptor Value)
          (if optional? (map/option identity response) (some response))))
        (unless (table-option=? (some value) next) (set! changed? #t))
        next)
      ;; The declared specialized traversal retains its original left-to-right
      ;; callbacks. Otherwise capture changed bindings through the standard list
      ;; builder, then let the existing batch installer prepare ALL correlated
      ;; indexes against the final primary root (including unique-value swaps).
      (def result (if (.has? descriptor .map/key/opt)
        (.call descriptor .map/key/opt project input)
        (let (changes (with-list-builder (emit)
          (.call descriptor .for-each (lambda (key value)
            (def next (project key value))
            (unless (table-option=? (some value) next)
              (emit (make-table-change key (some value) next)))) input)))
          (if (null? changes) input
            (.call descriptor .apply-delta input
              (make-table-delta (.@ descriptor Key) (.@ descriptor Value)
                sources (map object-revision sources) changes))))))
      ;; No-op identity does not mean zero work: a specialized backend may already
      ;; have built temporary nodes. Complete custom recognition still runs.
      (require-table descriptor (if changed? result input))))))

;; Explicit entry projection can change both child Types without claiming an
;; inverse. One shared boundary admits input, Option/Pair responses and the final
;; target. The target's key registry, not host equal?, decides collisions.
(def (map-table-into source target transform input optional?)
  (using (transform :~ procedure?)
    (with-table-sources (list source target) (lambda ()
      (with-table-sources (append (table-sources source) (table-sources target)) (lambda ()
        (require-table source input)
        (def owners (table-key-table target (.@ source Key)))
        (with-table-sources (table-sources owners) (lambda ()
          (def seen (.@ owners .empty))
          (def binding (Pair (.@ target Key) (.@ target Value)))
          (def rows (with-list-builder (emit)
            (.call source .for-each (lambda (key value)
              (def response (transform key value))
              ;; Copy callback-owned shells BEFORE child recognition. A child
              ;; predicate may mutate the original response, never this decision.
              (def next (require-table-option binding
                (map/option (lambda (row) (if (pair? row) (cons (car row) (cdr row)) row))
                  (if optional? response (some response)))))
              (when (some? next)
                (let* ((output (some-value next))
                       (previous (.call owners .ref/opt seen (car output))))
                (when (some? previous)
                  (raise (make-table-index-conflict 'primary (car output) (some-value previous) key)))
                (set! seen (.call owners .acons (car output) key seen))
                (emit output)))) input)))
          ;; Construct only the complete target. Empty and partial target roots
          ;; need not satisfy a business refinement or final unique index family.
          (require-table target (.call target .<-list rows))))))))))

;; Merge both original snapshots, never newly staged bindings. Callback options
;; are fresh shells; neither mutating an input Option nor reusing an output shell
;; may rewrite another decision or an optimistic old-value expectation.
(def (merge-table-bindings descriptor choose left right)
  (using (choose :~ procedure?)
    (def sources (table-sources descriptor))
    (with-table-sources sources (lambda ()
      (require-table descriptor left)
      (require-table descriptor right)
      ;; Backend callbacks must describe actual admitted keys and optional values.
      ;; The specialized traversal's visitation order remains its own contract.
      (def (project key a b)
        (require-table-key descriptor key)
        (require-table-option (.@ descriptor Value) a)
        (require-table-option (.@ descriptor Value) b)
        (require-table-option (.@ descriptor Value)
          (map/option identity (choose key (map/option identity a) (map/option identity b)))))
      (def result (if (.has? descriptor .merge/key/opt)
        (.call descriptor .merge/key/opt project left right)
        (let (changes (with-list-builder (emit)
          ;; Preserve generic left order, then visit only right-exclusive keys.
          ;; Capture changes before any index writes so unique swaps are legal.
          (def (visit key a b)
            (def next (project key a b))
            (unless (table-option=? a next) (emit (make-table-change key a next))))
          (.call descriptor .for-each (lambda (key value)
            (visit key (some value) (.call descriptor .ref/opt right key))) left)
          (.call descriptor .for-each (lambda (key value)
            (unless (.call descriptor .key? left key) (visit key #f (some value)))) right)))
          (if (null? changes) left
            (.call descriptor .apply-delta left
              (make-table-delta (.@ descriptor Key) (.@ descriptor Value)
                sources (map object-revision sources) changes))))))
      (require-table descriptor result)))))

;; A read relation must not require an unrelated empty output to be admitted.
;; Two-sided domain inclusion plus matching left values establish equality under
;; the persistent backend's distinct-key law; callbacks remain guarded.
(def (equal-table-bindings? descriptor left right)
  (with-table-sources (table-sources descriptor) (lambda ()
    (require-table descriptor left)
    (require-table descriptor right)
    (and (.call descriptor .every (lambda (key value)
        (def found (.call descriptor .ref/opt right key))
        (and found (.call (.@ descriptor Value) .=? value (some-value found)))) left)
      (.call descriptor .every (lambda (key _) (.call descriptor .key? left key)) right)))))

;; Select from one admitted snapshot. Shared validation surrounds declared
;; structural capabilities; generic tables stage only removals, then reuse their
;; final-state delta installer. No empty seed or partial indexed root is required.
(def (select-table descriptor predicate input split?)
  (using (predicate :~ procedure?)
    (def sources (table-sources descriptor))
    (with-table-sources sources (lambda ()
      (require-table descriptor input)
      ;; Every backend observes the same strict Bool boundary and exact failure.
      (def (classify key value)
        (def selected? (predicate key value))
        (using (selected? :~ boolean?) selected?))
      ;; Each side starts at the original root; unchanged selections retain it.
      ;; All decisions precede installation, and no predicate is replayed.
      (def (generic)
        (def removals (.call descriptor .foldl (lambda (key value sides)
          (def selected? (classify key value))
          (if selected?
            (if split? (cons (car sides)
              (cons (make-table-change key (some value) #f) (cdr sides))) sides)
            (cons (cons (make-table-change key (some value) #f) (car sides)) (cdr sides)))) (cons [] []) input))
        ;; Capture ordered deletions using the existing optimistic delta format.
        (def (install changes)
          (if (null? changes) input
            (.call descriptor .apply-delta input
              (make-table-delta (.@ descriptor Key) (.@ descriptor Value)
                sources (map object-revision sources) (reverse changes)))))
        (def yes (install (car removals)))
        (cons yes (and split? (install (cdr removals)))))
      (def roots (cond
        ((and split? (.has? descriptor .partition/key))
          (let-values (((yes no) (.call descriptor .partition/key classify input))) (cons yes no)))
        ((and (not split?) (.has? descriptor .filter/key))
          (cons (.call descriptor .filter/key classify input) #f))
        (else (generic))))
      (require-table descriptor (car roots))
      (when split? (require-table descriptor (cdr roots)))
      roots))))
