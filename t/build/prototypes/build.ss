#!/usr/bin/env -S gxi -:max-heap=2G,debug=q
;;; Compiler-only standard package; the original test declarations stay authoritative.
(import (only-in "../../build.ss" build-test-partition))
;; Keep standard build options and the shared compiler cleanup contract.
(def (main . options) (build-test-partition "prototypes" options))
