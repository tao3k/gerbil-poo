(export tuple-json-performance-test)

(import :std/iter :std/test ../object ../number ../type)

(def (measure-cpu count thunk)
  (def started (cpu-time))
  (for (_ (in-range count)) (thunk))
  (- (cpu-time) started))

(def tuple-json-performance-test
  (test-suite "tuple JSON performance"
    (test-case "wide tuple JSON round trip"
      (def width 256)
      (def repetitions 10000)
      (def UInt8 (UIntN 8))
      (def tuple-type (apply Tuple (for/collect (_ (in-range width)) UInt8)))
      (def value (list->vector (for/collect (i (in-range width)) (modulo i 256))))
      (def json (.call tuple-type .json<- value))
      (check-equal? (.call tuple-type .<-json json) value)
      (measure-cpu 30 (lambda () (.call tuple-type .json<- value)))
      (measure-cpu 30 (lambda () (.call tuple-type .<-json json)))
      (def encode-samples
        (for/collect (_ (in-range 5))
          (measure-cpu repetitions (lambda () (.call tuple-type .json<- value)))))
      (def decode-samples
        (for/collect (_ (in-range 5))
          (measure-cpu repetitions (lambda () (.call tuple-type .<-json json)))))
      (displayln "TUPLE_JSON_PERFORMANCE_RECEIPT="
                 [width: width repetitions: repetitions
                  encode-samples: encode-samples decode-samples: decode-samples]))))
