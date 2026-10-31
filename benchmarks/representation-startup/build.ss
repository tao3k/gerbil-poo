#!/usr/bin/env -S gxi -:max-heap=1G,debug=q
;;; Standard program declarations; workload objects are built by the root package.
(import :std/build-script (only-in :std/make pkg-config-libs)
        (only-in "../../t/build.ss" call-with-build-jobs))
;; Preserve the compiler backend bound in this standard package entry.
(let (options (getenv "GAMBOPT" #f))
  (setenv "GAMBOPT" (string-append (if options (string-append options ",") "") "max-heap=2G,debug=q")))
;; One standard executable graph retains the compiler's concurrent object jobs.
(def build (let ((links (pkg-config-libs "openssl")))
  (defbuild-script `((exe: "main" bin: "representation-startup"
    "-cc-options" "-D___SINGLE_HOST_LIMIT=10000" "-ld-options" ,links))) main))
;; Public executor cleanup is shared with the other standard build entries.
(def (main . options) (call-with-build-jobs (cut apply build options)))
