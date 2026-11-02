(export #t)

(import
  (only-in :gerbil/runtime/loader load-module)
  :std/assert
  (only-in :std/error raise-premature-end-of-input)
  (only-in :std/io/interface/base Reader Reader-read Writer Writer-write)
  :std/format
  (only-in :std/func compose)
  :std/iter
  :std/list/walist
  :std/encoding/json
  ./support/repr
  ./support/base
  ./support/io
  ./support/json
  ./object
  (only-in ./prototype-map prototype-map-keys)
  ./mop)

(extern namespace: "clan/poo/io" writeenv-style)
(begin-foreign
  (include "~~lib/_gambit#.scm")
  (define (clan/poo/io#writeenv-style environment)
    (macro-writeenv-style environment)))

;; Capture one runtime entry as a Reader-compatible IO action, without loading it.
;; The private path copy cannot drift away from the caller's explicit binding.
;; Gerbil owns discovery, dependency preparation and initialization/error caching.
;; Resolve the binding on EVERY invocation so successful reloads are visible;
;; tail apply preserves all values and the original loading/entry exceptions.
;; Binding is an explicit runtime identifier, including canonical reexport targets;
;; this boundary does not infer export aliases or retain a second module registry.
(def (module-action module binding)
  (using ((module :~ string?) (binding :~ symbol?))
    (let (path (string-copy module))
      (lambda (arguments)
        ;; Admit a finite call row before initialization effects. Own its spine
        ;; across loading/lookup; payloads, including Function values, stay shared.
        (using (arguments :~ list?)
          (let (request (list-copy arguments))
            ;; Standard loader diagnostics may expose the supplied string.
            ;; Hand off a copy so error inspection cannot retarget this action.
            (load-module (string-copy path))
            (apply (eval binding) request)))))))

;;; Byte I/O

;; Read one byte from a standard port or Reader; EOF remains the standard object.
;; The port path allocates no temporary buffer and never creates a buffered wrapper.
(def (object-read-byte input)
  (if (input-port? input) (read-u8 input)
    (let (byte (make-u8vector 1))
      (if (zero? (read-bytes-into byte input)) #!eof (u8vector-ref byte 0)))))

;; Write one byte through the standard port/Writer protocol, retaining its errors.
;; Closing/flushing and recovery of partially completed I/O belong to the caller.
(def (object-write-byte byte output)
  (if (output-port? output) (write-u8 byte output)
    (object-write-bytes (u8vector byte) output)))

;; One admission boundary translates offset/length/need to Reader's start/end/need.
;; A positive request attempts a read; zero bytes mean EOF. A short required read
;; raises the standard I/O error. Zero-length requests admit the source interface
;; but perform no read. Caller buffers may retain a prefix after an I/O failure.
(def (read-bytes-into (bytes : :u8vector) input
       offset: (offset 0) length: (length (- (u8vector-length bytes) offset))
       need: (need 0))
  (using ((offset :~ (in-range-inclusive? 0 (u8vector-length bytes)))
          (length :~ (in-range-inclusive? 0 (- (u8vector-length bytes) offset)))
          (need :~ (in-range-inclusive? 0 length)))
    (def end (+ offset length))
    (if (input-port? input)
      (if (zero? length) 0
        (let (read (read-subu8vector bytes offset end input (max 1 need)))
          (when (< read need) (raise-premature-end-of-input read-bytes-into)) read))
      (using (reader input : Reader)
        (if (zero? length) 0 (reader.read bytes offset end need))))))

;; Return exactly count fresh bytes, or propagate premature EOF without exposing
;; the private partial buffer. The input's consumed prefix is not rolled back.
(def (object-read-bytes (count :~ nonnegative-fixnum?) input)
  (def bytes (make-u8vector count))
  (read-bytes-into bytes input need: count)
  bytes)

;; Write the requested span with standard bulk I/O rather than a byte loop.
;; Range admission precedes output effects; a successful operation returns Unit.
(def (object-write-bytes (bytes : :u8vector) output
       offset: (offset 0) length: (length (- (u8vector-length bytes) offset)))
  (using ((offset :~ (in-range-inclusive? 0 (u8vector-length bytes)))
          (length :~ (in-range-inclusive? 0 (- (u8vector-length bytes) offset))))
    (def end (+ offset length))
    (if (output-port? output)
      (unless (zero? length) (write-subu8vector bytes offset end output))
      (using (writer output : Writer)
        (unless (zero? length) (writer.write bytes offset end))))
    (void)))

;;; Printing objects as per std/misc/repr

(defmethod (@method :pr object)
  (λ (self (port (current-output-port)) (options (current-representation-options)))
    (def (d . l) (for-each (cut display <> port) l))
    (cond
     ((and (object-%instance self) (not (object-%slot-funs self)))
      (d "#" (object->serial-number self) "#;{(inconsistent object)")
      (for-each (lambda (slot) (d " " slot))
        (append (prototype-map-keys (object-%slots self)) (prototype-map-keys (object-%defaults self))))
      (d "}"))
     ((.has? self .type .print-representation) ((.@ self .type .print-representation) self port options))
     ((.has? self .type .sexp<-) (write ((.@ self .type .sexp<-) self) port))
     ((.has? self .type) (print-class-object self port options))
     ((.has? self print-representation) (.call self print-representation port options))
     ((.has? self sexp) (write (.@ self sexp) port))
     ;; TODO: have a better fallback
     (else
      (let ()
        (def first? #t)
        (def slots (.all-slots self))
        (def h (or (object-%instance self) (hash)))
        (d "#" (object->serial-number self) " #;{")
        (for-each (lambda (k)
                    (if first? (set! first? #f) (d " "))
                    (d (symbol->string k) ": ")
                    (if (and h (hash-key? h k))
                      (pr (hash-get h k) port options)
                      (d "…")))
                  slots))
      (d "}")))))

(def (print-class-object
      x (port (current-output-port)) (options (current-representation-options)))
  (def (d x) (display x port))
  (def (w x) (write x port))
  (d "#") (d (object->serial-number x)) (d "#;{")
  (try
   (for-each (λ-match ([k . v] (d " (") (w k) (d " ") (prn v) (d ")"))) (.alist x))
   (catch (e) (void)))
  (d "}"))

(.defgeneric (printable-slots x) from: type default: .all-slots slot: .printable-slots)

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


;;; Gambit printer hook for object. See https://git.cons.io/mighty-gerbils/gerbil/issues/589
;;; See also ##inverse-eval.
(defmethod (@method :wr object)
  (lambda (self we)
    (ignore-errors (instantiate-object! self))
    (def inconsistent? (not (object-%slot-funs self)))
    (defvalues (slots h)
      (if inconsistent?
        (values (append (prototype-map-keys (object-%slots self))
                        (prototype-map-keys (object-%defaults self))) (hash))
        (values (.all-slots self) (object-%instance self))))
    (def style (writeenv-style we))
    (def mark? (eq? style 'mark))
    (def (s x) (unless mark? (##wr-str we x)))
    (def (w x) (##wr we x))
    (def (comma)
      (case style
        ((mark display) (void))
        ((write write-shared pretty-print) (s ","))))
    (def (sn)
      (s "#") (w (object->serial-number self)) (s " #;"))
    (def (wr-fields)
      (def first #t)
      (for-each (lambda (k)
                  (unless mark?
                    (if first
                      (begin
                        (set! first #f)
                        (s "{")
                        (when inconsistent?
                          (s "(inconsistent object) ")))
                      (s " "))
                    (w (string->keyword (symbol->string k)))
                    (s " "))
                  (if (and h (hash-key? h k))
                    (w (hash-get h k))
                    (s "…")))
                slots)
      (s "}"))
    (cond
     ((.has? self .type .write-object)
      ((.@ self .type .write-object) we self))
     ((.has? self .type .sexp<-)
      (comma) (w ((.@ self .type .sexp<-) self)))
     ;;((.has? self .type) (print-class-object self (macro-writeenv-port we) (current-representation-options)))
     ((.has? self write-object) (.call self write-object we))
     ((.has? self sexp) (comma) (w (.@ self sexp)))
     ((.has? self .sexp) (comma) (w (.@ self .sexp)))
     (else (sn) (wr-fields)))))

(defstruct TV (type value) ;; Typed Value
  transparent: #t)
(defmethod (@method :wr TV)
  (lambda (self writeenv)
    (def style (writeenv-style writeenv))
    (def mark? (eq? style 'mark))
    (def (s x) (unless mark? (##wr-str writeenv x)))
    (def (w x) (##wr writeenv x))
    (with ((TV type value) self)
      (if (.has? type write-object)
        ;; write-object specializes :wr
        (let (f (cut (.@ type write-object) value writeenv))
          (case style
            ((mark) (w type) (f))
            ((display) (f))
            ((write write-shared pretty-print)
             (s ",(TV ") (w type) (s " ") (f) (s ")"))))
        (case style
          ((mark) (w type) (w value))
          ((display)
           (w type) (s ":")
           (cond
            ((.has? type .json<-) (s (json-string<- type value)))
            ((.has? type .string<-) (w (string<- type value)))
            ((.has? type .sexp<-) (s (object->string (sexp<- type value))))
            (else (s (object->string (sexp<- type value))))))
          ((write write-shared pretty-print)
           (cond
            ((.has? type .string<-) (s ",(TS ") (w type) (s " ") (w (string<- type value)) (s ")"))
            ((.has? type .sexp<-) (s ",(TV ") (w type) (s " ") (w (sexp<- type value)) (s ")"))
            ((.has? type .json<-) (s ",(TJ ") (w type) (s " ") (w (json-string<- type value)) (s ")"))
            (else (s "#") (w (object->serial-number self))
                  (s " #;(TV ") (w type) (s " ") (w value) (s ")")))))))))

(def (TS type json-string) (TS type (<-string type string)))
(def (TJ type json-string) (TV type (<-json-string type json-string)))
