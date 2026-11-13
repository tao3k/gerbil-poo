;;; Optional actual-callee diagnosis; not a default build/CI workload.
(export publication-phases-test sealed-publication-test)
(import :std/test :std/iter
        :clan/poo/object :clan/poo/mop :clan/poo/support/option
        (only-in :clan/poo/lens-laws with-lens-checks)
        (only-in :clan/poo/component-closure component-group-builder)
        (only-in :clan/poo/generalized-closure closed-raw)
        (only-in :clan/poo/feedback-cache group-closed)
        (only-in :clan/poo/feedback-graph publish-owned-feedback-graph graph-cache-ref graph-cache-partition)
        (prefix-in :clan/poo/generalized-graph graph.)
        (prefix-in :clan/poo/strong-components scc.)
        (prefix-in :clan/poo/construction-cache cache.)
        (prefix-in :clan/poo/dependency-analysis code.)
        (only-in :clan/poo/benchmarks/closure-measure measure qualified-metrics))
(extern namespace: clan/poo/feedback-graph
  register-directly group-code start-guard admit-graph)

;; Both comparison revisions run this same public entry in a fresh process.
;; Fixture generation and checks remain outside the publication window.
(def sealed-publication-test
  (test-suite "complete cold publication of 10000 components"
    (test-case "stock publication with one dependency and isolated programs"
      (def count 10000)
      (def names (for/collect (i (in-range count))
        (string->symbol (string-append "publication-owner-" (number->string i)))))
      (def provider (car names))
      (def reader (cadr names))
      (def constant (code.pure 0))
      (def source (graph.declaration names
        (map (lambda (key)
          (cons key (if (eq? key reader) (code.need provider identity) constant))) names)))
      (def build (component-group-builder names (lambda (_) (.lens)) 0 0 8))
      (def approvals 0)
      (def (accept _ __) (set! approvals (1+ approvals)) #t)
      (defvalues (head stats)
        (measure (lambda ()
          (defvalues (head failure) (publish-owned-feedback-graph source build accept))
          (when failure (raise failure))
          head) 1))
      (displayln (list 'SEALED-PUBLICATION (qualified-metrics stats)))
      (force-output)
      (check-equal? approvals 1)
      (check-equal? (closed-raw (group-closed (graph-cache-ref head reader))) 0)
      (def partition (graph-cache-partition head))
      (check-equal? (scc.partition-groups partition) (map list names))
      (def reads (scc.partition-reads partition))
      (check (andmap (lambda (key) (equal? (reads key)
        (if (eq? key reader) (list provider) []))) names) => #t))))

;; Exact start-owned-quotient body, subdivided at its existing native callees.
(def (quotient-with-phases frozen partition build builder phase)
  (def groups (phase 'quotient-members (lambda () (scc.partition-groups partition))))
  (def keys (map car groups))
  (def codes (phase 'quotient-code
    (lambda () (map (lambda (members)
      (cons (car members) (group-code partition members frozen build))) groups))))
  (def scheduled (phase 'quotient-schedule (lambda () (graph.schedule-owned keys codes))))
  (def outcomes (phase 'value-materialize (lambda () (cache.start-owned scheduled builder))))
  (cons outcomes keys))

;; Same cold owned path and actual callees as graph-action (#f predecessor,
;; no extra guards), including the original source and approval boundaries.
;; Snapshots BETWEEN calls are diagnostic allocation, not author observers.
(def (staged-publication source build accept)
  (def phases [])
  (def (phase label action)
    (defvalues (result clocks) (measure action 1))
    (set! phases (cons (list label (qualified-metrics clocks)
      'raw-allocation (vector-ref clocks 4)) phases))
    result)
  (def builder (.cc cache.Builder.))
  (def result (with-lens-checks [] (lambda ()
    (def ownership (phase 'source-admission
      (lambda () (graph.%capture-component-source source register-directly))))
    (graph.%with-component-source ownership (lambda ()
      (def frozen (phase 'source-view (lambda () (graph.%component-source-view ownership))))
      (def partition (phase 'scc (lambda () (scc.partition-owned frozen))))
      (def quotient (phase 'quotient-and-values
        (lambda () (quotient-with-phases frozen partition build builder phase))))
      (def outcomes (car quotient))
      (def guard (phase 'guard-construction
        (lambda () (start-guard outcomes (cdr quotient) partition register-directly))))
      (phase 'final-admission
        (lambda () (admit-graph #f frozen partition build ownership outcomes #f guard accept))))))))
  (values result (reverse phases)))

(def publication-phases-test
  (test-suite "actual owned publication phases"
    (test-case "same fixed two-scalar/inert-group fixture, complete and staged"
      (for (scenario '((1000 complete staged staged complete)
                       (10000 complete staged staged complete)
                       (10000 timed-build timed-build)))
        (def count (car scenario))
        ;; Identical domain/build equations to owned-quotient-study. Source
        ;; declaration is prepared outside timing; ALL publication is charged.
        (def names (append '(anchor reader) (for/collect (index (in-range (- count 2)))
          (string->symbol (string-append "publication-phase-owner-" (number->string index))))))
        (def source (graph.declaration names [(cons 'reader (code.need 'anchor identity))]
          [(cons 'anchor (some (code.make-success 0)))]))
        (def real-build (component-group-builder '(anchor reader) (lambda (_) (.lens)) 0 0 8))
        (def (build members frozen resolve)
          (if (memq (car members) '(anchor reader)) (real-build members frozen resolve)
            (real-build '(anchor) source (lambda (_) (error "unexpected inert read")))))
        (def (accept _ __) #t)
        (for (side (cdr scenario))
          (def phases [])
          (def build-calls 0)
          (def build-clocks (vector 0. 0. 0. 0))
          ;; Separate diagnostic mode: extra snapshots perturb allocation/GC.
          ;; Never substitute this for the uninstrumented complete/staged pair.
          (def (timed-build members frozen resolve)
            (defvalues (result clocks) (measure (lambda () (build members frozen resolve)) 1))
            (set! build-calls (1+ build-calls))
            (for (i (in-range 4))
              (vector-set! build-clocks i (+ (vector-ref build-clocks i) (vector-ref clocks i))))
            result)
          (def selected-build (if (eq? side 'timed-build) timed-build build))
          (defvalues (head clocks)
            (measure (lambda ()
              (if (eq? side 'complete)
                (let-values (((head failure) (publish-owned-feedback-graph source selected-build accept)))
                  (when failure (raise failure)) head)
                (let-values (((head trace) (staged-publication source selected-build accept)))
                  (set! phases trace) head))) 1))
          (check-equal? (closed-raw (group-closed (graph-cache-ref head 'reader))) 0)
          (when (eq? side 'timed-build) (check-equal? build-calls count))
          (displayln (list 'PUBLICATION-PHASES count side 'total (qualified-metrics clocks)
            'phases phases 'raw-allocation (vector-ref clocks 4)
            'timed-build-calls build-calls 'timed-build-clocks build-clocks)))))))
