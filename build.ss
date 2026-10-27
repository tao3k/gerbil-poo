#!/usr/bin/env -S gxi -:max-heap=2G,debug=q
;;; Standard package build entry; inventories live with the build support.
(import (only-in :std/build-script defbuild-script)
        (only-in "t/build-spec.ss" build-request build-consumer consumer-request))

;; The standard macro owns option parsing, dependencies, incremental builds,
;; cleanup and backend scheduling. Only inventory and output selection vary.
(def (build-selected spec output options)
  ;; Compiler children inherit the build process environment; the package manager
;; and its later indexer are outside this native build invocation.
(let (options (getenv "GAMBOPT" #f))
  (setenv "GAMBOPT"
    (string-append (if options (string-append options ",") "")
                   "max-heap=2G,debug=q")))

(defbuild-script spec libdir: output)
  (apply main options))

;; Consumers own their complete test/example prerequisites. Metadata/spec/clean
;; requests remain non-compiling; std/make still owns freshness and scheduling.
(def (run-consumer args)
  (def options (caddr (consumer-request args)))
  ;; Failed prerequisite compilation can leave early outputs too. Standard clean
  ;; must reach that same owned graph before cleaning the consumer itself.
  (when (or (null? options) (member (car options) '("compile" "clean")))
    (apply build-selected (build-request (cons "qualification" options))))
  (apply build-consumer args))

;; Explicit arguments select shared modules, test groups or benchmark programs;
;; ordinary compile/clean/spec/meta options pass through to defbuild-script.
(def (main . args)
  (match args
    ;; Standard Gambit timing reports make work/GC separately from whole-process timing.
    (["library" . _] (time (apply build-selected (build-request args))))
    (["qualification" . _] (time (apply build-selected (build-request args))))
    ;; The linked collection workflow already owns complete producer admission.
    ;; Compile only its workload; standard clean likewise owns only this consumer.
    (["linked-benchmark" . _] (time (apply build-consumer args)))
    (["benchmark" . _] (time (run-consumer args)))
    (["test-program" . _]
      (cond-expand
        (darwin (time (apply build-selected (build-request args))))
        (else (time (run-consumer args)))))
    (else (apply build-selected (build-request args)))))
