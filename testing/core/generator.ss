;;; Independent generators and lazy shrinking provenance; no POO dependencies.
(export make-generator generator? integer-shrinks generator-unit generator-map generator-bind generator-sequence
        generate generator-current? sample? sample-value sample-children sample-current
        stale-generation? boolean-result live? random-at)
(import :std/error :std/iter (only-in :std/list/list delete-duplicates/hash))
(extern namespace: #f make-random-source random-source-pseudo-randomize! random-source-make-integers)
;; Generators describe pure actions and their explicit source observer.
(defstruct generation (run current) final: #t)
;; A value owns a lazy child factory and the provenance of its producer.
(defstruct sample (value children current) final: #t)
;; Internal source refusal cannot be mistaken for a false property.
(defstruct stale () final: #t)
;; Public recognition is independent of POO object classes.
(def generator? generation?)
;; Execution classifies this precise refusal before domain-specific error mapping.
(def stale-generation? stale?)
;; Predicates are strict Boolean judgments; truthy data cannot authorize a test.
(def (boolean-result value message)
  (unless (boolean? value) (error message value)) value)
;; Source observers are pure; immutable specifications may use the default observer.
(def (live? current) (boolean-result (current) "source observer must return a boolean"))
;; A stale branch may not execute its selector or generate a replacement suffix.
(def (require-live! current) (unless (live? current) (raise (make-stale))))
;; Obtain a fresh invocation-local random source, never a process-global PRNG.
(def (random-at seed)
  (def source (make-random-source))
  (random-source-pseudo-randomize! source 0 seed)
  (random-source-make-integers source))
;; Capture a child seed once: dependent re-generation reuses it without consuming
;; the original source during shrinking, as in Quickcheck/Rackcheck bind.
(def (split-seed random) (random 4294967087))
;; Execute one generator only while its declared callback sources remain current.
(def (generate generator random size)
  (unless (generator? generator) (error "generator required"))
  (require-live! (generation-current generator))
  (def value ((generation-run generator) random size))
  (unless (sample? value) (error "generator must produce a sample")) value)
;; Signed integer shrinking is a general value algorithm, independent of POO Types.
(def (integer-shrinks value)
  (if (zero? value) []
    (delete-duplicates/hash (list 0 (quotient value 2) (- value (if (> value 0) 1 -1))))))
;; Lift existing value/shrink callbacks into lazy provenance. The shrink callback
;; is not called until a positive-budget consumer requests its first child.
(def (make-generator (draw : :procedure) (shrink : :procedure)
                    current?: (current (lambda () #t)))
  (using (current : :procedure)
    (def (tree value)
      (make-sample value
        (lambda () (in-coroutine (lambda (yield)
          (require-live! current)
          (for (child (shrink value)) (yield (tree child)))))) current))
    (make-generation (lambda (random size) (tree (draw random size))) current)))
;; Constants have no children and do not consume randomness.
(def (generator-unit value)
  (make-generator (lambda (_random _size) value) (lambda (_) [])))
;; Transform every node lazily. Parent provenance survives non-injective maps;
;; shrinking never tries to infer a parent value from the transformed result.
(def (map-sample tree transform current)
  (def parent-current (sample-current tree))
  (require-live! current)
  (require-live! (sample-current tree))
  (make-sample (transform (sample-value tree))
    (lambda () (in-coroutine (lambda (yield)
      (require-live! current)
      (for (child ((sample-children tree))) (yield (map-sample child transform current))))))
    (lambda () (and (live? current) (live? parent-current)))))
;; Mapping is a generator combinator, separate from a domain's admission/measure.
(def (generator-map generator (transform : :procedure) current?: (current (lambda () #t)))
  (make-generation
    (lambda (random size) (map-sample (generate generator random size) transform current))
    (lambda () (and (live? current) (live? (generation-current generator))))))
;; Binding prioritizes parent shrinks, then the selected child's own shrinks.
;; The exact captured seed rebuilds each dependent child under its new parent.
(def (bind-sample parent select seed size current)
  (require-live! current)
  (require-live! (sample-current parent))
  (def child (generate (select (sample-value parent)) (random-at seed) size))
  (def parent-current (sample-current parent)) (def child-current (sample-current child))
  (make-sample (sample-value child)
    (lambda () (in-coroutine (lambda (yield)
      (require-live! current)
      (for (smaller ((sample-children parent)))
        (yield (bind-sample smaller select seed size current)))
      (for (smaller ((sample-children child)))
        (yield (map-sample smaller (lambda (value) value)
          (lambda () (and (live? current) (live? parent-current)))))))))
    (lambda () (and (live? current) (live? parent-current) (live? child-current)))))
;; Dependent generation has an explicit pure selector/revision contract, not a
;; cache from output values back to hidden inputs or a second random-state owner.
(def (generator-bind generator (select : :procedure) current?: (current (lambda () #t)))
  (make-generation
    (lambda (random size)
      (def parent-seed (split-seed random)) (def child-seed (split-seed random))
      (bind-sample (generate generator (random-at parent-seed) size) select child-seed size current))
    (lambda () (and (live? current) (live? (generation-current generator))))))
;; Products reuse bind/map; they introduce no separate generation traversal.
(def (generator-sequence generators)
  (foldr (lambda (generator tail)
    (generator-bind generator (lambda (head)
      (generator-map tail (lambda (rest) (cons head rest))))))
    (generator-unit []) generators))

;; Observe declared generator sources through the same strict Boolean contract.
(def (generator-current? generator) (live? (generation-current generator)))
