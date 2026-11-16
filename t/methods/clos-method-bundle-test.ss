;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import :std/test
        (only-in :clan/poo/object .def .o .ref seal-object! object-revision
                 replay-slot-reads!)
        (only-in :clan/poo/mop element?)
        (only-in :clan/poo/slot-observation %call-with-recorded-slot-reads)
        (only-in :std/error Error? Error-message)
        (only-in :std/sync/threads thread-join!/error)
        :clan/poo/mop)

(export clos-method-bundle-test)

(def bundle-protocol (clos-generic-protocol 'render))
(def other-protocol (clos-generic-protocol 'other))

(def base-method
  (clos-method
   'base (list (clos-any-specializer))
   (lambda (_frame value) (list 'base value))))

(.defmethod-bundle render-methods bundle-protocol base-method)

(def (fresh-method identity tag)
  (clos-method
   identity (list (clos-any-specializer))
   (lambda (_frame value) (list tag value))))

(def (fresh-bundle identity protocol-value method-identity tag)
  (clos-method-bundle
   identity protocol-value (list (fresh-method method-identity tag))))

(.def BundlePrototype.)
(.def (BundleChildPrototype. @ BundlePrototype.))
(.defclass BundleClass () ())

(def declared-protocol (clos-generic-protocol 'declared-bundle))
(def protocol-evaluations 0)
(def target-evaluations 0)
(def body-evaluations 0)

(.defgeneric deferred-render (object)
  (protocol (begin
              (set! protocol-evaluations (+ protocol-evaluations 1))
              declared-protocol)))
(.defmethod (deferred-render object) 'fallback)
(def initial-generation
  (.ref (clos-generic-binding-current deferred-render$clos-generic)
        'generation))

(defrules runtime-deferred-method ()
  ((_ generic target body ...)
   (.defmethod (generic (object (prototype target))) body ...)))

(.defmethod-bundle declared-methods declared-protocol
  (.defmethod (deferred-render
                (object (prototype
                          (begin
                            (set! target-evaluations (+ target-evaluations 1))
                            BundlePrototype.))))
    (set! body-evaluations (+ body-evaluations 1))
    'base)
  (runtime-deferred-method deferred-render BundleChildPrototype.
    (list 'child (call-next-method) (next-method-p))))

(.defmethod-bundle empty-declared-methods declared-protocol)

(.defmethod-bundle wrong-declared-methods
  (clos-generic-protocol 'declared-bundle)
  (runtime-deferred-method deferred-render BundleChildPrototype. 'wrong))

(.defgeneric deferred-kinds (object) (protocol declared-protocol))
(.defmethod (deferred-kinds object) 'fallback)
(.defmethod-bundle kind-methods declared-protocol
  (.defmethod (deferred-kinds (object BundleClass)) 'class)
  (.defmethod (deferred-kinds (object (eql 'sentinel))) 'eql)
  (runtime-deferred-method deferred-kinds BundlePrototype. 'prototype))

(.defgeneric deferred-strict (object &optional extra)
  (protocol declared-protocol))
(.defmethod-bundle incongruent-methods declared-protocol
  (.defmethod (deferred-strict object) 'wrong-arity))

(.defgeneric nested-registration (object))
(.defmethod (nested-registration object) 'before)
(.defgeneric deferred-body (object) (protocol declared-protocol))
(.defmethod-bundle body-methods declared-protocol
  (runtime-deferred-method deferred-body BundlePrototype.
    (.defmethod (nested-registration object) 'after)
    'outer))

;; Deferred descriptors need not resolve a Generic binding during declaration.
(.defmethod-bundle forward-methods declared-protocol
  (runtime-deferred-method forward-render BundlePrototype. 'forward))
(.defgeneric forward-render (object) (protocol declared-protocol))

(def clos-method-bundle-test
  (test-suite "POO CLOS generic protocol and method bundle composition"
    (test-case "malformed bundle collections retain the published methods and read evidence"
      (def generic (clos-generic-function 'finite-bundles 1 protocol: bundle-protocol))
      (def existing (fresh-method 'existing 'existing))
      (clos-add-method generic existing)
      (def pending (fresh-method 'pending 'pending))
      (def bundle (clos-method-bundle 'pending bundle-protocol (list pending)))
      (def cycle (list bundle))
      (set-cdr! cycle cycle)
      (def generation (clos-generic-generation generic))
      (def revision (object-revision generic))
      (defvalues (_ roots) (%call-with-recorded-slot-reads (lambda () (.ref generic 'methods))))
      (for-each
        (lambda (bundles)
          (def worker (make-thread (lambda () (clos-compose-method-bundles generic bundles))))
          (thread-start! worker)
          (check-exception
            (try (thread-join!/error worker 2)
                 (finally (with-catch void (lambda () (thread-terminate! worker)))))
            (lambda (failure)
              (and (clos-failure? failure) (eq? (.ref failure 'code) 'invalid-method-bundle))))
          (check-equal? (clos-generic-generation generic) generation)
          (check-equal? (object-revision generic) revision)
          (check-equal? (clos-generic-methods generic) (list existing))
          (check-equal? (clos-method-generic-function pending) #f)
          (check (eq? (clos-method-generic-function existing) generic) => #t)
          (replay-slot-reads! roots void))
        (list (cons bundle 'invalid-tail) cycle))
      (check (eq? (clos-compose-method-bundles generic '()) generic) => #t)
      (check-equal? (clos-generic-generation generic) generation))

    (test-case "protocol expression preserves identity and evaluates once"
      (check-equal? protocol-evaluations 1)
      (check (eq? (.ref (clos-generic-binding-current
                         deferred-render$clos-generic) 'protocol)
                  declared-protocol) => #t))
    (test-case "direct and defrules methods remain inert until explicit composition"
      (check-equal? target-evaluations 1)
      (check-equal? body-evaluations 0)
      (check-equal? (length (.ref declared-methods 'methods)) 2)
      (check-equal? (.ref empty-declared-methods 'methods) '())
      (check-equal?
       (.ref (clos-generic-binding-current deferred-render$clos-generic)
             'generation)
       initial-generation)
      (check-equal? (deferred-render (.o (:: @ BundleChildPrototype.))) 'fallback)
      (clos-compose-method-bundle deferred-render$clos-generic
                                    empty-declared-methods)
      (check-equal?
       (.ref (clos-generic-binding-current deferred-render$clos-generic)
             'generation)
       initial-generation))
    (test-case "same-labelled different protocol rejects before registration"
      (check-exception
       (clos-compose-method-bundle deferred-render$clos-generic
                                      wrong-declared-methods)
       (lambda (failure)
         (and (clos-failure? failure)
              (eq? (.ref failure 'code) 'method-bundle-protocol-mismatch))))
      (check-equal?
       (.ref (clos-generic-binding-current deferred-render$clos-generic)
             'generation)
       initial-generation))
    (test-case "failed bundle construction cannot leak a declared method"
      (check-exception
       (let ()
         (.defmethod-bundle invalid-declared-methods declared-protocol
           (.defmethod (deferred-render object) 'leaked)
           #f)
         invalid-declared-methods)
       (lambda (failure)
         (and (clos-failure? failure)
              (eq? (.ref failure 'code) 'invalid-method-bundle))))
      (check-equal?
       (.ref (clos-generic-binding-current deferred-render$clos-generic)
             'generation)
       initial-generation)
      (check-equal? (deferred-render (.o (:: @ BundleChildPrototype.))) 'fallback))
    (test-case "explicit compose activates methods and lexical next-method"
      (clos-compose-method-bundle deferred-render$clos-generic
                                    declared-methods)
      (check-equal?
       (.ref (clos-generic-binding-current deferred-render$clos-generic)
             'generation)
       (+ initial-generation 2))
      (check-equal? (deferred-render (.o (:: @ BundleChildPrototype.)))
                    '(child base #t))
      (check-equal? body-evaluations 1)
      (check-equal? target-evaluations 1)
      (check-equal? protocol-evaluations 1))
    (test-case "deferred class eql and prototype declarations share existing dispatch"
      (check-equal? (deferred-kinds 'sentinel) 'fallback)
      (clos-compose-method-bundle deferred-kinds$clos-generic kind-methods)
      (check-equal? (deferred-kinds 'sentinel) 'eql)
      (check-equal? (deferred-kinds (clos-make-instance BundleClass)) 'class)
      (check-equal? (deferred-kinds (.o (:: @ BundleChildPrototype.))) 'prototype))
    (test-case "deferred congruence admission occurs at explicit composition"
      (check-equal?
       (.ref (clos-generic-binding-current deferred-strict$clos-generic)
             'generation) 0)
      (check-exception
       (clos-compose-method-bundle deferred-strict$clos-generic
                                      incongruent-methods)
       (lambda (failure)
         (and (clos-failure? failure)
              (eq? (.ref failure 'code) 'incongruent-method-lambda-list))))
      (check-equal?
       (.ref (clos-generic-binding-current deferred-strict$clos-generic)
             'generation) 0))
    (test-case "method body restores ordinary immediate nested declarations"
      (check-equal? (nested-registration 'value) 'before)
      (clos-compose-method-bundle deferred-body$clos-generic body-methods)
      (check-equal? (nested-registration 'value) 'before)
      (check-equal? (deferred-body (.o (:: @ BundlePrototype.))) 'outer)
      (check-equal? (nested-registration 'value) 'after))
    (test-case "deferred declarations may precede their Generic binding"
      (check-equal?
       (.ref (clos-generic-binding-current forward-render$clos-generic)
             'generation) 0)
      (clos-compose-method-bundle forward-render$clos-generic forward-methods)
      (check-equal? (forward-render (.o (:: @ BundleChildPrototype.))) 'forward))
    (test-case "thin defrule produces a runtime checked bundle"
      (check (element? ClosMethodBundle render-methods) => #t)
      (check (.ref render-methods 'protocol) => bundle-protocol)
      (check (.ref render-methods 'methods) => (list base-method)))
    (test-case "one protocol composes a bundle into generic dispatch"
      (let ((generic (clos-generic-function 'render 1 protocol: bundle-protocol))
            (bundle (fresh-bundle 'base bundle-protocol 'base 'base)))
        (check (clos-compose-method-bundle generic bundle) => generic)
        (check (clos-call generic 'payload) => '(base payload))))
    (test-case "several bundles preserve ordinary replacement admission"
      (let* ((generic (clos-generic-function 'render 1 protocol: bundle-protocol))
             (base-bundle (fresh-bundle 'base bundle-protocol 'base 'base))
             (replacement-bundle
              (fresh-bundle 'replacement bundle-protocol
                            'replacement 'replacement)))
        (check (clos-compose-method-bundles
                generic (list base-bundle replacement-bundle))
               => generic)
        (check (clos-call generic 'payload) => '(replacement payload))
        (check-equal? (clos-generic-generation generic) 2)
        (check-equal? (clos-method-generic-function
                        (car (.ref base-bundle 'methods))) #f)
        (check (eq? (clos-method-generic-function
                      (car (.ref replacement-bundle 'methods))) generic) => #t)))
    (test-case "a refused method or write preserves dispatch, owners and revisions"
      (let* ((generic (clos-generic-function 'atomic 1 protocol: bundle-protocol))
             (old (fresh-method 'old 'original))
             (replacement (fresh-method 'new 'replacement))
             (invalid (clos-method 'bad '() (lambda (_frame) 'bad)))
             (first (clos-method-bundle 'first bundle-protocol (list replacement)))
             (mixed (clos-method-bundle 'mixed bundle-protocol (list replacement invalid)))
             (last (clos-method-bundle 'last bundle-protocol (list invalid))))
        (clos-add-method generic old)
        (defvalues (original-methods reads)
          (%call-with-recorded-slot-reads (cut .ref generic 'methods)))
        (def original-revision (object-revision generic))
        (def old-revision (object-revision old))
        (def (check-unchanged)
          (check-equal? (.ref generic 'methods) original-methods)
          (check-equal? (clos-generic-generation generic) 1)
          (check-equal? (object-revision generic) original-revision)
          (check-equal? (object-revision old) old-revision)
          (check (eq? (clos-method-generic-function old) generic) => #t)
          (check-equal? (clos-method-generic-function replacement) #f)
          (replay-slot-reads! reads void)
          (check-equal? (clos-call generic 'payload) '(original payload)))
        (def (arity-failure? failure)
          (and (clos-failure? failure)
               (eq? (.ref failure 'code) 'method-required-argument-mismatch)))
        (check-exception (clos-compose-method-bundle generic mixed) arity-failure?)
        (check-unchanged)
        (check-exception (clos-compose-method-bundles generic (list first last)) arity-failure?)
        (check-unchanged)
        (seal-object! replacement)
        (check-exception
         (clos-compose-method-bundle generic first)
         (lambda (failure)
           (and (Error? failure) (equal? (Error-message failure) "sealed prototype"))))
        (check-unchanged)
        (check-exception (clos-add-method generic replacement)
          (lambda (failure)
            (and (Error? failure) (equal? (Error-message failure) "sealed prototype"))))
        (check-unchanged)))
    (test-case "protocol identity mismatch fails before method ownership changes"
      (let* ((generic (clos-generic-function 'render 1 protocol: bundle-protocol))
             (bundle (fresh-bundle 'wrong other-protocol 'wrong 'wrong)))
        (check-exception
         (clos-compose-method-bundle generic bundle)
         (lambda (failure)
           (and (clos-failure? failure)
                (eq? (.ref failure 'code)
                     'method-bundle-protocol-mismatch))))
        (check (clos-generic-methods generic) => '())))))
