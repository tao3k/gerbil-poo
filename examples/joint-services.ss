;;; Consistent multi-service deployment with atomic shared policy replacement.
(export start stage stage-current value policy)
(import ../object
        ../mop
        ../brace
        (prefix-in ../joint-publication joint.)
        (runtime: :clan/poo/construction-cache)
        (prefix-in (only-in ../construction-cache Builder.) cache.)
        (runtime: :clan/poo/examples/component-membership)
        (prefix-in (only-in ./component-membership publish) initial.)
        (prefix-in ./component-rounds service.))
;; Immutable-in-practice native approval objects are replaced, never edited in place.
(def (policy ceiling (permit #t)) (.o (limit ceiling) (allowed permit)))
;; Observe an endpoint from ONE captured joint snapshot.
(def (value snapshot key) (service.value (joint.head snapshot key) 'settlement))
;; Construct approved compact graphs, then register shared/local policies and the
;; cross-endpoint consistency condition in one authoritative family.
(def (start extra-joint: (extra-joint (lambda (_ __) #t)))
  (def shared (policy 12))
  (def heads (map (lambda (key)
    (defvalues (graph failure) (initial.publish #f (service.source 3 4) shared (.cc cache.Builder.)))
    (when failure (raise failure)) (cons key graph)) '(a b)))
  (joint.publication heads [(cons 'shared shared) (cons 'a (policy 30)) (cons 'b (policy 30))]
    (lambda (_) service.build-group)
    (lambda (lookup key old next) ((service.admit [(lookup 'shared) (lookup key)]) old next))
    (lambda (old next) (and (= (value next 'a) (value next 'b)) (extra-joint old next)))))
;; Stage both endpoint edits and native policy replacements before construction.
;; Empty per-endpoint edits remain available through the general joint API.
(def (stage owner phase policies builder)
  (joint.stage owner policies (map (lambda (key) (cons key (service.contributions phase))) '(a b)) builder: builder))

;; Reprepare a shared policy from the actual current native object, retaining its
;; other fields, and stage both service phases against that SAME bundle. The caller
;; explicitly chooses the phase after a refusal or competing publication.
(def (stage-current owner phase ceiling builder)
  (joint.stage-with owner (lambda (snapshot)
    (values [(cons 'shared (.cc (joint.approval snapshot 'shared) limit: ceiling))]
      (map (lambda (key) (cons key (service.contributions phase))) '(a b)))) builder: builder))
