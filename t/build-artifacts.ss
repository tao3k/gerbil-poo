;;; Source-bound admission for disjoint compiled test-group artifacts.
(export main artifact-key-valid? artifact-root group-root check-group check-all read-one-file build-root build-files build-input-files build-digests build-output-files build-generation build-current? save-build-generation test-build-output?)
(import :std/misc/ports :std/crypto/digest :std/encoding/hex (only-in :std/list/list append-map) "test-groups.ss")
;; Standard dynamic scope isolates admission fixtures from real compiler artifacts.
(def artifact-root (make-parameter ".ci-tests/"))
;; One source tree per functional group; filenames never become module namespaces.
(def (group-root group) (path-expand (string-append group "/") (artifact-root)))
;; Pure cache admission: compiler/common-source key, group identity and exact test
;; bytes must agree. The original producer SHA is historical, not current authority.
(def (artifact-key-valid? datum group base-key source-key)
  (match datum
    (['test-group actual-group actual-base actual-source (? string? producer)]
      (and (equal? actual-group group) (equal? actual-base base-key) (equal? actual-source source-key)))
    (else #f)))
;; Read exactly one datum; truncated, appended or malformed receipts refuse.
(def (read-one-file path)
  (call-with-input-file path (lambda (port)
    (def value (read port))
    (unless (eof-object? (read port)) (error "extra artifact receipt" path)) value)))
;; Check source identity and every required compiled interface before loading it.
;; Missing runtime code is also rejected by the ordinary module loader/tests.
(def (check-group group base-key)
  (def root (group-root group))
  (unless (artifact-key-valid? (read-one-file (path-expand "source.scm" root))
            group base-key (group-source-key group)) (error "stale test artifact" group))
  (for-each (lambda (file)
    (unless (file-exists? (path-expand
      (string-append "lib/clan/poo/" (path-strip-extension file) ".ssi") root))
      (error "compiled group interface missing" group file))) (test-files group))
  #t)
;; Current-run admission is read-only after the compilation job stamps its output.
(def (check-revision group revision)
  (unless (equal? (read-one-file (path-expand "revision.scm" (group-root group))) revision)
    (error "test artifact revision differs" group)))
;; Every current group must occur exactly once before the single-process merge.
;; Per-group current-revision stamps prevent an old run from satisfying coverage.
(def (check-all base-key revision)
  (def groups (map car (checked-groups)))
  (unless (equal? (list-sort string<? (directory-files (artifact-root))) (list-sort string<? groups))
    (error "missing or extra test group artifacts"))
  (for-each (lambda (group)
    (check-group group base-key)
    (check-revision group revision)) groups)
  (displayln "BUILD-GROUPS-OK groups=" (length groups) " modules=" (length (test-files))))
;; Cache records are Scheme data outside Git. A fresh stamp follows key admission;
;; tests still execute on every hit. Standard Actions artifacts move the bytes.
(def (main mode base-key revision . groups)
  (if (equal? mode "collect") (check-all base-key revision)
    (let* ((group (if (= (length groups) 1) (car groups) (error "one test group required")))
           (root (group-root group)))
      (cond
        ((equal? mode "record")
          (call-with-output-file (list path: (path-expand "source.scm" root) truncate: #t)
            (lambda (port) (write (list 'test-group group base-key (group-source-key group) revision) port))))
        ((not (member mode '("verify" "check"))) (error "unknown artifact mode" mode)))
      (check-group group base-key)
      (if (equal? mode "check") (check-revision group revision)
        (call-with-output-file (list path: (path-expand "revision.scm" root) truncate: #t)
          (lambda (port) (write revision port))))
      (displayln "BUILD-GROUP-OK " group " source=" (group-source-key group)))))
;; Test fixtures may isolate cache receipts without changing the real Gerbil path.
(def build-root (make-parameter (gerbil-path)))
;; Enumerate finite source/resource trees, excluding generated compiler interfaces.
(def (build-files directory)
  (if (file-exists? directory)
    (append-map (lambda (name)
      (def path (path-expand name directory))
      (if (eq? (file-info-type (file-info path)) 'directory)
        (build-files path) [path])) (directory-files directory)) []))
;; Keep input names relative so temporary overlays and CI runners share identities.
(def (build-input-files root)
  (list-sort string<?
    (append (filter (lambda (name)
      (or (string-suffix? ".ss" name) (member name '("gerbil.pkg" "justfile"))))
      (directory-files root))
      (append-map (lambda (directory)
        (map (lambda (file) (substring file (string-length (path-expand "" root)) (string-length file)))
          (build-files (path-expand directory root)))) '("support" "examples" "t")))))
;; Hash exact bytes, not timestamps or an asserted producer revision.
(def (build-digests root files)
  (map (lambda (file) (cons file (hex-encode (sha256
    (call-with-input-file (path-expand file root) read-all-as-u8vector))))) files))
;; Prepare namespace stems once, rather than rescanning the test directory for
;; every compiler artifact. Both dynamic and static outputs follow Gerbil names.
(def (test-output-prefixes)
  (append-map (lambda (test)
    (def module (string-append "clan/poo/" (path-strip-extension test)))
    [module (string-append "static/" (string-join (string-split module #\/) "__"))])
    (test-files)))
;; A declared stem must be followed by a compiler suffix, never another module name.
(def (test-build-output? file (prefixes (test-output-prefixes)))
  (ormap (lambda (stem)
    (and (string-prefix? stem file) (> (string-length file) (string-length stem))
      (memv (string-ref file (string-length stem)) '(#\. #\~)))) prefixes))
;; Inspect only this package's namespace and static prefix, never another package.
(def (build-output-files shared?)
  (def lib (path-expand "lib/" (build-root)))
  (def prefixes (if shared? (test-output-prefixes) []))
  (def files (append (build-files (path-expand "clan/poo/" lib))
    (if (file-exists? (path-expand "static/" lib))
      (filter (lambda (file) (string-prefix? "clan__poo__" (path-strip-directory file)))
        (build-files (path-expand "static/" lib))) [])))
  (list-sort string<? (filter (lambda (file) (not (and shared? (test-build-output? file prefixes))))
    (map (lambda (file) (substring file (string-length lib) (string-length file))) files))))
;; Both source and output inventories are part of the complete generation identity.
(def (build-generation root shared? compiler)
  (def inputs (filter (lambda (file) (not (and shared? (string-suffix? "-test.ss" file))))
    (build-input-files root)))
  (def outputs (build-output-files shared?))
  (unless (pair? outputs) (error "compiled package is missing"))
  (list 'build-generation compiler (build-digests root inputs)
    (build-digests (path-expand "lib/" (build-root)) outputs)))
;; Missing, partial or changed receipts refuse reuse; callback errors are not passes.
(def (build-current? path root shared? compiler)
  (and (file-exists? path)
    (with-catch (lambda (_) #f)
      (lambda () (equal? (read-one-file path) (build-generation root shared? compiler))))))
;; Publish a complete datum only after successful compilation and source rechecks.
(def (save-build-generation path root shared? compiler)
  (def datum (build-generation root shared? compiler))
  (call-with-output-file (list path: path truncate: #t)
    (lambda (port) (write datum port) (newline port))) datum)
