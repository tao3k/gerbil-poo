;;; Construction option parsing, slot normalization and hygienic lexical bindings.
(export (for-syntax parse-object-options deduplicate-slot-identifiers prepare-shared-slot-specs
                     normalize-slot-specs normalize-slot-specs-for-match))
(import (for-syntax :std/iter
                    (only-in :gerbil/compiler/base make-bound-identifier-table)
                    (only-in :std/list/list delete-duplicates/hash push!)
                    (only-in :std/list/list-builder with-list-builder)))
(begin-syntax
  ;; Parse only the reserved leading option prefix; parenthesized slots can still
  ;; use reserved names. Options are lexical declarations, not runtime keywords.
  (def (parse-object-options ctx arguments)
    (def options (make-hash-table-eq))
    (let loop ((rest arguments))
      (syntax-case rest ()
        ((key value . tail)
         (memq (syntax-e #'key) '(self: super: inherit: bind: bind-these:))
         (let ((key (syntax-e #'key)))
           (when (hash-key? options key) (raise-syntax-error #f "duplicate object option" ctx #'key))
           (hash-put! options key #'value)
           (loop #'tail)))
        ((key)
         (memq (syntax-e #'key) '(self: super: inherit: bind: bind-these:))
         (raise-syntax-error #f "missing object option value" ctx #'key))
        (_
         (let* ((self (hash-ref options self: #'self))
                (super (hash-ref options super: #'#f))
                (parents (hash-ref options inherit: #'[]))
                (bindings (hash-ref options bind: #'()))
                (include? (hash-ref options bind-these: #'#t)))
           (unless (identifier? self) (raise-syntax-error #f "self must be an identifier" ctx self))
           (unless (or (eq? (syntax-e super) #f) (identifier? super))
             (raise-syntax-error #f "super must be an identifier" ctx super))
           (unless (identifier-list? bindings)
             (raise-syntax-error #f "bind must be an identifier list" ctx bindings))
           (unless (boolean? (syntax-e include?))
             (raise-syntax-error #f "bind-these must be a literal boolean" ctx include?))
           (values self super parents bindings include? rest)))))))

;; A prototype may name the same slot in its inherited, default, and direct
;; declarations.  Syntax bindings only need one entry for identifiers that
;; denote the same lexical slot.
(begin-syntax
  ;; Reuse the compiler's hygienic table: names select hash buckets, while
  ;; bound-identifier=? still compares complete context and marks. Retain the
  ;; first original syntax object, including distinct scopes sharing a name.
  (def (deduplicate-slot-identifiers slots)
    (delete-duplicates/hash (syntax->list slots)
      table: (make-bound-identifier-table)
      from-end?: #t))

  ;; Capture lexical shorthand once before slot-binding syntax is introduced.
  (def (prepare-shared-slot-specs specs)
    (let loop ((rest specs) (bindings []) (result []))
      (match rest
        ([] [(reverse bindings) (reverse result)])
        ([spec . tail]
         (syntax-case spec ()
           ((slot)
            (with-syntax ((value (genident 'slot-value)))
              (loop tail
                    [#'(value slot) . bindings]
                    [#'(slot lexical-slot-value value) . result])))
           (_ (loop tail bindings [spec . result]))))))))


(begin-syntax
  ;; Preserve the originating construction identifier when lowering keyword names.
  ;; The stx argument is the original syntax #'(.o args ...) or #'(@method args ...)
  (def (unkeywordify-syntax ctx k)
    (datum->syntax (stx-car ctx)
                   (string->symbol (keyword->string (syntax->datum k)))))

  ;; A NormalizedSlotSpec is one of:
  ;;  - (slot-name value-expr)                           ; ignore parent, override
  ;;  - (slot-name => function-expr extra-arg-expr ...)  ; invoke parent, pass into function
  ;;  - (slot-name (inherited-computation) value-expr)   ; lazy reference to parent
  ;;  - (slot-name)                                      ; same-named var from surrounding scope
  ;;  - (slot-name =>.+ object-expr)                     ; override parent with a mixin
  ;;  - (slot-name ?: default-expr)                      ; default for the slot
  ;; Interpretation according to `doc/poo.md` section `POO Definition Syntax`

  ;; Normalize methods/defaults in declaration order with separate duplicate checks.
  (def (normalize-slot-specs ctx specs)
    (def methods (make-hash-table-symbolic))
    (def defaults (make-hash-table-symbolic))
    (def defaults-list '())
    (def (d x) (push! x defaults-list))
    (def slot-methods
      (with-list-builder (c) (%normalize-slot-specs ctx specs methods defaults c d)))
    [slot-methods (reverse defaults-list)])

  ;; Stream keyword, lexical shorthand and parenthesized specifications once.
  (def (%normalize-slot-specs ctx specs methods defaults c d)
    (def (loop more) (%normalize-slot-specs ctx more methods defaults c d))
    (syntax-case specs ()
      (() (void))
      ((arg . more)
       (let ((e (syntax-e #'arg)))
         (cond
          ((pair? e) (%normalize-slot-spec ctx #'arg methods defaults c d) (loop #'more))
          ((symbol? e) (%normalize-slot-spec ctx #'(arg) methods defaults c d) (loop #'more))
          ((keyword? e) (%normalize-named-slot-specs
                         ctx (unkeywordify-syntax ctx #'arg) #'more methods defaults c d))
          (else (raise-syntax-error #f "bad slot spec" #'arg ctx)))))))

  ;; Classify one specification, retaining its syntax identity and exact refusal.
  (def (%normalize-slot-spec ctx spec methods defaults c d)
    (def (do-method name more)
      (def sym (syntax-e name))
      (unless (symbol? sym) (raise-syntax-error #f "Slot name not a symbol" ctx name))
      (if (hash-key? methods sym)
        (raise-syntax-error #f "Multiple slot methods specified" name ctx)
        (hash-put! methods sym #t))
      (c [name . more]))
    (def (do-defaults name value)
      (def sym (syntax-e name))
      (unless (symbol? sym) (raise-syntax-error #f "Slot name not a symbol" ctx name))
      (if (hash-key? defaults sym)
        (raise-syntax-error #f "Multiple slot defaults specified" name ctx)
        (hash-put! defaults sym #f))
      (d [name value]))
    (syntax-case spec (?)
      ((name value) (do-method #'name #'(value)))
      ((name ? value) (do-defaults #'name #'value))
      ((name ? . more) (raise-syntax-error #f "Invalid slot default specified" ctx #'name))
      ((name . more) (do-method #'name #'more))))

  ;; Consume one named value/operator before resuming the remaining declarations.
  (def (%normalize-named-slot-specs ctx name specs methods defaults c d)
    (def (loop spec more)
      (%normalize-slot-spec ctx spec methods defaults c d)
      (%normalize-slot-specs ctx more methods defaults c d))
    (with-syntax ((name name))
      (syntax-case specs (=> =>.+ ?)
        ((=> value-spec . more) (loop #'(name => value-spec) #'more))
        ((=>.+ value-spec . more) (loop #'(name =>.+ value-spec) #'more))
        ((? value-spec . more) (loop #'(name ? value-spec) #'more))
        ((value-spec . more) (loop #'(name value-spec) #'more))
        (() (raise-syntax-error #f "missing value after slot name" #'name (syntax->datum #'name) ctx (syntax->datum ctx))))))

  ;; Reuse construction normalization, then reject computations/defaults in matches.
  (def (normalize-slot-specs-for-match ctx specs)
    (with ([slot-methods defaults] (normalize-slot-specs ctx specs))
      (unless (null? defaults) (raise-syntax-error #f "? not allowed in patterns" ctx))
      (for/collect ((s slot-methods))
        (syntax-case s (=> =>.+ ?)
          ((slot form) #'(slot form))
          ((slot) #'(slot slot))
          ((slot ? . _) (raise-syntax-error #f "? not allowed in patterns" ctx))
          ((slot => . _) (raise-syntax-error #f "=> not allowed in patterns" ctx))
          ((slot =>.+ . _) (raise-syntax-error #f "=>.+ not allowed in patterns" ctx))
          ((slot (next-method) form) (raise-syntax-error #f "(inherited-computation) not allowed in patterns" ctx)))))))
