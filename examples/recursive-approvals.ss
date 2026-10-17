;;; Shared graph/approval revisions composed with existing entry observers.
(export policy local-admit? joint-admit? stage-transition entry-action)
(import ../object ../mop ../object-contract
        (prefix-in ../recursive-validation graph.)
        (prefix-in ../recursive-publication publication.)
        (prefix-in ../recursive-approvals approvals.)
        (prefix-in ./recursive-restaging restaging.)
        (prefix-in ./recursive-publication entry.)
        (prefix-in ./recursive-topology service.))

;; Immutable-in-use approval metadata declares per-entry ceilings and one shared
;; budget, plus the exact current shape/reader expected by whole-value refinement.
(def (policy target-vector provider-vector reader expected-total (budget-limit 200) (first-weight 2))
  (.o targets: target-vector providers: provider-vector chosen: reader expected: expected-total
      ceilings: '(200 200 200) budget: budget-limit weight: first-weight))

;; Each entry independently admits the checked graph and expected computed links.
;; Standard andmap and existing envelope refinement reuse the actual Type protocol.
(def (local-admit? proposed candidate)
  (def total (.get (graph.closed-ref candidate 'report) total))
  (and (andmap (lambda (ceiling) (<= total ceiling)) (.get proposed ceilings))
       (null? (diagnose (service.envelope candidate (.get proposed expected)
         (.get proposed targets) (.get proposed providers) (.get proposed chosen))
         (.o report: (graph.closed-ref candidate 'report))))))

;; The joint rule can refuse despite every local ceiling/shape check passing.
(def (joint-admit? _installed proposed candidate)
  (and (local-admit? proposed candidate)
       (<= (.get (graph.closed-ref candidate 'report) total) (.get proposed budget))))

;; Reuse membership-aware FUN preparation and the existing selective closure.
;; Its new final admission hook runs before old graph/reference retirement.
(def (stage-transition owner proposed admit: (admit joint-admit?))
  (approvals.stage-with owner proposed
    (lambda (current final-admission)
      ((restaging.transition-action (.get proposed targets) (.get proposed providers)
        (.get proposed chosen) #t (.get proposed weight) admit: final-admission) current))
    admit))

;; Read graph and policy from ONE installed snapshot, then compose the existing
;; refine/bind-evidence observer with this entry's independent invocation/context.
(def (entry-action invocation context)
  (lambda (state)
    (def proposed (publication.snapshot-metadata state))
    ((entry.entry-action (.get proposed expected) (.get proposed targets)
       (.get proposed providers) (.get proposed chosen) invocation context)
      (publication.snapshot-graph state))))
