;;; Atomic replacement of shared approval metadata and all endpoint heads.
(export publication current head approval stage submit!)
(import (only-in :gerbil/runtime/thread with-lock) (only-in :std/list/list delete-duplicates/hash)
        ./object ./mop ./lens-laws ./feedback-graph
        (prefix-in ./component-revision revision.) (prefix-in ./construction-cache cache.))
;; A private immutable bundle is the ONLY authoritative read/installation unit.
(defstruct %snapshot (heads approvals) final: #t)
;; Callbacks are fixed for the owner's lifetime; all prepare/approve work stays
;; outside the short lock. Mutable metadata must appear in explicit guards.
(defstruct %publication (snapshot lock build admit joint guards) final: #t)
;; A request captures one old bundle, policy replacements and endpoint fragments.
(defstruct %request (owner expected approvals revisions guards builder) final: #t)
;; Validate ordered keyed contributions before any constructor or publication.
(def (bindings! entries)
  (unless (and (list? entries) (andmap (lambda (entry) (and (pair? entry) (symbol? (car entry)))) entries)
      (= (length entries) (length (delete-duplicates/hash (map car entries)))))
    (error "distinct named joint publication bindings required")) entries)
;; Resolve only declared bindings; an unknown policy/endpoint never defaults.
(def (lookup entries key)
  (def entry (assq key entries))
  (unless entry (error "unknown joint publication binding" key)) (cdr entry))
;; Read one immutable bundle so several projections cannot mix publication rounds.
(def (current owner)
  (with-lock (%publication-lock owner) (lambda () (%publication-snapshot owner))))
;; Inspect a selected graph in an already captured consistent bundle.
(def (head snapshot key) (lookup (%snapshot-heads snapshot) key))
;; Approval values are native POO objects, immutable for the bundle's lifetime.
(def (approval snapshot key) (lookup (%snapshot-approvals snapshot) key))
;; Capture all registered old/proposed native approval revisions and explicit
;; extra metadata guards. Hidden callback dependencies remain caller premises.
(def (guards-for approvals guards)
  (append guards (map (lambda (entry)
    (lens-check (.lens) [(cdr entry)] sources: [(cdr entry)])) approvals)))
;; Initial bundle requires successful per-endpoint AND cross-endpoint approval.
;; build selects an existing whole-group builder; admit observes the proposed
;; bundle's policy lookup, key, old graph and complete candidate graph.
(def (publication heads approvals build admit joint guards: (guards []))
  (bindings! heads) (bindings! approvals)
  (unless (and (pair? heads) (andmap (lambda (entry) (graph-cache? (cdr entry))) heads)
      (andmap (lambda (entry) (object? (cdr entry))) approvals)) (error "joint graphs and approval objects required"))
  (def snapshot (make-%snapshot heads approvals))
  (with-lens-checks (guards-for approvals guards) (lambda ()
    (unless (and (andmap (lambda (entry) (eq? (admit (cut approval snapshot <>) (car entry) #f (cdr entry)) #t)) heads)
                 (eq? (joint #f snapshot) #t)) (error "initial joint publication refused"))))
  (make-%publication snapshot (make-mutex 'joint-publication) build admit joint guards))
;; Stage immutable REPLACEMENTS, never mutate installed policy objects in place.
;; All endpoints participate: omitted revisions are empty edits, reusing clean
;; construction receipts but still obtaining current approval under proposed policy.
(def (stage owner policies revisions guards: (guards []) builder: (builder (.cc cache.Builder.)))
  (bindings! policies) (bindings! revisions)
  (def expected (current owner))
  (for-each (lambda (entry)
    (lookup (%snapshot-approvals expected) (car entry))
    (unless (object? (cdr entry)) (error "native approval replacement required"))) policies)
  (for-each (lambda (entry) (lookup (%snapshot-heads expected) (car entry))) revisions)
  (def proposed (map (lambda (entry) (or (assq (car entry) policies) entry)) (%snapshot-approvals expected)))
  (make-%request owner expected proposed revisions
    (guards-for (append (%snapshot-approvals expected) proposed) (append (%publication-guards owner) guards)) builder))
;; Close every endpoint using its exact old graph and PROPOSED approval values.
;; Then check joint consistency, recheck sources/head under lock, and replace ONE
;; bundle pointer. Failure returns actual current bundle; no installed object was
;; mutated and no denied candidate becomes a retry cache. Side effects outside
;; this protocol are not rolled back; production callbacks are pure/locally total.
(def (submit! owner request)
  (try
    (unless (and (%request? request) (eq? owner (%request-owner request))) (error "foreign joint request"))
    (def expected (%request-expected request))
    (unless (eq? (current owner) expected) (error "stale joint publication snapshot"))
    (def candidate
      (with-lens-checks (%request-guards request) (lambda ()
        (def policies (%request-approvals request))
        (def heads (map (lambda (entry)
          (def key (car entry))
          (def edits (assq key (%request-revisions request)))
          (cons key ((revision.revision-action (cdr entry) (if edits (cdr edits) [])
            ((%publication-build owner) key)
            (lambda (old next) ((%publication-admit owner) (cut lookup policies <>) key old next))
            guards: (%request-guards request) builder: (%request-builder request)) (cdr entry))))
          (%snapshot-heads expected)))
        (def next (make-%snapshot heads policies))
        (unless (eq? ((%publication-joint owner) expected next) #t) (error "joint endpoint consistency refused"))
        next)))
    (with-lock (%publication-lock owner) (lambda ()
      (with-lens-checks (%request-guards request) (lambda ()
        (unless (eq? (%publication-snapshot owner) expected) (error "stale joint publication at installation"))
        (%publication-snapshot-set! owner candidate)))))
    (values candidate #f)
    (catch (failure) (values (current owner) failure))))
