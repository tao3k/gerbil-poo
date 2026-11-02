#!/usr/bin/env -S gxi -:max-heap=2G,debug=q
;;; Compiler-only standard package; no additional installed Type namespace.
(import (only-in "../../build.ss" build-test-partition))
;; Preserve standard options while bounding signature/inference source contexts.
(def (main . options) (build-test-partition "types" options))
