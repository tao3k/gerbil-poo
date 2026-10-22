;;; Pure values, mutable identities and consuming state references share one backend.

;; A fresh immutable head identifies a generation even when the value returns to
;; an equal snapshot. False denotes consumed ownership, never a stored table value.
(defstruct %table-head (value) final: #t)
;; Constructors and mutable fields remain private to the existing table module.
(defstruct %table-reference (owner style head lock) final: #t)

;; Derive all three styles from one persistent table. Operations stage callbacks
;; outside the lock, then compare the captured head before one whole installation.
;; Pure backend callbacks and immutable leaves are explicit ownership premises.
(def (table-styles source)
  (def sources (table-sources source))
  (def versions (map object-revision sources))
  (def owner (list source))
  ;; Retain every backend/converter origin across admission and user callbacks.
  (def (guard action)
    (with-table-sources sources (lambda ()
      (unless (equal? versions (map object-revision sources))
        (error "stale table styles"))
      (action))))
  ;; Allocate one private capability; no capability constructor is public.
  (def (reference style value)
    (make-%table-reference owner style (make-%table-head value) (make-mutex 'table-reference)))
  ;; Foreign styles/factories refuse before any user callback or ownership change.
  (def (check style input)
    (unless (and (%table-reference? input) (eq? (%table-reference-owner input) owner)
                 (eq? (%table-reference-style input) style))
      (error "incompatible table reference")))
  ;; Capture one live generation under the official runtime lock mechanism.
  (def (capture style input)
    (check style input)
    (with-lock (%table-reference-lock input) (lambda ()
      (or (%table-reference-head input) (error "consumed table reference")))))
  ;; Commit only the exact captured generation. Reentrant/competing installations
  ;; may win, but an older callback can never overwrite their result or resurrect it.
  (def (install input expected next)
    (with-lock (%table-reference-lock input) (lambda ()
      (unless (eq? (%table-reference-head input) expected)
        (error "stale table reference"))
      (set! (%table-reference-head input) next))))
  ;; One higher-order constructor supplies the same complete API for every style.
  (def (derive style)
    ;; Wrap an already admitted snapshot without replacing Function identities.
    (def (create value)
      (guard (lambda ()
        (def admitted (require-table source value))
        (if (eq? style 'pure) admitted (reference style admitted)))))
    ;; Snapshot observation never consumes ownership; returned pure roots are shared.
    (def (read input)
      (guard (lambda ()
        (if (eq? style 'pure) (require-table source input)
          (%table-head-value (capture style input))))))
    ;; Stage a single-result pure transformation, then admit without rewrapping.
    ;; Refusal, exception or conflict before installation preserves the old head.
    (def (step input transform)
      (using (transform :~ procedure?)
        (guard (lambda ()
          (def expected (and (not (eq? style 'pure)) (capture style input)))
          (def before (if expected (%table-head-value expected) (require-table source input)))
          (def after (require-table source (transform before)))
          (case style
            ((pure) after)
            ((mutable) (install input expected (make-%table-head after)) input)
            ((linear)
             ;; Prepare the successor before consuming; allocation failure cannot
             ;; retire the only reference. A losing staged successor never escapes.
             (let (successor (reference 'linear after))
               (install input expected #f)
               successor)))))))
    ;; Conversion transfers owned references, including same-style conversion.
    ;; Use .unap for a nonconsuming snapshot; pure sources need no retirement.
    (def (convert input target)
      (unless (memq target '(pure mutable linear)) (error "unknown table style" target))
      (guard (lambda ()
        (def expected (and (not (eq? style 'pure)) (capture style input)))
        (def value (if expected (%table-head-value expected) (require-table source input)))
        (def result (if (eq? target 'pure) value (reference target value)))
        (when expected (install input expected #f))
        result)))
    (.cc Wrapper.
      Domain: source
      ;; Raw input has a separate normalization boundary; .ap preserves admitted roots.
      .admit: (lambda (value) (guard (lambda () (create (validate source value)))))
      .ap: create .unap: read
      .bind: (lambda (input f) (guard (lambda () (f (read input)))))
      .map: (lambda (f input) (step input f))
      .step: step .convert: convert
      ;; Whole deltas/batches reuse the original optimistic conflict protocol.
      .apply-delta: (lambda (input delta) (step input (cut .call source .apply-delta <> delta)))
      .apply-batch: (lambda (input batch) (step input (lambda (before)
        (.call source .apply-delta before (.call source .compose-deltas batch)))))))
  (.cc Type. Pure: (derive 'pure) Mutable: (derive 'mutable) Linear: (derive 'linear)))
