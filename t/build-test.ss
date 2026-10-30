;;; Standard build declarations and resolved imports; no requested runtime evaluation.
(export build-test)
(import (only-in :gerbil/expander import-module expander-context-id module-context-import
          module-context? module-import? module-import-source module-export-context
          import-set? import-set-source)
        :std/test :std/error (only-in :std/misc/process run-process)
        (only-in :std/encoding/json string->json JSONReadOptions) (only-in :std/list/list delete-duplicates/hash) (only-in "build.ss" test-build-spec test-build-partitions call-with-build-jobs))

(def build-test
  (test-suite "standard test package declarations"
    (test-case "shared graph preserves included-source dependencies and package order"
      (let (complete (test-build-spec))
        (check (and (member "collection-order/table-cursor-test" complete) #t) => #t)
        (check (and (member '(gxc: "collection-order/table-order-test"
          (extra-inputs: ("collection-order/table-order/observations.scm"))) complete) #t) => #t)
        (check (and (member '(gxc: "collection-updates/table-mapping-test"
          (extra-inputs: ("collection-updates/table-mapping/composition.scm"
                          "collection-updates/table-mapping/retraction.scm"))) complete) #t) => #t))
      (check (test-build-spec "collection-order") =>
        '("rationaldict-order-test" "table-cursor-test"
          (gxc: "table-order-test" (extra-inputs: ("table-order/observations.scm")))
          "table-split-test")))
    (test-case "compiler partitions cover every existing package exactly once"
      (let* ((parts (test-build-partitions))
             (groups (apply append (map cdr parts)))
             (all (test-build-spec)))
        (check (test-build-spec "collection-deltas") =>
          '((gxc: "table-batch-test" (extra-inputs: ("table-batch/capture.scm"
            "table-batch/origins.scm" "table-batch/transport.scm")))))
        (check (test-build-spec "recovery") => '("coordinator-interleaving-test"))
        (check (length parts) => 4)
        (check (length all) => 144)
        (check (length groups) => 25)
        (check (length (delete-duplicates/hash groups)) => (length groups))
        (check (apply + (map (lambda (group) (length (test-build-spec group))) groups)) => (length all))))
    (test-case "standard Just dependencies share four bounded graphs for build and cleanup"
      (def graph (string->json (run-process ["just" "--dump" "--dump-format" "json"])
        (JSONReadOptions key-as-symbol: #f array-as-vector: #f object-as-hash: #t)))
      (def recipes (hash-ref graph "recipes"))
      (def entry (hash-ref recipes "_build-test-packages"))
      (check (hash-ref entry "attributes") => '("parallel"))
      (check (map (cut hash-ref <> "recipe") (hash-ref entry "dependencies")) =>
        '("_build-test-package" "_build-test-package" "_build-test-package" "_build-test-package"))
      ;; Build and failure cleanup share this one standard dependency graph.
      (check (map (cut hash-ref <> "arguments") (hash-ref entry "dependencies")) =>
        '(("contracts" ("variable" "action")) ("types" ("variable" "action"))
          ("prototypes" ("variable" "action")) ("collections" ("variable" "action"))))
      (check (hash-key? recipes "_build-test-prototypes") => #f)
      (check (hash-key? recipes "_build-test-publication") => #f))
    (test-case "shared build cleanup retains values failure identity and single evaluation"
      (check (call-with-values (lambda () (call-with-build-jobs (lambda () (values 1 #f)))) list) => '(1 #f))
      (def calls 0) (def cause (with-catch values (lambda () (error "original build refusal"))))
      (def caught (with-catch values (lambda ()
        (call-with-build-jobs (lambda () (set! calls (+ calls 1)) (raise cause))))))
      (check-eq? caught cause)
      (check calls => 1))
    (test-case "compiler observations identify shared IO and typed property imports"
      ;; Observe already-resolved public descriptors only. There is no source
      ;; scan, recursive resolver, loader substitution or private compiler entry.
      (def (source entry)
        (cond ((module-context? entry) entry)
              ((import-set? entry) (import-set-source entry))
              ((module-import? entry) (module-export-context (module-import-source entry)))
              (else (error "unexpected resolved import descriptor" entry))))
      (for-each (lambda (owner)
        (def dependencies (map (lambda (entry) (expander-context-id (source entry)))
          (module-context-import (import-module (car owner) #f #f))))
        (check (and (memq (cdr owner) dependencies) #t) => #t)
        (check (and (memq 'clan/poo/testing/type dependencies) #t) => #f))
        '((:clan/poo/debug . clan/poo/io)
          (:clan/poo/support/testing . clan/poo/support/io))))
    (test-case "unknown package refuses instead of silently dropping checks"
      (check-exception (test-build-spec "not-a-declared-package") Error?))))
