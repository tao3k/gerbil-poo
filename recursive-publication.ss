;;; Shared sequential publication of checked recursive graphs across entry points.
(export publication current stage-with submit! observe!)
(import (prefix-in ./recursive-validation validation.))

;; One handle owns the authoritative current graph. The busy flag rejects nested
;; preparation/publication; it is not a thread lock or a concurrent CAS protocol.
(defstruct %publication (graph busy) final: #t)

;; Require a live declared catalog before handing it to any entry-point callback.
;; Existing checkpoint validation performs freshness checks without rebuilding.
(def (check-current graph)
  ((validation.validation-checkpoint graph []) graph))

;; Create one shared handle for all entry points of this revision family. Callers
;; must serialize access and keep graph metadata immutable outside supported edits.
(def (publication graph)
  (check-current graph)
  (make-%publication graph #f))

;; Read the one current head; this grants no reservation for later preparation.
(def (current owner) (%publication-graph owner))

;; Bound each operation to locally returning callbacks. Reject reentrant writes
;; before invoking user code and clear the guard on both normal and exceptional exit.
(def (with-publication owner action)
  (when (%publication-busy owner) (error "recursive publication is already active"))
  (dynamic-wind
    (lambda () (%publication-busy-set! owner #t))
    (lambda () (action (current owner)))
    (lambda () (%publication-busy-set! owner #f))))

;; Run an existing restaging Reader against the current shared head. Preparation
;; returns its guarded request, preserving all original snapshot/watch checks.
(def (stage-with owner prepare)
  (with-publication owner (lambda (graph) (check-current graph) (prepare graph))))

;; Reuse the installed graph for a fresh refinement/evidence action after an effect
;; refusal. Multiple return values and exceptions retain their original meaning.
(def (observe! owner observer)
  (with-publication owner (lambda (graph) (check-current graph) (observer graph))))

;; Requests must be guarded staging actions over the existing selective closure.
;; Their successful return already admits the whole new graph. Store
;; the new head BEFORE the observer: refusal/exception in later refine or evidence
;; cannot leave other entry points pointing at a retired graph. A graph failure
;; leaves the old head installed and never invokes the observer. No automatic retry,
;; callback-effect rollback or atomic graph-plus-effect transaction is provided.
(def (submit! owner request observer)
  (with-publication owner
    (lambda (graph)
      (def next (request graph))
      (%publication-graph-set! owner next)
      (observer next))))
