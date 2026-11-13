;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import :std/test :std/iter :clan/poo/clos
        (only-in :clan/poo/object .ref replay-slot-reads!)
        (only-in :clan/poo/slot-observation %call-with-recorded-slot-reads)
        (only-in :clan/poo/clos/objects require-clos-generic make-invocation-frame)
        (only-in :clan/poo/benchmarks/closure-measure measure median))
(export clos-dispatch-test)
(extern namespace: clan/poo/class-validation %prepared-local-slot?)

(extern namespace: clan/poo/clos/dispatch
        arguments-valid! protocol-ranked-methods keyword-arguments-valid!
        prepare-default-effective-method execute-standard-effective-method)

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
  (def (full) (apply poo-clos-call generic arguments))
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
    (if (eq? (poo-clos-call generic 'item color: 'selected) 'selected)
      (poo-clos-call generic 'other)
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

(def clos-dispatch-test
  (test-suite "CLOS dispatch phases"
    (test-case "matched batches isolate phases" (report-phases))
    (test-case "interleaved full calls use the same methods and arguments" (compare-dispatch))))
