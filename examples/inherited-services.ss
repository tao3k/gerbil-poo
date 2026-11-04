;;; Shared declaration revisions across inherited service branches and their join.
(export make-services report revision-action protocol-action combined-action precedence-workflow precedence-cache-workflow callback-workflow query-workflow read-key-workflow)
(import (only-in :std/error contract-violation-error?)
        (only-in ../slot-observation call-with-slot-read-observer slot-read-key slot-read-receiver)
        ../object
        ../mop
        ../number
        ../brace
        ../reflection
        (only-in ../type List)
        (runtime: :clan/poo/fun)
        (runtime: :clan/poo/method-combination)
        (prefix-in (only-in ../method-combination compile-simula-context
                   simula-body) combination.)
        (prefix-in (only-in :clan/poo/fun Observation.) fun.))
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
  (.call fun.Observation. .map report
    (lambda (services) (write-slot! (.@ services source) 'amount amount) services)))

;; Reconfigure the billing branch through the checked mutation boundary, then
;; observe all services through FUN. The join selects billing's current complete
;; protocol; risk keeps its own protocol. Refusal never reaches report.
(def (protocol-action protocol)
  (.call fun.Observation. .map report
    (lambda (services) (object-protocol-set! (.@ services billing) protocol) services)))

;; Prepare one Simula program, then reuse it as a FUN action across service
;; families. Callbacks read CURRENT public metadata; only code is retained.
;; General-first checks precede specific-first settlement. Refusal stops the
;; remaining callbacks; previously emitted observations are not rolled back.
(def (combined-action units emit)
  (def program (combination.compile-simula-context
    (map (lambda (name)
      (combination.simula-body
        (lambda (requested services)
          (def amount (read-slot (.ref services name) 'amount))
          (unless (>= amount requested) (error "insufficient service capacity" name))
          (emit (list 'check name requested amount)))
        (lambda (requested services)
          (emit (list 'settle name requested (read-slot (.ref services name) 'amount))))))
      '(billing risk join))))
  (.call fun.Observation. .map report
    (lambda (services) (program services (list units)) services)))

;; Retained MOP/public snapshots are editable observations, never cached C3 cells.
;; A shared declaration diamond still supports FUN revision and public reflection
;; after callers overwrite every retained hook spine. No private field is demanded.
(def (precedence-workflow)
  (def family (make-services (lambda (_) (void)) (lambda () (error "private body forced"))))
  (def saved [])
  (def protocol (.o (compute-precedence-list (lambda (_ next)
    (def snapshot (next))
    (set! saved (cons snapshot saved)) snapshot))))
  (def initial ((protocol-action protocol) family))
  (def join (.ref family 'join))
  (def public (compute-precedence-list! join))
  (for-each (lambda (snapshot) (set-car! snapshot (.o rogue: #t))) (cons public saved))
  (unless (eq? (car (compute-precedence-list! join)) join) (error "C3 snapshot escaped"))
  (list initial ((revision-action 20) family)))

;; Current C3 snapshots accompany FUN revisions on one shared-service diamond.
;; Inspect is a benchmark/example strategy, never a persisted admission verdict.
;; The refused cycle leaves warm order intact; a later supported edit rebuilds it.
(def (precedence-cache-workflow (inspect compute-precedence-list!))
  ;; let* owns effect order: warm, observe, refuse, revise, then observe again.
  (let* ((family (make-services (lambda (_) (void)) (lambda () (error "private body forced"))))
         (join (.ref family 'join))
         (source (.ref family 'source))
         (first (inspect join))
         (before (begin
           (unless (and (eq? (car first) join) (equal? (inspect join) first))
             (error "warm C3 order oracle"))
           (report family)))
         (refused (with-catch (lambda (_) #t)
           (lambda () (object-supers-set! source [join]) #f)))
         (after (begin
           (unless (and refused (equal? (inspect join) first)) (error "C3 refusal oracle"))
           ((revision-action 20) family))))
    (unless (equal? (inspect join) first) (error "C3 rebuilt identity oracle"))
    (list before after)))

;; Shared callback metadata is compiled once into the ordinary declaration
;; diamond. FUN installs the recursively checked list; reflective reads retain
;; argument/result contracts on every branch. A refused replacement keeps the
;; current revision and inline read credentials; retry invalidates old reads.
(def (callback-workflow)
  (def signature (List (Fun Integer <- Integer)))
  (def slot (instance Slot type: signature default: (list (lambda (n) (+ n 1)))))
  (def root (object<-declarations (list (cons 'handlers slot))))
  (def left (.mix root))
  (def right (.mix root))
  (def join (.mix left right))
  ;; One Observation chain publishes the checked result before branch consumers.
  (def action (.call fun.Observation. .map
    (lambda (_) (map (lambda (owner) ((car (read-slot owner 'handlers)) 10))
                   (list left right join)))
    (lambda (callbacks) (write-slot! root 'handlers callbacks))))
  (def first (action (list (lambda (n) (+ n 1)))))
  (def revision (object-revision root))
  (unless (with-catch (lambda (_) #t) (lambda () (action (list #f)) #f))
    (error "invalid callback accepted"))
  (unless (= revision (object-revision root)) (error "refused write changed source"))
  (list first (action (list (lambda (n) (+ n 12))))))

;; One FUN query crosses structural presence and current declared reflection on
;; the shared service diamond. Malformed names cannot enter either protocol or
;; deliver a result; an explicit revision retires old observations before retry.
(def (query-workflow)
  (def family (make-services (lambda (_) (void)) (lambda () (error "private body forced"))))
  (def join (.ref family 'join))
  (def delivered 0)
  (def reads [])
  (def action (.call fun.Observation. .map
    (lambda (value) (set! delivered (1+ delivered)) value)
    (lambda (name)
      (unless (.slot? join name) (error "undeclared service field"))
      (read-slot join name))))
  (def first (call-with-slot-read-observer (lambda (read) (set! reads (cons read reads)))
    (lambda () (action 'amount))))
  ;; Catch only standard grammar refusals; unrelated callback failures propagate.
  (for-each (lambda (bad)
    (unless (with-catch (lambda (cause)
                        (if (contract-violation-error? cause) #t (raise cause)))
              (lambda () (action bad) #f))
      (error "malformed service query accepted"))) (list #f 17 "amount" amount:))
  (unless (and (= delivered 1) (andmap object-read-current? reads))
    (error "refused service query changed observation"))
  ((revision-action 20) family)
  (let ((retired? (not (andmap object-read-current? reads))) (last (action 'amount)))
    (vector first last delivered retired?)))


;; Observe the shared declaration diamond through FUN. Consumers can edit
;; both observation and replay keys. An explicit receiver edit retires the
;; structural read before the same loaded service queries the new value.
(def (read-key-workflow)
  (def family (make-services void (lambda () (error "private body forced"))))
  (def join (.ref family 'join))
  (def roots [])
  (def action (.call fun.Observation. .map
    (lambda (owner) (read-slot owner 'amount))
    (lambda (owner) (unless (.slot? owner 'amount) (error "missing amount")) owner)))
  (def first (call-with-slot-read-observer
    (lambda (read)
      (let (key (slot-read-key read))
        (when (and (eq? (slot-read-receiver read) join)
                   (equal? key '(presence amount)))
          (set! roots (cons read roots))
          (set-car! (cdr key) 'private))))
    (cut action join)))
  (unless (pair? roots) (error "missing presence read"))
  (replay-slot-reads! roots
    (lambda (_ key) (when (equal? key '(presence amount)) (set-car! key 'client))))
  ((revision-action 20) family)
  ;; Updating the source value does not itself change the join's inventory.
  ;; Publish a receiver override before checking the issued structural epoch.
  (.put! join 'amount 20)
  (let (retired? (not (ormap object-read-current? roots)))
    (list first (action join) retired?)))
