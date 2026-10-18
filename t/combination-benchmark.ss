;;; Same-binary original-algorithm controls for continuation preparation.
(export main)
(import (only-in ../support/base require-value) ../object ../mop ../method-declaration
  (prefix-in ../examples/declared-methods service.) (prefix-in ../generalized-prototype gp.)
  (only-in ../reflection read-slot) :std/iter (only-in :std/list/list foldr) (only-in :std/func compose1)
  (prefix-in ../method-combination combination.) "combination-cases.ss"
  (only-in "closure-measure.ss" run-child))
;; Rejected candidate: lift to unary continuation builders and use std compose1.
;; This remains a study control, not another runtime strategy or public namespace.
(def (composed-inner methods terminal)
  ((apply compose1 (map (lambda (method)
    (lambda (next) (lambda (args) (apply method (lambda () (next args)) args))))
    (reverse methods))) terminal))
;; Same candidate across the complete explicit-view Simula compiler. Preserve
;; getter order before composition; invocation contains no composition traversal.
(def (composed-simula methods)
  (def suffix (foldr (lambda (body builders)
    (def callback (.@ body suffix-part))
    (cons (lambda (next)
      (lambda (view args) (callback (car args) view) (next view args))) builders)) [] methods))
  (def builders (foldl (lambda (body builders)
    (def callback (.@ body prefix-part))
    (cons (lambda (next)
      (lambda (view args) (callback (car args) view) (next view args))) builders)) suffix methods))
  ((apply compose1 builders) (lambda (_ __) (void))))
;; A finite row oracle keeps false and escaped keyword data observable.
(def (row-combination fragments row)
  (and (eq? fragments 'parts) (equal? row '(label: #f #!rest 3 #f payload: #f))))
;; Actual production lowering exercises canonical keyword/rest row construction.
(.defgeneric (direct-row self required (optional #f) label: (label #f) . rest)
  slot: .parts combination: row-combination)
;; Immediately preceding apply/list lowering, with identical selection, lookup,
;; admission and core bindings. Compare one change, not accumulated optimizations.
(def (reference-row self required (optional #f) label: (label #f) . rest)
  (let* ((combine row-combination) (parts (.ref self '.parts)))
    (unless (procedure? combine) (error "generic combination must be a procedure"))
    (combine parts (apply list label: label #!rest required optional rest))))
;; Isolate parameter transport from object lookup, method selection and factories.
;; Both paths copy the rest spine and demand the same exact row oracle.
(def (reference-transport rest)
  (row-combination 'parts (apply list label: #f #!rest 3 #f rest)))
;; This is the fixed prefix emitted by the production macro, using core cons and
;; append only; append's final empty list makes the callback's rest spine private.
(def (direct-transport rest)
  (row-combination 'parts (cons label: (cons #f (cons #!rest (cons 3 (cons #f (append rest '()))))))))
;; Benchmark control: ordinary current descriptors without constructor evidence.
;; This is not a production API or an alternative argument/Reader protocol.
(def (unregistered-contribution qualifier body)
  (require-value body procedure? (lambda () (error "method body must be a procedure")))
  (.cc combination.Contribution. qualifier: qualifier body: body))
;; Measure only the bridge or the complete Reader/reflection/C3 workflow. Each
;; fresh child constructs and warms all four controls in the same order. No setup,
;; GC count or callback history is chosen after seeing the measured side.
(def (generic-workload scenario)
  (def conditioned? (memq scenario '(generic-hot-conditioned generic-workflow-conditioned generic-construction-conditioned)))
  (def kind (case scenario
    ((generic-hot-conditioned) 'generic-hot)
    ((generic-workflow-conditioned) 'generic-workflow)
    ((generic-construction-conditioned) 'generic-construction)
    (else scenario)))
  (def receiver (.o (.parts 'parts)))
  (def calls 0)
  ;; A bounded counter forces callbacks; each complete operation resets it.
  (def (record _) (set! calls (+ calls 1)))
  (def families (map (cut service.make-reporting-family record <>)
    (list unregistered-contribution combination.contribution)))
  (def family (cadr families))
  (def context (.o rate: 10))
  (def makers
    (map (lambda (owner) (lambda () (service.typed-summary-action owner 2))) families))
  (def held #f)
  (def actions
    (if (eq? kind 'generic-transport)
      (map (lambda (transport) (lambda () (transport '(payload: #f))))
        (list reference-transport direct-transport))
    (if (eq? kind 'generic-account)
      (let (construct (lambda ()
        (set! held (service.make-account family 10))
        (and (eq? (.@ held .type) family) (= (.@ held rate) 10))))
        (list construct construct))
    (if (memq kind '(generic-factory generic-factory-allocation))
      (map (lambda (make-action)
        (lambda () (set! held (make-action)) (procedure? held))) makers)
    (if (memq kind '(generic-workflow generic-workflow-allocation generic-construction generic-construction-allocation))
      (map (lambda (make-action)
        (def prepared (make-action))
        (lambda ()
          (set! calls 0)
          (def action (if (memq kind '(generic-construction generic-construction-allocation)) (make-action) prepared))
          (def observed (call/values (lambda () (action context)) list))
          (and (= calls 9) (equal? observed '(46 ((10 2 2 #f (payload: #f)))))))) makers)
      (map (lambda (invoke)
        (lambda () (invoke receiver 3 #f label: #f #!rest payload: #f)))
        (list reference-row direct-row)))))))
  ;; Fixed all-control conditioning precedes the shared prefix and measured side.
  ;; Natural GC is retained: this tests sensitivity to workload history, without
  ;; claiming two separate processes have identical heaps or subtracting A/A noise.
  (when conditioned?
    (for* ((_ (in-range 128)) (action actions))
      (unless (action) (error "conditioning oracle"))))
  (list (car actions) (cadr actions) (car actions) (cadr actions)))

;; Include evidence setup, lazy declaration realization, first reflection and FUN
;; invocation. Both sides share constructors, call rows and current method bodies.
(def (registration-workload scenario)
  ;; Count callback effects independently of registration and reflection.
  (def calls 0)
  ;; Reset per complete request, retaining an exact body-count oracle.
  (def (record _) (set! calls (+ calls 1)))
  ;; Both constructions receive the same immutable input context.
  (def context (.o rate: 10))
  ;; Retain constructed objects across the measured boundary.
  (def held #f)
  ;; Lift the same request over ordinary and registered descriptor constructors.
  (def actions
    (map (lambda (construct)
      ;; Admission-only work uses an equal fixed-size descriptor group.
      (def parts (map (lambda (_) (construct 'primary (lambda (_ value) value)))
                     '(1 2 3 4 5 6 7 8)))
      (lambda ()
        (case scenario
          ((registration-admission)
           (andmap combination.standard-contribution? parts))
          ((registration-construction)
           (set! held (construct 'primary (lambda (_ value) value)))
           (object? held))
          (else
           (let (owner (service.make-reporting-family record construct))
             (read-slot owner '.summary)
             (read-slot owner '.charge)
             (if (eq? scenario 'registration-family)
               (begin (set! held owner) #t)
               (begin
                 (set! calls 0)
                 (let (answer (call/values
                       (lambda () ((service.typed-summary-action owner 2) context)) list))
                   (and (= calls 9)
                        (equal? answer '(46 ((10 2 2 #f (payload: #f))))))))))))))
      (list unregistered-contribution combination.contribution)))
  (list (car actions) (cadr actions) (car actions) (cadr actions)))

;; Both implementations share callback identities and fully demanded return oracles.
;; A bounded mutable sink ensures AOT cannot erase Simula callback execution.
(def (combination-workload scenario)
  (def total 0)
  (def methods (for/collect (_ (in-range 8)) (lambda (next value) (+ 1 (next)))))
  (def bodies (for/collect (_ (in-range 8))
    (combination.simula-body (lambda (units view) (set! total (+ total units view)))
      (lambda (units view) (set! total (+ total units view))))))
  (def actions
    (if (memq scenario '(prepare-inner call-inner))
      (map (lambda (compiler)
        (def compiled (compiler methods (lambda (args) (car args))))
        (lambda () (= ((if (eq? scenario 'prepare-inner)
          (compiler methods (lambda (args) (car args))) compiled) '(3)) 11)))
        (list composed-inner combination.prepare-inner))
      (map (lambda (compiler)
        (def compiled (compiler bodies))
        (lambda ()
          (set! total 0)
          ((if (eq? scenario 'prepare-simula) (compiler bodies) compiled) 5 '(3))
          (= total 128))) (list composed-simula combination.compile-simula-context))))
  (list (car actions) (cadr actions) (car actions) (cadr actions)))
;; The shared study retains the earlier continuation candidates as historical
;; controls; new generic scenarios compare the complete production bridge only.
(def (workload scenario)
  (if (memq scenario '(registration-admission registration-construction registration-family registration-complete))
    (registration-workload scenario)
  (if (memq scenario '(generic-account generic-workflow-allocation generic-factory generic-transport generic-hot-conditioned generic-workflow-conditioned generic-construction-conditioned generic-allocation generic-hot generic-workflow generic-construction generic-factory-allocation generic-construction-allocation))
    (generic-workload scenario) (combination-workload scenario))))
;; Validate CLI dimensions before using the shared 1GiB/fresh-process protocol.
(def (main scenario-text regime-text side-text)
  (def scenario (string->symbol scenario-text))
  (def regime (string->symbol regime-text))
  (def side (string->number side-text))
  (unless (and (memq scenario scenarios) (memq regime '(natural collected)) (memv side '(0 1 2 3)))
    (error "invalid combination study request"))
  (run-child scenario regime side (workload scenario) (repetitions scenario) 4))
