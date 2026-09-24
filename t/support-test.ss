(export support-test)

(import :std/test
        ../support/io
        ../support/repr)

(def (roundtrip writer reader value)
  (def bytes
    (call-with-output-u8vector
     (lambda (port) (writer value port))))
  (call-with-input-u8vector bytes reader))

(def support-test
  (test-suite "test suite for clan/poo support"
    (test-case "signed varints round-trip across byte boundaries"
      (check (roundtrip write-varint read-varint -65) => -65)
      (def large-negative (- (arithmetic-shift 1 512)))
      (check (roundtrip write-varint read-varint large-negative)
             => large-negative))
    (test-case "extended unsigned varint lengths use the unsigned codec"
      (def large-unsigned (arithmetic-shift 1 1024))
      (check (roundtrip write-varuint read-varuint large-unsigned)
             => large-unsigned))
    (test-case "source representation preserves dotted tails"
      (check (repr (cons 1 2)) => "[1 . 2]"))))
