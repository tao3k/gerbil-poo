#!/usr/bin/env -S gxi -:max-heap=1G,debug=q
;;; Standard executable package for the existing shared entry.
(export main representation-build-spec)
(import :std/build-script (only-in :std/source this-source-file)
        (only-in :std/make pkg-config-libs)
        (only-in "../t/build.ss" call-with-build-jobs))
;; Only this program's dependency closure needs static runtime objects.
(def (representation-build-spec (entry "representation-main"))
  `((exe: ,entry bin: "representation-main"
     "-cc-options" "-D___SINGLE_HOST_LIMIT=10000"
     "-ld-options" ,(pkg-config-libs "openssl"))))
(def build
  (let ()
    (defbuild-script (representation-build-spec))
    main))
;; Preserve the existing backend bound and standard compiler cleanup.
(def (main . options)
  (let (settings (getenv "GAMBOPT" #f))
    (setenv "GAMBOPT" (string-append (if settings (string-append settings ",") "") "max-heap=2G,debug=q")))
  (call-with-build-jobs (cut apply build options)))
