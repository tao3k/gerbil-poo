;;; Selective DAG reconstruction of whole feedback groups with joint publication.
(export close-feedback-group feedback-group? group-closed feedback-cache-ref
        feedback-cache-action publish-feedback-cache)
(import (only-in :std/list/list foldr delete-duplicates/hash) ./object ./mop ./support/option
        ./generalized-declaration ./generalized-closure ./feedback-closure ./lens-laws
        (prefix-in ./construction-cache cache.) (prefix-in ./dependency-analysis code.)
        (prefix-in ./generalized-prototype gp.))
;; Only successful whole-raw closure plus every component residual creates a group.
;; Registered sources and immutable receipt data remain part of the reuse premise.
(defstruct group (prepared closed checks) final: #t)
;; Recognize a whole feedback group; arbitrary cached values cannot substitute for it.
(def feedback-group? group?)
;; Build one atomic feedback group using the existing Reader and explicit seed.
;; A dirty group is reconstructed in full; there is no per-node cycle skipping.
(def (close-feedback-group prepared base seed budget checks: (checks []))
  (make-group prepared ((feedback-closure-action prepared base budget checks: checks) seed) checks))
;; Require an actual successful group outcome. Missing/error/non-group outputs
;; refuse the whole publication even if application approval would ignore them.
(def (feedback-cache-ref current key)
  (def found (cache.cache-ref current key))
  (unless (and (some? found) (code.success? (some-value found))
               (feedback-group? (code.success-value (some-value found))))
    (error "required feedback group unavailable" key found))
  (code.success-value (some-value found)))
;; Guard retained AND rebuilt group sources through complete joint approval.
;; A stale retained owner refuses, rather than treating a cache hit as new proof.
(def (with-feedback-groups groups action)
  ((foldr (lambda (group rest) (lambda ()
    (with-fragment-sources (group-prepared group) (lambda ()
      (with-lens-checks (group-checks group) rest))))) action groups)))
;; Reader input is old cache or #f. Existing ConstructionCache propagates dirty
;; declared reads through a DAG of atomic groups and skips untouched builders.
;; Graph/code metadata must be immutable/extensional, as in that existing cache.
;; Optional guards are captured lens-check source guards held for this operation;
;; group law checks execute inside close-feedback-group, not on the cache object.
(def (feedback-cache-action source keys admit guards: (guards []) builder: (builder (.cc cache.Builder.)))
  (unless (and (list? keys) (andmap symbol? keys) (procedure? admit)
               (= (length keys) (length (delete-duplicates/hash keys))))
    (error "distinct required feedback keys and joint admission required"))
  (lambda (old)
    (unless (or (not old) (cache.cache? old)) (error "old construction cache or #f required"))
    (with-lens-checks guards (lambda ()
      (def candidate (if old (cache.refresh old source builder) (cache.start source builder)))
      (def groups (map (cut feedback-cache-ref candidate <>) keys))
      (with-feedback-groups groups (lambda ()
        ;; The same native FUN Reader chain performs final approval. No approval
        ;; result is retained, including when every construction slot was reused.
        ((.call gp.Observation. .map (lambda (next)
          (unless (eq? (admit old next) #t) (error "joint feedback cache approval refused")) next)
          (.call gp.Observation. .ap candidate)) old)))))))
;; Construction, required-group checks, source admission and joint approval share
;; one publication boundary. Any refusal retains the exact old cache and exception.
;; Later publication failure never promotes a speculative cache for subsequent reuse.
(def (publish-feedback-cache old source keys admit guards: (guards []) builder: (builder (.cc cache.Builder.)))
  (try (values ((feedback-cache-action source keys admit guards: guards builder: builder) old) #f)
    (catch (failure) (values old failure))))
