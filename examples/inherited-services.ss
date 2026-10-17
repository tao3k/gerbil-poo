;;; Shared declaration revisions across inherited service branches and their join.
(export make-services report revision-action protocol-action)
(import ../object ../mop ../number ../brace ../reflection ../inheritance-hooks
        (prefix-in ../generalized-prototype gp.))
;; Derive an audited protocol using ordinary inherited method continuations.
;; Compilation is lazy with respect to slot bodies; the log runs only on demand.
(def (service-protocol log)
  (def inherited (.o
    (compute-precedence-list (lambda (_ next) (next)))
    (compute-slot (lambda (_ next slot) (next)))))
  (.o (:: @ inherited)
    (compute-slot (super)
      (lambda (self next slot)
        (def body ((super) self next slot))
        (lambda () (log slot) (body))))))
;; A shared root, two service branches and a diamond join retain one metadata
;; source. The private computation must remain unforced during public reflection.
(def (make-services log private-body)
  (def amount (instance Slot type: Integer default: 10))
  (def secret (instance Slot hidden: #t compute: (lambda (_ inherited) (private-body))))
  (def source (object<-declarations [(cons 'amount amount) (cons 'secret secret)]))
  (def protocol (service-protocol log))
  (def billing (with-inheritance-hooks protocol source))
  (def risk (with-inheritance-hooks protocol source))
  (object<-alist (list (cons 'source source) (cons 'amount amount)
    (cons 'billing billing) (cons 'risk risk) (cons 'join (.mix billing risk)))))
;; Public reads use current metadata on each branch; private slots are never read.
(def (report services)
  (map (lambda (name) (read-slot (.ref services name) 'amount)) '(billing risk join)))
;; Reader/FUN chaining validates one shared revision before all branch observations.
;; A refused value or sealed source publishes no edit; arbitrary I/O is not undone.
(def (revision-action amount)
  (.call gp.Observation. .map report
    (lambda (services) (write-slot! (.@ services source) 'amount amount) services)))

;; Reconfigure the billing branch through the checked mutation boundary, then
;; observe all services through FUN. The join selects billing's current complete
;; protocol; risk keeps its own protocol. Refusal never reaches report.
(def (protocol-action protocol)
  (.call gp.Observation. .map report
    (lambda (services) (object-protocol-set! (.@ services billing) protocol) services)))
