#!/usr/bin/env -S gxi -:max-heap=1G,debug=q
;;; Standard build for the existing collection-deltas test responsibility.
(import :std/build-script (only-in "../build.ss" call-with-build-jobs))
;; The official compiler inherits the unchanged backend heap bound.
(let (options (getenv "GAMBOPT" #f))
  (setenv "GAMBOPT" (string-append (if options (string-append options ",") "") "max-heap=2G,debug=q")))
;; This is the authoritative make declaration; no source-input scanner is added.
(def build (let () (defbuild-script '("table-batch-test"
    "table-capture-test"
    "table-origins-test"
    "table-transport-test")) main))
;; Preserve standard options and let the public compiler executor finish its jobs.
(def (main . options) (call-with-build-jobs (cut apply build options)))
