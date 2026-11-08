;;; Joint component membership edits before SCC discovery and whole publication.
(export Fragment. fragment reconfigure revision-action)
(import (only-in :std/list/list delete-duplicates/hash filter append-map) ./object ./mop
        ./feedback-graph (prefix-in ./construction-cache cache.) (prefix-in ./generalized-graph graph.)
        (prefix-in (only-in ./fun Observation.) fun.))
;; Service contributions use ordinary POO descriptors; code/base remain separate
;; namespaces, and cross-fragment references are checked only on the final graph.
(define-type (Fragment. @ [] added removed codes bases))
;; Describe one immutable contribution. Membership lists declare actual additions
;; and removals, not an alternate support view or an implicit replacement policy.
(def (fragment added removed codes (bases []))
  (.cc Fragment. added: added removed: removed codes: codes bases: bases))
;; Join all services before construction: reject duplicate or stale membership
;; edits, forbid remove/re-add ambiguity, and delegate provider conflict checks to
;; graph.reconfigure. Unedited survivors keep identity; additions have no latent
;; providers. The ordered union determines the final deterministic SCC key order.
;; Descriptors/lists and callbacks obey the existing immutable-source discipline.
(def (reconfigure spec fragments)
  ;; Flatten each provider namespace in deterministic contribution order.
  (def (collect field) (append-map (lambda (part) (.ref part field)) fragments))
  (def added (collect 'added))
  (def removed (collect 'removed))
  (def old-keys (.@ spec keys))
  (def old-index (make-hash-table-eq))
  (def removed-index (make-hash-table-eq))
  (for-each (lambda (key) (hash-put! old-index key #t)) old-keys)
  ;; Membership validation applies across all services, not just each descriptor.
  (def (distinct-symbols? names)
    (and (list? names) (andmap symbol? names)
      (= (length names) (length (delete-duplicates/hash names)))))
  (unless (and (distinct-symbols? added) (distinct-symbols? removed)
               (andmap (lambda (key) (not (hash-key? old-index key))) added)
               (andmap (cut hash-key? old-index <>) removed))
    (error "conflicting or stale component membership contributions"))
  (for-each (lambda (key) (hash-put! removed-index key #t)) removed)
  (graph.reconfigure spec
    (append (filter (lambda (key) (not (hash-key? removed-index key))) old-keys) added)
    (collect 'codes) (collect 'bases)))

;; Stage against the exact approved publication. FUN Reader bind threads that same
;; input through validation and joint revision. A later equal-valued publication
;; is still a different snapshot: stale requests refuse before preparation,
;; builders or approval. The expected object stays live in this lexical closure.
(def (revision-action expected fragments build admit guards: (guards []) builder: (builder (.cc cache.Builder.)))
  (unless (graph-cache? expected) (error "expected published component snapshot required"))
  (.call fun.Observation. .bind identity (lambda (current)
    (unless (eq? current expected) (error "stale component revision snapshot"))
    (feedback-graph-revision-action (lambda (spec) (reconfigure spec fragments)) build admit
      guards: guards builder: builder))))
