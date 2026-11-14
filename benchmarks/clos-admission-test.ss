;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import :std/iter :std/test :clan/poo/clos
        (only-in :clan/poo/object .ref)
        (only-in :clan/poo/clos/lambda-list poo-clos-key-argument)
        (only-in :clan/poo/benchmarks/closure-measure measure median qualified-metrics))
(export clos-admission-test)

(.defgeneric positional (object))
(.defmethod (positional object) object)

(.defgeneric keyword-call (object &key ((color: color))))
(.defmethod (keyword-call object &key ((color: color) object color?))
  (cons color? color))

;; Use the former two lookups with the same dispatch and lambda-list shape.
(def keyword-reference
  (poo-clos-generic-function 'keyword-call 1 key?: #t keys: '(color:)))
(poo-clos-add-method keyword-reference
  (poo-clos-method
   'keyword-call (list (poo-clos-any-specializer))
   (lambda (_frame . arguments)
     (let* ((object (list-ref arguments 0))
            (color (let (entry (poo-clos-key-argument arguments 1 'color:))
                     (if (car entry) (cdr entry) object)))
            (color? (car (poo-clos-key-argument arguments 1 'color:))))
       (cons color? color)))
   lambda-list: (poo-clos-lambda-list 1 0 #f #t '(color:) #f)))

(def (report label rows)
  (displayln
   (list 'CLOS-BENCHMARK label
         'cpu-ms (* 1000 (median (map (lambda (row) (vector-ref row 0)) rows)))
         'gc-ms (* 1000 (median (map (lambda (row) (vector-ref row 2)) rows)))
         'bytes (let (bytes (filter number? (map (lambda (row) (vector-ref row 4)) rows)))
                  (and (pair? bytes) (median bytes)))
         'allocation-samples (length (filter (lambda (row) (vector-ref row 4)) rows)))))

(def (paired label sample)
  (def reference [])
  (def production [])
  (for (side '(reference production production reference production reference reference production))
    (let (row (qualified-metrics (sample side)))
      (if (eq? side 'reference)
        (set! reference (cons row reference))
        (set! production (cons row production)))))
  (report (list label 'reference) reference)
  (report (list label 'production) production))

(def calls-per-sample 1024)
(def body-calls-per-sample 16384)
(def (measure-call call expected (count calls-per-sample))
  (check-equal? (call) expected)
  (defvalues (result row) (measure call count #t))
  (check-equal? result expected)
  row)

(def (keyword-generic side)
  (if (eq? side 'production) (.generic-object keyword-call) keyword-reference))

(def bundle-size 8)
(def bundles-per-sample 32)
(def bundle-protocol (poo-clos-generic-protocol 'benchmark-bundle))

(def (bundle-fixture)
  (def generic (poo-clos-generic-function 'bundle 1 protocol: bundle-protocol))
  (def methods
    (for/collect (i (in-range bundle-size))
      (poo-clos-method 'member (list (poo-clos-eql-specializer i))
                       (lambda (_frame value) value))))
  (cons generic (poo-clos-method-bundle 'bundle bundle-protocol methods)))

(def (measure-bundles side call?)
  (def fixtures (for/collect (_ (in-range bundles-per-sample)) (bundle-fixture)))
  (def (install)
    (for (fixture fixtures)
      (let ((generic (car fixture)) (bundle (cdr fixture)))
        (if (eq? side 'production)
          (poo-clos-compose-method-bundle generic bundle)
          (for-each (lambda (method) (poo-clos-add-method generic method))
                    (.ref bundle 'methods)))
        (when call?
          (unless (eqv? (poo-clos-call generic 0) 0)
            (error "first bundle dispatch returned the wrong result"))))))
  (defvalues (_ row) (measure install 1 #t))
  (for (fixture fixtures)
    (let ((generic (car fixture)) (methods (.ref (cdr fixture) 'methods)))
      (check-equal? (.ref generic 'methods) (reverse methods))
      (check-equal? (.ref generic 'generation) bundle-size)
      (for (method methods) (check-eq? (.ref method 'generic-function) generic))))
  row)

(def clos-admission-test
  (test-suite "CLOS admission and dispatch benchmark"
    (test-case "positional dispatch variation control"
      (paired (list 'positional calls-per-sample)
              (lambda (_) (measure-call (lambda () (positional 'object)) 'object))))
    (test-case "keyword binding with supplied flag"
      (for (input '(((object color: #f) #t . #f) ((object) #f . object)))
        (def arguments (car input))
        (def expected (cdr input))
        (paired (list 'keyword calls-per-sample arguments)
                (lambda (side)
                  (def generic (keyword-generic side))
                  (measure-call (lambda () (apply poo-clos-call generic arguments))
                                expected)))
        (paired (list 'keyword-body body-calls-per-sample arguments)
                (lambda (side)
                  (def body (.ref (car (.ref (keyword-generic side) 'methods)) 'body))
                  (measure-call (lambda () (apply body #f arguments))
                                expected body-calls-per-sample)))))
    (test-case "new generic installs an eight-method bundle"
      (paired (list 'bundle bundles-per-sample bundle-size)
              (lambda (side) (measure-bundles side #f)))
      (paired (list 'bundle-and-first-call bundles-per-sample bundle-size)
              (lambda (side) (measure-bundles side #t))))))
