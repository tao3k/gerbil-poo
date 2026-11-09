;;; Selective DAG reconstruction of whole feedback groups with joint publication.
(export close-feedback-group feedback-group? group-closed feedback-cache-ref
        feedback-cache-action publish-feedback-cache %admit-feedback-cache %feedback-cache-current!
        %start-feedback-guard %revise-feedback-guard %feedback-guard-current! %admit-guarded-feedback-cache)
(import (only-in :std/list/list foldr list-sort delete-duplicates/hash) ./object ./mop ./support/option
        ./generalized-declaration ./generalized-closure ./feedback-closure ./lens-laws
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

;; Each node watches its exact sources through native POO invalidation. Strong
;; child links retain live support. Weak reverse links do not retain old heads.
(defstruct guard-node (witness left right group) final: #t)
(defstruct guard-index (width root) final: #t)
(def (guard-current? node)
  (or (not node) (zero? (object-revision (guard-node-witness node)))))
(def (attach-guard! node)
  (def witness (guard-node-witness node))
  (def group (guard-node-group node))
  (def left (guard-node-left node))
  (def right (guard-node-right node))
  (def current?
    (if group
      (let ((fragments? (%watch-fragment-sources (group-prepared group) witness))
            (checks? (%watch-lens-sources (group-checks group) witness)))
        (and fragments? checks?))
      (begin
        (when left (depend-on-object! witness (guard-node-witness left)))
        (when right (depend-on-object! witness (guard-node-witness right)))
        (and (guard-current? left) (guard-current? right)))))
  ;; Linking to an already dirty child does not replay its past invalidation.
  (unless current? (uninstantiate-object! witness)))

;; The source positions do not move during a local SCC edit. Sorted replacements
;; visit the union of changed paths once. An empty row retires its old guard.
(def (splice-guards old width edits register)
  (def pending [])
  (def (node left right group)
    (def result (make-guard-node (make-object) left right group))
    (set! pending (cons result pending))
    result)
  (def (walk old first width rest)
    (cond
     ((or (null? rest) (>= (caar rest) (+ first width))) (values old rest))
     ((= width 1)
      (def group (cdar rest))
      (values (and group (node #f #f group)) (cdr rest)))
     (else
      (def half (quotient width 2))
      (defvalues (left next) (walk (and old (guard-node-left old)) first half rest))
      (defvalues (right tail) (walk (and old (guard-node-right old)) (+ first half) (- width half) next))
      (values (and (or left right) (node left right #f)) tail))))
  (defvalues (root rest) (walk old 0 width edits))
  (unless (null? rest) (error "feedback guard positions disagree with owned support"))
  ;; Allocate the tree before taking the lock. The registration section runs
  ;; no constructors or author callbacks and attaches children before parents.
  (when (pair? pending)
    (let (nodes (reverse pending))
      (register (lambda () (for-each attach-guard! nodes)))))
  root)
(def (%start-feedback-guard candidate keys position width register)
  (def span (max 1 width))
  (def edits (map (lambda (key) (cons (position key) (feedback-cache-ref candidate key))) keys))
  (make-guard-index span (splice-guards #f span edits register)))
(def (%revise-feedback-guard index candidate position retired register)
  (def changed (cache.cache-evaluated candidate))
  (if (and (null? changed) (null? retired)) index
    (let* ((positions (append (map (lambda (key) (cons (position key) key)) changed)
                             (map (lambda (key) (cons (position key) #f)) retired)))
           (edits (map (lambda (entry)
                         (cons (car entry) (and (cdr entry) (feedback-cache-ref candidate (cdr entry)))))
                       (list-sort (lambda (a b) (< (car a) (car b))) positions)))
           (width (guard-index-width index)))
      (make-guard-index width
        (splice-guards (guard-index-root index) width edits register)))))
(def (%feedback-guard-current! index)
  ;; A stale aggregate keeps the same ordered fragment-before-lens refusal.
  (def (check node)
    (unless (guard-current? node)
      (let (group (guard-node-group node))
        (if group (with-feedback-group group void)
          (begin (check (guard-node-left node)) (check (guard-node-right node)))))))
  (check (guard-index-root index)))
(def (with-feedback-guard index action)
  (def root (guard-index-root index))
  (if (not root) (action)
    (parameterize ((active-object-constructions (cons (guard-node-witness root) (active-object-constructions))))
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
