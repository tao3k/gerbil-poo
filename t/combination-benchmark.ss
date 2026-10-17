;;; Same-binary original-algorithm controls for continuation preparation.
(export main)
(import ../object :std/iter (only-in :std/list/list foldr) (only-in :std/func compose1)
  (prefix-in ../method-combination combination.) "combination-cases.ss"
  (only-in "metadata-paired-benchmark.ss" run-child))
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
;; Both implementations share callback identities and fully demanded return oracles.
;; A bounded mutable sink ensures AOT cannot erase Simula callback execution.
(def (workload scenario)
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
;; Validate CLI dimensions before using the shared 1GiB/fresh-process protocol.
(def (main scenario-text regime-text side-text)
  (def scenario (string->symbol scenario-text))
  (def regime (string->symbol regime-text))
  (def side (string->number side-text))
  (unless (and (memq scenario scenarios) (memq regime '(natural collected)) (memv side '(0 1 2 3)))
    (error "invalid combination study request"))
  (run-child scenario regime side (workload scenario) (repetitions scenario) 4))
