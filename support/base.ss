;;; Small control-plane primitives owned by gerbil-poo.

(export #t)

(import
  (only-in :std/error deferror-class defraise/context)
  (only-in :std/func rcompose))

(defalias λ lambda)
(defrule (lambda-match clauses ...) (match <> clauses ...))
(defalias λ-match lambda-match)
(defrule (ignore-errors body ...) (with-catch false (lambda () body ...)))
(defrule (awhen (id test) body ...) (let (id test) (when id body ...)))
(defrule (until test body ...) (let loop () (unless test body ... (loop))))
(defrule (hash (key value) ...) (list->hash-table [(cons key value) ...]))

(defsyntax (nest stx)
  (syntax-case stx ()
    ((_ outer ... inner)
     (foldr (lambda (outer-form inner-form)
              (with-syntax (((o ...) outer-form) (i inner-form))
                #'(o ... i)))
            #'inner
            #'(outer ...)))))

(defsyntax (left-to-right stx)
  (syntax-case stx ()
    ((_ fun arg ...)
     (with-syntax (((tmp ...) (gentemps #'(arg ...))))
       #'(let* ((tmp arg) ...) (fun tmp ...))))))

(deferror-class Undefined ())
(defraise/context (raise-undefined where irritants)
  (Undefined "undefined" irritants: irritants))
(def (undefined . args) (raise-undefined undefined args))

(deferror-class Invalid ())
(defraise/context (raise-invalid where irritants)
  (Invalid "invalid" irritants: irritants))
(def (invalid . args) (raise-invalid invalid args))

(def (looking-for value test: (test equal?) key: (key identity))
  (λ (x) (test value (key x))))
(def (comparing-key test: (test equal?) key: (key identity))
  (λ (x y) (test (key x) (key y))))

(defrules let-id-rule ()
  ((_ ((id val) ...) body ...)
   (let-syntax ((id (identifier-rules () ((_ . a) (val . a)) (_ val))) ...)
     body ...))
  ((_ (id val) body ...)
   (let-id-rule ((id val)) body ...)))

(defrule (defonce (id) body)
  (def id (let ((promise (delay body))) (lambda () (force promise)))))

(defrules modify! ()
  ((_ x f) (set! x (f x)))
  ((_ x f1 fs ...) (set! x ((rcompose f1 fs ...) x)))
  ((_ x) (void)))

(def (number-comparer x y) (if (= x y) 0 (if (< x y) -1 1)))
