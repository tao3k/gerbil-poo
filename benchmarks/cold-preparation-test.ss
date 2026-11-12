;;; Optional native study; deliberately absent from the default development build.
;;; Compile with the standard compiler and execute through Just test-file.
(export root-linearization-test root-protocol-test leaf-demand-test shape-construction-test scalar-layout-paired-test slot-assembly-test constructor-call-test)
(import :std/test :std/iter :clan/poo/object (only-in :std/error Error?)
        (only-in :gerbil/runtime/c3 c4-linearize*)
        (only-in :gerbil/runtime/loader list-modules)
        (only-in :std/values first-value)
        (only-in :clan/poo/slot-layout make-slot-layout slot-layout-shape slot-layout-index slot-layout-set!)
        (only-in :clan/poo/object-state object-state-revision)
        (only-in :gerbil/runtime/gambit string->uninterned-symbol)
        (prefix-in (only-in :gerbil/runtime/mop object-class make-class-slot-accessor class-slot-offset slot-ref) assembly.)
        (only-in :gerbil/runtime/interface &interface-descriptor-type interface-instance-object)
        (only-in :gerbil/runtime/hash HashTable::interface)
        (only-in :gerbil/runtime/table raw-table-for-each &raw-table-free &raw-table-table symbolic-hash)
        (only-in :clan/poo/read-route symbolic-write-route-current?)
        :clan/poo/prototype-map
        (only-in :std/list/list map-in-order)
        (only-in :std/hash/misc hash-ensure-modify!)
        (only-in :clan/poo/benchmarks/closure-measure measure qualified-metrics)
        (only-in :gerbil/runtime/gambit default-random-source))
(extern namespace: #f random-source-state-ref random-source-state-set!)
(extern namespace: clan/poo/slot-layout shape-for-names intern-ordered-shape make-layout
        ordinary-shape-for-names same-shape-names? shape-names scalar-shape-routes-current?)
(extern namespace: clan/poo/object
  compile-slot-specs slot-spec-discards-super? prepare-declaration-specifications)

(def (constructor-from-state state constructor)
  (def saved (random-source-state-ref default-random-source))
  (dynamic-wind
    (lambda () (random-source-state-set! default-random-source state))
    (lambda ()
      (let (table (constructor))
        (vector table (random-source-state-ref default-random-source))))
    (lambda () (random-source-state-set! default-random-source saved))))

(def constructor-call-test
  (test-suite "closed native constructor keyword binding"
    (test-case "same native backend and default RNG state, matched ABBA and controls"
      (for (kind '(symbolic identity))
        (def (helper)
          (if (eq? kind 'symbolic) (make-hash-table-symbolic) (make-hash-table-eq)))
        (def (literal)
          (if (eq? kind 'symbolic)
            (make-hash-table test: eq? hash: symbolic-hash)
            (make-hash-table test: eq?)))
        ;; Warm native adapters only; no business object or slot is constructed.
        (helper) (literal)
        (def state (random-source-state-ref default-random-source))
        (def a (constructor-from-state state helper))
        (def b (constructor-from-state state literal))
        (check-equal? (vector-ref a 1) (vector-ref b 1))
        (check-eq? (assembly.object-class (interface-instance-object (vector-ref a 0)))
                  (assembly.object-class (interface-instance-object (vector-ref b 0))))
        (for (field '(ref set! for-each))
          (check-eq? (assembly.slot-ref (vector-ref a 0) field)
                    (assembly.slot-ref (vector-ref b 0) field)))
        (when (eq? kind 'symbolic)
          (check-equal? (assembly.slot-ref (interface-instance-object (vector-ref a 0)) 'seed)
                        (assembly.slot-ref (interface-instance-object (vector-ref b 0)) 'seed)))
        (for* ((schedule '((paired helper literal literal helper literal helper helper literal)
                          (aa helper helper) (bb literal literal)))
               (side (cdr schedule)))
          (defvalues (last clocks)
            (measure (lambda ()
              ;; A 16K pilot's work was shorter than one native collection.
              ;; Keep its evidence; span multiple collection quanta here.
              (for/fold (previous #f) (_ (in-range 65536))
                (let (table (if (eq? side 'helper) (helper) (literal)))
                  (when (eq? table previous) (error "constructor reused a table"))
                  table))) 1))
          (check-equal? (hash-length last) 0)
          (hash-put! last 'value #f)
          (check-eq? (hash-ref last 'value 'missing) #f)
          (check-eq? (hash-ref last 'absent 'missing) 'missing)
          (displayln (list 'CONSTRUCTOR-CALL kind (car schedule) side 'operations 65536
            (qualified-metrics clocks) 'raw-allocation (vector-ref clocks 4))))))))

;; Controlled native prototype only, not production route admission. A final
;; implementation would need a total guard for malformed/changed field maps,
;; independently matched callback controls and complete .get qualification.
(def assembly-stable?
  (let* ((sample (make-hash-table-symbolic seed: 0))
         (wrapper (assembly.object-class sample))
         (foreach-offset (assembly.class-slot-offset wrapper 'for-each))
         (foreach-field (assembly.make-class-slot-accessor wrapper 'for-each)))
    (lambda (table)
      (and (eq? (&interface-descriptor-type HashTable::interface) wrapper)
           (symbolic-write-route-current? table)
           (eqv? (assembly.class-slot-offset wrapper 'for-each) foreach-offset)
           (eq? (foreach-field table) raw-table-for-each)
           (let (backend (interface-instance-object table))
             ;; Gerbil checks this threshold BEFORE looking up an existing key.
             (>= (&raw-table-free backend)
                 (quotient (vector-length (&raw-table-table backend)) 4)))))))

;; Frozen ordinary assembly with just the second native enumeration fused.
;; The first snapshot remains private; its rows are rewritten after each
;; successful compile/write. All thunks are frozen BEFORE the original hook loop.
(def (assemble-slot-funs! self fused?)
  (def h (make-hash-table test: eq? hash: symbolic-hash))
  (def prepared (map-in-order (lambda (super) (cons super (prepare-declaration-specifications super)))
                             (reverse (object-%precedence-list self))))
  (def sources (map-in-order (lambda (entry)
    (cons (car entry) (and (cdr entry) ((cdr entry))))) prepared))
  (def (default! slot value) (hash-put! h slot (list ($constant-slot-spec value))))
  (def (contribution! slot spec)
    (def discards? (slot-spec-discards-super? spec))
    (unless (or discards? ($computed-slot-spec? spec)) (apply-slot-spec self spec #f))
    (if discards? (hash-put! h slot (list spec))
      (hash-ensure-modify! h slot (lambda () []) (cut cons spec <>))))
  (for (([super . declarations] sources))
    (when declarations (prototype-map-for-each (cdr declarations) default!))
    (prototype-map-for-each (object-%defaults super) default!))
  (for (([super . declarations] sources))
    (when declarations (prototype-map-for-each (car declarations) contribution!))
    (prototype-map-for-each (object-%slots super) contribution!))
  (def entries
    (if fused?
      (begin
        (unless (assembly-stable? h) (error "experimental assembly interval not applicable"))
        (let (entries (hash->list h))
          (for (entry entries)
            (def compiled (compile-slot-specs self (car entry) (cdr entry)))
            (hash-put! h (car entry) compiled)
            (set-cdr! entry compiled))
          entries))
      (begin
        (for (([slot . specs] (hash->list h)))
          (hash-put! h slot (compile-slot-specs self slot specs)))
        (hash->list h))))
  (def closed? (and (pair? entries) (pair? (cdr entries)) (symbolic-write-route-current? h)
                    (not (object-protocol self))))
  (for (([slot . standard] entries))
    (def compiled (if (or closed? (bootstrap-anchor self slot)) standard
      (invoke-object-hook self 'compute-slot (lambda () standard) slot)))
    (unless (procedure? compiled) (error "compute-slot must return a thunk" slot))
    (hash-put! h slot compiled))
  (set! (object-%slot-funs self) h))

(def slot-assembly-test
  (test-suite "experimental ordered slot catalog fusion"
    (test-case "an existing-key replacement can rehash and change hook order"
      (def keys (for/collect (i (in-range 17))
        (string->symbol (string-append "rehash-field-" (number->string i)))))
      (def witness
        (ormap (lambda (seed)
          (def h (make-hash-table-symbolic seed: seed))
          (for (key keys) (hash-put! h key key))
          (check-eq? (assembly-stable? h) #f)
          (def before (hash->list h))
          (for (([key . value] before)) (hash-put! h key value))
          (def after (hash->list h))
          (and (not (equal? (map car before) (map car after)))
            (list seed before after))) (iota 16)))
      (check (pair? witness) ? values)
      (def owner (make-object slots:
        (map (lambda (key) (cons key ($constant-slot-spec key))) keys)))
      (compute-precedence-list! owner)
      (check-exception (assemble-slot-funs! owner #t) Error?)
      (compute-slot-funs! owner)
      (check-equal? (hash-length (object-%slot-funs owner)) 17)
      (for (key keys) (check-eq? ((hash-ref (object-%slot-funs owner) key)) key)))
    (test-case "runtime oracle, matched prototype ABBA, and same-side controls"
      (for (width '(1 8 64))
        (def keys (for/collect (i (in-range width))
          (string->symbol (string-append "assembly-field-" (number->string i)))))
        (def payload (list 'assembly width))
        (def slots (prototype-map
          (map (lambda (key) (cons key ($constant-slot-spec payload))) keys) policy: 'compact))
        (def count (quotient 4096 width))
        (for* ((schedule '((oracle runtime mirror mirror runtime)
                          (paired mirror fused fused mirror fused mirror mirror fused)
                          (aa mirror mirror) (bb fused fused)))
               (side (cdr schedule)))
          (defvalues (owners preparation)
            (measure (lambda ()
              (for/collect (_ (in-range count))
                (let (owner (make-object slots: slots))
                  (compute-precedence-list! owner)
                  owner))) 1))
          (defvalues (_ clocks)
            (measure (lambda ()
              (for (owner owners)
                (case side
                  ((runtime) (compute-slot-funs! owner))
                  ((mirror) (assemble-slot-funs! owner #f))
                  ((fused) (assemble-slot-funs! owner #t))))) 1))
          ;; Check every compiled value outside timing, not merely a checksum.
          ;; These are known constant fixtures, not business scope prewarming.
          (for (owner owners)
            (check-equal? (hash-length (object-%slot-funs owner)) width)
            (for (key keys)
              (check-eq? ((hash-ref (object-%slot-funs owner) key)) payload)))
          (defvalues (guard-result guard-clocks)
            (measure (lambda ()
              (for (owner owners)
                (unless (assembly-stable? (object-%slot-funs owner))
                  (error "compiled catalog lost the closed interval")))) 1))
          (displayln (list 'SLOT-ASSEMBLY (car schedule) side 'fields width 'owners count
            'preparation (qualified-metrics preparation)
            'assembly (qualified-metrics clocks) 'raw-allocation (vector-ref clocks 4)
            'guard-only (qualified-metrics guard-clocks))))))))

;; Preserve native counter endpoints when the signed allocation result is not
;; admissible. This observer runs after timing, without observing POO sources.
(def (counter-endpoints before after _elapsed)
  (displayln (list 'ALLOCATION-ENDPOINTS
    'before (vector (f64vector-ref before 6) (f64vector-ref before 7) (f64vector-ref before 9))
    'after (vector (f64vector-ref after 6) (f64vector-ref after 7) (f64vector-ref after 9)))))

;; Complete public precedence protocol, distinct from the pure C4 base-case
;; diagnostic below. Each cold window receives fresh runtime receiver state.
;; Warm windows use precisely those receivers; no business slot is demanded.
(def root-protocol-test
  (test-suite "complete root precedence protocol costs"
    (test-case "fresh roots and their cached metadata, preparation charged separately"
      (for (_ (in-range 4))
        (defvalues (owners preparation)
          (measure (lambda ()
            (for/collect (_ (in-range 4096)) (make-object))) 1))
        (for (phase '(cold warm))
          (defvalues (_ clocks)
            (measure (lambda ()
              (for (owner owners)
                (let (order (compute-precedence-list! owner))
                  (unless (and (pair? order) (eq? (car order) owner) (null? (cdr order)))
                    (error "root protocol changed precedence"))))) 1 #f counter-endpoints))
          (displayln (list 'ROOT-PROTOCOL phase 'operations 4096
            'preparation (qualified-metrics preparation)
            'precedence (qualified-metrics clocks) 'raw-allocation (vector-ref clocks 4))))))))

;; The same lexical constant leaf used by the cold Graph author's .code.
;; This is a first .get study, not the pure C4 or layout diagnostic.
(def leaf-demand-test
  (test-suite "complete lexical leaf demand costs"
    (test-case "construction first get and repeated get retain payload identity"
      ;; The native loader reports actual loaded artifacts, not a source guess.
      (displayln (list 'DEMAND-MODULES
        (assoc "clan/poo/object~0" (list-modules))
        (assoc "clan/poo/benchmarks/cold-preparation-test~0" (list-modules))))
      (for (_ (in-range 4))
        (def payloads (for/collect (i (in-range 4096)) (list i)))
        (defvalues (leaves construction)
          (measure (lambda ()
            (for/collect (payload payloads) (.o reads: payload))) 1))
        (for (phase '(cold warm))
          (defvalues (_ clocks)
            (measure (lambda ()
              (for ((leaf leaves) (payload payloads))
                (unless (eq? (.get leaf reads) payload)
                  (error "leaf demand changed payload identity")))) 1 #f counter-endpoints))
          (displayln (list 'LEAF-DEMAND phase 'operations 4096
            'construction (qualified-metrics construction)
            'demand (qualified-metrics clocks) 'raw-allocation (vector-ref clocks 4))))))))

;; Frozen former public constructor, including its keyword and contract boundary.
;; Only shape preparation differs; cells, initialization and revisions are identical.
(def (ordinary-layout names initial missing previous: (previous #f) state: (state #f))
  (using (names :~ list?)
    (def hint (and previous (slot-layout-shape previous)))
    (def canonical
      (if (and hint (same-shape-names? names hint)) hint (ordinary-shape-for-names names hint)))
    (def keys (shape-names canonical))
    (def result (make-layout canonical (make-vector (length keys) missing) missing 0
      state (and state (object-state-revision state))))
    (when initial
      (for ((name keys) (index (in-range (length keys))))
        (slot-layout-set! result index (hash-ref initial name missing))))
    result))

(def scalar-layout-paired-test
  (test-suite "paired native scalar layout construction"
    (test-case "balanced hit and independent cold miss, no forced collection"
      (def anchor (make-slot-layout '(value) #f absent-value))
      (unless (scalar-shape-routes-current?) (error "native route guard not active"))
      (for (regime '(hit miss))
        (for (side '(ordinary selected selected ordinary selected ordinary ordinary selected))
          ;; Fresh uninterned keys prevent either arm from populating the other's
          ;; miss workload. Enumeration is outside, and reported separately.
          (def count (if (eq? regime 'hit) 16384 1024))
          (defvalues (requests preparation)
            (measure (lambda ()
              (for/collect (_ (in-range count))
                (if (eq? regime 'hit) (list 'value)
                  (list (string->uninterned-symbol "paired-scalar"))))) 1))
          (defvalues (last clocks)
            (measure (lambda ()
              (for/fold (last #f) (keys requests)
                ;; Keep distinct direct call sites: the native optimizer can
                ;; incorrectly specialize a conditional keyword-procedure alias.
                (let (result (if (eq? side 'ordinary)
                               (ordinary-layout keys #f absent-value)
                               (make-slot-layout keys #f absent-value)))
                  (unless (eqv? (slot-layout-index result (car keys)) 0)
                    (error "scalar index changed"))
                  result))) 1))
          (when (eq? regime 'hit)
            (check-eq? (slot-layout-shape last) (slot-layout-shape anchor)))
          (displayln (list 'SCALAR-LAYOUT-PAIRED regime side 'operations count
            'preparation (qualified-metrics preparation)
            'construction (qualified-metrics clocks) 'raw-allocation (vector-ref clocks 4)))))
      (check (scalar-shape-routes-current?) ? values))))

;; This isolates the pure C4 base case, not POO cycle/constructor/hook routing.
;; It does not authorize removing any of those potentially effectful operations.
(def root-linearization-test
  (test-suite "pure C4 zero-parent call cost"
    (test-case "identical receiver metadata, runtime base case versus its result"
      (def owners (for/collect (_ (in-range 1024)) (make-object)))
      (def (unexpected . _) (error "C4 base case dispatched a callback"))
      (def (runtime-root owner supers)
        (first-value
          (c4-linearize* (list owner) (list supers)
            get-precedence-list: unexpected suffix: unexpected
            eq: eq? get-name: unexpected)))
      (def (direct-root owner supers)
        (unless (null? supers) (error "direct result requires a root"))
        (list owner))
      (for (side '(runtime direct direct runtime direct runtime runtime direct))
        (def kernel (if (eq? side 'runtime) runtime-root direct-root))
        (defvalues (_ clocks)
          (measure
            (lambda ()
              (for (_ (in-range 64))
                (for (owner owners)
                  ;; A runtime receiver field prevents literal-empty-input folding.
                  (def result (kernel owner (object-%supers owner)))
                  (unless (and (pair? result) (eq? (car result) owner) (null? (cdr result)))
                    (error "C4 root result changed"))))) 1))
        (displayln (list 'ROOT-LINEARIZATION side 'operations 65536
          (qualified-metrics clocks) 'raw-allocation (vector-ref clocks 4)))))))

;; Shape hits, including admission, versus the existing intern lookup and the
;; receiver-local cells. These diagnostic subphases are not alternate APIs.
(def shape-construction-test
  (test-suite "existing shared shape construction costs"
    (test-case "admission, weak-index hit and fresh cells on identical names"
      (def keys (list 'value))
      ;; Keep the canonical shape alive. This warms metadata, never a business
      ;; Scope or slot value. All timed receivers still own fresh empty cells.
      (defvalues (anchor setup)
        (measure (lambda () (make-slot-layout keys #f absent-value)) 1))
      (def shared (slot-layout-shape anchor))
      (def (full)
        (slot-layout-shape (make-slot-layout keys #f absent-value)))
      (def (admission) (shape-for-names keys #f))
      (def (intern) (intern-ordered-shape keys))
      (def (cells)
        (slot-layout-shape (make-layout shared (vector absent-value) absent-value 0 #f #f)))
      (displayln (list 'SHAPE-CONSTRUCTION-SETUP (qualified-metrics setup)))
      (for (side '(full admission intern cells cells intern admission full
                   cells intern admission full full admission intern cells))
        (def kernel (case side
          ((full) full) ((admission) admission) ((intern) intern) ((cells) cells)))
        (defvalues (_ clocks)
          (measure (lambda ()
            (for (_ (in-range 16384))
              (unless (eq? (kernel) shared) (error "canonical shape identity changed")))) 1))
        (displayln (list 'SHAPE-CONSTRUCTION side 'operations 16384
          (qualified-metrics clocks) 'raw-allocation (vector-ref clocks 4))))
      (check-eq? (slot-layout-shape anchor) shared))))
