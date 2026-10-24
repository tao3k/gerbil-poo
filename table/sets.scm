;;; Finite set algebra is an incremental layer over existing Unit-valued tables.

;; Admit both operands before any merge callback or identity shortcut. Recognition
;; does not normalize Function keys again. Metadata protection covers backend work
;; and all observed Key/Value origins; callback exceptions retain their cause.
(def (with-set-inputs descriptor inputs action)
  (def table (.@ descriptor Table))
  (with-table-sources (append (list descriptor)
    (if (.has? descriptor .sources) (.@ descriptor .sources) []) (table-sources table)) (lambda ()
    (unless (eq? (.@ table Value) Unit) (error "set algebra requires Unit values"))
    ;; Resolve refinements under the original guard before extending its scope.
    (def elt (.@ descriptor Elt))
    ;; The ordinary Key alias needs no second scope; overridden contracts do.
    (def (admit)
      (for-each (cut require-set descriptor <>) inputs)
      (action))
    (if (eq? elt (.@ table Key)) (admit)
      (with-table-sources (list elt) admit)))))

;; A set refinement cannot weaken the backing carrier/child admission. Recognition
;; retains admitted Function keys and does not reconstruct or normalize them.
(def (require-set descriptor root)
  (require-table (.@ descriptor Table) root)
  (require-table descriptor root))

;; Both operands, including identical/empty roots, precede relation/merge work.
(def (with-set-tables descriptor left right action)
  (with-set-inputs descriptor (list left right) action))

;; Resolve and call one backing method inside the shared admission scope. Standard
;; apply carries its arguments; callers need no extra construction thunk. Backend
;; failures retain their cause and external callback effects are not undone.
(def (build-set descriptor inputs method . args)
  (with-set-inputs descriptor inputs (lambda ()
    (require-set descriptor (apply (.ref (.@ descriptor Table) method) args)))))

;; Derive the closed point-method family from Function signatures once. Wrapper
;; owns argument/result recognition; no validator cooks an admitted Function key.
;; Method lookup stays inside the call scope, after original-root admission.
(def (set-methods descriptor methods signatures)
  (with-set-inputs descriptor [] (lambda ()
    (object<-alist
      (map (lambda (name)
        (def signature (.ref signatures name))
        (def inputs (.@ signature inputs))
        (def boundary (.cc Wrapper.
          .unap: (lambda (args)
            (unless (signature-shape? signature args) (raise-type-error signature args))
            (for-each (lambda (type value)
              (when (eq? type descriptor) (require-set descriptor value))) inputs args)
            (for-each (lambda (type value)
              (unless (eq? type descriptor) (require-table (.@ descriptor Elt) value))) inputs args)
            args)
          .ap: (cut require-set descriptor <>)))
        (cons name (lambda args
          (with-set-inputs descriptor [] (lambda ()
            (.call boundary .map
              (lambda (checked)
                (def method (.ref methods name))
                (using (method :~ procedure?) (apply method checked)))
              args))))))
        (.all-slots signatures))))))

;; Share the existing Option/Unit decision across snapshot and incremental
;; algebra. These closed operations never coerce keys or compare Functions.
(def (set-operation name)
  (case name
    ((union) (lambda (a b) (or a b)))
    ((inter) (lambda (a b) (and a b)))
    ((diff) (lambda (a b) (and (not b) a)))
    ((symdiff) (lambda (a b) (if a (and (not b) a) b)))
    (else (error "unknown set operation" name))))

;; Reuse the backend's complete merge algorithm and branch order. Its persistent
;; output is private until complete; a failure never returns a partially built set.
(def (merge-set-tables descriptor choose left right)
  (build-set descriptor (list left right) '.merge (lambda (_ a b) (choose a b)) left right))

;; Subset uses the backend's short-circuit traversal and membership primitive.
;; It constructs no merged set and does not compare or rewrap stored elements.
(def (subset-set-tables? table left right)
  (.call table .every (lambda (key _) (.call table .key? right key)) left))

;; Reuse the project Lens constructor and source admission with one typed key.
;; Recognition preserves an already wrapped Function element; it never cooks it.
(def (set-membership-lens descriptor key)
  (def table (.@ descriptor Table))
  (def sources (append (list descriptor)
    (if (.has? descriptor .sources) (.@ descriptor .sources) []) (table-sources table)))
  (def versions (map object-revision sources))
  ;; Both accessors guard the same table origins and refuse invalid element keys.
  (def (observe source action)
    (with-table-sources sources (lambda ()
      (unless (equal? versions (map object-revision sources)) (error "stale set focus"))
      (with-set-inputs descriptor (list source) (lambda ()
      (unless (element? (.@ table Key) key) (raise-type-error (.@ table Key) key))
      (action))))))
  (lens-of-get-set
    (lambda (source) (observe source (lambda () (.call table .key? source key))))
    (lambda (present? source)
      (using (present? :~ boolean?)
        (observe source (lambda ()
          (require-set descriptor
            (if present? (.call table .acons key (void) source) (.call table .remove source key)))))))))

;; Preserve set-specific recognition and declared origins on direct selection,
;; including empty inputs. Table methods own traversal; this only changes arity
;; and admits both returned roots before exposing any result to the caller.
(def (select-set descriptor predicate input split?)
  (using (predicate :~ procedure?)
    (def table (.@ descriptor Table))
    (with-set-inputs descriptor (list input) (lambda ()
      (def classify (lambda (element _) (predicate element)))
      (def roots (if split?
        (let-values (((yes no) (.call table .partition classify input))) (list yes no))
        (list (.call table .filter classify input))))
      (for-each (cut require-set descriptor <>) roots)
      (apply values roots)))))

;; Set decomposition protects custom refinements and metadata on both results;
;; only the optional pivot payload is projected to presence, retaining Unit semantics.
(def (split-set descriptor pivot input)
  (def table (.@ descriptor Table))
  (with-set-inputs descriptor (list input) (lambda ()
      (defvalues (left found right) (.call table .split pivot input))
      (require-set descriptor left)
      (require-set descriptor right)
      (values left (some? found) right))))

;; Project the shared table extraction's observation to an element while keeping
;; source/remainder set refinements in one protected boundary. Unit stays private.
(def (decons-set descriptor input required?)
  (with-set-inputs descriptor (list input) (lambda ()
    (def table (.@ descriptor Table))
    (defvalues (found rest) ((.ref table (if required? '.decons '.decons/opt)) input))
    (require-set descriptor rest)
    (values (if required? (car found) (map/option car found)) rest))))

(define-type (Set<-Table. @ Type. Table sexp)
  ;; Table must be a table from Elt to Unit, i.e. (.@ Table Key) == Elt, (.@ Table Value) == Unit
  Elt: (.@ Table Key) ;; : Type
  ;; Normalize through the backing protocol once, then admit the set refinement.
  .validate: (cut build-set @ [] '.validate <>) ;; : @ <- Any
  .element?: (.@ Table .element?) ;; recognition retains the table protocol without normalization
  ;; Empty is a partial constructor when the declared set excludes that root.
  .empty: (.<-list []) ;; : @
  .empty?: (.@ Table .empty?) ;; : Bool <- @
  .elt?: (.@ Table .key?) ;; : Bool <- @ Elt
  ;; One derived boundary admits the family; the backend delegates stay simple.
  methods: (set-methods @
    (.o .cons: (cut .call Table .acons <> (void) <>)
        .singleton: (lambda (elt) (.call Table .<-list [(cons elt (void))]))
        (.remove (.@ Table .remove)))
    (.o (.cons (.cc Function. inputs: [Elt @] outputs: [@]))
        (.singleton (.cc Function. inputs: [Elt] outputs: [@]))
        (.remove (.cc Function. inputs: [@ Elt] outputs: [@]))))
  .cons: (.@ methods .cons) ;; : @ <- Elt @
  .singleton: (.@ methods .singleton) ;; : @ <- Elt
  .remove: (.@ methods .remove) ;; : @ <- @ Elt
  .for-each: (lambda (f t) (.call Table .for-each (lambda (e _) (f e)) t)) ;; : Unit <- (Unit <- Elt) @
  .for-each/reverse: (lambda (f t) (.call Table .for-each/reverse (lambda (e _) (f e)) t)) ;; : Unit <- (Unit <- Elt) @
  .foldl: (lambda (f a t) (.call Table .foldl (lambda (e _ a) (f e a)) a t)) ;; : a <- (a <- Elt a)
  .foldr: (lambda (f a t) (.call Table .foldr (lambda (e _ a) (f e a)) a t)) ;; : a <- (a <- Elt a)
  .every: (lambda (f t) (.call Table .every (lambda (e _) (f e)) t)) ;; : Bool <- (Bool <- Elt) @
  .any: (lambda (f t) (.call Table .any (lambda (e _) (f e)) t)) ;; : Bool <- (Bool <- Elt) @
  ;; Checked selection protects custom set refinements as well as backing Types.
  .filter: (lambda (f t) (select-set @ f t #f)) ;; : @ <- (Bool <- Elt) @
  ;; The shared set boundary delegates prefix algorithms to the backing table.
  .take: (lambda (count input) (build-set @ (list input) '.take count input))
  .drop: (lambda (count input) (build-set @ (list input) '.drop count input))
  ;; Both branches satisfy the same set descriptor before either escapes.
  .partition: (lambda (f t) (select-set @ f t #t)) ;; : @ @ <- (Bool <- Elt) @
  .count: (.@ Table .count) ;; : Nat <- @
  .list<-: (lambda (t) (map car (.call Table .list<- t))) ;; : (List Elt) <- @
  ;; A complete family may be valid while every singleton is forbidden. Reuse the
  ;; table's bulk constructor once, without exposing intermediate roots.
  .<-list: (lambda (l) (using (l :~ list?)
    (build-set @ [] '.<-list (map (lambda (elt) (cons elt (void))) l)))) ;; : @ <- (List Elt)
  .sexp<-: (lambda (x) `(.call ,sexp .<-list (@list ,@(map (.@ Elt sexp<-) (.list<- x))))) ;; : Sexp <- @
  .min-elt: (lambda (t) (car (.call Table .min-binding t))) ;; : Elt <- @
  .min-elt/opt: (lambda (t) (map/option car (.call Table .min-binding/opt t))) ;; : (Option Elt) <- @
  .max-elt: (lambda (t) (car (.call Table .max-binding t))) ;; : Elt <- @
  .max-elt/opt: (lambda (t) (map/option car (.call Table .max-binding/opt t))) ;; : (Option Elt) <- @
  .choose: .min-elt ;; : Elt <- @
  .choose-opt: .min-elt/opt ;; : (Option Elt) <- @
  ;; Element-level extraction shares table choice, conflicts and complete admission.
  .decons/opt: (lambda (input) (decons-set @ input #f))
  .decons: (lambda (input) (decons-set @ input #t))
  ;; Both set roots pass complete admission before the presence observation escapes.
  .split: (lambda (elt t) (split-set @ elt t)) ;; : @ Bool @ <- Elt @
  .find-first/opt: (lambda (f t) (map/option car (.call Table .find-first/opt (lambda (e _) (f e)) t))) ;; : (Option Elt) <- (Bool <- Elt) @
  .find-first: (lambda (f t) (option-ref (.find-first/opt f t))) ;; : Elt <- (Bool <- Elt) @
  .find-last/opt: (lambda (f t) (map/option car (.call Table .find-last/opt (lambda (e _) (f e)) t))) ;; : (Option Elt) <- (Bool <- Elt) @
  .find-last: (lambda (f t) (option-ref (.find-last/opt f t))) ;; : Elt <- (Bool <- Elt) @
  .iter<-: (lambda (t from: (from #f)) ;; : (Iterator Elt) <- @ ?Elt
              (iterator-map car
                            (if (not from)
                              (.call Table .iter<- t)
                              (.call Table .iter<- t from))))
  ;; Materialize the finite input once and construct the final root once. The
  ;; existing snapshot scan is explicit; no streaming/constant-space law is claimed.
  .<-iter: (case-lambda
    ((s) (with-set-inputs @ [] (lambda () (.<-list (for/collect (elt s) elt)))))
    ((s t) (with-set-inputs @ [t] (lambda ()
      (.<-list (append (.list<- t) (for/collect (elt s) elt))))))) ;; : @ <- (Iterator Elt) ?@
  .List: (List Elt)
  .json<-: (compose (.@ .List .json<-) .list<-) ;; : Json <- @
  .<-json: (compose .<-list (.@ .List .<-json)) ;; : @ <- Json
  .bytes<-: (compose (.@ .List .bytes<-) .list<-) ;; : Bytes <- @
  .<-bytes: (compose .<-list (.@ .List .<-bytes)) ;; : @ <- Bytes
  .marshal: (lambda (x port) (marshal .List (.list<- x) port))
  .unmarshal: (compose .<-list (.@ .List .unmarshal))
  ;; TODO: for union, inter, diff, compare, equal, subset,
  ;; optimize for full subtables, by caching count in wrapper?
  .union: (lambda (a b) (merge-set-tables @ (set-operation 'union) a b)) ;; : @ <- @ @
  .inter: (lambda (a b) (merge-set-tables @ (set-operation 'inter) a b)) ;; : @ <- @ @
  .diff: (lambda (a b) (merge-set-tables @ (set-operation 'diff) a b)) ;; : @ <- @ @
  ;; A lexicographic comparison requires the backend's explicit key-order capability.
  .compare: (lambda (a b) (with-set-tables @ a b (lambda ()
    (unless (.has? Table .compare) (error "unsupported set comparison"))
    (.call Table .compare (lambda (_1 _2) 0) a b)))) ;; : : Integer <- @ @
  ;; Symmetric difference preserves the original surviving admitted key objects.
  .symdiff: (lambda (a b) (merge-set-tables @ (set-operation 'symdiff) a b))
  ;; All relations admit both inputs, including the empty and identical cases.
  .subset?: (lambda (a b) (with-set-tables @ a b
    (lambda () (subset-set-tables? Table a b))))
  .disjoint?: (lambda (a b) (with-set-tables @ a b
    (lambda () (.call Table .every (lambda (key _) (not (.call Table .key? b key))) a))))
  ;; Membership equality does not require a backend-specific comparator/equality.
  .=?: (lambda (a b) (with-set-tables @ a b
    (lambda () (and (subset-set-tables? Table a b) (subset-set-tables? Table b a))))) ;; : Bool <- @ @
  ;; Boolean membership focus uses the existing value-before-state Lens law.
  ;; Type refusal and backend failure retain the original persistent source.
  .lens: (lambda (e) (set-membership-lens @ e)))


;; A private immutable image retains the grouped owners and every delta origin.
(defstruct %set-image (owner indexed target sources versions) final: #t)

;; Many-to-one Set image. Stable, pure projection respects declared key equality;
;; explicit origins invalidate both reads and updates. Grouped indexes own all
;; deduplication/retraction. Only complete source/target roots face refinements;
;; private owner buckets use structural key spaces, never business refinements.
;; Explicit multiple? accepts a finite list, including empty/duplicate outputs;
;; a list-valued single key remains unambiguous in the default cardinality.
(def (set-image source target transform (origins []) multiple?: (multiple? #f))
  (using ((transform :~ procedure?) (origins :~ list?) (multiple? :~ boolean?))
    (with-set-inputs source [] (lambda ()
      (with-set-inputs target [] (lambda ()
        (def primary (table-key-table (.@ source Table) Unit))
        (def groups (table-key-table (.@ target Table) primary))
        (def touched (table-key-table (.@ target Table) Unit))
        ;; Share cardinality and recognition between cold index preparation and
        ;; warm touched-key discovery. Admit leaves without cooking Functions.
        (def (image-keys key)
          (def output (transform key))
          (def keys (if multiple? output (list output)))
          (using (keys :~ list?)
            (for-each (lambda (key)
              (unless (element? (.@ target Elt) key)
                (raise-type-error (.@ target Elt) key 'set-image))) keys)
            keys))
        (def indexes (table-indexes primary
          (list (.o name: 'image table: groups unique?: #f multiple?: #t
            project: (lambda (key _row) (image-keys key))))))
        (def sources (delete-duplicates/hash
          (append (list source target indexes) origins (.@ indexes .sources)
            (if (.has? source .sources) (.@ source .sources) [])
            (if (.has? target .sources) (.@ target .sources) [])
            (table-sources (.@ source Table)) (table-sources (.@ target Table))
            (table-sources touched) (list (.@ source Elt) (.@ target Elt)))
          table: (make-hash-table-eq) from-end?: #t))
        (def versions (map object-revision sources))
        (def owner (list source target transform))
        ;; Keep all inherited metadata live throughout callbacks and delivery.
        (def (guard dependencies action)
          (with-table-sources dependencies (lambda ()
            (unless (equal? versions (map object-revision sources)) (error "stale set image"))
            (action))))
        ;; Reject foreign snapshots and changed historical delta origins first.
        (def (observe state action)
          (unless (and (%set-image? state) (eq? owner (%set-image-owner state)))
            (error "incompatible set image"))
          (guard (%set-image-sources state) (lambda ()
            (unless (equal? (%set-image-versions state)
                           (map object-revision (%set-image-sources state)))
              (error "stale set image state"))
            (action))))
        ;; Construct the complete image once from the existing grouped index.
        (def (initialize input)
          (guard sources (lambda ()
            (require-set source input)
            (def indexed (.call indexes .wrap input))
            (def keys (.call indexes .index-fold indexed 'image
              (lambda (key _bucket keys) (cons key keys)) []))
            (def output (.call target .<-list (reverse keys)))
            (require-set target output)
            (make-%set-image owner indexed output sources versions))))
        ;; Admit all source expectations before projecting. Touched target keys
        ;; are coalesced by backend equality; bucket nonemptiness decides one
        ;; ordinary target edit. No target snapshot diff or full scan is needed.
        ;; The optional continuation receives the exact installed target delta.
        (def (update state delta (receive (lambda (next _delta) next)))
          (using (receive :~ procedure?)
            (unless (table-delta? delta) (error "table delta required"))
            (observe state (lambda ()
              (def dependencies (delete-duplicates/hash
                (append (%set-image-sources state) (table-delta-sources delta))
                table: (make-hash-table-eq) from-end?: #t))
              (guard dependencies (lambda ()
                (def before (.call indexes .unwrap (%set-image-indexed state)))
                (def indexed (.call indexes .apply-delta (%set-image-indexed state) delta
                  (cut require-set source <>)))
                (def after (.call indexes .unwrap indexed))
                (def seen (.@ touched .empty))
                (def keys (with-list-builder (emit)
                  (for-each (lambda (change)
                    (def key (table-change-key change))
                    ;; Deleted/inserted owners retain the same stable finite
                    ;; image. The backend registry coalesces shared/duplicate keys.
                    (when (or (.call primary .key? before key) (.call primary .key? after key))
                      (for-each (lambda (output)
                        (unless (.call touched .key? seen output)
                          (set! seen (.call touched .acons output (void) seen))
                          (emit output))) (image-keys key)))) (table-delta-changes delta))))
                (def edits (with-list-builder (emit)
                  (for-each (lambda (key)
                    (def old (.call (.@ target Table) .ref/opt (%set-image-target state) key))
                    (def present? (some? (.call indexes .index-ref/opt indexed 'image key)))
                    (unless (eq? (some? old) present?)
                      (emit (make-table-change key old (and present? (some (void))))))) keys)))
                (def output-delta (make-table-delta (.@ (.@ target Table) Key) Unit
                  dependencies (map object-revision dependencies) edits))
                (def output (.call (.@ target Table) .apply-delta (%set-image-target state) output-delta))
                (require-set target output)
                (def next (make-%set-image owner indexed output dependencies (map object-revision dependencies)))
                (receive next output-delta)))))))
        (.cc Wrapper. Domain: source Value: target .sources: sources
          .ap: initialize
          .unap: (lambda (state) (observe state
            (lambda () (.call indexes .unwrap (%set-image-indexed state)))))
          .get: (lambda (state) (observe state (lambda () (%set-image-target state))))
          .apply-delta: update)))))))


;; One immutable binary view owns both admitted source roots and their result.
(defstruct %set-combination (owner sources versions inputs target) final: #t)

;; Incremental binary Set algebra across explicit compatible key spaces. Standard
;; Pair/Wrapper carries the two snapshots; ordinary deltas and the target backend
;; supply all conflict, persistence and installation behavior. Shared Key identity
;; and coherent backend logical equality are premises, not inferred comparers.
(def (set-combination left right target operation)
  (def choose (set-operation operation))
  (with-set-inputs left [] (lambda ()
    (with-set-inputs right [] (lambda ()
      (with-set-inputs target [] (lambda ()
        (def lt (.@ left Table)) (def rt (.@ right Table)) (def tt (.@ target Table))
        (unless (and (eq? (.@ lt Key) (.@ rt Key)) (eq? (.@ lt Key) (.@ tt Key)))
          (error "incompatible set combination keys"))
        (def domain (Pair left right))
        (def touched (table-key-table tt Unit))
        (def sources (delete-duplicates/hash
          (append (list domain) (table-sources touched)
            (append-map (lambda (descriptor)
              (append (list descriptor (.@ descriptor Elt))
                (table-sources (.@ descriptor Table))
                (if (.has? descriptor .sources) (.@ descriptor .sources) [])))
              (list left right target))) table: (make-hash-table-eq) from-end?: #t))
        (def versions (map object-revision sources))
        (def owner (list left right target operation))
        ;; All callbacks see protected live metadata, including inherited origins.
        (def (guard dependencies action)
          (with-table-sources dependencies (lambda ()
            (unless (equal? versions (map object-revision sources))
              (error "stale set combination"))
            (action))))
        ;; Private provenance and historical stamps are checked before any work.
        (def (observe state action)
          (unless (and (%set-combination? state) (eq? owner (%set-combination-owner state)))
            (error "incompatible set combination state"))
          (guard (%set-combination-sources state) (lambda ()
            (unless (equal? (%set-combination-versions state)
                           (map object-revision (%set-combination-sources state)))
              (error "stale set combination state"))
            (action))))
        ;; Copy backend-owned Option shells before another lookup can reuse one.
        ;; Unit and Function keys are admitted already, never normalized again.
        (def (selected a b key)
          (choose (map/option identity (.call lt .ref/opt a key))
                  (map/option identity (.call rt .ref/opt b key))))
        ;; The only ownership object is allocated after every complete root passes.
        (def (snapshot inputs output dependencies)
          (make-%set-combination owner dependencies (map object-revision dependencies) inputs output))
        ;; Reuse the target key-space registry to deduplicate candidates by its
        ;; declared equality. Only final selected elements enter a refined target.
        (def (initialize input)
          (using (input :~ pair?)
            (def inputs (cons (car input) (cdr input)))
            (guard sources (lambda ()
              (require-set left (car inputs)) (require-set right (cdr inputs))
              (def keys (.@ touched .empty))
              ;; This backend fold inserts keys only; Unit leaves retain identity.
              (def (collect key _row) (set! keys (.call touched .acons key (void) keys)))
              (.call lt .for-each collect (car inputs))
              (.call rt .for-each collect (cdr inputs))
              (def rows (.call touched .foldr (lambda (key _row rows)
                (if (selected (car inputs) (cdr inputs) key)
                  (cons (cons key (void)) rows) rows)) [] keys))
              (snapshot inputs (require-set target (.call tt .<-list rows)) sources)))))
        ;; Both ordered source installations finish before result preparation.
        ;; Coalescing the two edit streams bounds target membership work by their
        ;; distinct keys; unchanged result memberships emit no target writes.
        (def (update state delta-left delta-right (receive (lambda (next _delta) next)))
          (using (receive :~ procedure?)
            (unless (and (table-delta? delta-left) (table-delta? delta-right))
              (error "two table deltas required"))
            (observe state (lambda ()
              (def dependencies (delete-duplicates/hash
                (append (%set-combination-sources state) (table-delta-sources delta-left)
                  (table-delta-sources delta-right)) table: (make-hash-table-eq) from-end?: #t))
              (guard dependencies (lambda ()
                (require-table-delta lt delta-left) (require-table-delta rt delta-right)
                (def input (%set-combination-inputs state))
                (def a (.call lt .apply-delta (car input) delta-left))
                (def b (.call rt .apply-delta (cdr input) delta-right))
                (require-set left a) (require-set right b)
                (def keys (.@ touched .empty))
                (def edits (with-list-builder (emit)
                  (for-each (lambda (change)
                    (def key (table-change-key change))
                    (unless (.call touched .key? keys key)
                      (set! keys (.call touched .acons key (void) keys))
                      (let ((before (map/option identity (.call tt .ref/opt (%set-combination-target state) key)))
                            (after (selected a b key)))
                        (unless (table-option=? before after)
                          (emit (make-table-change key before after))))))
                    (append (table-delta-changes delta-left) (table-delta-changes delta-right)))))
                (def delta (make-table-delta (.@ tt Key) Unit dependencies
                  (map object-revision dependencies) edits))
                (def output (require-set target (.call tt .apply-delta (%set-combination-target state) delta)))
                (receive (snapshot (cons a b) output dependencies) delta)))))))
        (.cc Wrapper. Domain: domain Value: target .sources: sources
          .ap: initialize
          .unap: (lambda (state) (observe state (lambda ()
            (cons (car (%set-combination-inputs state)) (cdr (%set-combination-inputs state))))))
          .get: (lambda (state) (observe state (lambda () (%set-combination-target state))))
          .apply-deltas: update))))))))
