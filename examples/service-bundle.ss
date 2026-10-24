;;; ServiceBundle: C4 method combination, negative watches and joint metadata.
(export Policy. model declarations admit cache-admit start revise)
(import :std/iter
        (only-in :std/values first-value)
        ../object
        (only-in ../mop define-type Any Bool)
        (only-in ../number IntegerRange)
        (only-in ../type String)
        (runtime: :clan/poo/contract-family)
        (prefix-in (only-in ../contract-family Source.) contract-family.)
        (runtime: :clan/poo/generic-family)
        (prefix-in (only-in ../generic-family Model. Projection.
                   methods.refresh<-projection) family.)
        (prefix-in ../staged-publication staged.)
        (runtime: :clan/poo/cyclic-publication)
        (prefix-in (only-in ../cyclic-publication probe same-service?
                   version-service version-view) publication.)
        (runtime: :clan/poo/declarative-metadata)
        (prefix-in (only-in ../declarative-metadata atom both check contribute family
                   guarded remove replace) metadata.)
        (runtime: :clan/poo/multimethod)
        (prefix-in (only-in ../multimethod cache-size make prototype) multimethod.)
        (runtime: :clan/poo/dispatch-extension)
        (prefix-in (only-in ../dispatch-extension call shape snapshot) dispatch.)
        (prefix-in ./protected-dispatch protected.)
        (runtime: :clan/poo/examples/cyclic-access)
        (prefix-in (only-in ./cyclic-access config equations) access.)
        (prefix-in ./service-metadata service.))
(define-type (Policy. @ [] capacity price invoice)
  reserve-shift: 0 cancel-shift: "" broken-reserve: #f forbidden-cancel: #f
  forbidden-quote: #f cancelled-extension: #f ceiling: 1000 cache-limit: 8)
(def units-type (IntegerRange min: 0))
(def (combine methods args)
  (if (null? methods) '(error missing) (apply (car methods) args)))
(def (seed key policy _)
  (case key
    ((quote) (protected.make-dispatch))
    ((reserve) (multimethod.make (list units-type) Any (lambda (_) '((Reserve))) combine
                               (if (.@ policy broken-reserve) 2 1)))
    ((cancel) (multimethod.make (list String Bool) Any
                  (lambda (args) (if (string=? (car args) "forbidden") '((Forbidden)) '((Cancel)))) combine 1))))
(def (declarations key policy view)
  (case key
    ((quote)
     (append
       (list (metadata.contribute "quote.financial" (protected.path 'Financial 'Card)
                 (lambda (_ __ amount) (+ amount (.@ view price))))
             (metadata.guarded "quote.bank" (protected.path 'Invoice 'Bank)
                 (lambda (_ __ amount) (> amount 100))
                 (lambda (_ __ amount) (+ amount (.@ view capacity)))))
       (if (.@ policy forbidden-quote)
         (list (metadata.replace "quote.forbidden" (protected.path 'Document 'Bank) (lambda (_ __ amount) amount))) [])
       (if (.@ policy cancelled-extension)
         (list (metadata.remove "quote.remove" (protected.path 'Document 'Bank))) [])))
    ((reserve)
     (list (metadata.replace "reserve.capacity" (list (multimethod.prototype 'Reserve))
               (lambda (units) (list 'ok (- (+ (.@ view capacity) (.@ policy reserve-shift)) units)
                                    (and (.@ view release) (<= units (.@ view capacity))))))))
    ((cancel)
     (append
       (list (metadata.replace "cancel.invoice" (list (multimethod.prototype 'Cancel))
               (lambda (customer consent)
                 (if consent (list customer (string-append (.@ view invoice) (.@ policy cancel-shift))) '(error consent)))))
       (if (.@ policy forbidden-cancel)
         (list (metadata.replace "cancel.forbidden" (list (multimethod.prototype 'Forbidden)) (lambda (_ __) '("forbidden")))) [])))))
(def (watches key)
  (case key
    ((quote) (protected.watches))
    ((reserve) (list (dispatch.shape '((Forbidden)))))
    ((cancel) (list (dispatch.call "forbidden" #t)))))
;; Projection is the closed lexical environment used by compilation, not a
;; revision label. Expand supplies only these inputs to the existing constructors.
(def projection
  (.cc family.Projection.
    project: (lambda (key policy view)
      (case key
        ((quote) (list (.@ view capacity) (.@ view price) (.@ policy forbidden-quote) (.@ policy cancelled-extension)))
        ((reserve) (list (.@ view capacity) (.@ view release) (.@ policy reserve-shift) (.@ policy broken-reserve)))
        ((cancel) (list (.@ view invoice) (.@ policy cancel-shift) (.@ policy forbidden-cancel)))))
    expand: (lambda (key inputs)
      (match (cons key inputs)
        (['quote capacity-value price-value forbidden cancelled]
         (values (.cc Policy. capacity: capacity-value price: price-value invoice: "" forbidden-quote: forbidden cancelled-extension: cancelled)
                 (.o (capacity capacity-value) (price price-value))))
        (['reserve capacity-value released shift broken]
         (values (.cc Policy. capacity: capacity-value price: 0 invoice: "" reserve-shift: shift broken-reserve: broken)
                 (.o (capacity capacity-value) (release released))))
        (['cancel invoice-value shift forbidden]
         (values (.cc Policy. capacity: 0 price: 0 invoice: invoice-value cancel-shift: shift forbidden-cancel: forbidden)
                 (.o (invoice invoice-value))))))))
(def generics
  (.mix (.cc family.methods.refresh<-projection projection: projection)
   (metadata.family
    (.cc family.Model. keys: '(quote reserve cancel) seed: seed watches: watches)
    declarations)))
(def contract-source
  (.cc contract-family.Source.
    keys: (lambda (_ __) '(reserve))
    project: (lambda (_ __ view) (.@ view capacity))
    construct: (lambda (_ capacity) (service.reservation capacity))))
(def (contracts _ view) (list (cons 'reserve (service.reservation (.@ view capacity)))))
(def release-rule
  (metadata.both (metadata.atom 'quote-bound)
    (metadata.both (metadata.atom 'reserve-linked)
      (metadata.both (metadata.atom 'cancel-linked)
        (metadata.both (metadata.atom 'release) (metadata.atom 'cache-budget))))))
(def (cache-admit policy candidate)
  (<= (apply + (map (lambda (service)
                     (multimethod.cache-size (dispatch.snapshot (publication.version-service candidate service))))
                   '(quote reserve cancel)))
      (.@ policy cache-limit)))
(def (admit policy candidate (old #f))
  (def view (publication.version-view candidate))
  ;; Probes validate actual implementations/contracts and discard tentative caches.
  (def (probe key . args) (first-value (apply publication.probe candidate key args)))
  (metadata.check release-rule
    (lambda (key)
      (case key
        ((quote-bound)
         (let (quote-result
                 (if (and (publication.same-service? old candidate 'quote)
                          (= (.@ view price) (.@ (publication.version-view old) price)))
                   (list 13 (+ 10 (.@ view price)))
                   (probe 'quote protected.invoice protected.card 10)))
           (and (equal? quote-result (list 13 (+ 10 (.@ view price))))
                (<= (apply + quote-result) (.@ policy ceiling)))))
        ((reserve-linked)
         (or (and (publication.same-service? old candidate 'reserve)
                  (= (.@ view capacity) (.@ (publication.version-view old) capacity)))
             (equal? (probe 'reserve 2) (list 'ok (- (.@ view capacity) 2) #t))))
        ((cancel-linked)
         (or (and (publication.same-service? old candidate 'cancel)
                  (equal? (.@ view invoice) (.@ (publication.version-view old) invoice)))
             (equal? (probe 'cancel "customer" #t) (list "customer" (.@ view invoice)))))
        ((release) (.@ view release))
        ((cache-budget) (cache-admit policy candidate))))))
(def model
  (.mix (.cc staged.methods.contracts<-projection contract-source: contract-source contracts-source: contracts)
   (.cc staged.Model. generics: generics contracts: contracts admit: admit
       ;; Dispatch cache insertion preserves methods, contracts and cooked view.
       ;; Business probes run on every release; actual successor budget on every call.
       .readmit: cache-admit
       admit-source: admit
       .admit-refresh: (lambda (old policy candidate) (admit policy candidate old))
       cook: (lambda (policy facts) (service.cook (.@ policy capacity) (.@ policy price) (.@ policy invoice) facts)))))
(def (start policy (config (access.config)) (enabled #t))
  (staged.prepare model (access.equations config enabled) policy))
(def (revise old policy (config (access.config)) (enabled #t))
  (staged.publish model old (access.equations config enabled) policy))
