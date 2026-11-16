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

(export clos-evolution-test)

(def (failure-code? code)
  (lambda (error)
    (and (clos-failure? error)
         (eq? (.ref error 'code) code))))

(def (check-instance-publication operation)
  (def old-class
    (clos-class 'instance-publication-old
      direct-slots: (list (clos-direct-slot-definition 'old))))
  (def new-slots (list (clos-direct-slot-definition 'new)))
  (def instance (clos-make-instance old-class))
  (def state (.ref instance '%clos-state))
  (def next-class
    (if (eq? operation 'redefine)
      (clos-redefine-class old-class direct-slots: new-slots)
      (clos-redefine-class
       (clos-class 'instance-publication-new) direct-slots: new-slots)))
  (def (snapshot)
    (let (storage (.ref state 'storage))
      (list (eq? (.ref state 'class) next-class)
            (.ref state 'generation)
            (hash-key? storage 'old) (hash-key? storage 'new))))
  (def before (snapshot))
  (def after (list #t (clos-class-generation next-class) #f #t))
  (def seen '())
  (call-with-slot-read-observer
    void
    (lambda ()
      (if (eq? operation 'redefine)
        (clos-slot-bound? instance 'new)
        (clos-change-class instance next-class)))
    before:
    (lambda (_receiver key)
      (when (memq key (quote (class generation storage)))
        (set! seen (cons (snapshot) seen)))))
  (check-equal? (snapshot) after)
  (check-equal? (and (member before seen) #t) #t)
  (check-equal? (and (member after seen) #t) #t)
  (check-equal? (andmap (lambda (entry) (or (equal? entry before) (equal? entry after))) seen)
                #t))

(def clos-evolution-test
  (test-suite "POO CLOS class evolution"
    (test-case "common slot readers compose with direct and effective class slots"
      (def direct
        (clos-direct-slot-definition 'value allocation: 'class
          initargs: (list value:) readers: '(read-value) writers: '(write-value)))
      (def class-value (clos-class 'slot-reflection direct-slots: (list direct)))
      (def effective (clos-find-effective-slot class-value 'value))
      (for-each
        (lambda (slot)
          (check-equal? (clos-slot-name slot) 'value)
          (check-equal? (clos-slot-allocation slot) 'class)
          (check-equal? (clos-slot-initargs slot) (list value:))
          (check-equal? (clos-slot-readers slot) '(read-value))
          (check-equal? (clos-slot-writers slot) '(write-value))
          (set-car! (clos-slot-initargs slot) other:)
          (set-car! (clos-slot-readers slot) 'other-reader)
          (set-car! (clos-slot-writers slot) 'other-writer)
          (check-equal? (clos-slot-initargs slot) (list value:))
          (check-equal? (clos-slot-readers slot) '(read-value))
          (check-equal? (clos-slot-writers slot) '(write-value)))
        (list (car (clos-class-direct-slots class-value)) effective))
      (check-equal? (clos-slot-defining-classes effective) (list class-value))
      (check (clos-slot-storage-class effective) => class-value)
      (check-exception (clos-slot-defining-classes direct)
        (failure-code? 'invalid-effective-slot-definition))
      (check-exception (clos-slot-storage-class direct)
        (failure-code? 'invalid-effective-slot-definition))
      (check-exception (clos-slot-name #f) (failure-code? 'invalid-slot-definition)))
    (test-case "lazy migration publishes one complete instance layout"
      (check-instance-publication (quote redefine)))
    (test-case "change-class publishes one complete instance layout"
      (check-instance-publication (quote change)))
    (test-case "refused layout publication preserves instance state and revision"
      (def old (clos-class 'instance-refusal-old
                 direct-slots: (list (clos-direct-slot-definition 'old))))
      (def next (clos-class 'instance-refusal-new
                  direct-slots: (list (clos-direct-slot-definition 'new))))
      (def instance (clos-make-instance old))
      (def state (.ref instance '%clos-state))
      (def storage (.ref state 'storage))
      (def revision (object-revision state))
      (seal-object! state)
      (check-exception (clos-change-class instance next) (lambda (_) #t))
      (check-equal? (eq? (.ref state 'class) old) #t)
      (check-equal? (.ref state 'generation) 0)
      (check-equal? (eq? (.ref state 'storage) storage) #t)
      (check-equal? (object-revision state) revision))

    (test-case "an update callback refuses after the complete instance layout is published"
      (def old (clos-class 'instance-update-old
                 direct-slots: (list (clos-direct-slot-definition 'old))))
      (def cause (list 'instance-update-refused))
      (def next
        (clos-class 'instance-update-new
          direct-slots: (list (clos-direct-slot-definition 'new))
          different-class-update-handler: (lambda (_previous _current . _args) (raise cause))))
      (def instance (clos-make-instance old))
      (def state (.ref instance '%clos-state))
      (check-exception (clos-change-class instance next) (lambda (error) (eq? error cause)))
      (check-equal? (eq? (.ref state 'class) next) #t)
      (check-equal? (.ref state 'generation) (clos-class-generation next))
      (check-equal? (hash-key? (.ref state 'storage) 'old) #f)
      (check-equal? (hash-key? (.ref state 'storage) 'new) #t))

    (test-case "class declaration cells are owned across input reflection and read observation"
      (def calls 0)
      (def initial (lambda () (set! calls (1+ calls)) 10))
      (def defaults (list (cons value: initial)))
      (def slot (clos-direct-slot-definition 'value initargs: (list value:)))
      (def direct (list slot))
      (def class-value
        (clos-class 'owned-declarations direct-slots: direct default-initargs: defaults))
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
      (set-cdr! (car (clos-class-default-initargs class-value)) (lambda () 93))
      (set-car! (car (.ref class-value 'default-initargs)) 'other)
      (set-car! direct #f)
      (set-car! (.ref class-value 'direct-slots) #f)
      (check-equal? calls 0)
      (check (cdr (car (.ref class-value 'default-initargs))) => initial)
      (check (car (clos-class-direct-slots class-value)) => slot)
      (check-equal? (object-revision class-value) revision)
      (check-equal? (clos-class-generation class-value) 0)
      (replay-slot-reads! (list read) void)
      (check-equal? (clos-slot-value (clos-make-instance class-value) 'value) 10)
      (check-equal? calls 1))
    (test-case "redefinition and Slot assignment retain declaration ownership"
      (def slot (clos-direct-slot-definition 'value initargs: (list value:)))
      (def class-value (clos-class 'redefined-owned-declarations))
      (def direct (list slot))
      (def defaults (list (cons value: (lambda () 20))))
      (clos-redefine-class class-value direct-slots: direct default-initargs: defaults)
      (set-car! direct #f)
      (set-cdr! (car defaults) (lambda () 94))
      (set-cdr! (car (.ref class-value 'default-initargs)) (lambda () 95))
      (check (car (clos-class-direct-slots class-value)) => slot)
      (check-equal? (clos-slot-value (clos-make-instance class-value) 'value) 20)
      (def read #f)
      (call-with-slot-read-observer
        (lambda (record)
          (when (and (eq? (slot-read-receiver record) class-value)
                     (eq? (slot-read-key record) 'default-initargs))
            (set! read record)))
        (lambda () (.ref class-value 'default-initargs)))
      (def generation (clos-class-generation class-value))
      (def revision (object-revision class-value))
      (def replacement (list (cons value: (lambda () 30))))
      (.put! class-value 'default-initargs replacement)
      (check (> (object-revision class-value) revision) => #t)
      (check-exception (replay-slot-reads! (list read) void) true)
      (set-cdr! (car replacement) (lambda () 96))
      (set-cdr! (car (.ref class-value 'default-initargs)) (lambda () 97))
      (check-equal? (clos-class-generation class-value) generation)
      (check-equal? (clos-slot-value (clos-make-instance class-value) 'value) 30))

    (test-case "redefinition preserves class identity and migrates lazily"
      (let* ((updates '())
             (x-slot
              (clos-direct-slot-definition 'x initargs: (list x:)))
             (y-slot
              (clos-direct-slot-definition 'y initargs: (list y:)))
             (base
              (clos-class
               'evolving-base direct-slots: (list x-slot)
               redefinition-update-handler:
               (lambda (instance added discarded plist)
                 (set! updates (list instance added discarded plist))
                 instance)))
             (child
              (clos-class 'evolving-child
                              direct-superclasses: (list base)
                              direct-slots: (list y-slot)))
             (instance (clos-make-instance child x: 10 y: 20))
             (generic
              (clos-add-method
               (clos-generic-function 'generation-dispatch 1)
               (clos-method
                'old-base-method (list (clos-class-specializer base))
                (lambda (_frame _instance) 'base-method))))
             (z-slot
              (clos-direct-slot-definition
               'z initform: (lambda () 30)))
             (new-base
              (clos-redefine-class
               base direct-slots: (list x-slot z-slot)))
             (new-child child))
        (check (eq? new-base base) => #t)
        (check (eq? new-child child) => #t)
        (check-equal? (clos-class-generation new-base) 1)
        (check-equal? (clos-class-generation new-child) 1)
        (check (eq? (car (clos-class-direct-superclasses new-child))
                    new-base)
               => #t)
        ;; Dispatch sees the logical generation before slot access triggers the
        ;; physical instance-state migration.
        (check-equal? (clos-call generic instance) 'base-method)
        (check (eq? (clos-class-of instance) new-child) => #t)
        (check-equal? (clos-slot-value instance 'x) 10)
        (check-equal? (clos-slot-value instance 'y) 20)
        (check-equal? (clos-slot-value instance 'z) 30)
        (check (eq? (car updates) instance) => #t)
        (check-equal? (cadr updates) '(z))
        (check-equal? (caddr updates) '())
        (check-equal? (clos-instance-slot-names instance) '(y x z))
        (let ((slot (clos-find-effective-slot new-child 'z))
              (method (car (clos-generic-methods generic))))
          (check-equal? (clos-slot-name slot) 'z)
          (check-equal? (clos-slot-allocation slot) 'instance)
          (check-equal? (clos-method-name method) 'old-base-method)
          (check-equal? (clos-method-qualifiers method) '())
          (check-equal?
           (clos-specializer-kind
            (car (clos-method-specializers method)))
           'class)
          (check-equal? (clos-generic-name generic)
                        'generation-dispatch)
          (check-equal? (clos-generic-generation generic) 1))))

    (test-case "discarded bound slots are supplied to the update hook"
      (let* ((receipt #f)
             (old-slot
              (clos-direct-slot-definition 'old initargs: (list old:)))
             (new-slot
              (clos-direct-slot-definition 'new initform: (lambda () 8)))
             (class-value
              (clos-class
               'discarding direct-slots: (list old-slot)
               redefinition-update-handler:
               (lambda (_instance added discarded plist)
                 (set! receipt (list added discarded plist)))))
             (instance (clos-make-instance class-value old: 7)))
        (def effective (clos-find-effective-slot class-value 'old))
        (set-car! (clos-class-effective-slots class-value) #f)
        (set-car! (.ref effective 'initargs) new:)
        (check-equal? (clos-slot-initargs effective) (list old:))
        (check-exception (.put! effective 'allocation 'class) true)
        (check-exception (hash-put! (.ref class-value 'effective-slot-index) 'old #f) true)
        (check (clos-find-effective-slot class-value 'old) => effective)
        (clos-redefine-class class-value direct-slots: (list new-slot))
        (def history (.ref class-value 'layout-history))
        (set-car! (history 0) #f)
        (check (car (history 0)) => effective)
        (check-equal? (clos-slot-value instance 'new) 8)
        (check-equal? receipt '((new) (old) (old 7)))))

    (test-case "read prechecks see a complete class family generation"
      (def left
        (clos-class 'publication-left
          direct-slots: (list (clos-direct-slot-definition 'old))))
      (def right
        (clos-class 'publication-right
          direct-slots: (list (clos-direct-slot-definition 'new))))
      (def base
        (clos-class 'publication-base direct-superclasses: (list left)))
      (def leaf
        (clos-class 'publication-leaf direct-superclasses: (list base)))
      (def (snapshot)
        (list (clos-class-generation base) (clos-class-generation leaf)
              (eq? (car (clos-class-direct-superclasses base)) right)
              (and (memq base (clos-class-direct-subclasses left)) #t)
              (and (memq base (clos-class-direct-subclasses right)) #t)
              (and (clos-find-effective-slot base 'new) #t)
              (and (clos-find-effective-slot leaf 'new) #t)))
      (def before '(0 0 #f #t #f #f #f))
      (def after '(1 1 #t #f #t #t #t))
      (def seen '())
      (check-equal? (snapshot) before)
      (call-with-slot-read-observer
        void
        (lambda () (clos-redefine-class base direct-superclasses: (list right)))
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
              (clos-direct-slot-definition
               'common initargs: (list common:)))
             (only-a
              (clos-direct-slot-definition 'only-a initargs: (list only-a:)))
             (common-b
              (clos-direct-slot-definition
               'common initargs: (list common:)))
             (only-b
              (clos-direct-slot-definition
               'only-b initargs: (list only-b:)
               initform: (lambda () 'default-b)))
             (class-a
              (clos-class 'change-a
                              direct-slots: (list common-a only-a)))
             (class-b
              (clos-class
               'change-b direct-slots: (list common-b only-b)
               different-class-update-handler:
               (lambda (previous current . initargs)
                 (set! receipt
                       (list (clos-class-name
                              (clos-class-of previous))
                             (clos-slot-value previous 'only-a)
                             (clos-slot-value previous 'common)
                             (clos-class-name
                              (clos-class-of current))
                             (clos-slot-value current 'common)
                             initargs))
                 current)))
             (instance
              (clos-make-instance class-a common: 4 only-a: 5))
             (identity instance))
        (def generic (clos-generic-function 'class-sensitive 1))
        (clos-add-method generic
          (clos-method 'before-change (list (clos-class-specializer class-a))
            (lambda (_frame _instance) 'a)))
        (clos-add-method generic
          (clos-method 'after-change (list (clos-class-specializer class-b))
            (lambda (_frame _instance) 'b)))
        (def generation (clos-generic-generation generic))
        (check-equal? (clos-call generic instance) 'a)
        (check (eq? (clos-change-class instance class-b
                                           common: 10 only-b: 9)
                    identity)
               => #t)
        (check-equal? (clos-class-name (clos-class-of instance))
                      'change-b)
        (check-equal? (clos-slot-value instance 'common) 10)
        (check-equal? (clos-slot-value instance 'only-b) 9)
        (check-equal? (clos-generic-generation generic) generation)
        (check-equal? (clos-call generic instance) 'b)
        (check-equal? receipt
                      '(change-a 5 4 change-b 10 (common: 10 only-b: 9)))))

    (test-case "successive redefinitions retain the exact class object"
      (let* ((class-value (clos-class 'stable-generation))
             (first (clos-redefine-class class-value))
             (second (clos-redefine-class class-value)))
        (check (eq? class-value first) => #t)
        (check (eq? first second) => #t)
        (check-equal? (clos-class-generation class-value) 2)))

    (test-case "dependent C4 rejection preserves every class generation"
      (let* ((x (clos-class 'dependent-precedence-x))
             (y (clos-class 'dependent-precedence-y))
             (base (clos-class 'dependent-precedence-base
                                   direct-superclasses: (list x)))
             (child (clos-class 'dependent-precedence-child
                                    direct-superclasses: (list y base)))
             (base-prototype (.ref base 'instance-prototype))
             (child-prototype (.ref child 'instance-prototype)))
        (check-exception
         (clos-redefine-class base direct-superclasses: (list x y))
         (failure-code? 'inconsistent-class-precedence))
        (check-equal? (map clos-class-generation (list base child))
                      '(0 0))
        (check (eq? (.ref base 'instance-prototype) base-prototype) => #t)
        (check (eq? (.ref child 'instance-prototype) child-prototype) => #t)
        (check (eq? (car (clos-class-direct-superclasses base)) x) => #t)
        (check (memq base (.ref y 'direct-subclasses)) => #f)))

    (test-case "diamond dependents are reinitialized exactly once"
      (let* ((root (clos-class 'evolution-diamond-root))
             (left
              (clos-class
               'evolution-diamond-left
               direct-superclasses: (list root)))
             (right
              (clos-class
               'evolution-diamond-right
               direct-superclasses: (list root)))
             (leaf
              (clos-class
               'evolution-diamond-leaf
               direct-superclasses: (list left right))))
        (clos-redefine-class root)
        (check-equal?
         (map clos-class-generation (list root left right leaf))
         '(1 1 1 1))))

    (test-case "MOP-EXTENDED is a sealed read-only capability profile"
      (let (profile (clos-mop-extended-profile))
        (check (clos-mop-profile-admits? profile 'generic-methods) => #t)
        (check (clos-mop-profile-admits? profile 'replace-runtime-c4)
               => #f)
        (check-equal? (.ref profile 'status) 'admitted)
        (check-equal? (.ref profile 'sealed?) #t)))

    (test-case "make-instances-obsolete preserves class identity"
      (let* ((class-value (clos-class 'explicit-obsolescence))
             (instance (clos-make-instance class-value))
             (reinitialized (clos-make-instances-obsolete class-value)))
        (check (eq? class-value reinitialized) => #t)
        (check-equal? (clos-class-generation class-value) 1)
        (check (eq? (clos-class-of instance) class-value) => #t)))))
