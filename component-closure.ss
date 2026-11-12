;;; Lens-based complete component equations, reusable on any comparable carrier.
(export component-group-builder)
(import (only-in :std/list/list delete-duplicates/hash) ./object ./mop ./support/option ./generalized-declaration ./generalized-closure ./feedback-cache
        (only-in ./read-route gc-table-route-current?)
        (prefix-in ./dependency-analysis code.))
;; Prepare one stable builder for an explicit key/lens family and raw base/seed.
;; self-ref projects cooked self; the default is suitable for identity cooking.
;; External reads project actual predecessor raw receipts with the same lenses.
;; Programs must declare every read, callbacks must be pure/locally total, lenses
;; lawful, and base/seed immutable. Focus objects are selected ONCE and all read
;; lenses are registered as sources. Own the family spine before calling focus;
;; the private lens index also owns membership. Caller list edits cannot change
;; an already prepared family. Additional self-ref metadata belongs in sources.
;; Whole closure plus every residual is required.
(def (component-group-builder keys focus base seed budget cook: (cook identity)
       self-ref: (self-ref #f) sources: (sources []))
  (unless (and (list? keys) (andmap symbol? keys)
               (= (length keys) (length (delete-duplicates/hash keys))))
    (error "distinct component lens keys required"))
  (def names (list-copy keys))
  (def lenses (make-hash-table-eq))
  (def indexed? (gc-table-route-current? lenses))
  (def (index-current?)
    (and indexed?
      (or (gc-table-route-current? lenses)
          (begin (set! indexed? #f) #f))))
  (for-each (lambda (key)
    (def selected (focus key))
    ;; Recheck AFTER the author. Unknown writes still execute, but their
    ;; table no longer certifies the immutable family membership.
    (index-current?)
    (hash-put! lenses key selected)) names)
  ;; Stable projection identity is part of preparation, not a per-read lens factory.
  (def (focus-of key)
    (index-current?)
    (hash-ref lenses key))
  (def project-self (or self-ref (lambda (key self) (.call (focus-of key) .get self))))
  (lambda (members spec external)
    ;; One live admission spans this callback-free batch only. A tainted
    ;; origin never regains authority merely because metadata is restored.
    (def current? (index-current?))
    (unless (andmap (lambda (key)
      (and (symbol? key) (if current? (hash-key? lenses key) (memq key names)))) members)
      (error "unknown component group member"))
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
