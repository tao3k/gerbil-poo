#!/usr/bin/env gxi
;;; -*- Gerbil -*-
;;; Gerbil v0.19 package build for Gerbil POO.

(import
  (only-in :std/build-script defbuild-script)
  (only-in :std/make include-gambit-sharp))

;; Keep the package build graph explicit. V19 std/make owns dependency
;; scheduling and native compilation; this file only declares package inputs.
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
    "fq"
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
