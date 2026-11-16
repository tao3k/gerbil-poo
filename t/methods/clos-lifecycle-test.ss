;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; POO CLOS class, slot, and instance lifecycle conformance.

(import (only-in :std/test
                 test-suite test-case check-equal? check-exception check)
        (only-in :clan/poo/object .ref .o .get .put! .putslot! $thunk-slot-spec .slot? object? object-revision
                 replay-slot-reads! object-read-issued?)
        (only-in :clan/poo/mop clos-instance?)
        (only-in :clan/poo/slot-observation call-with-slot-read-observer)
        (only-in :clan/poo/number Integer)
        (only-in :clan/poo/type Record Type. Type define-type element? Any validate TypeError? Bool Fun)
        :std/error
        :clan/poo/mop)

(export clos-lifecycle-test)

(define-type (LifecycleInstance @ Type.) .element?: clos-instance?)

(def (failure-code? code)
  (lambda (error)
    (and (clos-failure? error)
         (eq? (.ref error 'code) code))))

(def (class-identities class-value)
  (map (lambda (entry) (.ref entry 'identity))
       (clos-class-precedence-list class-value)))

(def (slot-names class-value)
  (map (lambda (slot) (.ref slot 'identity))
       (clos-class-effective-slots class-value)))

(def clos-lifecycle-test
  (test-suite "POO CLOS class and instance lifecycle"
    (test-case "the public lifecycle predicate composes with the existing Type API"
      (def class-value (clos-class 'instance-predicate))
      (def instance (clos-make-instance class-value))
      (check (clos-instance? instance) => #t)
      (check (element? LifecycleInstance instance) => #t)
      (for-each
        (lambda (value)
          (check (clos-instance? value) => #f)
          (check (element? LifecycleInstance value) => #f))
        (list #f (.o) class-value (clos-generic-function 'predicate-generic 0))))

    (test-case "class descriptors and identities stay on the MOP spine"
      (let (class-value (clos-class 'runtime-mop-spine))
        (check (element? Type ClosClass) => #t)
        (check (eq? (.ref (.ref class-value 'instance-prototype)
                          '%clos-class)
                    class-value)
               => #t)
        (check (eq? (car (clos-class-precedence-list class-value))
                    class-value)
               => #t)))

    (test-case "lifecycle classes and effective slots share the POO contracts"
      (def calls 0)
      (def class-value
        (clos-class 'native-slot-contract
          direct-slots:
          (list (clos-direct-slot-definition
                 'value initargs: (list value:) type: Integer
                 initform: (lambda () (set! calls (+ calls 1)) 7)))))
      (check (element? Type class-value) => #t)
      (check (element? Class class-value) => #t)
      (check (element? Slot (clos-find-effective-slot class-value 'value)) => #t)
      (check-exception (.put! (.get class-value slots) 'value (.o)) Error?)
      (check-exception (.put! (.get class-value effective-slots) 'value (.o)) Error?)
      (check-exception (.put! (.get class-value effective-slots value) 'type Any) Error?)
      (def allocated (clos-allocate-instance class-value))
      (check calls => 0)
      (check (clos-slot-bound? allocated 'value) => #f)
      (check (element? class-value allocated) => #t)
      (check (validate class-value allocated) => allocated)
      (def initialized (clos-make-instance class-value))
      (check calls => 1)
      (check (.get initialized value) => 7)
      (check (element? class-value initialized) => #t)
      (def lazy-calls 0)
      (.putslot! initialized 'deferred
        ($thunk-slot-spec (lambda () (set! lazy-calls (+ lazy-calls 1)) 'ready)))
      (check (validate class-value initialized) => initialized)
      (check lazy-calls => 0)
      (check (.get initialized deferred) => 'ready)
      (check lazy-calls => 1))

    (test-case "omitted types stay absent without weakening inherited constraints"
      (def untyped
        (clos-class 'untyped-slot
          direct-slots: (list (clos-direct-slot-definition 'value initargs: (list value:)))))
      (def slot (clos-find-effective-slot untyped 'value))
      (check (.slot? slot 'type) => #f)
      (check (element? Slot slot) => #t)
      (check (element? ClosEffectiveSlotDefinition (.o (:: @ slot) type: #f)) => #f)
      (check (.get (clos-make-instance untyped value: 'dynamic) value) => 'dynamic)
      (def base
        (clos-class 'typed-parent
          direct-slots: (list (clos-direct-slot-definition
                               'value initargs: (list value:) type: Integer))))
      (def child
        (clos-class 'untyped-child direct-superclasses: (list base)
          direct-slots: (list (clos-direct-slot-definition 'value))))
      (def effective (clos-find-effective-slot child 'value))
      (check (.slot? effective 'type) => #t)
      (check (element? (.get effective type) 3) => #t)
      (check (element? (.get effective type) 'bad) => #f)
      (check-exception (clos-make-instance child value: 'bad) TypeError?)
      (def instance (clos-make-instance child value: 3))
      (check-exception (clos-set-slot-value! instance 'value 'bad) TypeError?)
      (check (.get instance value) => 3))

    (test-case "slot declarations retain native Type objects and their normalizers"
      (def calls 0)
      (define-type (Incremented @ Type.)
        .element?: integer?
        .validate: (lambda (value) (set! calls (+ calls 1)) (+ value 1)))
      (def direct (clos-direct-slot-definition 'value initargs: (list value:) type: Incremented))
      (def class-value (clos-class 'native-normalizer direct-slots: (list direct)))
      (check (eq? (.get direct type) Incremented) => #t)
      (set-car! (.get direct initargs) other:)
      (check-equal? (.get direct initargs) (list value:))
      (check-exception (.put! direct 'type Bool) Error?)
      (check (eq? (.get (clos-find-effective-slot class-value 'value) type) Incremented) => #t)
      (check-exception (clos-direct-slot-definition 'value type: integer?)
                       (failure-code? 'invalid-slot-type))
      (check-exception (clos-direct-slot-definition 'value type: #f)
                       (failure-code? 'invalid-slot-type))
      (def instance (clos-make-instance class-value value: 2))
      (check (.get instance value) => 3)
      (check calls => 1)
      (check (eq? (validate class-value instance) instance) => #t)
      (check calls => 1)
      (clos-set-slot-value! instance 'value 4)
      (check (.get instance value) => 5)
      (check calls => 2)
      (def order '())
      (define-type (ParentValue @ Type.)
        .element?: integer?
        .validate: (lambda (n) (set! order (cons 'parent order)) (+ n 1)))
      (define-type (ChildValue @ Type.)
        .element?: integer?
        .validate: (lambda (n) (set! order (cons 'child order)) (* n 2)))
      (def parent
        (clos-class 'normalization-parent
          direct-slots: (list (clos-direct-slot-definition 'value initargs: (list value:) type: ParentValue))))
      (def derived
        (clos-class 'normalization-child direct-superclasses: (list parent)
          direct-slots: (list (clos-direct-slot-definition 'value type: ChildValue))))
      (check (.get (clos-make-instance derived value: 3) value) => 7)
      (check-equal? (reverse order) '(child parent)))

    (test-case "Class Record and FUN slot types share native validation and cells"
      (def payload (Record count: [Integer]))
      (def command (Fun Integer <- Integer))
      (def child-class (clos-class 'contained-class))
      (def child (clos-make-instance child-class))
      (def prototype (.get child-class instance-prototype))
      (def class-value
        (clos-class 'native-compound-fields
          direct-slots:
          (list (clos-direct-slot-definition 'payload initargs: (list payload:) type: payload)
                (clos-direct-slot-definition 'command initargs: (list command:) type: command)
                (clos-direct-slot-definition 'child initargs: (list child:) type: child-class))))
      (check (eq? (.get child-class instance-prototype) prototype) => #t)
      (check-exception (.put! prototype '%clos-class class-value) Error?)
      (def instance
        (clos-make-instance class-value payload: (.o count: 3)
                           command: (lambda (n) (+ n 1)) child: child))
      (def wrapper (.get instance command))
      (check (element? class-value (.o %clos-state: #f)) => #f)
      (check-exception (validate class-value (.o %clos-state: #f)) TypeError?)
      (check (.get instance payload count) => 3)
      (check (eq? (.get instance child) child) => #t)
      (check (wrapper 3) => 4)
      (check-exception (wrapper 'bad) TypeError?)
      (check (eq? (validate class-value instance) instance) => #t)
      (check (eq? wrapper (.get instance command)) => #t)
      (check (eq? wrapper (clos-slot-value instance 'command)) => #t)
      (check-exception (clos-set-slot-value! instance 'payload (.o count: 'bad)) TypeError?))

    (test-case "normalizer failure and edited Type evidence cannot publish a cell"
      (def armed #f)
      (define-type (Changing @ Type.)
        .validate: identity
        .element?: (lambda (_)
                     (when armed (.put! Changing '.validate identity)) #t))
      (def class-value
        (clos-class 'normalizer-publication
          direct-slots: (list (clos-direct-slot-definition
                               'value initargs: (list value:) type: Changing))))
      (def instance (clos-make-instance class-value value: 1))
      (def cell (hash-get (.ref (.ref instance '%clos-state) 'storage) 'value))
      (def revision (object-revision cell))
      (set! armed #t)
      (check-exception (clos-set-slot-value! instance 'value 2) Error?)
      (check (object-revision cell) => revision)
      (check (.ref cell 'value) => 1)
      (set! armed #f)
      (.put! Changing '.element? integer?)
      (.put! Changing '.validate (lambda (_) 'invalid-result))
      (check-exception (clos-set-slot-value! instance 'value 3) TypeError?)
      (check (object-revision cell) => revision)
      (check (.ref cell 'value) => 1)
      (check-exception
        (clos-class 'invalid-shared-normalizer
          direct-slots: (list (clos-direct-slot-definition
                               'value allocation: 'class type: Changing initform: (lambda () 1))))
        TypeError?)
      (check (clos-find-class 'invalid-shared-normalizer error?: #f) => #f)
      (def cause (.o failure: 'native-type))
      (.put! Changing '.validate (lambda (_) (raise cause)))
      (check-exception (clos-set-slot-value! instance 'value 3)
                       (lambda (failure) (eq? failure cause)))
      (check (object-revision cell) => revision)
      (check (.ref cell 'value) => 1))

    (test-case "Slot rejection leaves the bound cell and generation unchanged"


      (def class-value
        (clos-class 'checked-cell
          direct-slots: (list (clos-direct-slot-definition
                               'value initargs: (list value:) type: Integer))))
      (def instance (clos-make-instance class-value value: 1))
      (def state (.ref instance '%clos-state))
      (def cell (hash-get (.ref state 'storage) 'value))
      (def revision (object-revision cell))
      (def generation (.ref state 'generation))
      (check-exception (clos-set-slot-value! instance 'value 'bad) TypeError?)
      (check (clos-slot-value instance 'value) => 1)
      (check (object-revision cell) => revision)
      (check (.ref state 'generation) => generation)
      (check-exception (clos-make-instance class-value value: 'bad) TypeError?))

    (test-case "native get observes the same cell and its invalidation"
      (def class-value
        (clos-class 'reflected-cell
          direct-slots: (list (clos-direct-slot-definition 'value initargs: (list value:)))))
      (def instance (clos-make-instance class-value value: 1))
      (def reads '())
      (call-with-slot-read-observer
        (lambda (read) (set! reads (cons read reads)))
        (lambda () (check (.get instance value) => 1)))
      (check (andmap object-read-issued? reads) => #t)
      (replay-slot-reads! (reverse reads) void)
      (clos-set-slot-value! instance 'value 2)
      (check (.get instance value) => 2)
      (check-exception (replay-slot-reads! (reverse reads) void) (lambda (_) #t))
      (clos-slot-makunbound! instance 'value)
      (check (.slot? instance 'value) => #f)
      (check-exception (.get instance value) clos-unbound-slot?)
      (def migrations 0)
      (clos-redefine-class class-value
        direct-slots: (list (clos-direct-slot-definition
                             'added initform: (lambda ()
                                                (set! migrations (+ migrations 1)) 3))))
      (check (element? class-value instance) => #f)
      (check-exception (.get instance added) (failure-code? 'instance-update-required))
      (check migrations => 0)
      (check (clos-slot-value instance 'added) => 3)
      (check (.get instance added) => 3)
      (check migrations => 1))

    (test-case "the complete initializer combination precedes final Class checks"
      (def class-value
        (clos-class 'complete-initialization
          direct-slots: (list (clos-direct-slot-definition
                               'value initargs: (list value:) type: Integer))))
      (def corrupt
        (clos-method 'corrupt-initialized-value
          (list (clos-class-specializer class-value))
          (lambda (_frame instance . _args)
            (.put! (hash-get (.ref (.ref instance '%clos-state) 'storage) 'value)
                   'value 'bad))
          qualifier: 'after
          lambda-list: (clos-lambda-list 1 0 #t #f '() #f)))
      (dynamic-wind
        (lambda () (clos-add-method clos-initialize-instance-generic corrupt))
        (lambda ()
          (check-exception (clos-make-instance class-value value: 1) TypeError?))
        (lambda () (clos-remove-method clos-initialize-instance-generic corrupt))))

    (test-case "a final validator cannot publish evidence from before its callback edit"
      (def current-instance #f)
      (def effects 0)
      (define-type (ObservedValue @ Type.)
        .element?: (lambda (value)
                     (when current-instance
                       (set! effects (+ effects 1))
                       (.put! (hash-get (.ref (.ref current-instance '%clos-state) 'storage)
                                        'value)
                              'value 'changed-during-check))
                     (integer? value)))
      (def class-value
        (clos-class 'validation-effect-boundary
          direct-slots: (list (clos-direct-slot-definition
                               'value initargs: (list value:) type: ObservedValue))))
      (def expose
        (clos-method 'expose-for-final-check
          (list (clos-class-specializer class-value))
          (lambda (_frame instance . _args) (set! current-instance instance))
          qualifier: 'after
          lambda-list: (clos-lambda-list 1 0 #t #f '() #f)))
      (dynamic-wind
        (lambda () (clos-add-method clos-initialize-instance-generic expose))
        (lambda ()
          (check-exception (clos-make-instance class-value value: 1) Error?)
          (check effects => 1))
        (lambda () (clos-remove-method clos-initialize-instance-generic expose))))

    (test-case "POO C4 closes a diamond and effective slot options merge"


      (let* ((root-slot
              (clos-direct-slot-definition
               'payload initargs: (list root:)
               initform: (lambda () 'root)))
             (left-slot
              (clos-direct-slot-definition
               'payload initargs: (list left:)))
             (right-slot
              (clos-direct-slot-definition
               'payload initargs: (list right:)
               initform: (lambda () 'right)))
             (root (clos-class 'root direct-slots: (list root-slot)))
             (left (clos-class 'left direct-superclasses: (list root)
                                   direct-slots: (list left-slot)))
             (right (clos-class 'right direct-superclasses: (list root)
                                    direct-slots: (list right-slot)))
             (leaf (clos-class 'leaf
                                   direct-superclasses: (list left right)))
             (effective (clos-find-effective-slot leaf 'payload))
             (instance-value (clos-make-instance leaf)))
        (check-equal? (class-identities leaf)
                      '(leaf left right root standard-object))
        (check-equal? (slot-names leaf) '(payload))
        (check-equal? (.ref effective 'allocation) 'instance)
        (check-equal? (.ref effective 'initargs) (list left: right: root:))
        (check-equal? (map (lambda (entry) (.ref entry 'identity))
                           (.ref effective 'defining-classes))
                      '(left right root))
        (check-equal? (clos-slot-value instance-value 'payload) 'right)
        (check (clos-class-subclass? leaf root) => #t)))

    (test-case "POO C4 preserves monotonic pedalo precedence"
      ;; Barrett et al., figure 2, separates the historical ANSI topological
      ;; order from C4. POO CLOS intentionally uses prototype
      ;; linearization, so day-boat remains before wheel-boat in pedalo.
      (let* ((boat (clos-class 'boat))
             (day-boat
              (clos-class 'day-boat direct-superclasses: (list boat)))
             (wheel-boat
              (clos-class 'wheel-boat direct-superclasses: (list boat)))
             (engineless
              (clos-class 'engineless
                              direct-superclasses: (list day-boat)))
             (pedal-wheel-boat
              (clos-class
               'pedal-wheel-boat
               direct-superclasses: (list engineless wheel-boat)))
             (small-multihull
              (clos-class 'small-multihull
                              direct-superclasses: (list day-boat)))
             (small-catamaran
              (clos-class 'small-catamaran
                              direct-superclasses: (list small-multihull)))
             (pedalo
              (clos-class
               'pedalo
               direct-superclasses: (list pedal-wheel-boat
                                           small-catamaran))))
        (check-equal?
         (class-identities pedal-wheel-boat)
         '(pedal-wheel-boat engineless day-boat wheel-boat boat
                            standard-object))
        (check-equal?
         (class-identities small-catamaran)
         '(small-catamaran small-multihull day-boat boat standard-object))
        (check-equal?
         (class-identities pedalo)
         '(pedalo pedal-wheel-boat engineless small-catamaran
                  small-multihull day-boat wheel-boat boat standard-object))))

    (test-case "explicit and default initargs precede initforms with leftmost wins"
      (let ((default-count 0)
            (initform-count 0))
        (def slot
          (clos-direct-slot-definition
           'value initargs: (list first: second:)
           initform: (lambda ()
                       (set! initform-count (+ initform-count 1))
                       'from-initform)))
        (def class-value
          (clos-class
           'initialized direct-slots: (list slot)
           default-initargs:
           (list (cons second:
                       (lambda ()
                         (set! default-count (+ default-count 1))
                         'from-default)))))
        (let ((explicit
               (clos-make-instance class-value first: 'explicit
                                       second: 'ignored))
              (defaulted (clos-make-instance class-value)))
          (check-equal? (clos-slot-value explicit 'value) 'explicit)
          (check-equal? (clos-slot-value defaulted 'value) 'from-default)
          (check-equal? default-count 1)
          (check-equal? initform-count 0))))

    (test-case "class names and aliases redispatch the make-instance generic"
      (def pane (clos-class 'redispatch-pane))
      (clos-set-find-class! pane 'redispatch-alias)
      (def events '())
      (def extension
        (clos-method 'class-specific-construction
          (list (clos-eql-specializer pane))
          (lambda (_frame class-value . _args) (set! events (cons class-value events)))
          qualifier: 'after lambda-list: (clos-lambda-list 1 0 #t #f '() #f)))
      (dynamic-wind
        (lambda () (clos-add-method clos-make-instance-generic extension))
        (lambda ()
          (for-each
            (lambda (designator)
              (check (clos-class-of (clos-make-instance designator)) => pane))
            (list pane 'redispatch-pane 'redispatch-alias))
          (check-equal? events (list pane pane pane)))
        (lambda () (clos-remove-method clos-make-instance-generic extension))))

    (test-case "class names are registered ANSI class designators"
      (let* ((source (clos-class 'registered-source))
             (target (clos-class 'registered-target))
             (instance (clos-make-instance 'registered-source)))
        (check (eq? (clos-find-class 'registered-source) source) => #t)
        (check-equal? (clos-find-class 'missing-class error?: #f) #f)
        (check (eq? (clos-class-of instance) source) => #t)
        (check (eq? (clos-change-class instance 'registered-target)
                    instance)
               => #t)
        (check (eq? (clos-class-of instance) target) => #t)
        (check (eq? (clos-set-find-class! source 'registered-alias)
                    source) => #t)
        (check (eq? (clos-find-class 'registered-alias) source) => #t)
        (check-equal? (clos-set-find-class! #f 'registered-alias) #f)
        (check-equal? (clos-find-class 'registered-alias error?: #f) #f)
        (check-equal? (clos-set-class-name! 'renamed-source source)
                      'renamed-source)
        (check-equal? (clos-class-name source) 'renamed-source)
        ;; Naming and association are independent until FIND-CLASS is set.
        (check (eq? (clos-find-class 'registered-source) source) => #t)
        (check-equal? (clos-find-class 'renamed-source error?: #f) #f)
        (clos-set-find-class! source 'renamed-source)
        (check (eq? (clos-find-class 'renamed-source) source) => #t)
        (check-exception (clos-make-instance 'missing-class)
                         (failure-code? 'class-not-found))))

    (test-case "standard lifecycle entry points are extensible generic functions"
      (let* ((slot
              (clos-direct-slot-definition
               'initialized initform: (lambda () 'default)))
             (class-value
              (clos-class 'custom-initialization direct-slots: (list slot)))
             (method
              (clos-method
               'custom-initialize
               (list (clos-class-specializer class-value))
               (lambda (frame instance-value . initargs)
                 (apply clos-call-next-method
                        frame instance-value initargs)
                 (clos-set-slot-value!
                  instance-value 'initialized (cadr initargs)))
               lambda-list:
               (clos-lambda-list 1 0 #f #t (list custom:) #f))))
        (clos-add-method clos-initialize-instance-generic method)
        (let (instance (clos-make-instance class-value custom: 'custom))
          (check-equal? (clos-slot-value instance 'initialized) 'custom)
          (check (eq? (clos-method-generic-function method)
                      clos-initialize-instance-generic)
                 => #t)
          (check-equal?
           (call-with-values
            (lambda () (clos-function-keywords method)) list)
           (list (list custom:) #f)))))

    (test-case "class-allocated cells are shared and a redefining subclass owns a new cell"
      (let (class-init-count 0)
        (def shared-slot
          (clos-direct-slot-definition
           'counter allocation: 'class initform:
           (lambda ()
             (set! class-init-count (+ class-init-count 1))
             10)))
        (def base
          (clos-class 'shared-base direct-slots: (list shared-slot)))
        (def inherited
          (clos-class 'shared-child direct-superclasses: (list base)))
        (def replacement-slot
          (clos-direct-slot-definition 'counter allocation: 'class))
        (def replaced
          (clos-class 'replaced-child direct-superclasses: (list base)
                          direct-slots: (list replacement-slot)))
        (let ((one (clos-make-instance base))
              (two (clos-make-instance inherited))
              (three (clos-make-instance replaced)))
          (check-equal? class-init-count 2)
          (check-equal? (clos-slot-value one 'counter) 10)
          (clos-set-slot-value! two 'counter 11)
          (check-equal? (clos-slot-value one 'counter) 11)
          (check-equal? (clos-slot-value three 'counter) 10)
          (clos-set-slot-value! three 'counter 30)
          (check-equal? (clos-slot-value two 'counter) 11)
          (check-equal? (clos-slot-value three 'counter) 30))))

    (test-case "bound state and missing or unbound hooks have exact operations"
      (let (events '())
        (def plain-slot (clos-direct-slot-definition 'plain))
        (def hooked
          (clos-class
           'hooked direct-slots: (list plain-slot)
           slot-missing-handler:
           (lambda (_class _instance slot operation . values)
             (set! events (append events (list (list slot operation values))))
             (eq? operation 'slot-boundp))
           slot-unbound-handler:
           (lambda (_class _instance slot)
             (set! events (append events (list (list slot 'slot-unbound))))
             'unbound-value)))
        (let (instance-value (clos-make-instance hooked))
          (check-equal? (clos-slot-bound? instance-value 'plain) #f)
          (check-equal? (clos-slot-value instance-value 'plain)
                        'unbound-value)
          (check-equal? (clos-slot-bound? instance-value 'missing) #t)
          (check-equal? (clos-slot-value instance-value 'missing) #f)
          (clos-set-slot-value! instance-value 'missing 8)
          (clos-slot-makunbound! instance-value 'missing)
          (check-equal?
           events
           '((plain slot-unbound)
             (missing slot-boundp ())
             (missing slot-value ())
             (missing setf (8))
             (missing slot-makunbound ()))))))

    (test-case "default hooks raise typed failures and makunbound preserves identity"
      (let* ((slot (clos-direct-slot-definition 'state))
             (class-value (clos-class 'plain direct-slots: (list slot)))
             (instance-value (clos-allocate-instance class-value)))
        (check (object? instance-value) => #t)
        (check (clos-instance? instance-value) => #t)
        (check (eq? (clos-class-of instance-value) class-value) => #t)
        (check-exception (clos-slot-value instance-value 'state)
                         (failure-code? 'slot-unbound))
        (check-exception (clos-slot-value instance-value 'absent)
                         (failure-code? 'slot-missing))
        (clos-set-slot-value! instance-value 'state #f)
        (check-equal? (clos-slot-bound? instance-value 'state) #t)
        (check-equal? (clos-slot-value instance-value 'state) #f)
        (check (eq? (clos-slot-makunbound! instance-value 'state)
                    instance-value) => #t)
        (check-equal? (clos-slot-bound? instance-value 'state) #f)))

    (test-case "unbound slot failures retain their condition subtype and instance"
      (let* ((slot (clos-direct-slot-definition 'state))
             (class-value
              (clos-class 'typed-unbound-slot direct-slots: (list slot)))
             (instance-value (clos-allocate-instance class-value))
             (condition #f))
        (with-exception-catcher
         (lambda (failure) (set! condition failure))
         (lambda () (clos-slot-value instance-value 'state)))
        (check (clos-failure? condition) => #t)
        (check (clos-unbound-slot? condition) => #t)
        (check (eq? (clos-unbound-slot-instance condition)
                    instance-value) => #t)
        (check-equal? (.ref condition 'slot) 'state)))

    (test-case "slot-missing and slot-unbound are ordinary mutable generics"
      (let* ((slot (clos-direct-slot-definition 'state))
             (class-value
              (clos-class 'generic-slot-protocol
                              direct-slots: (list slot)))
             (instance-value (clos-allocate-instance class-value))
             (slot-missing-method
              (clos-method
               'generic-slot-protocol/missing
               (list (clos-eql-specializer class-value)
                     (clos-any-specializer)
                     (clos-any-specializer)
                     (clos-any-specializer))
               (lambda (_frame _class _instance slot-name operation . values)
                 (list slot-name operation values))
               lambda-list: (clos-lambda-list 4 1 #f #f '() #f)))
             (slot-unbound-method
              (clos-method
               'generic-slot-protocol/unbound
               (list (clos-eql-specializer class-value)
                     (clos-any-specializer)
                     (clos-any-specializer))
               (lambda (_frame _class _instance slot-name)
                 (list slot-name 'unbound))
               lambda-list: (clos-lambda-list 3 0 #f #f '() #f))))
        (clos-add-method clos-slot-missing-generic
                             slot-missing-method)
        (clos-add-method clos-slot-unbound-generic
                             slot-unbound-method)
        (check-equal? (clos-slot-value instance-value 'absent)
                      '(absent slot-value ()))
        (check-equal? (clos-slot-value instance-value 'state)
                      '(state unbound))
        (check (eq? (clos-method-generic-function slot-unbound-method)
                    clos-slot-unbound-generic) => #t)
        (clos-remove-method clos-slot-missing-generic
                                slot-missing-method)
        (clos-remove-method clos-slot-unbound-generic
                                slot-unbound-method)))

    (test-case "reinitialize uses initargs only while shared-initialize can rerun initforms"
      (let (init-count 0)
        (def slot
          (clos-direct-slot-definition
           'state initargs: (list state:)
           initform: (lambda ()
                       (set! init-count (+ init-count 1))
                       init-count)))
        (def class-value
          (clos-class 'reinitializable direct-slots: (list slot)))
        (let (instance-value (clos-make-instance class-value))
          (check-equal? (clos-slot-value instance-value 'state) 1)
          (clos-reinitialize-instance instance-value)
          (check-equal? init-count 1)
          (clos-reinitialize-instance instance-value state: 9)
          (check-equal? (clos-slot-value instance-value 'state) 9)
          (clos-slot-makunbound! instance-value 'state)
          (clos-reinitialize-instance instance-value)
          (check-equal? (clos-slot-bound? instance-value 'state) #f)
          (clos-shared-initialize instance-value '(state))
          (check-equal? (clos-slot-value instance-value 'state) 2))))

    (test-case "reader and writer methods participate in ordinary multiple dispatch"
      (let* ((slot
              (clos-direct-slot-definition
               'name initargs: (list name:)
               readers: '(name-of) writers: '(set-name)))
             (class-value
              (clos-class 'named direct-slots: (list slot)))
             (instance-value
              (clos-make-instance class-value name: 'old))
             (reader
              (clos-add-method
               (clos-generic-function 'name-of 1)
               (clos-slot-reader-method class-value 'name 'read-name)))
             (writer
              (clos-add-method
               (clos-generic-function 'set-name 2)
               (clos-slot-writer-method class-value 'name 'write-name))))
        (check-equal? (clos-call reader instance-value) 'old)
        (check-equal? (clos-call writer 'new instance-value) 'new)
        (check-equal? (clos-call reader instance-value) 'new)))

    (test-case "rejected C4 redefinition leaves the live class and edges intact"
      (let* ((x (clos-class 'redefine-precedence-x))
             (y (clos-class 'redefine-precedence-y))
             (xy (clos-class 'redefine-precedence-xy
                                 direct-superclasses: (list x y)))
             (yx (clos-class 'redefine-precedence-yx
                                 direct-superclasses: (list y x)))
             (current (clos-class 'redefine-precedence-current
                                      direct-superclasses: (list xy)))
             (prototype (.ref current 'instance-prototype))
             (generation (clos-class-generation current)))
        (check-exception
         (clos-redefine-class current direct-superclasses: (list xy yx))
         (failure-code? 'inconsistent-class-precedence))
        (check (eq? (.ref current 'instance-prototype) prototype) => #t)
        (check-equal? (clos-class-generation current) generation)
        (check-equal? (class-identities current)
                      '(redefine-precedence-current redefine-precedence-xy
                        redefine-precedence-x redefine-precedence-y
                        standard-object))
        (check (if (memq current (.ref xy 'direct-subclasses)) #t #f)
               => #t)
        (check (memq current (.ref yx 'direct-subclasses)) => #f)))

    (test-case "invalid declarations and initialization arguments fail before effects"
      (let (slot (clos-direct-slot-definition 'only initargs: (list only:)))
        (check-exception
         (clos-direct-slot-definition 'bad allocation: 'dynamic)
         (failure-code? 'invalid-slot-allocation))
        (check-exception
         (clos-direct-slot-definition 'bad initargs: '((setf only)) writers: '((setf . writer)))
         (failure-code? 'invalid-slot-initargs))
        (check-exception
         (clos-direct-slot-definition 'bad writers: '((setf . writer)))
         (failure-code? 'invalid-slot-accessors))
        (check-exception
         (clos-class 'bad-default
           default-initargs: (list (cons '(setf only) (lambda () 1))))
         (failure-code? 'invalid-default-initargs))
        (check-equal? (.ref (clos-lambda-list 0 0 #f #t (list 'one two:) #f) 'keys)
                      (list 'one two:))
        (check-exception
         (clos-lambda-list 0 0 #f #t '((setf name)) #f)
         (failure-code? 'invalid-lambda-list))
        (check-exception
         (clos-class 'duplicates direct-slots: (list slot slot))
         (failure-code? 'duplicate-direct-slot))
        (let (class-value
              (clos-class 'strict-initargs direct-slots: (list slot)))
          (check-exception (clos-make-instance class-value unknown: 1)
                           (failure-code? 'invalid-initialization-argument))
          (check-exception
           (apply clos-make-instance class-value
             (list 'allow-other-keys #f allow-other-keys: #t unknown: 1))
           (failure-code? 'invalid-initialization-argument))
          (let (instance-value (clos-make-instance class-value only: 1))
            (check (clos-slot-exists? instance-value 'only) => #t)
            (check (clos-slot-exists? instance-value 'missing) => #f))
          (check-exception (apply clos-make-instance
                                  (list class-value only:))
                           (failure-code? 'malformed-initialization-arguments))
          (check-exception (apply clos-make-instance class-value '((setf only) 1))
                           (failure-code? 'malformed-initialization-arguments))
          (check (clos-instance?
                  (clos-make-instance
                   class-value unknown: 1 allow-other-keys: #t
                   'allow-other-keys #f))
                 => #t)))
      (let* ((slot (clos-direct-slot-definition
                    'aliased initargs: (list primary: alias:)))
             (class-value (clos-class 'indexed-initargs
                            direct-slots: (list slot)))
             (leftmost-alias
              (clos-make-instance class-value alias: 'first primary: 'second))
             (leftmost-duplicate
              (clos-make-instance class-value primary: 'first primary: 'second)))
        ;; The linear index preserves the previous leftmost argument behavior,
        ;; including when multiple initarg aliases name the same slot.
        (check-equal? (clos-slot-value leftmost-alias 'aliased) 'first)
        (check-equal? (clos-slot-value leftmost-duplicate 'aliased) 'first))
      (let* ((x (clos-class 'precedence-x))
             (y (clos-class 'precedence-y))
             (xy (clos-class 'precedence-xy
                                 direct-superclasses: (list x y)))
             (yx (clos-class 'precedence-yx
                                 direct-superclasses: (list y x))))
        ;; The CLOS boundary
        ;; translates its rejection without recomputing precedence.
        (check-exception
         (clos-class 'inconsistent
                         direct-superclasses: (list xy yx))
         (lambda (error)
           (and (clos-failure? error)
                (eq? (.ref error 'code)
                     'inconsistent-class-precedence))))))))
