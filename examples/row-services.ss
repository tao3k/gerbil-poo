;;; Closed recursive service trees with inferred row extensions and FUN admission.
(export Tree ServiceType service-expression admit-service shared-service publish-service)
(import ../object
        ../mop
        ../types/relation
        ../prototype-types
        ../object-contract
        ../object-contract-flow
        (runtime: :clan/poo/examples/polymorphic-services)
        (prefix-in (only-in ./polymorphic-services publish-service) publication.))
;; A finite guarded approximation accepts leaves with no children. Three unfoldings
;; bound observations without tying a host recursive descriptor knot.
(def Tree '(Mu Node 3 (Object ((value UInt) (adjust (Function (UInt) (Integer)))
                              (children (List Node))) closed)))
;; One row parameter uses the existing positional Type specialization protocol.
(def Service (.o .parameters: '(Extra)))
;; The explicit fields are disjoint from Extra; closed tails enforce exact keys.
(def service-expression
  `(Object ((handler (Function (UInt) (Integer))) (roots (List ,Tree))) (Row Extra)))
;; The same schema drives finite inference and ordinary recursive contract building.
(def ServiceType (prototype-type Service '(Extra) service-expression []))
;; Existing FUN composition wraps all nested methods before whole-object policy.
(def (admit-service instance maximum consume)
  (let (contract (refine (.get instance descriptor)
                  (lambda (candidate location)
                    (if (<= ((.get candidate handler) -5) maximum) []
                      (list (.o bind-these: #f kind: 'service-limit path: location))))))
    (checked-action contract consume)))
;; Two roots share one immutable leaf. Validation may normalize each occurrence;
;; no graph-identity preservation or cross-context approval reuse is asserted.
(def (shared-service)
  (let* ((leaf (.o value: 1 adjust: abs children: []))
         (root (.o value: 2 adjust: abs children: (list leaf leaf))))
    (.o handler: abs roots: (list root leaf) audit: 3)))
;; Reuse the existing exact subject/descriptor/context publication boundary.
(def publish-service publication.publish-service)
