;;; Standard port and Reader/Writer admission, with FUN transfer/retry controls.
(export io-test)
(import :std/test :std/error :std/iter
        (prefix-in :clan/poo/io io.)
        (only-in :clan/poo/object .o)
        (only-in :clan/poo/examples/byte-io copy-bytes-action))

;; Count only actual reads; the underlying standard port owns byte transport.
(defstruct counted-reader (port calls) final: #t)
;; Implement the official Reader method, including its minimum-input obligation.
(defmethod {read counted-reader}
  (lambda (self bytes start end need)
    (set! (counted-reader-calls self) (1+ (counted-reader-calls self)))
    (def n (read-subu8vector bytes start end (counted-reader-port self) (max 1 need)))
    (when (< n need) (raise-premature-end-of-input 'counted-reader)) n))
;; The caller remains responsible for closing its standard interface.
(defmethod {close counted-reader} (lambda (self) (close-input-port (counted-reader-port self))))
;; Count writes without adding a buffer, registry or transport implementation.
(defstruct counted-writer (port calls) final: #t)
;; Official Writer operations write the complete span or propagate the port error.
(defmethod {write counted-writer}
  (lambda (self bytes start end)
    (set! (counted-writer-calls self) (1+ (counted-writer-calls self)))
    (write-subu8vector bytes start end (counted-writer-port self))))
;; Closing is explicit, not an implicit consequence of the POO operation.
(defmethod {close counted-writer} (lambda (self) (close-output-port (counted-writer-port self))))
;; A valid standard interface may raise any host cause, including false.
(defstruct refusing-stream (cause) final: #t)
;; Preserve exact reader exception identity through the public operation.
(defmethod {read refusing-stream} (lambda (self _bytes _start _end _need) (raise (refusing-stream-cause self))))
;; Preserve exact writer exception identity through the public operation.
(defmethod {write refusing-stream} (lambda (self _bytes _start _end) (raise (refusing-stream-cause self))))
;; This fixture owns no external resource.
(defmethod {close refusing-stream} (lambda (_) (void)))

(def io-test
  (test-suite "byte I/O"
    (test-case "byte input uses the supplied standard port"
      (def input (open-input-u8vector #u8(7)))
      (check-equal? (io.object-read-byte input) 7)
      (check (io.object-read-byte input) ? eof-object?))
    (test-case "byte output uses the supplied standard port"
      (def target (open-output-u8vector))
      (io.object-write-byte 9 target)
      (check-equal? (get-output-u8vector target) #u8(9)))
    (test-case "bulk input honors the requested buffer offset"
      (def buffer (u8vector 90 90 90 90))
      (def input (open-input-u8vector #u8(1 2)))
      (check-equal? (io.read-bytes-into buffer input offset: 1 length: 2 need: 2) 2)
      (check-equal? buffer #u8(90 1 2 90)))
    (test-case "exact input and bulk output keep public argument order"
      (def target (open-output-u8vector))
      (def bytes (io.object-read-bytes 3 (open-input-u8vector #u8(4 5 6))))
      (io.object-write-bytes bytes target offset: 1 length: 2)
      (check-equal? (get-output-u8vector target) #u8(5 6)))
    (test-case "partial reads return counts and retain untouched buffer suffixes"
      (def buffer (make-u8vector 4 90)) (def input (open-input-u8vector #u8(7)))
      (check-equal? (io.read-bytes-into buffer input offset: 1 length: 3) 1)
      (check-equal? buffer #u8(90 7 90 90))
      (check-equal? (io.read-bytes-into buffer input offset: 1 length: 3) 0)
      (check-equal? buffer #u8(90 7 90 90)))
    (test-case "exact reads report standard premature EOF"
      (check-exception (io.object-read-bytes 2 (open-input-u8vector #u8(7))) io-error?)
      (check-exception (io.object-read-bytes 1 (open-input-u8vector #u8())) io-error?))
    (test-case "non-port sources use the official Reader and Writer method contracts"
      (def source (make-counted-reader (open-input-u8vector #u8(1 2 3)) 0))
      (def port (open-output-u8vector)) (def sink (make-counted-writer port 0))
      (check-equal? (io.object-read-byte source) 1)
      (io.object-write-byte 8 sink)
      (io.object-write-bytes (io.object-read-bytes 2 source) sink)
      (check-equal? (get-output-u8vector port) #u8(8 2 3))
      (check (io.object-read-byte source) ? eof-object?)
      (check-equal? (counted-writer-calls sink) 2))
    (test-case "zero-length spans admit standard interfaces without read or write effects"
      (def source (make-counted-reader (open-input-u8vector #u8(1)) 0))
      (def port (open-output-u8vector)) (def sink (make-counted-writer port 0))
      (check-equal? (io.read-bytes-into #u8() source) 0)
      (check-equal? (io.object-read-bytes 0 source) #u8())
      (io.object-write-bytes #u8() sink)
      (io.object-write-bytes #u8(1) sink offset: 1 length: 0)
      (check-equal? (list (counted-reader-calls source) (counted-writer-calls sink)) '(0 0))
      (check-equal? (get-output-u8vector port) #u8()))
    (test-case "invalid ranges and minimum counts refuse before stream effects"
      (def source (make-counted-reader (open-input-u8vector #u8(1 2 3)) 0))
      (def sink (make-counted-writer (open-output-u8vector) 0))
      (for (row '((-1 1) (4 0) (0 4) (1 -1) (1/2 1)))
        (check-exception (io.read-bytes-into #u8(0 0 0) source offset: (car row) length: (cadr row)) contract-violation-error?)
        (check-exception (io.object-write-bytes #u8(0 0 0) sink offset: (car row) length: (cadr row)) contract-violation-error?))
      (for (need '(-1 4 1/2))
        (check-exception (io.read-bytes-into #u8(0 0 0) source need: need) contract-violation-error?))
      (check-exception (io.object-read-bytes -1 source) contract-violation-error?)
      (check-equal? (list (counted-reader-calls source) (counted-writer-calls sink)) '(0 0)))
    (test-case "Reader and Writer failures retain opaque cause identity"
      (for (cause (list #f (cons 'transport 'cause)))
        (def endpoint (make-refusing-stream cause))
        (check-eq? (with-catch values (lambda () (io.object-read-byte endpoint))) cause)
        (check-eq? (with-catch values (lambda () (io.object-read-bytes 2 endpoint))) cause)
        (check-eq? (with-catch values (lambda () (io.object-write-byte 7 endpoint))) cause)
        (check-eq? (with-catch values (lambda () (io.object-write-bytes #u8(1 2) endpoint))) cause)))
    (test-case "FUN bounded transfer stops before output on EOF and retries with fresh endpoints"
      (def action (copy-bytes-action 2)) (def old-output (open-output-u8vector))
      (check-exception (action (.o input: (open-input-u8vector #u8(7)) output: old-output)) io-error?)
      (check-equal? (get-output-u8vector old-output) #u8())
      (def target (open-output-u8vector))
      (check-equal? (action (.o input: (make-counted-reader (open-input-u8vector #u8(8 9)) 0)
                              output: (make-counted-writer target 0))) #u8(8 9))
      (check-equal? (get-output-u8vector target) #u8(8 9)))
    (test-case "FUN output failures propagate without caching the previous read"
      (def action (copy-bytes-action 2)) (def cause (cons 'write 'failure))
      (check-eq? (with-catch values (lambda () (action (.o input: (open-input-u8vector #u8(1 2))
        output: (make-refusing-stream cause))))) cause)
      (def target (open-output-u8vector))
      (check-equal? (action (.o input: (open-input-u8vector #u8(3 4)) output: target)) #u8(3 4))
      (check-equal? (get-output-u8vector target) #u8(3 4)))))
