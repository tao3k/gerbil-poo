;;; Inherited interception of the existing C3 and effective-slot operations.
(export with-inheritance-hooks)
(import ./object)
;; Attach an ordinary protocol object to an ordinary object; protocol methods can
;; themselves use C3 inheritance, before/after behavior and inherited continuations.
;; compute-precedence-list: (receiver next) -> SAME checked C3 order or refusal.
;; compute-slot: (receiver next slot) -> effective thunk, without running its body.
;; A custom slot transformation has its own semantics; equivalence needs its laws.
(def (with-inheritance-hooks protocol . supers)
  (unless (object? protocol) (error "inheritance protocol object required"))
  (make-object supers: supers protocol: protocol))
