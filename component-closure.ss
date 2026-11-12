;;; Lens-based complete component equations, reusable on any comparable carrier.
(export component-group-builder %component-member-builder? %with-member-fragment-seeds)
(import (only-in :std/list/list delete-duplicates/hash) ./object ./mop ./support/option ./generalized-declaration ./generalized-closure ./feedback-cache
        (only-in :gerbil/runtime/thread with-lock)
        (only-in ./support/base %graph-table-seed %with-graph-table-seeds %with-application-table-seeds)
        (only-in ./read-route gc-table-route-current?)
        (prefix-in ./dependency-analysis code.))
(extern namespace: clan/poo/generalized-declaration %fragment-preparation-current?)
(extern namespace: clan/poo/object %cached-native-lens?)
;; Only this constructor issues evidence for the actual returned procedure.
;; The weak identity set owns neither builder lifetimes nor computed results.
(def member-builders (make-table test: eq? weak-keys: #t))
(def member-builders-lock (make-mutex 'component-member-builders))
(def fragment-support (make-parameter #f))
(def (%with-member-fragment-seeds members providers action)
  (parameterize ((fragment-support (cons members providers)))
    (%with-graph-table-seeds action)))
(def (%component-member-builder? build)
  (with-lock member-builders-lock (lambda () (table-ref member-builders build #f))))
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
  (def (build members spec external)
    ;; One live admission spans this callback-free batch only. A tainted
    ;; origin never regains authority merely because metadata is restored.
    (def current? (index-current?))
    (unless (andmap (lambda (key)
      (and (symbol? key) (if current? (hash-key? lenses key) (memq key names)))) members)
      (error "unknown component group member"))
    (def (prepare)
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
      (prepare-fragments GeneralizedDeclaration. (.o) cook forms))
    (def (warm-focus? key)
      (%cached-native-lens? (hash-ref lenses key #f)))
    ;; Validation only inspects warm lens metadata. Unknown construction
    ;; stays ordinary. The lens compiler and cook handoffs restore the
    ;; application policy at each actual callback.
    (def support (fragment-support))
    (def qualified?
      (and support (eq? members (car support)) (%graph-table-seed) current? (null? sources)
           (%fragment-preparation-current?)
           (andmap warm-focus? members) (andmap warm-focus? (cdr support))))
    (def prepared
      (if qualified? (prepare) (%with-application-table-seeds prepare)))
    (if (and qualified? (%fragment-preparation-current?))
      (close-feedback-group prepared base seed budget)
      (%with-application-table-seeds
        (lambda () (close-feedback-group prepared base seed budget)))))
  (with-lock member-builders-lock (lambda () (table-set! member-builders build #t)))
  build)
