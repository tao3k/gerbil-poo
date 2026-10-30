(export coordinator-interleaving-test coordinator-prepared-test coordinator-retry-test)
(import :std/test :std/sync/channel :std/sync/threads
        :clan/poo/object :clan/poo/mop :clan/poo/brace
        (prefix-in :clan/poo/construction-cache cache.)
        (prefix-in :clan/poo/examples/joint-receipts receipts.)
        (prefix-in :clan/poo/joint-publication joint.)
        (prefix-in :clan/poo/examples/joint-topology service.)
        :clan/poo/examples/joint-coordination-rounds :clan/poo/examples/coordinator-rejoining
        :clan/poo/t/joint-coordination-cases)
;; Private named state belongs to the supervisor; workers communicate by channel.
(defstruct recovery (gate receipts threads failures restarts exits) final: #t)
;; Bounded handshakes expose stalled or misrouted recovery instead of sleeping.
(def (get channel)
  (def value (channel-get channel 5 'timeout))
  (when (eq? value 'timeout) (error "interleaved recovery rendezvous timed out")) value)
;; Keep actual handles across incarnations, including children awaiting installation.
(def (terminated? thread)
  (def state (thread-state thread))
  (or (thread-state-normally-terminated? state) (thread-state-abnormally-terminated? state)))
;; Two independent failed names interleave, then fail in one wave in either order.
;; Restarted d remains paused while c rejoins, fails again and rejoins alongside d.
(def (check-interleaved order)
  (def owner (service.start)) (def prepared (make-channel)) (def joined (make-channel))
  (def states (map (lambda (name) (cons name (make-recovery (make-channel) [] [] 0 0 0))) '(c d)))
  (def failures (map (lambda (name) (cons name (list name 'failed))) '(c d)))
  (def round 0) (def waiting []) (def release-ready #f) (def before-exit #f)
  ;; State lookup is only for recovering names, never for the persistent peers.
  (def (state name) (cdr (assq name states)))
  ;; Rejoin rounds differ from launch rounds: replacement operations may wait.
  (def (rejoining)
    (case round ((2 5) '(c)) ((3) '(d)) ((6) order) (else [])))
  ;; Initial and restored four-way competition alternates with partial failures.
  (def (failing)
    (case round ((1 5) '(c)) ((2) '(d)) ((4) order) (else [])))
  ;; d's second replacement is intentionally absent from the fifth round.
  (def (active) (if (= round 5) '(a b c) '(a b c d)))
  ;; A replacement explicitly refuses all historical receipts before construction.
  ;; Per-phase worker handles are sent to the supervisor before its ready checkpoint.
  (def (operation name recovered?)
    (lambda (exchange)
      (when recovered?
        (let ((receipts (get (recovery-gate (state name)))) (before (joint.current owner)))
          (for-each (lambda (receipt)
            (call-with-values (lambda () (joint.install! owner receipt))
              (lambda (snapshot failure)
                (check (not (not failure)) => #t) (check (eq? snapshot before) => #t)))) receipts))
        (channel-put joined name))
      (coordinate-revisions owner (lambda (message)
        (when (eq? (car message) 'ready)
          (channel-put prepared (cons name (thread-group->thread-list* (current-thread-group)))))
        (exchange message)))))
  ;; Resume all selected names before consuming unordered ready acknowledgements.
  (def (resume-recovered)
    (def names (rejoining))
    (for-each (lambda (name)
      (channel-put (recovery-gate (state name)) (recovery-receipts (state name)))) names)
    (let ((arrivals (map (lambda (_) (get joined)) names)))
      (for-each (lambda (name)
        (check-equal? (length (filter (lambda (seen) (eq? name seen)) arrivals)) 1)) names)))
  ;; Release one failing incarnation at a time; only after all exits are observed
  ;; may live peers publish. Winning order among live primaries remains unrestricted.
  (def (advance)
    (if (pair? waiting)
      (release-ready (lambda (name receipt)
        (def item (state name))
        (recovery-receipts-set! item (cons receipt (recovery-receipts item)))
        (cdr (assq name failures))) [(car waiting)])
      (release-ready (lambda (_ __) 'install)
        (filter (lambda (name) (not (memq name (failing)))) (active)))))
  (call-with-rejoining-coordinators
    [(cons 'a (lambda (exchange) (coordinate-revisions owner exchange)))
     (cons 'b (lambda (exchange) (coordinate-revisions owner exchange)))
     (cons 'c (operation 'c #f)) (cons 'd (operation 'd #f))]
    (lambda (next)
      (check-revisions owner next
        participants: (lambda (_ phase)
          (when (eq? phase 'next) (set! round (+ round 1)) (resume-recovered))
          (if (eq? phase 'published)
            (filter (lambda (name) (not (memq name (failing)))) (active)) (active)))
        before-release: (lambda (_ release)
          (for-each (lambda (_)
            (def entry (get prepared)) (def item (state (car entry)))
            (recovery-threads-set! item (append (cdr entry) (recovery-threads item))))
            (filter (lambda (name) (memq name '(c d))) (active)))
          (set! release-ready release) (set! waiting (failing))
          (set! before-exit (joint.current owner)) (advance))))
    (lambda (name outcome)
      (if (memq name '(c d))
        (let ((item (state name)))
          (recovery-exits-set! item (+ 1 (recovery-exits item)))
          (try (outcome) #f (catch (failure)
            (check (eq? failure (cdr (assq name failures))) => #t)
            (check-equal? (car waiting) name)
            (check (eq? before-exit (joint.current owner)) => #t)
            (check (andmap terminated? (recovery-threads item)) => #t)
            (recovery-failures-set! item (+ 1 (recovery-failures item)))
            (recovery-restarts-set! item (+ 1 (recovery-restarts item)))
            (set! waiting (cdr waiting)) (advance)
            (operation name #t))))
        (begin (outcome) #f))))
  (for-each (lambda (entry)
    (def item (cdr entry)) (def expected (if (eq? (car entry) 'c) 3 2))
    (check-equal? (recovery-failures item) expected)
    (check-equal? (recovery-restarts item) expected)
    (check-equal? (recovery-exits item) (+ expected 1))
    (check (andmap terminated? (recovery-threads item)) => #t)) states)
  (check-equal? (service.value (joint.current owner) 'a) 12))
;; Opposite joint-exit orders exercise name routing; rejoin arrivals and winners are free.
(def coordinator-interleaving-test
  (test-suite "multiple failed coordinators interleave recovery and publication"
    (test-case "c then d exit order" (check-interleaved '(c d)))
    (test-case "d then c exit order" (check-interleaved '(d c)))
    (test-case "a later recovery failure cleans another name's live replacement"
      (def failure (list 'recovery-failed)) (def replies []) (def threads [])
      (check-exception (call-with-rejoining-coordinators
        (map (lambda (name) (cons name (lambda (exchange)
          (exchange (list (current-thread))) (raise name)))) '(c d))
        (lambda (next)
          (for-each (lambda (_)
            (next (lambda (name handles reply)
              (set! threads (append handles threads))
              (set! replies (cons (cons name reply) replies))))) '(c d))
          ((cdr (assq 'c replies)) 'fail)
          (next (lambda (name handles _)
            (check-equal? name 'c) (check-equal? (length handles) 2)
            (set! threads (append handles threads))))
          ((cdr (assq 'd replies)) 'fail)
          (next (lambda _ (error "unexpected checkpoint after recovery failure"))))
        (lambda (name outcome)
          (check-exception (outcome) (lambda (caught) (eq? caught name)))
          (if (eq? name 'd) (raise failure)
            (lambda (exchange)
              (def ready (make-channel)) (def blocked (make-channel))
              (def child (make-thread (lambda () (channel-put ready 'ready) (get blocked))))
              (thread-start! child) (get ready)
              (exchange (list (current-thread) child))))))
        (lambda (caught) (eq? caught failure)))
      (check (andmap terminated? threads) => #t))
    (test-case "malformed recovery is rejected even during final joins"
      (check-exception (call-with-rejoining-coordinators
        [(cons 'c (lambda (_) 'done))] (lambda (_) 'finished)
        (lambda (_ outcome) (outcome) 42)) true))))

;; Collect one checkpoint from each live name without prescribing arrival order.
;; Replies remain one-shot capabilities belonging to their current incarnation.
(def (collect next expected)
  (def checkpoints [])
  (for-each (lambda (_)
    (next (lambda (name payload reply)
      (check-equal? (car payload) expected)
      (check (not (assq name checkpoints)) => #t)
      (set! checkpoints (cons (cons name (cons payload reply)) checkpoints))))) '(c d))
  checkpoints)
;; Resume both prepared coordinators in either order; no timing/sleep controls.
(def (resume checkpoints order)
  (for-each (lambda (name) ((cddr (assq name checkpoints)) 'resume)) order))
;; A six-round merge/delete/split/restore workflow keeps successful preparations
;; suspended while peers publish, then invalidates registered shared approvals.
;; Both names retry explicitly; fresh checks still do not reserve installation.
(def (check-prepared order)
  (def owner (service.start)) (def historical []) (def refusals 0) (def joined 0)
  (for-each (lambda (row)
    (def receipts []) (def failures []) (def installations [])
    ;; Each attempt constructs/approves once, preserving that exact opaque receipt.
    (def operation
      (rejoin-checked
        (lambda (_)
          (def source (joint.current owner))
          (car (receipts.approve-revisions owner [[]]
            (.cc (joint.approval source 'shared)) (.cc cache.Builder.))))
        (lambda (exchange receipt)
          (exchange ['prepared receipt])
          (call-with-values (lambda () (joint.check-approved owner receipt))
            (lambda (_ failure) (when failure (raise failure)))))
        (lambda (exchange receipt)
          ;; Both names must pass observation before either starts installation.
          (exchange ['checked receipt])
          (call-with-values (lambda () (joint.install! owner receipt))
            (lambda (snapshot failure) (exchange ['installed snapshot failure]))))))
    (call-with-rejoining-coordinators
      (map (lambda (name) (cons name operation)) '(c d))
      (lambda (next)
        (def prepared (collect next 'prepared))
        (set! receipts (map (lambda (entry) (cadar (cdr entry))) prepared))
        (def before (joint.current owner))
        ;; A real peer publication changes component membership and SCC grouping
        ;; after preparation succeeds, while both recovery threads are suspended.
        (def winner (car (receipts.approve-revisions owner
          [[(cons 'a (.cc service.Change. phase: (car row)))
            (cons 'b (.cc service.Change. phase: (car row)))]]
          (.cc (joint.approval before 'shared) limit: (cadr row) budget: (caddr row))
          (.cc cache.Builder.))))
        (call-with-values (lambda () (joint.install! owner winner))
          (lambda (_ failure) (check-equal? failure #f)))
        (resume prepared order)
        (set! prepared (collect next 'prepared))
        (set! receipts (append (map (lambda (entry) (cadar (cdr entry))) prepared) receipts))
        (check-equal? (length failures) 2)
        (def observed (joint.current owner))
        (def shared (joint.approval observed 'shared)) (def budget (.@ shared budget))
        ;; Same-value ABA restores observations but cannot restore guard revisions.
        (.putslot! shared 'budget ($constant-slot-spec (+ budget 1)))
        (.putslot! shared 'budget ($constant-slot-spec budget))
        (resume prepared (reverse order))
        (set! prepared (collect next 'prepared))
        (set! receipts (append (map (lambda (entry) (cadar (cdr entry))) prepared) receipts))
        (check-equal? (length failures) 4)
        (check (eq? observed (joint.current owner)) => #t)
        (resume prepared order)
        (def checked (collect next 'checked))
        (set! joined (+ joined 2))
        (resume checked (reverse order))
        (def installed (collect next 'installed))
        (set! installations (map (lambda (entry) (caddar (cdr entry))) installed))
        (check-equal? (length (filter not installations)) 1)
        (resume installed order)
        ;; Every receipt from previous generations or failed preparation must
        ;; refuse without replacing the exact current whole bundle.
        (for-each (lambda (receipt)
          (def current (joint.current owner))
          (call-with-values (lambda () (joint.install! owner receipt))
            (lambda (snapshot failure)
              (check (not (not failure)) => #t) (check (eq? snapshot current) => #t)))) historical))
      (lambda (_ outcome)
        (try (outcome) #f
          (catch (failure)
            (set! failures (cons failure failures)) (set! refusals (+ refusals 1)) operation))))
    (set! historical (append receipts historical)))
    '((merge 24 48) (replace 16 32) (restore 12 24)
      (merge 24 48) (replace 16 32) (restore 12 24)))
  (check-equal? refusals 24) (check-equal? joined 12)
  (check-equal? (service.value (joint.current owner) 'a) 12))
;; Reverse releases to cover either recovering name becoming the first contender.
(def coordinator-prepared-test
  (test-suite "successful preparation is rechecked before rejoining"
    (test-case "c/d publication, shared-guard drift and retries" (check-prepared '(c d)))
    (test-case "d/c publication, shared-guard drift and retries" (check-prepared '(d c)))))

;; State is supervisor-owned; preparation and service workers send observations.
(defstruct retry-state (reply receipts threads active-failures prepare-failures exits completed) final: #t)
;; Bounded handshakes detect missing recovery progress without timed release.
(def (retry-get channel)
  (def value (channel-get channel 5 'timeout))
  (when (eq? value 'timeout) (error "coordinator retry rendezvous timed out")) value)
;; Persistent a/b publish across seven failures, four occurring DURING preparation.
;; c/d restoration failures are driven in both orders without choosing a winner.
(def (check-retries order)
  (def owner (service.start)) (def prepared (make-channel)) (def completed (make-channel))
  (def buffered (make-channel)) (def states (make-hash-table-eq))
  (for-each (lambda (name) (hash-put! states name (make-retry-state #f [] [] 0 0 0 0))) '(c d))
  (def round 0) (def waiting []) (def release-ready #f) (def before-exit #f)
  (def active-errors (map (lambda (name) (cons name (list name 'active-failure))) '(c d)))
  (def prepare-errors (map (lambda (name) (cons name (list name 'prepare-failure))) '(c d)))
  ;; Recovering names have separate replies, histories and error identities.
  (def (state name) (hash-ref states name))
  ;; Deferred restoration leaves active service scopes unchanged.
  (def (active)
    (case round ((2) '(a b)) ((3) '(a b d)) ((5) '(a b c)) (else '(a b c d))))
  ;; These failures occur only after fresh service approvals, before installation.
  (def (failing) (case round ((1) order) ((4) '(d)) (else [])))
  ;; Route recovery checkpoints without losing ordinary service checkpoints.
  (def (remember name message reply)
    (if (eq? (car message) 'recovering)
      (let ((item (state name)))
        (check (not (retry-state-reply item)) => #t)
        (retry-state-reply-set! item reply)
        (retry-state-threads-set! item (append (cadr message) (retry-state-threads item))) #t)
      #f))
  ;; A replacement prepares in its own group before entering the shared workflow.
  ;; A nested resource group is cleaned on BOTH preparation success and failure.
  (def (operation name recovering?)
    (if recovering?
      (rejoin-after
        (lambda (exchange)
          (def resources (make-thread-group 'recovery-resources (current-thread-group)))
          (def ready (make-channel)) (def blocked (make-channel))
          (def child (make-thread (lambda () (channel-put ready 'ready) (retry-get blocked)) 'resource resources))
          (try
            (thread-start! child) (retry-get ready)
            (let ((command (exchange (list 'recovering (thread-group->thread-list* (current-thread-group))))))
              (unless (eq? command 'resume) (raise command)))
            ;; Snapshot capture and historical checks happen AFTER explicit resume.
            (let ((before (joint.current owner)) (receipts (retry-state-receipts (state name))))
              (for-each (lambda (receipt)
                (call-with-values (lambda () (joint.install! owner receipt))
                  (lambda (snapshot failure)
                    (check (not (not failure)) => #t) (check (eq? before snapshot) => #t)))) receipts)
              (values before (length receipts) child))
            (finally (thread-group-kill! resources))))
        (lambda (exchange before count resource)
          (check (terminated? resource) => #t)
          (check (eq? before (joint.current owner)) => #t)
          (channel-put completed (list name count))
          ((operation name #f) exchange)))
      (lambda (exchange)
        (coordinate-revisions owner (lambda (message)
          (when (eq? (car message) 'ready)
            (channel-put prepared (cons name (thread-group->thread-list* (current-thread-group)))))
          (exchange message))))))
  ;; Only current ready incarnations are released; other peers retain their scope.
  (def (advance)
    (if (pair? waiting)
      (release-ready (lambda (name receipt)
        (def item (state name))
        (retry-state-receipts-set! item (cons receipt (retry-state-receipts item)))
        (cdr (assq name active-errors))) [(car waiting)])
      (release-ready (lambda (_ __) 'install)
        (filter (lambda (name) (not (memq name (failing)))) (active)))))
  (call-with-rejoining-coordinators
    [(cons 'a (lambda (exchange) (coordinate-revisions owner exchange)))
     (cons 'b (lambda (exchange) (coordinate-revisions owner exchange)))
     (cons 'c (operation 'c #f)) (cons 'd (operation 'd #f))]
    (lambda (next)
      ;; A FIFO standard channel preserves live checkpoints intercepted during retry.
      (def (live handler)
        (def pending (channel-try-get buffered))
        (if pending (pending handler)
          (next (lambda (name message reply)
            (if (remember name message reply) (live handler) (handler name message reply))))))
      ;; Drive supervision until every requested name has its new preparation reply.
      ;; Ordinary checkpoints are buffered, not acknowledged or discarded.
      (def (await names)
        (let loop ()
          (unless (andmap (lambda (name) (retry-state-reply (state name))) names)
            (next (lambda (name message reply)
              (unless (remember name message reply)
                (channel-put buffered (lambda (handler) (handler name message reply))))))
            (loop))))
      ;; Repeated preparation failure never enters the service continuation.
      (def (fail-prepare name)
        (await [name])
        (set! before-exit (joint.current owner))
        (let ((reply (retry-state-reply (state name))))
          (retry-state-reply-set! (state name) #f) (reply (cdr (assq name prepare-errors))))
        (await [name]))
      ;; Resume a fresh instance, retaining its complete prepared-value tuple.
      (def (resume name)
        (await [name])
        (let ((reply (retry-state-reply (state name))))
          (retry-state-reply-set! (state name) #f) (reply 'resume))
        (let ((result (retry-get completed)))
          (check-equal? (car result) name)
          (check-equal? (cadr result) (length (retry-state-receipts (state name)))))
        (retry-state-completed-set! (state name) (+ 1 (retry-state-completed (state name)))))
      (check-revisions owner live
        participants: (lambda (_ phase)
          (when (eq? phase 'next)
            (set! round (+ round 1))
            (case round
              ((2) (for-each fail-prepare order))
              ((3) (fail-prepare 'c) (resume 'd))
              ((4) (resume 'c))
              ((5) (fail-prepare 'd))
              ((6) (resume 'd))))
          (if (eq? phase 'published)
            (filter (lambda (name) (not (memq name (failing)))) (active)) (active)))
        before-release: (lambda (_ release)
          (for-each (lambda (_)
            (def entry (retry-get prepared)) (def item (state (car entry)))
            (retry-state-threads-set! item (append (cdr entry) (retry-state-threads item))))
            (filter (lambda (name) (memq name '(c d))) (active)))
          (set! before-exit (joint.current owner)) (set! waiting (failing))
          (set! release-ready release) (advance)))
      (check (not (channel-try-get buffered)) => #t))
    (lambda (name outcome)
      (if (memq name '(c d))
        (let ((item (state name)))
          (retry-state-exits-set! item (+ 1 (retry-state-exits item)))
          (try (outcome) #f (catch (failure)
            (check (eq? before-exit (joint.current owner)) => #t)
            (check (andmap terminated? (retry-state-threads item)) => #t)
            (cond
              ((eq? failure (cdr (assq name prepare-errors)))
                (retry-state-prepare-failures-set! item (+ 1 (retry-state-prepare-failures item))))
              ((eq? failure (cdr (assq name active-errors)))
                (check-equal? (car waiting) name)
                (retry-state-active-failures-set! item (+ 1 (retry-state-active-failures item)))
                (set! waiting (cdr waiting)) (advance))
              (else (raise failure)))
            (operation name #t))))
        (begin (outcome) #f))))
  (for-each (lambda (name)
    (def item (state name))
    (check-equal? (retry-state-prepare-failures item) 2)
    (check-equal? (retry-state-active-failures item) (if (eq? name 'c) 1 2))
    (check-equal? (retry-state-exits item) (if (eq? name 'c) 4 5))
    (check-equal? (retry-state-completed item) (if (eq? name 'c) 1 2))
    (check (andmap terminated? (retry-state-threads item)) => #t)) '(c d))
  (check-equal? (service.value (joint.current owner) 'a) 12))
;; Opposite preparation retry orders preserve free service publication winners.
(def coordinator-retry-test
  (test-suite "coordinators fail again during restoration while peers publish"
    (test-case "c then d preparation retries" (check-retries '(c d)))
    (test-case "d then c preparation retries" (check-retries '(d c)))
    (test-case "unknown preparation error cleans peers and never enters continuation"
      (def ready (make-channel)) (def go (make-channel))
      (def failure (list 'unknown-preparation-error)) (def threads []) (def continued? #f)
      (check-exception (call-with-rejoining-coordinators
        [(cons 'a (lambda (_)
           (channel-put ready (current-thread)) (retry-get (make-channel))))
         (cons 'c (rejoin-after
           (lambda (_) (channel-put ready (current-thread)) (retry-get go) (raise failure))
           (lambda _ (set! continued? #t))))]
        (lambda (next)
          (set! threads [(retry-get ready) (retry-get ready)]) (channel-put go 'fail)
          (next (lambda _ (error "unexpected recovery checkpoint"))))
        (lambda (_ outcome) (outcome) #f))
        (lambda (caught) (eq? caught failure)))
      (check (not continued?) => #t)
      (check (andmap terminated? threads) => #t))))
