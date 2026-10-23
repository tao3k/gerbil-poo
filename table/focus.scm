;;; Typed key focuses share the existing Lens, delta and ownership protocols.

;; Refuse incompatible keys before a backend comparison or any update callback.
(def (require-table-key descriptor key)
  (unless (element? (.@ descriptor Key) key)
    (raise-type-error (.@ descriptor Key) key 'table-focus))
  key)

;; Recognize admitted optional values without normalizing Function leaves again.
;; False is absence; (some #f) remains a stored false. Other shells are refused.
(def (require-table-option descriptor response)
  (match response
    (#f response)
    ((some value)
      (unless (element? (.@ descriptor Value) value)
        (raise-type-error (.@ descriptor Value) value 'table-focus))
      response)
    (else (error "table update must return Option" response))))

;; Capture once, install privately, then recognize the complete successor. This
;; reuses delta shell copies, unchanged-value identity and exact failure causes.
;; A custom whole-table refinement may refuse even a well-typed child replacement.
(def (update-table-focus descriptor key transform before)
  (with-table-sources (table-sources descriptor) (lambda ()
    (def delta (.call descriptor .delta/opt key transform before))
    (require-table descriptor (.call descriptor .apply-delta before delta)))))

;; Construct an ordinary Lens over either roots or style-owned states. Read and
;; update retain their originating protocol; setters take VALUE before STATE.
;; Validation is recognition only: callers admit raw Function payloads explicitly.
(def (make-table-key-focus descriptor key optional? read update guard)
  (guard (lambda () (require-table-key descriptor key)))
  (.cc (lens-of-get-set
    (lambda (input) (guard (lambda () (read input))))
    (lambda (value input)
      (guard (lambda ()
        (def response (require-table-option descriptor (if optional? value (some value))))
        (update input (lambda (_) response))))))
    ;; Lens.modify must capture ownership BEFORE the user modifier. A generic
    ;; get/transform/set sequence would otherwise overwrite a reentrant winner.
    .modify: (lambda (transform input)
      (using (transform :~ procedure?)
        (guard (lambda ()
          (update input (lambda (old)
            (def response (transform (if optional? old (option-ref old))))
            (require-table-option descriptor (if optional? response (some response)))))))))))

;; A retained raw-root focus remembers its complete origin revisions. Both
;; accessors protect those origins, including declared dependencies and child Types.
(def (table-key-focus descriptor key optional?)
  (def sources (table-sources descriptor))
  (def versions (map object-revision sources))
  ;; Supported metadata edits invalidate old focuses, including an empty read.
  (def (guard action)
    (with-table-sources sources (lambda ()
      (unless (equal? versions (map object-revision sources)) (error "stale table focus"))
      (action))))
  (make-table-key-focus descriptor key optional?
    (lambda (input)
      (require-table descriptor input)
      ((.ref descriptor (if optional? '.ref/opt '.ref)) input key))
    (lambda (input transform) (update-table-focus descriptor key transform input)) guard))
