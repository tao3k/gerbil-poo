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
(defstruct read-collection (seen reversed) final: #t)
;; One dynamic binding owns the complete observation scope: #f when disabled,
;; the existing collection for capture alone, or a scope with actual observers.
;; Capture alone allocates no extra context. parameterize still owns nesting,
;; exceptions, continuations and the standard inherited thread scope.
(defstruct read-scope (frame observers prechecks) final: #t)
;; The standard dynamic parameter provides lexical restoration and inheritance.
(def current-read-scope (make-parameter #f))
;; Preserve the existing frame-or-Boolean result, with one parameter lookup.
(def (%slot-read-active?)
  (let (scope (current-read-scope))
    (if (read-scope? scope)
      (or (read-scope-frame scope) (pair? (read-scope-observers scope))) scope)))
;; An already disabled scope needs no new dynamic binding. Active observation
;; suppresses capture, callbacks and prechecks together while this action runs.
(def (without-observation action)
  (if (current-read-scope)
    (parameterize ((current-read-scope #f)) (action))
    (action)))
;; Check sources before invoking a potentially cold getter. Metadata inspection
;; must not recursively observe itself; outer source collectors remain active.
(def (%slot-read-demand! receiver key)
  (let* ((scope (current-read-scope)) (checks (if (read-scope? scope) (read-scope-prechecks scope) '())))
    (unless (null? checks)
      (without-observation
        (lambda () (for-each (lambda (check) (check receiver key)) checks))))))
;; Replace only the capture frame; retain the actual observer/precheck payloads.
(def (%call-with-recorded-slot-reads action unique-roots?: (unique-roots? #f))
  ;; Only replay-root consumers opt in. Dependency capture keeps every
  ;; edge occurrence; no signed dependency list is edited or reconstructed.
  (unless (boolean? unique-roots?) (error "invalid root collection policy"))
  (def frame (make-read-collection (and unique-roots? (make-hash-table-eq)) '()))
  (def parent (current-read-scope))
  (def value (parameterize ((current-read-scope
    (if (read-scope? parent)
      (make-read-scope frame (read-scope-observers parent) (read-scope-prechecks parent))
      frame))) (action)))
  (values value (reverse (read-collection-reversed frame))))
;; Record the original read, then deliver it in order without observing callbacks.
(def (%deliver-slot-read read value)
  (def scope (current-read-scope))
  (def observed? (read-scope? scope))
  (let (frame (if observed? (read-scope-frame scope) scope))
    (when frame
      (let (seen (read-collection-seen frame))
        (unless (and seen (hash-key? seen read))
          (when seen (hash-put! seen read #t))
          (set! (read-collection-reversed frame)
            (cons read (read-collection-reversed frame)))))))
  ;; Deduplicate storage, NEVER delivery. Duplicate events, observer ordering,
  ;; effects and exceptions keep their original per-delivery boundary.
  (let (observers (if observed? (read-scope-observers scope) '()))
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
  (def parent (current-read-scope))
  (def observed? (read-scope? parent))
  (def checks (if observed? (read-scope-prechecks parent) '()))
  (parameterize ((current-read-scope
      (make-read-scope (if observed? (read-scope-frame parent) parent)
        (cons observe (if observed? (read-scope-observers parent) '()))
        (if before (cons before checks) checks))))
    (action)))
