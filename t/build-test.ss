;;; Source-only checks for compiler-owned build declarations; no POO runtime dependency.
(export build-test)
(import :std/test :std/error (only-in :std/list/list delete-duplicates/hash) (only-in "build.ss" test-build-spec test-build-partitions))

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
        (check (length parts) => 6)
        (check (length all) => 144)
        (check (length groups) => 25)
        (check (length (delete-duplicates/hash groups)) => (length groups))
        (check (apply + (map (lambda (group) (length (test-build-spec group))) groups)) => (length all))))
    (test-case "unknown package refuses instead of silently dropping checks"
      (check-exception (test-build-spec "not-a-declared-package") Error?))))
