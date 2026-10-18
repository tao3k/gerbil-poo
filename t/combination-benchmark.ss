;;; Same-binary original-algorithm controls for continuation preparation.
(export main)
(import ../object ../mop ../method-declaration
  (prefix-in ../examples/declared-methods service.) :std/iter (only-in :std/list/list foldr) (only-in :std/func compose1)
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
;; Historical bridge, retained only as an independent same-binary study control.
;; Both variants use identical core formals and the public production combiner.
(def (reference-combine combine fragments)
  (unless (procedure? combine) (error "generic combination must be a procedure"))
  (lambda arguments (combine fragments arguments)))
;; A finite row oracle keeps false and escaped keyword data observable.
(def (row-combination fragments row)
  (and (eq? fragments 'parts) (equal? row '(label: #f #!rest 3 #f payload: #f))))
;; Actual production lowering exercises canonical keyword/rest row construction.
(.defgeneric (direct-row self required (optional #f) label: (label #f) . rest)
  slot: .parts combination: row-combination)
;; Previous lowering over the exact same formal bindings and fragment lookup.
(def (reference-row self required (optional #f) label: (label #f) . rest)
  (apply (reference-combine row-combination (.ref self '.parts))
    label: label #!rest required optional rest))
;; Previous contracted type-provided generic, without a substitute interpreter.
(def (reference-summary account (required :~ fixnum?)
    (optional required :~ fixnum?) label: (label #f) . rest)
  (apply (reference-combine (simple-combination combination.collect)
           (.ref (.get account .type) '.summary))
    label: label #!rest account required optional rest))
;; Match the production named factory boundary as well as its native FUN syntax.
;; Inlining only the reference factory would confound construction measurements.
(def (reference-summary-action family units)
  (service.summary-observation family units reference-summary))
;; Measure only the bridge or the complete Reader/reflection/C3 workflow. Each
;; fresh child constructs and warms all four controls in the same order. No setup,
;; GC count or callback history is chosen after seeing the measured side.
(def (generic-workload scenario)
  (def receiver (.o (.parts 'parts)))
  (def calls 0)
  ;; A bounded counter forces callbacks; each complete operation resets it.
  (def (record _) (set! calls (+ calls 1)))
  (def family (service.make-reporting-family record))
  (def context (.o rate: 10))
  (def makers
    (list (lambda () (reference-summary-action family 2))
          (lambda () (service.typed-summary-action family 2))))
  (def held #f)
  (def actions
    (if (eq? scenario 'generic-factory-allocation)
      (map (lambda (make-action)
        (lambda () (set! held (make-action)) (procedure? held))) makers)
    (if (memq scenario '(generic-workflow generic-construction generic-construction-allocation))
      (map (lambda (make-action)
        (def prepared (make-action))
        (lambda ()
          (set! calls 0)
          (def action (if (memq scenario '(generic-construction generic-construction-allocation)) (make-action) prepared))
          (def observed (call/values (lambda () (action context)) list))
          (and (= calls 9) (equal? observed '(46 ((10 2 2 #f (payload: #f)))))))) makers)
      (map (lambda (invoke)
        (lambda () (invoke receiver 3 #f label: #f #!rest payload: #f)))
        (list reference-row direct-row)))))
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
  (if (memq scenario '(generic-allocation generic-hot generic-workflow generic-construction generic-factory-allocation generic-construction-allocation))
    (generic-workload scenario) (combination-workload scenario)))
;; Validate CLI dimensions before using the shared 1GiB/fresh-process protocol.
(def (main scenario-text regime-text side-text)
  (def scenario (string->symbol scenario-text))
  (def regime (string->symbol regime-text))
  (def side (string->number side-text))
  (unless (and (memq scenario scenarios) (memq regime '(natural collected)) (memv side '(0 1 2 3)))
    (error "invalid combination study request"))
  (run-child scenario regime side (workload scenario) (repetitions scenario) 4))
