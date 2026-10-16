;;; Replace endpoints in two SCCs while migrating their shared input atomically.
(export source contributions reconfigure revision-action admit value report build-group)
(import ../object ../mop ../brace ../feedback-graph ../lens-laws
        (prefix-in ../component-revision revision.)
        (prefix-in ./service-revisions recipes.) (prefix-in ./component-membership service.))
;; Reuse the original compact source and the existing stable lens/closure family.
(def source service.source)
;; The fixed carrier and current-owner observations are shared with prior examples.
(def build-group service.build-group)
;; Read actual current closed receipts; removed raw positions are never components.
(def value service.value)
;; Enumerate only the final declaration's active support.
(def report service.report)
;; Shared now reads spare and replacement E; capped advancement closes its new SCC.
(def shared-code (recipes.recipe '(spare e) (lambda (vs) (min (car vs) (+ 1 (cadr vs))))))
;; Service A depends on E contributed by another service, not an intermediate graph.
(def a-code (recipes.recipe '(shared e) (lambda (vs) (min (car vs) (+ 1 (cadr vs))))))
;; E replaces B and completes the shared/A cycle.
(def e-code (recipes.recipe '(a) car))
;; C/F close separately using the already closed shared SCC as their external input.
(def c-code (recipes.recipe '(shared f) (lambda (vs) (min (car vs) (+ 1 (cadr vs))))))
;; F replaces D; it must never inherit an old inactive definition.
(def f-code (recipes.recipe '(c) car))
;; Settlement joins both replacement services; the monitor recipe stays unchanged.
(def settlement-code (recipes.recipe '(a c e f) (lambda (vs) (apply + vs))))
;; Independent service contributions are combined once, before validating reads.
;; The first contribution intentionally refers to not-yet-submitted E/F providers.
(def contributions
  [(revision.fragment [] '(b) [(cons 'shared shared-code) (cons 'a a-code)])
   (revision.fragment '(e) [] [(cons 'e e-code)])
   (revision.fragment '(f) '(d) [(cons 'c c-code) (cons 'f f-code)])
   (revision.fragment [] [] [(cons 'settlement settlement-code)])])
;; A single batch preserves the old snapshot until every contribution is accepted.
(def (reconfigure spec) (revision.reconfigure spec contributions))
;; Current joint approval checks the support replacement and every service result.
(def (admit policy)
  (lambda (_ candidate)
    (def keys (.@ (graph-cache-source candidate) keys))
    (and (eq? (.@ policy allowed) #t) (not (memq 'b keys)) (not (memq 'd keys))
      (andmap (lambda (key) (and (memq key keys) (= (value candidate key) (value candidate 'shared))))
        '(a c e f monitor))
      (= (value candidate 'settlement) (* 4 (value candidate 'shared)))
      (<= (value candidate 'settlement) (.@ policy limit)))))
;; Existing FUN revision bind carries one publication through final SCC closure and
;; guarded current approval. No service fragment has its own publication boundary.
(def (revision-action policy builder)
  (feedback-graph-revision-action reconfigure build-group (admit policy)
    guards: [(lens-check (.lens) [policy] sources: [policy])] builder: builder))
