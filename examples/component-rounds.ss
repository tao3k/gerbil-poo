;;; Multi-round SCC merge/split with component replacement and shared migration.
(export source build-group value report contributions admit revision-action)
(import (only-in :std/list/list filter) ../object ../mop ../brace ../feedback-graph ../lens-laws
        (prefix-in ../component-revision revision.)
        (prefix-in ./component-membership membership.) (prefix-in ./component-migration migration.))
;; Initial compact publication and the fixed lawful lens family are reused.
(def source membership.source)
;; Whole feedback groups use the existing source-driven lens/closure builder.
(def build-group membership.build-group)
;; Current partition owners determine observations, never old carrier positions.
(def value membership.value)
;; Reports enumerate only active support, whose order may evolve across rounds.
(def report membership.report)
;; Stable original recipes restore both deleted endpoints explicitly; no latent
;; provider is allowed to reappear merely because a name is added back.
(def template (source 0 0))
;; Joining bridge nodes uses exactly the earlier validated merge recipe family.
(def merged [(revision.fragment '(e f) [] (membership.code-edits #t))])
;; E/F already exist after merging. Reuse replacement service contributions while
;; keeping their independent code namespaces and deleting the old B/D endpoints.
(def replaced (map (lambda (part) (.cc part added: [])) migration.contributions))
;; Returning to compact support restores A as well as shared/B/C/D/settlement;
;; A's replacement recipe otherwise retains a dangling read of deleted E.
(def restored [(revision.fragment '(b d) '(e f)
  (map (lambda (key) (cons key (.call template .code key))) '(shared a b c d settlement)))])
;; Every round joins all service contributions and optional inputs once. Invalid
;; phase transitions refuse through ordinary current-support checks, not a counter.
(def (contributions phase (inputs []))
  (append (case phase ((merge) merged) ((replace) replaced) ((restore) restored)
            (else (error "unknown component revision phase" phase)))
    (if (null? inputs) [] [(revision.fragment [] [] [] inputs)])))
;; Joint approval derives current endpoints from support and requires complete
;; B/D and E/F pairs. Every endpoint and unchanged monitor agrees with shared;
;; both service policies must approve this exact candidate on EVERY round.
(def (admit policies)
  (lambda (_ candidate)
    (def keys (.@ (graph-cache-source candidate) keys))
    (def present? (lambda (key) (and (memq key keys) #t)))
    (def endpoints (filter present? '(a b c d e f)))
    (and (andmap present? '(quota spare shared a c monitor settlement stable))
      (eq? (present? 'b) (present? 'd)) (eq? (present? 'e) (present? 'f))
      (or (present? 'b) (present? 'e))
      (andmap (lambda (key) (= (value candidate key) (value candidate 'shared))) (cons 'monitor endpoints))
      (= (value candidate 'settlement) (* (length endpoints) (value candidate 'shared)))
      (andmap (lambda (policy) (and (eq? (.@ policy allowed) #t)
        (<= (value candidate 'settlement) (.@ policy limit)))) policies))))
;; Snapshot-bound FUN actions cannot be replayed on a later publication, even
;; after support and values return. Both mutable service approvals remain guarded.
(def (revision-action expected phase inputs policies builder)
  (revision.revision-action expected (contributions phase inputs) build-group (admit policies)
    guards: [(lens-check (.lens) policies sources: policies)] builder: builder))
