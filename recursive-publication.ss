;;; Shared sequential publication of checked recursive graphs across entry points.
(export publication current stage-with submit! observe!
        snapshot snapshot-graph snapshot-metadata stage-joint-with submit-joint! observe-joint!)
(import (prefix-in ./recursive-validation validation.))

;; One handle owns the authoritative current graph. The busy flag rejects nested
;; preparation/publication; it is not a thread lock or a concurrent CAS protocol.
(defstruct %snapshot (graph metadata) final: #t)
;; Read-only projections expose one captured publication unit, not constructors.
(def snapshot-graph %snapshot-graph)
;; Metadata is shared by every entry observing this same captured snapshot.
(def snapshot-metadata %snapshot-metadata)
;; One private whole-snapshot pointer is replaced at publication, so graph and
;; shared metadata can never be projected from different installed rounds.
(defstruct %publication (snapshot busy) final: #t)

;; Require a live declared catalog before handing it to any entry-point callback.
;; Existing checkpoint validation performs freshness checks without rebuilding.
(def (check-current graph)
  ((validation.validation-checkpoint graph []) graph))

;; Create one shared handle for all entry points of this revision family. Callers
;; must serialize access and keep graph metadata immutable outside supported edits.
(def (publication graph metadata: (metadata #f))
  (check-current graph)
  (make-%publication (make-%snapshot graph metadata) #f))

;; Capture the complete immutable publication unit for consistent projections.
(def (snapshot owner) (%publication-snapshot owner))

;; Read the one current head; this grants no reservation for later preparation.
(def (current owner) (snapshot-graph (snapshot owner)))

;; Bound each operation to locally returning callbacks. Reject reentrant writes
;; before invoking user code and clear the guard on both normal and exceptional exit.
(def (with-publication owner action)
  (when (%publication-busy owner) (error "recursive publication is already active"))
  (dynamic-wind
    (lambda () (%publication-busy-set! owner #t))
    (lambda () (action (snapshot owner)))
    (lambda () (%publication-busy-set! owner #f))))

;; Run an existing restaging Reader against the current shared head. Preparation
;; returns its guarded request, preserving all original snapshot/watch checks.
(def (stage-with owner prepare)
  (stage-joint-with owner (lambda (state) (prepare (snapshot-graph state)))))

;; Prepare from one exact graph/metadata snapshot while guarding reentrant writes.
(def (stage-joint-with owner prepare)
  (with-publication owner (lambda (state) (check-current (snapshot-graph state)) (prepare state))))

;; Reuse the installed graph for a fresh refinement/evidence action after an effect
;; refusal. Multiple return values and exceptions retain their original meaning.
(def (observe! owner observer)
  (observe-joint! owner (lambda (state) (observer (snapshot-graph state)))))

;; Retry refinement/evidence against one current graph/metadata pair, without closure.
(def (observe-joint! owner observer)
  (with-publication owner (lambda (state) (check-current (snapshot-graph state)) (observer state))))

;; Requests must be guarded staging actions over the existing selective closure.
;; Their successful return already admits the whole new graph. Store
;; the new head BEFORE the observer: refusal/exception in later refine or evidence
;; cannot leave other entry points pointing at a retired graph. A graph failure
;; leaves the old head installed and never invokes the observer. No automatic retry,
;; callback-effect rollback or atomic graph-plus-effect transaction is provided.
(def (submit! owner request observer)
  (submit-joint! owner
    (lambda (state) (values (request (snapshot-graph state)) (snapshot-metadata state)))
    (lambda (state) (observer (snapshot-graph state)))))

;; A guarded joint request returns an admitted graph and its metadata. Both become
;; current by ONE snapshot write before any external observer, including a refusing
;; observer. Preparation/admission failures happen before that write. Callbacks must
;; use the existing guarded graph closure protocol and caller-serialized access.
(def (submit-joint! owner request observer)
  (with-publication owner
    (lambda (state)
      (defvalues (graph metadata) (request state))
      (def next (make-%snapshot graph metadata))
      (%publication-snapshot-set! owner next)
      (observer next))))
