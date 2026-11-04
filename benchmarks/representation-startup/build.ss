#!/usr/bin/env -S gxi -:max-heap=1G,debug=q
;;; Standard program declarations; workload objects are built by the root package.
(import :std/build-script (only-in :std/make pkg-config-libs)
        (prefix-in "../../examples/build.ss" entry-build.)
        (only-in "../../t/build.ss" call-with-build-jobs))
;; Preserve the compiler backend bound in this standard package entry.
(let (options (getenv "GAMBOPT" #f))
  (setenv "GAMBOPT" (string-append (if options (string-append options ",") "") "max-heap=2G,debug=q")))
;; Standard make shares the programs' required static closure. Darwin already
;; prepared representation-main in the root graph; other platforms prepare it here.
(def build (let ((links (pkg-config-libs "openssl")))
  (defbuild-script
    (append
      (cond-expand
        (darwin [])
        (else (entry-build.representation-build-spec "../../examples/representation-main" links)))
      `((exe: "main" bin: "representation-startup"
        "-cc-options" "-O2 -D___SINGLE_HOST_LIMIT=10000" "-ld-options" ,links)))) main))
;; Public executor cleanup is shared with the other standard build entries.
(def (main . options) (call-with-build-jobs (cut apply build options)))
