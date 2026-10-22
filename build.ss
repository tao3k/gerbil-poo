#!/usr/bin/env gxi
;;; Standard package build entry; inventories live with the build support.
(import (only-in :std/build-script defbuild-script)
        (only-in "t/build-spec.ss" build-request build-consumer))

;; The standard macro owns option parsing, dependencies, incremental builds,
;; cleanup and backend scheduling. Only inventory and output selection vary.
(def (build-selected spec output options)
  (defbuild-script spec libdir: output)
  (apply main options))

;; Explicit arguments select shared modules, test groups or benchmark programs;
;; ordinary compile/clean/spec/meta options pass through to defbuild-script.
(def (main . args)
  (match args
    ;; Standard Gambit timing reports make work/GC separately from whole-process timing.
    (["library" . _] (time (apply build-selected (build-request args))))
    (["benchmark" . _] (apply build-consumer args))
    (["test-program" . _] (apply build-consumer args))
    (else (apply build-selected (build-request args)))))
