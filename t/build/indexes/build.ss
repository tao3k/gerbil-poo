#!/usr/bin/env -S gxi -:max-heap=2G,debug=q
;;; Compiler-only standard package; the original test declarations stay authoritative.
(import (only-in "../../build.ss" build-test-partition))
;; Preserve standard options while bounding ordered/indexed collection contexts.
(def (main . options) (build-test-partition "indexes" options))
