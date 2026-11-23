(define-type (Pair. @ [methods.bytes<-marshal Type.] left right)
  .validate: (lambda (value) (validate-pair @ left right value))
  .diagnose: (lambda (value location) (pair-shape @ left right value location diagnose-value))
  .diagnose-shape: (lambda (value location (check-field diagnose-structure))
                     (pair-shape @ left right value location check-field))
  .element?: (lambda (v) (and (pair? v) (element? left (car v)) (element? right (cdr v))))
  .sexp<-: (lambda (v) `(cons ,(sexp<- left (car v)) ,(sexp<- right (cdr v))))
  .json<-: (lambda (v) [(json<- left (car v)) (json<- right (cdr v))])
  ;; Decode each child through its descriptor, including integer strings and containers.
  .<-json: (lambda (j)
    (let* ((a (<-json left (car j))) (d (<-json right (cadr j)))) (cons a d)))
  .marshal: (lambda (v port)
              (marshal left (car v) port)
              (marshal right (cdr v) port))
  .unmarshal: (lambda (port) (let* ((a (unmarshal left port))
                               (d (unmarshal right port)))
                          (cons a d))))
(def (Pair left right)
  {(:: @ Pair.) left right sexp: `(Pair ,(.@ left sexp) ,(.@ right sexp))})

(define-type (TypeValuePair @ Type.)
  .element?: (match <> ([t . v] (and (element? Type t) (element? t v))) (_ #f))
  .validate: (lambda (value) (validate-type-value @ value))
  .diagnose: (lambda (value location) (type-value-shape @ value location diagnose-value))
  .diagnose-shape: (lambda (value location (check-field diagnose-structure))
                     (type-value-shape @ value location check-field))
  .sexp<-: (match <> ([t . v] `(cons ,(.@ t sexp) ,(sexp<- t v))))
  .json<-: (match <> ([t . v] [(sexp<- Type t) (json<- t v)])) ;; supposes a simple enough type
  .<-json: invalid ;; maybe we should somehow register types that are valid for I/O into a table?
  .marshal: invalid
  .unmarshal: invalid)


;; This was not put in number.ss because it depended on Pair
(define-type (Rational @ Real)
  .element?: rational?
  ;; NB: a Scheme "rational" includes floating point numbers.
  ;; For actual ratios between integers, we should have a separate type "Ratnum" or some such.
  .Pair: (Pair Integer UInt) ;; Pair isn't defined until a later file. Commenting out for now.
  .pair<-: (lambda (x) (cons (numerator x) (denominator x)))
  ;; Pair decoders and compose supply one admitted pair, not two arguments.
  .<-pair: (lambda (parts) (/ (car parts) (cdr parts)))
  .marshal: (lambda (x port) (marshal .Pair (.pair<- x) port))
  .unmarshal: (compose .<-pair (.@ .Pair .unmarshal))
  .bytes<-: (u8vector<-<-marshal .marshal)
  .<-bytes: (<-u8vector<-unmarshal .unmarshal)
  .json<-: (compose (.@ .Pair .json<-) .pair<-)
  .<-json: (compose .<-pair (.@ .Pair .<-json)))
