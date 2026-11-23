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
