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
