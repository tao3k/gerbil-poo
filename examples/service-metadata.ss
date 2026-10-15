;;; ServiceMetadata: cooked refinements on a heterogeneous declared family.
;;; Generalized-prototype future work; the finite cyclic graph is CyclicAccess's.
(export reservation declarations contracts services cook start revise release-rule)
(import :std/iter (only-in :std/func compose) (only-in ../mop element?) (only-in :std/values first-value)
        (only-in :std/list/list delete-duplicates/hash append-map)
        ../object (only-in ../mop Any Bool) (only-in ../number Integer IntegerRange)
        (only-in ../type String List)
        (prefix-in ../declarative-metadata metadata.)
        (prefix-in ../multimethod multimethod.)
        (prefix-in ../dispatch-extension dispatch-extension.)
        (prefix-in ../cyclic-publication publication.)
        (prefix-in ./cyclic-access access.))
(def units-type (IntegerRange min: 0))
(def (reservation available)
  (metadata.contract
    (metadata.predicate "positive-units" (match <> ([units] (and (element? units-type units) (> units 0))) (else #f)))
    (metadata.predicate "successful-reservation"
      (match <> (['ok remaining permitted] (and (integer? remaining) (>= remaining 0) (boolean? permitted))) (else #f)))
    (lambda (key args result)
      (case key
        ((permission) (<= (car args) available))
        ((conservation) (equal? result (list 'ok (- available (car args)) #t)))))
    (metadata.both (metadata.atom 'permission) (metadata.atom 'conservation))))
(def (declarations view)
  (list
    (cons 'quote (list (metadata.replace "quote.total" [] (lambda (units) (* units (.@ view price))))))
    (cons 'reserve (list (metadata.replace "reserve.capacity" []
                    (lambda (units) (list 'ok (- (.@ view capacity) units) (and (.@ view release) (<= units (.@ view capacity))))))))
    (cons 'cancel (list (metadata.replace "cancel.invoice" []
                    (lambda (customer consent) (if consent (list customer (.@ view invoice)) '(error consent))))))))
(def (combine methods args) (apply (car methods) args))
(def (seed service)
  ;; Dispatch arity zero, with heterogeneous typed argument rows. No parallel
  ;; dispatch implementation: these declarations use the existing sparse index.
  (case service
    ((quote) (multimethod.make (list units-type) Integer (lambda (_) []) combine 0))
    ((reserve) (multimethod.make (list units-type) Any (lambda (_) []) combine 0))
    ((cancel) (multimethod.make (list String Bool) Any (lambda (_) []) combine 0))))
(def (services view)
  (map (match <> ([name . declarations]
          (cons name (dispatch-extension.check (metadata.install (seed name) declarations) []))))
       (declarations view)))
(def (contracts view) (list (cons 'reserve (reservation (.@ view capacity)))))
(def (cook available unit-price invoice-name facts)
  (def access (access.cook facts))
  (.cc access capacity: available price: unit-price invoice: invoice-name))
(def release-rule
  (metadata.both (metadata.atom 'distinct-names)
    (metadata.both (metadata.atom 'quote-bound)
      (metadata.both (metadata.atom 'reserve-linked) (metadata.atom 'cancel-linked)))))
(def (admit ceiling candidate)
  (def view (publication.version-view candidate))
  (def (probe service . args) (first-value (apply publication.invoke candidate service args)))
  (metadata.check release-rule
    (lambda (key)
      (case key
        ((distinct-names)
         (let (names (append-map (compose (cut map metadata.declaration-name <>) cdr) (declarations view)))
           (= (length names) (length (delete-duplicates/hash names)))))
        ((quote-bound) (<= 0 (probe 'quote 2) ceiling))
        ((reserve-linked) (equal? (probe 'reserve 2) (list 'ok (- (.@ view capacity) 2) #t)))
        ((cancel-linked) (equal? (probe 'cancel "customer" #t) (list "customer" (.@ view invoice))))))))
(def (start config seed available unit-price invoice-name ceiling)
  (publication.prepare (access.equations config seed) (cut cook available unit-price invoice-name <>) services
                       (cut admit ceiling <>) contracts))
(def (revise old config seed available unit-price invoice-name ceiling)
  ;; Publication retains the builder, which rebinds contracts to the new view.
  (publication.publish old (access.equations config seed) (cut cook available unit-price invoice-name <>) services
                       (cut admit ceiling <>)))
