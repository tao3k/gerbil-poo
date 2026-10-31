;;; Parameterized service construction composes syntax, C3, generic calls and FUN.
(export Service specialize-action quote-service)
(import ../object
        ../mop
        ../number
        (prefix-in ../object-contract contract.)
        ../object-contract
        (prefix-in ../parameters parameters.)
        (runtime: :clan/poo/fun)
        (prefix-in (only-in :clan/poo/fun Observation.) fun.))

;; Canonical generic formals evaluate defaults at the call boundary exactly once.
(.defgeneric (quote-service self units (discount 0) currency: (currency 'USD) . notes) slot: quote)

;; A shared ancestor contributes once under C3; each child modifies its own slot's
;; inherited computation. Parameter values are supplied later by persistent copies.
(def base (.o fee: 5 region: 'global))
;; The left extension composes one inherited fee contribution.
(def left (.o inherit: (list base) (fee => (lambda (value) (+ value 1)))))
;; The right extension shares the same base rather than duplicating its fee.
(def right (.o inherit: (list base) (fee => (lambda (value) (+ value 2)))))

;; Disable automatic local slot bindings; region is explicitly imported, while
;; capacity/tariff are accessed on final-self. super is the current fee thunk.
(def Service (.o self: receiver super: inherited inherit: (list left right)
  bind: (region) bind-these: #f
  (.parameters '(capacity tariff))
  (fee (+ (inherited) (.get receiver tariff)))
  (total (+ (* (.get receiver capacity) (.get receiver tariff)) (.get receiver fee)))
  (quote (lambda (units discount currency: currency . notes)
    (values (- (* units (.get receiver total)) discount) currency region notes)))))

;; Normalize and admit a completed service before the FUN consumer may observe it.
(def ClosedService (contract.refine
  (.cc contract.ObjectContract. responsibilities: (.o capacity: Integer tariff: Integer)
    extra-fields: 'delegate constraints: (list Object))
  (lambda (value location)
    (if (and (>= (.get value capacity) 0) (>= (.get value tariff) 0)) []
      [(.o kind: 'negative-parameter path: location)]))))

;; Explicit prefix specialization is a Reader computation. Existing checked-action
;; gates the exact derived receiver before invoking the result/effect consumer;
;; original contexts and any other entry's partially specialized object are retained.
(def (specialize-action arguments consume)
  (.call fun.Observation. .bind
    (lambda (template) (apply parameters.specialize template arguments))
    (lambda (candidate) (lambda (_template) ((checked-action ClosedService consume) candidate)))))
