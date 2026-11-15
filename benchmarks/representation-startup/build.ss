#!/usr/bin/env -S gxi -:max-heap=1G,debug=q
;;; Linked startup programs and the workloads called through the module loader.
(import :std/build-script
        (rename-in (only-in "../../build.ss" project-build-source)
          (project-build-source this-source-file))
        (only-in :std/make pkg-config-libs)
        (only-in "../../t/build.ss" call-with-build-jobs))
;; Preserve the compiler backend bound in this standard package entry.
(let (options (getenv "GAMBOPT" #f))
  (setenv "GAMBOPT" (string-append (if options (string-append options ",") "") "max-heap=2G,debug=q")))
(def build (let ((links (pkg-config-libs "openssl")))
  (defbuild-script
    (append
      '((gxc: "benchmarks/closure-measure" "-cc-options" "-O2")
        (gxc: "benchmarks/representation-startup" "-cc-options" "-O2")
        (gxc: "benchmarks/prototype-map-benchmark" "-cc-options" "-O2")
        (gxc: "benchmarks/collection-paired-slots" "-cc-options" "-O2")
        (gxc: "benchmarks/collection-paired-order" "-cc-options" "-O2")
        (gxc: "benchmarks/collection-paired-backends" "-cc-options" "-O2")
        (gxc: "benchmarks/collection-paired-benchmark" "-cc-options" "-O2")
        (gxc: "benchmarks/generation-benchmark" "-cc-options" "-O2"))
      `((exe: "benchmarks/representation-startup/main" bin: "representation-startup"
        "-cc-options" "-O2 -D___SINGLE_HOST_LIMIT=10000" "-ld-options" ,links)))) main))
;; Public executor cleanup is shared with the other standard build entries.
(def (main . options) (call-with-build-jobs (cut apply build options)))
