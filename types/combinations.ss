(define-type (Or. @ [methods.bytes<-marshal Type.] types)
  types@: (list->vector types)
  .element?: (λ (x) (any (cut element? <> x) types))
  ;; Preserve first-member selection while retaining recursive child wrappers.
  .validate: (lambda (value) (validate-or @ types value))
  ;; WE ASSUME THE JSON'S ARE DISJOINT, AS ARE THE VALUES (BUT WE DISCRIMINATE WHEN MARSHALLING)
  .discriminant-length-in-bits: (integer-length (1- (length types)))
  .discriminant-length-in-bytes: (n-bits->n-u8 .discriminant-length-in-bits)
  .discriminant<-: (lambda (v) (let/cc return (vector-for-each/index (lambda (i t) (when (element? t v) (return i))) types@) #f))
  .sexp<-: (lambda (v) (sexp<- (vector-ref types@ (.discriminant<- v)) v))
  .json<-: (lambda (v) (def disc (.discriminant<- v))
              ;;[disc (json<- (vector-ref types@ disc) v)])
              (json<- (vector-ref types@ disc) v))
  .<-json: ;;(lambda (j) (<-json (vector-ref types@ (car j)) (cadr j)))
  (lambda (v) (let/cc return (for-each (lambda (t) (return (<-json t v))) types) #f))
  .marshal: (lambda (v port)
              (def disc (.discriminant<- v))
              (write-uint-u8vector disc .discriminant-length-in-bytes port)
              (marshal (vector-ref types@ disc) v port))
  .unmarshal: (lambda (port)
                (def disc (read-uint-u8vector .discriminant-length-in-bytes port))
                (unmarshal (vector-ref types@ disc) port)))
(def (Or . types) {(:: @ Or.) (types) sexp: `(Or ,@(map (cut .@ <> sexp) types))})

;; Intersection uses the same Type validators as Class and Slot. Its final
;; check is necessary because a later normalizer can violate an earlier Type.
(extern namespace: clan/poo/object %owned-list-slot-spec %ref-owned-list)
(define-type (And. @ Type.)
  .element?: (lambda (value)
               (andmap (cut element? <> value) (%ref-owned-list @ 'types)))
  .validate: (lambda (value)
               (validate-intersection @ (%ref-owned-list @ 'types) value)))

;; Empty conjunction is Top; a single Type retains its identity and validator.
;; Keep repeated declarations: author validators need not be idempotent.
(def (And . types)
  (for-each (lambda (type)
              (unless (element? Type type) (raise-type-error Type type))) types)
  (cond ((null? types) Top)
        ((null? (cdr types)) (car types))
        (else
         (let (descriptor
               (.o (:: @ And.)
                   sexp: (cons 'And (map (cut .ref <> 'sexp)
                                        (%ref-owned-list @ 'types)))))
           (.putslot! descriptor 'types (%owned-list-slot-spec types))
           (seal-object! descriptor)))))

;; Bottom tells you everything about nothing
(define-type (Bottom @ Type.)
  .element?: false
  .sexp<-: invalid
  .bytes<-: invalid .<-bytes: invalid
  .json<-: invalid .<-json: invalid
  .marshal: invalid .unmarshal: invalid)
(defalias ⊥ Bottom)

;; Top tells you nothing about everything
(define-type (Top @ [Type.])
  .element?: true
  .sexp<-: invalid
  .string<-: invalid .<-string: invalid
  .bytes<-: invalid .<-bytes: invalid
  .json<-: invalid .<-json: invalid)
(defalias ⊤ Top)

(define-type (Exactly. @ Type. value)
  .element?: (λ (x) (equal? x value))
  .Log: Bottom
  kvalue: (lambda _ value)
  jsvalue: (json-normalize value)
  .sexp<-: (.@ Any .sexp<-)
  .json<-: (lambda (x) (assert! (equal? x value)) jsvalue)
  .<-json: (lambda (x) (assert! (equal? x jsvalue)) value)
  .bytes<-: (lambda _ #u8())
  .<-bytes: kvalue
  .marshal: void
  .unmarshal: kvalue)
;; TODO: have a better generic sexp function?
(def (Exactly value) {(:: @ Exactly.) (value) sexp: `(Exactly ,(:sexp value))})

(define-type Null (Exactly '()))
(define-type False (Exactly #f))
(define-type True (Exactly #t))
(define-type Unit (Exactly (void)))

(def (first-index-hash<-vector values)
  (def indices (make-hash-table size: (vector-length values)))
  (for (index (in-range (vector-length values)))
    (hash-ensure-ref indices (vector-ref values index) (lambda () index)))
  indices)

(define-type (Enum. @ [methods.marshal<-fixed-length-bytes Type.] vals)
  .vals@: (list->vector vals)
  .json@: (list->vector (map json-normalize vals))
  .value-indices@: (first-index-hash<-vector .vals@)
  .json-indices@: (first-index-hash<-vector .json@)
  .element?: (cut hash-key? .value-indices@ <>)
  .length-in-bits: (integer-length (1- (vector-length .vals@)))
  .length-in-bytes: (n-bits->n-u8 .length-in-bits)
  .<-uint: (cut vector-ref .vals@ <>)
  .uint<-: (cut hash-get .value-indices@ <>)
  .json<-: (lambda (v) (vector-ref .json@ (.uint<- v)))
  .<-json: (cut hash-get .json-indices@ <>)
  .bytes<-: (compose (cut uint->u8vector <> big .length-in-bytes) .uint<-)
  .<-bytes: (compose .<-uint u8vector->uint)
  .marshal: => (lambda (super) (if (zero? .length-in-bytes) void super))
  .unmarshal: => (lambda (super) (cond
                             ((< 0 .length-in-bytes) super)
                             ((void? vals) (lambda _ (error "no value to unmarshal of type" sexp)))
                             (else (let (val (car vals)) (lambda _ val)) super))))
(defrule (Enum values ...) {(:: @ Enum.) vals: '(values ...)
                            sexp: `(Enum ,@(map :sexp vals))})

;; Untagged union. Can be used for JSON, but no automatic marshaling.
(define-type (Union. @ [methods.string&bytes&marshal<-json Type.] types)
  .validate: (lambda (value) (validate-union @ types value))
  .diagnose: (lambda (value location) (union-diagnostics @ types value location))
  .diagnose-shape: (lambda (value location (check-field diagnose-structure))
                     (union-shape @ types value location check-field))
  .element?: (λ (x) (any (cut element? <> x) types))
  .json<-: (lambda (v) (let/cc return
                    (for-each (λ (t) (when (element? t v) (return (json<- t v))))
                              types)
                    (error "invalid element of type" v sexp)))
  .<-json: (lambda (j) (let/cc return
                    (for-each (λ (t) (ignore-errors (return (<-json t j))))
                              types)
                    (error "invalid json for type" j sexp))))
;; Ordered alternatives keep recognition separate from committed normalization.
(def (Union . types)
  (for-each (cut validate Type <>) types)
  {(:: @ Union.) (types) sexp: `(Union ,@(map (cut .@ <> sexp) types))})
