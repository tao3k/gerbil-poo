;;; Source-only checks for compiler-owned build declarations; no POO runtime dependency.
(export build-test)
(import :std/test :std/error (only-in :std/list/list delete-duplicates/hash) (only-in "build.ss" test-build-spec test-build-partitions))

(def build-test
  (test-suite "standard test package declarations"
    (test-case "shared graph preserves included-source dependencies and package order"
      (let ((complete (test-build-spec))
            (ordered '(gxc: "collection-order/table-order-test"
              (extra-inputs: ("collection-order/table-order/rationaldict.scm"
                "collection-order/table-order/cursors.scm"
                "collection-order/table-order/queries.scm"
                "collection-order/table-order/decomposition.scm"
                "collection-order/table-order/observations.scm"))
              "-cc-options" "-D___SINGLE_HOST_LIMIT=10000")))
        (check (and (member ordered complete) #t) => #t)
        (check (and (member '(gxc: "collection-updates/table-mapping-test"
          (extra-inputs: ("collection-updates/table-mapping/composition.scm"
                          "collection-updates/table-mapping/retraction.scm"))) complete) #t) => #t))
      (check (test-build-spec "collection-order") =>
        '((gxc: "table-order-test" (extra-inputs: ("table-order/rationaldict.scm"
          "table-order/cursors.scm" "table-order/queries.scm"
          "table-order/decomposition.scm" "table-order/observations.scm"))
          "-cc-options" "-D___SINGLE_HOST_LIMIT=10000"))))
    (test-case "compiler partitions cover every existing package exactly once"
      (let* ((parts (test-build-partitions))
             (groups (apply append (map cdr parts)))
             (all (test-build-spec)))
        (check (length parts) => 6)
        (check (length all) => 146)
        (check (length groups) => 25)
        (check (length (delete-duplicates/hash groups)) => (length groups))
        (check (apply + (map (lambda (group) (length (test-build-spec group))) groups)) => (length all))))
    (test-case "unknown package refuses instead of silently dropping checks"
      (check-exception (test-build-spec "not-a-declared-package") Error?))))
