#!/usr/bin/env -S gxi -:max-heap=1G,debug=q
;;; Standard build for the existing contracts test responsibility.
(import :std/build-script (only-in "../build.ss" call-with-build-jobs))
;; The official compiler inherits the unchanged backend heap bound.
(let (options (getenv "GAMBOPT" #f))
  (setenv "GAMBOPT" (string-append (if options (string-append options ",") "") "max-heap=2G,debug=q")))
;; This is the authoritative make declaration; no source-input scanner is added.
(def build (let () (defbuild-script '("class-validation-test"
    "computed-validation-test"
    "container-validation-test"
    "contract-checks-test"
    "contract-family-test"
    "contract-publication-test"
    "evidence-binding-test"
    "object-contract-flow-test"
    "object-contract-test"
    "object-contract-validation-test"
    "optional-validation-test"
    "protected-dispatch-test"
    "recursive-approvals-test"
    "recursive-competition-test"
    "recursive-coordination-test"
    "recursive-migration-test"
    "recursive-publication-test"
    "recursive-recovery-test"
    "recursive-restaging-test"
    "recursive-revision-test"
    "recursive-staging-test"
    "recursive-submissions-test"
    "recursive-topology-test"
    "recursive-validation-test"
    "service-bundle-test"
    "service-metadata-test"
    "service-revisions-test"
    "shared-approvals-test"
    "variant-validation-test")) main))
;; Preserve standard options and let the public compiler executor finish its jobs.
(def (main . options) (call-with-build-jobs (cut apply build options)))
