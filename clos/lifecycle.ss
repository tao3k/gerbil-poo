;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Standard CLOS instance allocation, initialization, and slot access.

(import :clan/poo/object
        (only-in :std/hash/misc hash-ref/default)
        (only-in :std/list/list filter-map find)
        "types.ss" "objects.ss" "classes.ss" "dispatch.ss"
        "instance-state.ss" "funcs.ss")

(export ClosInstanceState ClosSlotCell clos-instance?
        clos-class-of clos-allocate-instance clos-make-instance
        clos-initialize-instance clos-shared-initialize
        clos-reinitialize-instance clos-slot-value
        clos-set-slot-value! clos-slot-bound? clos-slot-exists?
        clos-slot-makunbound! clos-slot-reader-method
        clos-slot-missing clos-slot-unbound
        clos-slot-missing-generic clos-slot-unbound-generic
        clos-slot-writer-method clos-change-class
        clos-update-instance-for-redefined-class
        clos-update-instance-for-different-class
        clos-allocate-instance-generic clos-make-instance-generic
        clos-initialize-instance-generic
        clos-shared-initialize-generic
        clos-reinitialize-instance-generic clos-change-class-generic
        clos-update-instance-for-redefined-class-generic
        clos-update-instance-for-different-class-generic)

(extern namespace: clan/poo/clos/dispatch %prospective-instance-methods)
(extern namespace: clan/poo/object %publish-slot-edits!)

;; : (-> ClosInstance [Symbol] [Symbol] [SchemeValue] SchemeValue ... ClosInstance)
(def (%clos-update-instance-for-redefined-class
      instance-value added discarded property-list . initargs)
  (let* ((class-value (.ref (.ref instance-value '%clos-state) 'class))
         (handler (class-handler class-value 'redefinition-update-handler)))
    (require-initialization-arguments
     class-value 'update-instance-for-redefined-class initargs
     (lambda ()
       (append
        (apply clos-compute-applicable-methods
               clos-update-instance-for-redefined-class-generic
               instance-value added discarded property-list initargs)
        (apply clos-compute-applicable-methods
               clos-shared-initialize-generic instance-value added initargs))))
    (apply clos-shared-initialize instance-value added initargs)
    (if handler
      (handler instance-value added discarded property-list)
      instance-value)))

;; : (-> ClosInstance ClosInstance SchemeValue ... ClosInstance)
(def (%clos-update-instance-for-different-class
      previous-value instance-value . initargs)
  (let ((previous-class (clos-class-of previous-value))
        (class-value (clos-class-of instance-value)))
    (let-values (((added _) (class-slot-difference previous-class class-value)))
      (require-initialization-arguments
       class-value 'update-instance-for-different-class initargs
       (lambda ()
         (append
          (apply clos-compute-applicable-methods
                 clos-update-instance-for-different-class-generic
                 previous-value instance-value initargs)
          (apply clos-compute-applicable-methods
                 clos-shared-initialize-generic instance-value added initargs))))
      (apply clos-shared-initialize instance-value added initargs)
      (let (handler (class-handler class-value 'different-class-update-handler))
        (if handler
          (apply handler previous-value instance-value initargs)
          instance-value)))))

;;; One lazy step retains cells for still-present slots and publishes the new
;;; layout before the update generic initializes the added slots.
;; : (-> ClosInstance ClosInstanceState ClosClass ClosInstanceState)
(def (migrate-instance-generation! instance-value state class-value)
  (let-values (((added discarded)
                (effective-slot-difference
                 (class-effective-slots-at-generation
                  class-value (.ref state 'generation))
                 (clos-class-effective-slots class-value))))
    (let ((property-list (discarded-slot-property-list state discarded))
          (new-storage (migrated-instance-storage state class-value)))
      (%publish-slot-edits!
       (list (list state
                   (cons 'class class-value)
                   (cons 'generation (.ref class-value 'generation))
                   (cons 'storage new-storage))))
      (clos-update-instance-for-redefined-class
       instance-value added discarded property-list)
      state)))

;; : (-> ClosInstance ClosInstanceState)
(def (ensure-current-instance-state! instance-value)
  (unless (clos-instance? instance-value) (clos-fail 'invalid-instance))
  (let* ((state (.ref instance-value '%clos-state))
         (class-value (.ref state 'class)))
    (if (= (.ref state 'generation) (.ref class-value 'generation))
      state
      (migrate-instance-generation! instance-value state class-value))))

;; : (-> ClosInstance ClosClass)
(def (clos-class-of instance-value)
  (.ref (ensure-current-instance-state! instance-value) 'class))

;; : (-> ClosClass ClosInstance)
(def (%clos-allocate-instance class-value . _initargs)
  (let (current-value (clos-resolve-class class-value))
    (.o (:: @ (.ref current-value 'instance-prototype))
        %clos-state: (make-instance-state current-value))))

;; : (-> ClosInstance Symbol (Maybe ClosSlotCell))
(def (instance-slot-cell instance-value slot-name)
  (let* ((class-value (clos-class-of instance-value))
         (slot (clos-find-effective-slot class-value slot-name)))
    (and slot
         (if (eq? (.ref slot 'allocation) 'class)
           (clos-class-slot-cell (.ref slot 'storage-class) slot-name)
           (hash-ref/default
            (.ref (.ref instance-value '%clos-state) 'storage)
            slot-name (lambda () #f))))))

;; Initialization already traverses effective slot definitions.  Resolve the
;; cell directly instead of searching the full effective-slot list again.
(def (effective-slot-cell state slot)
  (if (eq? (.ref slot 'allocation) 'class)
    (clos-class-slot-cell (.ref slot 'storage-class)
                              (.ref slot 'identity))
    (hash-ref/default (.ref state 'storage) (.ref slot 'identity)
                      (lambda () #f))))

(def (bind-effective-slot! state slot value)
  (let (cell (effective-slot-cell state slot))
    (unless cell
      (clos-fail 'slot-missing slot: (.ref slot 'identity)
                 operation: 'initialize-instance))
    (.put! cell 'value value)
    (.put! cell 'bound? #t)))

;; : (-> SchemeValue (Maybe Symbol))
(def (failure-name value)
  (cond
   ((symbol? value) value)
   ((keyword? value) (string->symbol (keyword->string value)))
   (else #f)))

;; : (-> ClosClass ClosInstance Symbol Symbol [SchemeValue] SchemeValue)
(def (call-slot-missing class-value instance-value slot-name operation args)
  (apply clos-slot-missing class-value instance-value slot-name operation
         args))

;; : (-> ClosClass ClosInstance Symbol SchemeValue)
(def (call-slot-unbound class-value instance-value slot-name)
  (clos-slot-unbound class-value instance-value slot-name))

;;; The standard slot protocol is expressed as ordinary mutable generic
;;; functions.  Class-owned procedure handlers remain a compatibility bridge
;;; in the default methods, not the primary extension surface.
;; : (-> ClosClass ClosInstance Symbol Symbol SchemeValue ... SchemeValue)
(def (clos-slot-missing class-value instance-value slot-name operation
                            . values)
  (apply clos-call clos-slot-missing-generic
         class-value instance-value slot-name operation values))

;; : (-> ClosClass ClosInstance Symbol SchemeValue)
(def (clos-slot-unbound class-value instance-value slot-name)
  (clos-call clos-slot-unbound-generic
                 class-value instance-value slot-name))

;; : ClosGenericFunction
(def clos-slot-missing-generic
  (clos-add-method
   (clos-generic-function 'slot-missing 4 optional: 1)
   (clos-method
    'slot-missing/default
    (list (clos-any-specializer) (clos-any-specializer)
          (clos-any-specializer) (clos-any-specializer))
    (lambda (_frame class-value instance-value slot-name operation . values)
      (let (handler (class-handler class-value 'slot-missing-handler))
        (if handler
          (apply handler class-value instance-value slot-name operation values)
          (clos-fail 'slot-missing class: (.ref class-value 'identity)
                     slot: slot-name operation: operation))))
    lambda-list: (clos-lambda-list 4 1 #f #f '() #f))))

;; : ClosGenericFunction
(def clos-slot-unbound-generic
  (clos-add-method
   (clos-generic-function 'slot-unbound 3)
   (clos-method
    'slot-unbound/default
    (list (clos-any-specializer) (clos-any-specializer)
          (clos-any-specializer))
    (lambda (_frame class-value instance-value slot-name)
  (let (handler (class-handler class-value 'slot-unbound-handler))
    (if handler
      (handler class-value instance-value slot-name)
          (clos-unbound-slot-fail (.ref class-value 'identity)
                                  instance-value slot-name 'slot-value))))
    lambda-list: (clos-lambda-list 3 0 #f #f '() #f))))

;; | ClosInstance = POOObject
;; clos-slot-value
;;   : (-> ClosInstance Symbol SchemeValue)
;;   | contract: delegates missing and unbound reads to their class hooks.
;;   | doc m%
;;   | result: the bound value or the primary value returned by a hook.
(def (clos-slot-value instance-value slot-name)
  (unless (symbol? slot-name)
    (clos-fail 'invalid-slot-name slot: (failure-name slot-name)))
  (let* ((class-value (clos-class-of instance-value))
         (cell (instance-slot-cell instance-value slot-name)))
    (cond
     ((not cell)
      (call-slot-missing class-value instance-value slot-name 'slot-value '()))
     ((.ref cell 'bound?) (.ref cell 'value))
     (else (call-slot-unbound class-value instance-value slot-name)))))

;; : (-> ClosInstance Symbol SchemeValue SchemeValue)
(def (clos-set-slot-value! instance-value slot-name new-value)
  (unless (symbol? slot-name)
    (clos-fail 'invalid-slot-name slot: (failure-name slot-name)))
  (let* ((class-value (clos-class-of instance-value))
         (cell (instance-slot-cell instance-value slot-name)))
    (if cell
      (begin
        (.put! cell 'value new-value)
        (.put! cell 'bound? #t))
      (call-slot-missing class-value instance-value slot-name
                         'setf (list new-value)))
    new-value))

;; : (-> ClosInstance Symbol Boolean)
(def (clos-slot-bound? instance-value slot-name)
  (unless (symbol? slot-name)
    (clos-fail 'invalid-slot-name slot: (failure-name slot-name)))
  (let* ((class-value (clos-class-of instance-value))
         (cell (instance-slot-cell instance-value slot-name)))
    (if cell
      (if (.ref cell 'bound?) #t #f)
      (if (call-slot-missing class-value instance-value slot-name
                             'slot-boundp '()) #t #f))))

;; : (-> ClosInstance Symbol Boolean)
(def (clos-slot-exists? instance-value slot-name)
  (unless (symbol? slot-name)
    (clos-fail 'invalid-slot-name slot: (failure-name slot-name)))
  (if (clos-find-effective-slot
       (clos-class-of instance-value) slot-name) #t #f))

;; : (-> ClosInstance Symbol ClosInstance)
(def (clos-slot-makunbound! instance-value slot-name)
  (unless (symbol? slot-name)
    (clos-fail 'invalid-slot-name slot: (failure-name slot-name)))
  (let* ((class-value (clos-class-of instance-value))
         (cell (instance-slot-cell instance-value slot-name)))
    (if cell
      (begin
        (.put! cell 'bound? #f)
        (.put! cell 'value #f))
      (call-slot-missing class-value instance-value slot-name
                         'slot-makunbound '()))
    instance-value))

;; : (-> [SchemeValue] Boolean)
(def initialization-argument-list? clos-initarg-list?)

;; : (-> [SchemeValue] [SchemeValue])
(def initialization-argument-names clos-initarg-names)

;; One ordered index replaces a full initarg scan for every effective slot.
;; Each entry retains the leftmost position because CLOS initarg lookup does.
(def initialization-argument-index clos-initarg-index)

;; : (-> [SchemeValue] [SchemeValue] (values Boolean SchemeValue))
(def slot-initialization-argument clos-initarg-index-first-of)

(def (slot-initarg-index class-value)
  (let (index (make-hash-table-eq))
    (for-each
     (lambda (slot)
       (for-each (lambda (name) (hash-put! index name #t))
                 (.ref slot 'initargs)))
     (clos-class-effective-slots class-value))
    index))

;; The caller supplies exactly the methods of the lifecycle operations it will
;; invoke. The shared generic receives the same original keyword list.
(def (require-initialization-arguments class-value operation values methods)
  (unless (initialization-argument-list? values)
    (clos-fail 'malformed-initialization-arguments
               class: (.ref class-value 'identity) operation: operation))
  (unless (or (null? values) (clos-allow-other-keys? values))
    (let (index (slot-initarg-index class-value))
      (when (clos-first-invalid-initarg
             values index clos-allow-other-keys-name?)
        (let (signatures (filter-map (lambda (method) (.ref method 'lambda-list))
                                     (methods)))
          (unless (find (lambda (signature) (.ref signature 'allow-other-keys?))
                        signatures)
            (for-each
             (lambda (signature)
               (for-each (lambda (name) (hash-put! index name #t))
                         (.ref signature 'keys)))
             signatures)
            (let (invalid-name (clos-first-invalid-initarg
                                values index clos-allow-other-keys-name?))
              (when invalid-name
                (clos-fail 'invalid-initialization-argument
                           class: (.ref class-value 'identity)
                           slot: (failure-name invalid-name)
                           operation: operation)))))))))

;; : (-> ClosClass [SchemeValue] [SchemeValue])
(def (default-initialization-arguments class-value supplied-values)
  (let* ((supplied-names (initialization-argument-names supplied-values))
         (seen (make-hash-table-eq))
         (_seed-seen
          (for-each (lambda (name) (hash-put! seen name #t)) supplied-names))
         (defaults-rev
          (foldl
           (lambda (owner-class defaults-rev)
             (foldl
              (lambda (entry defaults-rev)
                (let (name (car entry))
                  (if (hash-key? seen name)
                    defaults-rev
                    (begin
                      (hash-put! seen name #t)
                      (cons ((cdr entry))
                            (cons name defaults-rev))))))
              defaults-rev
              (.ref owner-class 'default-initargs)))
           '()
           (clos-class-precedence-list class-value))))
    (append supplied-values (reverse defaults-rev))))

;; : (-> ClosInstance (U Boolean [Symbol]) [SchemeValue] ClosInstance)
(def (%clos-shared-initialize instance-value slot-names . initargs)
  (unless (or (eq? slot-names #t)
              (and (list? slot-names) (andmap symbol? slot-names)))
    (clos-fail 'invalid-shared-initialize-slot-names))
  (let* ((state (ensure-current-instance-state! instance-value))
         (class-value (.ref state 'class))
         (initarg-index (initialization-argument-index initargs))
         (slot-name-index
          (and (list? slot-names) (clos-identity-index slot-names))))
    (for-each
     (lambda (slot)
       (let-values (((supplied? supplied-value)
                     (slot-initialization-argument
                      initarg-index (.ref slot 'initargs))))
         (cond
          (supplied?
           (bind-effective-slot! state slot supplied-value))
          ((and (or (eq? slot-names #t)
                    (hash-key? slot-name-index (.ref slot 'identity)))
                (not (.ref (effective-slot-cell state slot) 'bound?))
                (.ref slot 'initfunction))
           (bind-effective-slot! state slot ((.ref slot 'initfunction)))))))
     (clos-class-effective-slots class-value))
    instance-value))

;; : (-> ClosInstance SchemeValue ... ClosInstance)
(def (%clos-initialize-instance instance-value . initargs)
  (apply clos-shared-initialize instance-value #t initargs))

;; : (-> ClosInstance SchemeValue ... ClosInstance)
(def (%clos-reinitialize-instance instance-value . initargs)
  (require-initialization-arguments
   (clos-class-of instance-value) 'reinitialize-instance initargs
   (lambda ()
     (append
      (apply clos-compute-applicable-methods
             clos-reinitialize-instance-generic instance-value initargs)
      (apply clos-compute-applicable-methods
             clos-shared-initialize-generic instance-value '() initargs))))
  (apply clos-shared-initialize instance-value '() initargs)
  instance-value)

;;; =change-class= preserves the original POO object identity.  A distinct
;;; snapshot object supplies the previous-class view expected by the hook.
;; : (-> ClosInstance ClosClass SchemeValue ... ClosInstance)
(def (%clos-change-class instance-value new-class-value . initargs)
  (let* ((state (ensure-current-instance-state! instance-value))
         (old-class (.ref state 'class))
         (new-class (clos-resolve-class new-class-value)))
    (let-values (((added _discarded)
                  (class-slot-difference old-class new-class)))
      (let* ((previous-state
              (instance-state-value old-class (.ref state 'generation)
                                    (snapshot-instance-storage state)))
             (previous-value
              (.o (:: @ (.ref old-class 'instance-prototype))
                  %clos-state: previous-state))
             (new-storage (migrated-instance-storage state new-class)))
        (require-initialization-arguments
         new-class 'change-class initargs
         (lambda ()
           (append
            (%prospective-instance-methods
             clos-update-instance-for-different-class-generic
             (list previous-value instance-value) 1 new-class)
            (%prospective-instance-methods
             clos-shared-initialize-generic
             (list instance-value added) 0 new-class))))
        (%publish-slot-edits!
         (list (list state
                     (cons 'class new-class)
                     (cons 'generation (.ref new-class 'generation))
                     (cons 'storage new-storage))))
        (apply clos-update-instance-for-different-class
               previous-value instance-value initargs)
        instance-value))))

;; | ClosClass = POOObject
;; clos-make-instance
;;   : (-> ClosClass SchemeValue ... ClosInstance)
;;   | contract: defaults and validates initargs before allocating an instance
;;     whose local slots begin unbound, then performs shared initialization.
;;   | doc m%
;;   | result: the initialized identity-bearing POO instance.
(def (%clos-make-instance class-value . supplied-initargs)
  (let (current-value (clos-resolve-class class-value))
    (unless (initialization-argument-list? supplied-initargs)
      (clos-fail 'malformed-initialization-arguments
                 class: (.ref current-value 'identity)))
    (let (initargs
          (default-initialization-arguments current-value supplied-initargs))
      (require-initialization-arguments
       current-value 'make-instance initargs
       (lambda ()
         (append
          (apply clos-compute-applicable-methods
                 clos-allocate-instance-generic current-value initargs)
          (%prospective-instance-methods
           clos-initialize-instance-generic '(#f) 0 current-value)
          (%prospective-instance-methods
           clos-shared-initialize-generic '(#f #t) 0 current-value))))
      (let (instance-value (apply clos-allocate-instance
                                  current-value initargs))
        (apply clos-initialize-instance instance-value initargs)
        instance-value))))

;; : (-> ClosClass Symbol Symbol ClosMethod)
(def (clos-slot-reader-method class-value slot-name method-identity)
  (unless (clos-find-effective-slot class-value slot-name)
    (clos-fail 'slot-missing class: (.ref class-value 'identity)
               slot: slot-name operation: 'reader-method))
  (clos-method
   method-identity (list (clos-class-specializer class-value))
   (lambda (_frame instance-value)
     (clos-slot-value instance-value slot-name))))

;; : (-> ClosClass Symbol Symbol ClosMethod)
(def (clos-slot-writer-method class-value slot-name method-identity)
  (unless (clos-find-effective-slot class-value slot-name)
    (clos-fail 'slot-missing class: (.ref class-value 'identity)
               slot: slot-name operation: 'writer-method))
  (clos-method
   method-identity
   (list (clos-any-specializer)
         (clos-class-specializer class-value))
   (lambda (_frame new-value instance-value)
     (clos-set-slot-value! instance-value slot-name new-value))))

;;; Standard lifecycle entry points are ordinary POO generic functions.
;;; The primary methods below own the default kernel behavior; callers may add
;;; class-specialized methods through the exported generic objects without
;;; installing raw class-owned procedure hooks.
;; : (-> Symbol Natural Boolean [ClosSpecializer] Procedure
;;        ClosGenericFunction)
(def (standard-lifecycle-generic identity-value required-value rest-value
                                 specializers body-value)
  (let ((generic-value
         (clos-generic-function identity-value required-value
                                    rest?: rest-value
                                    key?: rest-value
                                    allow-other-keys?: rest-value))
        (lambda-list-value
         (clos-lambda-list required-value 0 rest-value #f '() #f)))
    (clos-add-method
     generic-value
     (clos-method identity-value specializers body-value
                      lambda-list: lambda-list-value))
    generic-value))

(def class-metaobject-specializer
  (clos-prototype-specializer (.ref ClosClass 'proto)))
(def standard-instance-specializer
  (clos-class-specializer clos-standard-object-class))

(def clos-allocate-instance-generic
  (standard-lifecycle-generic
   'allocate-instance 1 #t (list class-metaobject-specializer)
   (lambda (_frame class-value . initargs)
     (apply %clos-allocate-instance class-value initargs))))

(def clos-shared-initialize-generic
  (standard-lifecycle-generic
   'shared-initialize 2 #t
   (list standard-instance-specializer (clos-any-specializer))
   (lambda (_frame instance-value slot-names . initargs)
     (apply %clos-shared-initialize instance-value slot-names initargs))))

(def clos-initialize-instance-generic
  (standard-lifecycle-generic
   'initialize-instance 1 #t (list standard-instance-specializer)
   (lambda (_frame instance-value . initargs)
     (apply %clos-initialize-instance instance-value initargs))))

(def clos-reinitialize-instance-generic
  (standard-lifecycle-generic
   'reinitialize-instance 1 #t (list standard-instance-specializer)
   (lambda (_frame instance-value . initargs)
     (apply %clos-reinitialize-instance instance-value initargs))))

(def clos-update-instance-for-redefined-class-generic
  (standard-lifecycle-generic
   'update-instance-for-redefined-class 4 #t
   (list standard-instance-specializer (clos-any-specializer)
         (clos-any-specializer) (clos-any-specializer))
   (lambda (_frame instance-value added discarded property-list . initargs)
     (apply %clos-update-instance-for-redefined-class
            instance-value added discarded property-list initargs))))

(def clos-update-instance-for-different-class-generic
  (standard-lifecycle-generic
   'update-instance-for-different-class 2 #t
   (list standard-instance-specializer standard-instance-specializer)
   (lambda (_frame previous-value instance-value . initargs)
     (apply %clos-update-instance-for-different-class
            previous-value instance-value initargs))))

(def clos-change-class-generic
  (standard-lifecycle-generic
   'change-class 2 #t
   (list standard-instance-specializer (clos-any-specializer))
   (lambda (_frame instance-value new-class-value . initargs)
     (apply %clos-change-class instance-value new-class-value initargs))))

(def clos-make-instance-generic
  (standard-lifecycle-generic
   'make-instance 1 #t (list (clos-any-specializer))
   (lambda (_frame class-value . initargs)
     (apply %clos-make-instance class-value initargs))))

(def (clos-allocate-instance . arguments)
  (apply clos-call clos-allocate-instance-generic arguments))
(def (clos-shared-initialize . arguments)
  (apply clos-call clos-shared-initialize-generic arguments))
(def (clos-initialize-instance . arguments)
  (apply clos-call clos-initialize-instance-generic arguments))
(def (clos-reinitialize-instance . arguments)
  (apply clos-call clos-reinitialize-instance-generic arguments))
(def (clos-update-instance-for-redefined-class . arguments)
  (apply clos-call
         clos-update-instance-for-redefined-class-generic arguments))
(def (clos-update-instance-for-different-class . arguments)
  (apply clos-call
         clos-update-instance-for-different-class-generic arguments))
(def (clos-change-class . arguments)
  (apply clos-call clos-change-class-generic arguments))
(def (clos-make-instance . arguments)
  (when (and (pair? arguments)
             (not (initialization-argument-list? (cdr arguments))))
    (clos-fail 'malformed-initialization-arguments operation: 'make-instance))
  (apply clos-call clos-make-instance-generic arguments))

(for-each clos-register-generic-function!
          (list clos-allocate-instance-generic
                clos-shared-initialize-generic
                clos-initialize-instance-generic
                clos-reinitialize-instance-generic
                clos-update-instance-for-redefined-class-generic
                clos-update-instance-for-different-class-generic
                clos-change-class-generic
                clos-make-instance-generic))
