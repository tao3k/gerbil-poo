;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import :clan/poo/mop
        (only-in :clan/poo/object .o .mix compute-precedence-list!)
        (only-in :clan/poo/benchmarks/closure-measure measure write-datum)
        (only-in :gerbil/runtime/c3 c4-linearize)
        :std/iter
        (only-in :std/list/list append-map length=?)
        (only-in :std/test test-suite test-case check-equal?))
(export mop-lifecycle-test)

(.defgeneric (prototype-width instance) slot: width)
(.defclass BenchmarkPane ()
  ((width (initarg width:) (initform 80))))

(def (write-benchmark name data)
  (def directory (path-expand "benchs" (getenv "GERBIL_PATH")))
  (create-directory* directory)
  (write-datum (path-expand name directory) data))

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
          (set! rows (cons (list shape size iteration (car work) repetitions clocks) rows)))))
    (reverse rows)))

(def mop-lifecycle-test
  (test-suite "MOP lifecycle cost"
    (test-case "measure C4 merges and POO precedence on deep chains and wide diamonds"
      (write-benchmark "mop-precedence.scm"
        (list '(benchmark mop-precedence-v1)
              (list 'gerbil (gerbil-version-string))
              '(units cpu-seconds wall-seconds gc-cpu-seconds collections allocated-bytes)
              (cons 'rows
                    (append-map
                     (lambda (fixture) (apply precedence-samples fixture))
                     '((deep 32) (deep 128) (diamond 8) (diamond 32) (diamond 128)))))))
    (test-case "record prototype and CLOS workloads with natural GC"
      (def prototype (.o width: 80))
      (def pane (poo-clos-make-instance BenchmarkPane))
      (def (make-pane) (poo-clos-make-instance BenchmarkPane width: 80))
      (def (refresh-pane) (poo-clos-reinitialize-instance pane width: 80))
      (def (pane-width value) (poo-clos-slot-value value 'width))
      (def (allocate-prototype) (.o (:: @ prototype)))
      (def calls
        (list
         (list 'prototype-slot 32768 (lambda () (prototype-width prototype)) values 80)
         (list 'prototype-construction 32768 allocate-prototype prototype-width 80)
         (list 'clos-slot 2048 (lambda () (pane-width pane)) values 80)
         (list 'clos-construction 128 make-pane pane-width 80)
         (list 'clos-reinitialization 128 refresh-pane pane-width 80)))
      (def shared poo-clos-shared-initialize-generic)
      (def count 0)
      (def extension
        (poo-clos-method
         'benchmark-pane-extension
         (list (poo-clos-class-specializer BenchmarkPane)
               (poo-clos-any-specializer))
         (lambda (_frame _pane _slots . _initargs) (set! count (+ count 1)))
         qualifier: 'after
         lambda-list: (poo-clos-lambda-list 2 0 #t #f '() #f)))
      (def rows [])
      (def (sample mode iteration workloads)
        (for (work (if (even? iteration) workloads (reverse workloads)))
          (let ((name (car work)) (repetitions (cadr work)) (call (caddr work))
                (verify (cadddr work)) (expected (car (cddddr work))))
            (let-values (((result metrics) (measure call repetitions)))
              (check-equal? (verify result) expected)
              (set! rows (cons (list mode iteration name repetitions metrics) rows))))))
      (def (sample-extended iteration)
        (dynamic-wind
          (lambda () (poo-clos-add-method shared extension))
          (lambda () (sample 'extended iteration (cdddr calls)))
          (lambda () (poo-clos-remove-method shared extension))))
      (for (iteration (in-range 8))
        (if (even? iteration)
          (begin (sample 'standard iteration calls) (sample-extended iteration))
          (begin (sample-extended iteration) (sample 'standard iteration calls))))
      (check-equal? count (* 8 2 128))
      (write-benchmark "mop-lifecycle.scm"
        (list '(benchmark mop-lifecycle-v1)
              (list 'gerbil (gerbil-version-string))
              '(units cpu-seconds wall-seconds gc-cpu-seconds collections allocated-bytes)
              (list 'extension-calls count)
              (cons 'rows (reverse rows)))))))
