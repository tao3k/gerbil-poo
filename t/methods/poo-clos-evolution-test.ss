;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; POO CLOS class evolution, identity, and reflection conformance.

(import (only-in :std/test
                 test-suite test-case check-equal? check-exception check)
        (only-in :clan/poo/object .ref .put! seal-object! object-revision replay-slot-reads!)
        (only-in :clan/poo/slot-observation call-with-slot-read-observer slot-read-receiver slot-read-key slot-read-value slot-read-instance)
        :clan/poo/mop)

(export poo-clos-evolution-test)

(def (failure-code? code)
  (lambda (error)
    (and (poo-clos-failure? error)
         (eq? (.ref error 'code) code))))

(def (check-instance-publication operation)
  (def old-class
    (poo-clos-class 'instance-publication-old
      direct-slots: (list (poo-clos-direct-slot-definition 'old))))
  (def new-slots (list (poo-clos-direct-slot-definition 'new)))
  (def instance (poo-clos-make-instance old-class))
  (def state (.ref instance '%poo-clos-state))
  (def next-class
    (if (eq? operation 'redefine)
      (poo-clos-redefine-class old-class direct-slots: new-slots)
      (poo-clos-redefine-class
       (poo-clos-class 'instance-publication-new) direct-slots: new-slots)))
  (def (snapshot)
    (let (storage (.ref state 'storage))
      (list (eq? (.ref state 'class) next-class)
            (.ref state 'generation)
            (hash-key? storage 'old) (hash-key? storage 'new))))
  (def before (snapshot))
  (def after (list #t (poo-clos-class-generation next-class) #f #t))
  (def seen '())
  (call-with-slot-read-observer
    void
    (lambda ()
      (if (eq? operation 'redefine)
        (poo-clos-slot-bound? instance 'new)
        (poo-clos-change-class instance next-class)))
    before:
    (lambda (_receiver key)
      (when (memq key (quote (class generation storage)))
        (set! seen (cons (snapshot) seen)))))
  (check-equal? (snapshot) after)
  (check-equal? (and (member before seen) #t) #t)
  (check-equal? (and (member after seen) #t) #t)
  (check-equal? (andmap (lambda (entry) (or (equal? entry before) (equal? entry after))) seen)
                #t))

(def poo-clos-evolution-test
  (test-suite "POO CLOS class evolution"
    (test-case "lazy migration publishes one complete instance layout"
      (check-instance-publication (quote redefine)))
    (test-case "change-class publishes one complete instance layout"
      (check-instance-publication (quote change)))
    (test-case "refused layout publication preserves instance state and revision"
      (def old (poo-clos-class 'instance-refusal-old
                 direct-slots: (list (poo-clos-direct-slot-definition 'old))))
      (def next (poo-clos-class 'instance-refusal-new
                  direct-slots: (list (poo-clos-direct-slot-definition 'new))))
      (def instance (poo-clos-make-instance old))
      (def state (.ref instance '%poo-clos-state))
      (def storage (.ref state 'storage))
      (def revision (object-revision state))
      (seal-object! state)
      (check-exception (poo-clos-change-class instance next) (lambda (_) #t))
      (check-equal? (eq? (.ref state 'class) old) #t)
      (check-equal? (.ref state 'generation) 0)
      (check-equal? (eq? (.ref state 'storage) storage) #t)
      (check-equal? (object-revision state) revision))

    (test-case "an update callback refuses after the complete instance layout is published"
      (def old (poo-clos-class 'instance-update-old
                 direct-slots: (list (poo-clos-direct-slot-definition 'old))))
      (def cause (list 'instance-update-refused))
      (def next
        (poo-clos-class 'instance-update-new
          direct-slots: (list (poo-clos-direct-slot-definition 'new))
          different-class-update-handler: (lambda (_previous _current . _args) (raise cause))))
      (def instance (poo-clos-make-instance old))
      (def state (.ref instance '%poo-clos-state))
      (check-exception (poo-clos-change-class instance next) (lambda (error) (eq? error cause)))
      (check-equal? (eq? (.ref state 'class) next) #t)
      (check-equal? (.ref state 'generation) (poo-clos-class-generation next))
      (check-equal? (hash-key? (.ref state 'storage) 'old) #f)
      (check-equal? (hash-key? (.ref state 'storage) 'new) #t))

    (test-case "class declaration cells are owned across input reflection and read observation"
      (def calls 0)
      (def initial (lambda () (set! calls (1+ calls)) 10))
      (def defaults (list (cons value: initial)))
      (def slot (poo-clos-direct-slot-definition 'value initargs: (list value:)))
      (def direct (list slot))
      (def class-value
        (poo-clos-class 'owned-declarations direct-slots: direct default-initargs: defaults))
      (def revision (object-revision class-value))
      (def read #f)
      (call-with-slot-read-observer
        (lambda (record)
          (when (and (eq? (slot-read-receiver record) class-value)
                     (eq? (slot-read-key record) 'default-initargs))
            (set! read record)
            (set-cdr! (car (slot-read-value record)) (lambda () 90))
            (set-cdr! (car (hash-ref (slot-read-instance record) 'default-initargs)) (lambda () 91))))
        (lambda () (.ref class-value 'default-initargs)))
      (set-cdr! (car defaults) (lambda () 92))
      (set-cdr! (car (poo-clos-class-default-initargs class-value)) (lambda () 93))
      (set-car! (car (.ref class-value 'default-initargs)) 'other)
      (set-car! direct #f)
      (set-car! (.ref class-value 'direct-slots) #f)
      (check-equal? calls 0)
      (check (cdr (car (.ref class-value 'default-initargs))) => initial)
      (check (car (poo-clos-class-direct-slots class-value)) => slot)
      (check-equal? (object-revision class-value) revision)
      (check-equal? (poo-clos-class-generation class-value) 0)
      (replay-slot-reads! (list read) void)
      (check-equal? (poo-clos-slot-value (poo-clos-make-instance class-value) 'value) 10)
      (check-equal? calls 1))
    (test-case "redefinition and Slot assignment retain declaration ownership"
      (def slot (poo-clos-direct-slot-definition 'value initargs: (list value:)))
      (def class-value (poo-clos-class 'redefined-owned-declarations))
      (def direct (list slot))
      (def defaults (list (cons value: (lambda () 20))))
      (poo-clos-redefine-class class-value direct-slots: direct default-initargs: defaults)
      (set-car! direct #f)
      (set-cdr! (car defaults) (lambda () 94))
      (set-cdr! (car (.ref class-value 'default-initargs)) (lambda () 95))
      (check (car (poo-clos-class-direct-slots class-value)) => slot)
      (check-equal? (poo-clos-slot-value (poo-clos-make-instance class-value) 'value) 20)
      (def read #f)
      (call-with-slot-read-observer
        (lambda (record)
          (when (and (eq? (slot-read-receiver record) class-value)
                     (eq? (slot-read-key record) 'default-initargs))
            (set! read record)))
        (lambda () (.ref class-value 'default-initargs)))
      (def generation (poo-clos-class-generation class-value))
      (def revision (object-revision class-value))
      (def replacement (list (cons value: (lambda () 30))))
      (.put! class-value 'default-initargs replacement)
      (check (> (object-revision class-value) revision) => #t)
      (check-exception (replay-slot-reads! (list read) void) true)
      (set-cdr! (car replacement) (lambda () 96))
      (set-cdr! (car (.ref class-value 'default-initargs)) (lambda () 97))
      (check-equal? (poo-clos-class-generation class-value) generation)
      (check-equal? (poo-clos-slot-value (poo-clos-make-instance class-value) 'value) 30))

    (test-case "redefinition preserves class identity and migrates lazily"
      (let* ((updates '())
             (x-slot
              (poo-clos-direct-slot-definition 'x initargs: (list x:)))
             (y-slot
              (poo-clos-direct-slot-definition 'y initargs: (list y:)))
             (base
              (poo-clos-class
               'evolving-base direct-slots: (list x-slot)
               redefinition-update-handler:
               (lambda (instance added discarded plist)
                 (set! updates (list instance added discarded plist))
                 instance)))
             (child
              (poo-clos-class 'evolving-child
                              direct-superclasses: (list base)
                              direct-slots: (list y-slot)))
             (instance (poo-clos-make-instance child x: 10 y: 20))
             (generic
              (poo-clos-add-method
               (poo-clos-generic-function 'generation-dispatch 1)
               (poo-clos-method
                'old-base-method (list (poo-clos-class-specializer base))
                (lambda (_frame _instance) 'base-method))))
             (z-slot
              (poo-clos-direct-slot-definition
               'z initform: (lambda () 30)))
             (new-base
              (poo-clos-redefine-class
               base direct-slots: (list x-slot z-slot)))
             (new-child child))
        (check (eq? new-base base) => #t)
        (check (eq? new-child child) => #t)
        (check-equal? (poo-clos-class-generation new-base) 1)
        (check-equal? (poo-clos-class-generation new-child) 1)
        (check (eq? (car (poo-clos-class-direct-superclasses new-child))
                    new-base)
               => #t)
        ;; Dispatch sees the logical generation before slot access triggers the
        ;; physical instance-state migration.
        (check-equal? (poo-clos-call generic instance) 'base-method)
        (check (eq? (poo-clos-class-of instance) new-child) => #t)
        (check-equal? (poo-clos-slot-value instance 'x) 10)
        (check-equal? (poo-clos-slot-value instance 'y) 20)
        (check-equal? (poo-clos-slot-value instance 'z) 30)
        (check (eq? (car updates) instance) => #t)
        (check-equal? (cadr updates) '(z))
        (check-equal? (caddr updates) '())
        (check-equal? (poo-clos-instance-slot-names instance) '(y x z))
        (let ((slot (poo-clos-find-effective-slot new-child 'z))
              (method (car (poo-clos-generic-methods generic))))
          (check-equal? (poo-clos-slot-name slot) 'z)
          (check-equal? (poo-clos-slot-allocation slot) 'instance)
          (check-equal? (poo-clos-method-name method) 'old-base-method)
          (check-equal? (poo-clos-method-qualifiers method) '())
          (check-equal?
           (poo-clos-specializer-kind
            (car (poo-clos-method-specializers method)))
           'class)
          (check-equal? (poo-clos-generic-name generic)
                        'generation-dispatch)
          (check-equal? (poo-clos-generic-generation generic) 1))))

    (test-case "discarded bound slots are supplied to the update hook"
      (let* ((receipt #f)
             (old-slot
              (poo-clos-direct-slot-definition 'old initargs: (list old:)))
             (new-slot
              (poo-clos-direct-slot-definition 'new initform: (lambda () 8)))
             (class-value
              (poo-clos-class
               'discarding direct-slots: (list old-slot)
               redefinition-update-handler:
               (lambda (_instance added discarded plist)
                 (set! receipt (list added discarded plist)))))
             (instance (poo-clos-make-instance class-value old: 7)))
        (def effective (poo-clos-find-effective-slot class-value 'old))
        (set-car! (poo-clos-class-effective-slots class-value) #f)
        (set-car! (.ref effective 'initargs) new:)
        (check-equal? (poo-clos-slot-initargs effective) (list old:))
        (check-exception (.put! effective 'allocation 'class) true)
        (check-exception (hash-put! (.ref class-value 'effective-slot-index) 'old #f) true)
        (check (poo-clos-find-effective-slot class-value 'old) => effective)
        (poo-clos-redefine-class class-value direct-slots: (list new-slot))
        (def history (.ref class-value 'layout-history))
        (set-car! (history 0) #f)
        (check (car (history 0)) => effective)
        (check-equal? (poo-clos-slot-value instance 'new) 8)
        (check-equal? receipt '((new) (old) (old 7)))))

    (test-case "read prechecks see a complete class family generation"
      (def left
        (poo-clos-class 'publication-left
          direct-slots: (list (poo-clos-direct-slot-definition 'old))))
      (def right
        (poo-clos-class 'publication-right
          direct-slots: (list (poo-clos-direct-slot-definition 'new))))
      (def base
        (poo-clos-class 'publication-base direct-superclasses: (list left)))
      (def leaf
        (poo-clos-class 'publication-leaf direct-superclasses: (list base)))
      (def (snapshot)
        (list (poo-clos-class-generation base) (poo-clos-class-generation leaf)
              (eq? (car (poo-clos-class-direct-superclasses base)) right)
              (and (memq base (poo-clos-class-direct-subclasses left)) #t)
              (and (memq base (poo-clos-class-direct-subclasses right)) #t)
              (and (poo-clos-find-effective-slot base 'new) #t)
              (and (poo-clos-find-effective-slot leaf 'new) #t)))
      (def before '(0 0 #f #t #f #f #f))
      (def after '(1 1 #t #f #t #t #t))
      (def seen '())
      (check-equal? (snapshot) before)
      (call-with-slot-read-observer
        void
        (lambda () (poo-clos-redefine-class base direct-superclasses: (list right)))
        before:
        (lambda (_receiver key)
          (when (memq key '(generation prototype precedence effective-slots))
            (set! seen (cons (snapshot) seen)))))
      (check-equal? (snapshot) after)
      (check-equal? (and (member before seen) #t) #t)
      (check-equal? (and (member after seen) #t) #t)
      (check-equal? (andmap (lambda (state) (or (equal? state before) (equal? state after))) seen)
                    #t))

    (test-case "change-class preserves identity, common slots, and hook views"
      (let* ((receipt #f)
             (common-a
              (poo-clos-direct-slot-definition
               'common initargs: (list common:)))
             (only-a
              (poo-clos-direct-slot-definition 'only-a initargs: (list only-a:)))
             (common-b
              (poo-clos-direct-slot-definition
               'common initargs: (list common:)))
             (only-b
              (poo-clos-direct-slot-definition
               'only-b initargs: (list only-b:)
               initform: (lambda () 'default-b)))
             (class-a
              (poo-clos-class 'change-a
                              direct-slots: (list common-a only-a)))
             (class-b
              (poo-clos-class
               'change-b direct-slots: (list common-b only-b)
               different-class-update-handler:
               (lambda (previous current . initargs)
                 (set! receipt
                       (list (poo-clos-class-name
                              (poo-clos-class-of previous))
                             (poo-clos-slot-value previous 'only-a)
                             (poo-clos-slot-value previous 'common)
                             (poo-clos-class-name
                              (poo-clos-class-of current))
                             (poo-clos-slot-value current 'common)
                             initargs))
                 current)))
             (instance
              (poo-clos-make-instance class-a common: 4 only-a: 5))
             (identity instance))
        (def generic (poo-clos-generic-function 'class-sensitive 1))
        (poo-clos-add-method generic
          (poo-clos-method 'before-change (list (poo-clos-class-specializer class-a))
            (lambda (_frame _instance) 'a)))
        (poo-clos-add-method generic
          (poo-clos-method 'after-change (list (poo-clos-class-specializer class-b))
            (lambda (_frame _instance) 'b)))
        (def generation (poo-clos-generic-generation generic))
        (check-equal? (poo-clos-call generic instance) 'a)
        (check (eq? (poo-clos-change-class instance class-b
                                           common: 10 only-b: 9)
                    identity)
               => #t)
        (check-equal? (poo-clos-class-name (poo-clos-class-of instance))
                      'change-b)
        (check-equal? (poo-clos-slot-value instance 'common) 10)
        (check-equal? (poo-clos-slot-value instance 'only-b) 9)
        (check-equal? (poo-clos-generic-generation generic) generation)
        (check-equal? (poo-clos-call generic instance) 'b)
        (check-equal? receipt
                      '(change-a 5 4 change-b 10 (common: 10 only-b: 9)))))

    (test-case "successive redefinitions retain the exact class object"
      (let* ((class-value (poo-clos-class 'stable-generation))
             (first (poo-clos-redefine-class class-value))
             (second (poo-clos-redefine-class class-value)))
        (check (eq? class-value first) => #t)
        (check (eq? first second) => #t)
        (check-equal? (poo-clos-class-generation class-value) 2)))

    (test-case "dependent C4 rejection preserves every class generation"
      (let* ((x (poo-clos-class 'dependent-precedence-x))
             (y (poo-clos-class 'dependent-precedence-y))
             (base (poo-clos-class 'dependent-precedence-base
                                   direct-superclasses: (list x)))
             (child (poo-clos-class 'dependent-precedence-child
                                    direct-superclasses: (list y base)))
             (base-prototype (.ref base 'instance-prototype))
             (child-prototype (.ref child 'instance-prototype)))
        (check-exception
         (poo-clos-redefine-class base direct-superclasses: (list x y))
         (failure-code? 'inconsistent-class-precedence))
        (check-equal? (map poo-clos-class-generation (list base child))
                      '(0 0))
        (check (eq? (.ref base 'instance-prototype) base-prototype) => #t)
        (check (eq? (.ref child 'instance-prototype) child-prototype) => #t)
        (check (eq? (car (poo-clos-class-direct-superclasses base)) x) => #t)
        (check (memq base (.ref y 'direct-subclasses)) => #f)))

    (test-case "diamond dependents are reinitialized exactly once"
      (let* ((root (poo-clos-class 'evolution-diamond-root))
             (left
              (poo-clos-class
               'evolution-diamond-left
               direct-superclasses: (list root)))
             (right
              (poo-clos-class
               'evolution-diamond-right
               direct-superclasses: (list root)))
             (leaf
              (poo-clos-class
               'evolution-diamond-leaf
               direct-superclasses: (list left right))))
        (poo-clos-redefine-class root)
        (check-equal?
         (map poo-clos-class-generation (list root left right leaf))
         '(1 1 1 1))))

    (test-case "MOP-EXTENDED is a sealed read-only capability profile"
      (let (profile (poo-clos-mop-extended-profile))
        (check (poo-clos-mop-profile-admits? profile 'generic-methods) => #t)
        (check (poo-clos-mop-profile-admits? profile 'replace-runtime-c4)
               => #f)
        (check-equal? (.ref profile 'status) 'admitted)
        (check-equal? (.ref profile 'sealed?) #t)))

    (test-case "make-instances-obsolete preserves class identity"
      (let* ((class-value (poo-clos-class 'explicit-obsolescence))
             (instance (poo-clos-make-instance class-value))
             (reinitialized (poo-clos-make-instances-obsolete class-value)))
        (check (eq? class-value reinitialized) => #t)
        (check-equal? (poo-clos-class-generation class-value) 1)
        (check (eq? (poo-clos-class-of instance) class-value) => #t)))))
