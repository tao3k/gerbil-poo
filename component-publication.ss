;;; Coordinated installation of snapshot-bound component revisions.
(export approval-domain publication publication? current snapshot snapshot-graph snapshot-metadata
        stage restage submit! submit-snapshot! call-with-snapshot revise-approval!)
(import (only-in :gerbil/runtime/thread with-lock) ./object ./mop ./feedback-graph ./lens-laws
        (prefix-in ./construction-cache cache.))
;; Private coordination records never expose setters or candidate-install APIs.
(defstruct %approval-domain (lock) final: #t)
(defstruct %snapshot (graph metadata) final: #t)
(defstruct %publication (head domain) final: #t)
;; Each independent stage gets its own lineage. Only explicit restage advances
;; its private counter; merely sharing an old snapshot does not merge requests.
(defstruct %lineage (version invalidation) final: #t)
(defstruct %request (owner expected action guards metadata lineage version) final: #t)
(def +keep-metadata+ (vector 'keep-publication-metadata))
(def publication? %publication?)
(def snapshot-graph %snapshot-graph)
(def snapshot-metadata %snapshot-metadata)
(def (approval-domain) (make-%approval-domain (make-mutex 'approval-domain)))
(def (metadata! value)
  (unless (or (not value) (object? value)) (error "publication metadata must be a POO object or #f")))
;; An approved value graph remains the admission premise. Associated metadata
;; does not manufacture source approval and follows the same immutable discipline.
(def (publication initial domain: (domain (approval-domain)) metadata: (metadata #f))
  (unless (graph-cache? initial) (error "approved component graph required"))
  (unless (%approval-domain? domain) (error "shared approval domain required"))
  (metadata! metadata)
  (graph-cache-current! initial)
  (make-%publication (make-%snapshot initial metadata) domain))
(def (locked owner action)
  (unless (publication? owner) (error "component publication required"))
  (with-lock (%approval-domain-lock (%publication-domain owner)) action))
;; This is a historical observation, not a reservation or a live source check.
(def (snapshot owner) (locked owner (lambda () (%publication-head owner))))
(def (current owner) (snapshot-graph (snapshot owner)))
(def (require-current! owner expected)
  (unless (eq? (%publication-head owner) expected) (error "stale component revision snapshot")))
(def (require-request! owner request)
  (unless (and (publication? owner) (%request? request) (eq? owner (%request-owner request)))
    (error "request belongs to another component publication")))
;; Called under the coordinator domain lock. Neither check invokes user code.
(def (request-current! owner request)
  (require-current! owner (%request-expected request))
  (require-version! (%request-lineage request) (%request-version request)))
(def (require-version! lineage version)
  (unless (= version (%lineage-version lineage))
    (error "stale component revision ticket")))
(def (revise-approval! owner policy slot value)
  (unless (and (publication? owner) (object? policy) (symbol? slot))
    (error "component publication and approval slot required"))
  (locked owner (lambda ()
    (.putslot! policy slot ($constant-slot-spec value))
    (snapshot-graph (%publication-head owner)))))
(def (make-request owner expected fragments build admit guards builder metadata lineage version)
  (unless (eq? metadata +keep-metadata+) (metadata! metadata))
  (def (invalidation)
    (locked owner (lambda ()
      (require-current! owner expected)
      (require-version! lineage version)
      (unless (%lineage-invalidation lineage)
        (%lineage-invalidation-set! lineage
          (cache.cache-invalidation (graph-cache-values (snapshot-graph expected)))))
      (%lineage-invalidation lineage))))
  (make-%request owner expected
    (feedback-component-revision-action fragments build admit
      guards: guards builder: builder invalidation: invalidation)
    guards (if (eq? metadata +keep-metadata+) (snapshot-metadata expected) metadata) lineage version))
;; Stage a fresh independent proposal, with no business construction. Capture
;; inherited metadata from the SAME snapshot as the revision action.
(def (stage owner fragments build admit guards: (guards []) builder: (builder (.cc cache.Builder.))
            metadata: (metadata +keep-metadata+))
  (def expected (snapshot owner))
  (make-request owner expected fragments build admit guards builder metadata (make-%lineage 0 #f) 0))
;; Replace the complete proposal in one explicit family; do not append/merge
;; opaque fragments or callbacks. Advance before preparing the replacement so
;; a failure cannot reactivate the predecessor's already-issued ticket.
(def (restage owner previous fragments build admit guards: (guards []) builder: (builder (.cc cache.Builder.))
              metadata: (metadata +keep-metadata+))
  (require-request! owner previous)
  (unless (eq? metadata +keep-metadata+) (metadata! metadata))
  (def version
    (locked owner (lambda ()
      (request-current! owner previous)
      (def lineage (%request-lineage previous))
      (def next (1+ (%lineage-version lineage)))
      (%lineage-version-set! lineage next)
      next)))
  (make-request owner (%request-expected previous) fragments build admit guards builder metadata
    (%request-lineage previous) version))
;; Invoke callbacks outside the head lock. Ordinary .get remains unchanged;
;; consumers of a live publication use this boundary plus their source guards.
(def (call-with-snapshot owner action guards: (guards []))
  (def expected (snapshot owner))
  (def (require-live!)
    (locked owner (lambda ()
      (require-current! owner expected)
      (graph-cache-current! (snapshot-graph expected))
      ;; A sibling can revise policy in this domain without moving the head.
      ;; The thread-local write guard cannot protect against that sibling.
      (with-lens-checks guards void))))
  (with-lens-checks guards (lambda ()
    (require-live!)
    (call-with-values (lambda () (action expected))
      (lambda results
        (require-live!)
        (apply values results))))))
;; Return the complete installed/refused snapshot. Graph and metadata are ONE
;; pointer update; reentrant/rival commits cannot leak a mixed return pair.
(def (submit-snapshot! owner request)
  (try
    (require-request! owner request)
    (locked owner (lambda () (request-current! owner request)))
    (def graph ((%request-action request) (snapshot-graph (%request-expected request))))
    (def candidate (make-%snapshot graph (%request-metadata request)))
    (locked owner (lambda ()
      (with-lens-checks (%request-guards request) (lambda ()
        (request-current! owner request)
        (graph-cache-current! graph)
        (%publication-head-set! owner candidate)
        (%lineage-invalidation-set! (%request-lineage request) #f)))))
    (values candidate #f)
    (catch (failure) (values (snapshot owner) failure))))
;; Existing value-only consumers keep their existing value result. This is a
;; projection of the same coordinator operation, not a second publication path.
(def (submit! owner request)
  (defvalues (result failure) (submit-snapshot! owner request))
  (values (snapshot-graph result) failure))
