;;; JSON I/O

(defmethod (@method :write-json object)
  (lambda (self port)
    (cond
     ((.has? self .type .write-json) ((.@ self .type .write-json) self port))
     ((.has? self .type .json<-) (write-json ((.@ self .type .json<-) self) port))
     ((.has? self sexp) (write-json (object->string (.@ self sexp)) port))
     (else (write-json (walist (.alist self)) port)))))
(defmethod (@method :json object)
  (lambda (self)
    (cond
     ;;((.has? self .type .write-json) self) ;; TODO: Uncomment after vyzo/gerbil#595 goes through
     ((.has? self .type .json<-) ((.@ self .type .json<-) self))
     ((.has? self sexp) (object->string (.@ self sexp)))
     (else (hash<-object self)))))

(def (json-string<- type x)
  (string<-json (json<- type x)))
(def (<-json-string type x)
  (<-json type (json<-string x)))

(define-type (methods.string<-json @ [] .json<- .<-json)
  .string<-: (compose string<-json .json<-)
  .<-string: (compose .<-json json<-string))

;;; (Un)Marshaling data to/from bytes
;; The output has to be self-delimited, so marshaling output can be concatenated given the types.
;; A trivial way to satisfy this constraint is for the output to have fixed length,
;; or for the length to be prepended. Another way is to have some terminator value (e.g. 0 in C strings).

(.defgeneric (marshal type x port) slot: .marshal)
(.defgeneric (unmarshal type port) slot: .unmarshal)

(defrule (marshal-product port (val type) ...)
  (begin (marshal type val port) ...))
(defrule (unmarshal-product port type ...)
  (left-to-right values (unmarshal type port) ...))


;;; Converting to/from bytes
;; Unlike with marshaling, these bytes do NOT have to be self-delimited in case length is variable.

;; The bytes<- and its corresponding .bytes<- methods return bytes (a byte vector)
;; that need not be self-delimiting, as contrasted to the marshal method that must output
;; a self-delimiting sequence of bytes. There is usually no difference for a fixed-size data types,
;; but there may be a difference for variable-size types, wherein bytes<- may omit size information
;; that marshal must include.
;; : Bytes <- 'a:Type 'a
(.defgeneric (bytes<- type x) slot: .bytes<-)

;; The <-bytes function and its .<-bytes methods take bytes as output by the bytes<- function,
;; and return an object of the given type that will be equal to the originally encoded object,
;; according to whichever equality predicate makes sense for the data type.
;; : 'a <- 'a:Type Bytes
(.defgeneric (<-bytes type b) slot: .<-bytes)

(define-type (methods.bytes<-marshal @ [] .marshal .unmarshal)
  .bytes<-: (u8vector<-<-marshal .marshal)
  .<-bytes: (<-u8vector<-unmarshal .unmarshal))

(define-type (methods.marshal<-bytes @ [] .<-bytes .bytes<- .Bytes)
  .marshal: (lambda (x port) (marshal .Bytes (.bytes<- x) port))
  .unmarshal: (lambda (port) (.<-bytes (unmarshal .Bytes port))))

(define-type (methods.marshal<-fixed-length-bytes @ [] .<-bytes .bytes<- .length-in-bytes)
  .marshal: (lambda (x port) (write-u8vector* (.bytes<- x) port))
  .unmarshal: (lambda (port) (.<-bytes (unmarshal-n-u8 .length-in-bytes port))))

;;; Converting to/from string

;; : String <- 'a:Type 'a
(.defgeneric (string<- type x) slot: .string<-)

;; : 'a <- 'a:Type String
(.defgeneric (<-string type b) slot: .<-string)
