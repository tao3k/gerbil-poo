;;; Matched full/reused fold transport, with fixed prefixes, AB/BA and A/A controls.
(export main)
(import :std/iter ../object ../mop ../number ../type ../table ../rationaldict
        (only-in ../slot-layout make-slot-cache slot-cache-name slot-cache-hit? slot-cache-read slot-cache-bind! slot-cache-index slot-layout-ref slot-layout-set! make-slot-layout slot-layout-index)
        (only-in ../object-contract-flow checked-action)
        (only-in ../slot-observation call-with-slot-read-observer %slot-read-active?)
        (only-in :gerbil/runtime/loader load-module)
        (prefix-in ../examples/representation-service service.)
        (only-in ../support/base number-comparer) ../support/option (only-in ../fun Wrapper.) (only-in ../trie SimpleTrie Trie. trie-for-each-change) (only-in ../fun IdWrap)
        (only-in "closure-measure.ss" measure measure-pair median mean))

;; One inventory drives diagnostic setup and the full measured suite.
(def +backend-phases+
  '(backend-rational-prepare backend-rational-cold backend-rational-observe backend-rational-equality
    backend-rational-workflow backend-rational-retry
    backend-trie-prepare backend-trie-cold backend-trie-observe backend-trie-equality
    backend-trie-workflow backend-trie-retry
    backend-trie-shape-cold backend-trie-shape-workflow backend-trie-shape-retry))

;; Ordered diagnostics retain the existing complete publication and ownership phases.
(def +order-phases+
  '(order-factory order-prepare order-cold order-seek order-range order-diff order-stage
    order-owner order-workflow order-publication))

;; Cold preparation, lazy evaluation and switched/tracked hot access all remain
;; visible. The module phase measures a standard cached load, not a fresh import.
(def +slot-phases+ '(slot-prepare slot-cold slot-hot slot-switch slot-tracked slot-revision slot-load-workflow
    slot-seeding-prepare slot-seeding-workflow slot-seeding-all
    slot-shape-prepare slot-shape-workflow slot-shape-change))

;; Compare the same current layout constructor with/without an old shape hint.
;; Full operations use the preceding inline route and the production hint route.
;; Preparation charges complete name capture, duplicate removal and value seeding.
;; Full workflows include cached standard loading, fresh inherited owners, checked
;; Reader consumers, shared invalidation, refused refinement and successful retry.
;; Changed layouts exercise both added and removed fields, not only steady hits.
(def (shape-workload size scenario)
  (def names (for/collect (n (in-range size)) (string->symbol (string-append "extra-" (number->string n)))))
  (def entries (map (lambda (name) (cons name #f)) names))
  (def initial (list->hash-table entries))
  (def old (make-slot-layout names initial absent-value))
  (def (action reuse?)
    (lambda ()
      (if (eq? scenario 'slot-shape-prepare)
        (let (layout (make-slot-layout (append (reverse names) names) initial absent-value previous: (and reuse? old)))
          (unless (eq? (slot-layout-ref layout (slot-layout-index layout (car names))) #f)
            (error "shape preparation oracle")))
        (begin
          (load-module "clan/poo/examples/representation-service")
          (let* ((recipe (.o inherit: [service.Service (object<-alist entries)] tariff: 3))
                 (owners (for/collect (n (in-range 4)) (.o inherit: [recipe] capacity: n)))
                 (site (make-slot-cache 'total)) (delivered 0)
                 (consume (checked-action service.ValidService
                   (lambda (owner)
                     (let (total ((if reuse? .ref/inline reference-inline) owner site))
                       (set! delivered (1+ delivered)) total)))))
            ;; Exactly one checked boundary owns refinement. Only its admitted
            ;; receiver is prepared/read; original sources get no duplicate layout.
            (def (visit tariff)
              (.putslot! recipe 'tariff ($constant-slot-spec tariff))
              (let (total (for/fold (sum 0) (owner owners) (+ sum (consume owner))))
                (unless (= total (+ 12 (* 6 tariff))) (error "shape workflow oracle"))))
            (visit 3)
            (when (eq? scenario 'slot-shape-change) (.putslot! recipe 'approval ($constant-slot-spec #f)))
            (visit 4)
            (.putslot! recipe 'tariff ($constant-slot-spec -1))
            (unless (and (TypeError? (with-catch identity (cut consume (car owners)))) (= delivered 8))
              (error "shape refused consumer oracle"))
            (when (eq? scenario 'slot-shape-change) (.removeslot! recipe 'approval))
            (visit 5)
            (unless (= delivered 12) (error "shape delivery oracle")))))
      #t))
  (values (action #f) (action #t)))

;; Counterfactual for hot/switch: the preceding production read path, with
;; eager value seeding and the SAME ready-layout shortcut/observation guard.
;; Benchmark-only; it is not an alternate production evaluator or compatibility API.
(def (reference-inline receiver cache)
  (def slot (slot-cache-name cache))
  (if (%slot-read-active?) (.ref receiver slot)
    (let (prepared (object-%layout receiver))
      (if (and (not prepared) (bootstrap-anchor receiver slot)) (.ref receiver slot)
        (let ((layout (or prepared (object-layout receiver eager?: #t)))
              (revision (object-revision receiver)))
          (if (slot-cache-hit? cache receiver revision layout) (slot-cache-read cache)
            (let* ((index (slot-cache-index cache layout))
                   (stored (if index (slot-layout-ref layout index) absent-value))
                   (value (if (eq? stored absent-value)
                     (let (value (.ref receiver slot))
                       (when index (slot-layout-set! layout index value)) value) stored)))
              (slot-cache-bind! cache receiver revision layout index) value)))))))

;; Compare cached-value seeding with demand promotion on identical finite shapes.
;; Preparation isolates the shared-shape/vector work. Complete workflows charge
;; construction, warming, selected/all reads and supported revision recovery.
(def (seeding-workload size scenario)
  (def names (for/collect (n (in-range size)) (string->symbol (string-append "field-" (number->string n)))))
  (def entries (map (lambda (name) (cons name 1)) names))
  (def initial (list->hash-table entries))
  (def first (car names))
  (def (action deferred?)
    (lambda ()
      (if (eq? scenario 'slot-seeding-prepare)
        (let* ((layout (make-slot-layout names (and (not deferred?) initial) absent-value))
               (stored (slot-layout-ref layout (slot-layout-index layout first))))
          (unless (if deferred? (eq? stored absent-value) (= stored 1)) (error "seeding preparation oracle")))
        (let ((owner (object<-alist entries)) (site (make-slot-cache first eager?: (not deferred?))))
          ;; Warming belongs INSIDE this complete workflow's timing boundary.
          (for-each (cut .ref owner <>) names)
          (if (eq? scenario 'slot-seeding-all)
            (for-each (lambda (name)
              (unless (= (.ref/inline owner (make-slot-cache name eager?: (not deferred?))) 1) (error "all-cell oracle"))) names)
            (unless (= (.ref/inline owner site) 1) (error "selected-cell oracle")))
          (.putslot! owner first ($constant-slot-spec #f))
          (unless (eq? (.ref/inline owner site) #f) (error "revised-cell oracle"))))
      #t))
  (values (action #f) (action #t)))

;; Compare existing symbolic reads with the explicit inline API through the same
;; receiver formulas and runtime. Each side owns its parent, instances and site.
(def (slot-workload size scenario)
  ;; Construction binds formulas without demanding either computed field.
  (def (family)
    (def parent (.o base: 3))
    (cons parent (for/collect (n (in-range size))
      (.o self: self inherit: [parent] offset: n
        (value (+ (.get self base) (.get self offset)))
        (unused (error "slot benchmark forced an unrelated body"))))))
  ;; The sum is checked inside every complete measured operation.
  (def (action inline?)
    (def fixture (family))
    (def reference? (and (not inline?) (memq scenario '(slot-hot slot-switch))))
    (def site (and (or inline? reference?) (make-slot-cache 'value)))
    ;; Read only this receiver, never the last owner's retained result.
    (def (read receiver)
      (cond (inline? (.ref/inline receiver site)) (reference? (reference-inline receiver site))
            (else (.ref receiver 'value))))
    ;; The reference/candidate consume the same ordered receiver trace.
    (def (visit owners cycles base)
      (def total (for/fold (sum 0) (_ (in-range cycles))
        (for/fold (sum sum) (owner owners) (+ sum (read owner)))))
      (unless (= total (* cycles (+ (* base size) (/ (* size (1- size)) 2))))
        (error "slot access oracle" scenario total)) #t)
    (case scenario
      ((slot-prepare) (lambda ()
        (for (owner (cdr (family))) ((if inline? object-layout object-instance) owner)) #t))
      ((slot-cold) (lambda ()
        (def fresh (family)) (def cold-site (and inline? (make-slot-cache 'value)))
        (def total (for/fold (sum 0) (owner (cdr fresh))
          (+ sum (if inline? (.ref/inline owner cold-site) (.ref owner 'value)))))
        (unless (= total (+ (* 3 size) (/ (* size (1- size)) 2))) (error "cold slot oracle")) #t))
      ((slot-hot) (lambda ()
        (def total (for/fold (sum 0) (_ (in-range (* size 16))) (+ sum (read (cadr fixture)))))
        (unless (= total (* size 16 3)) (error "monomorphic slot oracle")) #t))
      ((slot-switch) (cut visit (cdr fixture) 16 3))
      ((slot-tracked) (lambda ()
        (call-with-slot-read-observer (lambda (_) (void)) (cut visit (cdr fixture) 16 3))))
      ((slot-revision) (lambda ()
        (.putslot! (car fixture) 'base ($constant-slot-spec 4)) (visit (cdr fixture) 1 4)
        (.putslot! (car fixture) 'base ($constant-slot-spec 3)) (visit (cdr fixture) 1 3)))
      ((slot-load-workflow) (lambda ()
        (load-module "clan/poo/examples/representation-service")
        ;; Keep initialization after the loader; Gerbil hoists internal defs.
        (let* ((access (and inline? (make-slot-cache 'total)))
               (total (for/fold (sum 0) (n (in-range size))
                 (let (receiver (.cc service.Service capacity: n))
                   (+ sum (if inline? (.ref/inline receiver access) (.ref receiver 'total)))))))
          (unless (= total (+ (* 3 size) (* 3 (/ (* size (1- size)) 2))))
            (error "cached module service oracle")) #t)))))
  (values (action #f) (action #t)))

;; Every variant consumes the same admitted source, delta and exact sum oracle.
;; Factory setup is measured in cold; other phases retain their declared setup.
(def (workload size scenario)
  (def source (.cc (RationalDict Integer) Key: UInt))
  (def target (SimpleTrie UInt Integer))
  (def failure (list 'conversion-refused))
  (def refuse? #f)
  (def replacement 1000000)
  (def keys (.cc Wrapper. Domain: UInt Codomain: UInt
    .ap: (cut bitwise-xor <> 1) .unap: (cut bitwise-xor <> 1)))
  (def payloads (.cc Wrapper. Domain: Integer Codomain: Integer
    .ap: (lambda (v) (when (and refuse? (= v replacement)) (raise failure)) (- v)) .unap: -))
  ;; Both source and target contributions implement the same exact pullback.
  (def (score k v) (+ (* 2 k) v))
  (def (target-score k v) (score (bitwise-xor k 1) (- v)))
  (def source-fold (table-fold source Integer score))
  (def base (.call source .<-list (for/collect (k (in-range 1 (+ size 1))) (cons k k))))
  (def original (.call source-fold .ap base))
  (def total (/ (* 3 size (+ size 1)) 2))
  (def next-total (+ total (- replacement 1)))
  (def mapping (table-isomorphism source target keys payloads))
  (def target-fold (table-fold target Integer target-score))
  (def mapped (.call mapping .ap base))
  (def bstate original)
  (def btarget (.call target-fold .ap mapped))
  (def bridge (.call source-fold .isomorphism target keys payloads))
  (def cstate original)
  (def ctarget (.call bridge .ap original))
  (def derived (.@ bridge Codomain))
  (def delta (.call source .diff base (.call source .acons 1 replacement base)))
  ;; Oracles run inside each measured complete operation, never only its setup.
  (def (consume folding state expected)
    (unless (= (.call folding .get state) expected) (error "collection fold oracle")) #t)
  ;; The prior path updates source, maps both snapshots, then updates target's fold.
  (def (baseline-update edit)
    (def before (.call source-fold .unap bstate))
    (def next (.call source-fold .apply-delta bstate edit))
    (def staged (.call (.@ mapping Delta) .ap (cons before edit)))
    (def changed (.call target-fold .apply-delta btarget (cdr staged)))
    (consume source-fold next next-total) (consume target-fold changed next-total)
    (set! bstate (.call source-fold .apply-delta next (invert-table-delta edit)))
    (set! btarget (.call target-fold .apply-delta changed (invert-table-delta (cdr staged))))
    (consume source-fold bstate total) (consume target-fold btarget total))
  ;; Reused transport updates source once, writes mapped edits, and retains totals.
  (def (candidate-update edit)
    (def changed (.call bridge .apply-delta cstate edit))
    (def next (.call bridge .unap changed))
    (consume source-fold next next-total) (consume derived changed next-total)
    (set! ctarget (.call bridge .apply-delta next (invert-table-delta edit)))
    (set! cstate (.call bridge .unap ctarget))
    (consume source-fold cstate total) (consume derived ctarget total))
  ;; Failure is expected, preserves its identity, and precedes an identical retry.
  (def (retry action)
    (set! refuse? #t)
    (let (cause (try (action delta) #f (catch (cause) cause)))
      (unless (eq? cause failure) (error "collection retry oracle" cause)))
    (set! refuse? #f)
    (action delta))
  (case scenario
    ;; Factory isolates checked metadata/closure construction from any snapshot.
    ((factory)
      (values
        (lambda ()
          (def m (table-isomorphism source target keys payloads))
          (def f (table-fold target Integer target-score))
          (unless (and (eq? (.@ m Domain) source) (eq? (.@ f Value) Integer))
            (error "baseline factory oracle")) #t)
        (lambda ()
          (def m (.call source-fold .isomorphism target keys payloads))
          (unless (and (eq? (.@ m Domain) source-fold) (eq? (.@ (.@ m Codomain) Value) Integer))
            (error "derived factory oracle")) #t)))
    ((cold)
      (values
        (lambda ()
          (def m (table-isomorphism source target keys payloads))
          (def f (table-fold target Integer target-score))
          (consume f (.call f .ap (.call m .ap base)) total))
        (lambda ()
          (def m (.call source-fold .isomorphism target keys payloads))
          (consume (.@ m Codomain) (.call m .ap original) total))))
    ((hit)
      (values (lambda () (consume target-fold (.call target-fold .ap (.call mapping .ap base)) total))
        (lambda () (consume derived (.call bridge .ap cstate) total))))
    ((revision) (values (cut baseline-update delta) (cut candidate-update delta)))
    ((workflow)
      (values
        (lambda ()
          (def before (.call source-fold .unap bstate))
          (baseline-update (.call source .diff before (.call source .acons 1 replacement before))))
        (lambda ()
          (def before (.call source-fold .unap cstate))
          (candidate-update (.call source .diff before (.call source .acons 1 replacement before))))))
    ((retry) (values (cut retry baseline-update) (cut retry candidate-update)))
    (else (error "unknown collection phase" scenario))))

;; Matched ordered-index workload: both sides keep the same source, projections,
;; admission and ownership work. Cold/preparation compare full successor validation
;; with shape-preserving output reuse. Revision phases compare only generic versus
;; shared discovery; seek/range retain the positioned-versus-sorted comparison.
;; Cold includes factories/caches; workflow includes diff, install, ownership and undo.
(def (order-workload size scenario)
  (def source (SimpleTrie UInt UInt))
  ;; Both descriptors use the same backend/order; only output-admission reuse differs.
  (def backend (.cc (.mix Trie. IdWrap) Key: UInt Value: UInt .shape-preserving?: #t))
  (def reference-backend (.cc (.mix Trie. IdWrap) Key: UInt Value: UInt .shape-preserving?: #f))
  (def reference-source #f)
  (set! reference-source (.cc source .for-each-change:
    (lambda (emit before after) (table-for-each-change reference-source emit before after))))
  (def revision? (memq scenario '(order-diff order-stage order-owner order-workflow order-publication)))
  (def base (.call source .<-list (for/collect (k (in-range size)) (cons k k))))
  (def lower (max 0 (- size 4)))
  (def expected (for/collect (k (in-range lower size)) (cons k k)))
  (def preparation? (or revision? (memq scenario '(order-factory order-prepare order-cold))))
  ;; Preparation compares only admission reuse. Query-only phases separately force
  ;; the sorting reference with an extensionally equal but distinct procedure.
  (def (factory optimized?)
    (def compare (if optimized? number-comparer (lambda (a b) (number-comparer a b))))
    (def ordered (table-order
      (if (or revision? optimized? (not preparation?)) backend reference-backend)
      (table-comparer UInt (if preparation? number-comparer compare))))
    (table-indexes (if (and revision? (not optimized?)) reference-source source) (list (.cc Type. name: 'value table: ordered unique?: #t
      project: (lambda (_ row) row)))))
  ;; Validate actual results inside every timed complete operation.
  (def (consume indexed state rows)
    (unless (equal? (.call indexed .index-range state 'value (some lower) (some (1- size))) rows)
      (error "ordered collection range oracle")) #t)
  ;; Each side owns its prepared state and style, sharing only immutable input rows.
  (def (action optimized?)
    (def indexed (factory optimized?))
    (def state (.call indexed .wrap base))
    (def linear (.@ (table-styles indexed) Linear))
    (def producer (if (and revision? (not optimized?)) reference-source source))
    (def after (and (memq scenario '(order-diff order-stage)) (.call producer .acons lower (+ size 1) base)))
    (def prepared (and (eq? scenario 'order-stage) (.call producer .diff base after)))
    ;; The retained and newly constructed workflows share the exact same body.
    ;; Admission, ownership transfer, range observation and undo stay inside timing.
    (def (publish table state style)
      (def delta (.call producer .diff base (.call producer .acons lower (+ size 1) base)))
      (def next (.call style .apply-delta (.call style .ap state) delta))
      (def pure (.call style .convert next 'pure))
      (consume table pure (cdr expected))
      (consume table (.call table .apply-delta pure (invert-table-delta delta)) expected))
    (case scenario
      ((order-factory) (lambda ()
        (unless (.has? (factory optimized?) .index-range) (error "ordered factory oracle")) #t))
      ((order-prepare) (lambda ()
        (unless (eq? (.call indexed .unwrap (.call indexed .wrap base)) base)
          (error "ordered preparation identity oracle")) #t))
      ((order-cold) (lambda ()
        (def fresh (factory optimized?))
        (consume fresh (.call fresh .wrap base) expected)))
      ((order-seek)
        (let (ordered (table-order source (table-comparer UInt
          (if optimized? number-comparer (lambda (a b) (number-comparer a b))))))
          (lambda ()
            (unless (equal? (.call ordered .seek base (some lower)) (some (cons lower lower)))
              (error "ordered collection seek oracle")) #t)))
      ((order-range) (lambda () (consume indexed state expected)))
      ((order-diff) (lambda ()
        (unless (= (table-delta-count (.call producer .diff base after)) 1)
          (error "ordered discovery oracle")) #t))
      ((order-stage) (lambda () (consume indexed (.call indexed .apply-delta state prepared) (cdr expected))))
      ((order-owner) (lambda ()
        (unless (eq? (.call linear .convert (.call linear .ap state) 'pure) state)
          (error "ordered ownership oracle")) #t))
      ((order-workflow) (cut publish indexed state linear))
      ((order-publication) (lambda ()
        (def fresh (factory optimized?))
        (publish fresh (.call fresh .wrap base) (.@ (table-styles fresh) Linear))))
      (else (error "unknown ordered collection phase" scenario))))
  (values (action #f) (action #t)))


;; Attribute work outside every timed interval. The instrumented backend counts
;; full-shape traversal separately from lookup/update traversal and projection work;
;; dynamic-wind restores the diagnostic scope even if shape recognition refuses.
(def (order-shape-work size preserves?)
  (def visits 0) (def shape-visits 0) (def shape-calls 0) (def projections 0)
  (def checking? #f)
  (def source (SimpleTrie UInt UInt))
  (def raw (.cc (.mix Trie. IdWrap) Key: UInt Value: UInt
    .unwrap: (lambda (tree)
      (set! visits (+ visits 1))
      (when checking? (set! shape-visits (+ shape-visits 1))) tree)))
  (def backend (.cc raw .shape-preserving?: preserves?
    .validate-shape: (lambda (tree)
      (set! shape-calls (+ shape-calls 1))
      (dynamic-wind (lambda () (set! checking? #t))
        (lambda () (.call raw .validate-shape tree))
        (lambda () (set! checking? #f))))))
  (def ordered (table-order backend (.@ backend Comparer)))
  (def indexed (table-indexes source (list (.cc Type. name: 'value table: ordered unique?: #t
    project: (lambda (_ row) (set! projections (+ projections 1)) row)))))
  (def base (.call source .<-list (for/collect (key (in-range size)) (cons key key))))
  (set! visits 0) (set! shape-visits 0) (set! shape-calls 0) (set! projections 0)
  (.call indexed .wrap base)
  (displayln "COLLECTION-SHAPE-WORK " (vector size preserves? visits shape-visits shape-calls projections)))

;; Gerbil's host carrier retains the persistent backend and shared Function leaves.
(defstruct representation-snapshot (tree) transparent: #t final: #t)

;; Compare a source backend with its explicit derived representation. Both routes
;; include their own fresh protocol preparation in cold, capture/install/undo in
;; workflow, and conflict/refusal plus explicit retry in retry. Warm sides share
;; only the admitted source fixture; cold creates fresh protocols. The raw source
;; is a cost reference, not a replacement for guards.
(def (representation-workload size scenario (counts #f))
  (def callback (Fun Integer <- Integer))
  (def raw-value (Tuple Integer callback))
  (def cooked-value (Pair callback Integer))
  (def checked (validate callback (lambda (x) (+ x 1))))
  (def trie? (string-prefix? "backend-trie-" (symbol->string scenario)))
  (def shape? (memq scenario '(backend-trie-shape-cold backend-trie-shape-workflow backend-trie-shape-retry)))
  ;; Diagnostic counters run separately from timed observations. Backend reads,
  ;; writes and folds are distinct from carrier, key and payload conversions.
  (def (observe index f)
    (if counts (lambda args
      (vector-set! counts index (+ 1 (vector-ref counts index))) (apply f args)) f))
  ;; Fresh receivers have independent metadata and normal standard-library storage.
  (def (make-source (preserves? #t))
    (def backend (if trie? (SimpleTrie UInt raw-value) (.cc (RationalDict raw-value) Key: UInt)))
    ;; Both diagnostic sides own equivalent protocols, differing only in the
    ;; existing explicit law. No GC-regime switch enters the library.
    (def source (if shape? (.cc backend .shape-preserving?: preserves?) backend))
    (.cc source
      .ref: (observe 6 (.@ source .ref)) .acons: (observe 7 (.@ source .acons))
      .foldl: (observe 8 (.@ source .foldl))))
  (def source (make-source))
  (def rows (for/collect (k (in-range size)) (cons k (vector k checked))))
  (def base (.call source .<-list rows))
  (def replacement (vector (+ size 10) checked))
  ;; Construct the complete generated protocol; callbacks preserve Function identity.
  (def (derive source)
    (def raw (.cc Type. Key: UInt Value: cooked-value .element?: representation-snapshot?))
    (def carrier (.cc Wrapper. Domain: source Codomain: raw
      .ap: (observe 0 make-representation-snapshot) .unap: (observe 1 representation-snapshot-tree)))
    (def keys (.cc Wrapper. Domain: UInt Codomain: UInt
      .ap: (observe 2 (cut bitwise-xor <> 1)) .unap: (observe 3 (cut bitwise-xor <> 1))))
    (def payloads (.cc Wrapper. Domain: raw-value Codomain: cooked-value
      .ap: (observe 4 (lambda (v) (cons (vector-ref v 1) (vector-ref v 0))))
      .unap: (observe 5 (lambda (v) (vector (cdr v) (car v))))))
    (table-wrapper source carrier keys payloads))
  ;; Both routes observe all rows, the exact total, callback identity and behavior.
  ;; This full observation is charged, rather than replaced with a last-key probe.
  (def (consume table snapshot derived? total)
    (def seen 0)
    (def sum (.call table .foldl (lambda (k v acc)
      (def f (if derived? (car v) (vector-ref v 1)))
      (def source-key (if derived? (bitwise-xor k 1) k))
      (def amount (if derived? (cdr v) (vector-ref v 0)))
      (unless (and (<= 0 source-key) (< source-key size)
                   (= amount (if (= source-key 0)
                     (- total (quotient (* size (- size 1)) 2)) source-key)))
        (error "backend binding oracle" k amount))
      (unless (and (eq? f checked) (= (f 7) 8)) (error "backend Function oracle"))
      (set! seen (+ seen 1)) (+ acc amount)) 0 snapshot))
    (unless (and (= seen size) (= sum total)) (error "backend total oracle" seen sum total)) #t)
  (def total (quotient (* size (- size 1)) 2))
  ;; The same captured callback runs once; installation never reruns it. A stale
  ;; snapshot must fail before successful retry and inverse restoration.
  (def (publish table initial derived? retry?)
    (def key (if derived? 1 0))
    (def value (if derived? (cons checked (+ size 10)) replacement))
    (def calls 0)
    (def current initial)
    (def delta (.call table .delta/opt key (lambda (_) (set! calls (+ calls 1)) (some value)) current))
    (when retry?
      (set! current (.call table .acons key (if derived? (cons checked -1) (vector -1 checked)) initial))
      (unless (try (.call table .apply-delta current delta) #f (catch (e) (table-conflict? e)))
        (error "backend conflict oracle"))
      (set! delta (.call table .delta/opt key (lambda (_) (set! calls (+ calls 1)) (some value)) current)))
    (def next (.call table .apply-delta current delta))
    (consume table next derived? (+ total size 10))
    (unless (= calls (if retry? 2 1)) (error "backend capture oracle" calls))
    (consume table (.call table .apply-delta next (invert-table-delta delta)) derived? (if retry? (- total 1) total)))
  (def cold? (string-suffix? "-cold" (symbol->string scenario)))
  (def retry? (string-suffix? "-retry" (symbol->string scenario)))
  ;; Setup is common and recorded separately; only cold constructs within timing.
  (def generated (derive source))
  (def target (.call generated .wrap base))
  ;; Independent same-process reference keeps every derived inverse/Function
  ;; check; disabling the declaration restores output-shape admission.
  (def reference (and shape? (derive (make-source #f))))
  (def reference-target (and reference (.call reference .wrap base)))
  ;; Structural equality is measured directly on fresh, equal/unequal Tuple/Pair
  ;; fixtures. This is an independent control, not a subtraction-based attribution
  ;; of equality CPU inside the full workflow. No conversion occurs in this slice.
  (def (equality-fixture derived?)
    (for/collect (k (in-range size))
      (if derived?
        (vector (cons checked k) (cons checked k) (cons checked (+ k 1)))
        (vector (vector k checked) (vector k checked) (vector (+ k 1) checked)))))
  ;; Slice selection occurs during reported setup; complete publication still
  ;; retains all metadata, conversion, equality, callback and inverse work.
  (def (action derived?)
    (cond
      ((string-suffix? "-prepare" (symbol->string scenario))
        (lambda ()
          (unless (.has? (if derived? (derive (make-source)) (make-source)) .apply-delta)
            (error "backend preparation oracle")) #t))
      ((string-suffix? "-observe" (symbol->string scenario))
        (if derived? (cut consume generated target #t total) (cut consume source base #f total)))
      ((string-suffix? "-equality" (symbol->string scenario))
        (let (entries (equality-fixture derived?))
          (lambda ()
            (for (entry entries)
              (unless (and (equal? (vector-ref entry 0) (vector-ref entry 1))
                           (not (equal? (vector-ref entry 0) (vector-ref entry 2))))
                (error "backend equality oracle"))) #t)))
      ((or derived? shape?)
        (lambda ()
          (def selected-source (if cold? (make-source derived?) source))
          (def selected (if cold? (derive selected-source) (if derived? generated reference)))
          (publish selected
            (if cold? (.call selected .wrap (.call selected-source .<-list rows))
              (if derived? target reference-target)) #t retry?)))
      (else
        (lambda ()
          (def selected (if cold? (make-source) source))
          (publish selected (if cold? (.call selected .<-list rows) base) #f retry?)))))
  (values (action #f) (action #t)))

;; Keep attribution outside timing. Actual equality CPU is included in complete
;; wall/CPU samples; these counts are invocations, never unit-time assumptions.
(def (representation-work size scenario)
  (for (side '(0 1))
    (def counts (make-vector 9 0))
    (def actions (call-with-values (cut representation-workload size scenario counts) vector))
    ;; Retain setup work separately; removing apparently unused cold fixtures
    ;; changed subsequent cold-call tails in paired controls and was withdrawn.
    (displayln "COLLECTION-BACKEND-SETUP-WORK " (vector scenario side counts))
    (vector-fill! counts 0)
    ((vector-ref actions side))
    (displayln "COLLECTION-BACKEND-WORK " (vector scenario side counts))))

;; Raw signed allocation remains visible. Only GC-free, nonnegative samples have
;; an attributable allocation value; GC CPU is reported separately from core CPU.
(def (allocation metrics)
  (and (= (vector-ref metrics 3) 0) (>= (vector-ref metrics 4) 0) (vector-ref metrics 4)))

;; Gambit history fields: cumulative collections/allocation, then the last GC's
;; wall time, heap size and live bytes. Interval fields are GC wall/minor/major
;; faults, followed by the independent monotonic duration. Slot 9 is statistics-structure overhead, never a live-heap estimate.
(def (measurement-history before after elapsed)
  ;; Keep cumulative history separate from this observation's interval deltas.
  (def (prefix stats)
    (vector (f64vector-ref stats 6) (f64vector-ref stats 7)
      (f64vector-ref stats 14) (f64vector-ref stats 15) (f64vector-ref stats 17)))
  (vector (prefix before) (prefix after)
    (- (f64vector-ref after 5) (f64vector-ref before 5))
    (- (f64vector-ref after 10) (f64vector-ref before 10))
    (- (f64vector-ref after 11) (f64vector-ref before 11)) elapsed))

;; Capture the same bounded observation protocol for a batch, forced collection,
;; or first post-GC call. The diagnostic charges preparation instead of hiding it.
(def (measure-collection-action action repetitions regime)
  ;; The observer allocates only after the measured interval has ended.
  (def (capture thunk count)
    (def history #f)
    (defvalues (ok metrics) (measure thunk count #f
      (lambda (before after elapsed) (set! history (measurement-history before after elapsed)))))
    (unless ok (error "collection measured oracle"))
    (vector metrics history))
  (def preparation (and (eq? regime 'post-gc)
    (capture (lambda () (##gc) #t) 1)))
  (def first (and preparation (capture action 1)))
  (when (eq? regime 'collected) (##gc))
  (vector (capture action repetitions) first preparation))

;; Describe every retained pair, including loss count and empirical upper tail.
;; A small sample quantile is diagnostic, never a future latency guarantee.
(def (report-collection-tail label differences)
  (def ordered (list-sort < differences))
  (def n (length ordered))
  (displayln "COLLECTION-TAIL " label " n=" n
    " wins=" (length (filter negative? differences))
    " losses=" (length (filter positive? differences))
    " mean-us=" (mean differences)
    " p90-us=" (list-ref ordered (- (quotient (+ (* 9 n) 9) 10) 1))
    " min=" (car ordered) " max=" (list-ref ordered (- n 1))))

;; Every regime uses fresh matched fixtures per pair and the same fixed prefix.
;; A/A and B/B retain both prefix histories and alternate measurement slots. The
;; candidate control distinguishes its own noise from the slower reference's noise.
;; No natural-regime GC is forced.
;; Full observations go to stdout, never a versioned data file or archive.
(def (run-collection-study width count rounds)
  (def n (string->number width)) (def repetitions (string->number count))
  (def pairs (string->number rounds))
  (unless (and (exact-integer? n) (<= 2 n 1024) (exact-integer? repetitions) (<= 1 repetitions 100)
               (exact-integer? pairs) (<= 4 pairs 12) (even? pairs))
    (error "invalid bounded collection study"))
  (displayln "COLLECTION-CLOCKS wall=system-realtime history-last=runtime-monotonic")
  (displayln "COLLECTION-RUNTIME gerbil=" (gerbil-version-string) " gambit=" (system-version-string))
  (let (startup (##process-statistics))
    (displayln "COLLECTION-STARTUP cpu=" (+ (f64vector-ref startup 0) (f64vector-ref startup 1))
      " wall=" (f64vector-ref startup 2) " gc-cpu=" (+ (f64vector-ref startup 3) (f64vector-ref startup 4))
      " gc-wall=" (f64vector-ref startup 5) " history=" (measurement-history startup startup 0.0)))
  (order-shape-work n #f)
  (order-shape-work n #t)
  (displayln "COLLECTION-BACKEND-COLUMNS #(carrier-ap carrier-unap key-ap key-unap value-ap value-unap read write fold)")
  (for (scenario +backend-phases+)
    (representation-work n scenario))
  (displayln "COLLECTION-PAIRED size=" n " count=" repetitions " rounds=" pairs " prefix=2")
  (displayln "COLLECTION-SLOT-BASELINES hot/switch=prior-untracked-inline other-slots=symbolic-ref module-load=cached")
  (for* ((scenario (append +backend-phases+ '(factory cold hit revision workflow retry) +order-phases+ +slot-phases+)) (regime (if (memq scenario '(backend-rational-workflow backend-rational-retry backend-trie-workflow backend-trie-retry backend-trie-shape-workflow backend-trie-shape-retry order-diff order-stage order-owner order-workflow order-publication slot-cold slot-revision slot-load-workflow))
      '(natural collected post-gc) '(natural collected))) (control? '(#f #t candidate)))
    (def observations [])
    (for (round (in-range (if control? 4 pairs)))
      (def setup-history #f)
      (defvalues (actions setup-metrics)
        (measure (lambda () (call-with-values
          (cond
            ((memq scenario +backend-phases+)
             (cut representation-workload n scenario))
            ((memq scenario +order-phases+)
             (cut order-workload n scenario))
            ((memq scenario '(slot-seeding-prepare slot-seeding-workflow slot-seeding-all))
             (cut seeding-workload n scenario))
            ((memq scenario '(slot-shape-prepare slot-shape-workflow slot-shape-change))
             (cut shape-workload n scenario))
            ((memq scenario +slot-phases+) (cut slot-workload n scenario))
            (else (cut workload n scenario))) vector)) 1 #f
          (lambda (before after elapsed) (set! setup-history (measurement-history before after elapsed)))))
      (def baseline (vector-ref actions 0))
      (def candidate (vector-ref actions 1))
      (displayln "COLLECTION-SETUP " (vector scenario regime control? round setup-metrics setup-history))
      (def order (if (even? round) '(baseline candidate) '(candidate baseline)))
      ;; Fixed-prefix execution is part of entry cost, not unexplained overhead.
      ;; Preserve both calls and order while measuring through the shared helper.
      (let ((history #f))
        (defvalues (_ metrics) (measure (lambda ()
          (for* ((_ (in-range 2)) (side order)) ((if (eq? side 'baseline) baseline candidate)))
          #t) 1 #f (lambda (before after elapsed) (set! history (measurement-history before after elapsed)))))
        (displayln "COLLECTION-PREFIX " (vector scenario regime control? round metrics history)))
      ;; Report after both sides, so serialization cannot perturb the second
      ;; sample's natural GC history. The whole entry still charges every write;
      ;; finally retains partial diagnostics on refusal and one flush per pair.
      (let ((results (measure-pair order
        (lambda (side)
          (def action (cond ((eq? control? 'candidate) candidate) ((or control? (eq? side 'baseline)) baseline) (else candidate)))
          (measure-collection-action action repetitions regime))
        (lambda (completed)
          (for (([side . measured] completed))
            (def batch (vector-ref measured 0))
            (def metrics (vector-ref batch 0))
            (def history (vector-ref batch 1))
            (when (eq? regime 'post-gc)
              (write (vector 'collection-preparation scenario control? round side
                (vector-ref measured 2) (vector-ref measured 1)))
              (newline))
            (write (vector 'collection-pair scenario regime control? round side metrics (allocation metrics) history))
            (newline))
          (force-output)))))
      ;; Read observations after both measured actions; internal definitions are
      ;; expanded ahead of expressions by Gerbil and must not snapshot results.
      (let ((a (cdr (assq 'baseline results))) (b (cdr (assq 'candidate results))))
        (set! observations (cons (vector (vector-ref (vector-ref a 0) 0) (vector-ref (vector-ref b 0) 0)
          (vector-ref (vector-ref a 0) 1) (vector-ref (vector-ref b 0) 1) a b) observations)))))
    ;; Positive signed differences mean regression; controls and ranges remain visible.
    (def (deltas index)
      (map (lambda (pair) (* (/ 1e6 repetitions)
        (- (vector-ref (vector-ref pair 1) index) (vector-ref (vector-ref pair 0) index)))) observations))
    ;; Signed residuals distinguish CPU work and GC wall from elapsed time; a
    ;; wall-minus-CPU difference is not automatically an OS scheduling diagnosis.
    (def (derived-deltas select)
      (map (lambda (pair) (* (/ 1e6 repetitions)
        (- (select (vector-ref pair 1) (vector-ref pair 3))
           (select (vector-ref pair 0) (vector-ref pair 2))))) observations))
    ;; Inclusive diagnostic cost charges one forced collection, the first call and
    ;; every batch call. This is a synthetic control, never the production policy.
    (when (eq? regime 'post-gc)
      (let (charged (map (lambda (pair)
        (def (wall side)
          (apply + (map (lambda (record) (vector-ref (vector-ref record 0) 1))
            (vector->list side))))
        (* (/ 1e6 (+ repetitions 1)) (- (wall (vector-ref pair 5)) (wall (vector-ref pair 4))))) observations))
        (displayln "COLLECTION-CHARGED " scenario "/" control?
          " wall-us=" (median charged) " min=" (apply min charged) " max=" (apply max charged))
        (report-collection-tail (list scenario 'inclusive control?) charged)
        ;; Means of disjoint components add to the inclusive mean; medians do not.
        (for (component '(0 1 2))
          (def (component-deltas select)
            (map (lambda (pair)
              (def (amount side)
                (select (vector-ref (vector-ref (vector-ref side component) 0) 0)
                        (vector-ref (vector-ref (vector-ref side component) 0) 1)
                        (vector-ref (vector-ref (vector-ref side component) 0) 2)))
              (* (/ 1e6 (+ repetitions 1))
                (- (amount (vector-ref pair 5)) (amount (vector-ref pair 4))))) observations))
          (displayln "COLLECTION-COMPONENT " (list scenario control? (list-ref '(batch first forced-gc) component))
            " wall-mean-us=" (mean (component-deltas (lambda (_cpu wall _gc) wall)))
            " non-gc-mean-us=" (mean (component-deltas (lambda (cpu _wall gc) (- cpu gc))))
            " gc-mean-us=" (mean (component-deltas (lambda (_cpu _wall gc) gc)))
            " residual-mean-us=" (mean (component-deltas (lambda (cpu wall _gc) (- wall cpu))))))))
    (let (wall (deltas 1))
      (report-collection-tail (list scenario regime control?) wall)
      (displayln "COLLECTION-SUMMARY " scenario "/" regime "/" (cond ((eq? control? 'candidate) 'bb) (control? 'aa) (else 'ab))
        " wall-us=" (median wall) " min=" (apply min wall) " max=" (apply max wall)
        " cpu-us=" (median (deltas 0)) " gc-us=" (median (deltas 2))
        " non-gc-cpu-us=" (median (derived-deltas (lambda (m _) (- (vector-ref m 0) (vector-ref m 2)))))
        " wall-minus-cpu-us=" (median (derived-deltas (lambda (m _) (- (vector-ref m 1) (vector-ref m 0)))))
        " gc-wall-us=" (median (derived-deltas (lambda (_ h) (vector-ref h 2)))))))
  #t)

;; Charge the entire loaded entry, including diagnostics, setup, prefixes, GC,
;; formatting and output. Startup remains separately reported by the runtime.
(def (main (width "64") (count "3") (rounds "6"))
  (def history #f)
  (defvalues (ok metrics) (measure (cut run-collection-study width count rounds) 1 #f
    (lambda (before after elapsed) (set! history (measurement-history before after elapsed)))))
  (unless ok (error "collection entry oracle"))
  (displayln "COLLECTION-ENTRY " (vector metrics history))
  (displayln "COLLECTION-PAIRED-OK"))
