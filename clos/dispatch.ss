;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Multi-argument applicability, specificity and standard method combination.

(import :clan/poo/object
        (only-in :clan/poo/mop/prototype element?)
        (only-in :clan/poo/slot-observation slot-read-receiver)
        (only-in :std/list/list filter filter-map find flatten1 length=?)
        (only-in :std/hash/misc hash-remove!)
        "types.ss" "objects.ss" "method-combination.ss"
        "funcs.ss"
        (only-in "lambda-list.ss" clos-rest-arguments)
        (only-in :clan/poo/read-projection owned-read-open! owned-read-method! owned-read-hook-owner!))

(export clos-compute-applicable-methods clos-call
        clos-compute-effective-method
        clos-no-applicable-method clos-no-next-method
        clos-no-applicable-method-generic
        clos-no-next-method-generic
        clos-effective-method-group clos-call-method
        clos-make-method
        clos-call-next-method clos-next-method?
        clos-funcall clos-setf)

(extern namespace: clan/poo/clos/objects
        %published-method-positions %method-position method-positions-size %frameless-method-body)
(extern namespace: clan/poo/clos/types %carrier-declarations-current? %stock-call-validator?)
(extern namespace: clan/poo/slot-observation
        slot-read-key slot-read-value %call-with-private-slot-read-prefix)
(extern namespace: clan/poo/object %ref-owned-list %prepared-vector-slot-ref
        object-construction-current? %call-with-fresh-slot-read-group)
(extern namespace: clan/poo/read-projection %owned-private-registration?)
(extern namespace: clan/poo/slot-layout %fresh-vector-seeds-available? %advance-fresh-vector-seeds!)
(extern namespace: clan/poo/slot-observation
        %with-slot-read-registration-interval %without-slot-read-registration-interval
        %revoke-slot-read-registration-interval!)

;;; Runtime memq preserves identity comparison; length difference yields its
;;; position in the finite C4 precedence list without a project-local walker.
;; : (forall (a) (-> a [a] (Maybe Natural)))
(def (identity-index target values)
  (let (tail (memq target values))
    (and tail (- (length values) (length tail)))))

;; The canonical C4 list is borrowed only for an immediate scalar query.
;; Cold arguments still go through the public preparation and hook boundary.
(def (prototype-precedence-position target argument)
  (identity-index target
    (or (object-%precedence-list argument)
        (compute-precedence-list! argument))))

;; : (-> SchemeValue Boolean)
(def (clos-instance-state-bearing? value)
  (and (object? value)
       (.slot? value '%clos-state)
       (element? ClosInstanceState (.ref value '%clos-state))))

;;; Logical class precedence follows the identity-preserved class generation;
;;; POO prototypes remain the sole source of its C4 order.
;; : (-> SchemeValue (Maybe ClosClass))
(def (argument-clos-class argument)
  (and (clos-instance-state-bearing? argument)
       (.ref (.ref argument '%clos-state) 'class)))

;; : (-> SchemeValue SchemeValue (Maybe Natural))
(def (class-target-distance target argument)
  (and (object? argument)
       (let* ((argument-class (argument-clos-class argument))
              (index
               (and argument-class
                    (clos-class-precedence-position
                     argument-class target))))
         (and index (+ index 1)))))

;; : (-> SchemeValue Natural)
(def (universal-specializer-distance argument)
  (+ 2 (if (object? argument)
         (let (argument-class (argument-clos-class argument))
           (length (if argument-class
                     (clos-class-precedence-list argument-class)
                     (or (object-%precedence-list argument)
                         (compute-precedence-list! argument)))))
         0)))

;;; Eql ranks before every class; a class rank is its runtime C4 distance; the
;;; universal specializer follows every applicable class.
;; : (-> ClosSpecializer SchemeValue (Maybe Natural))
(def (specializer-distance specializer argument)
  (case (.ref specializer 'kind)
    ((eql) (and (eqv? argument (.ref specializer 'target)) 0))
    ((class)
     (class-target-distance (.ref specializer 'target) argument))
    ((prototype)
     (and (object? argument)
          (let (index
                (prototype-precedence-position (.ref specializer 'target) argument))
            (and index (+ index 1)))))
    ((any) (universal-specializer-distance argument))
    (else #f)))

;; : (-> ClosMethod [SchemeValue] (Maybe (Vector Natural)))
(def (method-distances method arguments)
  (let (distances
        (map specializer-distance
             (%ref-owned-list method 'specializers)
             arguments))
    (and (andmap (lambda (distance) (if distance #t #f)) distances)
         (list->vector distances))))

;;; Ranked method entries keep distances in required-argument order; lookup is
;;; bounded by the generic's admitted arity.
;; : (-> (Vector Natural) Natural Natural)
(def (distance-at distances index)
  (vector-ref distances index))

;;; Argument precedence is a generic-owned permutation.  The first unequal
;;; distance is the complete lexicographic method-order decision.
;; : (-> (Vector Natural) (Vector Natural) [Natural] Boolean)
(def (distances-before? left right precedence-order)
  (let loop ((remaining precedence-order))
    (and (pair? remaining)
         (let ((left-distance (distance-at left (car remaining)))
               (right-distance (distance-at right (car remaining))))
           (cond
            ((< left-distance right-distance) #t)
            ((> left-distance right-distance) #f)
            (else (loop (cdr remaining))))))))

;;; Gerbil std owns the stable O(n log n) merge sort. Equal method distances
;;; retain source-generation order without the former insertion-sort O(n²).
;; : (forall (a) (-> [(Pair a (Vector Natural))] [Natural]
;;        [(Pair a (Vector Natural))]))
(def (sort-ranked ranked precedence-order)
  (list-sort
   (lambda (left right)
     (distances-before? (cdr left) (cdr right) precedence-order))
   ranked))

;;; Applicability is a pure projection from one immutable generic generation;
;;; no cache or registry can change the method set during this computation.
;; : (-> ClosGenericFunction [SchemeValue]
;;        [(Pair ClosMethod (Vector Natural))])
(def (applicable-ranked-methods generic arguments)
  (sort-ranked
   (filter-map
    (lambda (method)
      (let (distances (method-distances method arguments))
        (and distances (cons method distances))))
    (%ref-owned-list generic 'methods))
   (%ref-owned-list generic 'argument-precedence-order)))


;;; Arity admission precedes applicability and every method body, including an
;;; around method that would otherwise short circuit.
;; : (-> ClosGenericFunction [SchemeValue] Unit)
(def (arguments-valid! generic arguments)
  (let* ((count (length arguments))
         (required (.ref generic 'required))
         (lambda-list (.ref generic 'lambda-list))
         (optional (.ref lambda-list 'optional))
         (open-tail?
          (or (.ref lambda-list 'rest?) (.ref lambda-list 'key?))))
    (unless (and (>= count required)
                 (or open-tail? (<= count (+ required optional))))
      (clos-fail 'argument-count-mismatch
                 generic: (.ref generic 'identity)))))

;; : (-> ClosGenericFunction [(Pair ClosMethod (Vector Natural))]
;;        [SchemeValue] Unit)
(def (keyword-arguments-valid! generic ranked arguments)
  (let* ((lambda-list (.ref generic 'lambda-list))
         (method-lists
          (filter-map (lambda (entry) (.ref (car entry) 'lambda-list))
                      ranked)))
    (when (or (.ref lambda-list 'key?)
              (find (lambda (method-list) (.ref method-list 'key?))
                    method-lists))
      (let* ((start (+ (.ref lambda-list 'required)
                       (.ref lambda-list 'optional)))
             (tail (clos-rest-arguments arguments start)))
        (unless (clos-initarg-list? tail)
          (clos-fail 'malformed-keyword-arguments
                     generic: (.ref generic 'identity)))
        (let* ((valid-keys
                (append
                 (%ref-owned-list lambda-list 'keys)
                 (flatten1
                  (map (lambda (method-list) (%ref-owned-list method-list 'keys))
                       method-lists))))
               (allow-other?
                (or (.ref lambda-list 'allow-other-keys?)
                    (clos-allow-other-keys? tail)
                    (find (lambda (method-list)
                            (.ref method-list 'allow-other-keys?))
                          method-lists)))
               (valid-key-index (clos-identity-index valid-keys))
               (invalid-key
                (clos-first-invalid-initarg
                 tail valid-key-index clos-allow-other-keys-name?)))
          (when (and invalid-key (not allow-other?))
            (clos-fail 'invalid-keyword-argument
                       generic: (.ref generic 'identity))))))))

(def (ranked-method-lookup generic ranked)
  (def (find-ranked method)
    (find (lambda (entry) (eq? (car entry) method)) ranked))
  (def count (length ranked))
  (def positions (and (>= count 4) (%published-method-positions generic)))
  (def (hash-lookup)
    (let (index (clos-leftmost-index-by car ranked))
      (lambda (method) (hash-get index method))))
  (cond
   ((< count 4) find-ranked)
   ((not positions) (hash-lookup))
   (else
    (def size (method-positions-size positions))
    ;; A dense projection uses positions from publication, without rebuilding
    ;; the method hash. Keep ranks private to this call and in specificity order.
    (if (> size (* 2 count)) (hash-lookup)
      (let (rows (make-vector size #f))
        (if (andmap
              (lambda (entry)
                (let (position (%method-position positions (car entry)))
                  (and position
                       (begin
                         (unless (vector-ref rows position)
                           (vector-set! rows position entry))
                         #t))))
              ranked)
          (lambda (method)
            (let* ((position (%method-position positions method))
                   (entry (and position (vector-ref rows position))))
              (and entry
                   (if (eq? (car entry) method) entry (find-ranked method)))))
          (hash-lookup)))))))

;;; Protocol customization may filter or reorder the default applicable set,
;;; but cannot inject a method outside the generic generation or one that is
;;; inapplicable to the current required arguments.
;; : (-> ClosGenericFunction [SchemeValue]
;;        [(Pair ClosMethod [Natural])])
(def (protocol-ranked-methods generic arguments)
  (let* ((ranked (applicable-ranked-methods generic arguments))
         (protocol (.ref generic 'protocol))
         (hook (.ref protocol 'compute-applicable-methods)))
    (owned-read-hook-owner! protocol)
    (if (not hook)
      ranked
      (let* ((methods (begin (owned-read-open!) (hook generic arguments (map car ranked))))
             (lookup-ranked (ranked-method-lookup generic ranked)))
        (unless (and (list? methods)
                     (andmap
                      (lambda (method)
                        (and (element? ClosMethod method)
                             (lookup-ranked method)))
                      methods))
          (clos-fail 'invalid-compute-applicable-methods-result
                     generic: (.ref generic 'identity)))
        (map lookup-ranked methods)))))

;;; Prepare one private admission continuation for standard/short/long carriers.
;;; A short combination uses the primary field for methods bearing its name.
;; : (-> ClosGenericFunction [SchemeValue]
;;        [(Pair ClosMethod [Natural])] (-> ClosEffectiveMethod))
(def (prepare-default-effective-method generic arguments ranked)
  (let (combination (.ref generic 'method-combination))
    (case (.ref combination 'kind)
      ((standard)
       (%prepare-effective-method
        generic arguments
        (clos-methods-with-qualifier ranked 'around)
        (clos-methods-with-qualifier ranked 'before)
        (clos-methods-with-qualifier ranked 'primary)
        (clos-methods-with-qualifier ranked 'after)))
      ((short)
       (owned-read-open!)
       (%prepare-effective-method
        generic arguments
        (clos-methods-with-qualifier ranked 'around)
        '()
        (clos-methods-with-qualifier ranked
          (clos-short-qualifier (.ref combination 'identity)))
        '()))
      ((long)
       (owned-read-open!)
       (let ((builder (.ref combination 'effective-builder))
             (groups (clos-partition-long-methods generic ranked)))
         (unless builder
           (clos-fail 'missing-effective-method-builder
                      generic: (.ref generic 'identity)))
         (let (executor (builder generic arguments groups))
           (unless (procedure? executor)
             (clos-fail 'invalid-effective-method-result
                        generic: (.ref generic 'identity)))
           (%prepare-effective-method generic arguments '() '() '() '()
                                groups: groups executor: executor))))
      (else
       (clos-fail 'unsupported-method-combination
                  generic: (.ref generic 'identity))))))

;;; One effective method captures both arguments and the immutable generic
;;; generation used to rank all qualifier groups.  The protocol hook receives
;;; the checked default effective method rather than a raw evaluator continuation.
;; : (-> ClosGenericFunction [SchemeValue] (Maybe ClosEffectiveMethod))
(def (select-effective-method generic arguments (roots #f))
  (arguments-valid! generic arguments)
  (let (ranked (protocol-ranked-methods generic arguments))
    (if (null? ranked)
      ;; ANSI ordering invokes no-applicable-method before keyword rejection.
      #f
      (begin
        (keyword-arguments-valid! generic ranked arguments)
        (let* ((admit-default (prepare-default-effective-method generic arguments ranked))
               (protocol (.ref generic 'protocol))
               (hook (.ref protocol 'compute-effective-method))
               (direct (begin
                         (owned-read-hook-owner! protocol)
                         (and (not hook) roots
                              (prepare-direct-primary generic arguments ranked roots))))
               (effective-method
                (cond
                  (direct direct)
                  (hook
                   (begin (owned-read-open!)
                     ;; An open hook receives a checked default and its return
                     ;; is checked again below, even if it returns that object.
                     (hook generic arguments (map car ranked)
                       (admit-default))))
                  ;; All protocol lookup has completed. There is no public
                  ;; callback between this check and the identity assertion.
                  (else (admit-default)))))
          (def effective-arguments
            (and hook (element? ClosEffectiveMethod effective-method)
                 (.ref effective-method 'arguments)))
          (unless (or direct
                      (and (or (not hook)
                               (and effective-arguments
                                    (or (eq? effective-arguments arguments)
                                        (and (length=? effective-arguments arguments)
                                             (andmap eqv? effective-arguments arguments)))
                                    (not (effective-method-empty? effective-method))))
                           (eq? (.ref effective-method 'generic) generic)))
            (clos-fail 'invalid-effective-method-result
                       generic: (.ref generic 'identity)))
          effective-method)))))

;; The initial Generic admission actually ran every nested method, lambda
;; list and specializer validator. Accept its native signed graph once after
;; ranking. Live external list spines or a custom validator keep the
;; ordinary path. The selected body and the two native preparations cannot
;; run author code until this interval ends.
(def (current-direct-group? roots)
  (with-catch (lambda (_) #f)
    (lambda ()
      (%call-with-fresh-slot-read-group roots
        (lambda (read)
          (let ((key (slot-read-key read)) (value (slot-read-value read)))
            (cond
             ((eq? key '.element?)
              (%stock-call-validator? (slot-read-receiver read) value))
             ((equal? key '(bootstrap .element?)) #f)
             ((symbol? key) (not (pair? value)))
             (else #t))))
        ;; Captured roots are unique. Reserve space for them and leave room
        ;; for receiver-route entries and dependencies discovered by the sweep.
        (* 2 (length roots))))))

(def (prepare-direct-primary generic arguments ranked roots)
  (and (%owned-private-registration?) (null? (cdr ranked))
       (object-construction-current?) (%carrier-declarations-current?)
       (%fresh-vector-seeds-available?)
       (let* ((method (caar ranked))
              (combination (%prepared-vector-slot-ref generic 'method-combination))
              (body (%prepared-vector-slot-ref method 'body)))
         (and (object? combination)
              (eq? (%prepared-vector-slot-ref combination 'kind) 'standard)
              (eq? (%prepared-vector-slot-ref method 'qualifier) 'primary)
              (let (entry (%frameless-method-body method body))
                (and entry (current-direct-group? roots)
                     (lambda ()
                       (%advance-fresh-vector-seeds!) ; EffectiveMethod preparation
                       (owned-read-method! body method)
                       (%advance-fresh-vector-seeds!) ; InvocationFrame preparation
                       (apply entry arguments))))))))

;; Reflection represents an empty applicable set as an empty effective method.
(def (compute-effective-method generic arguments)
  (or (select-effective-method generic arguments)
      (make-effective-method generic arguments '() '() '() '())))

;;; Public reflection returns the shared specificity order before qualifier
;;; grouping; qualifiers do not create a second precedence system.
;; : (-> ClosGenericFunction SchemeValue... [ClosMethod])
(def (clos-compute-applicable-methods generic-source . arguments)
  (let (generic-value (require-clos-generic generic-source))
    (arguments-valid! generic-value arguments)
    (map car (protocol-ranked-methods generic-value arguments))))

;; Allocation and change-class validate before publishing an instance with
;; the target class. A fresh instance cannot satisfy an eql specializer.
;; A changing instance keeps both its eql identity and its POO prototype.
(def (%prospective-instance-methods generic arguments position class-value)
  (let ((prototype (.ref class-value 'instance-prototype))
        (instance (list-ref arguments position)))
    (def (distance index specializer argument)
      (if (= index position)
        (case (.ref specializer 'kind)
          ((class)
           (let (rank (clos-class-precedence-position
                       class-value (.ref specializer 'target)))
             (and rank (+ rank 1))))
          ((any) (+ 2 (length (clos-class-precedence-list class-value))))
          ((prototype)
           (if instance
             (specializer-distance specializer instance)
             (let (rank (prototype-precedence-position
                         (.ref specializer 'target) prototype))
               (and rank (+ rank 2)))))
          (else (and instance (specializer-distance specializer instance))))
        (specializer-distance specializer argument)))
    (filter
     (lambda (method)
       (let (index -1)
         (andmap (lambda (specializer argument)
                   (set! index (+ index 1))
                   (distance index specializer argument))
                 (%ref-owned-list method 'specializers) arguments)))
     (%ref-owned-list generic 'methods))))

;; : (-> ClosGenericFunction SchemeValue... ClosEffectiveMethod)
(def (clos-compute-effective-method generic-source . arguments)
  (let (generic-value (require-clos-generic generic-source))
    (compute-effective-method generic-value arguments)))

;;; An empty applicable set invokes the terminal generic with the original call.
;; : (-> ClosGenericFunction [SchemeValue] SchemeValue)
(def (clos-no-applicable-method generic arguments)
  (owned-read-open!)
  (apply clos-call clos-no-applicable-method-generic
         (cons generic arguments)))

;; : (-> ClosGenericFunction ClosMethod [SchemeValue] SchemeValue)
(def (clos-no-next-method generic method arguments)
  (owned-read-open!)
  (apply clos-call clos-no-next-method-generic
         (cons generic (cons method arguments))))

;; : ClosGenericFunction
(def clos-no-applicable-method-generic
  (clos-add-method
   (clos-generic-function 'no-applicable-method 1 rest?: #t)
   (clos-method
    'no-applicable-method/default
    (list (clos-any-specializer))
    (lambda (_frame generic . arguments)
      (let (hook (.ref (.ref generic 'protocol) 'no-applicable-method))
        (if hook
          (hook generic arguments)
          (clos-fail 'no-applicable-method
                     generic: (.ref generic 'identity)))))
    lambda-list: (clos-lambda-list 1 0 #t #f '() #f))))

;; : ClosGenericFunction
(def clos-no-next-method-generic
  (clos-add-method
   (clos-generic-function 'no-next-method 2 rest?: #t)
   (clos-method
    'no-next-method/default
    (list (clos-any-specializer) (clos-any-specializer))
    (lambda (_frame generic method . arguments)
      (let (hook (.ref (.ref generic 'protocol) 'no-next-method))
        (if hook
          (hook generic method arguments)
          (clos-fail 'no-next-method
                     generic: (.ref generic 'identity)
                     qualifier: (.ref method 'qualifier)
                     method: (.ref method 'identity)))))
    lambda-list: (clos-lambda-list 2 0 #t #f '() #f))))

;; Methods with agreeing specializers can trade places within their run.
;; Every method identity and every other ordering decision must agree.
(def (same-applicable-methods? left right)
  (let compare ((left left) (right right))
    (cond
     ((null? left) (null? right))
     ((null? right) #f)
     ((eq? (caar left) (caar right)) (compare (cdr left) (cdr right)))
     (else
      (def signature (%ref-owned-list (caar left) 'specializers))
      (def (agrees? entry)
        (same-specializers? signature (%ref-owned-list (car entry) 'specializers)))
      (and (agrees? (car right))
           (let (counts (make-hash-table-eq))
             (def left-tail
               (let collect ((remaining left))
                 (if (and (pair? remaining) (agrees? (car remaining)))
                   (begin
                     (hash-update! counts (caar remaining) 1+ 0)
                     (collect (cdr remaining)))
                   remaining)))
             (let consume ((remaining right))
               (if (and (pair? remaining) (agrees? (car remaining)))
                 (let* ((method (caar remaining)) (count (hash-get counts method)))
                   (and count
                        (begin
                          (if (= count 1) (hash-remove! counts method)
                              (hash-put! counts method (1- count)))
                          (consume (cdr remaining)))))
                 (and (zero? (hash-length counts)) (compare left-tail remaining))))))))))

;;; Frame admission prevents arbitrary lookalike POO objects from exercising a
;;; captured next-method continuation.
;; : (forall (a) (-> a ClosInvocationFrame))
(def (require-frame frame)
  (checked ClosInvocationFrame frame 'invalid-invocation-frame))

;;; Invocation failures retain method and qualifier identity while omitting raw
;;; arguments from the raised POO value.
;; : (-> ClosInvocationFrame Symbol Bottom)
(def (frame-fail frame code)
  (clos-fail
   code
   generic: (.ref (.ref (.ref frame 'effective-method) 'generic) 'identity)
   qualifier: (.ref frame 'qualifier)
   method: (.ref (.ref frame 'method) 'identity)))

;;; Auxiliary frames never report a next method even if another auxiliary
;;; method follows in specificity order.
;; : (-> ClosInvocationFrame Boolean)
(def (clos-next-method? frame)
  (require-frame frame)
  (and (if (memq (.ref frame 'qualifier) '(around primary long)) #t #f)
       (if (.ref frame 'next) #t #f)))

;;; Replacement arguments must preserve the complete ordered applicable method
;;; set before the captured continuation can be invoked.
;; : (-> ClosInvocationFrame SchemeValue... SchemeValue)
(def (clos-call-next-method frame . replacement)
  (if (null? replacement)
    (call-next-method frame replacement)
    (begin
      (%revoke-slot-read-registration-interval!)
      (%without-slot-read-registration-interval
        (lambda () (call-next-method frame replacement))))))

(def (call-next-method frame replacement)
  (require-frame frame)
  (unless (memq (.ref frame 'qualifier) '(around primary long))
    (frame-fail frame 'next-forbidden-in-auxiliary))
  (let* ((effective-method (.ref frame 'effective-method))
         (generic (.ref effective-method 'generic))
         (arguments (if (null? replacement)
                      (.ref frame 'arguments)
                      replacement)))
    (arguments-valid! generic arguments)
    (unless (null? replacement)
      (let* ((revision (object-revision generic))
             (original (protocol-ranked-methods generic (.ref effective-method 'arguments)))
             (ranked (protocol-ranked-methods generic arguments)))
        (when (pair? ranked) (keyword-arguments-valid! generic ranked arguments))
        (unless (and (same-applicable-methods? original ranked)
                     (= revision (object-revision generic)))
          (frame-fail frame 'changed-applicable-methods))))
    (if (.ref frame 'next)
      ((.ref frame 'next) arguments)
      (clos-no-next-method generic (.ref frame 'method) arguments))))

;;; Long-form bodies receive named immutable method lists through the effective method,
;;; never through a mutable global method-group registry.
;; : (-> ClosEffectiveMethod Symbol [ClosMethod])
(def (clos-effective-method-group effective-method name)
  (unless (element? ClosEffectiveMethod effective-method)
    (clos-fail 'invalid-effective-method))
  (let (entry (assq name (.ref effective-method 'groups)))
    (if entry (cdr entry)
        (clos-fail 'unknown-effective-method-group))))

;; : (-> Thunk ClosMethod)
(def (clos-make-method thunk)
  (make-synthetic-effective-method thunk))

;; : (-> ClosEffectiveMethod ClosMethod Boolean)
(def (effective-method-member? effective-method method)
  (or (.ref method 'synthetic-effective-method?)
      (find (lambda (entry) (memq method (cdr entry)))
            (.ref effective-method 'groups))
      (find (lambda (qualifier)
              (memq method (.ref effective-method qualifier)))
            '(around before primary after))))

;;; =call-method= semantics invoke one explicit method and provide only the
;;; declared next-method list as its continuation chain.
;; : (-> ClosEffectiveMethod ClosMethod [ClosMethod] SchemeValue)
(def (clos-call-method effective-method method next-methods)
  (unless (element? ClosEffectiveMethod effective-method)
    (clos-fail 'invalid-call-method operation: 'invalid-effective-method))
  (unless (element? ClosMethod method)
    (clos-fail 'invalid-call-method operation: 'invalid-method))
  (unless (list? next-methods)
    (clos-fail 'invalid-call-method operation: 'invalid-next-method-list))
  (unless (effective-method-member? effective-method method)
    (clos-fail 'invalid-call-method operation: 'method-not-applicable))
  (for-each
   (lambda (next)
     (unless (element? ClosMethod next)
       (clos-fail 'invalid-next-method operation: 'call-method))
     (unless (effective-method-member? effective-method next)
       (clos-fail 'next-method-not-applicable operation: 'call-method)))
   next-methods)
  (def (run current remaining arguments)
    (invoke current effective-method arguments
            (and (pair? remaining)
                 (lambda (replacement)
                   (run (car remaining) (cdr remaining) replacement)))
            'long))
  (run method next-methods (.ref effective-method 'arguments)))

;;; Invocation allocates one POO lexical frame and calls the already admitted
;;; method procedure; it does not repeat method selection.
;; : (-> ClosMethod ClosEffectiveMethod [SchemeValue] (Maybe Procedure)
;;        MethodQualifier SchemeValue)
(def (invoke method effective-method arguments next qualifier)
  (def body (.ref method 'body))
  (owned-read-method! body method)
  (apply body
         (make-invocation-frame effective-method arguments next qualifier method)
         arguments))

;;; Auxiliary return values are discarded without collapsing or inspecting the
;;; number of Scheme values produced.
;; : (forall (a) (-> (-> a) Unit))
(def (ignore-values thunk)
  (call-with-values thunk (lambda _ (void))))

;;; Short combinations consume one primary value per method, matching Common
;;; Lisp value-context behavior; zero values adapt to Scheme =#f=.
;; : (-> Thunk SchemeValue)
(def (primary-value thunk)
  (call-with-values thunk
    (lambda results (if (pair? results) (car results) #f))))

;; : (-> ClosMethod ClosEffectiveMethod [SchemeValue] SchemeValue)
(def (invoke-short method effective-method arguments)
  (primary-value
   (lambda ()
     (invoke method effective-method arguments #f (.ref method 'qualifier)))))

;; : (-> ClosEffectiveMethod SchemeValue)
(def (execute-short-effective-method effective-method)
  (let* ((generic (.ref effective-method 'generic))
         (arguments (.ref effective-method 'arguments))
         (combination (.ref generic 'method-combination))
         (ordered (if (eq? (.ref combination 'order) 'most-specific-last)
                    (reverse (.ref effective-method 'primary))
                    (.ref effective-method 'primary))))
    (when (null? ordered)
      (clos-fail 'no-primary-method generic: (.ref generic 'identity)))
    (def (run-core args)
      (if (and (.ref combination 'identity-with-one-argument?)
               (null? (cdr ordered)))
        (invoke (car ordered) effective-method args #f
                (.ref (car ordered) 'qualifier))
        (clos-execute-short-operator
         (.ref combination 'operator) ordered
         (lambda (method) (invoke-short method effective-method args)))))
    (def (run-around methods args)
      (if (null? methods)
        (run-core args)
        (invoke (car methods) effective-method args
                (lambda (new-arguments)
                  (run-around (cdr methods) new-arguments))
                'around)))
    (run-around (.ref effective-method 'around) arguments)))

;;; The specialized execution branch preserves Scheme multiple values.  Before
;;; is most-specific-first; after is reversed only after effective-method construction.
;; : (-> ClosEffectiveMethod SchemeValue)
(def (execute-standard-effective-method effective-method)
  (let ((arguments (.ref effective-method 'arguments))
        (around (.ref effective-method 'around))
        (before (.ref effective-method 'before))
        (primary (.ref effective-method 'primary))
        (after (reverse (.ref effective-method 'after)))
        (generic (.ref effective-method 'generic)))
    (when (null? primary)
      (clos-fail 'no-primary-method generic: (.ref generic 'identity)))
    (def (run-primary methods args)
      (invoke (car methods) effective-method args
              (and (pair? (cdr methods))
                   (lambda (new-arguments)
                     (run-primary (cdr methods) new-arguments)))
              'primary))
    (def (run-auxiliary methods args qualifier)
      (for-each
       (lambda (method)
         (ignore-values
          (lambda () (invoke method effective-method args #f qualifier))))
       methods))
    (def (run-core args)
      (if (and (null? before) (null? after))
        ;; The same invocation and frame guards run. With no auxiliary
        ;; methods, the caller can receive all Scheme values directly.
        (run-primary primary args)
        (begin
          (run-auxiliary before args 'before)
          (call-with-values
           (lambda () (run-primary primary args))
           (lambda results
             (run-auxiliary after args 'after)
             (apply values results))))))
    (def (run-around methods args)
      (if (null? methods)
        (run-core args)
        (invoke (car methods) effective-method args
                (lambda (new-arguments)
                  (run-around (cdr methods) new-arguments))
                'around)))
    (run-around around arguments)))

;;; The public call captures exactly one effective method from the supplied
;;; immutable generic generation.
;; : (-> ClosEffectiveMethod Boolean)
(def (effective-method-empty? effective-method)
  (and (not (.ref effective-method 'executor))
       (null? (.ref effective-method 'around))
       (null? (.ref effective-method 'before))
       (null? (.ref effective-method 'primary))
       (null? (.ref effective-method 'after))))

;; : (-> ClosGenericFunction SchemeValue... SchemeValue)
(def (clos-call generic-source . arguments)
  (%with-slot-read-registration-interval
    (lambda () (call-generic generic-source arguments))))

(def (call-generic generic-source arguments)
  (defvalues (generic-value roots)
    (if (%owned-private-registration?)
      (let-values (((generic-value reads)
                    (%call-with-private-slot-read-prefix
                      (lambda ()
                        ;; This is the first admission. Collect its original
                        ;; signed reads for the group instead of probing the
                        ;; repeated-field route before the group exists.
                        (%without-slot-read-registration-interval
                          (lambda () (require-clos-generic generic-source)))))))
        (values generic-value (and (eq? generic-value generic-source) reads)))
      (values (require-clos-generic generic-source) #f)))
  (let ()
    (owned-read-hook-owner! generic-value)
    (let (effective-method (select-effective-method generic-value arguments roots))
      (if (not effective-method)
        (clos-no-applicable-method generic-value arguments)
        (if (procedure? effective-method) (effective-method)
          (if (.ref effective-method 'executor)
            ((.ref effective-method 'executor) effective-method)
            (case (.ref (.ref generic-value 'method-combination) 'kind)
              ((short) (execute-short-effective-method effective-method))
              (else (execute-standard-effective-method effective-method)))))))))

;; : (-> FunctionName SchemeValue ... SchemeValue)
(def (clos-funcall function-name . arguments)
  (apply clos-call
         (clos-find-generic-function function-name) arguments))

;; : (-> Symbol SchemeValue SchemeValue ... SchemeValue)
(def (clos-setf accessor-name new-value . arguments)
  (apply clos-funcall
         (cons (list 'setf accessor-name) (cons new-value arguments))))
