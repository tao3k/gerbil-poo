;;; Shared assertions for original and failure-isolated coordinator workflows.
(export check-revisions)
(import :std/test
        :clan/poo/object
        :clan/poo/mop
        :clan/poo/brace
        :clan/poo/feedback-graph
        (runtime: :clan/poo/joint-publication)
        (prefix-in (only-in :clan/poo/joint-publication approval current head) joint.)
        (prefix-in :clan/poo/examples/joint-topology service.)
        :clan/poo/examples/joint-coordination-rounds)
;; Checkpoint provenance retains the reply for its specific coordinator.
(defstruct checkpoint (name value reply) final: #t)
;; Explicit final-round marker is separate from repeating topology phase names.
(def rows '((merge 24 48 24 #f) (replace 16 32 16 #f) (restore 12 24 12 #f)
            (merge 24 48 24 #f) (replace 16 32 16 #f) (restore 12 24 12 #t)))
;; Cook before sharing proposed metadata across coordinator threads.
(def (policy owner ceiling budget)
  (def value (.cc (joint.approval (joint.current owner) 'shared) limit: ceiling budget: budget))
  (instantiate-object! value) value)
;; Each phase admits exactly the named live participants in arbitrary arrival order.
(def (collect next phase names)
  (def results (map (lambda (_) (next make-checkpoint)) names))
  (for-each (lambda (entry) (check-equal? (car (checkpoint-value entry)) phase)) results)
  (for-each (lambda (name)
    (check-equal? (length (filter (lambda (entry) (eq? (checkpoint-name entry) name)) results)) 1)) names)
  results)

;; Assert complete states across six real SCC rounds. The callback may defer
;; releasing fresh workers until independently observed local exits.
(def (check-revisions owner next
       before-release: (before-release (lambda (_ release) (release)))
       participants: (participants (lambda (_ __) '(a b))))
  (def original (joint.current owner))
  (for-each (lambda (row)
    (def before (joint.current owner)) (def shared (policy owner (cadr row) (caddr row)))
    (for-each (lambda (entry) ((checkpoint-reply entry) (list (car row) shared))) (collect next 'next (participants row 'next)))
    (def approved (collect next 'approved (participants row 'approved)))
    (check (eq? before (joint.current owner)) => #t)
    ;; All participant admissions returned; only uninstalled metadata drifts.
    (.putslot! shared 'budget ($constant-slot-spec (+ (caddr row) 1)))
    (.putslot! shared 'budget ($constant-slot-spec (caddr row)))
    (for-each (lambda (entry) ((checkpoint-reply entry) 'install)) approved)
    (def denied (collect next 'refused (participants row 'refused)))
    (for-each (lambda (entry)
      (def result (cadr (checkpoint-value entry)))
      (check (not (not (observation-failure result))) => #t)
      (check (eq? (observation-snapshot result) before) => #t)) denied)
    (for-each (lambda (entry)
      ((checkpoint-reply entry) (policy owner (cadr row)
        (+ (caddr row) (if (eq? (checkpoint-name entry) 'a) 0 2))))) denied)
    (def ready (collect next 'ready (participants row 'ready)))
    ;; Optional per-receipt commands fail only selected coordinator incarnations.
    (def (release (command (lambda (_ __) 'install)) (names (map checkpoint-name ready)))
      (for-each (lambda (entry) ((checkpoint-reply entry)
        (command (checkpoint-name entry) (cadr (checkpoint-value entry)))))
        (filter (lambda (entry) (memq (checkpoint-name entry) names)) ready)))
    (before-release row release)
    (def published (collect next 'published (participants row 'published))) (def successes 0) (def winner (joint.current owner))
    (for-each (lambda (entry)
      (def message (checkpoint-value entry))
      (for-each (lambda (result)
        (if (eq? (observation-receipt result) (cadr message))
          (unless (observation-failure result)
            (set! successes (+ successes 1)) (check (eq? (observation-snapshot result) winner) => #t))
          (begin (check (eq? (observation-receipt result) (caddr message)) => #t)
                 (check (not (not (observation-failure result))) => #t)))
        (check (or (eq? (observation-snapshot result) before) (eq? (observation-snapshot result) winner)) => #t))
        (list-ref message 3))) published)
    (check-equal? successes 1)
    (for-each (lambda (key)
      (check-equal? (service.value winner key) (list-ref row 3))
      (check (eq? (graph-cache-ref (joint.head original key) 'stable)
                  (graph-cache-ref (joint.head winner key) 'stable)) => #t)
      (case (car row)
        ((replace) (check-exception (graph-cache-ref (joint.head winner key) 'b) true))
        ((restore) (for-each (lambda (removed)
          (check-exception (graph-cache-ref (joint.head winner key) removed) true)
          (check-equal? (.call (graph-cache-source (joint.head winner key)) .code removed) #f)
          (check-equal? (.call (graph-cache-source (joint.head winner key)) .base removed) #f)) '(e f))))) '(a b))
    (for-each (lambda (entry) ((checkpoint-reply entry) (if (list-ref row 4) 'finish 'continue))) published))
    ;; The final marker is explicit; phase names repeat across cycles.
    rows)
  (for-each (lambda (entry)
    (check (not (not (observation-failure (cadr (checkpoint-value entry))))) => #t)
    ((checkpoint-reply entry) 'done)) (collect next 'drained (participants #f 'drained))))
