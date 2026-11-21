;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import :std/test :std/iter :clan/poo/mop
        (only-in :clan/poo/object .o .ref replay-slot-reads!)
        (only-in :clan/poo/slot-observation %call-with-recorded-slot-reads
                 call-with-slot-read-observer)
        (only-in :clan/poo/clos/objects require-clos-generic make-invocation-frame)
        (only-in :clan/poo/benchmarks/closure-measure measure median))
(export clos-dispatch-test)
(extern namespace: clan/poo/class-validation %prepared-local-slot?)
(extern namespace: clan/poo/object %prepared-slot-present?)
(extern namespace: clan/poo/slot-observation %delivery-observers)

(extern namespace: clan/poo/clos/dispatch
        arguments-valid! protocol-ranked-methods keyword-arguments-valid!
        prepare-default-effective-method execute-standard-effective-method)
(extern namespace: clan/poo/clos/objects %published-method-positions)

(.defgeneric render (item &key ((color: color))))
(.defmethod (render item &key ((color: color) item color?))
  (if color? color item))
(.defmethod (render (item (eql 'other)) &key ((color: color) item))
  color)

(def (report-phases)
  (def generic (.generic-object render))
  (def arguments '(item color: selected))
  (def ranked (protocol-ranked-methods generic arguments))
  (def construct (prepare-default-effective-method generic arguments ranked))
  (def effective (construct))
  (def method (caar ranked))
  (def (full) (apply clos-call generic arguments))
  (def (observed) (%call-with-recorded-slot-reads full unique-roots?: #t))
  (defvalues (_ reads) (observed))
  (def phases
    (list
      (cons 'full full)
      (cons 'generic (lambda () (require-clos-generic generic)))
      (cons 'arity (lambda () (arguments-valid! generic arguments)))
      (cons 'applicable (lambda () (protocol-ranked-methods generic arguments)))
      (cons 'keyword (lambda () (keyword-arguments-valid! generic ranked arguments)))
      (cons 'effective (lambda () ((prepare-default-effective-method generic arguments ranked))))
      (cons 'frame (lambda () (make-invocation-frame effective arguments #f 'primary method)))
      (cons 'execute (lambda () (execute-standard-effective-method effective)))
      (cons 'capture (lambda () (let-values (((value _) (observed))) value)))
      (cons 'replay (lambda () (replay-slot-reads! reads void)))))
  (def samples (make-hash-table-eq))
  (for (pass (in-range 4))
    (for (phase (if (even? pass) phases (reverse phases)))
      (defvalues (_ clocks) (measure (cdr phase) 256 #t))
      (def name (car phase))
      (hash-put! samples name (cons (* 1000 (vector-ref clocks 0)) (hash-ref samples name '())))))
  (for (phase phases) (displayln (list 'PHASE (car phase) (median (hash-ref samples (car phase))))))
  (displayln (list 'READS (length reads)))
  (check-equal? (full) 'selected))

;; Disable only the private positive-presence probe. Both sides still run
;; production dispatch, with the same generics, bodies and full type checks.
(def (compare-dispatch)
  (def candidate %prepared-local-slot?)
  (def (reference _receiver _name) #f)
  (def samples (make-hash-table-eq))
  (def generic (.generic-object render))
  (def (call)
    (if (eq? (clos-call generic 'item color: 'selected) 'selected)
      (clos-call generic 'other)
      (error "keyword dispatch result changed")))
  (for (side '(reference candidate candidate reference candidate reference reference candidate))
    (defvalues (result clocks)
      (dynamic-wind
        (lambda () (set! %prepared-local-slot? (if (eq? side 'reference) reference candidate)))
        (lambda () (measure call 512 #t))
        (lambda () (set! %prepared-local-slot? candidate))))
    (check-equal? result 'other)
    (hash-put! samples side (cons (* 1000 (vector-ref clocks 0)) (hash-ref samples side '()))))
  (for (side '(reference candidate))
    (displayln (list 'DISPATCH side (median (hash-ref samples side))))))

(def (compare-observed)
  (def (call) (render 'item color: 'selected))
  (def (capture observer)
    (%call-with-recorded-slot-reads
      (lambda () (call-with-slot-read-observer observer call)) unique-roots?: #t))
  (def (capture-result observer) (let-values (((result _) (capture observer))) result))
  (defvalues (expected reads) (capture void))
  (def delivered 0)
  (def (count-read _read) (set! delivered (+ delivered 1)))
  (def deliveries-per-call (begin (capture count-read) delivered))
  (def present? %prepared-slot-present?)
  (def delivery %delivery-observers)
  (def (ordinary _receiver _slot) #f)
  (def (observe _receiver _key) (void))
  (def samples (make-hash-table))
  (def (sample name side action)
    (defvalues (result clocks) (measure action 256 #t))
    (def key (list name side))
    (hash-update! samples key (lambda (rows) (cons (* 1000 (vector-ref clocks 0)) rows)) '())
    result)
  (for (side '(reference candidate candidate reference candidate reference reference candidate))
    (def reference? (eq? side 'reference))
    (set! delivered 0)
    (dynamic-wind
      (lambda ()
        (set! %prepared-slot-present? (if reference? ordinary present?))
        (set! %delivery-observers (if reference? values delivery)))
      (lambda ()
        (check-equal? (sample 'capture side (cut capture-result void)) expected)
        (check-equal? (sample 'capture-callback side (cut capture-result count-read)) expected))
      (lambda ()
        (set! %prepared-slot-present? present?)
        (set! %delivery-observers delivery)))
    (check-equal? delivered (* 256 deliveries-per-call))
    (sample 'replay side (lambda () (replay-slot-reads! reads (if reference? observe void)))))
  (for* ((phase '(capture capture-callback replay)) (side '(reference candidate)))
    (displayln (list 'OBSERVED phase side (median (hash-ref samples (list phase side))))))
  (displayln (list 'OBSERVED-ROOTS (length reads))))

(def (compare-protocol-lookup)
  (def roots (for/collect (_ (in-range 32)) (.o)))
  (def argument (.o inherit: roots))
  (def protocol
    (clos-generic-protocol 'reorder
      compute-applicable-methods: (lambda (_generic _args methods) (reverse methods))))
  (def generic (clos-generic-function 'compare-protocol-lookup 1 protocol: protocol))
  (for-each
    (lambda (root)
      (clos-add-method generic
        (clos-method 'method (list (clos-prototype-specializer root)) void)))
    roots)
  (def arguments (list argument))
  (def (call) (protocol-ranked-methods generic arguments))
  (def expected (call))
  (def published %published-method-positions)
  (unless (published generic) (error "expected published method positions"))
  (def samples (make-hash-table-eq))
  (for (side '(reference candidate candidate reference candidate reference reference candidate))
    (defvalues (result metrics)
      (dynamic-wind
        (lambda ()
          (set! %published-method-positions
            (if (eq? side 'reference) (lambda (_) #f) published)))
        (lambda () (measure call 512 #t))
        (lambda () (set! %published-method-positions published))))
    (check-equal? result expected)
    (hash-update! samples side (cut cons metrics <>) '()))
  (for (side '(reference candidate))
    (def rows (hash-ref samples side))
    (displayln (list 'PROTOCOL side
      (median (map (lambda (row) (* 1000 (vector-ref row 0))) rows))
      (median (map (lambda (row) (vector-ref row 4)) rows))))))

(def clos-dispatch-test
  (test-suite "CLOS dispatch phases"
    (test-case "matched batches isolate phases" (report-phases))
    (test-case "interleaved full calls use the same methods and arguments" (compare-dispatch))
    (test-case "interleaved observed captures and replay of the same roots" (compare-observed))
    (test-case "interleaved protocol lookup uses the published method positions"
      (compare-protocol-lookup))))
