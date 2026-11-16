;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; CLOS specializer, multi-dispatch, and standard-combination conformance.

(import (only-in :clan/poo/type Type. element?) (only-in :std/test
                 test-suite test-case check-equal? check-exception check)
        :std/error
        (only-in :clan/poo/object .o .ref .put! .all-slots object-slots $constant-slot-spec $constant-slot-spec?
                 .putslot! object-slots-set! object-supers-set! object-protocol-set!
                 replay-slot-reads! object-read-issued? object-instance object-revision hash<-object
                 depend-on-object! object-%precedence-list with-slot-dependencies)
        (prefix-in (only-in :gerbil/runtime/mop slot-ref slot-set!) runtime.)
        (only-in :std/list/list foldl)
        (only-in :clan/poo/slot-observation call-with-slot-read-observer
                 slot-read-key slot-read-receiver slot-read-dependencies slot-read-value
                 %call-with-recorded-slot-reads)
        (only-in :clan/poo/clos/objects make-effective-method make-invocation-frame)
        (only-in :clan/poo/read-projection call-with-owned-read-projection
                 current-owned-read-open-guard owned-read-value! owned-read-open!)
        :clan/poo/mop)

(export clos-dispatch-test)

(extern namespace: clan/poo/slot-observation
        %with-slot-read-registration-interval %first-registered-read?
        %call-with-private-slot-read-prefix)
(extern namespace: clan/poo/clos/objects %frameless-method-body)

(def any-specializer (clos-any-specializer))
(def animal-class (.o))
(def dog-class (.o (:: @ animal-class)))
(def cat-class (.o (:: @ animal-class)))
(def dog (.o (:: @ dog-class)))
(def cat (.o (:: @ cat-class)))

(def (failure-code? code)
  (lambda (error)
    (and (clos-failure? error)
         (eq? (.ref error 'code) code))))

(def (primary-method identity specializers value)
  (clos-method identity specializers
                   (lambda (_frame . _arguments) value)))

(def clos-dispatch-test
  (test-suite "POO CLOS multi-dispatch conformance"
    (test-case "ordered qualifier values determine long-form replacement and lookup"
      (def group (clos-method-group 'ordered '((first second))))
      (def other (clos-method-group 'other '((second first) (tag) () (primary))))
      (def combination
        (clos-long-method-combination 'ordered-qualifiers (list group other)
          (lambda (_generic _arguments _groups)
            (lambda (effective)
              (def methods (clos-effective-method-group effective 'ordered))
              (clos-call-method effective (car methods) '())))))
      (def generic (clos-generic-function 'qualifier-test 1 method-combination: combination))
      (def (make-method name qualifiers specializer)
        (clos-method name (list specializer) (lambda (_frame _argument) name)
                          qualifier: qualifiers))
      (def supplied (list 'first 'second))
      (def old (make-method 'old supplied any-specializer))
      (def new (make-method 'new (list 'first 'second) any-specializer))
      (def reversed (make-method 'reversed (list 'second 'first) any-specializer))
      (def other-specializer (clos-eql-specializer 'elsewhere))
      (def other-target (make-method 'other-target (list 'first 'second) other-specializer))
      (clos-add-method generic old)
      (check (eq? (clos-find-method generic '(first second) (list any-specializer)) old) => #t)
      (check-equal? (clos-method-qualifiers old) '(first second))
      (for-each (cut clos-add-method generic <>) (list reversed other-target new))
      (check-equal? (clos-generic-generation generic) 4)
      (check-equal? (length (clos-generic-methods generic)) 3)
      (check-equal? (clos-method-generic-function old) #f)
      (check (eq? (clos-find-method generic '(first second) (list any-specializer)) new) => #t)
      (check (eq? (clos-find-method generic '(second first) (list any-specializer)) reversed) => #t)
      (check (eq? (clos-find-method generic '(first second) (list other-specializer)) other-target) => #t)
      (check-equal? (clos-call generic 'item) 'new)
      (def shorthand (make-method 'shorthand 'tag any-specializer))
      (def singleton (make-method 'singleton (list 'tag) any-specializer))
      (clos-add-method generic shorthand)
      (clos-add-method generic singleton)
      (check-equal? (clos-method-generic-function shorthand) #f)
      (check (eq? (clos-find-method generic '(tag) (list any-specializer)) singleton) => #t)
      (def primary (make-method 'primary 'primary any-specializer))
      (def qualified-primary (make-method 'qualified-primary (list 'primary) any-specializer))
      (clos-add-method generic primary)
      (clos-add-method generic qualified-primary)
      (check (eq? (clos-find-method generic '() (list any-specializer)) primary) => #t)
      (check (eq? (clos-find-method generic '(primary) (list any-specializer)) qualified-primary) => #t))
    (test-case "projection preserves multiple values and unwinds a failed region"
      (check-exception
        (call-with-owned-read-projection '() (lambda () #t)
          (lambda () (error "negative region failure"))) error?)
      (check-equal?
        (call-with-values
          (lambda ()
            (call-with-owned-read-projection '() (lambda () #t)
              (lambda () (values 'first 'second)))) list)
        '(first second)))
    (test-case "owned observer keeps author guard reads outside the capture"
      (def source (.o value: 1))
      (def guard-source (.o value: 2))
      (object-protocol-set! source (.o))
      (.ref source 'value)
      (def calls 0)
      (defvalues (answer reads)
        (%call-with-recorded-slot-reads
          (lambda ()
            (parameterize ((current-owned-read-open-guard
                            (lambda ()
                              (set! calls (fx1+ calls))
                              (.ref guard-source 'value))))
              (call-with-owned-read-projection '() void
                (lambda () (.ref source 'value)))))
          unique-roots?: #t))
      (check-equal? answer 1)
      (check (positive? calls) => #t)
      (check (ormap (lambda (read) (eq? source (slot-read-receiver read))) reads) => #t)
      (check (ormap (lambda (read) (eq? guard-source (slot-read-receiver read))) reads) => #f))
    (test-case "repeated descriptor admission keeps public events and live refusal"
      (def descriptor (clos-lambda-list 1 0 #f #f '() #f))
      (def (check-shape) (element? ClosLambdaList descriptor))
      (defvalues (accepted reads)
        (%call-with-recorded-slot-reads
          (lambda ()
            (call-with-owned-read-projection '() void
              (lambda () (and (check-shape) (check-shape)))))))
      (check-equal? accepted #t)
      (check (andmap object-read-issued? reads) => #t)
      (def events 0)
      (check-equal?
        (call-with-owned-read-projection '() void
          (lambda ()
            (and (check-shape)
                 (call-with-slot-read-observer
                   (lambda (read)
                     (when (and (eq? (slot-read-receiver read) descriptor)
                                (eq? (slot-read-key read) 'required))
                       (set! events (1+ events))
                       (.put! descriptor 'optional 'refuse)))
                   check-shape))))
        #f)
      (check-equal? events 1)
      (defvalues (_value captured)
        (%call-with-recorded-slot-reads (lambda () (.ref descriptor 'required))))
      (def original (car captured))
      (%call-with-recorded-slot-reads
        (lambda ()
          (%with-slot-read-registration-interval
            (lambda ()
              (.ref descriptor 'required)
              (check ((%first-registered-read?) original) => #t)
              (owned-read-open!)
              (check-equal? (%first-registered-read?) #f)))
          (%with-slot-read-registration-interval
            (lambda ()
              (.ref descriptor 'required)
              (check ((%first-registered-read?) original) => #f))))
        unique-roots?: #t))
    (test-case "effective-method and MOP hooks retain the complete call trace"
     (for-each
      (lambda (axis)
      (def exposed #f)
      (def body
        (lambda (frame _value)
          (when (eq? axis 'runtime-mop) (set! exposed frame)) 'done))
      (def protocol
        (clos-generic-protocol 'open-projection
          compute-effective-method:
          (and (eq? axis 'effective)
               (lambda (_generic _args _methods original)
                 (set! exposed original) original))))
      (when (eq? axis 'runtime-mop) (object-protocol-set! protocol (.o)))
      (def generic
        (clos-add-method
          (clos-generic-function 'hooked-projection 1 protocol: protocol)
          (clos-method 'check (list any-specializer) body)))
      (def result
        (.o answer:
          (call-with-owned-read-projection (list body) (clos-call-carrier-policy-guard)
            (cut clos-call generic dog))))
      (def root #f)
      (call-with-slot-read-observer
        (lambda (read) (when (eq? (slot-read-key read) 'answer) (set! root read)))
        (lambda () (.ref result 'answer)))
      (def support (slot-read-dependencies root))
      ;; Internal bundle markers were removed. Preserve the stronger actual
      ;; contract: original issued records directly cover the escaped receiver.
      (check-equal? (andmap object-read-issued? support) #t)
      (check-equal? (ormap (lambda (read) (eq? (slot-read-receiver read) exposed))
                      support) #t)
      (.put! exposed 'negative-edit #t)
      (check-exception (replay-slot-reads! (list root) (lambda (_receiver _key) (void))) error?))
      '(effective runtime-mop)))
    (test-case "owned getter dependencies promote their external policy"
      ;; This isolated ownership fixture puts the only external read UNDER the
      ;; owned token, rather than relying on an independently observed root.
      (def policy (.o allowed: #t))
      (def result
        (.o answer:
          (call-with-owned-read-projection '() (lambda () #t)
            (lambda ()
              (def owned (owned-read-value! (.o value: (.ref policy 'allowed))))
              (.ref owned 'value)))))
      (def root #f)
      (call-with-slot-read-observer
        (lambda (read) (when (eq? (slot-read-key read) 'answer) (set! root read)))
        (lambda () (.ref result 'answer)))
      (##gc)
      (.put! policy 'allowed #f)
      (check-exception (replay-slot-reads! (list root) (lambda (_receiver _key) (void))) error?))
    (test-case "owned-read projection promotes external dependencies and preserves open frames"
      (check-equal? ((clos-call-carrier-policy-guard)) #t)
      (for-each
        (lambda (axis)
          (def policy (.o allowed: #t))
          (def value-checks 0)
          (def constraint
            (.o (:: @ Type.) .element?:
              (lambda (_value) (set! value-checks (+ 1 value-checks)) #t)))
          (def escaped #f)
          (def body
            (lambda (frame value)
              (when (memq axis '(open-frame known-frame)) (set! escaped frame))
              (and (.ref policy 'allowed) (element? constraint value))))
          (def generic
            (clos-add-method (clos-generic-function 'projected-reads 1)
              (clos-method 'check (list any-specializer) body)))
          (def known (if (eq? axis 'open-frame) '() (list body)))
          (def result
            (.o answer:
              (call-with-owned-read-projection known (clos-call-carrier-policy-guard)
                (cut clos-call generic dog))))
          (def root #f)
          (check-equal?
            (call-with-slot-read-observer
              (lambda (read) (when (eq? (slot-read-key read) 'answer) (set! root read)))
              (lambda () (.ref result 'answer))) #t)
          (replay-slot-reads! (list root) (lambda (_receiver _key) (void)))
          (check-equal? value-checks 1)
          (case axis
            ((policy) (.put! policy 'allowed #f))
            ((contract) (.put! constraint '.element? (lambda (_value) #f)))
            ((generic) (.put! generic 'generation (+ 1 (.ref generic 'generation))))
            ((open-frame known-frame) (.put! escaped 'qualifier 'before)))
          ;; Deliberately enroll an escaping fixture body as known: even this
          ;; producer-error probe may not turn a lost weak token into approval.
          (when (eq? axis 'known-frame)
            (##gc))
          (check-exception
            (replay-slot-reads! (list root) (lambda (_receiver _key) (void))) error?))
        '(policy contract generic open-frame known-frame)))
    (test-case "CLOS owns the spines used by its list contracts"
      (def precedence (list 0))
      (def keys (list 'example))
      (def qualifiers (list 'custom))
      (def generic
        (clos-generic-function 'owned-order 1 argument-precedence-order: precedence))
      (def arguments (clos-lambda-list 1 0 #f #t keys #f))
      (def method
        (clos-method 'owned-qualifiers (list any-specializer) void qualifier: qualifiers))
      (def witness (.o))
      (check (with-slot-dependencies witness
               (lambda () (element? ClosGenericFunction generic))) => #t)
      (def revision (object-revision witness))
      (for-each
        (lambda (source receiver field expected)
          (set-car! source 'changed)
          (set-car! (.ref receiver field) 'changed)
          (check-equal? (.ref receiver field) expected))
        (list precedence keys qualifiers)
        (list generic arguments method)
        '(argument-precedence-order keys qualifier)
        '((0) (example) (custom)))
      (check-equal? (object-revision witness) revision)
      (def replacement (list 0))
      (.put! generic 'argument-precedence-order replacement)
      (check-equal? (object-revision witness) (+ revision 1))
      (set-car! replacement 'changed)
      (check-equal? (.ref generic 'argument-precedence-order) '(0))
      (def external (list 0))
      (.putslot! generic 'declarations ($constant-slot-spec external))
      (check-equal? (object-revision witness) (+ revision 2))
      (check (element? ClosGenericFunction generic) => #t)
      (set-cdr! external 'invalid)
      (check (element? ClosGenericFunction generic) => #f))
    (test-case "private admission captures its exact prefix before and after prior reads"
      (def owner (.o first: 1 second: 2))
      (.ref owner 'first)
      (.ref owner 'second)
      (defvalues (result merged)
        (%call-with-recorded-slot-reads
          (lambda ()
            (defvalues (first first-reads)
              (%call-with-private-slot-read-prefix (lambda () (.ref owner 'first))))
            (defvalues (second second-reads)
              (%call-with-private-slot-read-prefix
                (lambda () (begin (.ref owner 'second) (.ref owner 'first)))))
            (check-equal? (map slot-read-key first-reads) '(first))
            (check-equal? (map slot-read-key second-reads) '(second first))
            (check (eq? (car first-reads) (cadr second-reads)) => #t)
            (+ first second))
          unique-roots?: #t))
      (check-equal? result 2)
      (check-equal? (map slot-read-key merged) '(first second)))
    (test-case "frame-free entry belongs to the actual declared method body"
      (.defgeneric direct-identity (value))
      (def method (.defmethod (direct-identity value) value))
      (def body (.ref method 'body))
      (def entry (%frameless-method-body method body))
      (check (procedure? entry) => #t)
      (check-equal? (entry 'value) 'value)
      (check-equal?
        (call-with-owned-read-projection (list body) void
          (lambda () (direct-identity 'value)))
        'value)
      (.put! method 'body (lambda (_frame _value) 'replacement))
      (check-equal? (%frameless-method-body method (.ref method 'body)) #f)
      (check-equal? (direct-identity 'value) 'replacement))
    (test-case "an enclosing native capture receives both single-primary carrier identities"
      (.defgeneric captured-primary (argument))
      (def method (.defmethod (captured-primary argument) argument))
      (def body (.ref method 'body))
      (def effective-proto (.ref ClosEffectiveMethod 'proto))
      (def frame-proto (.ref ClosInvocationFrame 'proto))
      (defvalues (result reads)
        (%call-with-recorded-slot-reads
          (lambda ()
            (call-with-owned-read-projection (list body) void
              (lambda () (captured-primary dog))))
          unique-roots?: #t))
      (check-equal? result dog)
      (def (first-carrier prototype)
        (let loop ((remaining reads))
          (and (pair? remaining)
               (let* ((read (car remaining))
                      (receiver (slot-read-receiver read)))
                 (if (and (object-%precedence-list receiver)
                          (memq prototype (object-%precedence-list receiver)))
                   read
                   (loop (cdr remaining)))))))
      (def effective-read (first-carrier effective-proto))
      (def frame-read (first-carrier frame-proto))
      (check (and effective-read (object-read-issued? effective-read)) => #t)
      (check (and frame-read (object-read-issued? frame-read)) => #t)
      (check (eq? (.ref (slot-read-receiver frame-read) 'effective-method)
                  (slot-read-receiver effective-read)) => #t))
    (test-case "applicability hooks cannot run the same lifecycle extension twice"
      (def writes 0)
      (def class-value
        (clos-class 'unique-applicable-initializer
          direct-slots: (list (clos-direct-slot-definition 'value
                               initform: (lambda () (set! writes (+ writes 1)) writes)))))
      (def instance (clos-allocate-instance class-value))
      (def repeat? #t)
      (def protocol
        (clos-generic-protocol 'selection-identity
          compute-applicable-methods:
          (lambda (_generic _arguments methods)
            (if repeat? (cons (car methods) methods) methods))))
      (def generic
        (clos-add-method (clos-generic-function 'initialize-selected 1 protocol: protocol)
          (clos-method 'initialize-selected/default (list (clos-class-specializer class-value))
            (lambda (_frame instance) (clos-initialize-instance instance)))))
      (def refused (failure-code? 'invalid-compute-applicable-methods-result))
      (check-exception (clos-call generic instance) refused)
      (check-equal? writes 0)
      (check-equal? (clos-slot-bound? instance 'value) #f)
      (check-exception (clos-compute-applicable-methods generic instance) refused)
      (set! repeat? #f)
      (check-equal? (length (clos-compute-applicable-methods generic instance)) 1)
      (check (eq? (clos-call generic instance) instance) => #t)
      (check-equal? writes 1))
    (test-case "ranking callback invalidates a previously checked child descriptor"
      (def ran? #f)
      (def ranked? #f)
      (def arguments (clos-lambda-list 1 0 #f #f '() #f))
      (def (body _frame argument) (set! ran? #t) argument)
      (def protocol
        (clos-generic-protocol 'child-change
          compute-applicable-methods:
          (lambda (_generic _arguments methods)
            (set! ranked? #t)
            (.put! arguments 'optional 'invalid)
            methods)))
      (def generic
        (clos-add-method
          (clos-generic-function 'child-change 1 protocol: protocol)
          (clos-method 'primary (list any-specializer) body
            lambda-list: arguments)))
      (check-exception
        (call-with-owned-read-projection (list body) void
          (lambda () (clos-call generic dog)))
        (failure-code? 'invalid-compute-applicable-methods-result))
      (check-equal? ranked? #t)
      (check-equal? ran? #f))
    (test-case "prototype policy changes invalidate collected-carrier evidence"
      ;; Mutate the shared declaration LAST: restoring a value intentionally
      ;; does not restore its runtime revision or re-certify the old policy.
      (def body (lambda (_frame _value) 'done))
      (def generic
        (clos-add-method (clos-generic-function 'prototype-policy 1)
          (clos-method 'check (list any-specializer) body)))
      (def projected
        (.o answer:
          (call-with-owned-read-projection (list body) (clos-call-carrier-policy-guard)
            (cut clos-call generic dog))))
      (def prototype (.ref ClosInvocationFrame 'proto))
      (def original-kind (.ref prototype 'kind))
      (def projected-root #f)
      (call-with-slot-read-observer
        (lambda (read) (when (eq? (slot-read-key read) 'answer) (set! projected-root read)))
        (lambda () (.ref projected 'answer)))
      (##gc)
      (dynamic-wind
        (lambda () (.put! prototype 'kind 'negative-policy-injection))
        (lambda ()
          (check-exception
            (replay-slot-reads! (list projected-root) (lambda (_receiver _key) (void))) error?))
        (lambda () (.put! prototype 'kind original-kind)))
      (check-equal? ((clos-call-carrier-policy-guard)) #f))
    (test-case "completed CLOS reads retain policy Type Generic and escaped-frame dependencies"
      (for-each
        (lambda (axis)
          (def policy (.o allowed: #t))
          (def constraint (.o (:: @ Type.) .element?: (lambda (_value) #t)))
          (def escaped #f)
          (def generic
            (clos-add-method
              (clos-generic-function 'semantic-reads 1)
              (clos-method 'check (list any-specializer)
                (lambda (frame value)
                  ;; A public method may retain its frame. Allocation identity
                  ;; or CLOS ancestry cannot certify a disposable dependency.
                  (set! escaped frame)
                  (and (.ref policy 'allowed) (element? constraint value))))))
          (def result (.o answer: (clos-call generic dog)))
          (def reads (make-hash-table-eq))
          (check-equal?
            (call-with-slot-read-observer
              (lambda (read) (hash-put! reads read #t))
              (lambda () (.ref result 'answer))) #t)
          (replay-slot-reads! (hash-keys reads) (lambda (_receiver _key) (void)))
          ;; No source-byte change. Each is a real runtime object mutation,
          ;; after the lazy result has completed and its call stack returned.
          (case axis
            ((policy) (.put! policy 'allowed #f))
            ((contract) (.put! constraint '.element? (lambda (_value) #f)))
            ((generic) (.put! generic 'generation (+ 1 (.ref generic 'generation))))
            ((frame) (.put! escaped 'qualifier 'before)))
          (check-exception
            (replay-slot-reads! (hash-keys reads) (lambda (_receiver _key) (void)))
            error?))
        '(policy contract generic frame)))
    (test-case "CLOS carriers capture values without constructor-wide lazy closures"
      (def generic (clos-generic-function 'carrier-values 1))
      (def method (primary-method 'carrier-method (list any-specializer) 'done))
      (def args (list dog))
      (def primaries (list method))
      (def effective (make-effective-method generic args '() '() primaries '()))
      ;; Independent original shape, not a constructor calling itself.
      (def generic-value generic)
      (def original
        (.o (:: @ (.ref ClosEffectiveMethod 'proto))
            generic: generic-value arguments: args around: '() before: '()
            primary: primaries after: '() groups: '() executor: #f))
      (check-equal? (.all-slots effective) (.all-slots original))
      (for-each (lambda (name)
                  (check-equal? (eq? (.ref effective name) (.ref original name)) #t))
        '(generic arguments primary executor))
      (check-equal? (andmap (lambda (entry) ($constant-slot-spec? (cdr entry)))
                      (object-slots effective)) #t)
      (def next (lambda (replacement) replacement))
      (def frame (make-invocation-frame effective args next 'primary method))
      (check-equal? (element? ClosInvocationFrame frame) #t)
      (check-equal? (eq? (.ref frame 'effective-method) effective) #t)
      (check-equal? (eq? (.ref frame 'arguments) args) #t)
      (check-equal? (eq? (.ref frame 'next) next) #t)
      (check-equal? (andmap (lambda (entry) ($constant-slot-spec? (cdr entry)))
                      (object-slots frame)) #t)
      (check-exception (make-effective-method generic 'invalid '() '() primaries '())
                       (failure-code? 'invalid-effective-method))
      (check-exception (make-invocation-frame effective args 42 'primary method)
                       (failure-code? 'invalid-invocation-frame)))
    (test-case "CLOS field contracts preserve lazy demand, protocol and issued reads"
      (def policy (.o current: 'method))
      (def demanded '())
      (def (note name value)
        (set! demanded (cons name demanded))
        value)
      (def prototype (.ref ClosMethod 'proto))
      (def invalid
        (.o (:: @ prototype)
            identity: (note 'invalid 42)
            specializers: (error "later field demanded after rejection")))
      (check-equal? (element? ClosMethod invalid) #f)
      (check-equal? demanded '(invalid))
      (set! demanded '())
      (def method
        (.o (:: @ prototype)
            identity: (note 'identity (.ref policy 'current))
            specializers: (note 'specializers (list any-specializer))
            qualifier: 'primary
            body: (lambda _ 'done)
            lambda-list: #f
            generic-function: #f
            synthetic-effective-method?: #f))
      (object-protocol-set! method
        (.o compute-slot:
            (lambda (_receiver next name)
              (let (inherited (next))
                (if (eq? name 'identity)
                  (lambda () (note 'protocol (inherited)))
                  inherited)))))
      (def read #f)
      (check-equal?
        (call-with-slot-read-observer
          (lambda (record)
            (when (and (eq? (slot-read-receiver record) method)
                       (eq? (slot-read-key record) 'identity))
              (set! read record)))
          (lambda () (element? ClosMethod method)))
        #t)
      (check-equal? demanded '(specializers protocol identity))
      (check-equal? (object-read-issued? read) #t)
      (replay-slot-reads! (list read) (lambda (_receiver _key) (void)))
      (.put! policy 'current 'changed)
      (check-exception
        (replay-slot-reads! (list read) (lambda (_receiver _key) (void)))
        error?))
    (test-case "runtime prototype and any specializers participate in multi-argument dispatch"
      (let* ((generic (clos-generic-function 'meet 2))
             (generic
              (clos-add-method
               generic
               (primary-method
                'animal-animal
                (list (clos-prototype-specializer animal-class)
                      (clos-prototype-specializer animal-class))
                'animal-animal)))
             (generic
              (clos-add-method
               generic
               (primary-method
                'dog-any
                (list (clos-prototype-specializer dog-class) any-specializer)
                'dog-any)))
             (generic
              (clos-add-method
               generic
               (primary-method
                'animal-cat
                (list (clos-prototype-specializer animal-class)
                      (clos-prototype-specializer cat-class))
                'animal-cat))))
        (check-equal? (clos-call generic dog dog) 'dog-any)
        (check-equal? (clos-call generic dog cat) 'dog-any)
        (let (second-first
              (clos-generic-function
               'meet-second-first 2 argument-precedence-order: '(1 0)))
          (let loop ((methods (.ref generic 'methods)) (result second-first))
            (if (null? methods)
              (check-equal? (clos-call result dog cat) 'animal-cat)
              (loop (cdr methods)
                    (let (method (car methods))
                      (clos-add-method
                      result
                       (clos-method
                        (.ref method 'identity) (.ref method 'specializers)
                        (.ref method 'body)
                        qualifier: (.ref method 'qualifier)
                        lambda-list: (.ref method 'lambda-list))))))))))

    (test-case "wide prototype ranking follows replacement and parent invalidation"
      (def root (.o))
      (def parent (.o (:: @ root)))
      (def argument (.o (:: @ parent)))
      (def generic (clos-generic-function 'wide-index 1))
      (for-each
        (lambda (ordinal)
          (clos-add-method generic
            (primary-method 'unrelated (list (clos-prototype-specializer (.o))) ordinal)))
        '(0 1 2 3 4 5 6 7))
      (def fallback (primary-method 'root (list (clos-prototype-specializer root)) 'root))
      (def primary (primary-method 'parent (list (clos-prototype-specializer parent)) 'parent))
      (clos-add-method generic fallback)
      (clos-add-method generic primary)
      (def (applicable)
        (map (cut .ref <> 'identity) (clos-compute-applicable-methods generic argument)))
      (check-equal? (applicable) '(parent root))
      (check-equal? (applicable) '(parent root))
      (def reads 0)
      (check-equal? (call-with-slot-read-observer
                       (lambda (_) (set! reads (1+ reads))) applicable)
                    '(parent root))
      (check-equal? (> reads 0) #t)
      (clos-add-method generic
        (primary-method 'new-parent (list (clos-prototype-specializer parent)) 'new-parent))
      (check-equal? (applicable) '(new-parent root))
      (object-supers-set! parent '())
      (check-equal? (applicable) '(new-parent))
      (check-equal? (applicable) '(new-parent)))
    (test-case "runtime prototypes cannot masquerade as CLOS classes"
      (check-exception
       (clos-class-specializer animal-class)
       (failure-code? 'invalid-specializer)))

    (test-case "published positions do not override live ranks after a protocol callback"
      (def roots (map (lambda (_) (.o)) '(a b c d)))
      (def argument (.o inherit: roots))
      (def replacement
        (primary-method 'new-root (list (clos-prototype-specializer (car roots))) 'new-root))
      (def edit? #f)
      (def protocol
        (clos-generic-protocol 'reordering
          compute-applicable-methods:
          (lambda (generic _arguments ranked)
            (when edit? (clos-add-method generic replacement))
            (reverse ranked))))
      (def generic (clos-generic-function 'position-test 1 protocol: protocol))
      (for-each
        (lambda (root name)
          (clos-add-method generic
            (primary-method name (list (clos-prototype-specializer root)) name)))
        roots '(a b c d))
      (def (applicable)
        (map (cut .ref <> 'identity) (clos-compute-applicable-methods generic argument)))
      (check-equal? (applicable) '(d c b a))
      (set! edit? #t)
      (check-equal? (applicable) '(d c b a))
      (set! edit? #f)
      (check-equal? (applicable) '(d c b new-root))
      (def roster (.ref generic 'methods))
      (set-car! roster
        (primary-method 'pair-write (list (clos-prototype-specializer (car roots))) 'pair-write))
      (check-equal? (applicable) '(d c b new-root))
      (def original (list any-specializer))
      (def detached (primary-method 'detached original 'detached))
      (set-car! original (clos-eql-specializer 'unrelated))
      (set-car! (.ref detached 'specializers) (car original))
      (call-with-slot-read-observer
        (lambda (read)
          (when (and (eq? (slot-read-receiver read) detached)
                     (eq? (slot-read-key read) 'specializers))
            (set-car! (slot-read-value read) (car original))))
        (lambda () (.ref detached 'specializers)))
      (check-equal? (.ref detached 'specializers) (list any-specializer))
      (.put! detached 'specializers original)
      (set-car! original any-specializer)
      (check-equal? (.ref (car (.ref detached 'specializers)) 'target) 'unrelated))

    (test-case "eql specializers are more specific than class specializers"
      (let* ((generic (clos-generic-function 'feed 1))
             (generic
              (clos-add-method
               generic
               (primary-method
                'dog (list (clos-prototype-specializer dog-class)) 'dog)))
             (eql-dog (clos-eql-specializer dog))
             (generic
              (clos-add-method
               generic
               (primary-method 'this-dog (list eql-dog) 'this-dog))))
        (check-equal?
         (map (lambda (method) (.ref method 'identity))
              (clos-compute-applicable-methods generic dog))
         '(this-dog dog))
        (check-equal? (clos-call generic dog) 'this-dog)
        (check-equal? (clos-call generic (.o (:: @ dog-class))) 'dog)
        (def affected (.o))
        (def unrelated (.o))
        (depend-on-object! affected eql-dog)
        (depend-on-object! unrelated dog-class)
        (def affected-before (object-revision affected))
        (def unrelated-before (object-revision unrelated))
        (def generation (.ref generic 'generation))
        (.put! eql-dog 'target cat)
        (check-equal? (.ref generic 'generation) generation)
        (check-equal? (clos-call generic dog) 'dog)
        (check-equal? (clos-call generic cat) 'this-dog)
        ;; Cell and adapter writes on either reflected snapshot stay local.
        (def revision (object-revision eql-dog))
        (for-each
          (lambda (store)
            (hash-put! store 'target dog)
            (check-equal? (hash-ref store 'target) dog)
            (check-equal? (clos-call generic dog) 'dog)
            (runtime.slot-set! store 'ref
              (lambda (_table _key . _default) 'snapshot-only))
            (check-equal? (hash-ref store 'target) 'snapshot-only)
            (check-equal? (object-revision eql-dog) revision)
            (check-equal? (clos-call generic dog) 'dog)
            (check-equal? (clos-call generic cat) 'this-dog))
          (list (object-instance eql-dog) (hash<-object eql-dog)))
        (check-equal? (object-revision affected) (1+ affected-before))
        (check-equal? (object-revision unrelated) unrelated-before)))

    (test-case "class precedence inspection cannot edit dispatch"
      (def left (clos-class 'left))
      (def right (clos-class 'right))
      (def child
        (clos-class 'child direct-superclasses: (list left)))
      (def instance (clos-make-instance child))
      (def generic (clos-generic-function 'inspect 1))
      (clos-add-method generic
        (primary-method 'left (list (clos-class-specializer left)) 'left))
      (clos-add-method generic
        (primary-method 'right (list (clos-class-specializer right)) 'right))
      (check-equal? (clos-call generic instance) 'left)
      (def revision (object-revision child))
      (def generation (clos-class-generation child))
      (def lookup (.ref child 'class-precedence-index))
      (check-equal? (lookup child) 0)
      (check-exception (hash-put! lookup right 0) true)
      (set-car! (.ref child 'class-precedence-list) right)
      (set-car! (clos-class-precedence-list child) right)
      (check-equal? (car (clos-class-precedence-list child)) child)
      (check-equal? (clos-class-subclass? child right) #f)
      (check-equal? (clos-call generic instance) 'left)
      (check-equal? (object-revision child) revision)
      (check-equal? (clos-class-generation child) generation)
      (clos-redefine-class child direct-superclasses: (list right))
      (check-equal? (lookup right) #f)
      (check-equal? (clos-class-subclass? child right) #t)
      (check-equal? (clos-call generic instance) 'right))

    (test-case "standard qualifier order and lexical next are preserved"
      (let ((trace '())
            (base-generic (clos-generic-function 'render 1)))
        (def (record value)
          (set! trace (append trace (list value))))
        (def (method identity specializer qualifier body)
          (clos-method identity (list specializer) body
                           qualifier: qualifier))
        (def (around-dog frame _dog)
          (record 'around-dog-enter)
          (let (value (clos-call-next-method frame))
            (record 'around-dog-exit)
            value))
        (def (before-animal _frame _animal) (record 'before-animal))
        (def (before-dog _frame _dog) (record 'before-dog))
        (def (primary-animal _frame _animal)
          (record 'primary-animal)
          'animal)
        (def (primary-dog frame replacement)
          (record 'primary-dog)
          (clos-call-next-method frame replacement))
        (def (after-animal _frame _animal) (record 'after-animal))
        (def (after-dog _frame _dog) (record 'after-dog))
        (let* ((animal (clos-prototype-specializer animal-class))
               (dog-specializer (clos-prototype-specializer dog-class))
               (generic
                (foldl
                 (lambda (method generic)
                   (clos-add-method generic method))
                 base-generic
                 (list
                  (method 'around-dog dog-specializer 'around around-dog)
                  (method 'before-animal animal 'before before-animal)
                  (method 'before-dog dog-specializer 'before before-dog)
                  (method 'primary-animal animal 'primary primary-animal)
                  (method 'primary-dog dog-specializer 'primary primary-dog)
                  (method 'after-animal animal 'after after-animal)
                  (method 'after-dog dog-specializer 'after after-dog)))))
          (check-equal? (clos-call generic dog) 'animal)
          (check-equal?
           trace
           '(around-dog-enter before-dog before-animal
             primary-dog primary-animal after-animal after-dog
             around-dog-exit)))))

    (test-case "replacement arguments retain the exact applicable method set"
      (def (delegate frame _value)
        (clos-call-next-method frame cat))
      (def (terminal _frame _value) 'terminal)
      (let* ((generic (clos-generic-function 'replacement 1))
             (generic
              (clos-add-method
               generic
               (clos-method
                'animal (list (clos-prototype-specializer animal-class))
                terminal)))
             (generic
              (clos-add-method
               generic
               (clos-method
                'dog (list (clos-prototype-specializer dog-class))
                delegate))))
        (check-exception (clos-call generic dog)
                         (failure-code? 'changed-applicable-methods))))

    (test-case "replacement compares applicability before method combination"
      (def first-effective #f)
      (def combinations 0)
      (def protocol
        (clos-generic-protocol 'reuse-effective
          compute-effective-method:
          (lambda (_generic _arguments _methods default)
            (set! combinations (1+ combinations))
            (unless first-effective (set! first-effective default))
            first-effective)))
      (def generic (clos-generic-function 'replace-with-eql 1 protocol: protocol))
      (clos-add-method generic (primary-method 'base (list any-specializer) 'base))
      (clos-add-method generic
        (primary-method 'new (list (clos-eql-specializer 'changed)) 'new))
      (clos-add-method generic
        (clos-method 'around (list any-specializer)
          (lambda (frame _value) (clos-call-next-method frame 'changed))
          qualifier: 'around))
      (check-exception (clos-call generic 'original)
                       (failure-code? 'changed-applicable-methods))
      (check-equal? combinations 1))

    (test-case "replacement may reorder methods with agreeing specializers"
      (def (run specializer)
        (def protocol
          (clos-generic-protocol 'reverse-for-replacement
            compute-applicable-methods:
            (lambda (_generic arguments methods)
              (if (eq? (car arguments) dog) methods (reverse methods)))))
        (def generic (clos-generic-function 'reorder 1 protocol: protocol))
        (clos-add-method generic (primary-method 'primary (list specializer) 'terminal))
        (clos-add-method generic
          (clos-method 'around (list any-specializer)
            (lambda (frame _value) (clos-call-next-method frame cat))
            qualifier: 'around))
        (clos-call generic dog))
      (check-equal? (run any-specializer) 'terminal)
      (check-exception (run (clos-prototype-specializer animal-class))
                       (failure-code? 'changed-applicable-methods)))

    (test-case "replacement rechecks applicable hooks before invoking the next method"
      (def (run replace?)
        (def foreign (primary-method 'foreign (list any-specializer) 'foreign))
        (def protocol
          (clos-generic-protocol 'open-ranking
            compute-applicable-methods:
            (lambda (generic arguments methods)
              (cond
               ((not (eq? (car arguments) 'changed)) methods)
               (replace? (clos-add-method generic foreign) methods)
               (else (list foreign))))))
        (def generic (clos-generic-function 'recheck 1 protocol: protocol))
        (clos-add-method generic (primary-method 'base (list any-specializer) 'base))
        (clos-add-method generic
          (clos-method 'around (list any-specializer)
            (lambda (frame _value) (clos-call-next-method frame 'changed))
            qualifier: 'around))
        (clos-call generic 'original))
      (check-exception (run #f) (failure-code? 'invalid-compute-applicable-methods-result))
      (check-exception (run #t) (failure-code? 'changed-applicable-methods)))

    (test-case "rest arguments and multiple values survive effective invocation"
      (def (many _frame _required . rest)
        (apply values rest))
      (let* ((generic (clos-generic-function 'many 1 rest?: #t))
             (generic
              (clos-add-method
               generic
               (clos-method 'many (list any-specializer) many))))
        (check-equal?
         (call-with-values (lambda () (clos-call generic 'x 1 2 3)) list)
         '(1 2 3))))

    (test-case "same qualifier and specializers replace the prior method"
      (let* ((generic (clos-generic-function 'replace 1))
             (specializers (list any-specializer))
             (old (primary-method 'old specializers 'old))
             (new (primary-method 'new specializers 'new))
             (with-old (clos-add-method generic old))
             (with-new (clos-add-method with-old new)))
        (check (eq? generic with-old) => #t)
        (check (eq? with-old with-new) => #t)
        (check-equal? (clos-call with-new 1) 'new)
        (check-equal? (.ref with-new 'generation) 2)
        (check-equal? (length (.ref with-new 'methods)) 1)
        (let (without-new (clos-remove-method with-new new))
          (check-equal? (.ref without-new 'generation) 3)
          (check-equal? (.ref without-new 'methods) '())
          (check-exception (clos-call without-new 1)
                           (failure-code? 'no-applicable-method)))))

    (test-case "a method has one generic owner and find-method uses ANSI qualifiers"
      (let* ((specializers (list any-specializer))
             (method (primary-method 'owned specializers 'owned))
             (first (clos-generic-function 'first-owner 1))
             (second (clos-generic-function 'second-owner 1)))
        (clos-add-method first method)
        (check (eq? (clos-method-generic-function method) first) => #t)
        (check-equal? (clos-method-qualifiers method) '())
        (check (eq? (clos-find-method first '() specializers) method) => #t)
        (check-equal?
         (clos-find-method first '(before) specializers error?: #f) #f)
        (check-exception (clos-find-method first '() '() error?: #f)
                         (failure-code? 'method-required-argument-mismatch))
        (check-exception (clos-find-method second '() '())
                         (failure-code? 'method-required-argument-mismatch))
        (check-exception (clos-find-method first '() '(any) error?: #f)
                         (failure-code? 'invalid-specializer))
        (check-exception (clos-find-method first 'before specializers error?: #f)
                         (failure-code? 'invalid-method-qualifier))
        (check-exception
         (clos-add-method second method)
         (failure-code? 'method-owned-by-another-generic))
        (clos-remove-method first method)
        (check-equal? (clos-method-generic-function method) #f)
        (check (eq? (clos-add-method second method) second) => #t)))

    (test-case "applicable methods extend keyword admission"
      (let* ((method-list
              (clos-lambda-list 1 0 #f #t (list extra:) #f))
             (method
              (clos-method
               'method-key (list any-specializer)
               (lambda (_frame _required . tail) tail)
               lambda-list: method-list))
             (generic
              (clos-add-method
               (clos-generic-function 'method-keys 1 rest?: #t)
               method)))
        (check-equal? (clos-call generic 'value extra: 9)
                      (list extra: 9))
        (check-exception (clos-call generic 'value unknown: 9)
                         (failure-code? 'invalid-keyword-argument))))

    (test-case "malformed keyword arguments refuse before the method body"
      (def called? #f)
      (def method
        (clos-method 'checked (list any-specializer)
                         (lambda (_frame . _arguments) (set! called? #t))))
      (def generic
        (clos-add-method
          (clos-generic-function 'keyword-order 1 key?: #t keys: '(known)) method))
      (check-exception (clos-call generic 'item 'unknown)
                       (failure-code? 'malformed-keyword-arguments))
      (check-exception (clos-call generic 'item 'unknown 1)
                       (failure-code? 'invalid-keyword-argument))
      (check-equal? called? #f)
      (clos-call generic 'item 'known 1)
      (check-equal? called? #t))

    (test-case "no-applicable-method precedes keyword validation"
      (let* ((filtered '())
             (policy (.o allowed: #t))
             (protocol
              (clos-generic-protocol
               'no-app-first
               compute-applicable-methods:
               (lambda (_generic _arguments methods)
                 (set! filtered methods)
                 '())
               compute-effective-method:
               (lambda _ (error "effective method requested for an empty applicable set"))
               no-applicable-method:
               (lambda (_generic _arguments) 'no-applicable)))
             (generic
              (clos-add-method
               (clos-generic-function
                'no-app-first 1 key?: #t keys: '(known) protocol: protocol)
               (primary-method 'filtered (list any-specializer) 'primary))))
        (check-equal? (clos-call generic 'value unknown: 1)
                      'no-applicable)
        (check-equal? (map (lambda (method) (.ref method 'identity)) filtered)
                      '(filtered))
        (def method
          (clos-method
           'no-app-first/specialized
           (list (clos-eql-specializer generic))
           (lambda (_frame original . arguments)
             (values original arguments (.ref policy 'allowed)))
           lambda-list: (clos-lambda-list 1 0 #t #f '() #f)))
        (clos-add-method clos-no-applicable-method-generic method)
        (try
          (let* ((result (.o answer:
                            (call-with-values
                              (lambda () (clos-call generic 'value unknown: 1))
                              list)))
                 (root #f))
            (check-equal?
              (call-with-slot-read-observer
                (lambda (read)
                  (when (and (eq? (slot-read-receiver read) result)
                             (eq? (slot-read-key read) 'answer))
                    (set! root read)))
                (lambda () (.ref result 'answer)))
              (list generic '(value unknown: 1) #t))
            (check-equal? (object-read-issued? root) #t)
            (replay-slot-reads! (list root) (lambda (_receiver _key) (void)))
            (.put! policy 'allowed #f)
            (check-exception
              (replay-slot-reads! (list root) (lambda (_receiver _key) (void))) error?))
          (finally
            (clos-remove-method clos-no-applicable-method-generic method)))))

    (test-case "terminal protocol functions are ordinary mutable generics"
      (let* ((protocol
              (clos-generic-protocol 'local-terminal
                no-next-method: (lambda (_generic _method arguments) (cons 'local arguments))))
             (target (clos-generic-function 'terminal-target 1 protocol: protocol))
             (no-applicable
              (clos-method
               'terminal-target/no-applicable
               (list (clos-eql-specializer target))
               (lambda (_frame generic . arguments)
                 (list (.ref generic 'identity) arguments))
               lambda-list: (clos-lambda-list 1 0 #t #f '() #f)))
             (terminal
              (clos-method
               'terminal-target/primary (list any-specializer)
               (lambda (frame _value)
                 (clos-call-next-method frame))))
             (no-next
              (clos-method
               'terminal-target/no-next
               (list (clos-eql-specializer target) any-specializer)
               (lambda (_frame generic method . arguments)
                 (list (.ref generic 'identity)
                       (.ref method 'identity) arguments))
               lambda-list: (clos-lambda-list 2 0 #t #f '() #f))))
        (clos-add-method clos-no-applicable-method-generic
                             no-applicable)
        (check-equal? (clos-call target 'absent)
                      '(terminal-target (absent)))
        (clos-add-method target terminal)
        (check-equal? (clos-call target 'present) '(local present))
        (clos-add-method clos-no-next-method-generic no-next)
        (check-equal? (clos-call target 'present)
                      '(terminal-target terminal-target/primary (present)))
        (check (eq? (clos-method-generic-function no-applicable)
                    clos-no-applicable-method-generic) => #t)
        (clos-remove-method clos-no-applicable-method-generic
                                no-applicable)
        (clos-remove-method clos-no-next-method-generic no-next)))

    (test-case "typed failures close invalid and inapplicable calls"
      (check-exception
       (clos-generic-function
        'bad-order 2 argument-precedence-order: '(0 0))
       (failure-code? 'invalid-argument-precedence-order))
      (let (generic (clos-generic-function 'missing 1))
        (check-exception (clos-call generic dog)
                         (failure-code? 'no-applicable-method))
        (check-exception (clos-call generic)
                         (failure-code? 'argument-count-mismatch)))
      (let* ((generic (clos-generic-function 'only-before 1))
             (method
              (clos-method
               'before (list any-specializer)
               (lambda (_frame _value) (void)) qualifier: 'before)))
        (check-exception
         (clos-call (clos-add-method generic method) 1)
         (failure-code? 'no-primary-method)))
      (let* ((generic (clos-generic-function 'no-next 1))
             (method
              (clos-method
               'terminal (list any-specializer)
               (lambda (frame _value)
                 (clos-call-next-method frame)))))
        (check-exception
         (clos-call (clos-add-method generic method) 1)
         (failure-code? 'no-next-method))))

    (test-case "single primary still observes carrier policy refusals"
      (def ran? #f)
      (.defgeneric checked-primary (argument))
      (.defmethod (checked-primary argument)
        (set! ran? #t)
        argument)
      (check-equal? (checked-primary dog) dog)
      (def (snapshot) (random-source-state-ref default-random-source))
      (def generic (.generic-object checked-primary))
      (def arguments (list dog))
      (def methods (clos-compute-applicable-methods generic dog))
      (def before-effective (snapshot))
      (def effective (make-effective-method generic arguments '() '() methods '()))
      (def before-frame (snapshot))
      (make-invocation-frame effective arguments #f 'primary (car methods))
      (def after-frame (snapshot))
      (check (equal? before-effective before-frame) => #f)
      (check (equal? before-frame after-frame) => #f)
      (set! ran? #f)
      (def (recording-policy type predicate action)
        (def slots (object-slots type))
        (dynamic-wind
          (lambda () (.putslot! type '.element? ($constant-slot-spec predicate)))
          action
          (lambda () (object-slots-set! type slots))))
      (recording-policy ClosInvocationFrame
        (lambda (_frame) (error "frame checked after effective method refusal"))
        (lambda ()
          (recording-policy ClosEffectiveMethod (lambda (_carrier) #f)
            (lambda ()
              (check-exception (checked-primary dog)
                               (failure-code? 'invalid-effective-method))
              (check-equal? ran? #f)))))
      (check-equal? (checked-primary dog) dog)
      (check-equal? ran? #t))))
