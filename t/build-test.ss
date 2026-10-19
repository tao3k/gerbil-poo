;;; Cache admission and complete, disjoint compilation ownership.
(export build-test)
(import :std/test :std/io/tempfile (only-in :std/list/list append-map delete-duplicates/hash)
  (only-in "test-groups.ss" test-files checked-groups group-source-key)
  (only-in "build-artifacts.ss" artifact-key-valid? artifact-root group-root check-all))
;; Exercise source/group boundaries independently of the Actions cache backend.
(def build-test
  (test-suite "compiled group source admission"
    (test-case "every test belongs to exactly one compilation group"
      (def files (append-map (lambda (group) (test-files (car group))) (checked-groups)))
      (check-equal? (length files) (length (delete-duplicates/hash files)))
      (check-equal? (list-sort string<? files) (test-files))
      (check-exception (test-files "not-a-test-group") true))
    (test-case "compiler-heavy protocols retain independent bounded groups"
      ;; Bound each known compiler-heavy family while the inventory test above
      ;; separately proves that no module was omitted or duplicated by grouping.
      (for-each (lambda (name)
        (def files (test-files name))
        (check (and (pair? files) (<= (length files) 6)) => #t))
        '("methods" "inference" "signatures" "scalars"))
      (check (and (member "t/container-inference-test.ss" (test-files "inference")) #t) => #t)
      (check (and (member "t/union-inference-test.ss" (test-files "scalars")) #t) => #t))
    (test-case "matching bytes permit reuse while all changed identity axes refuse"
      (def record '(test-group "objects" "compiler-and-library" "tests" "original-producer"))
      (check (artifact-key-valid? record "objects" "compiler-and-library" "tests") => #t)
      (check (artifact-key-valid? record "methods" "compiler-and-library" "tests") => #f)
      (check (artifact-key-valid? record "objects" "different-library" "tests") => #f)
      (check (artifact-key-valid? record "objects" "compiler-and-library" "revised-tests") => #f)
      (check (artifact-key-valid? '(test-group "objects" "compiler-and-library" "tests")
        "objects" "compiler-and-library" "tests") => #f)
      (check (artifact-key-valid? '(test-group "objects" "compiler-and-library" "tests" #f)
        "objects" "compiler-and-library" "tests") => #f))
    (test-case "assembly rejects missing interfaces stale revisions and extra group directories"
      ;; Empty interfaces exercise admission only; they are never executed as code.
      (call-with-temporary-directory "poo-build-admission-"
        (lambda (directory)
          (parameterize ((artifact-root (string-append directory "/")))
            ;; Write exactly one complete datum and close the standard file port.
            (def (save path value)
              (call-with-output-file (list path: path truncate: #t)
                (lambda (port) (write value port))))
            (for-each (lambda (group)
              (def name (car group)) (def root (group-root name))
              (for-each (lambda (file)
                (def path (path-expand
                  (string-append "lib/clan/poo/" (path-strip-extension file) ".ssi") root))
                (create-directory* (path-directory path)) (save path 'interface-fixture)) (cdr group))
              (save (path-expand "source.scm" root) (list 'test-group name "base" (group-source-key name) "producer"))
              (save (path-expand "revision.scm" root) "current")) (checked-groups))
            (check (begin (check-all "base" "current") #t) => #t)
            (def root (group-root "objects"))
            (save (path-expand "revision.scm" root) "old")
            (check-exception (check-all "base" "current") true)
            (save (path-expand "revision.scm" root) "current")
            (delete-file (path-expand "lib/clan/poo/t/object-test.ssi" root))
            (check-exception (check-all "base" "current") true)
            (save (path-expand "lib/clan/poo/t/object-test.ssi" root) 'interface-fixture)
            (create-directory (group-root "unexpected"))
            (check-exception (check-all "base" "current") true)))))
    (test-case "source keys cover each full group and preserve the checked inventory"
      (for-each (lambda (group)
        (def key (group-source-key (car group)))
        (check-equal? (string-length key) 64)
        (check-equal? key (group-source-key (car group)))) (checked-groups)))))
