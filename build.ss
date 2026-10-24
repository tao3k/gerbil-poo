#!/usr/bin/env -S timeout --signal=TERM --kill-after=5s 180s gxi
;;; Standard package build entry; inventories live with the build support.
(import (only-in :std/build-script defbuild-script)
        (only-in "t/build-spec.ss" build-request build-consumer consumer-request))

;; The standard macro owns option parsing, dependencies, incremental builds,
;; cleanup and backend scheduling. Only inventory and output selection vary.
(def (build-selected spec output options)
  (defbuild-script spec libdir: output)
  (apply main options))

;; Consumers own their complete test/example prerequisites. Metadata/spec/clean
;; requests remain non-compiling; std/make still owns freshness and scheduling.
(def (run-consumer args)
  (def options (caddr (consumer-request args)))
  (when (or (null? options) (equal? (car options) "compile"))
    (apply build-selected (build-request (cons "qualification" options))))
  (apply build-consumer args))

;; Explicit arguments select shared modules, test groups or benchmark programs;
;; ordinary compile/clean/spec/meta options pass through to defbuild-script.
(def (main . args)
  (match args
    ;; Standard Gambit timing reports make work/GC separately from whole-process timing.
    (["library" . _] (time (apply build-selected (build-request args))))
    (["qualification" . _] (time (apply build-selected (build-request args))))
    (["benchmark" . _] (time (run-consumer args)))
    (["test-program" . _] (time (run-consumer args)))
    (else (apply build-selected (build-request args)))))
