;;; One inventory for independent Scheme tests and the Actions matrix.
(export test-groups test-files test-batch checked-groups compiled-library-module?)
(import :gerbil/runtime/gambit
        (only-in :std/list/list append-map delete-duplicates/hash))

;; Admit only the numbered runtime bundle for this exact library root. The
;; standard loader chooses its current object; interpreted source and modules
;; from another package path cannot satisfy compiled-library acceptance.
(def (compiled-library-module? file loaded root)
  (and (string? loaded)
       (equal? (path-strip-extension (path-expand loaded))
         (path-expand (string-append "lib/clan/poo/" file) root))
       (let (extension (path-extension loaded))
         (and (string-prefix? ".o" extension) (> (string-length extension) 2)
              (let (version (substring extension 2 (string-length extension)))
                (and (andmap char-numeric? (string->list version))
                     (let (number (string->number version)) (and (exact-integer? number) (> number 0)))))))))

;; Keep existing modules classified by responsibility. New modules are still
;; tested in an additional group until their author assigns a functional group.
(def test-groups
  '((objects support object mop parameters inheritance-hooks slot-observation issued-read)
    (representations row-types prototype-types function-signature property-testing recursive-generation representation type type-performance tuple-json-performance tuple-unmarshal-performance)
    ;; Independent collection responsibilities bound retained compiler ASTs.
    ;; Shared fixtures belong to table-testing, already in the common artifact.
    (collections table-validation table-construction table-io table-focus table-selection table-wrapper table-normalization)
    (collection-order rationaldict-order table-order table-cursor table-split)
    (collection-updates table-fold table-merge table-mapping table-index table-index-equivalence table-transport table-group-join table-batch)
    (collection-styles set-algebra set-style table-style table-receiver)
    (backends library-reuse number polynomial rationaldict trie fq)
    ;; Bound compiler retention by responsibility, rather than increasing its
    ;; heap: the old mixed methods group retained all inference/signature ASTs.
    ;; The checked inventory and final one-process suite remain complete.
    (methods multimethod method-combination method-declaration typed-method-declaration inferred-declaration)
    (inference container-inference record-inference candidate-inference optional-inference empty-inference descriptor-inference)
    (signatures function-coverage keyword-coverage keyword-prefix keyword-values keyword-rest function-options)
    (scalars scalar-inference range-inference union-inference)
    (declarations catalog-inference declarative-metadata generalized-declaration recursive-declaration meta-prototype)
    (closure closure closure-alignment component-closure)
    (construction construction-cache construction-workflow focused-closure)
    (components component-membership component-migration component-requests component-rounds)
    (feedback feedback-cache feedback-closure feedback-graph feedback-revision cyclic-access)
    (recursion recursive recursive-benchmark)
    (contracts contract-checks recursive-coordination recursive-recovery recursive-submissions recursive-competition recursive-approvals recursive-publication recursive-restaging recursive-staging recursive-topology recursive-migration recursive-revision recursive-validation computed-validation class-validation optional-validation variant-validation container-validation contract-family object-contract object-contract-flow object-contract-validation contract-publication evidence-binding protected-dispatch service-bundle service-metadata service-revisions shared-approvals)
    (publication joint-publication joint-admission joint-receipts joint-installation approval-revision)
    (revisions joint-topology joint-rounds joint-restaging joint-generations)
    (coordination joint-coordination joint-concurrency coordinator-recovery coordinator-rejoining)
    (recovery coordinator-interleaving coordinator-retry coordinator-prepared)
    (generalized binding-benchmark factory-benchmark focused-benchmark generalized-benchmark generalized-closure generalized-prototype)
    (tools build cli debug lifecycle metadata-paired metadata-report)))

;; Convert the existing module names to repository-owned harness inputs.
(def (module-file name) (string-append "t/" (symbol->string name) "-test.ss"))

;; Reject missing/duplicate classified tests; include every newly added test too.
(def (checked-groups)
  (def groups (map (lambda (group) (cons (symbol->string (car group)) (map module-file (cdr group)))) test-groups))
  (def declared (append-map cdr groups))
  (def actual (map (cut string-append "t/" <>)
                  (filter (cut string-suffix? "-test.ss" <>) (directory-files "t"))))
  (unless (= (length declared) (length (delete-duplicates/hash declared)))
    (error "duplicate test module in functional groups"))
  (unless (andmap (cut member <> actual) declared)
    (error "classified test module is missing"))
  (def extra (list-sort string<? (filter (lambda (file) (not (member file declared))) actual)))
  (if (null? extra) groups (append groups (list (cons "additional" extra)))))

;; Share the checked source inventory with compilation and single-process tests.
;; Preserve the release harness's source preparation order, independent of groups.
(def (test-files (group #f))
  (def groups (checked-groups))
  (list-sort string<? (if group
    (cdr (or (assoc group groups) (error "unknown test group" group)))
    (append-map cdr groups))))

;; Disjoint local compiler batches share the exact CI inventory. The explicit
;; count permits matched memory/worker studies without silently dropping roots.
(def (test-batch index (count 8))
  (unless (and (exact-integer? count) (> count 0)
               (exact-integer? index) (<= 0 index) (< index count))
    (error "test batch requires a positive count and an index in [0,count)" index count))
  (def files (test-files))
  (when (> count (length files)) (error "empty compiler batches are not admitted" count))
  (let loop ((files files) (position 0) (result []))
    (if (null? files) (reverse result)
      (loop (cdr files) (+ position 1)
        (if (= (modulo position count) index) (cons (car files) result) result)))))
