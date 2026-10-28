#!/usr/bin/env -S gxi -:max-heap=1G,debug=q
;;; Standard independent-library build; POO derivation modules are not inputs.
(import :std/build-script (only-in :std/source this-source-file))
(export main)
(defbuild-script '("generator" "property" "model" "replay"))
