;;; Source-oriented representation retained by gerbil-poo after V19 removed std/repr.

(export default-representation-options current-representation-options
        display-separated print-representation pr prn repr)

(def default-representation-options (make-hash-table))
(def current-representation-options (make-parameter default-representation-options))

(def (display-separated values (port (current-output-port))
                        prefix: (prefix "") separate-prefix?: (separate? #f)
                        separator: (separator " ") suffix: (suffix "")
                        display-element: (display-element display))
  (display prefix port)
  (let loop ((values values) (separate? separate?))
    (match values
      ([value . rest]
       (when separate? (display separator port))
       (display-element value port)
       (loop rest #t))
      (_ (void))))
  (display suffix port))

(def (print-representation value (port (current-output-port))
                           (options (current-representation-options)))
  (def (recur value port) (print-representation value port options))
  (cond
   ((or (number? value) (boolean? value) (string? value) (char? value)
        (void? value) (keyword? value) (eof-object? value))
    (write value port))
   ((symbol? value) (display "'" port) (write value port))
   ((null? value) (display "[]" port))
   ((pair? value)
    (display-separated value port prefix: "[" suffix: "]" display-element: recur))
   ((vector? value)
    (display-separated (vector->list value) port prefix: "(vector"
                       separate-prefix?: #t suffix: ")" display-element: recur))
   ((u8vector? value)
    (display-separated (u8vector->list value) port prefix: "#u8(" suffix: ")"))
   ((and (procedure? value) (##procedure-name value)) => (cut display <> port))
   ((method-ref value ':pr) => (lambda (method) (method value port options)))
   (else (write value port))))

(defalias pr print-representation)
(def (prn value (port (current-output-port)) (options (current-representation-options)))
  (pr value port options) (newline port))
(def (repr value (options (current-representation-options)))
  (call-with-output-string [] (lambda (port) (pr value port options))))
