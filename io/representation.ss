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
