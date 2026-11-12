;;; Optional native study; deliberately absent from the default development build.
;;; Compile with the standard compiler and execute through Just test-file.
(export root-linearization-test root-protocol-test leaf-demand-test shape-construction-test scalar-layout-paired-test)
(import :std/test :std/iter :clan/poo/object
        (only-in :gerbil/runtime/c3 c4-linearize*)
        (only-in :std/values first-value)
        (only-in :clan/poo/slot-layout make-slot-layout slot-layout-shape slot-layout-index slot-layout-set!)
        (only-in :clan/poo/object-state object-state-revision)
        (only-in :gerbil/runtime/gambit string->uninterned-symbol)
        (only-in :clan/poo/benchmarks/closure-measure measure qualified-metrics))
(extern namespace: clan/poo/slot-layout shape-for-names intern-ordered-shape make-layout
        ordinary-shape-for-names same-shape-names? shape-names scalar-shape-routes-current?)

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
