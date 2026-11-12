;;; Optional native study; deliberately absent from the default development build.
;;; Compile with the standard compiler and execute through Just test-file.
(export root-linearization-test shape-construction-test)
(import :std/test :std/iter :clan/poo/object
        (only-in :gerbil/runtime/c3 c4-linearize*)
        (only-in :std/values first-value)
        (only-in :clan/poo/slot-layout make-slot-layout slot-layout-shape)
        (only-in :clan/poo/benchmarks/closure-measure measure qualified-metrics))
(extern namespace: clan/poo/slot-layout shape-for-names intern-ordered-shape make-layout)

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
