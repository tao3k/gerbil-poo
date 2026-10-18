;;; One inventory for independent Scheme tests and the Actions matrix.
(export main test-groups test-files checked-groups group-source-key)
(import :gerbil/runtime/gambit :std/encoding/json
        (only-in :std/list/list append-map delete-duplicates/hash)
        :std/crypto/digest :std/encoding/hex :std/misc/ports)

;; Keep existing modules classified by responsibility. New modules are still
;; tested in an additional group until their author assigns a functional group.
(def test-groups
  '((objects support object mop parameters inheritance-hooks slot-observation)
    (representations row-types prototype-types function-signature property-testing recursive-generation representation type type-performance tuple-json-performance tuple-unmarshal-performance)
    (collections table-validation library-reuse number polynomial rationaldict trie fq)
    (methods multimethod method-combination method-declaration typed-method-declaration inferred-declaration container-inference record-inference candidate-inference function-coverage keyword-coverage)
    (declarations declarative-metadata generalized-declaration recursive-declaration meta-prototype)
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

;; Emit only the ephemeral matrix required by Actions, using the standard JSON
;; encoder. The registry remains Scheme data; no generated JSON is kept in Git.
(def (main)
  (def rows (map (lambda (group)
                  (hash ("group" (car group)) ("modules" (string-join (cdr group) " ")) ("source-key" (group-source-key (car group)))))
                (checked-groups)))
  (display (json->string (hash ("include" (list->vector rows)))))
  (newline))

;; Share the checked source inventory with compilation and single-process tests.
;; Preserve the release harness's source preparation order, independent of groups.
(def (test-files (group #f))
  (def groups (checked-groups))
  (list-sort string<? (if group
    (cdr (or (assoc group groups) (error "unknown test group" group)))
    (append-map cdr groups))))

;; Hash an unambiguous filename/digest sequence for this group. CI additionally
;; binds shared inputs and the complete test snapshot, including cross-group macros.
(def (group-source-key group)
  (hex-encode (sha256 (string->utf8 (call-with-output-string (lambda (port) (write
    (map (lambda (file) (cons file (hex-encode
      (sha256 (call-with-input-file file read-all-as-u8vector))))) (test-files group)) port)))))))
