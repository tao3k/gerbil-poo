;;; Selective DAG reconstruction of whole feedback groups with joint publication.
(export close-feedback-group feedback-group? group-closed feedback-cache-ref
        feedback-cache-action publish-feedback-cache %admit-feedback-cache %feedback-cache-current!
        %start-feedback-guard %revise-feedback-guard %feedback-guard-current! %admit-guarded-feedback-cache)
(import (only-in :std/list/list foldr list-sort delete-duplicates/hash) ./object ./mop ./support/option
        ./generalized-declaration ./generalized-closure ./feedback-closure ./lens-laws
        (only-in ./generalized-graph %splice-witness-tree %witness-span %witness-tree-current? %witness-tree-stamp
                 %witness-tree-left %witness-tree-right %witness-tree-evidence)
        (prefix-in ./construction-cache cache.) (prefix-in ./dependency-analysis code.)
        (prefix-in (only-in ./fun Observation.) fun.))
;; Only successful whole-raw closure plus every component residual creates a group.
;; Registered sources and immutable receipt data remain part of the reuse premise.
(defstruct group (prepared closed checks) final: #t)
;; Recognize a whole feedback group; arbitrary cached values cannot substitute for it.
(def feedback-group? group?)
;; Build one atomic feedback group using the existing Reader and explicit seed.
;; A dirty group is reconstructed in full; there is no per-node cycle skipping.
(def (close-feedback-group prepared base seed budget checks: (checks []))
  (def owned-checks (if (list? checks) (list-copy checks) checks))
  (make-group prepared ((feedback-closure-action prepared base budget checks: owned-checks) seed) owned-checks))
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
(def (with-feedback-group group action)
  (with-fragment-sources (group-prepared group)
    (lambda () (with-lens-checks (group-checks group) action))))
(def (with-feedback-groups groups action)
  ((foldr (lambda (group rest) (cut with-feedback-group group rest)) action groups)))
;; The coordinator calls this without author code under the approval lock.
;; Thread-local guards in the approval callback cannot cover a sibling writer.
(def (%feedback-cache-current! candidate keys)
  (for-each (lambda (key) (with-feedback-group (feedback-cache-ref candidate key) void)) keys))

;; The graph's witness tree supplies the same source retirement for group guards.
(defstruct guard-index (width root) final: #t)
(def (attach-guard! witness group)
  (def fragments? (%watch-fragment-sources (group-prepared group) witness))
  (def checks? (%watch-lens-sources (group-checks group) witness))
  (and fragments? checks?))
(def (%start-feedback-guard candidate keys position width register)
  (def span (max 1 width))
  (def edits (map (lambda (key) (cons (position key) (feedback-cache-ref candidate key))) keys))
  (make-guard-index span (%splice-witness-tree #f span edits attach-guard! register)))
(def (%revise-feedback-guard index candidate position retired register)
  (def changed (cache.cache-evaluated candidate))
  (if (and (null? changed) (null? retired)) index
    (let* ((positions (append (map (lambda (key) (cons (position key) key)) changed)
                             (map (lambda (key) (cons (position key) #f)) retired)))
           (edits (map (lambda (entry)
                         (cons (car entry) (and (cdr entry) (feedback-cache-ref candidate (cdr entry)))))
                       (list-sort (lambda (a b) (< (car a) (car b))) positions)))
           (width (guard-index-width index))
           (minimum (foldr (lambda (edit span) (max (1+ (car edit)) span)) width edits)))
      (make-guard-index (%witness-span width minimum)
        (%splice-witness-tree (guard-index-root index) width edits attach-guard! register
          minimum-width: minimum)))))
(def (%feedback-guard-current! index)
  ;; A stale aggregate keeps the same ordered fragment-before-lens refusal.
  (def (check node)
    (unless (%witness-tree-current? node)
      (let (group (%witness-tree-evidence node))
        (if group (with-feedback-group group void)
          (begin (check (%witness-tree-left node)) (check (%witness-tree-right node)))))))
  (check (guard-index-root index)))
(def (with-feedback-guard index action)
  (def root (guard-index-root index))
  (if (not root) (action)
    (parameterize ((active-object-constructions (cons (%witness-tree-stamp root) (active-object-constructions))))
      (%feedback-guard-current! index)
      (begin0 (action) (%feedback-guard-current! index)))))

(def (admit-feedback-cache old candidate admit)
  ((.call fun.Observation. .map (lambda (next)
    (unless (eq? (admit old next) #t) (error "joint feedback cache approval refused")) next)
    (.call fun.Observation. .ap candidate)) old))
;; Unknown sources retain the complete guard and outcome admission.
(def (%admit-feedback-cache old candidate keys admit)
  (def groups (map (cut feedback-cache-ref candidate <>) keys))
  (with-feedback-groups groups (lambda () (admit-feedback-cache old candidate admit))))
(def (%admit-guarded-feedback-cache old candidate index admit)
  (with-feedback-guard index (lambda () (admit-feedback-cache old candidate admit))))

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
      (%admit-feedback-cache old candidate keys admit)))))
;; Construction, required-group checks, source admission and joint approval share
;; one publication boundary. Any refusal retains the exact old cache and exception.
;; Later publication failure never promotes a speculative cache for subsequent reuse.
(def (publish-feedback-cache old source keys admit guards: (guards []) builder: (builder (.cc cache.Builder.)))
  (try (values ((feedback-cache-action source keys admit guards: guards builder: builder) old) #f)
    (catch (failure) (values old failure))))
