;;; Joint component membership edits before SCC discovery and whole publication.
(export Fragment. fragment reconfigure revision-action)
(import ./object ./mop
        ./feedback-graph (prefix-in ./construction-cache cache.)
        (prefix-in (only-in ./fun Observation.) fun.))
;; Service contributions use ordinary POO descriptors; code/base remain separate
;; namespaces, and cross-fragment references are checked only on the final graph.
(define-type (Fragment. @ [] added removed codes bases))
;; Describe one immutable contribution. Membership lists declare actual additions
;; and removals, not an alternate support view or an implicit replacement policy.
(def (fragment added removed codes (bases []))
  (.cc Fragment. added: added removed: removed codes: codes bases: bases))
(def reconfigure reconfigure-components)

;; Stage against the exact approved publication. FUN Reader bind threads that same
;; input through validation and joint revision. A later equal-valued publication
;; is still a different snapshot: stale requests refuse before preparation,
;; builders or approval. The expected object stays live in this lexical closure.
(def (revision-action expected fragments build admit guards: (guards []) builder: (builder (.cc cache.Builder.)))
  (unless (graph-cache? expected) (error "expected published component snapshot required"))
  (.call fun.Observation. .bind identity (lambda (current)
    (unless (eq? current expected) (error "stale component revision snapshot"))
    (feedback-component-revision-action fragments build admit
      guards: guards builder: builder))))
