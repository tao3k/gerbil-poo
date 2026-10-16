;;; ServiceMetadata: cooked refinements on a heterogeneous declared family.
;;; Generalized-prototype future work; the finite cyclic graph is CyclicAccess's.
(export reservation specialized-reservation declarations contracts services cook start revise release-rule)
(import :std/iter (only-in :std/func compose) (only-in ../mop element?) (only-in :std/values first-value)
        (only-in :std/list/list delete-duplicates/hash append-map)
        ../object (only-in ../mop Any Bool) (only-in ../number Integer IntegerRange)
        (only-in ../type String List)
        (prefix-in ../declarative-metadata metadata.)
        (prefix-in ../multimethod multimethod.)
        (prefix-in ../dispatch-extension dispatch-extension.)
        (prefix-in ../cyclic-publication publication.)
        (prefix-in ./cyclic-access access.))
;; Nonnegative native integer Type used by all declared service argument rows.
(def units-type (IntegerRange min: 0))
;; Interpret permission and conservation against the supplied current capacity.
(def (reservation-meaning available)
  (lambda (key args result)
    (case key
      ((permission) (<= (car args) available))
      ((conservation) (equal? result (list 'ok (- available (car args)) #t))))))
;; Validate invariant native Type/Formula descriptors once; specialize only meaning.
(def reservation-template
  (metadata.contract
    (metadata.predicate "positive-units" (match <> ([units] (and (element? units-type units) (> units 0))) (else #f)))
    (metadata.predicate "successful-reservation"
      (match <> (['ok remaining permitted] (and (integer? remaining) (>= remaining 0) (boolean? permitted))) (else #f)))
    (reservation-meaning 0)
    (metadata.both (metadata.atom 'permission) (metadata.atom 'conservation))))
;; Baseline specialization copies current meaning while ordinary wrap compiles fresh checks.
(def (reservation available) (.cc reservation-template meaning: (reservation-meaning available)))
;; Reuse invariant native checks through the existing withMeaning specialization
;; protocol. Capacity remains the new dependent meaning, never a cached result.
(def (specialized-reservation available)
  (metadata.with-meaning reservation-template (reservation-meaning available)))
;; Declare quote, reserve and cancel implementations against this cooked service view.
(def (declarations view)
  (list
    (cons 'quote (list (metadata.replace "quote.total" [] (lambda (units) (* units (.@ view price))))))
    (cons 'reserve (list (metadata.replace "reserve.capacity" []
                    (lambda (units) (list 'ok (- (.@ view capacity) units) (and (.@ view release) (<= units (.@ view capacity))))))))
    (cons 'cancel (list (metadata.replace "cancel.invoice" []
                    (lambda (customer consent) (if consent (list customer (.@ view invoice)) '(error consent))))))))
;; Invoke the selected primary procedure with its complete typed service argument row.
(def (combine methods args) (apply (car methods) args))
;; Build each heterogeneous typed generic over the existing sparse index; unknown service is absent.
(def (seed service)
  ;; Dispatch arity zero, with heterogeneous typed argument rows. No parallel
  ;; dispatch implementation: these declarations use the existing sparse index.
  (case service
    ((quote) (multimethod.make (list units-type) Integer (lambda (_) []) combine 0))
    ((reserve) (multimethod.make (list units-type) Any (lambda (_) []) combine 0))
    ((cancel) (multimethod.make (list String Bool) Any (lambda (_) []) combine 0))))
;; Compile declarations, install edits and check complete generic candidates using existing APIs.
(def (services view)
  (map (match <> ([name . declarations]
          (cons name (dispatch-extension.check (metadata.install (seed name) declarations) []))))
       (declarations view)))
;; Publish the current reservation refinement and dependent conservation contract.
(def (contracts view) (list (cons 'reserve (reservation (.@ view capacity)))))
;; Combine finite access facts with current capacity, price and invoice representation.
(def (cook available unit-price invoice-name facts)
  (def access (access.cook facts))
  (.cc access capacity: available price: unit-price invoice: invoice-name))
;; Joint approval formula linking unique service names and three current service observations.
(def release-rule
  (metadata.both (metadata.atom 'distinct-names)
    (metadata.both (metadata.atom 'quote-bound)
      (metadata.both (metadata.atom 'reserve-linked) (metadata.atom 'cancel-linked)))))
;; Probe the candidate through current generics and contracts; false declines atomic publication.
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
;; Construct and approve an initial finite service snapshot; return version or typed failure.
(def (start config seed available unit-price invoice-name ceiling)
  (publication.prepare (access.equations config seed) (cut cook available unit-price invoice-name <>) services
                       (cut admit ceiling <>) contracts))
;; Stage current equations/policy and atomically retain old version if joint approval refuses.
(def (revise old config seed available unit-price invoice-name ceiling)
  ;; Publication retains the builder, which rebinds contracts to the new view.
  (publication.publish old (access.equations config seed) (cut cook available unit-price invoice-name <>) services
                       (cut admit ceiling <>)))
