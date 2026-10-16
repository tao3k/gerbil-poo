;;; Asymmetric component lifecycles share one atomic approval/head bundle.
(export Change. start stage-current value)
(import ../object ../mop ../brace (prefix-in ../joint-publication joint.)
        (prefix-in ../construction-cache cache.) (prefix-in ./component-membership initial.)
        (prefix-in ./component-rounds service.))
;; Each endpoint contributes an existing lifecycle phase and optional source edits.
;; This is ordinary POO metadata, not a new graph/closure representation.
(define-type (Change. @ [] phase) inputs: [])
;; Observe current settlement from a single captured authoritative bundle.
(def (value snapshot endpoint) (service.value (joint.head snapshot endpoint) 'settlement))
;; Both compact services initially settle 12; joint approval bounds their SUM,
;; allowing different supported component sets and SCC topologies at each endpoint.
(def (start)
  (def shared (.o (allowed #t) (limit 12) (budget 24)))
  (def heads (map (lambda (key)
    (defvalues (graph failure) (initial.publish #f (service.source 3 4) shared (.cc cache.Builder.)))
    (when failure (raise failure)) (cons key graph)) '(a b)))
  (joint.publication heads [(cons 'shared shared) (cons 'a (.o (allowed #t) (limit 30)))
                           (cons 'b (.o (allowed #t) (limit 30)))]
    (lambda (_) service.build-group)
    (lambda (lookup key old next) ((service.admit [(lookup 'shared) (lookup key)]) old next))
    (lambda (_ candidate)
      (<= (+ (value candidate 'a) (value candidate 'b)) (.@ (joint.approval candidate 'shared) budget)))))
;; Derive new shared approval values and each DIFFERENT endpoint phase from one
;; exact current snapshot. Existing declared batch/FUN closure handles all support
;; changes, SCC regrouping and dependency propagation; absent entries reapprove.
;; Values/lists/descriptors are immutable and callbacks pure/locally total.
(def (stage-current owner changes ceiling allowance builder)
  (joint.stage-with owner (lambda (snapshot)
    (values [(cons 'shared (.cc (joint.approval snapshot 'shared) limit: ceiling budget: allowance))]
      (map (lambda (entry) (cons (car entry)
        (service.contributions (.@ (cdr entry) phase) (.@ (cdr entry) inputs)))) changes))) builder: builder))
