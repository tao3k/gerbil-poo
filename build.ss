#!/usr/bin/env gxi
;;; Standard package build entry; inventories live with the build support.
(import (only-in :std/build-script defbuild-script)
        (only-in :gerbil/runtime/system gerbil-path)
        (only-in "t/build-spec.ss" build-request))

;; The standard macro owns option parsing, dependencies, incremental builds,
;; cleanup and backend scheduling. Only inventory and output selection vary.
(def (build-selected spec output options)
  (defbuild-script spec
    bindir: (path-expand ".build/combination")
    libdir: (or output (path-expand "lib" (gerbil-path))))
  (apply main options))

;; Explicit arguments select shared modules, test groups or benchmark programs;
;; ordinary compile/clean/spec/meta options pass through to defbuild-script.
(def (main . args)
  (apply build-selected (build-request args)))
