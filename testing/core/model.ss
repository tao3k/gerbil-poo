;;; Generic finite model traces. Domains supply admission and normalization.
(export make-model model? make-system system? valid-trace? repair-trace draw-trace check-trace
        trace-report? trace-report-matched? trace-report-phase trace-report-index
        trace-report-has-command? trace-report-command trace-report-expected trace-report-actual)
(import :std/error :std/iter)
;; Private model records hold ordinary pure callbacks, not POO descriptors.
(defstruct reference (initial enabled advance observe accept normalize) final: #t)
;; Each fixture supplies owned state and its actual transition/observation functions.
(defstruct fixture (initial step observe) final: #t)
;; Presence is separate from payload so false remains a valid command.
(defstruct trace-report (matched? phase index has-command? command expected actual) final: #t)

;; Public recognizers retain ordinary Gerbil record identity.
(def model? reference?)
;; An actual fixture remains private to its scoped caller.
(def system? fixture?)

;; The model's normalization and membership are explicit domain responsibilities.
(def (make-model (initial : :procedure) (enabled : :procedure) (advance : :procedure)
                 (observe : :procedure) (accept : :procedure) (normalize : :procedure))
  (make-reference initial enabled advance observe accept normalize))
;; The fixture constructor owns no setup/cleanup policy; its caller supplies scope.
(def (make-system initial (step : :procedure) (observe : :procedure))
  (make-fixture initial step observe))
;; Model predicates cannot confuse arbitrary truthy values with authorization.
(def (judgment value message)
  (unless (boolean? value) (error message value)) value)
;; One shared fold advances retained commands. Selection returns two values,
;; separating keep/omit from a command payload which may itself be false.
(def (fold-trace model commands select)
  (foldl (lambda (raw progress)
    (let-values (((keep? command) (select (car progress) raw)))
      (if keep?
        (let-values (((next _reply) ((reference-advance model) (car progress) command)))
          (cons next (cons command (cdr progress)))) progress)))
    (cons ((reference-initial model)) []) commands))
;; Complete prefix admission runs before any actual fixture can have effects.
(def (valid-trace? model commands)
  (let/cc invalid
    (unless (list? commands) (invalid #f))
    (fold-trace model commands (lambda (state raw)
      (unless (judgment ((reference-accept model) raw) "command predicate must return a boolean") (invalid #f))
      (def command ((reference-normalize model) raw))
      (unless (judgment ((reference-enabled model) state command) "trace precondition must return a boolean") (invalid #f))
      (values #t command))) #t))
;; Dependency retirement uses the same fold and never renames logical handles.
(def (repair-trace model commands)
  (reverse (cdr (fold-trace model commands (lambda (state raw)
    (if (judgment ((reference-accept model) raw) "command predicate must return a boolean")
      (let (command ((reference-normalize model) raw))
        (values (judgment ((reference-enabled model) state command) "trace precondition must return a boolean") command))
      (values #f #f)))))))
;; A two-value draw callback returns continue?/command. This API requires no
;; domain-specific Option class, and the finite step cap bounds all successful draws.
(def (draw-trace model draw steps random size)
  (let/cc done
    (def progress (for/fold (progress (cons ((reference-initial model)) [])) (_ (in-range (min steps size)))
      (let-values (((continue? raw) (draw (car progress) random size)))
        (unless (judgment continue? "draw continuation must return a boolean") (done (reverse (cdr progress))))
        (unless (judgment ((reference-accept model) raw) "command predicate must return a boolean")
          (error "generated command is outside its domain"))
        (let (command ((reference-normalize model) raw))
          (unless (judgment ((reference-enabled model) (car progress) command) "trace precondition must return a boolean")
            (error "disabled generated command" command))
          (let-values (((next _reply) ((reference-advance model) (car progress) command)))
            (cons next (cons command (cdr progress))))))))
    (reverse (cdr progress))))
;; Scope and first-difference execution are generic. The same? callback receives
;; phase/expected/actual, permitting typed domains to normalize at that boundary.
(def (check-trace model commands (with-system : :procedure)
                  same?: (same? (lambda (_phase left right) (equal? left right))))
  (unless (valid-trace? model commands) (error "invalid command trace"))
  ;; The comparison fold exits before any later step or unnecessary observation.
  (def (run actual)
    (unless (system? actual) (error "system required"))
    (let/cc different
      (def (compare phase index present? command expected found)
        (unless (judgment (same? phase expected found) "trace equality must return a boolean")
          (different (make-trace-report #f phase index present? command expected found))))
      (def reference ((reference-initial model)))
      (def initial (fixture-initial actual))
      (compare 'initial 0 #f #f ((reference-observe model) reference) ((fixture-observe actual) initial))
      (for/fold (states (cons reference initial)) ((command commands) (index (in-range (length commands))))
        (let*-values (((next expected) ((reference-advance model) (car states) command))
                      ((updated found) ((fixture-step actual) (cdr states) command)))
          (compare 'result index #t command expected found)
          (compare 'state index #t command ((reference-observe model) next) ((fixture-observe actual) updated))
          (cons next updated)))
      (make-trace-report #t 'complete (length commands) #f #f #f #f)))
  (def active? #t) (def entered? #f) (def result #f)
  (try
    (let (returned (with-system (lambda (actual)
      (unless (and active? (not entered?)) (error "trace fixture callback is not active or was reused"))
      (set! entered? #t) (set! result (run actual)) result)))
      (unless (and entered? result (eq? returned result)) (error "trace fixture did not return its observation")) result)
    (finally (set! active? #f))))
