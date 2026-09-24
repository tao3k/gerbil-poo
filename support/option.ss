;;; Option values used by the persistent table interfaces.

(export #t)

(defstruct some (value) transparent: #t)

(def (option-ref x)
  (match x ((some value) value) (else (error "no value" x))))
(def (option-get/default x (default false))
  (match x ((some value) value) (else (default))))
(def (map/option f x)
  (match x ((some value) (some (f value))) (else x)))
