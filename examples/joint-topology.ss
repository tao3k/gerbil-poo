;;; Asymmetric component lifecycles share one atomic approval/head bundle.
(export Change. start stage-current value joint-approved?)
(import ../object
        ../mop
        ../brace
        (runtime: :clan/poo/joint-publication)
        (prefix-in (only-in ../joint-publication approval head publication stage-with) joint.)
        (runtime: :clan/poo/construction-cache)
        (prefix-in (only-in ../construction-cache Builder.) cache.)
        (runtime: :clan/poo/examples/component-membership)
        (prefix-in (only-in ./component-membership publish) initial.)
        (prefix-in ./component-rounds service.))
;; Each endpoint contributes an existing lifecycle phase and optional source edits.
;; This is ordinary POO metadata, not a new graph/closure representation.
(define-type (Change. @ [] phase) inputs: [])
;; Observe current settlement from a single captured authoritative bundle.
(def (value snapshot endpoint) (service.value (joint.head snapshot endpoint) 'settlement))
;; Whole-family admission relates actual settlements under the proposed budget.
;; Service-local admission remains separate and runs before this predicate.
(def (joint-approved? snapshot)
  (<= (+ (value snapshot 'a) (value snapshot 'b)) (.@ (joint.approval snapshot 'shared) budget)))
;; Both compact services initially settle 12; joint approval bounds their SUM,
;; allowing different supported component sets and SCC topologies at each endpoint.
;; A pure higher-order joint predicate can impose additional family relations.
(def (start joint: (joint joint-approved?))
  (def shared (.o (allowed #t) (limit 12) (budget 24)))
  (def heads (map (lambda (key)
    (defvalues (graph failure) (initial.publish #f (service.source 3 4) shared (.cc cache.Builder.)))
    (when failure (raise failure)) (cons key graph)) '(a b)))
  (joint.publication heads [(cons 'shared shared) (cons 'a (.o (allowed #t) (limit 30)))
                           (cons 'b (.o (allowed #t) (limit 30)))]
    (lambda (_) service.build-group)
    (lambda (lookup key old next) ((service.admit [(lookup 'shared) (lookup key)]) old next))
    (lambda (_ candidate) (joint candidate))))
;; Derive new shared approval values and each DIFFERENT endpoint phase from one
;; exact current snapshot. Existing declared batch/FUN closure handles all support
;; changes, SCC regrouping and dependency propagation; absent entries reapprove.
;; Values/lists/descriptors are immutable and callbacks pure/locally total.
(def (stage-current owner changes ceiling allowance builder)
  (joint.stage-with owner (lambda (snapshot)
    (values [(cons 'shared (.cc (joint.approval snapshot 'shared) limit: ceiling budget: allowance))]
      (map (lambda (entry) (cons (car entry)
        (service.contributions (.@ (cdr entry) phase) (.@ (cdr entry) inputs)))) changes))) builder: builder))
