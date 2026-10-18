;;-*- Gerbil -*-
;;; Brace syntax for POO

(export @method @@method)

(import
  (prefix-in (only-in :gerbil/core @method) @)
  (only-in ./object .o))

;; The core alias preserves the SAME match-aware binding as .o, including its
;; expression use-site context. .o alone owns match/constructor selection and
;; slot lowering; braces do not supply another expander or receiver scope.
;; Keep @@method above as the explicit escape to Gerbil's host method syntax.
(defalias @method .o)
