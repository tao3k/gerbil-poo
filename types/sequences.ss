;; V19 vector-map/index visits right-to-left; port reads require left-to-right.
(def (vector-map-in-order f source)
  (def result (make-vector (vector-length source)))
  (vector-for-each/index
   (lambda (index value) (vector-set! result index (f index value)))
   source)
  result)

(def (vector-map2-in-order f left right)
  (def length (vector-length left))
  (unless (= length (vector-length right))
    (error "vector-map2-in-order: length mismatch" length (vector-length right)))
  (vector-unfold
   (lambda (index) (f index (vector-ref left index) (vector-ref right index)))
   length))

(define-type (Tuple. @ [methods.bytes<-marshal Type.] types)
  .gerbil-type: vector::t
  type-list: (vector->list types)
  .validate: (lambda (value) (validate-tuple @ types value))
  .diagnose: (lambda (value location) (tuple-shape @ types value location diagnose-value))
  .diagnose-shape: (lambda (value location (check-field diagnose-structure))
                     (tuple-shape @ types value location check-field))
  .element?:
    (λ (x)
      (def l (vector-length types))
      (and (vector? x) (= (vector-length x) l)
           (let/cc return
             (for ((i (in-range l)))
               (unless (element? (vector-ref types i) (vector-ref x i)) (return #f)))
             #t)))
  .sexp<-: (lambda (v) `(vector ,@(vector->list (vector-map2-in-order (lambda (_ t x) (sexp<- t x)) types v))))
  .json<-: (lambda (v) (vector->list (vector-map2-in-order (lambda (_ t x) (json<- t x)) types v)))
  .<-json: (lambda (j) (vector-map2-in-order (lambda (_ t x) (<-json t x)) types (if (list? j) (list->vector j) j)))
  .marshal: (lambda (v port)
              (vector-for-each/index (lambda (_ type val) (marshal type val port))
                                     types v))
  .unmarshal: (lambda (port)
                (vector-map-in-order (lambda (_ type) (unmarshal type port)) types)))
(def (Tuple . type-list) ;; type of tuples, heterogeneous arrays of given length and type
  (def types (list->vector (map (cut validate Type <>) type-list)))
  {(:: @ Tuple.) (types) sexp: `(Tuple ,@(map (cut .@ <> sexp) type-list))})

(define-type (List. @ [methods.bytes<-marshal methods.string<-json Type.] type)
  .gerbil-type: list::t
  .Length: UInt
  .validate: (lambda (value) (validate-list @ type value))
  .diagnose: (lambda (value location) (list-shape @ type value location diagnose-value))
  .diagnose-shape: (lambda (value location (check-field diagnose-structure))
                     (list-shape @ type value location check-field))
  .element?: (λ (x) (and (list? x) (every (cut element? type <>) x)))
  .sexp<-: (lambda (v) ['@list (map (.@ type .sexp<-) v) ...])
  .json<-: (let (m (.@ type .json<-)) (cut map m <>))
  .<-json: (let (m (.@ type .<-json)) (cut map m <>))
  .marshal: (let (m (.@ type .marshal))
              (lambda (v port) (marshal .Length (length v) port) (for-each (cut m <> port) v)))
  .unmarshal: (let ((ul (.@ .Length .unmarshal))
                    (ut (.@ type .unmarshal)))
                (lambda (port) (def l (ul port)) (for/collect (_ (in-range l)) (ut port)))))
(def (List type)
  (validate Type type)
  {(:: @ List.) (type) sexp: `(List ,(.@ type sexp))})
