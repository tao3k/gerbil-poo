;;; Bounded native thread composition for already-approved joint receipts.
(export install-concurrently)
(import (prefix-in ./joint-workers workers.))
;; Standard channels form a ready/release rendezvous AFTER all approval calls.
;; before-release may coordinate declared external changes while workers wait;
;; it must return locally. Results retain completion order, not input order.
;; Each worker uses existing install!, so the owner lock remains the only
;; publication critical section. No approval or automatic retry happens here.
;; A pure report maps receipt/snapshot/failure to a caller-chosen result outside
;; the owner lock; it can preserve provenance for mixed-generation submissions.
(def (install-concurrently owner receipts before-release: (before-release void)
     report: (report (lambda (_ snapshot failure) (cons snapshot failure))))
  (unless (list? receipts) (error "proper joint receipt list required"))
  (workers.call-with-installations owner (lambda (start receive)
    (def release (map start receipts))
    (before-release)
    (for-each (lambda (go) (go)) release)
    (map (lambda (_) (receive)) receipts)) report: report))
