;;; Ordered open Slot callbacks and diagnostic-group admission.
(import :std/test :std/error
        (only-in :clan/poo/object .o .get .all-slots .put!)
        (only-in :clan/poo/class-validation class-shape))
(export class-diagnostics-test)

(def (fixture callback)
  (def policy (.o .slot.shape: callback))
  (def slot (.o .type: policy))
  (values (.o sealed: #f effective-slots: (.o a: slot b: slot c: slot)) policy))

(def (shape descriptor)
  (class-shape descriptor (.o a: 1 b: 2 c: 3) '() (lambda _ '())))

(def class-diagnostics-test
  (test-suite "Ordered Class diagnostic aggregation"
    (test-case "empty groups retain every callback in inventory order"
      (def seen '())
      (defvalues (descriptor _policy)
        (fixture (lambda (_slot name _candidate _location _check)
                   (set! seen (cons name seen)) '())))
      (check-equal? (shape descriptor) '())
      (check-equal? (reverse seen) (.all-slots (.get descriptor effective-slots))))
    (test-case "mixed groups retain diagnostic identity and locked internal order"
      (def a1 (.o kind: 'a1 path: '())) (def a2 (.o kind: 'a2 path: '()))
      (def c1 (.o kind: 'c1 path: '())) (def c2 (.o kind: 'c2 path: '()))
      (def seen '())
      (defvalues (descriptor _policy)
        (fixture (lambda (_slot name _candidate _location _check)
                   (set! seen (cons name seen))
                   (case (length seen)
                     ((1) (list a1 a2)) ((2) '()) (else (list c1 c2))))))
      (def actual (shape descriptor))
      (check-equal? (length actual) 4)
      (for-each (lambda (item expected) (check-eq? item expected))
                actual (list a2 a1 c2 c1))
      (check-equal? (reverse seen) (.all-slots (.get descriptor effective-slots))))
    (test-case "false groups retain the locked append-map behavior and every callback"
      (def seen '())
      (def raised #f)
      (def result #f)
      (defvalues (descriptor _policy)
        (fixture (lambda (_slot name _candidate _location _check)
                   (set! seen (cons name seen))
                   (if (= (length seen) 1) #f '()))))
      ;; Assert outside the handler: broad Error? must not catch the assertion.
      (with-catch (lambda (cause) (set! raised cause))
        (lambda () (set! result (shape descriptor))))
      (check-equal? (reverse seen) (.all-slots (.get descriptor effective-slots)))
      (check-eq? raised #f)
      (check-equal? result '()))
    (test-case "callback exceptions retain their cause and suppress the suffix"
      (def cause (with-catch values (lambda () (error "shape callback refused"))))
      (def calls 0)
      (defvalues (descriptor _policy)
        (fixture (lambda _
                   (set! calls (+ calls 1))
                   (if (= calls 2) (raise cause) '()))))
      (check-exception (shape descriptor) (lambda (raised) (eq? raised cause)))
      (check-equal? calls 2))
    (test-case "later fields resolve the current Slot shape method"
      (def calls '())
      (def policy #f)
      (defvalues (descriptor current)
        (fixture (lambda _
                   (set! calls (cons 'first calls))
                   (.put! policy '.slot.shape
                     (lambda _ (set! calls (cons 'current calls)) '()))
                   '())))
      (set! policy current)
      (check-equal? (shape descriptor) '())
      (check-equal? (reverse calls) '(first current current)))
    (test-case "continuation re-entry cannot retain an earlier result spine"
      (def seen '())
      (def resume #f)
      (def replayed? #f)
      (defvalues (descriptor _policy)
        (fixture (lambda (_slot name _candidate _location _check)
                   (set! seen (cons name seen))
                   (if (= (length seen) 1)
                     (call/cc (lambda (continuation)
                                (set! resume continuation)
                                (list name)))
                     (list name)))))
      (def names (.all-slots (.get descriptor effective-slots)))
      (def result (shape descriptor))
      (if replayed?
        (begin
          (check-equal? result (cdr names))
          (check-equal? (reverse seen) (append names (cdr names))))
        (begin
          (check-equal? result names)
          (set! replayed? #t)
          (resume '()))))))
