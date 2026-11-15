#!/usr/bin/env -S gxi -:max-heap=2G,debug=q
;;; Fixtures for the tests that exercise Gerbil's compiled module loader.
(export main representation-build-spec)
(import :std/build-script (only-in :std/source this-source-file)
        (only-in :std/make pkg-config-libs)
        (only-in "../t/build.ss" call-with-build-jobs))
;; Only this program's dependency closure needs static runtime objects.
(def (representation-build-spec (entry "representation-main") (links (pkg-config-libs "openssl")))
  `((exe: ,entry bin: "representation-main"
     "-cc-options" "-O2 -D___SINGLE_HOST_LIMIT=10000"
     "-ld-options" ,links)))
(def build
  (let ()
    (defbuild-script
      (append '((gxc: "representation-service" "-cc-options" "-O2")
                (gxc: "generalized-checkout" "-cc-options" "-O2")
                (gxc: "inherited-services" "-cc-options" "-O2")
                (gxc: "property-workflows" "-cc-options" "-O2")
                (gxc: "property-refusals" "-cc-options" "-O2"))
              (representation-build-spec)))
    main))
;; Preserve the existing backend bound and standard compiler cleanup.
(def (main . options)
  (let (settings (getenv "GAMBOPT" #f))
    (setenv "GAMBOPT" (string-append (if settings (string-append settings ",") "") "max-heap=2G,debug=q")))
  (call-with-build-jobs (cut apply build options)))
