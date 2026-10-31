;;; Own metadata-study admission without loading or initializing its workload.
(export main check-study sources phases rounds repetitions)
(import :std/iter "closure-measure.ss")
;; The producer and report use one definition of source identity and dimensions.
;; Inspecting a report never constructs a service, contract or publication family.
;; Exact source identities cover the producer and this admission definition.
(def sources '("contract-family.ss" "build.ss" "dependency-analysis.ss" "generalized-graph.ss" "construction-cache.ss" "declarative-metadata.ss" "generic-family.ss" "staged-publication.ss" "cyclic-publication.ss" "dispatch-extension.ss" "multimethod.ss"
               "closure.ss" "object.ss" "mop.ss" "type.ss" "number.ss" "justfile"
               "examples/shared-contracts.ss" "examples/construction-workflow.ss" "examples/service-metadata.ss" "examples/service-bundle.ss" "examples/protected-dispatch.ss" "examples/cyclic-access.ss"
               "benchmarks/closure-measure.ss" "benchmarks/metadata-benchmark.ss" "benchmarks/metadata-report.ss"))
;; Preserve the established ordered matrix, including refusal and full workflows.
(def phases '(raw bound invoke wrap-build input-refuse output-refuse logic-refuse family-build family-warm revise refused-revise
              protected-build protected-cold protected-warm guarded-low guarded-high protected-refuse protected-cancelled metadata-refuse call-refuse
              component-start component-refresh component-reuse component-root component-presence
              selective-release policy-release selective-negative-refuse selective-admission-refuse
              schedule-full schedule-retained component-recapture protected-full-cold protected-full-warm
              service-reuse service-cold service-price service-price-cold service-invoice service-invoice-cold
              service-budget-refuse service-negative-refuse
              contract-prepare contract-retain contract-change contract-rebind
              contract-release-reuse contract-release-cold contract-price-reuse contract-price-cold
              shared-input-retain independent-input-retain shared-price independent-price shared-joint independent-joint
              joint-input-shared joint-input-independent joint-construct joint-bind joint-family-shared joint-family-independent joint-generics joint-approval joint-cook
              selected-price selected-joint joint-family-selected joint-input-direct joint-selection joint-unfactored-construct unfactored-joint unfactored-price
              workflow-selected-joint workflow-unfactored-joint))
;; Both GC regimes retain the same number of independently ordered rounds.
(def rounds 4)
;; Preserve the producer's fixed per-phase counts across both GC regimes.
(def (repetitions phase)
  ;; Release-only follow-up: initial 8-op natural-GC price comparison regressed.
  ;; Increase both matched sides equally; keep the same fixed time/heap bounds.
  (cond ((memq phase '(workflow-selected-joint workflow-unfactored-joint)) 128)
        ((memq phase '(selected-price selected-joint joint-family-selected joint-input-direct joint-selection joint-unfactored-construct unfactored-joint unfactored-price)) 128)
        ((memq phase '(joint-input-shared joint-input-independent joint-construct joint-bind joint-family-shared joint-family-independent joint-generics joint-approval joint-cook)) 128)
        ((memq phase '(shared-input-retain independent-input-retain shared-price independent-price shared-joint independent-joint)) 128)
        ((memq phase '(contract-release-reuse contract-release-cold contract-price-reuse contract-price-cold)) 128)
        ((memq phase '(family-build revise refused-revise protected-build protected-refuse protected-cancelled metadata-refuse
                         component-start component-refresh component-reuse component-root component-presence
                         selective-release policy-release selective-negative-refuse selective-admission-refuse
                         schedule-full schedule-retained component-recapture
                         service-reuse service-cold service-price service-price-cold service-invoice service-invoice-cold
                         service-budget-refuse service-negative-refuse
                         contract-prepare contract-retain contract-change contract-rebind
                         contract-release-reuse contract-release-cold contract-price-reuse contract-price-cold)) 8)
        ((memq phase '(protected-cold protected-warm guarded-low guarded-high call-refuse protected-full-cold protected-full-warm)) 512)
        (else 4000)))
;; Reject stale, incomplete, duplicate and invalid-allocation rows before reporting.
(def (check-study study)
  (unless (and (pair? study) (eq? (car study) 'metadata-benchmarks)) (error "wrong study"))
  (def (field key) (cdr (or (assq key (cdr study)) (error "missing field" key))))
  (unless (and (equal? (field 'status) '(complete))
               (equal? (field 'rounds) (list rounds))
               (equal? (field 'phases) phases)
               (equal? (field 'sources) (source-digests sources))) (error "stale or incomplete study"))
  (def rows (field 'rows))
  (def seen (make-hash-table))
  (for (row rows)
    (unless (and (vector? row) (= (vector-length row) 6)) (error "invalid row"))
    (def gc (vector-ref row 0))
    (def round (vector-ref row 1))
    (def phase (vector-ref row 2))
    (def metrics (vector-ref row 4))
    (def raw (vector-ref row 5))
    (def key (list gc round phase))
    (unless (and (memq gc '(natural collected)) (exact-integer? round) (<= 0 round) (< round rounds)
                 (memq phase phases) (= (vector-ref row 3) (repetitions phase))
                 (vector? metrics) (= (vector-length metrics) 5) (exact-integer? raw)) (error "invalid dimensions"))
    (when (hash-key? seen key) (error "duplicate row" key))
    (hash-put! seen key #t)
    (for (index (in-range 4))
      (unless (and (real? (vector-ref metrics index)) (<= 0 (vector-ref metrics index))) (error "invalid metric")))
    (unless (equal? (vector-ref metrics 4) (and (= (vector-ref metrics 3) 0) (>= raw 0) raw))
      (error "allocation policy")))
  (unless (= (length rows) (* 2 rounds (length phases))) (error "missing rows"))
  rows)
;; Admit the entire matrix before deriving any display-only timing summary.
(def (main path)
  (def rows (check-study (read-datum path)))
  (for* ((gc '(natural collected)) (phase phases))
    (def samples (filter (lambda (row) (and (eq? (vector-ref row 0) gc) (eq? (vector-ref row 2) phase))) rows))
    (def (per-call index)
      (median (map (lambda (row) (/ (vector-ref (vector-ref row 4) index) (vector-ref row 3))) samples)))
    (displayln gc " " phase " cpu-us=" (* 1e6 (per-call 0))
      " bytes=" (if (andmap (lambda (row) (vector-ref (vector-ref row 4) 4)) samples) (per-call 4) 'unavailable)))
  (displayln "METADATA-REPORT-OK rows=" (length rows)))
