#!/usr/bin/env -S gxi -:max-heap=1G,debug=q
;;; Standard build for the existing signatures test responsibility.
(import :std/build-script (only-in "../build.ss" call-with-build-jobs))
;; The official compiler inherits the unchanged backend heap bound.
(let (options (getenv "GAMBOPT" #f))
  (setenv "GAMBOPT" (string-append (if options (string-append options ",") "") "max-heap=2G,debug=q")))
;; This is the authoritative make declaration; no source-input scanner is added.
(def build (let () (defbuild-script '("function-coverage-test"
    "function-options-test"
    "keyword-coverage-test"
    "keyword-prefix-test"
    "keyword-rest-test"
    "keyword-values-test")) main))
;; Preserve standard options and let the public compiler executor finish its jobs.
(def (main . options) (call-with-build-jobs (cut apply build options)))
