;;; Native standard/simple method combination in the existing joint service chain.
(export standard-model simple-model start revise)
(import ../object (only-in ../mop Any) (only-in ../number IntegerRange)
        (prefix-in ../multimethod dispatch.) (prefix-in ../method-combination combination.)
        (prefix-in ../declarative-metadata metadata.) (prefix-in ../staged-publication staged.)
        (prefix-in ./shared-contracts shared.) (prefix-in ./cyclic-access access.))
;; Reserve arguments retain their ordinary runtime Type; dispatch has one C4 axis.
(def units-type (IntegerRange min: 0))
;; Shared immutable projection reconstructs the same policy/view for seed and edits.
;; Other heterogeneous services retain their existing seed, watches and compilation.
(def original (.@ shared.expanded-generics seed))
;; The simple accumulator represents remaining capacity; individual item results
;; are integers while the final service result retains the checked reservation shape.
(def remaining-policy
  (.cc combination.SimplePolicy. stop: (lambda (_) #f) empty: 0 first: identity
       step: (lambda (value acc) (+ acc value)) finish: (lambda (remaining) (list 'ok remaining #t))))
;; Construct a typed standard/simple reserve seed, or the original sibling seed.
;; Native registration owns the method carrier; malformed qualifiers fail before bodies run.
(def (seed mode key policy view)
  (if (eq? key 'reserve)
    (case mode
      ((standard) (dispatch.standard (list units-type) Any (lambda (_) '((Reserve Object)))))
      ((simple) (dispatch.simple (list units-type) Any (lambda (_) '((Reserve Object))) remaining-policy))
      (else (error "unknown combination mode" mode)))
    (original key policy view)))
;; Reuse sibling declarations. Reserve's primary/around/side groups and simple
;; item/around groups stay in the existing declarative edit and negative-watch chain.
;; Callbacks observe only their reconstructed current immutable environment.
(def (declarations mode key policy view)
  (if (not (eq? key 'reserve))
    ((.@ shared.expanded-generics methods) key policy view)
    (let ((exact (list (dispatch.prototype 'Reserve))) (base (list (dispatch.prototype 'Object))))
      (map metadata.compile
        (case mode
          ((standard)
           (list
             (metadata.replace "reserve.base" base
               (combination.primary (lambda (_ units) (list 'ok (- (.@ view capacity) units) #t))))
             (metadata.replace "reserve.primary" exact
               (combination.primary (lambda (next _) (next))))
             (metadata.contribute "reserve.before" exact
               (combination.before (lambda (units)
                 (unless (> units 0) (error "positive reservation required")))))
             (metadata.contribute "reserve.after" exact
               (combination.after (lambda (_)
                 (unless (.@ view release) (error "reservation release required")))))
             (metadata.contribute "reserve.around" exact
               (combination.around (lambda (next units)
                 (unless (<= units (.@ view capacity)) (error "reservation capacity exceeded"))
                 (next))))))
          ((simple)
           (list
             (metadata.replace "reserve.capacity" base (combination.item (lambda (_) (.@ view capacity))))
             (metadata.replace "reserve.debit" exact (combination.item (lambda (units) (- units))))
             (metadata.contribute "reserve.around" exact
               (combination.around (lambda (next units)
                 (unless (and (.@ view release) (<= units (.@ view capacity))) (error "reservation unavailable"))
                 (next))))))
          (else (error "unknown combination mode" mode)))))))
;; Compose a selected carrier into shared expansion, stamped contracts, preparation
;; budget, warm-cache transport and exact-successor joint admission. No new publisher.
(def (model mode)
  (.cc shared.budgeted-model generics:
    (.cc shared.expanded-generics seed: (cut seed mode <> <> <>) methods: (cut declarations mode <> <> <>))))
;; Complete standard qualified service model; primary next retains the argument row.
(def standard-model (model 'standard))
;; Complete simple-policy service model; item/accumulator/output types may differ.
(def simple-model (model 'simple))
;; Prepare the selected model from existing finite access equations and policy.
;; Return version/failure using the same atomic lifecycle as the original bundle.
(def (start selected policy) (staged.prepare selected (access.equations (access.config) #t) policy))
;; Revise the same source under new policy; source/type/watch/contract approval errors
;; retain the exact old version. External effect rollback is not claimed.
(def (revise selected old policy) (staged.publish selected old (access.equations (access.config) #t) policy))
