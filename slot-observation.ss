;;; Receiver-bound read observations shared by every object access route.
;;; Values are still computed by object.ss; this module only records/replays.
(export make-slot-read slot-read-key slot-read-receiver
        slot-read-revision slot-read-instance slot-read-value slot-read-dependencies
        call-with-slot-read-observer without-observation
        %slot-read-active? %slot-read-demand! %deliver-slot-read
        %call-with-recorded-slot-reads)
(import :std/error)
(defstruct slot-read (receiver key revision instance value dependencies current? birth)
  final: #t constructor: :init!)
;; Keep the public seven-argument raw constructor. It never mints provenance.
(defmethod {:init! slot-read}
  (lambda (self receiver key revision instance value dependencies current?)
    (struct-instance-init! self
      receiver key revision instance value dependencies current? #f)))
(def read-frame (make-parameter #f))
(def read-observers (make-parameter '()))
(def read-prechecks (make-parameter '()))
(def (%slot-read-active?) (or (read-frame) (pair? (read-observers))))
(def (without-observation action)
  (parameterize ((read-frame #f) (read-observers '()) (read-prechecks '()))
    (action)))
;; Check sources before invoking a potentially cold getter. Metadata inspection
;; must not recursively observe itself; outer source collectors remain active.
(def (%slot-read-demand! receiver key)
  (let (checks (read-prechecks))
    (unless (null? checks)
      (without-observation
        (lambda () (for-each (lambda (check) (check receiver key)) checks))))))
(def (%call-with-recorded-slot-reads action)
  (def frame (box '()))
  (def value (parameterize ((read-frame frame)) (action)))
  (values value (reverse (unbox frame))))
(def (%deliver-slot-read read value)
  (when (read-frame)
    (set-box! (read-frame) (cons read (unbox (read-frame)))))
  (let (observers (read-observers))
    (unless (null? observers)
      (without-observation
        (lambda () (for-each (lambda (observe) (observe read)) observers)))))
  value)
;; Nested observers receive the same actual reads. Final replay is owned by the
;; consumer's admission boundary, not memoized as a successful previous check.
(def (call-with-slot-read-observer observe action before: (before #f))
  (unless (and (procedure? observe) (procedure? action)
               (or (not before) (procedure? before)))
    (error "invalid slot-read observer"))
  (parameterize ((read-observers (cons observe (read-observers)))
                 (read-prechecks (if before (cons before (read-prechecks)) (read-prechecks))))
    (action)))
