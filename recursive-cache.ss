;;; Recursive.Cached: source-bound memo, bounded machine depth and atomic diagnostics.
(export empty run memo? memo-has? memo-size memo-hits memo-misses memo-steps receipt? receipt-program receipt-input receipt-result
        diagnostic? diagnostic-kind diagnostic-path)
(import :std/iter ./object (only-in ./mop element?) (prefix-in ./recursive recursive.))
;; Only this module constructs evaluation receipts; it exports no constructor/setter.
;; These are runtime provenance records, not transported Lean kernel proofs.
(defstruct receipt (program input result) final: #t)
;; Entries/stats are immutable published values. A run copies storage lazily once.
(defstruct memo (program entries hits misses steps) final: #t)
;; Machine refusal is distinct from a completed explicit source error.
(defstruct diagnostic (kind path) final: #t)
;; Create an empty owner-bound cache. Arbitrary cache injection is not a public API.
(def (empty program) (make-memo program (make-hash-table) 0 0 0))
;; Inspect exact completed membership before a run; nested hits do not imply that
;; the root itself was reused. No mutable table or injected receipt escapes.
(def (memo-has? cache input) (hash-key? (memo-entries cache) input))
;; Count actually completed request entries, including completed source errors.
(def (memo-size cache) (hash-length (memo-entries cache)))
;; Run the exact immutable program; fuel counts machine depth INCLUDING continuation
;; interpretation, as in Lean Cached.resolve/evaluate. It is not a total-work quota.
;; Diagnostics discard every tentative entry/statistic and return the exact old memo.
(def (run program input budget (previous (empty program)))
  (unless (and (exact-integer? budget) (>= budget 0)) (error "invalid recursive budget"))
  (unless (eq? program (memo-program previous)) (error "recursive memo owner mismatch"))
  (def entries (memo-entries previous))
  (def copied? #f)
  (def hits (memo-hits previous))
  (def misses (memo-misses previous))
  (def steps (memo-steps previous))
  ;; Resolve caches BEFORE active-path detection; only completed owned receipts hit.
  ;; Active requests never enter the table, so a cycle cannot manufacture authority.
  (def (resolve input active fuel)
    (cond ((= fuel 0) (make-diagnostic 'budget-exhausted []))
          ((hash-key? entries input) (set! hits (+ hits 1)) (hash-ref entries input))
          ((member input active) (make-diagnostic 'cycle (append (reverse active) (list input))))
          (else
           (set! misses (+ misses 1))
           (let (answer (evaluate (recursive.generate program input) (cons input active) (- fuel 1)))
             (if (diagnostic? answer) answer
               (begin
                 (when (and (recursive.value? answer)
                   (not (element? (.@ program output) (recursive.value-result answer))))
                   (error "recursive output type refused"))
                 (unless copied? (set! entries (hash-copy entries)) (set! copied? #t))
                 (let (checked (make-receipt program input answer))
                   (hash-put! entries input checked) checked)))))))
  ;; Every local node spends one depth level; a source failure short-circuits its
  ;; caller without forcing the continuation. Shared subrequests retain their memo.
  (def (evaluate tree active fuel)
    (if (= fuel 0) (make-diagnostic 'budget-exhausted [])
      (begin
        (set! steps (+ steps 1))
        (cond ((or (recursive.value? tree) (recursive.source-error? tree)) tree)
          (else
            ;; Interpret a single explicit request via bind, preserving its closed
            ;; node representation. The recursive module owns node elimination.
            (recursive.fold tree
              (lambda (input next)
                (let (head (resolve input active (- fuel 1)))
                  (cond ((diagnostic? head) head)
                    ((recursive.source-error? (receipt-result head)) (receipt-result head))
                    (else (evaluate (next (recursive.value-result (receipt-result head))) active (- fuel 1))))))))))))
  (def result (resolve input [] budget))
  (if (diagnostic? result) (values result previous)
    (values result (make-memo program entries hits misses steps))))
