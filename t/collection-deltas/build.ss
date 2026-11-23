#!/usr/bin/env -S gxi -:max-heap=2G,debug=q
;;; Standard build for the existing collection-deltas test responsibility.
(import :std/build-script (only-in "../build.ss" test-build-spec)
        (only-in "../../support/compile-jobs.ss" call-with-build-jobs))
;; The official compiler inherits the unchanged backend heap bound.
(let (options (getenv "GAMBOPT" #f))
  (setenv "GAMBOPT" (string-append (if options (string-append options ",") "") "max-heap=2G,debug=q")))
;; Reuse the same authoritative declarations as the complete standard build graph.
(def build (let () (defbuild-script (test-build-spec "collection-deltas")) main))
;; Preserve standard options and let the public compiler executor finish its jobs.
(def (main . options) (call-with-build-jobs (cut apply build options)))
