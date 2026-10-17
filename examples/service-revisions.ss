;;; Simultaneous SCC regrouping, shared quota migration and joint service revision.
(export keys recipe source revise build-group report admit publish revision-action)
(import (only-in :std/list/list foldl) ../object ../mop ../brace ../support/option
        ../component-closure ../generalized-closure ../feedback-cache ../feedback-graph ../lens-laws
        (prefix-in ../generalized-graph graph.) (prefix-in ../dependency-analysis code.)
        (prefix-in ./closed-declarations product.))
;; Stable support includes two quota sources, six service endpoints and a monitor.
(def keys '(quota spare shared a b c d e f monitor settlement stable))
;; Refuse unknown names so a migration never aliases a different storage position.
(def (index key)
  (let loop ((rest keys) (n 0))
    (cond ((null? rest) (error "unknown service" key))
          ((eq? key (car rest)) n) (else (loop (cdr rest) (+ n 1))))))
;; Each equation is built from existing inspectable Computation combinators.
(def (recipe deps equation)
  (code.map (foldl (lambda (dep prior)
    (code.both prior (code.need dep identity) (lambda (values value) (append values [value]))))
    (code.pure []) deps) equation))
;; Capped advancement closes multi-service cycles without an unrestricted knot.
(def (advance values) (min (car values) (+ 1 (cadr values))))
;; Old SCCs are (shared a b), (c d), with e/f separate readers of shared.
(def original (list
  (cons 'shared (recipe '(quota b) advance)) (cons 'a (recipe '(shared b) advance))
  (cons 'b (recipe '(a) car)) (cons 'c (recipe '(quota d) advance)) (cons 'd (recipe '(c) car))
  (cons 'e (recipe '(shared) car)) (cons 'f (recipe '(shared) car))))
;; Final SCCs are (shared c d), (e f); a/b split, shared migrates to spare.
;; The shared representative SURVIVES; value equality or owner symbols cannot
;; hide its changed membership, and unchanged monitor must still rebuild.
(def migrated (list
  (cons 'shared (recipe '(spare d) advance)) (cons 'a (recipe '(shared) car))
  (cons 'b (recipe '(shared) car)) (cons 'c (recipe '(shared d) advance)) (cons 'd (cdr (assq 'd original)))
  (cons 'e (recipe '(shared f) advance)) (cons 'f (recipe '(shared e) advance))))
;; This consumer's own recipe and owner never change during migration.
(def monitor-code (recipe '(shared) car))
;; Joint settlement combines endpoints from multiple current SCCs.
(def settlement-code (recipe '(a b c d e f) (lambda (values) (apply + values))))
;; An independent feedback group must keep its exact closed object.
(def stable-code (recipe '(stable) (lambda (values) (min 2 (+ 1 (car values))))))
;; Initial source preserves stable recipe identities through every later batch.
(def (source quota spare)
  (graph.declaration keys (append original [(cons 'monitor monitor-code)
    (cons 'settlement settlement-code) (cons 'stable stable-code)])
    [(cons 'quota (some (code.make-success quota))) (cons 'spare (some (code.make-success spare)))]))
;; Stage topology and input edits together; no intermediate partition is published.
;; Optional input entries use the existing graph optional-outcome representation.
(def (revise spec migrated? (inputs [])) (graph.revise spec (if migrated? migrated original) inputs))
;; Stable functional focuses are shared across all group construction callbacks.
(def focuses (map product.vector-focus '(0 1 2 3 4 5 6 7 8 9 10 11)))
;; Reuse the same lens/closure abstraction as the smaller component-services case.
(def build-group (component-group-builder keys (lambda (key) (list-ref focuses (index key)))
  (make-vector 12 0) (make-vector 12 0) 32))
;; Resolve each endpoint via the CURRENT group's actual wider raw receipt.
(def (report current)
  (map (lambda (key) (vector-ref (closed-raw (group-closed (graph-cache-ref current key))) (index key))) keys))
;; Approval simultaneously checks six service commitments, unchanged monitor and
;; current settlement, under a source guard held through the whole revision.
(def (admit policy)
  (lambda (_ current)
    (def values (report current))
    (def shared (list-ref values 2))
    (and (eq? (.@ policy allowed) #t)
      (andmap (lambda (value) (= value shared)) (map (cut list-ref values <>) '(3 4 5 6 7 8 9)))
      (= (list-ref values 10) (* 6 shared)) (<= (list-ref values 10) (.@ policy limit)))))
;; Initial publication and complete-source replacement share the original API.
(def (publish old spec policy builder)
  (publish-feedback-graph old spec build-group (admit policy)
    guards: [(lens-check (.lens) [policy] sources: [policy])] builder: builder))
;; Native FUN bind runs revision from the current source, then closes/approves the
;; final graph with the same old publication. Preparation exceptions stop suffixes.
(def (revision-action migrated? inputs policy builder)
  (feedback-graph-revision-action (lambda (spec) (revise spec migrated? inputs)) build-group (admit policy)
    guards: [(lens-check (.lens) [policy] sources: [policy])] builder: builder))
