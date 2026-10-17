;;; Shared-input invalidation across closed feedback groups and joint admission.
(export source keys required-keys build-group admit report publish)
(import ../object ../mop ../support/option ../lens-laws ../feedback-cache ../generalized-closure
        (prefix-in ../generalized-graph graph.)
        (prefix-in ../dependency-analysis code.) (prefix-in ./feedback-services service.))
;; Group support is explicit; internal feedback is closed atomically in each node.
(def keys '(quota left right stable))
;; Every service group must be available before joint approval may run.
(def required-keys '(left right stable))
;; Fresh reconstruction uses the same seed/base and existing capped-ring closure.
;; A stable builder closure is reused across source revisions, not recreated per hit.
(def (build-group quota)
  (close-feedback-group (service.prepare-services quota) service.base service.base (+ quota 2)))
;; Inspect one successful closed group using its existing callable self interface.
(def (allocation group) ((closed-view group) 'a))
;; Keep all service observation behind the existing group's closed interface.
(def (closed-view group)
  ;; group-closed is a native receipt, not a new interpreted method representation.
  (closed-interface (group-closed group)))
;; Both groups read quota; right also reads left, so a left edit invalidates right.
(def left-code (code.need 'quota build-group))
;; A shared dependency plus a cross-group edge remains an ordinary inspectable DAG.
(def right-code (code.both (code.need 'quota identity) (code.need 'left allocation)
  (lambda (quota left) (build-group (+ 1 (max quota left))))))
;; This independent cycle group must survive shared-input and sibling revisions.
(def stable-code (code.map (code.pure 2) build-group))
;; Build the immutable initial source; future edits use persistent graph operations.
(def (source quota)
  (graph.declaration keys (list (cons 'left left-code) (cons 'right right-code) (cons 'stable stable-code))
    (list (cons 'quota (some (code.make-success quota))))))
;; Current joint approval is ALWAYS reevaluated, including entirely retained caches.
;; Group capacities are allocation commitments, separate from callable charge values.
(def (admit policy)
  (lambda (_ candidate)
    (def groups (map (cut feedback-cache-ref candidate <>) required-keys))
    (and (eq? (.@ policy allowed) #t)
      (andmap (lambda (group) ((closed-view group) 'ready)) groups)
      (<= (apply + (map (lambda (group) (* 3 (allocation group))) groups)) (.@ policy limit)))))
;; Each observation uses fresh units with the existing actual combined methods.
(def (report current units)
  (map (lambda (key) (service.report (group-closed (feedback-cache-ref current key)) units)) required-keys))
;; Capture approval metadata with the existing identity-lens source guard. These
;; descriptors guard versions only here; actual group lens laws run during closure.
(def (publish old source policy builder)
  (publish-feedback-cache old source required-keys (admit policy)
    guards: [(lens-check (.lens) [policy] sources: [policy])] builder: builder))
