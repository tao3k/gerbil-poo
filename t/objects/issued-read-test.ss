;;; Replay runtime-issued Slot reads and reject fabricated or stale records.
(export issued-read-test test-cleanup!)
(import (only-in :clan/poo/slot-layout make-slot-cache) :std/iter :std/test (only-in :clan/poo/io module-action) :clan/poo/object :clan/poo/slot-observation
        (only-in :clan/poo/read-route make-read-issuer %issued-read?)
        (only-in :gerbil/runtime/gambit unbound-global-exception?)
        (prefix-in (only-in :gerbil/runtime/mop slot-ref slot-set! find-method bind-method! object-class
                            class-slot-offset &class-type-slot-table) runtime.)
        (only-in :gerbil/runtime/table symbolic-table-set!)
        (only-in :gerbil/runtime/hash HashTable::interface)
        (only-in :gerbil/expander current-expander-context make-top-context
                 core-import-module module-context-export module-export-name eval-syntax)
        (only-in :std/error Error? Error-message contract-violation-error?))
(def completed 0)
(def (test-cleanup!)
  (check-equal? completed 35)
  (displayln "ISSUED-READ: 35 cases completed"))
;; White-box ownership check only. This private entry is NOT a public export;
;; Ordinary consumers use the public replay and protected checkpoint entries.
(extern namespace: clan/poo/object call-with-issued-reads object-read-key
        object-read-dependencies object-read-value require-current-read-sweep!)
(def (captured-order roots)
  (call-with-issued-reads roots (lambda (reads _current! _receivers) reads) #t))
(def (recorded action)
  (def reads '())
  (call-with-slot-read-observer (lambda (r) (set! reads (cons r reads))) action)
  (reverse reads))
(def (refuses message action)
  (def failure (with-catch values action))
  (unless (Error? failure) (error "expected native refusal" message failure))
  (check-equal? (Error? failure) #t)
  (check-equal? (Error-message failure) message))
(def (selected roots key)
  (car (filter (lambda (r) (equal? (slot-read-key r) key)) roots)))
(def (copy-read read)
  (make-slot-read (slot-read-receiver read) (slot-read-key read)
    (slot-read-revision read) (slot-read-instance read) (slot-read-value read)
    (slot-read-dependencies read) object-read-current?))
(def (miss-witness receiver)
  (def watcher (make-hash-table test: eq? weak-keys: #t))
  (for-each (lambda (read) (hash-put! watcher read #t))
    (recorded (cut .ref/cached receiver 'missing (lambda () #f))))
  watcher)
(def (with-declared-field-fixture action)
  (.def Source port: 5432)
  (.def Alternative empty: '())
  (def source-read (selected (recorded (lambda () (.get Source port))) 'port))
  (def alternative-read (selected (recorded (lambda () (.get Alternative empty))) 'empty))
  (.def Target payload: (begin (.get Source port) (list alternative-read)))
  (def target-read (selected (recorded (lambda () (.get Target payload))) 'payload))
  (check-equal? (and (memq source-read (slot-read-dependencies target-read)) #t) #t)
  (action target-read source-read))
(def (with-moved-declared-field read field replacement-field action)
  (def class (runtime.object-class read))
  (def offsets (runtime.&class-type-slot-table class))
  (def original (runtime.class-slot-offset class field))
  (def replacement (runtime.class-slot-offset class replacement-field))
  (dynamic-wind
    (lambda () (symbolic-table-set! offsets field replacement))
    action
    (lambda () (symbolic-table-set! offsets field original))))
(def issued-read-test
 (test-suite "Read issuance with transient tokens and guarded replay"
  (test-case "pinned key access preserves live symbolic and structural fields"
    (.def Owner value: #f)
    (def reads (recorded (lambda () (.get Owner value) (.all-slots Owner)
                             (.ref/cached Owner 'missing (lambda () #f)))))
    (for (read reads)
      (check-equal? (object-read-issued? read) #t)
      (check-eq? (object-read-key read) (runtime.slot-ref read 'key))
      (check-eq? (object-read-dependencies read) (runtime.slot-ref read 'dependencies))
      (check-eq? (object-read-value read) (runtime.slot-ref read 'value)))
    (def read (selected reads 'value))
    ;; Every access sees the live field. No captured key may survive a
    ;; mutated record, even if a previous currentness check accepted it.
    (check-equal? (object-read-current? read) #t)
    (try
      (runtime.slot-set! read 'key '(names))
      (check-equal? (object-read-key read) '(names))
      (check-equal? (object-read-current? read) #f)
      (finally (runtime.slot-set! read 'key 'value)))
    (check-equal? (object-read-current? read) #t)
    (set! completed (1+ completed)))
  (test-case "vector value and index routes refuse replaced refs before dispatch"
    (for (index? '(#f #t))
      (def owner (.o value: #f))
      (def roots (recorded (cut .ref owner 'value)))
      (def instance (object-instance owner))
      (def table (if index?
        (runtime.slot-ref (runtime.slot-ref (runtime.slot-ref instance 'object) 'shape) 'indices)
        instance))
      (def original (runtime.slot-ref table 'ref))
      (def calls 0)
      (try
        (runtime.slot-set! table 'ref
          (lambda (_self _key _default) (set! calls (1+ calls)) #f))
        (refuses "changed metadata ref" (cut reobserve-slot-reads! roots))
        (check-equal? calls 0)
        (finally (runtime.slot-set! table 'ref original))))
    (def owner (.o value: 1))
    (def roots (recorded (cut .ref owner 'value)))
    (def instance (object-instance owner))
    (def backend (runtime.slot-ref instance 'object))
    (def shape (runtime.slot-ref backend 'shape))
    (def foreign-shape (make-hash-table-symbolic))
    (def method (runtime.slot-ref instance 'ref))
    (try
      (runtime.slot-set! backend 'shape foreign-shape)
      (try
        (runtime.slot-set! instance 'ref void)
        (refuses "changed metadata ref" (cut call-with-current-slot-reads roots values))
        (finally (runtime.slot-set! instance 'ref method)))
      (refuses "foreign vector shape" (cut call-with-current-slot-reads roots values))
      (finally (runtime.slot-set! backend 'shape shape)))
    (check (object-read-current? (selected roots 'value)) => #t)
    ;; A compatible table instance is insufficient if hash-ref would cast it
    ;; through a different live interface descriptor.
    (def read (selected roots 'value))
    (def descriptor-class (runtime.slot-ref HashTable::interface 'type))
    (def failure
      (dynamic-wind
        (lambda () (runtime.slot-set! HashTable::interface 'type (runtime.object-class read)))
        (lambda () (with-catch values (cut object-read-current? read)))
        (lambda () (runtime.slot-set! HashTable::interface 'type descriptor-class))))
    (check-equal? (and (Error? failure) (Error-message failure))
                  "changed HashTable interface")
    (check-equal? (object-read-current? read) #t)
    (set! completed (1+ completed)))
  (test-case "vector storage exposure and shape growth preserve genuine read authority"
    (def parent (.o value: #f))
    (def owner (.o inherit: [parent]))
    (def site (make-slot-cache 'value shapes: 2))
    (def record #f)
    (call-with-slot-read-observer
      (lambda (read) (when (eq? (slot-read-key read) 'value) (set! record read)))
      (cut .ref owner 'value))
    (def instance (object-instance owner))
    (def layout (object-layout owner))
    (check (object-read-current? record) => #t)
    (check-eq? (slot-read-instance record) instance)
    (check (.ref/inline owner site) => #f)
    (hash-put! instance 'new-key identity)
    (check (object-read-current? record) => #t)
    (check (.ref/inline owner site) => #f)
    (hash-put! instance 'value identity)
    (check (object-read-current? record) => #f)
    (check-eq? (.ref/inline owner site) identity)
    (.put! parent 'value 7)
    (check (object-%instance owner) => #f)
    (check (object-%layout owner) => #f)
    ;; Instance assignments do not replace inherited slot specifications.
    (check (.ref/inline owner site) => #f)
    (check (eq? layout (object-%layout owner)) => #f)
    (.putslot! parent 'value ($constant-slot-spec 7))
    (check-equal? (.ref/inline owner site) 7)
    (set! completed (1+ completed)))
  (test-case "cold cyclic root spines refuse before replay"
    (.def Root port: 5432)
    (def read (selected (recorded (cut .get Root port)) 'port))
    (def roots (list read))
    (set-cdr! roots roots)
    (check-exception (replay-slot-reads! roots (lambda (_r _k) (error "must not deliver")))
      contract-violation-error?)
    (set! completed (+ completed 1)))
  (test-case "cold root grammar precedes authentication without consuming source state"
    (.def Root port: 5432)
    (def read (selected (recorded (cut .get Root port)) 'port))
    (def forged (copy-read read))
    (def revision (object-revision Root))
    (def instance (object-%instance Root))
    (def delivered 0)
    (for-each (lambda (bad)
      (check-exception (replay-slot-reads! bad (lambda (_r _k) (set! delivered (+ delivered 1))))
        contract-violation-error?))
      (list #f 7 "roots" (vector read) (cons read 'tail) (cons forged 'tail)))
    (check-equal? delivered 0)
    (check-equal? (object-revision Root) revision)
    (check-equal? (eq? (object-%instance Root) instance) #t)
    (check-equal? (object-read-current? read) #t)
    (refuses "unissued slot dependency" (cut replay-slot-reads! (list forged) (lambda (_r _k) (void))))
    (replay-slot-reads! [] (lambda (_r _k) (error "empty roots delivered")))
    (set! completed (+ completed 1)))
  (test-case "damaged warm root spines refuse and repaired requests retain current checks"
    (.def Root port: 5432)
    (def read (selected (recorded (cut .get Root port)) 'port))
    (def roots (list read))
    (def before (captured-order roots))
    (set-cdr! roots roots)
    (check-exception (captured-order roots) contract-violation-error?)
    (set-cdr! roots 'tail)
    (check-exception (captured-order roots) contract-violation-error?)
    (set-cdr! roots [])
    (check-equal? (captured-order roots) before)
    (check-equal? (object-read-current? read) #t)
    (.putslot! Root 'port ($constant-slot-spec 5433))
    (refuses "stale slot dependency" (cut captured-order roots))
    (def fresh (recorded (cut .get Root port)))
    (replay-slot-reads! fresh (lambda (_r _k) (void)))
    (check-equal? ((module-action "clan/poo/examples/representation-service"
                    'clan/poo/examples/representation-service#replay-workflow) []) '#(9 12 9 3))
    (set! completed (+ completed 1)))
  (test-case "the Gerbil export interface does not expose private read-issuance helpers"
    (def forged-public-read?
      (parameterize ((current-expander-context (make-top-context)))
        (eval-syntax '(import :gerbil/core :clan/poo/object))
        (def issue
          (with-catch
            (lambda (cause) (if (unbound-global-exception? cause) #f (raise cause)))
            (lambda () (eval-syntax '%issue-read))))
        (and issue
             (let* ((owner (.o answer: 9))
                    (value (.get owner answer))
                    (read (issue owner 'answer (object-revision owner)
                                 (object-%instance owner) value [] object-read-current?)))
               (hash-put! (object-read-table owner) 'answer read)
               (object-read-current? read)))))
    (check-equal? forged-public-read? #f)
    (def names
      (parameterize ((current-expander-context (make-top-context)))
        (map module-export-name
          (module-context-export (core-import-module ':clan/poo/object)))))
    (for-each (lambda (name) (check-equal? (memq name names) #f))
      '(object-record-read object-read-query object-read-bootstrap
        object-deliver-value object-issued-read-current? require-object-read-route!
        call-with-issued-reads active-read-replays object-read-key
        object-read-dependencies object-read-value record-key-field
        record-dependencies-field record-value-field
        require-current-read-sweep! %pure-read-sweep?))
    (check-equal? (and (memq 'object-read-issued? names) #t) #t)
    (check-equal? (and (memq '%issue-read names) #t) #f)
    (def route-names
      (parameterize ((current-expander-context (make-top-context)))
        (map module-export-name
          (module-context-export (core-import-module ':clan/poo/read-route)))))
    (check-equal? (memq '%issue-read route-names) #f)
    (for-each (lambda (name) (check-equal? (memq name route-names) #f))
      '(record-key-field record-value-field record-current-field
        record-dependencies-field record-birth-field record-birth-set! %pure-read-sweep?))
    (check-equal? (and (memq '%issued-read? route-names) #t) #t)
    ;; A descriptor that cannot use identity conversion takes the original
    ;; checker. Keep all framework/Test operations outside the temporary edit.
    (let* ((owner (.o answer: 9))
           (roots (recorded (cut .get owner answer)))
           (read (selected roots 'answer))
           (saved-type (runtime.slot-ref HashTable::interface 'type))
           (delivered []))
      (dynamic-wind
        (lambda () (runtime.slot-set! HashTable::interface 'type (runtime.object-class read)))
        (lambda ()
          ;; No receiver map is supplied: fallback must not inspect it.
          (require-current-read-sweep! (list read) #f '#(0)
            (lambda (record) (set! delivered (cons record delivered))) #t))
        (lambda () (runtime.slot-set! HashTable::interface 'type saved-type)))
      (check-equal? delivered (list read))
      ;; An index built on the unsupported path remains ordinary even if the
      ;; descriptor is restored by the time the next check occurs.
      (set! delivered [])
      (require-current-read-sweep! (list read) #f #f
        (lambda (record) (set! delivered (cons record delivered))) #t)
      (check-equal? delivered (list read)))
    (set! completed (+ completed 1)))
  (test-case "real persistent records authenticate but public copies do not"
    (.def Root port: 5432 unused: (error "unselected branch forced"))
    (def roots (recorded (cut .get Root port)))
    (def genuine (selected roots 'port))
    (def forged (copy-read genuine))
    (check-equal? (object-read-issued? genuine) #t)
    (check-equal? (object-read-issued? forged) #f)
    ;; The public dependency list must not alias the issuer's private snapshot.
    (def original-dependencies (runtime.slot-ref genuine 'dependencies))
    (def dependencies (slot-read-dependencies genuine))
    ;; The ordinary constant slot has one preparation parent. The issuer may
    ;; retain that identity directly, but inspection must still return a fresh
    ;; list and every public mutation must be authenticated anew.
    (check-equal? (length dependencies) 1)
    (defvalues (_p0 _o0 _r0 single-copy _s0) (object-read-issuance genuine))
    (check-equal? (eq? (vector-ref single-copy 5) dependencies) #f)
    (check-equal? (eq? (car (vector-ref single-copy 5)) (car dependencies)) #t)
    (runtime.slot-set! genuine 'dependencies (append dependencies dependencies))
    (check-equal? (object-read-issued? genuine) #f)
    (runtime.slot-set! genuine 'dependencies '())
    (check-equal? (object-read-issued? genuine) #f)
    (runtime.slot-set! genuine 'dependencies original-dependencies)
    (check-equal? (object-read-issued? genuine) #t)
    (when (pair? dependencies)
      (let (first (car dependencies))
        (set-car! dependencies forged)
        (check-equal? (object-read-issued? genuine) #t)
        (set-car! dependencies first)
        (check-equal? (object-read-issued? genuine) #t)))
    (check-equal? (object-read-current? forged) #f)
    ;; Inspection and authentication share one private captured payload. Its
    ;; published copies must neither mutate authority nor authorize a raw copy.
    (defvalues (presented original signed snapshot shape) (object-read-issuance genuine))
    (check-equal? (eq? presented original) #t)
    (check-equal? (eq? signed genuine) #t)
    (vector-set! snapshot 4 'edited-copy)
    (when (pair? (vector-ref snapshot 5))
      (set-car! (vector-ref snapshot 5) forged))
    (when (pair? shape) (set-car! shape 'edited-key))
    (check-equal? (object-read-issued? genuine) #t)
    (check-equal? (object-read-issued? forged) #f)
    (defvalues (_presented _original _signed fresh _shape) (object-read-issuance genuine))
    (check-equal? (vector-ref fresh 4) 5432)
    (.def Composite port:
      (begin (%deliver-slot-read genuine #t) (%deliver-slot-read genuine #t) 5432))
    (def composite
      (selected (filter (lambda (read) (eq? (slot-read-receiver read) Composite))
                  (recorded (cut .get Composite port))) 'port))
    (def repeated (slot-read-dependencies composite))
    (check-equal? (length (filter (cut eq? genuine <>) repeated)) 2)
    (runtime.slot-set! composite 'dependencies (reverse repeated))
    (check-equal? (object-read-issued? composite) #f)
    (runtime.slot-set! composite 'dependencies (cdr repeated))
    (check-equal? (object-read-issued? composite) #f)
    (runtime.slot-set! composite 'dependencies repeated)
    (check-equal? (object-read-issued? composite) #t)
    (refuses "unissued slot dependency"
      (cut replay-slot-reads! (list forged) (lambda (_r _k) (error "must not observe"))))
    (replay-slot-reads! roots (lambda (_r _k) (void)))
    (set! completed (+ completed 1)))
  (test-case "published structural keys do not own the read index or replay route"
    (.def Root port: #f)
    (def roots (recorded (cut .slot? Root 'port)))
    (def genuine (selected roots '(presence port)))
    ;; Warm indexed presence keeps the same record and delivers both occurrences.
    (def warm (recorded (lambda () (.slot? Root 'port) (.slot? Root 'port))))
    (check-equal? (length warm) 2)
    (for (read warm) (check-eq? read genuine))
    (def nested (recorded (lambda () (call-with-slot-read-observer void (cut .slot? Root 'port)))))
    (check-equal? (length nested) 1)
    (check-eq? (car nested) genuine)
    (def edited (slot-read-key genuine))
    (set-car! (cdr edited) 'missing)
    (check-equal? edited '(presence missing))
    (check-equal? (slot-read-key genuine) '(presence port))
    (check (object-read-current? genuine) => #t)
    (check-eq? (hash-get (object-%reads Root) '(presence port)) genuine)
    (check (.slot? Root 'missing) => #f)
    (replay-slot-reads! roots
      (lambda (_ key)
        (when (equal? key '(presence port)) (set-cdr! key key))))
    (check (object-read-current? genuine) => #t)
    (let-values (((_presented _original _signed fields shape) (object-read-issuance genuine)))
      (set-car! (vector-ref fields 1) 'edited-inspection)
      (check-equal? shape '(presence port))
      (set-car! shape 'edited-shape))
    (check (object-read-current? genuine) => #t)
    ;; Runtime reflection bypasses the public accessor but owns no hash key.
    (set-car! (cdr (runtime.slot-ref genuine 'key)) 'missing)
    (check (object-read-issued? genuine) => #f)
    (check-eq? (hash-get (object-%reads Root) '(presence port)) genuine)
    (refuses "unissued slot dependency" (cut replay-slot-reads! roots void))
    (def fresh (recorded (cut .slot? Root 'port)))
    (check (object-read-current? (selected fresh '(presence port))) => #t)
    (.put! Root 'port 5432)
    (refuses "stale slot dependency" (cut replay-slot-reads! fresh void))
    (check (.slot? Root 'port) => #t)
    (def checks 0)
    (def observed
      (call-with-slot-read-observer void (cut .slot? Root 'port)
        before: (lambda (receiver key)
                  (when (and (eq? receiver Root) (equal? key '(presence port)))
                    (set! checks (+ checks 1))
                    (.removeslot! Root 'port)))))
    (check-equal? checks 1)
    (check-equal? observed #f)
    (check-equal? ((module-action "clan/poo/examples/inherited-services"
                   'clan/poo/examples/inherited-services#read-key-workflow) []) '(10 20 #t))
    (set! completed (+ completed 1)))
  (test-case "published names and dependency lists are independent of signed replay"
    (.def Root names: (list 'user) enabled: #f)
    (def roots (recorded (cut .all-slots Root)))
    (def read (selected roots '(names)))
    (def names (slot-read-value read))
    (def parents (slot-read-dependencies read))
    (defvalues (_p _o _r fields _shape) (object-read-issuance read))
    (set-car! names 'edited)
    (set-car! (vector-ref fields 4) 'inspected)
    (set-car! parents read)
    (check-equal? (slot-read-value read) (.all-slots Root))
    (check (object-read-current? read) => #t)
    (check-eq? (slot-read-value (selected (recorded (cut .ref Root 'names)) 'names))
               (.ref Root 'names))
    (reobserve-slot-reads! roots)
    (replay-slot-reads! roots void)
    (def delivered 0)
    (def original (runtime.slot-ref read 'dependencies))
    (dynamic-wind void
      (lambda ()
        (refuses "unissued slot dependency"
          (lambda ()
            (call-with-slot-read-observer (lambda (_) (set! delivered (1+ delivered)))
              (cut reobserve-slot-reads! (list read)
                (lambda () (runtime.slot-set! read 'dependencies (list read)))))))
        (check-equal? delivered 0))
      (lambda () (runtime.slot-set! read 'dependencies original)))
    ;; A receiver's name cache is producer-owned metadata. Editing both that
    ;; cache and the exposed raw record must not rewrite its original birth.
    (def producer (runtime.slot-ref Root '%all-slots))
    (def presentation (runtime.slot-ref read 'value))
    (def producer-first (car producer))
    (def presentation-first (car presentation))
    (dynamic-wind void
      (lambda ()
        (set-car! producer 'forged-source-name)
        (set-car! presentation 'forged-source-name)
        (check-equal? (object-read-issued? read) #f))
      (lambda ()
        (set-car! producer producer-first)
        (set-car! presentation presentation-first)))
    (check-equal? (object-read-issued? read) #t)
    (.putslot! Root 'extra ($constant-slot-spec 7))
    (refuses "stale slot dependency" (cut replay-slot-reads! roots void))
    (set! completed (+ completed 1)))
  (test-case "transient miss is issued without being put in the receiver cache"
    (.def Root port: 5432)
    (def roots (recorded (cut .ref/cached Root 'missing (lambda () #f))))
    (def key '(cache-miss missing))
    (def genuine (selected roots key))
    (check-equal? (hash-key? (object-%instance Root) 'missing) #f)
    (check-equal? (hash-get (object-%reads Root) key) #f)
    (check-equal? (object-read-issued? genuine) #t)
    (check-equal? (object-read-current? genuine) #t)
    (check-equal? (object-read-issued? (copy-read genuine)) #f)
    (replay-slot-reads! roots (lambda (_r _k) (void)))
    (set! completed (+ completed 1)))
  (test-case "a borrowed birth cannot authorize a copy or a changed payload"
    (.def Root port: 5432)
    (def genuine (selected (recorded (cut .get Root port)) 'port))
    ;; Object and lower source preparation check ONE existing authority. A
    ;; separately created factory still cannot introduce evidence into it.
    (check-equal? (%issued-read? genuine) #t)
    (check-equal? (object-read-issued? genuine) #t)
    (defvalues (foreign-issue foreign-issued? _foreign-inspect) (make-read-issuer))
    (def foreign (foreign-issue Root 'port (object-revision Root)
      (slot-read-instance genuine) 5432 (slot-read-dependencies genuine) object-read-current?))
    (check-equal? (foreign-issued? foreign) #t)
    (check-equal? (foreign-issued? genuine) #f)
    (check-equal? (%issued-read? foreign) #f)
    (check-equal? (object-read-issued? foreign) #f)
    ;; The signed key must not borrow the producer's mutable list either.
    (def original-key (list 'presence 'port))
    (def structural (foreign-issue Root original-key (object-revision Root)
      (slot-read-instance genuine) #t '() object-read-current?))
    (check-equal? (foreign-issued? structural) #t)
    (set-car! original-key 'cache-miss)
    (set-car! (runtime.slot-ref structural 'key) 'cache-miss)
    (check-equal? (foreign-issued? structural) #f)
    (def forged (copy-read genuine))
    (runtime.slot-set! forged 'birth (runtime.slot-ref genuine 'birth))
    (check-equal? (object-read-issued? forged) #f)
    (runtime.slot-set! genuine 'value 5440)
    (check-equal? (object-read-issued? genuine) #f)
    (check-equal? (object-read-current? genuine) #f)
    (set! completed (+ completed 1)))
  (test-case "the entire dependency closure is authenticated before observing any root"
    (.def External port: 5432)
    (.get External port)
    (def calls 0)
    (def forged (make-slot-read External 'port (object-revision External)
      (object-%instance External) 5432 '() (lambda (_read) (set! calls (+ calls 1)) #t)))
    (.def Root port: (begin (%deliver-slot-read forged #t) 5432))
    (def roots (recorded (cut .get Root port)))
    (def observed 0)
    (refuses "unissued slot dependency"
      (cut replay-slot-reads! roots (lambda (_r _k) (set! observed (+ observed 1)))))
    (check-equal? calls 0)
    (check-equal? observed 0)
    (set! completed (+ completed 1)))
  (test-case "native replay refuses a changed metadata method before executing it"
    (.def Root port: 5432)
    (def roots (recorded (cut .get Root port)))
    (def calls 0)
    (runtime.slot-set! (object-%reads Root) 'ref
      (lambda (_self _key _default) (set! calls (+ calls 1)) #f))
    (refuses "changed metadata ref"
      (cut replay-slot-reads! roots (lambda (_r _k) (void))))
    (check-equal? calls 0)
    (set! completed (+ completed 1)))
  (test-case "callback edits of checker payload are refused in the final native sweep"
    (.def Root port: 5432)
    (def roots (recorded (cut .get Root port)))
    (def genuine (selected roots 'port))
    (def calls 0)
    (refuses "unissued slot dependency"
      (lambda ()
        (replay-slot-reads! roots
          (lambda (_r key)
            (when (eq? key 'port)
              (runtime.slot-set! genuine 'current?
                (lambda (_read) (set! calls (+ calls 1)) #t)))))))
    (check-equal? calls 0)
    (set! completed (+ completed 1)))
  (test-case "replacing birth cannot execute a foreign authenticator"
    (.def Root port: 5432)
    (def genuine (selected (recorded (cut .get Root port)) 'port))
    (def calls 0)
    (runtime.slot-set! genuine 'birth
      (lambda (_read) (set! calls (+ calls 1)) #t))
    (check-equal? (object-read-issued? genuine) #f)
    (check-equal? calls 0)
    (set! completed (+ completed 1)))
  (test-case "a live miss survives GC while dead transient records are not rooted"
    (.def Root port: 5432)
    (def live (selected (recorded (cut .ref/cached Root 'live-missing (lambda () #f)))
                        '(cache-miss live-missing)))
    (def watcher (miss-witness Root))
    (##gc)
    (##gc)
    (check-equal? (object-read-issued? live) #t)
    (check-equal? (object-read-current? live) #t)
    (check-equal? (hash-length watcher) 0)
    (check-equal? (hash-get (object-%reads Root) '(cache-miss missing)) #f)
    (check-equal? (.get Root port) 5432)
    (set! completed (+ completed 1)))

  (test-case "metadata replaced inside an observer is refused before later dispatch"
    (.def Root port: 5432)
    (def roots (recorded (cut .get Root port)))
    (def calls 0)
    (refuses "changed metadata ref"
      (lambda ()
        (replay-slot-reads! roots
          (lambda (_receiver key)
            (when (eq? key 'port)
              (runtime.slot-set! (object-%reads Root) 'ref
                (lambda (_self _key _default) (set! calls (+ calls 1)) #f)))))))
    (check-equal? calls 0)
    (set! completed (+ completed 1)))

  (test-case "warm reobservation forwards the original issued graph"
    (.def Root port: 5432 unused: (error "unselected field forced"))
    (def roots (recorded (cut .get Root port)))
    (def original (selected roots 'port))
    (def forwarded (recorded (cut reobserve-slot-reads! roots)))
    (check-equal? (and (memq original forwarded) #t) #t)
    (check-equal? (andmap object-read-issued? forwarded) #t)
    (set! completed (+ completed 1)))
  (test-case "warm reobservation authenticates before work and protects delivery"
    (.def Root port: 5432)
    (def genuine (selected (recorded (cut .get Root port)) 'port))
    (def calls 0)
    (refuses "unissued slot dependency"
      (cut reobserve-slot-reads! (list (copy-read genuine))
        (lambda () (set! calls (+ calls 1)))))
    (check-equal? calls 0)
    (refuses "object mutation during read replay"
      (cut reobserve-slot-reads! (list genuine) (lambda () (.put! Root 'port 5440))))
    (check-equal? (.get Root port) 5432)
    (refuses "object mutation during read replay"
      (lambda ()
        (call-with-slot-read-observer
          (lambda (_read) (.put! Root 'port 5440))
          (cut reobserve-slot-reads! (list genuine)))))
    (check-equal? (.get Root port) 5432)
    (set! completed (+ completed 1)))
  (test-case "warm reobservation reauthenticates after delivery callbacks"
    (.def Root port: 5432)
    (def genuine (selected (recorded (cut .get Root port)) 'port))
    (def calls 0)
    (refuses "unissued slot dependency"
      (lambda ()
        (call-with-slot-read-observer
          (lambda (read)
            (when (eq? read genuine)
              (runtime.slot-set! read 'current?
                (lambda (_read) (set! calls (+ calls 1)) #t))))
          (cut reobserve-slot-reads! (list genuine)))))
    (check-equal? calls 0)
    (set! completed (+ completed 1)))
  (test-case "private native projection reuses preorder and rebuilds changed root order"
    (.def First port: 5432 unused: (error "unselected"))
    (.def Second port: 5433)
    (def a (selected (recorded (cut .get First port)) 'port))
    (def b (selected (recorded (cut .get Second port)) 'port))
    (def roots (list a b a))
    (def first (captured-order roots))
    (check-equal? (car first) a)
    (check-equal? (length (filter (cut eq? <> a) first)) 1)
    ;; Weak eviction is allowed. Check actual reuse in a no-GC interval rather
    ;; than asserting that a weak value survives an arbitrary collection.
    (def reused 0)
    (let loop ((remaining 8))
      (unless (zero? remaining)
        (let* ((before (f64vector-ref (##process-statistics) 6))
               (previous (captured-order roots))
               (next (captured-order roots))
               (after (f64vector-ref (##process-statistics) 6)))
          (when (= before after)
            (check-equal? (eq? previous next) #t)
            (when (eq? previous next) (set! reused (+ reused 1))))
          (loop (- remaining 1)))))
    (check-equal? (> reused 0) #t)
    (set-car! roots b)
    (set-car! (cdr roots) a)
    (def reordered (captured-order roots))
    (check-equal? (car reordered) b)
    (check-equal? (eq? first reordered) #f)
    (check-equal? (car first) a)
    (set! completed (+ completed 1)))
  (test-case "cached structure retains issuance and transient miss currentness checks"
    (.def Root port: 5432 missing: 99)
    (def roots (recorded (cut .get Root port)))
    (def read (selected roots 'port))
    (captured-order roots)
    (def original (slot-read-dependencies read))
    (def delivered 0)
    (dynamic-wind
      (lambda () (runtime.slot-set! read 'dependencies (cons read original)))
      (lambda ()
        (refuses "unissued slot dependency"
          (cut replay-slot-reads! roots (lambda (_r _k) (set! delivered (+ delivered 1)))))
        (check-equal? delivered 0))
      (lambda () (runtime.slot-set! read 'dependencies original)))
    (captured-order roots)
    (def misses (recorded (cut .ref/cached Root 'missing (lambda () #f))))
    (def revision (object-revision Root))
    (captured-order misses)
    (check-equal? (.get Root missing) 99)
    (check-equal? (object-revision Root) revision)
    (refuses "stale slot dependency" (cut captured-order misses))
    ;; A new child record cannot inherit the parent's projection identity.
    (.def (Child @ Root) port: 5433)
    (def child-roots (recorded (cut .get Child port)))
    (def child-order (captured-order child-roots))
    (check-equal? (eq? child-order (captured-order roots)) #f)
    (check-equal? (.get Root port) 5432)
    (check-equal? (.get Child port) 5433)
    (set! completed (+ completed 1)))
  (test-case "weak projection eviction rebuilds without retaining roots or verdicts"
    (.def Root port: 5432)
    (def roots (recorded (cut .get Root port)))
    (def before (captured-order roots))
    (##gc)
    (##gc)
    (def after (captured-order roots))
    (check-equal? (equal? before after) #t)
    (check-equal? (eq? before after) #f)
    (.put! Root 'port 5433)
    (refuses "stale slot dependency" (cut captured-order roots))
    (check-equal? (.get Root port) 5433)
    (set! completed (+ completed 1)))
  (test-case "changed object constructors take the original uncached path without dispatch"
    (.def Root port: 5432)
    (def read (selected (recorded (cut .get Root port)) 'port))
    (def calls 0)
    (for-each
      (lambda (klass)
        (def original (runtime.find-method klass #f ':init!))
        (dynamic-wind
          (lambda ()
            (runtime.bind-method! klass ':init!
              (lambda (self . args)
                (set! calls (+ calls 1))
                (apply original self args)) #t))
          (lambda ()
            (check-equal? (object-construction-current?) #f)
            ;; A distinct list makes this a cold index demand.
            (check-equal? (car (captured-order (list read))) read)
            (check-equal? calls 0))
          (lambda () (runtime.bind-method! klass ':init! original #t))))
      (list object::t (runtime.object-class (object-%state Root))))
    (check-equal? (object-construction-current?) #t)
    (set! completed (+ completed 1)))
  (test-case "scope inspections preserve callback identities without invoking callbacks"
    (def calls 0)
    (def before (lambda (_receiver _key) (set! calls (+ calls 1))))
    (def cause (cons 'scope 'failure))
    (check-equal? (slot-read-precheck-active? before) #f)
    (call-with-slot-read-observer void
      (lambda ()
        (check-equal? (slot-read-precheck-active? before) #t)
        (check-equal? (slot-read-observers-compatible? (list void)) #f)
        (check-equal? (slot-read-observers-compatible? (list void) (list before)) #t)
        (defvalues (_ reads)
          (%call-with-recorded-slot-reads
            (lambda ()
              (check-equal? (slot-read-observers-compatible? (list void) (list before)) #t))))
        (check-equal? reads '())
        (def caught
          (with-catch values
            (lambda ()
              (call-with-slot-read-observer (lambda (_read) (set! calls (+ calls 1)))
                (lambda ()
                  (check-equal? (slot-read-observers-compatible? (list void) (list before)) #f)
                  (raise cause))))))
        (check-equal? (eq? caught cause) #t)
        (check-equal? (slot-read-observers-compatible? (list void) (list before)) #t))
      before: before)
    (check-equal? calls 0)
    (check-equal? (slot-read-precheck-active? before) #f)
    (check-equal? (slot-read-observers-compatible? '()) #t)
    (let (returned
          (call-with-values
            (lambda ()
              (call-with-slot-read-observer void
                (lambda () (values #f (slot-read-precheck-active? before) cause))
                before: before))
            list))
      (check-equal? returned (list #f #t cause))
      (check-eq? (caddr returned) cause)
      (check-eq? (slot-read-precheck-active? before) #f))
    (set! completed (+ completed 1)))
  (test-case "checkpoint counts native identity traversal once without read delivery"
    (.def Root field: 1 unused: (error "unselected slot was forced"))
    (def roots (recorded (cut .get Root field)))
    (def repeated (append roots roots))
    (def visits 0)
    (replay-slot-reads! repeated (lambda (_receiver _key) (set! visits (1+ visits))))
    (check-equal? (> visits 0) #t)
    (def calls 0)
    (def delivered
      (recorded (lambda ()
        (call-with-current-slot-reads repeated
          (lambda (count)
            (set! calls (1+ calls))
            (check-equal? count visits))))))
    (check-equal? calls 1)
    (check-equal? delivered '())
    (check-equal? (call-with-current-slot-reads repeated values) visits)
    (check-equal? (call-with-current-slot-reads '() values) 0)
    (call-with-current-slot-reads '() (lambda (count) (check-equal? count 0)))
    ;; A genuine miss is usable without entering the receiver's read cache.
    (def misses (recorded (cut .ref/cached Root 'missing (lambda () #f))))
    (def miss (selected misses '(cache-miss missing)))
    (check-equal? (object-read-issued? miss) #t)
    (check-equal? (hash-get (object-read-table Root) '(cache-miss missing)) #f)
    (call-with-current-slot-reads misses (lambda (count) (check-equal? (> count 0) #t)))
    (set! completed (1+ completed)))
  (test-case "checkpoint preflight refuses forgery before stale support or action"
    (.def Root field: 1)
    (def read (selected (recorded (cut .get Root field)) 'field))
    (def calls 0)
    (def (action _count) (set! calls (1+ calls)))
    (.put! Root 'field 2)
    (refuses "unissued slot dependency"
      (cut call-with-current-slot-reads (list read (copy-read read)) action))
    (refuses "unissued slot dependency"
      (cut call-with-current-slot-reads (list read (copy-read read)) values))
    (refuses "stale slot dependency"
      (cut call-with-current-slot-reads (list read) values))
    (refuses "stale slot dependency"
      (cut call-with-current-slot-reads (list read) action))
    ;; A later issuance refusal must win over an earlier bad receiver route,
    ;; both on cold acquisition and after the same traversal has been indexed.
    ;; Fixed checkpoints and observer delivery owe the same preflight order.
    (for (warm? '(#f #t))
      (def first (.o first: 1))
      (def last (.o last: 2))
      (def competing (append (recorded (cut .ref first 'first))
                             (recorded (cut .ref last 'last))))
      (when warm? (call-with-current-slot-reads competing values))
      (def invoked 0)
      (runtime.slot-set! (selected competing 'last) 'value 3)
      (runtime.slot-set! (object-%reads first) 'ref
        (lambda (_self _key _default) (set! invoked (+ invoked 1)) #f))
      (for (action (list values void))
        (refuses "unissued slot dependency"
          (cut call-with-current-slot-reads competing action)))
      (refuses "unissued slot dependency"
        (cut replay-slot-reads! competing
          (lambda (_receiver _key) (set! invoked (+ invoked 1)))))
      (check-equal? invoked 0))
    (check-equal? calls 0)
    (set! completed (1+ completed)))
  (test-case "checkpoint protects selected ancestors and restores nested failure frames"
    (.def Parent port: 5432 unused: (error "unselected slot was forced"))
    (def Child (.o inherit: [Parent]))
    (def Other (.o port: 7000))
    (def roots (recorded (cut .get Child port)))
    (def cause (list 'checkpoint-error))
    (call-with-current-slot-reads roots
      (lambda (_count)
        (refuses "object mutation during read replay" (cut .put! Parent 'port 5440))
        (refuses "object mutation during read replay" (cut .put! Child 'port 5440))
        (.put! Other 'port 7001)
        (check-eq?
          (with-catch values
            (lambda () (call-with-current-slot-reads roots (lambda (_) (raise cause)))))
          cause)
        (refuses "object mutation during read replay" (cut .put! Child 'port 5440))))
    (check-equal? (.get Parent port) 5432)
    (check-equal? (.get Child port) 5432)
    (check-equal? (.get Other port) 7001)
    (.put! Child 'port 5440)
    (check-equal? (.get Parent port) 5432)
    (check-equal? (.get Child port) 5440)
    (set! completed (1+ completed)))
  (test-case "changed class slot routing refuses despite unchanged wrapper identity"
    (.def Owner value: #f)
    (def roots (recorded (cut .get Owner value)))
    (def table (object-%reads Owner))
    (def class (runtime.object-class table))
    (def offsets (runtime.&class-type-slot-table class))
    (def original (runtime.class-slot-offset class 'ref))
    (def replacement (runtime.class-slot-offset class 'object))
    (for (action (list (cut call-with-current-slot-reads roots values)
                      (cut call-with-current-slot-reads roots void)
                      (cut replay-slot-reads! roots
                        (lambda (_receiver _key) (error "must not deliver")))))
      (def failure
        (dynamic-wind
          (lambda () (symbolic-table-set! offsets 'ref replacement))
          (lambda () (with-catch values action))
          (lambda () (symbolic-table-set! offsets 'ref original))))
      (check-equal? (Error? failure) #t)
      (when (Error? failure)
        (check-equal? (Error-message failure) "changed metadata ref")))
    (check-eq? (runtime.object-class table) class)
    (call-with-current-slot-reads roots values)
    ;; Entry layout success cannot survive the author callback. The return
    ;; loop must start a new interval and refuse the changed class mapping.
    (try
      (refuses "changed metadata ref"
        (lambda () (call-with-current-slot-reads roots
          (lambda (_) (symbolic-table-set! offsets 'ref replacement)))))
      (finally (symbolic-table-set! offsets 'ref original)))
    (call-with-current-slot-reads roots values)
    (set! completed (1+ completed)))
  (test-case "fixed checkpoints recheck alternating receivers and callback return"
    (for (warm? '(#f #t))
      ;; Explicit temporal binding: taking the metadata snapshot must FOLLOW
      ;; the observed demand, in both compiled and source execution.
      (let* ((Left (.o a: #f c: 3))
             (Right (.o b: 2))
             (Root (.o value: (list (.get Left a) (.get Right b) (.get Left c))))
             (roots (recorded (cut .get Root value))))
        ;; The existing topology set also owns dense stable positions. Flags
        ;; are absent from this shared index, including after callback return.
        (call-with-issued-reads roots
          (lambda (_reads _current! receivers)
            (def positions (hash-values receivers))
            (for (index (in-range (hash-length receivers)))
              (check (memv index positions) ? values))) #t)
        (when warm? (call-with-current-slot-reads roots values))
        (let* ((calls 0) (table (object-%reads Right))
               (saved (runtime.slot-ref table 'ref)))
          (try
            (runtime.slot-set! table 'ref
              (lambda (_self _key _default) (set! calls (+ calls 1)) #f))
            (for (action (list values void))
              (refuses "changed metadata ref" (cut call-with-current-slot-reads roots action)))
            (finally (runtime.slot-set! table 'ref saved)))
          (check-equal? calls 0)
          (call-with-current-slot-reads roots values)
          (try
            (refuses "changed metadata ref"
              (lambda ()
                (call-with-current-slot-reads roots
                  (lambda (_count)
                    (runtime.slot-set! table 'ref
                      (lambda (_self _key _default) (set! calls (+ calls 1)) #f))))))
            (finally (runtime.slot-set! table 'ref saved)))
          (check-equal? calls 0)
          (call-with-current-slot-reads roots void))))
    ;; Return keeps serial first-refusal order, rather than moving a later
    ;; issuance refusal ahead of an earlier stale live value.
    (.def First value: 1)
    (.def Last value: 2)
    (def roots (append (recorded (cut .get First value)) (recorded (cut .get Last value))))
    (def last-read (car (filter (lambda (read) (eq? (slot-read-receiver read) Last))
                         (filter (lambda (read) (eq? (slot-read-key read) 'value)) roots))))
    (try
      (refuses "stale slot dependency"
        (lambda ()
          (call-with-current-slot-reads roots
            (lambda (_count)
              (hash-put! (object-%instance First) 'value 3)
              (runtime.slot-set! last-read 'value 4)))))
      (finally
        (hash-put! (object-%instance First) 'value 1)
        (runtime.slot-set! last-read 'value 2)))
    (call-with-current-slot-reads roots values)
    (set! completed (1+ completed)))
  (test-case "checkpoint authenticates after action and preserves multiple return values"
    (.def Root port: 5432)
    (def roots (recorded (cut .get Root port)))
    (def read (selected roots 'port))
    (def checker (runtime.slot-ref read 'current?))
    (try
      (refuses "unissued slot dependency"
        (lambda () (call-with-current-slot-reads roots
          (lambda (_) (runtime.slot-set! read 'current? (lambda (_) #t))))))
      (finally (runtime.slot-set! read 'current? checker)))
    (defvalues (left right)
      (call-with-current-slot-reads roots (lambda (_) (values 'left 'right))))
    (check-equal? (list left right) '(left right))
    (check-equal? (object-read-current? read) #t)
    ;; A lazy fill is an observation effect even when both the old default
    ;; and computed value are false and the logical revision is unchanged.
    (.def Lazy value: #f)
    (defvalues (absent before-fill)
      (%call-with-recorded-slot-reads (lambda () (.ref/cached Lazy 'value))))
    (check-eq? absent #f)
    (def miss (selected before-fill '(cache-miss value)))
    (def revision (object-revision Lazy))
    (call-with-current-slot-reads (list miss) void)
    (refuses "stale slot dependency"
      (lambda () (call-with-current-slot-reads (list miss)
        (lambda (_) (check-eq? (.get Lazy value) #f) 'returned))))
    (check-equal? (object-revision Lazy) revision)
    (defvalues (present after-fill)
      (%call-with-recorded-slot-reads (lambda () (.get Lazy value))))
    (check-eq? present #f)
    (call-with-current-slot-reads after-fill void)
    (set! completed (1+ completed)))
  (test-case "symbolic field metadata cannot redirect a cold closure"
    (with-declared-field-fixture
      (lambda (root _source)
        (def normal (call-with-current-slot-reads (list root) values))
        (check-equal? (> normal 2) #t)
        (def redirected
          (with-moved-declared-field root 'dependencies 'value
            (lambda () (call-with-current-slot-reads (list root) values))))
        (check-equal? redirected normal)))
    (set! completed (1+ completed)))
  (test-case "cold replay authenticates the original parent after a metadata move"
    (with-declared-field-fixture
      (lambda (root source)
        (def revision (slot-read-revision source))
        (def (attempt)
          (with-catch values
            (lambda () (call-with-current-slot-reads (list root) values))))
        (dynamic-wind
          (lambda () (runtime.slot-set! source 'revision (1+ revision)))
          (lambda ()
            (def ordinary (attempt))
            (check-equal? (Error? ordinary) #t)
            (when (Error? ordinary)
              (check-equal? (Error-message ordinary) "unissued slot dependency"))
            (def moved
              (with-moved-declared-field root 'dependencies 'value attempt))
            (check-equal? (Error? moved) #t)
            (when (Error? moved)
              (check-equal? (Error-message moved) "unissued slot dependency")))
          (lambda () (runtime.slot-set! source 'revision revision)))))
    (set! completed (1+ completed)))
  (test-case "a new issuer retains constructor field meanings after display edits"
    (def sample (make-slot-read #f 'sample 0 #f #f '() values))
    (for-each
      (lambda (field)
        (with-moved-declared-field sample field (if (eq? field 'value) 'revision 'value)
          (lambda ()
            (defvalues (issue issued? _inspect) (make-read-issuer))
            (def read (issue #f 'metadata-field 0 #f 'payload '() values))
            (check-equal? (issued? read) #t)
            (check-equal? (slot-read-key read) 'metadata-field)
            (check-equal? (slot-read-value read) 'payload)
            (check-equal? (slot-read-dependencies read) '())
            (check-equal? (%issued-read? read) #f))))
      '(key value current? dependencies birth))
    (set! completed (1+ completed)))
))
