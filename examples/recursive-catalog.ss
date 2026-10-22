;;; RecursiveCatalog / RecursiveDispatch: shared requests with current Type admission.
(export program registry expected run-service)
(import ../object
        (only-in ../mop Any Type. validate)
        (only-in ../number IntegerRange)
        (prefix-in ../proto proto.)
        (runtime: :clan/poo/recursive)
        (prefix-in (only-in ../recursive Interaction. close source-error value) recursive.)
        (runtime: :clan/poo/recursive-handling)
        (prefix-in (only-in ../recursive-handling Signature. call-batch result-next) handling.)
        (runtime: :clan/poo/multimethod)
        (prefix-in (only-in ../multimethod contribute prototype standard) dispatch.)
        (runtime: :clan/poo/method-combination)
        (prefix-in (only-in ../method-combination primary) combination.))
;; Immutable source requests use the final self. The inherited head implementation
;; is overridden below, so every chain observes the same composed final program.
(def (base self _)
  (lambda (input)
    (let ((slot (car input)) (argument (cdr input)))
      (case slot
        ((head) (recursive.value argument))
        ((callback) (recursive.value 'alert))
        ((fail) (recursive.source-error "catalog-source"))
        ((loop) (self input))
        ((chain)
         (if (not (and (exact-integer? argument) (>= argument 0))) (recursive.source-error "count required")
           (if (= argument 0) (recursive.value [])
             (.call recursive.Interaction. .bind (self (cons 'head argument))
               (lambda (head)
                 (.call recursive.Interaction. .bind (self (cons 'chain (- argument 1)))
                   (lambda (tail)
                     (.call recursive.Interaction. .map
                       (lambda (callback) (list head tail callback)) (self (cons 'callback 'unit))))))))))
        (else (recursive.source-error "unknown slot"))))))
;; Extend the ordinary prototype chain; recursive chain calls reach this head.
(def (scaled self super)
  (lambda (input)
    (if (eq? (car input) 'head) (recursive.value (* 2 (cdr input))) (super input))))
;; Close existing prototypes with explicit recursive requests, not an unsafe fix.
(def program (recursive.close (proto.compose-proto scaled base) #f Any Any))
;; The complete expected immutable result, independent of the evaluator/memo.
(def (expected count) (if (= count 0) [] (list (* 2 count) (expected (- count 1)) 'alert)))
;; Validate nested source values under the CURRENT policy and function registry.
;; Fuel bounds native type inspection; a removed callback must fail even on a hit.
(def (tree? value ceiling callback? fuel)
  (or (null? value)
    (and (> fuel 0) (list? value) (= (length value) 3)
      (exact-integer? (car value)) (<= 0 (car value) ceiling)
      callback? (eq? (caddr value) 'alert) (tree? (cadr value) ceiling callback? (- fuel 1)))))
;; Runtime descriptors reuse the native Type system. Changing registry output or
;; input constraints never edits the program and must not invalidate its raw memo.
(def (registry ceiling (callback? #t) (max-count 5))
  (.o
    (chain (.cc handling.Signature. name: 'chain input: (IntegerRange min: 0 max: max-count)
      output: (.cc Type. .element?: (cut tree? <> ceiling callback? 16))))
    (head (.cc handling.Signature. name: 'head input: (IntegerRange min: 0 max: max-count) output: Any))
    (fail (.cc handling.Signature. name: 'fail input: Any output: Any))
    (loop (.cc handling.Signature. name: 'loop input: Any output: Any))))
;; Typed multi-dispatch executes the FUN request chain against current registry and
;; session arguments. Returned state carries completed memo on output refusal;
;; the business ledger remains unchanged by recursive evaluation itself.
(def run-service
  (dispatch.contribute
    (dispatch.standard (list Any Any (IntegerRange min: 0 max: 5)) Any (lambda (_) '((Run)))
      (lambda (_) (error "missing recursive workflow")) 1)
    (list (dispatch.prototype 'Run))
    (combination.primary (lambda (_next state current count)
      (def called (handling.call-batch (.@ state session) current
        (list (cons 'chain count) (cons 'head count)) 200))
      (.o (result called) (session (handling.result-next called)) (ledger (.@ state ledger)))))))
