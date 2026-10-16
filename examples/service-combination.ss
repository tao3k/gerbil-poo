;;; Native qualified, forwarding and superclass-controlled method combination in the existing joint service chain.
(export standard-model simple-model forwarding-model inner-model simula-model forwarder preflight start revise)
(import ../object (only-in ../mop Any element?) (only-in :std/values first-value)
        (prefix-in ../dispatch-extension extension.) (only-in ../number IntegerRange)
        (only-in ../support/option some) (prefix-in ../multimethod dispatch.) (prefix-in ../method-combination combination.)
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

;; Typed enrichment payload: units, current invoice, and symbolic approval trail.
;; Replacements are checked by the existing Type protocol before each continuation.
(def payload-type (metadata.predicate "reservation-payload"
  (match <> ([units invoice trail] (and (element? units-type units) (string? invoice)
    (list? trail) (andmap symbol? trail))) (else #f))))
;; Build a protected forwarding generic for request enrichment. Around installs
;; current invoice, primary adds an approval marker, and the inherited arithmetic
;; sees the updated payload while its dispatch identity stays fixed.
(def (forwarder view)
  (def seed (dispatch.forwarding-standard Any payload-type Any (lambda (_) '((Reserve Object)))))
  (def generic (metadata.install seed
    (list
      (metadata.replace "payload.base" (list (dispatch.prototype 'Object))
        (combination.forward-primary (lambda (_ dispatch payload)
          (unless (and (eq? dispatch 'reserve) (equal? (cadr payload) (.@ view invoice))
                       (equal? (caddr payload) '(approved))) (error "stale request enrichment"))
          (list 'ok (- (.@ view capacity) (car payload)) #t))))
      (metadata.replace "payload.approval" (list (dispatch.prototype 'Reserve))
        (combination.forward-primary (lambda (next _ payload)
          (next (some (list (car payload) (cadr payload) '(approved)))))))
      (metadata.contribute "payload.invoice" (list (dispatch.prototype 'Reserve))
        (combination.forward-around (lambda (next _ payload)
          (unless (and (.@ view release) (> (car payload) 0) (<= (car payload) (.@ view capacity)))
            (error "forwarded reservation unavailable"))
          (next (some (list (car payload) (.@ view invoice) (caddr payload))))))))))
  (extension.snapshot (extension.check generic (list (extension.shape '((Forbidden)))))))
;; Build a typed Simula preflight whose general/specific prefix/suffix checks all
;; use the current reconstructed view. A raised check aborts the remaining stages.
(def (preflight view)
  (def seed (dispatch.simula (list units-type) (lambda (_) '((Reserve Object)))))
  (def generic (metadata.install seed
    (list
      (metadata.replace "preflight.general" (list (dispatch.prototype 'Object))
        (combination.simula-body (lambda (units) (unless (> units 0) (error "positive units required")))
          (lambda (_) (unless (.@ view release) (error "release required")))))
      (metadata.replace "preflight.specific" (list (dispatch.prototype 'Reserve))
        (combination.simula-body (lambda (units) (unless (<= units (.@ view capacity)) (error "capacity exceeded")))
          (lambda (_) (unless (string? (.@ view invoice)) (error "invoice required"))))))))
  (extension.snapshot (extension.check generic (list (extension.shape '((Forbidden)))))))
;; Construct a typed standard/simple reserve seed, or the original sibling seed.
;; Native registration owns the method carrier; malformed qualifiers fail before bodies run.
(def (seed mode key policy view)
  (if (eq? key 'reserve)
    (case mode
      ((standard forwarding simula) (dispatch.standard (list units-type) Any (lambda (_) '((Reserve Object)))))
      ((inner) (dispatch.inner (list units-type) Any (lambda (_) '((Reserve Object)))
        (lambda (_) (error "missing reservation descendant"))))
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
          ((forwarding simula)
           (let (protocol (if (eq? mode 'forwarding) (forwarder view) (preflight view)))
             (list (metadata.replace "reserve.protocol" exact
               (combination.primary (lambda (_ units)
                 (if (eq? mode 'forwarding)
                   (first-value (dispatch.call protocol 'reserve (list units "pending" [])))
                   (begin (dispatch.call protocol units) (list 'ok (- (.@ view capacity) units) #t)))))))))
          ((inner)
           (list
             (metadata.replace "reserve.superclass" base
               (lambda (inner units)
                 (unless (and (.@ view release) (> units 0) (<= units (.@ view capacity))) (error "superclass refused"))
                 (inner)))
             (metadata.replace "reserve.descendant" exact
               (lambda (_ units) (list 'ok (- (.@ view capacity) units) #t)))))
          ((simple)
           (list
             (metadata.replace "reserve.capacity" base (combination.item (lambda (_) (.@ view capacity))))
             (metadata.replace "reserve.debit" exact (combination.item (lambda (units) (- units))))
             (metadata.contribute "reserve.around" exact
               (combination.around (lambda (next units)
                 (unless (and (.@ view release) (<= units (.@ view capacity))) (error "reservation unavailable"))
                 (next))))))
          (else (error "unknown combination mode" mode)))))))
;; Enrichment/preflight add a real invoice dependency to reserve. Extend the CLOSE;; projection and reconstruct only that extra field; do not capture the full view
;; or silently reuse a generic whose invoice changed. Sibling projections stay exact.
(def enriched-projection
  (let* ((base (.@ shared.expanded-generics projection))
         (project (.@ base project)) (expand (.@ base expand)))
    (.cc base
      project: (lambda (key policy view)
        (let (inputs (project key policy view))
          (if (eq? key 'reserve) (cons inputs (.@ view invoice)) inputs)))
      expand: (lambda (key inputs)
        (if (eq? key 'reserve)
          (let-values (((policy cooked) (expand key (car inputs))))
            (values policy (.cc cooked invoice: (cdr inputs))))
          (expand key inputs))))))
;; Compose a selected carrier into shared expansion, stamped contracts, preparation
;; budget, warm-cache transport and exact-successor joint admission. No new publisher.
(def (model mode)
  (let (generics (.cc shared.expanded-generics seed: (cut seed mode <> <> <>) methods: (cut declarations mode <> <> <>)))
    (.cc shared.budgeted-model contract-source: shared.repeated-source generics:
      (if (memq mode '(forwarding simula)) (.cc generics projection: enriched-projection) generics))))
;; Complete standard qualified service model; primary next retains the argument row.
(def standard-model (model 'standard))
;; Complete simple-policy service model; item/accumulator/output types may differ.
(def simple-model (model 'simple))
;; Request enrichment with fixed dispatch composes with current checked publication.
(def forwarding-model (model 'forwarding))
;; Superclass controls entry into the specialized reservation implementation.
(def inner-model (model 'inner))
;; Automatic prefix/suffix preflight composes with the ordinary typed reserve service.
(def simula-model (model 'simula))
;; Prepare the selected model from existing finite access equations and policy.
;; Return version/failure using the same atomic lifecycle as the original bundle.
(def (start selected policy) (staged.prepare selected (access.equations (access.config) #t) policy))
;; Revise the same source under new policy; source/type/watch/contract approval errors
;; retain the exact old version. External effect rollback is not claimed.
(def (revise selected old policy) (staged.publish selected old (access.equations (access.config) #t) policy))
