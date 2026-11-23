(define-type (methods.bytes @ [])
  .sexp<-: (lambda (x) ['hex-decode (hex-encode x)])
  .string<-: hex-encode
  .<-string: hex-decode
  .bytes<-: identity
  .<-bytes: identity
  .json<-: .string<-
  .<-json: .<-string)
(define-type (Bytes @ [methods.bytes Type.])
  .sexp<-: (lambda (x) `(hex-decode ,(hex-encode x)))
  .element?: u8vector?
  .Length: UInt
  .zero: #u8()
  .marshal: (lambda (x port) (marshal .Length (u8vector-length x) port) (write-u8vector* x port))
  .unmarshal: (lambda (port) (def n (unmarshal .Length port)) (unmarshal-n-u8 n port)))
(define-type (BytesN. @ [methods.bytes Type.] n)
  .element?: (λ (x) (and (u8vector? x) (= (u8vector-length x) n)))
  .validate: (λ (x)
               (unless (u8vector? x) (raise-type-error @ x))
               (unless (= (u8vector-length x) n)
                 (raise-type-error @ x [length-mismatch: expected: n given: (u8vector-length x)]))
               x)
  .sexp<-: (.@ Bytes .sexp<-)
  .length-in-bytes: n
  .zero: (make-u8vector n)
  .<-string: (λ (x) (validate @ (hex-decode x)))
  .<-bytes: (cut validate @ <>)
  .marshal: write-u8vector*
  .unmarshal: (cut unmarshal-n-u8 n <>))
(def BytesN<-n (make-hash-table))
(def (BytesN n (sexp `(BytesN ,n)))
  (hash-ensure-ref BytesN<-n n (lambda () {(:: @ BytesN.) n sexp})))
(def Bytes32 (BytesN 32 'Bytes32))
(def Bytes64 (BytesN 64 'Bytes64))

(define-type (String @ [methods.marshal<-bytes Type.])
  .element?: string?
  .Bytes: Bytes
  .zero: ""
  .add: string-append
  .=?: string=?
  .sexp<-: identity
  .<-string: identity
  .string<-: identity
  .bytes<-: string->bytes
  .<-bytes: bytes->string
  .<-json: (cut validate @ <>)
  .json<-: identity)
(define-type (methods.bytes&marshal<-string @ [methods.bytes<-marshal] .<-string .string<-)
  .String: String
  .marshal: (lambda (x port) (marshal .String (.string<- x) port))
  .unmarshal: (lambda (port) (.<-string (unmarshal .String port))))
(define-type (methods.json&bytes&marshal<-string @ [methods.bytes&marshal<-string] .<-string .string<-)
  .<-json: .<-string
  .json<-: .string<-)
(define-type (Symbol @ [methods.json&bytes&marshal<-string Type.])
  .element?: symbol?
  .sexp<-: (cut list 'quote <>)
  .<-string: string->symbol
  .string<-: symbol->string)
(define-type (Keyword @ [methods.json&bytes&marshal<-string Type.])
  .element?: keyword?
  .sexp<-: identity
  .<-string: string->keyword
  .string<-: keyword->string)
(define-type (Json @ [methods.bytes&marshal<-string Type.])
  .element?: true
  .sexp<-: (lambda (x) `(json<-string ,(.string<- x)))
  .json<-: identity
  .<-json: identity
  .string<-: string<-json
  .<-string: json<-string)
(define-type (methods.string&bytes&marshal<-json @ [methods.bytes&marshal<-string] .json<- .<-json)
  .string<-: (compose string<-json .json<-)
  .<-string: (compose .<-json json<-string))
