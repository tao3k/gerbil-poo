;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; ANSI short method combinations and generic protocol customization.

(import (only-in :clan/poo/type element?) (only-in :std/test
                 test-suite test-case check-equal? check-exception check)
        (only-in :clan/poo/object .o .ref .cc)
        (only-in :std/list/list foldl)
        (only-in :std/sync/threads thread-join!/error)
        :clan/poo/mop)

(export clos-method-combination-test)

(def any-specializer (clos-any-specializer))
(def combination-animal-class (.o))
(def combination-dog-class (.o (:: @ combination-animal-class)))
(def combination-dog (.o (:: @ combination-dog-class)))

(.define-method-combination declared-collect
  (short list)
  (order most-specific-last)
  (documentation "least-specific value first"))

(.defgeneric declared-values
  (object)
  (method-combination declared-collect))

(.defclass CombinationSyntaxEntity () ())

(.defmethod (declared-values (object CombinationSyntaxEntity))
  (qualifier declared-collect)
  'syntax-method)

(clos-generic-binding-add-method!
 declared-values$clos-generic
 (clos-method
  'declared-animal
  (list (clos-prototype-specializer combination-animal-class))
  (lambda (_frame _object) 'animal)
  qualifier: 'declared-collect))

(clos-generic-binding-add-method!
 declared-values$clos-generic
 (clos-method
  'declared-dog
  (list (clos-prototype-specializer combination-dog-class))
  (lambda (_frame _object) 'dog)
  qualifier: 'declared-collect))

(.define-method-combination declared-long
  (long)
  ((around (around))
   (primary () (required #t)))
  (let (methods (append around primary))
    (call-method (car methods) (cdr methods))))

(.defgeneric declared-long-values
  (object)
  (method-combination declared-long))

(.define-method-combination empty-key-options
  (long (&rest options &key))
  ((primary () (required #t)))
  (call-method (car primary) (cdr primary)))

(clos-generic-binding-add-method!
 declared-long-values$clos-generic
 (clos-method
  'declared-long-animal
  (list (clos-prototype-specializer combination-animal-class))
  (lambda (_frame _object) 'animal)))

(clos-generic-binding-add-method!
 declared-long-values$clos-generic
 (clos-method
  'declared-long-dog
  (list (clos-prototype-specializer combination-dog-class))
  (lambda (frame object)
    (list 'dog (clos-call-next-method frame object)))))

(.defgeneric declared-reordered-values
  (object)
  (method-combination declared-collect 'most-specific-first))

(clos-generic-binding-add-method!
 declared-reordered-values$clos-generic
 (clos-method
  'reordered-animal
  (list (clos-prototype-specializer combination-animal-class))
  (lambda (_frame _object) 'animal)
  qualifier: 'declared-collect))

(clos-generic-binding-add-method!
 declared-reordered-values$clos-generic
 (clos-method
  'reordered-dog
  (list (clos-prototype-specializer combination-dog-class))
  (lambda (_frame _object) 'dog)
  qualifier: 'declared-collect))

(.define-method-combination declared-configured-long
  (long (&optional (order 'most-specific-first) (primary-required? #t)))
  ((around (around))
   (primary () (order order) (required primary-required?)))
  (arguments
   (&whole whole object
    &optional (extra 'missing extra-supplied?)
    &key ((tag: tag) 'none tag-supplied?)))
  (generic-function active-generic)
  "Configured long-form combination"
  (let (invoke-primary
        (lambda ()
          (if (null? primary)
            'no-primary
            (call-method (car primary) (cdr primary)))))
    (let (payload
          (lambda ()
            (list (.ref active-generic 'identity)
                  (= (length whole) 4)
                  (eq? object combination-dog)
                  extra extra-supplied? tag tag-supplied?
                  (invoke-primary))))
      (if (null? around)
        (payload)
        (call-method
         (car around)
         (append (cdr around) (list (make-method (payload)))))))))

(.defgeneric configured-long-values
  (object &optional extra &key ((tag: tag)))
  (method-combination declared-configured-long 'most-specific-last #t))

(def configured-long-lambda-list
  (clos-lambda-list 1 1 #f #t '(tag:) #f))

(clos-generic-binding-add-method!
 configured-long-values$clos-generic
 (clos-method
  'configured-around
  (list (clos-prototype-specializer combination-dog-class))
  (lambda (frame _object . _arguments)
    (list 'around (clos-call-next-method frame)))
  qualifier: 'around lambda-list: configured-long-lambda-list))

(clos-generic-binding-add-method!
 configured-long-values$clos-generic
 (clos-method
  'configured-animal
  (list (clos-prototype-specializer combination-animal-class))
  (lambda (frame _object . _arguments)
    (list 'animal
          (if (clos-next-method? frame)
            (clos-call-next-method frame)
            'end)))
  lambda-list: configured-long-lambda-list))

(clos-generic-binding-add-method!
 configured-long-values$clos-generic
 (clos-method
  'configured-dog
  (list (clos-prototype-specializer combination-dog-class))
  (lambda (frame _object . _arguments)
    (list 'dog
          (if (clos-next-method? frame)
            (clos-call-next-method frame)
            'end)))
  lambda-list: configured-long-lambda-list))

(.defgeneric optional-configured-values
  (object)
  (method-combination declared-configured-long 'most-specific-first #f))

(clos-generic-binding-add-method!
 optional-configured-values$clos-generic
 (clos-method
  'optional-configured-around
  (list (clos-prototype-specializer combination-dog-class))
  (lambda (frame _object)
    (list 'around (clos-call-next-method frame)))
  qualifier: 'around))

(def (failure-code? code)
  (lambda (error)
    (and (clos-failure? error)
         (eq? (.ref error 'code) code))))

(def (constant-method identity qualifier specializer value)
  (clos-method
   identity (list specializer)
   (lambda (_frame _argument)
     (if (procedure? value) (value) value))
   qualifier: qualifier))

(def (add-methods generic methods)
  (foldl (lambda (method current)
           (clos-add-method current method))
         generic methods))

(def clos-method-combination-test
  (test-suite "POO CLOS method combinations and protocol"
    (test-case "standard combinations share qualifier-list meaning with reflection"
      (def seen '())
      (def generic (clos-generic-function 'listed-standard-qualifiers 1))
      (def (add name qualifiers body)
        (def method (clos-method name (list any-specializer) body qualifier: qualifiers))
        (clos-add-method generic method)
        (check-equal? (clos-method-qualifiers method) qualifiers)
        (check-equal? (.ref method 'qualifier) qualifiers)
        method)
      (def primary (add 'primary '() (lambda (_frame _value) (set! seen (cons 'primary seen)) 42)))
      (add 'around '(around)
        (lambda (frame _value)
          (set! seen (cons 'enter seen))
          (def value (clos-call-next-method frame))
          (set! seen (cons 'leave seen)) value))
      (add 'before '(before) (lambda (_frame _value) (set! seen (cons 'before seen))))
      (add 'after '(after) (lambda (_frame _value) (set! seen (cons 'after seen))))
      (check-equal? (clos-call generic 'item) 42)
      (check-equal? (reverse seen) '(enter before primary after leave))
      (check (eq? (clos-find-method generic '() (list any-specializer)) primary) => #t)
      (check-exception
        (add 'qualified-primary '(primary) void)
        (failure-code? 'invalid-method-qualifier))
      (def cycle (list 'around))
      (set-cdr! cycle cycle)
      (for-each
        (lambda (qualifiers)
          (check-exception
            (clos-method 'invalid-list (list any-specializer) void qualifier: qualifiers)
            (failure-code? 'invalid-method)))
        (list '(around . invalid) cycle)))
    (test-case "short combinations select singleton lists through the shared qualifier policy"
      (for-each
        (lambda (name)
          (def generic (clos-generic-function 'listed-short-qualifiers 1
            method-combination: (clos-short-method-combination name list)))
          (def old (clos-method 'shorthand (list any-specializer)
                      (lambda (_frame _value) 'old)
                      qualifier: (if (eq? name 'primary) '(primary) name)))
          (clos-add-method generic old)
          (def replacement (clos-method 'listed (list any-specializer)
                              (lambda (_frame _value) 'new) qualifier: (list name)))
          (clos-add-method generic replacement)
          (check-equal? (clos-method-generic-function old) #f)
          (check (eq? (clos-find-method generic (list name) (list any-specializer)) replacement) => #t)
          (check-equal? (clos-call generic 'item) '(new))
          (check-exception
            (clos-add-method generic
              (clos-method 'unqualified (list any-specializer) void qualifier: '()))
            (failure-code? 'invalid-method-qualifier)))
        '(collect primary)))

    (test-case "matcher collections reject cyclic and improper spines before callbacks"
      (def calls 0)
      (def predicate (lambda (_qualifiers) (set! calls (1+ calls)) #t))
      (def cycle (list predicate))
      (set-cdr! cycle cycle)
      (for-each
        (lambda (matchers)
          (def worker (make-thread (lambda () (clos-method-group 'invalid matchers))))
          (thread-start! worker)
          (check-exception
            (try (thread-join!/error worker 2)
                 (finally (with-catch void (lambda () (thread-terminate! worker)))))
            (failure-code? 'invalid-method-group)))
        (list '() (cons predicate 'invalid-tail) cycle))
      (check (element? ClosMethodGroup
               (clos-method-group 'valid (list '() '(tag . *) predicate))) => #t)
      (check-equal? calls 0))

    (test-case "single-receiver qualifier policy follows effective inherited slots"
      (def parent (clos-short-method-combination 'collect list))
      ;; Force the parent callback before deriving another policy identity.
      (check (clos-method-combination-admits-qualifier? parent 'collect) => #t)
      (def child (.o (:: @ parent) identity: 'release))
      (check (clos-method-combination-admits-qualifier? child 'release) => #t)
      (check (clos-method-combination-admits-qualifier? child 'collect) => #f)
      (check (clos-method-combination-admits-qualifier? parent 'collect) => #t)
      (check (element? ClosMethodCombination
               (.o (:: @ parent) .admits-qualifier?: #f)) => #f)
      ;; Runtime refinement owns this one-axis extension; registration must use
      ;; it too, rather than reimplementing kind dispatch at the call site.
      (def restricted
        (.o (:: @ (clos-standard-method-combination))
          .admits-qualifier?: (lambda (qualifier) (eq? qualifier 'around))))
      (def generic
        (clos-generic-function 'restricted 1 method-combination: restricted))
      (check-exception
       (clos-add-method generic
         (clos-method 'primary (list any-specializer)
           (lambda (_frame _argument) 'never)))
       (failure-code? 'invalid-method-qualifier)))

    (test-case "short declaration lowers to a lexical POO descriptor"
      (check (element? ClosMethodCombination declared-collect) => #t)
      (check-equal? (declared-values combination-dog) '(animal dog))
      (check-equal?
       (declared-values (clos-make-instance CombinationSyntaxEntity))
       '(syntax-method)))

    (test-case "long declaration binds groups and lexical call-method"
      (check (element? ClosMethodCombination declared-long) => #t)
      (check-equal? (declared-long-values combination-dog)
                    '(dog animal))
      (check-exception
       (clos-configure-method-combination empty-key-options unknown: 1)
       (failure-code? 'invalid-method-combination-options))
      (check-exception
       (apply clos-configure-method-combination empty-key-options
         (list 'allow-other-keys #f allow-other-keys: #t unknown: 1))
       (failure-code? 'invalid-method-combination-options))
      (def options (list allow-other-keys: #t 'allow-other-keys #f unknown: 1))
      (check-equal?
       (.ref (apply clos-configure-method-combination empty-key-options options)
             'configuration)
       options))

    (test-case "combination options configure short order without mutation"
      (check-equal? (declared-values combination-dog) '(animal dog))
      (check-equal? (declared-reordered-values combination-dog) '(dog animal))
      (check-equal? (.ref declared-collect 'order) 'most-specific-last))

    (test-case "long configuration, argument bindings, and make-method compose"
      (check-equal?
       (configured-long-values combination-dog 'extra tag: 'tagged)
       '(around
         (configured-long-values #t #t extra #t tagged #t
                                 (animal (dog end)))))
      (check-equal?
       (optional-configured-values combination-dog)
       '(around
         (optional-configured-values #f #t missing #f none #f no-primary)))
      (check-equal? (.ref declared-configured-long 'configuration) '())
      (check-exception
       (clos-configure-method-combination
        declared-configured-long 'sideways #t)
       (failure-code? 'invalid-method-group))
      (let* ((required-combination
              (clos-configure-method-combination
               declared-configured-long 'most-specific-first #t))
             (around-only
              (clos-add-method
               (clos-generic-function
                'configured-required 1
                method-combination: required-combination)
               (clos-method
                'configured-required-around (list any-specializer)
                (lambda (_frame _object) 'unreachable)
                qualifier: 'around))))
        (check-exception
         (clos-call around-only 'object)
         (failure-code? 'required-method-group-empty))))

    (test-case "numeric built-ins combine in admitted specificity order"
      (let* ((animal (clos-prototype-specializer combination-animal-class))
             (dog (clos-prototype-specializer combination-dog-class))
             (plus
              (add-methods
               (clos-generic-function 'score 1 method-combination: '+)
               (list (constant-method 'animal '+ animal 3)
                     (constant-method 'dog '+ dog 7))))
             (maximum
              (add-methods
               (clos-generic-function 'maximum 1
                                          method-combination: 'max)
               (list (constant-method 'animal 'max animal 3)
                     (constant-method 'dog 'max dog 7))))
             (minimum
              (add-methods
               (clos-generic-function 'minimum 1
                                          method-combination: 'min)
               (list (constant-method 'animal 'min animal 3)
                     (constant-method 'dog 'min dog 7)))))
        (check-equal? (clos-call plus combination-dog) 10)
        (check-equal? (clos-call maximum combination-dog) 7)
        (check-equal? (clos-call minimum combination-dog) 3)))

    (test-case "list order and sequence built-ins preserve their operators"
      (let* ((animal (clos-prototype-specializer combination-animal-class))
             (dog (clos-prototype-specializer combination-dog-class))
             (collect
              (clos-short-method-combination
               'collect 'list order: 'most-specific-last))
             (listed
              (add-methods
               (clos-generic-function
                'listed 1 method-combination: collect)
               (list (constant-method 'animal 'collect animal 'animal)
                     (constant-method 'dog 'collect dog 'dog))))
             (appended
              (add-methods
               (clos-generic-function 'appended 1
                                          method-combination: 'append)
               (list (constant-method 'animal 'append animal '(animal))
                     (constant-method 'dog 'append dog '(dog)))))
             (concatenated
              (add-methods
               (clos-generic-function 'concatenated 1
                                          method-combination: 'nconc)
               (list (constant-method 'animal 'nconc animal
                                      (lambda () (list 'animal)))
                     (constant-method 'dog 'nconc dog
                                      (lambda () (list 'dog)))))))
        (check-equal? (clos-call listed combination-dog) '(animal dog))
        (check-equal? (clos-call appended combination-dog) '(dog animal))
        (check-equal? (clos-call concatenated combination-dog)
                      '(dog animal))))

    (test-case "and, or, and progn retain short-circuit evaluation"
      (let ((trace '())
            (animal (clos-prototype-specializer combination-animal-class))
            (dog (clos-prototype-specializer combination-dog-class)))
        (def (record value result)
          (lambda ()
            (set! trace (append trace (list value)))
            result))
        (let (and-generic
              (add-methods
               (clos-generic-function 'all 1 method-combination: 'and)
               (list (constant-method 'animal 'and animal
                                      (record 'animal #t))
                     (constant-method 'dog 'and dog (record 'dog #f)))))
          (check-equal? (clos-call and-generic combination-dog) #f)
          (check-equal? trace '(dog)))
        (set! trace '())
        (let (or-generic
              (add-methods
               (clos-generic-function 'some 1 method-combination: 'or)
               (list (constant-method 'animal 'or animal
                                      (record 'animal 'fallback))
                     (constant-method 'dog 'or dog
                                      (record 'dog 'specific)))))
          (check-equal? (clos-call or-generic combination-dog) 'specific)
          (check-equal? trace '(dog)))
        (set! trace '())
        (let (progn-generic
              (add-methods
               (clos-generic-function 'steps 1
                                          method-combination: 'progn)
               (list (constant-method 'animal 'progn animal
                                      (record 'animal 'last))
                     (constant-method 'dog 'progn dog
                                      (record 'dog 'first)))))
          (check-equal? (clos-call progn-generic combination-dog) 'last)
          (check-equal? trace '(dog animal)))))

    (test-case "one-argument identity preserves multiple values"
      (let* ((identity-combination
              (clos-short-method-combination
               'identity-max 'max identity-with-one-argument?: #t))
             (method
              (clos-method
               'only (list any-specializer)
               (lambda (_frame _argument) (values 3 4))
               qualifier: 'identity-max))
             (generic
              (clos-add-method
               (clos-generic-function
                'only 1 method-combination: identity-combination)
               method)))
        (check-equal?
         (call-with-values (lambda () (clos-call generic 'value)) list)
         '(3 4))))

    (test-case "around methods cannot hide a missing primary"
      (let* ((standard-around
              (clos-method
               'standard-around (list any-specializer)
               (lambda (_frame _argument) 'standard-short-circuit)
               qualifier: 'around))
             (standard
              (clos-add-method
               (clos-generic-function 'standard-around 1)
               standard-around))
             (short-around
              (clos-method
               'short-around (list any-specializer)
               (lambda (_frame _argument) 'short-short-circuit)
               qualifier: 'around))
             (short
              (clos-add-method
               (clos-generic-function 'short-around 1
                                          method-combination: '+)
               short-around)))
        (check-exception (clos-call standard 'value)
                         (failure-code? 'no-primary-method))
        (check-exception (clos-call short 'value)
                         (failure-code? 'no-primary-method))))

    (test-case "generic protocol owns terminal and computation hooks"
      (let* ((fallback-protocol
              (clos-generic-protocol
               'fallback
               no-applicable-method:
               (lambda (generic arguments)
                 (list 'missing (.ref generic 'identity) arguments))))
             (missing
              (clos-generic-function
               'missing 1 protocol: fallback-protocol)))
        (check-equal? (clos-call missing 'payload)
                      '(missing missing (payload))))
      (let* ((next-protocol
              (clos-generic-protocol
               'next-fallback
               no-next-method:
               (lambda (generic method arguments)
                 (list (.ref generic 'identity)
                       (.ref method 'identity) arguments))))
             (terminal
              (clos-method
               'terminal (list any-specializer)
               (lambda (frame argument)
                 (clos-call-next-method frame argument))))
             (generic
              (clos-add-method
               (clos-generic-function
                'next-fallback 1 protocol: next-protocol)
               terminal)))
        (check-equal? (clos-call generic 'payload)
                      '(next-fallback terminal (payload))))
      (let* ((animal (clos-prototype-specializer combination-animal-class))
             (dog (clos-prototype-specializer combination-dog-class))
             (reverse-protocol
              (clos-generic-protocol
               'reverse
               compute-applicable-methods:
               (lambda (_generic _arguments methods) (reverse methods))))
             (generic
              (add-methods
               (clos-generic-function
                'reversed 1 protocol: reverse-protocol)
               (list (constant-method 'animal 'primary animal 'animal)
                     (constant-method 'dog 'primary dog 'dog)))))
        (check-equal? (clos-call generic combination-dog) 'animal)
        (check (element? ClosEffectiveMethod
                         (clos-compute-effective-method
                          generic combination-dog))
               => #t)))

    (test-case "long combinations partition groups and drive explicit next chains"
      (def combinations 0)
      (let* ((around-group
              (clos-method-group 'around '((around))))
             (primary-group
              (clos-method-group 'primary '(()) required?: #t))
             (combination
              (clos-long-method-combination
               'long-standard (list around-group primary-group)
               (lambda (_generic _arguments _groups)
                 (set! combinations (1+ combinations))
                 (lambda (effective-method)
                   (let ((around
                          (clos-effective-method-group
                           effective-method 'around))
                         (primary
                          (clos-effective-method-group
                           effective-method 'primary)))
                     (let (methods (append around primary))
                       (clos-call-method
                        effective-method (car methods) (cdr methods))))))))
             (animal (clos-prototype-specializer combination-animal-class))
             (dog (clos-prototype-specializer combination-dog-class))
             (around
              (clos-method
               'around (list dog)
               (lambda (frame argument)
                 (list 'around
                       (clos-call-next-method frame argument)))
               qualifier: 'around))
             (animal-primary
              (constant-method 'animal 'primary animal 'animal))
             (dog-primary
              (clos-method
               'dog (list dog)
               (lambda (frame argument)
                 (list 'dog
                       (clos-call-next-method frame argument)))))
             (generic
              (add-methods
               (clos-generic-function
                'long-standard 1 method-combination: combination)
               (list around animal-primary dog-primary))))
        (check-equal? (clos-call generic combination-dog)
                      '(around (dog animal)))
        (check-equal? combinations 1)
        (let (effective-method
              (clos-compute-effective-method generic combination-dog))
          (check-equal?
           (map (lambda (method) (.ref method 'identity))
                (clos-effective-method-group effective-method 'primary))
           '(dog animal)))))

    (test-case "long groups enforce required, claimed, and unambiguous methods"
      (let* ((required-group
              (clos-method-group
               'required '((needed)) required?: #t))
             (fallback-group
              (clos-method-group 'fallback '(*)))
             (required-combination
              (clos-long-method-combination
               'required (list required-group fallback-group)
               (lambda (_generic _arguments _groups)
                 (lambda (_effective-method) 'unreachable))))
             (generic
              (clos-add-method
               (clos-generic-function
                'required 1 method-combination: required-combination)
               (constant-method
                'fallback 'fallback any-specializer 'value))))
        (check-exception
         (clos-call generic 'argument)
         (failure-code? 'required-method-group-empty)))
      (let* ((primary-group (clos-method-group 'primary '(())))
             (combination
              (clos-long-method-combination
               'claimed (list primary-group)
               (lambda (_generic _arguments _groups)
                 (lambda (_effective-method) 'unreachable))))
             (generic
              (clos-add-method
               (clos-generic-function
                'claimed 1 method-combination: combination)
               (constant-method 'foreign 'foreign any-specializer 'bad))))
        (check-exception
         (clos-call generic 'argument)
         (failure-code? 'invalid-method-qualifier)))
      (let* ((all-group (clos-method-group 'all '(*)))
             (combination
              (clos-long-method-combination
               'ambiguous (list all-group)
               (lambda (_generic _arguments _groups)
                 (lambda (_effective-method) 'unreachable))))
             (generic
              (add-methods
               (clos-generic-function
                'ambiguous 1 method-combination: combination)
               (list (constant-method 'first 'first any-specializer 1)
                     (constant-method 'second 'second any-specializer 2)))))
        (check-exception
         (clos-call generic 'argument)
         (failure-code? 'ambiguous-method-group-order))))

    (test-case "invalid qualifiers and protocol results fail before invocation"
      (let* ((generic
              (clos-generic-function 'bad-qualifier 1
                                         method-combination: '+))
             (method
              (constant-method 'bad 'primary any-specializer 1)))
        (check-exception (clos-add-method generic method)
                         (failure-code? 'invalid-method-qualifier)))
      (let* ((protocol
              (clos-generic-protocol
               'invalid
               compute-effective-method:
               (lambda (_generic _arguments _methods _default) #f)))
             (generic
              (clos-add-method
               (clos-generic-function 'invalid 1 protocol: protocol)
               (constant-method 'method 'primary any-specializer 'value))))
        (check-exception
         (clos-call generic 'argument)
         (failure-code? 'invalid-effective-method-result)))
      (let* ((protocol
              (clos-generic-protocol 'wrong-effective-arguments
                compute-effective-method:
                (lambda (_generic _arguments _methods default)
                  (.cc default 'arguments '(different)))))
             (generic
              (clos-add-method
               (clos-generic-function 'wrong-effective-arguments 1 protocol: protocol)
               (constant-method 'method 'primary any-specializer 'value))))
        (check-exception (clos-call generic 'argument)
                         (failure-code? 'invalid-effective-method-result)))
      (let* ((terminal-called? #f)
             (protocol
              (clos-generic-protocol
               'empty-effective-method
               no-applicable-method:
               (lambda (_generic _arguments) (set! terminal-called? #t))
               compute-effective-method:
               (lambda (_generic _arguments _methods default)
                 (.cc default 'around '() 'before '() 'primary '() 'after '()
                              'executor #f))))
             (generic
              (clos-add-method
               (clos-generic-function 'empty-effective-method 1 protocol: protocol)
               (constant-method 'method 'primary any-specializer 'value))))
        (check-exception (clos-call generic 'argument)
                         (failure-code? 'invalid-effective-method-result))
        (check-equal? terminal-called? #f)))))
