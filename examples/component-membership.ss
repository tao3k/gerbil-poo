;;; Add/remove feedback bridges with shared invalidation and joint service approval.
(export keys compact-keys source code-edits reconfigure build-group value report admit publish revision-action)
(import ../object ../mop ../brace ../support/option ../generalized-closure ../feedback-cache ../feedback-graph ../lens-laws
        (prefix-in ../generalized-graph graph.) (prefix-in ../examples/service-revisions service.))
;; Explicit lens universe is reused; only supported components may be observed.
(def keys service.keys)
;; Initially two endpoint components have no support and must not have receipts.
(def compact-keys '(quota spare shared a b c d monitor settlement stable))
;; Compact settlement joins four endpoints; monitor is independently checked.
(def compact-settlement (service.recipe '(a b c d) (lambda (values) (apply + values))))
;; The new bridge creates mutual reachability across both former cyclic groups.
(def bridge-b (service.recipe '(a f) (lambda (values) (apply min values))))
;; C now reads shared, D and the new bridge, joining the same wider fixed point.
(def bridge-c (service.recipe '(shared d e) (lambda (values)
  (min (car values) (+ 1 (max (cadr values) (caddr values)))))))
;; Shared moves to spare in the same revision that inserts both bridge endpoints.
(def expanded-shared (service.recipe '(spare b) (lambda (values) (min (car values) (+ 1 (cadr values))))))
;; E connects shared, the second former SCC, and F; all equations use one self.
(def bridge-e (service.recipe '(shared c f) (lambda (values)
  (min (car values) (+ 1 (max (cadr values) (caddr values)))))))
;; F completes the reverse path; its presence is required by current admission.
(def bridge-f (service.recipe '(e) car))
;; Save stable original recipes for removal/re-addition without constructing services.
(def template (service.source 0 0))
;; Reuse the same key/lens family and complete-equation builder from earlier work.
(def build-group service.build-group)
;; Initial support explicitly erases E/F instead of leaving hidden code behind.
(def (source quota spare)
  (graph.reconfigure (service.source quota spare) compact-keys [(cons 'settlement compact-settlement)]))
;; All membership edits and rewiring are staged before the single SCC partition.
;; Removal restores surviving recipes AND erases both removed providers at once.
(def (reconfigure spec expanded? (inputs []))
  (graph.reconfigure spec (if expanded? keys compact-keys) (code-edits expanded?) inputs))
;; Share stable recipe edits with multi-round workflows; callers still declare
;; actual support additions/removals separately before final dependency checking.
(def (code-edits expanded?)
  (if expanded?
    [(cons 'shared expanded-shared) (cons 'b bridge-b) (cons 'c bridge-c)
     (cons 'e bridge-e) (cons 'f bridge-f) (cons 'settlement (.call template .code 'settlement))]
    [(cons 'shared (.call template .code 'shared)) (cons 'b (.call template .code 'b))
     (cons 'c (.call template .code 'c)) (cons 'settlement compact-settlement)]))
;; Resolve only current members; deleted nodes fail at graph-cache-ref, not a stale raw slot.
(def (value current key)
  (def index (let loop ((rest keys) (n 0))
    (cond ((null? rest) (error "unknown component" key))
          ((eq? key (car rest)) n) (else (loop (cdr rest) (+ n 1))))))
  (vector-ref (closed-raw (group-closed (graph-cache-ref current key))) index))
;; Observations enumerate CURRENT support, so compact publication omits removed E/F.
(def (report current) (map (cut value current <>) (.@ (graph-cache-source current) keys)))
;; Current support and all service commitments are checked together; an incomplete
;; bridge deployment cannot approve even when its surviving arithmetic converges.
(def (admit policy)
  (lambda (_ candidate)
    (def support (.@ (graph-cache-source candidate) keys))
    (def expanded? (and (memq 'e support) #t))
    (def endpoints (append '(a b c d) (if expanded? '(e f) [])))
    (and (eq? (.@ policy allowed) #t) (eq? expanded? (and (memq 'f support) #t))
      (andmap (lambda (key) (= (value candidate key) (value candidate 'shared))) (cons 'monitor endpoints))
      (= (value candidate 'settlement) (* (length endpoints) (value candidate 'shared)))
      (<= (value candidate 'settlement) (.@ policy limit)))))
;; Initial publication uses the existing guarded whole-graph admission boundary.
(def (publish old spec policy builder)
  (publish-feedback-graph old spec build-group (admit policy)
    guards: [(lens-check (.lens) [policy] sources: [policy])] builder: builder))
;; Native FUN bind preserves one old publication from preparation through approval.
(def (revision-action expanded? inputs policy builder)
  (feedback-graph-revision-action (lambda (spec) (reconfigure spec expanded? inputs)) build-group (admit policy)
    guards: [(lens-check (.lens) [policy] sources: [policy])] builder: builder))
