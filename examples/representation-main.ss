;;; Shared POO foundation with standard on-demand business-module initialization.
(export main)
(import (only-in :gerbil/runtime/loader list-modules)
        (only-in ../io module-action)
        (runtime: :clan/poo/generalized-prototype))
;; Link only the common foundation. Business modules remain ordinary compiled
;; plugins: the same module and explicit binding can be called by gxi or this exe.
;; No import-time enumeration, custom search path or entry registry is installed.
(def (main module binding . arguments)
  (let (before (list-modules))
    (display "MODULE-ENTRY ")
    (write (vector (and (assoc module before) #t)
      (andmap (lambda (id) (let (entry (assoc id before)) (and entry (eq? (cdr entry) 'builtin))))
        '("clan/poo/object" "clan/poo/mop" "clan/poo/generalized-prototype"))
      (length before)))
    (newline) (force-output))
  ((module-action module (string->symbol binding)) arguments))
