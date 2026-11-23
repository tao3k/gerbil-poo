;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import :clan/poo/mop
        (only-in :clan/poo/object .o .mix compute-precedence-list!)
        (only-in :clan/poo/mop/clos/objects require-clos-generic make-invocation-frame)
        (only-in :clan/poo/benchmarks/closure-measure measure qualified-metrics write-datum)
        (only-in :gerbil/runtime/c3 c4-linearize)
        :std/iter
        (only-in :std/list/list append-map length=?)
        (only-in :std/test test-suite test-case check-equal?))
(export mop-lifecycle-test)

(extern namespace: clan/poo/mop/clos/dispatch
        protocol-ranked-methods keyword-arguments-valid!
        prepare-default-effective-method execute-standard-effective-method)
(extern namespace: clan/poo/mop/clos/lifecycle
        require-initialization-arguments %clos-reinitialize-instance %clos-shared-initialize)

(.defgeneric (prototype-width instance) slot: width)
(.defclass BenchmarkPane ()
  ((width (initarg width:) (initform 80))))

(def (write-benchmark name rows . details)
  (def directory (path-expand "benchs" (getenv "GERBIL_PATH")))
  (create-directory* directory)
  (write-datum
   (path-expand (string-append (symbol->string name) ".scm") directory)
   [(list 'benchmark name)
    '(metrics cpu-seconds wall-seconds gc-cpu-seconds collections admitted-allocated-bytes)
    '(row-tail raw-allocation-delta)
    details ...
    (cons 'rows rows)]))

(def (precedence-parents shape size)
  (def root (.o width: 80))
  (case shape
    ((deep)
     (list (let loop ((remaining size) (parent root))
             (if (zero? remaining) parent
               (loop (- remaining 1) (.mix parent))))))
    ((diamond)
     (for/collect (_ (in-range size)) (.mix root)))))

(def (precedence-samples shape size)
  (def parents (precedence-parents shape size))
  (def orders (make-hash-table-eq))
  (for-each (lambda (parent)
              (hash-put! orders parent (compute-precedence-list! parent)))
            parents)
  (def hot (apply .mix parents))
  (def expected (cdr (compute-precedence-list! hot)))
  (def (merge)
    (let-values (((order _)
                  (c4-linearize [] parents get-precedence-list:
                    (lambda (parent) (hash-ref orders parent)))))
      order))
  (def (cook) (cdr (compute-precedence-list! (apply .mix parents))))
  (def (cached) (cdr (compute-precedence-list! hot)))
  (def workloads
    (list (cons 'gerbil-c4 merge) (cons 'poo-first-precedence cook)
          (cons 'poo-cached-precedence cached)))
  (let ((rows []) (repetitions 128))
    (for (iteration (in-range 8))
      (for (work (if (even? iteration) workloads (reverse workloads)))
        (let-values (((result clocks) (measure (cdr work) repetitions)))
          (check-equal? (and (length=? result expected) (andmap eq? result expected)) #t)
          (set! rows (cons (list shape size iteration (car work) repetitions
                                 (qualified-metrics clocks) (vector-ref clocks 4))
                           rows)))))
    (reverse rows)))

(def (reconfiguration-samples)
  (def pane (clos-make-instance BenchmarkPane))
  (def initargs [width: 80])
  (def args (cons* pane '() initargs))
  (def generic clos-shared-initialize-generic)
  (def ranked (protocol-ranked-methods generic args))
  (def effective ((prepare-default-effective-method generic args ranked)))
  (def (lifecycle-keywords)
    (require-initialization-arguments
     (clos-class-of pane) 'reinitialize-instance initargs
     (lambda () (error "unexpected method-level keyword admission"))))
  ;; Each sample times one phase in isolation. The rows overlap and do not
  ;; form a sum for the whole call.
  (def phases
    (list
     (cons 'reinitialize (lambda () (apply clos-reinitialize-instance pane initargs)))
     (cons 'reinitialize-primary (lambda () (apply %clos-reinitialize-instance pane initargs)))
     (cons 'lifecycle-keywords lifecycle-keywords)
     (cons 'shared-initialize (lambda () (apply clos-shared-initialize args)))
     (cons 'shared-generic (lambda () (require-clos-generic generic)))
     (cons 'shared-applicability (lambda () (protocol-ranked-methods generic args)))
     (cons 'shared-keywords (lambda () (keyword-arguments-valid! generic ranked args)))
     (cons 'shared-effective-method
           (lambda () ((prepare-default-effective-method generic args ranked))))
     (cons 'shared-frame
           (lambda () (make-invocation-frame effective args #f 'primary (caar ranked))))
     (cons 'shared-combination-and-write (lambda () (execute-standard-effective-method effective)))
     (cons 'shared-slot-write (lambda () (apply %clos-shared-initialize args)))))
  (let ((rows []) (repetitions 128))
    (for (pass (in-range 8))
      (for (phase (if (even? pass) phases (reverse phases)))
        (let-values (((result clocks) (measure (cdr phase) repetitions)))
          (when (eq? (car phase) 'reinitialize) (check-equal? (eq? result pane) #t))
          (set! rows (cons (list pass (car phase) repetitions
                                 (qualified-metrics clocks) (vector-ref clocks 4))
                           rows)))))
    (check-equal? (clos-slot-value pane 'width) 80)
    (reverse rows)))

(def mop-lifecycle-test
  (test-suite "MOP lifecycle cost"
    (test-case "measure C4 merges and POO precedence on deep chains and wide diamonds"
      (write-benchmark 'mop-precedence
        (append-map
         (lambda (fixture) (apply precedence-samples fixture))
         '((deep 32) (deep 128) (diamond 8) (diamond 32) (diamond 128)))))
    (test-case "measure reconfiguration admission, dispatch, and method combination"
      (write-benchmark 'mop-reconfiguration-phases (reconfiguration-samples)))
    (test-case "record prototype and CLOS workloads with natural GC"
      (def prototype (.o width: 80))
      (def pane (clos-make-instance BenchmarkPane))
      (def (make-pane) (clos-make-instance BenchmarkPane width: 80))
      (def (refresh-pane) (clos-reinitialize-instance pane width: 80))
      (def (pane-width value) (clos-slot-value value 'width))
      (def (allocate-prototype) (.o (:: @ prototype)))
      (def calls
        (list
         (list 'prototype-slot 32768 (lambda () (prototype-width prototype)) values 80)
         (list 'prototype-construction 32768 allocate-prototype prototype-width 80)
         (list 'clos-slot 2048 (lambda () (pane-width pane)) values 80)
         (list 'clos-construction 128 make-pane pane-width 80)
         (list 'clos-reinitialization 128 refresh-pane pane-width 80)))
      (def shared clos-shared-initialize-generic)
      (def count 0)
      (def extension
        (clos-method
         'benchmark-pane-extension
         (list (clos-class-specializer BenchmarkPane)
               (clos-any-specializer))
         (lambda (_frame _pane _slots . _initargs) (set! count (+ count 1)))
         qualifier: 'after
         lambda-list: (clos-lambda-list 2 0 #t #f '() #f)))
      (def rows [])
      (def (sample mode iteration workloads)
        (for (work (if (even? iteration) workloads (reverse workloads)))
          (let ((name (car work)) (repetitions (cadr work)) (call (caddr work))
                (verify (cadddr work)) (expected (car (cddddr work))))
            (let-values (((result metrics) (measure call repetitions)))
              (check-equal? (verify result) expected)
              (set! rows (cons (list mode iteration name repetitions
                                     (qualified-metrics metrics) (vector-ref metrics 4))
                               rows))))))
      (def (sample-extended iteration)
        (dynamic-wind
          (lambda () (clos-add-method shared extension))
          (lambda () (sample 'extended iteration (cdddr calls)))
          (lambda () (clos-remove-method shared extension))))
      (for (iteration (in-range 8))
        (if (even? iteration)
          (begin (sample 'standard iteration calls) (sample-extended iteration))
          (begin (sample-extended iteration) (sample 'standard iteration calls))))
      (check-equal? count (* 8 2 128))
      (write-benchmark 'mop-lifecycle (reverse rows) (list 'extension-calls count)))))
