;;; Named recursive coordinators fence requests by their current scoped incarnation.
(export coordination call-with-coordinator)
(import (prefix-in ./recursive-approvals approvals.)
        (prefix-in ./recursive-publication publication.))

;; Private per-name identity prevents a closed generation from becoming live again.
(defstruct %incarnation (generation active?) final: #t)
;; One registry belongs to one shared graph/approval owner; access is serialized.
(defstruct %coordination (owner names) final: #t)

;; Reuse a checked publication owner without creating another graph/cache engine.
(def (coordination owner)
  (publication.snapshot owner)
  (make-%coordination owner (make-hash-table-eq)))

;; coordinate receives (generation prepare! enqueue! advance! pending?). prepare!
;; runs an existing guarded staging Reader (owner -> request) and binds its request
;; to THIS live incarnation. Once the scope exits, retained requests refuse before
;; graph construction, even if the graph and approval versions have not changed.
;; The usual on-exit outcome thunk runs after both queue and incarnation cleanup;
;; it may explicitly start a replacement while another named scope remains live.
;; This is cooperative serialized lifecycle isolation, not a thread/process lease.
(def (call-with-coordinator registry name coordinate
       on-exit: (on-exit (lambda (outcome) (outcome))))
  (unless (and (symbol? name) (procedure? coordinate) (procedure? on-exit))
    (error "recursive coordinator requires a symbol and procedure callbacks"))
  (def names (%coordination-names registry))
  (def previous (hash-ref names name #f))
  (when (and previous (%incarnation-active? previous))
    (error "recursive coordinator is already active"))
  (def incarnation (make-%incarnation (if previous (+ 1 (%incarnation-generation previous)) 1) #f))
  (def phase 'new)
  ;; A private identity and liveness test fence both saved factories and requests.
  (def (check-current)
    (unless (and (eq? phase 'active) (%incarnation-active? incarnation)
                 (eq? incarnation (hash-ref names name #f)))
      (error "stale recursive coordinator")))
  ;; Preparation retains the existing staging guards in addition to this fence.
  (def (prepare! factory)
    (check-current)
    (unless (procedure? factory) (error "recursive coordinator requires a staging reader"))
    (def request (factory (%coordination-owner registry)))
    (check-current)
    (unless (procedure? request) (error "recursive staging reader must return a request"))
    (lambda (snapshot) (check-current) (request snapshot)))
  ;; Closing only this identity cannot deactivate a replacement opened by on-exit.
  (def (close!)
    (set! phase 'closed)
    (%incarnation-active?-set! incarnation #f))
  (dynamic-wind
    (lambda ()
      (unless (eq? phase 'new) (error "recursive coordinator cannot be resumed"))
      (set! phase 'active)
      (%incarnation-active?-set! incarnation #t)
      (hash-put! names name incarnation))
    (lambda ()
      (approvals.call-with-submissions (%coordination-owner registry)
        (lambda (enqueue! advance! pending?)
          (coordinate (%incarnation-generation incarnation) prepare! enqueue! advance! pending?))
        on-exit: (lambda (outcome) (close!) (on-exit outcome))))
    close!))
