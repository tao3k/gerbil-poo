;; Persistent seek backends admit roots by identity. Point-update outputs may be
;; recorded only under the explicit .shape-preserving? law, after an admitted input
;; and Key. Weak keys retain no snapshots; failures and arbitrary inputs never gain
;; provenance. Callers guard metadata before either admission or output recording.
(def (table-shape-checker source)
  (if (.has? source Comparer .seek<-)
    (let ((admitted (make-table test: eq? weak-keys: #t))
          (preserves? (and (.has? source .shape-preserving?) (eq? (.@ source .shape-preserving?) #t))))
      (lambda (root (updated? #f))
        (cond
          (updated? (when preserves? (table-set! admitted root #t)))
          ((not (table-ref admitted root #f))
            (.call source .validate-shape root)
            (table-set! admitted root #t))) root))
    (lambda (root (updated? #f)) (if updated? root (.call source .validate-shape root)))))

;; Recognize carrier and child membership without constructing normalized wrappers.
;; Catch only typed refusal; user/backend exceptions preserve their original cause.
(def (table-element? descriptor source)
  (try
    (.call descriptor .validate-shape source)
    ;; Recognition must not reenter the public query's complete-root admission.
    (not (table-entry-match descriptor
      (lambda (key value)
        (and (element? (.@ descriptor Key) key) (element? (.@ descriptor Value) value))) source #f #f))
    (catch (TypeError? _) #f)))

;; Validate a persistent table through its current public representation protocol.
;; Admit the carrier, normalize children, then privately rebuild and recognize the result.
(def (validate-table descriptor source (normalize #f))
  (with-table-sources (table-sources descriptor) (lambda ()
    (.call descriptor .validate-shape source)
    ;; Same-child-Type views may supply a complete source normalization. The
    ;; shared boundary still owns receiver refinements and metadata protection.
    ;; Ordinary backends retain their original child and collision/error order.
    (require-table descriptor
      (if normalize (normalize source)
        (let* ((key (.@ descriptor Key)) (value (.@ descriptor Value)))
          (validate-bindings (cut validate key <>) (cut validate value <>) source
            (.call descriptor .list<- source)
            (lambda (checked)
              (rebuild-bindings descriptor source checked (lambda () (.@ descriptor .empty))
                (.@ descriptor .key?) (.@ descriptor .acons))))))))))

;; Share whole-source normalization only when both child Type identities match.
;; An inherited view with overridden Types retains the ordinary validator instead
;; of assuming that two unrelated normalization functions commute.
(def (table-view-validator descriptor source normalize)
  (cut validate-table descriptor <>
    (and (eq? (.@ descriptor Key) (.@ source Key))
         (eq? (.@ descriptor Value) (.@ source Value)) normalize)))
