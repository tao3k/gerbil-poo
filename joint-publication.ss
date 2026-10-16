;;; Atomic replacement of shared approval metadata and all endpoint heads.
(export publication current head approval stage stage-at stage-with approve install! submit!)
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
;; Only this module constructs a receipt AFTER complete local and joint approval.
;; The exact request retains owner, old/proposed metadata guards and expected head.
(defstruct %approved (request candidate) final: #t)
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
  (stage-at owner (current owner) policies revisions guards: guards builder: builder))
;; Bind preparation to an EXPLICIT bundle. Reject stale captures before inspecting
;; edits; preparation computed against an old head must not silently target a new one.
(def (stage-at owner expected policies revisions guards: (guards []) builder: (builder (.cc cache.Builder.)))
  (unless (eq? expected (current owner)) (error "stale joint publication during staging"))
  (bindings! policies) (bindings! revisions)
  (for-each (lambda (entry)
    (lookup (%snapshot-approvals expected) (car entry))
    (unless (object? (cdr entry)) (error "native approval replacement required"))) policies)
  (for-each (lambda (entry) (lookup (%snapshot-heads expected) (car entry))) revisions)
  (def proposed (map (lambda (entry) (or (assq (car entry) policies) entry)) (%snapshot-approvals expected)))
  (make-%request owner expected proposed revisions
    (guards-for (append (%snapshot-approvals expected) proposed) (append (%publication-guards owner) guards)) builder))
;; Compute both contribution streams from ONE current bundle, then validate that
;; same expected bundle again. Standard call-with-values preserves the two streams;
;; prepare is pure/locally total in production. No automatic retry or rebase occurs.
(def (stage-with owner prepare guards: (guards []) builder: (builder (.cc cache.Builder.)))
  (def expected (current owner))
  (call-with-values (lambda () (prepare expected))
    (lambda (policies revisions) (stage-at owner expected policies revisions guards: guards builder: builder))))
;; Close every endpoint using its exact old graph and PROPOSED approval values.
;; Then check joint consistency and return a PRIVATE receipt, without installation.
;; Failure returns #f plus the error; no denied candidate becomes a retry cache.
;; Side effects outside this protocol are not rolled back; production callbacks
;; are pure/locally total. install! independently revalidates this receipt later.
(def (approve owner request)
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
    (values (make-%approved request candidate) #f)
    (catch (failure) (values #f failure))))
;; Install only a private approved receipt belonging to this owner. The short
;; critical section rechecks EVERY registered source/policy guard and expected
;; whole snapshot; failure returns the actual current winner, never an old head.
;; Approval receipts are not refreshable: metadata drift requires fresh staging.
(def (install! owner receipt)
  (try
    (unless (and (%approved? receipt)
      (eq? owner (%request-owner (%approved-request receipt)))) (error "foreign joint approval receipt"))
    (def request (%approved-request receipt))
    (def candidate (%approved-candidate receipt))
    (with-lock (%publication-lock owner) (lambda ()
      (with-lens-checks (%request-guards request) (lambda ()
        (unless (eq? (%publication-snapshot owner) (%request-expected request))
          (error "stale joint publication at installation"))
        (%publication-snapshot-set! owner candidate)))))
    (values candidate #f)
    (catch (failure) (values (current owner) failure))))
;; Standard composition retains the original one-call failure/current contract.
;; Explicit two-phase callers can schedule approval and installation independently
;; without access to constructors for trusted receipts or candidate internals.
(def (submit! owner request)
  (call-with-values (lambda () (approve owner request))
    (lambda (receipt failure)
      (if failure (values (current owner) failure) (install! owner receipt)))))
