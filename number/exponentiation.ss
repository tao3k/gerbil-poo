;; Compute a*x^e where multiplication is given by mul and e is a natural number,
;; by dichotomizing the exponent e.
;; Note: not safe vs side-channel leak for cryptographic use unless mul is, and n is specified,
;; and the suggested modification is made (and even then, be sure to use a constant-time if)
(def (mul-expt<-mul mul a x e (n (integer-length e)))
  (cond
   ((positive? n)
    (let loop ((i 0) (a a) (x x))
      (let* ((bit? (bit-set? i e))
             (j (1+ i))
             (aa (if bit? (mul a x) a))) ;; for constant-time, try (mul a (if bits? x 1))
        (if (> n j)
          (loop j aa (mul x x))
          aa))))
   ((zero? n)
    a)
   (else
    (error "exponent n must be a non-negative integer"))))

;; Compute a*x^e where multiplication is given by mul, inversion by inv, and e is a relative integer,
;; by dichotomizing the exponent e.
(def (mul-expt<-mul-inv mul inv a x e)
  (if (negative? e)
    (mul-expt<-mul mul a (inv x) (- e))
    (mul-expt<-mul mul a x e)))

;; natural integers as exponents
(define-type (expt<-mul. @ [Type.] .one .inv .mul)
  .mul-expt: (lambda (a x e) (mul-expt<-mul .mul a x e))
  .expt: (lambda (x e) (.mul-expt .one x e)))

;; relative integers as exponents
(define-type (expt<-mul-inv. @ [Type.] .one .inv .mul)
  .mul-expt: (lambda (a x e) (mul-expt<-mul-inv .mul .inv a x e))
  .expt: (lambda (x e) (.mul-expt .one x e)))
