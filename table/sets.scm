;;; Finite set algebra is an incremental layer over existing Unit-valued tables.

;; Capture the declared origin spine before Table/Elt getters can recycle it.
;; Existing source protection owns metadata preparation and the entire callback;
;; retained consumers receive this same family, including an independent Elt.
;; Each entry retains its existing non-Unit refusal rather than catching errors.
(def (with-set-sources descriptor receive (unit-failure "set algebra requires Unit values"))
  (with-table-sources (list descriptor) (lambda ()
    (def origins (if (.has? descriptor .sources) (.@ descriptor .sources) []))
    (using (origins :~ list?)
      (def captured (map identity origins))
      (with-table-sources (cons descriptor captured) (lambda ()
        (def table (.@ descriptor Table))
        (def backing (table-sources table))
        (with-table-sources backing (lambda ()
          (unless (eq? (.@ table Value) Unit) (error unit-failure))
          (def sources (append (list descriptor (.@ descriptor Elt)) captured backing))
          (with-table-sources sources (lambda ()
            (receive sources)))))))))))

;; Admit every input before callbacks or shortcuts, using the one source family.
;; Recognition does not normalize Function keys; original callback causes survive.
(def (with-set-inputs descriptor inputs action)
  (with-set-sources descriptor (lambda (_sources)
    (for-each (cut require-set descriptor <>) inputs)
    (action))))

;; A set refinement cannot weaken the backing carrier/child admission. Recognition
;; retains admitted Function keys and does not reconstruct or normalize them.
;; The shared dynamic admission guard rejects direct or mutual receiver/root
;; reentry before repeating a recognizer, and restores its scope on every exit.
(def (require-set descriptor root)
  (admit-table-observation descriptor root
    (lambda (descriptor root)
      (require-set-elements descriptor root)
      (require-table descriptor root))))

;; The backing carrier and every declared element are independent obligations.
;; Matching descriptor identities reuse backing recognition without another scan.
(def (require-set-elements descriptor root)
  (def table (.@ descriptor Table))
  (require-table table root)
  (def elt (.@ descriptor Elt))
  (unless (eq? elt (.@ table Key))
    (when (table-entry-match table (lambda (key _) (element? elt key)) root #f #f)
      (raise-type-error descriptor root 'set-elements)))
  root)

;; Default Type recognition includes independently overridden Elt contracts.
;; Typed refusal is false; callback/backend errors retain their original cause.
(def (set-element? descriptor root)
  (try (require-set-elements descriptor root) #t (catch (TypeError? _) #f)))

;; Checked element requests must satisfy Elt AND the backing key domain before
;; backend work. Recognition preserves existing Function handles, never cooks them.
(def (require-set-element descriptor element)
  (def elt (.@ descriptor Elt))
  (require-table elt element)
  (unless (eq? elt (.@ (.@ descriptor Table) Key))
    (require-table-key (.@ descriptor Table) element))
  element)

;; Normalize through the backing protocol, then an independent Elt if present.
;; Existing binding validation owns ordered child cooking and collision refusal;
;; a raw key space stages uniqueness, and only the complete business root is built.
;; No-change Elt validation retains the backing result without a bulk builder.
;; Reconstruction recognizes backing membership; it must not cook the keys again.
(def (validate-set descriptor input)
  (with-set-inputs descriptor [] (lambda ()
    (def table (.@ descriptor Table))
    (def root (validate table input))
    (def elt (.@ descriptor Elt))
    (require-set descriptor
      (if (eq? elt (.@ table Key)) root
        (validate-bindings (cut validate elt <>) identity root (capture-table-bindings (.call table .list/key root))
          (lambda (rows)
            (def keys (table-key-table table Unit))
            (with-table-sources (table-sources keys) (lambda ()
              (rebuild-bindings descriptor root rows (lambda () (.@ keys .empty))
                (lambda (seen key)
                  (require-table-key table key) (.call keys .key? seen key))
                (.@ keys .acons))
              (require-table table (.call table .<-list rows)))))))))))

;; Own the finite element request, recognize every occurrence before backend
;; coalescing, then reuse the complete bulk constructor and shared Set admission.
;; Pair-valued elements remain opaque leaves rather than binding shells.
(def (construct-set descriptor elements)
  (using (elements :~ list?)
    (def captured (map identity elements))
    (with-set-inputs descriptor [] (lambda ()
      (def elt (.@ descriptor Elt))
      ;; The existing Table constructor already admits every original Key.
      (unless (eq? elt (.@ (.@ descriptor Table) Key))
        (for-each (cut require-table elt <>) captured))
      (require-set descriptor
        (.call (.@ descriptor Table) .<-list
          (map (lambda (element) (cons element (void))) captured)))))))

 ;; Admit the complete Set once before issuing its backing stream. Each delayed
;; pull, including EOF, checks the captured Set/element/backend origins without
;; rescanning a persistent root or retaining protection across caller suspension.
(def (iterate-set descriptor input from)
  (with-set-sources descriptor (lambda (sources)
    (require-set descriptor input)
    (when (and from (not (eq? (.@ descriptor Elt) (.@ (.@ descriptor Table) Key))))
      (require-table (.@ descriptor Elt) from))
    (def table (.@ descriptor Table))
    (def versions (map object-revision sources))
    ;; Reuse the standard mapped Iterator guard; stale refusal precedes next!.
    (def (guard action)
      (with-table-sources sources action sources versions "stale set iterator"))
    (guard (lambda ()
      (iterator-map car (if (not from) (.call table .iter<- input)
        (.call table .iter<- input from)) guard))))))

;; Both operands, including identical/empty roots, precede relation/merge work.
(def (with-set-tables descriptor left right action)
  (with-set-inputs descriptor (list left right) action))

;; Predicate observations retain the Set refinement and reuse Table traversal.
;; Only search observations project Unit-valued bindings to optional elements;
;; false elements remain present shells and Function keys retain their identity.
(def (query-set descriptor method predicate input entry?)
  (using (predicate :~ procedure?)
    (with-set-inputs descriptor (list input) (lambda ()
      (def result ((.ref (.@ descriptor Table) method) (lambda (elt _) (predicate elt)) input))
      (if entry? (map/option car result) result)))))

;; One admitted traversal serves folds and visits in either backend direction.
;; Check the caller callback even for empty roots; discard visit results exactly
;; as for-each requires. No element is normalized or wrapped during observation.
(def (fold-set descriptor method f seed input (visit? #f))
  (using (f :~ procedure?)
    (with-set-inputs descriptor (list input) (lambda ()
      ((.ref (.@ descriptor Table) method)
        (if visit? (lambda (elt _value _seed) (f elt) (void))
          (lambda (elt _value acc) (f elt acc))) seed input)))))

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
              (unless (eq? type descriptor) (require-set-element descriptor value))) inputs args)
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
  (with-set-sources descriptor (lambda (sources)
    (def table (.@ descriptor Table))
    (def versions (map object-revision sources))
    ;; Both accessors guard original Set/Elt/backing origins before recognition.
    (def (observe source action)
      (with-table-sources sources (lambda ()
        (unless (equal? versions (map object-revision sources)) (error "stale set focus"))
        (with-set-inputs descriptor (list source) (lambda ()
          (require-set-element descriptor key)
          (action))))))
    (lens-of-get-set
      (lambda (source) (observe source (lambda () (.call table .key? source key))))
      (lambda (present? source)
        (using (present? :~ boolean?)
          (observe source (lambda ()
            (require-set descriptor
              (if present? (.call table .acons key (void) source) (.call table .remove source key)))))))))))

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
      (unless (eq? (.@ descriptor Elt) (.@ table Key))
        (require-table (.@ descriptor Elt) pivot))
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

;; Keep Set-specific input/result refinements while the backing table supplies
;; the complete division algorithm, including zero/singleton representation.
(def (divide-set descriptor input)
  (with-set-inputs descriptor (list input) (lambda ()
    (def roots (.call (.@ descriptor Table) .divide/list input))
    (for-each (cut require-set descriptor <>) roots)
    roots)))

;; Retain Set admission around the backing import without listing its seed.
;; The standard iterator mapper supplies Unit entries lazily inside that scope.
(def (set-from-iter descriptor sequence seeds)
  (with-set-inputs descriptor seeds (lambda ()
    (def elt (.@ descriptor Elt))
    (def independent? (not (eq? elt (.@ (.@ descriptor Table) Key))))
    (require-set descriptor (apply (.@ (.@ descriptor Table) .<-iter)
      (iterator-map (lambda (element)
        (when independent? (require-table elt element)) (cons element (void))) sequence) seeds)))))

(define-type (Set<-Table. @ Type. Table sexp)
  ;; Backing values are Unit. Elt defaults to Key; an independent Elt constrains
  ;; the same keys in addition to their backing domain. Styles require identity.
  Elt: (.@ Table Key) ;; : Type
  ;; Normalize backing keys, then independent elements, and recognize the result.
  .validate: (cut validate-set @ <>) ;; raw input retains recursively checked elements
  .element?: (cut set-element? @ <>) ;; backing and Elt recognition without normalization
  ;; Empty is a partial constructor when the declared set excludes that root.
  (.empty (.call methods .empty)) ;; : @
  ;; Set refinement precedes the backing predicate, even for an empty carrier.
  .empty?: (lambda (root) (with-set-inputs @ (list root)
    (lambda () (table-empty-key? Table root)))) ;; : Bool <- @
  ;; Membership retains backend key equivalence, after complete Set admission.
  .elt?: (lambda (root elt) (with-set-inputs @ (list root)
    (lambda () (require-set-element @ elt) (.call Table .key? root elt)))) ;; : Bool <- @ Elt
  ;; One derived boundary admits the family; the backend delegates stay simple.
  methods: (set-methods @
    (.o .empty: (lambda () (.@ Table .empty))
        .cons: (cut .call Table .acons <> (void) <>)
        .singleton: (lambda (elt) (.call Table .singleton elt (void)))
        (.remove (.@ Table .remove)))
    (.o (.empty (.cc Function. inputs: [] outputs: [@]))
        (.cons (.cc Function. inputs: [Elt @] outputs: [@]))
        (.singleton (.cc Function. inputs: [Elt] outputs: [@]))
        (.remove (.cc Function. inputs: [@ Elt] outputs: [@]))))
  .cons: (.@ methods .cons) ;; : @ <- Elt @
  .singleton: (.@ methods .singleton) ;; : @ <- Elt
  .remove: (.@ methods .remove) ;; : @ <- @ Elt
  ;; Nonempty parts retain the Set refinement without mapping their Unit leaves.
  .divide: (lambda (input) (table-division-values (divide-set @ input)))
  .divide/list: (cut divide-set @ <>)
  ;; Traversal directions share one boundary and the backend's original fold.
  .for-each: (lambda (f t) (fold-set @ '.foldl f (void) t #t))
  .for-each/reverse: (lambda (f t) (fold-set @ '.foldr f (void) t #t))
  .foldl: (lambda (f a t) (fold-set @ '.foldl f a t))
  .foldr: (lambda (f a t) (fold-set @ '.foldr f a t))
  .every: (lambda (f t) (query-set @ '.every f t #f)) ;; : Bool <- (Bool <- Elt) @
  .any: (lambda (f t) (query-set @ '.any f t #f)) ;; : Bool <- (Bool <- Elt) @
  ;; Checked selection protects custom set refinements as well as backing Types.
  .filter: (lambda (f t) (select-set @ f t #f)) ;; : @ <- (Bool <- Elt) @
  ;; The shared set boundary delegates prefix algorithms to the backing table.
  .take: (lambda (count input) (build-set @ (list input) '.take count input))
  .drop: (lambda (count input) (build-set @ (list input) '.drop count input))
  ;; Both branches satisfy the same set descriptor before either escapes.
  .partition: (lambda (f t) (select-set @ f t #t)) ;; : @ @ <- (Bool <- Elt) @
  ;; Preserve specialized backend observations instead of replacing them with scans.
  .count: (lambda (root) (with-set-inputs @ (list root)
    (lambda () (.call Table .count root)))) ;; : Nat <- @
  .list<-: (lambda (root) (with-set-inputs @ (list root)
    (lambda () (map car (.call Table .list<- root))))) ;; : (List Elt) <- @
  ;; A complete family may be valid while every singleton is forbidden. Reuse the
  ;; table's bulk constructor once, without exposing intermediate roots.
  .<-list: (cut construct-set @ <>) ;; : @ <- (List Elt)
  .sexp<-: (lambda (x) `(.call ,sexp .<-list (@list ,@(map (.@ Elt sexp<-) (.list<- x))))) ;; : Sexp <- @
  ;; Endpoint observations retain Set refinement and the backing traversal order.
  ;; Option shells distinguish an empty set from a selected false element.
  .min-elt: (lambda (t) (option-ref (.min-elt/opt t))) ;; : Elt <- @
  .min-elt/opt: (cut query-set @ '.find-first/opt true <> #t) ;; : (Option Elt) <- @
  .max-elt: (lambda (t) (option-ref (.max-elt/opt t))) ;; : Elt <- @
  .max-elt/opt: (cut query-set @ '.find-last/opt true <> #t) ;; : (Option Elt) <- @
  .choose: .min-elt ;; : Elt <- @
  .choose/opt: .min-elt/opt ;; : (Option Elt) <- @
  ;; Element-level extraction shares table choice, conflicts and complete admission.
  .decons/opt: (lambda (input) (decons-set @ input #f))
  .decons: (lambda (input) (decons-set @ input #t))
  ;; Both set roots pass complete admission before the presence observation escapes.
  .split: (lambda (elt t) (split-set @ elt t)) ;; : @ Bool @ <- Elt @
  .find-first/opt: (lambda (f t) (query-set @ '.find-first/opt f t #t)) ;; : (Option Elt) <- (Bool <- Elt) @
  .find-first: (lambda (f t) (option-ref (.find-first/opt f t))) ;; : Elt <- (Bool <- Elt) @
  .find-last/opt: (lambda (f t) (query-set @ '.find-last/opt f t #t)) ;; : (Option Elt) <- (Bool <- Elt) @
  .find-last: (lambda (f t) (option-ref (.find-last/opt f t))) ;; : Elt <- (Bool <- Elt) @
  ;; Complete admission precedes issuance; the captured guard covers every pull.
  .iter<-: (lambda (t from: (from #f)) (iterate-set @ t from))
  ;; The backing stream importer owns coalescing and one final installation.
  ;; Mapping elements to Unit entries does not scan/reconstruct the seed snapshot.
  .<-iter: (case-lambda
    ((s) (set-from-iter @ s []))
    ((s t) (set-from-iter @ s (list t)))) ;; : @ <- (Iterator Elt) ?@
  .List: (List Elt)
  ;; Element codecs share the same guarded IO boundary as Table binding codecs.
  .json<-: (cut collection-codec @ #t '.json<- <>) ;; : Json <- @
  .<-json: (cut collection-codec @ #t '.<-json <>) ;; : @ <- Json
  .bytes<-: (cut collection-codec @ #t '.bytes<- <>) ;; : Bytes <- @
  .<-bytes: (cut collection-codec @ #t '.<-bytes <>) ;; : @ <- Bytes
  .marshal: (cut collection-codec @ #t '.marshal <> <>)
  .unmarshal: (cut collection-codec @ #t '.unmarshal <>)
  ;; TODO: for union, inter, diff, compare, equal, subset,
  ;; optimize for full subtables, by caching count in wrapper?
  .union: (lambda (a b) (merge-set-tables @ (set-operation 'union) a b)) ;; : @ <- @ @
  .inter: (lambda (a b) (merge-set-tables @ (set-operation 'inter) a b)) ;; : @ <- @ @
  .diff: (lambda (a b) (merge-set-tables @ (set-operation 'diff) a b)) ;; : @ <- @ @
  ;; A lexicographic comparison requires the backend's explicit key-order capability.
  .compare: (lambda (a b) (with-set-tables @ a b (lambda ()
    (unless (.has? Table Comparer .compare) (error "unsupported set comparison"))
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
    ;; Snapshot explicit origins before any descriptor getter is forced.
    (set! origins (map identity origins))
    (with-table-sources origins (lambda () (with-set-sources source (lambda (source-sources)
      (with-set-sources target (lambda (target-sources)
        (def primary (table-key-table (.@ source Table) Unit))
        (def groups (table-key-table (.@ target Table) primary))
        (def touched (table-key-table (.@ target Table) Unit))
        ;; Share cardinality and recognition between cold index preparation and
        ;; warm touched-key discovery. Admit leaves without cooking Functions.
        (def (image-keys key)
          (def output (transform key))
          (def keys (if multiple? output (list output)))
          (using (keys :~ list?)
            ;; Own a borrowed finite result before Elt predicates can reuse it.
            ;; Single-output keys already have a private list; leaves stay shared.
            (when multiple? (set! keys (map identity keys)))
            (for-each (lambda (key)
              (unless (element? (.@ target Elt) key)
                (raise-type-error (.@ target Elt) key 'set-image))) keys)
            keys))
        (def indexes (table-indexes primary
          (list (.o name: 'image table: groups unique?: #f multiple?: #t
            project: (lambda (key _row) (image-keys key))))))
        (def sources (delete-duplicates/hash
          (append (list source target indexes) origins (.@ indexes .sources)
            source-sources target-sources (table-sources touched))
          table: (make-hash-table-eq) from-end?: #t))
        (def versions (map object-revision sources))
        (def owner (list source target transform))
        ;; Keep all inherited metadata live throughout callbacks and delivery.
        (def (guard dependencies action)
          (with-table-sources dependencies action sources versions "stale set image"))
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
                    (def old (map/option identity (.call (.@ target Table) .ref/opt (%set-image-target state) key)))
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
          .apply-delta: update)))))))))


;; Incremental Set operations are Unit-valued instances of table combination.
;; Keep Set/Elt refinements and their origin scopes, with no second cache engine.
(def (set-combination left right target operation)
  (def choose (set-operation operation))
  (with-set-sources left (lambda (left-sources)
    (with-set-sources right (lambda (right-sources)
      (with-set-sources target (lambda (target-sources)
        (def lt (.@ left Table)) (def rt (.@ right Table)) (def tt (.@ target Table))
        (unless (and (eq? (.@ lt Key) (.@ rt Key)) (eq? (.@ lt Key) (.@ tt Key)))
          (error "incompatible set combination keys"))
        (make-table-combination left right target lt rt tt (lambda (_key a b) (choose a b)) require-set
          (append left-sources right-sources target-sources) "set combination"))))))))
