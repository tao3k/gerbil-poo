;;; Explicit recursive declaration fragments reuse Recursive.Interaction and FUN.
(export RecursiveDeclaration. recursive-declaration-action object<-recursive-declarations)
(import :std/iter (only-in :std/list/list foldr delete-duplicates/hash)
        ./object ./mop ./declaration
        (prefix-in ./recursive recursive.) (prefix-in ./recursive-cache cached.)
        (prefix-in ./generalized-prototype gp.))
;; Ordinary inherited expansion lifts into Interaction. Extensions can request a
;; named fragment (including a later one), map its metadata, or bind several reads.
(define-type (RecursiveDeclaration. @ Declaration.)
  expand-recursive-declaration: (lambda (context form)
    (recursive.value ((.@ @ expand-declaration) context form))))
;; Compile one version of a finite named source catalog, not an ambient registry.
;; Memo is fresh PER context invocation and shared across all requested roots.
;; Callbacks/continuations must be pure, locally terminating and use immutable keys.
;; Machine depth limits recursive evaluation, not arbitrary host callback execution.
(def (recursive-declaration-action expander fragments roots budget)
  (unless (and (object? expander) (list? fragments) (list? roots)
               (andmap symbol? roots) (exact-integer? budget) (>= budget 0)
               (andmap (lambda (entry) (and (pair? entry) (symbol? (car entry))
                                            (object? (cdr entry)))) fragments)
               (= (length fragments) (length (delete-duplicates/hash (map car fragments)))))
    (error "distinct named recursive fragments and nonnegative budget required"))
  (def forms (map cdr fragments))
  (for-each instantiate-object! (cons expander forms))
  (def sources (append (cons expander forms) (map (lambda (form) (.@ form descriptor)) forms)))
  (for-each instantiate-object! sources)
  (def versions (map object-revision sources))
  (def expand (.@ expander expand-recursive-declaration))
  (def finalize (.@ expander finalize-declarations))
  ;; Root traversal is the existing Reader bind/map chain. Only fully completed
  ;; recursive receipts contribute entries; no prefix or diagnostic can publish.
  (lambda (context)
    (unless (and (object? context) (equal? versions (map object-revision sources)))
      (error "stale recursive declaration sources or invalid context"))
    (parameterize ((active-object-constructions (append sources (active-object-constructions))))
      (instantiate-object! context)
      (parameterize ((active-object-constructions (cons context (active-object-constructions))))
        (def program (.cc recursive.Generator.
          input: (.cc Type. .element?: symbol?) output: (.cc Type. .element?: list?)
          generate: (lambda (name)
            (let (entry (assq name fragments))
              (if entry (expand context (cdr entry))
                (recursive.source-error "unknown recursive declaration fragment"))))))
        (def memo (cached.empty program))
        ;; Diagnostics and source refusals stay distinct as exception irritants.
        ;; Nothing exports this tentative memo, even if later finalization fails.
        (def (resolve name)
          (defvalues (receipt next) (cached.run program name budget memo))
          (when (cached.diagnostic? receipt) (error "recursive declaration diagnostic" receipt))
          (def answer (cached.receipt-result receipt))
          (when (recursive.source-error? answer)
            (error "recursive declaration source refusal" (recursive.source-error-message answer)))
          (def entries (recursive.value-result answer))
          (unless (list? entries) (error "recursive declaration must return a finite list"))
          (set! memo next) entries)
        (def action (foldr (lambda (name rest)
          (.call gp.Observation. .bind (lambda (_) (resolve name))
            (lambda (front) (.call gp.Observation. .map (cut append front <>) rest))))
          (.call gp.Observation. .ap []) roots))
        (def entries (finalize context (action context)))
        (unless (list? entries) (error "recursive finalizer must return a finite list"))
        entries))))
;; Keep all registered sources stable through final descriptor checks and receiver
;; construction. A caller retains its old publication if this constructor refuses.
(def (object<-recursive-declarations expander context fragments roots budget
        supers: (supers []) protocol: (protocol #f))
  (def action (recursive-declaration-action expander fragments roots budget))
  (parameterize ((active-object-constructions
      (append (cons expander (map cdr fragments))
        (map (lambda (entry) (.@ (cdr entry) descriptor)) fragments) (active-object-constructions))))
    (instantiate-object! context)
    (parameterize ((active-object-constructions (cons context (active-object-constructions))))
      (object<-expanded-declarations context (action context) supers: supers protocol: protocol))))
