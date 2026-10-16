;;; Coordinated installation of snapshot-bound component revisions.
(export publication publication? current stage submit! revise-approval!)
(import (only-in :gerbil/runtime/thread with-lock) ./object ./mop ./feedback-graph ./lens-laws
        (prefix-in ./component-revision revision.) (prefix-in ./construction-cache cache.))
;; Private coordinator and staged request keep authoritative state and its lock
;; inaccessible. No setters or candidate-install API are exported.
(defstruct %publication (head lock) final: #t)
;; Requests bind one coordinator, exact old graph and existing FUN revision action.
(defstruct %request (owner expected action guards) final: #t)
;; Recognize coordinator values without exposing mutation or synchronization slots.
(def publication? %publication?)
;; Start from an already approved graph; creation does not manufacture approval.
(def (publication initial)
  (unless (graph-cache? initial) (error "approved component graph required"))
  (make-%publication initial (make-mutex 'component-publication)))
;; Read the authoritative current immutable publication under the standard lock.
(def (current owner)
  (unless (publication? owner) (error "component publication required"))
  (with-lock (%publication-lock owner) (lambda () (%publication-head owner))))
;; Serialize a registered policy write with final installation. This is one
;; ordinary native object slot update, not rollback or a multi-object transaction.
;; Concurrent writes to shared approval objects must use THIS same coordinator;
;; cross-coordinator/foreign writes and reentrant custom mutation hooks are outside
;; this protocol. Existing object revisions invalidate every old captured guard.
(def (revise-approval! owner policy slot value)
  (unless (and (publication? owner) (object? policy) (symbol? slot))
    (error "component publication and approval slot required"))
  (with-lock (%publication-lock owner) (lambda ()
    (.putslot! policy slot ($constant-slot-spec value))
    (%publication-head owner))))
;; Stage without building. Independent requests may share this exact expected
;; snapshot. Source descriptors and callbacks obey existing immutable discipline;
;; explicit guards cover mutable registered metadata through final installation.
(def (stage owner fragments build admit guards: (guards []) builder: (builder (.cc cache.Builder.)))
  (def expected (current owner))
  (make-%request owner expected
    (revision.revision-action expected fragments build admit guards: guards builder: builder) guards))
;; Execute outside the short installation lock. Re-read current state before work
;; and compare again under lock after candidate closure/current approval. A rival
;; accepted during construction/approval wins; this stale candidate never installs.
;; Both refusals and exceptions return the AUTHORITATIVE current head, which may
;; already be another request's successful publication, plus a nonfalse failure.
;; This coordinates publication only: callback side effects are not rolled back.
(def (submit! owner request)
  (try
    (unless (and (publication? owner) (%request? request) (eq? owner (%request-owner request)))
      (error "request belongs to another component publication"))
    (def expected (%request-expected request))
    (unless (eq? (current owner) expected) (error "stale component revision snapshot"))
    (def candidate ((%request-action request) expected))
    ;; Guard versions and expected head are checked under the SAME lock as all
    ;; coordinated approval revisions. No approval predicate reruns at installation.
    (with-lock (%publication-lock owner) (lambda ()
      (with-lens-checks (%request-guards request) (lambda ()
        (unless (eq? (%publication-head owner) expected) (error "stale component revision at installation"))
        (%publication-head-set! owner candidate)
        candidate))))
    (values candidate #f)
    (catch (failure) (values (current owner) failure))))
