;;; Typed command traces compare real indexed deltas with an independent list model.
(export Command model lifecycle with-collection-system collection-property collection-tests)
(import :std/error :std/iter (only-in :std/list/list filter-map)
        ../object ../mop ../type ../number ../property-testing ../support/option
        ../table ../rationaldict (only-in ../trie SimpleTrie))

;; Receipts are logical model data, never real TableDelta objects or owner handles.
(defstruct ticket (epoch key before after) final: #t)
;; Pure successors own new record/list spines; previous model states are not edited.
(defstruct ledger (epoch ready? rows tickets tick) final: #t)
;; A real fixture retains its last primary root even while its index family is stale.
(defstruct actual (family state root tickets ready?) final: #t)
;; The public command/result languages have finite tags and explicit scalar domains.
(def Reply (Enum staged installed restored removed conflict index-conflict
                 expired stale-index refreshed stale-delta))
;; Ordered Union alternatives are distinguished by Exactly tags, not an Any case.
(def Command (Union (Tuple (Exactly 'stage) UInt UInt Integer)
  (Tuple (Exactly 'install) UInt Reply) (Tuple (Exactly 'undo) UInt Reply)
  (Tuple (Exactly 'put) UInt Integer Reply) (Tuple (Exactly 'remove) UInt)
  (Tuple (Enum expire read-old refresh))))
;; These explicit opaque State descriptors admit logical records, including stale
;; fixture states; liveness is a transition precondition, not record recognition.
(def ModelState (.cc Type. .element?: ledger?))
;; Actual snapshots are owned by the scoped fixture and are never report payloads.
(def ActualState (.cc Type. .element?: actual?))
;; Both sides expose epoch, liveness, ordered primary rows and complete unique index.
(def Observation (Tuple UInt Bool (List (Pair UInt Integer)) (List (Pair Integer UInt))))

;; Canonical observations ignore backend tree shape while preserving every binding.
(def (ordered rows) (list-sort (lambda (a b) (< (car a) (car b))) rows))
;; Independent primary membership distinguishes absent from present zero.
(def (lookup rows key) (let (entry (assv key rows)) (and entry (some (cdr entry)))))
;; Pure list replacement supplies oracle semantics without calling table methods.
(def (replace rows key value)
  (ordered (append (if value (list (cons key (some-value value))) [])
    (filter (lambda (entry) (not (= key (car entry)))) rows))))
;; Unique projection clashes are predicted independently of the index implementation.
(def (collision? rows key value)
  (any (lambda (entry) (and (not (= key (car entry))) (= value (cdr entry)))) rows))
;; Decide one captured forward/inverse edit in the actual protocol's failure order.
(def (installation state saved inverse?)
  (let* ((key (ticket-key saved))
         (before (if inverse? (some (ticket-after saved)) (ticket-before saved)))
         (after (if inverse? (ticket-before saved) (some (ticket-after saved)))))
    (cond
      ((not (= (ledger-epoch state) (ticket-epoch saved))) (values 'stale-delta (ledger-rows state)))
      ((not (equal? (lookup (ledger-rows state) key) before)) (values 'conflict (ledger-rows state)))
      ((and after (collision? (ledger-rows state) key (some-value after)))
       (values 'index-conflict (ledger-rows state)))
      (else (values (if inverse? 'restored 'installed) (replace (ledger-rows state) key after))))))
;; Tags prescribe replies so shrinking cannot silently change a conflict into success.
(def (enabled? state command)
  (match command
    (#('stage id _key _value) (and (ledger-ready? state) (not (assv id (ledger-tickets state)))))
    (#((? (cut memq <> '(install undo)) tag) id expected)
     (and (ledger-ready? state)
       (let (saved (assv id (ledger-tickets state)))
         (and saved (let-values (((reply _rows) (installation state (cdr saved) (eq? tag 'undo))))
           (eq? expected reply))))))
    (#('put key value expected) (and (ledger-ready? state)
      (eq? expected (if (collision? (ledger-rows state) key value) 'index-conflict 'installed))))
    (#('remove _key) (ledger-ready? state))
    (#('expire) (ledger-ready? state))
    (#((? (cut memq <> '(read-old refresh)))) (not (ledger-ready? state)))
    (else #f)))
;; Reference transitions manipulate only logical rows, generations and ticket data.
(def (advance state command)
  (def (next rows tickets (ready? (ledger-ready? state)) (epoch (ledger-epoch state)))
    (make-ledger epoch ready? rows tickets (1+ (ledger-tick state))))
  (match command
    (#('stage id key value)
     (values (next (ledger-rows state) (cons (cons id (make-ticket (ledger-epoch state)
       key (lookup (ledger-rows state) key) value)) (ledger-tickets state))) 'staged))
    (#((? (cut memq <> '(install undo)) tag) id _expected)
     (let-values (((reply rows) (installation state (cdr (assv id (ledger-tickets state))) (eq? tag 'undo))))
       (values (next rows (ledger-tickets state)) reply)))
    (#('put key value expected)
     (values (next (if (eq? expected 'installed) (replace (ledger-rows state) key (some value))
       (ledger-rows state)) (ledger-tickets state)) expected))
    (#('remove key) (values (next (replace (ledger-rows state) key #f) (ledger-tickets state)) 'removed))
    (#('expire) (values (next (ledger-rows state) (ledger-tickets state) #f (1+ (ledger-epoch state))) 'expired))
    (#('read-old) (values (next (ledger-rows state) (ledger-tickets state)) 'stale-index))
    (#('refresh) (values (next (ledger-rows state) (ledger-tickets state) #t) 'refreshed))))
;; Initial observation and every successor include the entire unique index.
(def (observe state)
  (vector (ledger-epoch state) (ledger-ready? state) (ledger-rows state)
    (if (ledger-ready? state) (ordered (map (lambda (row) (cons (cdr row) (car row))) (ledger-rows state))) [])))
;; A valid deterministic prefix guarantees all required failure/recovery families.
(def lifecycle (list #(stage 0 1 10) #(install 0 installed)
  #(stage 1 2 10) #(install 1 index-conflict) #(remove 1) #(install 1 installed) #(undo 1 restored)
  #(stage 2 3 30) #(put 3 31 installed) #(install 2 conflict) #(remove 3)
  #(install 2 installed) #(undo 2 restored) #(stage 3 4 40) #(expire) #(read-old) #(refresh)
  #(install 3 stale-delta) #(stage 4 4 40) #(install 4 installed) #(undo 4 restored)))
;; Every random choice uses only the caller's PRNG; enabled alternatives are built
;; from the CURRENT model, so there is no rejection loop or retained random state.
(def (draw state random _size)
  (some (if (< (ledger-tick state) (length lifecycle)) (list-ref lifecycle (ledger-tick state))
    (if (not (ledger-ready? state)) (if (zero? (random 2)) #(refresh) #(read-old))
      (let* ((key (random 5)) (value (random 41)) (tickets (ledger-tickets state))
             (choices (list (vector 'stage (ledger-tick state) key value) (vector 'remove key)
               (vector 'put key value (if (collision? (ledger-rows state) key value) 'index-conflict 'installed)) #(expire))))
        (if (and (pair? tickets) (zero? (random 2)))
          (let* ((entry (list-ref tickets (random (length tickets)))) (inverse? (zero? (random 2))))
            (let-values (((reply _rows) (installation state (cdr entry) inverse?)))
              (vector (if inverse? 'undo 'install) (car entry) reply)))
          (list-ref choices (random (length choices)))))))))
;; Parameter shrinking preserves prescribed outcomes; prefix repair retires any
;; now-disabled dependents, and the existing runner independently checks falsity.
(def (shrink-command command)
  (match command
    (#('stage id key value) (if (zero? value) [] (list (vector 'stage id key 0))))
    (#('put key value expected) (if (zero? value) [] (list (vector 'put key 0 expected))))
    (else [])))
;; Positive trace length plus this parameter weight makes deletion strictly smaller.
(def (command-weight command)
  (apply + (map (lambda (value) (if (number? value) (abs value) 0)) (vector->list command))))
;; The model is an ordinary typed POO object, extensible with .cc for regressions.
(def model (make-instance TraceGenerator Command: Command State: ModelState Result: Reply Observation: Observation
  initial: (lambda () (make-ledger 0 #t [] [] 0)) enabled?: enabled? advance: advance observe: observe
  draw: draw shrink: shrink-command measure: command-weight))

;; Only these documented protocol failures become expected model results. Every
;; unrelated callback/constructor/recognizer exception retains its original cause.
(def (refusal cause)
  (cond ((table-index-conflict? cause) 'index-conflict) ((table-conflict? cause) 'conflict)
    ((and (Error? cause) (equal? (Error-message cause) "stale indexed table")) 'stale-index)
    ((and (Error? cause) (equal? (Error-message cause) "stale or incompatible table delta")) 'stale-delta)
    (else (raise cause))))
;; Each property/shrink/replay invocation receives its own source metadata,
;; index snapshots and real deltas. Stable specification objects are not mutated.
(def (with-collection-system use backend: (backend 'rationaldict) fault: (fault 'none))
  (using ((backend :~ (one-of rationaldict trie)) (fault :~ (one-of none stale inverse index atomic)))
    (def source (.cc (if (eq? backend 'trie) (SimpleTrie UInt Integer) (RationalDict Integer)) epoch: 0))
    (def declaration (.cc Type. name: 'value table: (RationalDict (.@ source Key)) unique?: #t
      project: (lambda (_ value) value)))
    (def (family) (table-indexes source (list declaration)))
    (def indexed (family)) (def root (.@ source .empty))
    ;; Only a successful operation publishes its returned indexed snapshot.
    (def (publish state snapshot)
      (make-actual (actual-family state) snapshot (.call (actual-family state) .unwrap snapshot)
        (actual-tickets state) #t))
    ;; Normalize public observations, never the index implementation's private structs.
    (def (inspect state)
      (def rows (ordered (.call source .list<- (actual-root state))))
      (def keys (if (actual-ready? state)
        (ordered (.call (actual-family state) .index-fold (actual-state state) 'value
          (lambda (value key rest) (cons (cons value key) rest)) [])) []))
      (vector (.get source epoch) (actual-ready? state) rows
        (if (and (eq? fault 'index) (pair? keys)) (cons (cons (caar keys) (1+ (cdar keys))) (cdr keys)) keys)))
    ;; The fixture adapter delegates all real edits/inversion/conflicts to public APIs.
    (def (step state command)
      (try
        (match command
          (#('stage id key value)
           (def delta (.call source .delta/opt key (lambda (_) (some value)) (actual-root state)))
           (values (make-actual (actual-family state) (actual-state state) (actual-root state)
             (cons (cons id delta) (actual-tickets state)) #t) 'staged))
          (#((? (cut memq <> '(install undo)) tag) id _expected)
           (def delta (cdr (assv id (actual-tickets state))))
           (if (and (eq? fault 'inverse) (eq? tag 'undo)) (values state 'restored)
             (values (publish state (.call (actual-family state) .apply-delta (actual-state state)
               (if (eq? tag 'undo) (invert-table-delta delta) delta)))
               (if (eq? tag 'undo) 'restored 'installed))))
          (#('put key value _expected)
           (values (publish state (.call (actual-family state) .acons key value (actual-state state))) 'installed))
          (#('remove key)
           (values (publish state (.call (actual-family state) .remove (actual-state state) key)) 'removed))
          (#('expire)
           (.set! source epoch (1+ (.get source epoch)))
           (values (make-actual (actual-family state) (actual-state state) (actual-root state)
             (actual-tickets state) #f) 'expired))
          (#('read-old) (.call (actual-family state) .list<- (actual-state state))
            (error "old family unexpectedly readable"))
          (#('refresh)
           (let* ((fresh (family)) (snapshot (.call fresh .wrap (actual-root state))))
             (values (make-actual fresh snapshot (actual-root state) (actual-tickets state) #t) 'refreshed))))
        (catch (cause)
          (def reply (refusal cause))
          (cond
            ((and (eq? fault 'stale) (eq? reply 'stale-delta)) (values state 'installed))
            ((and (eq? fault 'atomic) (eq? reply 'index-conflict))
             (match command
               (#('install id _expected)
                ;; Fault injection models an implementation publishing primary
                ;; BEFORE final index admission; it is not a production fallback.
                (values (make-actual (actual-family state) (actual-state state)
                  (.call source .apply-delta (actual-root state) (cdr (assv id (actual-tickets state))))
                  (actual-tickets state) #t) reply))
               (else (values state reply))))
            (else (values state reply))))))
    (use (make-instance (TraceSystem ActualState) initial: (make-actual indexed (.call indexed .wrap root) root [] #t)
      step: step observe: inspect))))
;; Ordinary Boolean projection permits the same fixture in std/test or FUN/IO.
(def (collection-property backend (fault 'none))
  (trace-property model (lambda (use) (with-collection-system use backend: backend fault: fault))))
;; Downstream consumers use the existing report/Reader chain, with no new runner.
(def (collection-tests consume backend: (backend 'rationaldict))
  (def sampler (trace-generator Command model steps: 64))
  (property-action (.get sampler descriptor) (collection-property backend) consume sampler: sampler))
