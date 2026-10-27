#!/usr/bin/env -S gxi -:max-heap=1G,debug=q
;;; Standard program declarations; workload objects are built by the root package.
(import :std/build-script (only-in :std/make pkg-config-libs)
        (only-in "../../t/build.ss" call-with-build-jobs))
;; Preserve the compiler backend bound in this standard package entry.
(let (options (getenv "GAMBOPT" #f))
  (setenv "GAMBOPT" (string-append (if options (string-append options ",") "") "max-heap=2G,debug=q")))
;; Reuse pkg-config once; std/make owns object reuse, linking and cleanup.
;; Link consumers synchronously through make: concurrent executable requests
;; otherwise regenerate the same dependency C files before their jobs finish.
;; Library and test compilation retain the standard concurrent backend budget.
(def build (let ((links (pkg-config-libs "openssl")))
  (defbuild-script `(
    (exe: "generalized-benchmark-main" bin: "generalized-benchmark" "-cc-options" "-D___SINGLE_HOST_LIMIT=10000" "-ld-options" ,links)
    (exe: "generalized-suite-main" bin: "generalized-suite" "-cc-options" "-D___SINGLE_HOST_LIMIT=10000" "-ld-options" ,links)) parallelize: #f) main))
;; Close the standard executor on refusal; no project process registry is used.
(def (main . options) (call-with-build-jobs (cut apply build options)))
