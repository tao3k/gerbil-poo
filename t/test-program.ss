;;; Standard executable linkage for the complete single-process test inventory.
(export main)
(import (only-in :gerbil/runtime/gambit eval)
        (only-in :gerbil/runtime/loader load-module list-modules)
        (only-in "test-groups.ss" test-files)
        (for-syntax (only-in :gerbil/expander genident import-module module-context-export module-export-phi)
                    (only-in "test-groups.ss" test-files)
                    (only-in "build-spec.ss" library-modules)))

;; Link shared runtime roots from the existing library graph. Compiled interfaces
;; keep source expansion bounded; macro-only roots need no runtime initialization.
;; Every test remains in the original runner, including tests outside this closure.
(defsyntax (import-shared-modules stx)
  (syntax-case stx ()
    ((_ libraries inventory)
     (let ()
       ;; Metadata selects runtime dependencies without executing their validators.
       (def (interface file)
         (path-expand (string-append "lib/clan/poo/" file ".ssi") (gerbil-path)))
       (def files (filter (lambda (file)
         (ormap (lambda (export) (= (module-export-phi export) 0))
           (module-context-export (import-module (interface file) #f #f)))) (library-modules)))
       (with-syntax (((module ...) (map (lambda (file) (datum->syntax #'libraries (interface file))) files))
                     ((prefix ...) (map (lambda (_) (genident 'library)) files))
                     ((file ...) files) ((test ...) (test-files)))
         #'(begin (import (prefix-in module prefix) ...)
                  (def libraries '(file ...))
                  (def inventory '(test ...))))))))
(import-shared-modules linked-libraries linked-test-files)

;; Refuse stale or incomplete linkage. The released runner owns discovery,
;; preparation, module/case order, setup/cleanup and original test failures.
;; Runtime loading keeps its tool dependencies out of the executable's link
;; closure; releases need not provide static objects for Gerbil command tools.
(def (main . request)
  (unless (equal? linked-test-files (test-files))
    (error "linked test inventory changed; rebuild test-program"))
  (def modules (list-modules))
  (for-each (lambda (file)
    (def entry (assoc (string-append "clan/poo/" file) modules))
    (unless (and entry (eq? (cdr entry) 'builtin))
      (error "shared library module is not linked" file))) linked-libraries)
  (displayln "TEST-LINKED libraries=" (length linked-libraries) " modules=" (length linked-test-files)) (force-output)
  ;; A fixed dispatch inventory prevents arbitrary module/symbol evaluation.
  ;; Benchmarks share precisely the linked library objects used by full tests;
  ;; their own code is a normal compiled module loaded by Gerbil's loader.
  (match request
    (["t"]
      (load-module "clan/poo/t/test-runner")
      ((eval 'clan/poo/t/test-runner#main) "t"))
    (["benchmark" "collection-paired-benchmark" . args]
      (load-module "clan/poo/t/collection-paired-benchmark")
      (apply (eval 'clan/poo/t/collection-paired-benchmark#main) args))
    (else (error "unknown linked program request" request))))
