;;; Gerbil predicate contracts with the existing POO boundary refusal policy.
(export check-contract)
(import (only-in :std/error contract-violation-error?))

;; Evaluate the user predicate once OUTSIDE the translation handler. Gerbil using
;; owns the truthiness check; its guarded body only returns the original value.
;; Only that local ContractViolation is translated. Predicate exceptions (including
;; ContractViolation), nonlocal exits and later consumer/body errors stay original.
;; No Type normalization, dynamic descriptor cache or new contract DSL lives here.
(def (check-contract value predicate refuse)
  (let (accepted (predicate value))
    (try
      (using (value :~ (lambda (_) accepted)) value)
      (catch (cause)
        (if (contract-violation-error? cause) (refuse) (raise cause))))))
