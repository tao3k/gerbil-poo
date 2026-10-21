;;; Finite guarded recursive Type approximants over existing Interaction/FUN.
(export unfold-type)
(import ./types/syntax ./object (only-in ./mop Any) (prefix-in ./recursive recursive.))
;; Mu X n F denotes n applications of F to Never. The self request decreases n;
;; every copied term spends shared work, so branching expansion cannot evade quota.
;; No host recursive descriptor knot or active-pair coinductive success is used.
(def (unfold-type term work)
  (let* ((name (cadr term)) (depth (caddr term)) (body (cadddr term))
         (program (.cc recursive.Generator. input: Any output: Any
           generate: (lambda (level)
             (work)
             (if (zero? level) (recursive.value 'Never)
               (recursive.map-interaction
                 (lambda (previous) (substitute-type body (list (cons name previous)) work))
                 (recursive.request (- level 1)))))))
         (result (recursive.solve program (+ depth 1) depth)))
    (unless (recursive.value? result) (refuse-type 'exhausted "Recursive Type unfolding did not close"))
    (let (expanded (recursive.value-result result))
      (bounded-type-data expanded work)
      expanded)))
