;;; Collection IO reuses existing List/Pair codecs and persistent constructors.

;; One scope covers root recognition, child codec lookup/calls and final admission.
;; Set payloads are elements; Table payloads are bindings. Neither path normalizes
;; admitted leaves again or rolls back bytes already consumed/emitted on a port.
(def (collection-codec descriptor set? method input . args)
  ;; Resolve the current schema only inside the complete descriptor/origin guard.
  (def (run)
    (def schema (.ref descriptor (if set? '.List '.Bindings)))
    (def (admit root) ((if set? require-set require-table) descriptor root))
    (with-table-sources (list schema) (lambda ()
    ;; Protect the exact child used by this List codec, not a second getter result.
    (with-table-sources (list (.@ schema type)) (lambda ()
    (case method
      ((.json<- .bytes<- .marshal)
        (admit input)
        ;; Retain method-lookup priority, then own the complete observation before
        ;; child codecs can recycle the backend's list or binding Pair shells.
        ;; Set elements and binding children remain opaque admitted leaves.
        (let* ((encode (.ref schema method))
               (rows (.call descriptor .list<- input))
               (snapshot (if set? (map identity rows) (capture-table-bindings rows))))
          (apply encode snapshot args)))
      ((.<-json .<-bytes .unmarshal)
        (admit (.call descriptor .<-list (apply (.ref schema method) input args))))
      (else (error "unsupported collection codec" method))))))))
  (if set? (with-set-inputs descriptor [] run)
    (with-table-sources (table-sources descriptor) run)))
