;;; Source-bound admission for disjoint compiled test-group artifacts.
(export main artifact-key-valid? artifact-root group-root check-group check-all read-one-file group-source-key test-inventory-key)
(import :std/misc/ports :std/crypto/digest :std/encoding/hex "test-groups.ss")
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
;; Source hashing belongs to artifact admission; inventory consumers do not need
;; crypto or JSON initialization. Preserve the same filename/digest preimage.
(def (group-source-key group)
  (hex-encode (sha256 (string->utf8 (call-with-output-string (lambda (port) (write
    (map (lambda (file) (cons file (hex-encode
      (sha256 (call-with-input-file file read-all-as-u8vector))))) (test-files group)) port)))))))
;; Executable linkage embeds the ordered filenames, not test bodies. Group keys
;; separately bind every body; cached consumers must never stand in for that check.
(def (test-inventory-key (files (test-files)))
  (hex-encode (sha256 (string->utf8
    (call-with-output-string (lambda (port) (write files port)))))))
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
