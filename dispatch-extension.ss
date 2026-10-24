;;; DispatchExtension: immutable edits and completed-candidate negative watches.
(export shape call register contribute register-when erase patch check guard publish invoke prepare-shape
        certificate? snapshot conflict? conflict-position conflict-watch conflict-kind conflict-first-method
        failure? failure-stage failure-cause)
(import :std/iter (prefix-in ./multimethod multimethod.))
(defstruct watch (kind value) final: #t)
(defstruct change (kind path predicate method) final: #t)
(defstruct certificate (snapshot watches) final: #t)
(defstruct conflict (position watch kind first-method) final: #t)
(defstruct failure (stage cause) final: #t)
(def (snapshot checked) (certificate-snapshot checked))
(def (shape orders)
  (unless (and (list? orders) (andmap list? orders)) (error "invalid shape watch"))
  (make-watch 'shape (map (lambda (order) (map identity order)) orders)))
(def (call . args) (make-watch 'call args))
(def (change! kind path predicate method)
  (unless (list? path) (error "invalid edit path"))
  (make-change kind (map identity path) predicate method))
(def (register path method) (change! 'register path #f method))
(def (contribute path method) (change! 'contribute path #f method))
(def (register-when path predicate method) (change! 'register-when path predicate method))
(def (erase path) (change! 'erase path #f #f))
(def (patch generic edits)
  (for/fold (current generic) (edit edits)
    (case (change-kind edit)
      ((register) (multimethod.register current (change-path edit) (change-method edit)))
      ((contribute) (multimethod.contribute current (change-path edit) (change-method edit)))
      ((register-when) (multimethod.register-when current (change-path edit) (change-predicate edit) (change-method edit)))
      ((erase) (multimethod.erase current (change-path edit))))))
(def (check generic watches)
  (unless (and (list? watches) (andmap watch? watches)) (error "invalid negative watches"))
  (for ((query watches) (position (in-range (length watches))))
    (def methods
      (try (multimethod.inspect generic (watch-kind query) (watch-value query))
        (catch (cause)
          (if (and (multimethod.dispatch-error? cause) (eq? (multimethod.dispatch-error-kind cause) 'arity))
            (raise (make-conflict position query 'arity #f)) (raise cause)))))
    (unless (null? methods) (raise (make-conflict position query 'method (car methods)))))
  (make-certificate generic (map identity watches)))
(def (guard previous edits)
  (def stage 'registration)
  (try
    (def candidate (patch (snapshot previous) edits))
    (set! stage 'negative)
    (values (check candidate (certificate-watches previous)) #f)
    (catch (cause) (values #f (make-failure stage cause)))))
(def (publish previous edits)
  (defvalues (next failure) (guard previous edits))
  (values (or next previous) failure))
(def (invoke previous . args)
  (defvalues (result next) (apply multimethod.call (snapshot previous) args))
  ;; Definition unchanged: reuse watches, no guard/body execution during checking.
  ;; Watched payloads, type/C4 graph and callbacks must be immutable/pure.
  (values result (if (eq? next (snapshot previous)) previous
                  (make-certificate next (certificate-watches previous)))))

;; Transport only the cache successor of explicit, body-free shape preparation.
;; The private preparation operation preserves definition and invoker identities,
;; so completed negative watches remain valid without executing them a second time.
(def (prepare-shape previous shape)
  (def next (multimethod.prepare-shape (snapshot previous) shape))
  (if (eq? next (snapshot previous)) previous (make-certificate next (certificate-watches previous))))
