;;; Lens-based complete component equations, reusable on any comparable carrier.
(export component-group-builder)
(import (only-in :std/list/list delete-duplicates/hash) ./object ./mop ./support/option ./generalized-declaration ./generalized-closure ./feedback-cache
        (prefix-in ./dependency-analysis code.))
;; Prepare one stable builder for an explicit key/lens family and raw base/seed.
;; self-ref projects cooked self; the default is suitable for identity cooking.
;; External reads project actual predecessor raw receipts with the same lenses.
;; Programs must declare every read, callbacks must be pure/locally total, lenses
;; lawful, and base/seed immutable. Focus objects are selected ONCE and all read
;; lenses are registered as sources. Additional self-ref metadata belongs in sources.
;; Whole closure plus every residual is required.
(def (component-group-builder keys focus base seed budget cook: (cook identity)
       self-ref: (self-ref #f) sources: (sources []))
  (unless (and (list? keys) (andmap symbol? keys)
               (= (length keys) (length (delete-duplicates/hash keys))))
    (error "distinct component lens keys required"))
  (def lenses (make-hash-table-eq))
  (for-each (lambda (key) (hash-put! lenses key (focus key))) keys)
  ;; Stable projection identity is part of preparation, not a per-read lens factory.
  (def (focus-of key) (hash-ref lenses key))
  (def project-self (or self-ref (lambda (key self) (.call (focus-of key) .get self))))
  (lambda (members spec external)
    (unless (andmap (lambda (key) (memq key keys)) members) (error "unknown component group member"))
    (def forms (map (lambda (key)
      (def program (.call spec .code key))
      (def part (lens-fragment (focus-of key) (lambda (_ self inherited)
        (def result (if program (.call program .evaluate (lambda (dep)
          (unless (memq dep (.@ program reads)) (error "undeclared component read" key dep))
          (some (code.make-success (if (memq dep members) (project-self dep (self))
            (.call (focus-of dep) .get (closed-raw (group-closed (external dep)))))))))
          (let (found (.call spec .base key))
            (unless (some? found) (error "missing component input" key)) (some-value found))))
        (unless (code.success? result) (error "component equation failed" key result))
        (code.success-value result)) #f
        sources: (append sources (if program (map focus-of (.@ program reads)) []))))
      (.o (kind 'fragment) (name key) (descriptor part))) members))
    (close-feedback-group (prepare-fragments GeneralizedDeclaration. (.o) cook forms) base seed budget)))
