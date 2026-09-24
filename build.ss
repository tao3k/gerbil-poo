#!/usr/bin/env gxi
;;; -*- Gerbil -*-
;;; Gerbil v0.19 package build for Gerbil POO.

(import
  (only-in :std/build-script defbuild-script)
  (only-in :std/make include-gambit-sharp))

;; Keep the package build graph explicit. V19 std/make owns dependency
;; scheduling and native compilation; this file only declares package inputs.
(def +gerbil-poo-fq-spec+
  (cond-expand
   (darwin
    ;; Gambit loads this AOT module as a Mach-O bundle. Math symbols such as
    ;; pow are resolved from the host runtime when the bundle is loaded.
    '(gxc: "fq" "-ld-options" "-Wl,-undefined,dynamic_lookup"))
   (else "fq")))

(def +gerbil-poo-build-spec+
  `("brace"
    "support/base"
    "support/debug"
    "support/io"
    "support/json"
    "support/list"
    "support/option"
    "support/rationaldict"
    "support/repr"
    "support/syntax"
    "support/testing"
    "cli"
    "debug"
    ,+gerbil-poo-fq-spec+
    "fun"
    (gxc: "io" ,@(include-gambit-sharp))
    "mop"
    "number"
    "object"
    "polynomial"
    "proto"
    "rationaldict"
    "table"
    "trie"
    "type"
    "t/table-testing"))

(defbuild-script +gerbil-poo-build-spec+)
