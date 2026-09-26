(export tuple-unmarshal-performance-test)

(import :std/iter :std/test ../object ../number ../type)

(def (measure-cpu count thunk)
  (def started (cpu-time))
  (for (_ (in-range count)) (thunk))
  (- (cpu-time) started))

(def tuple-unmarshal-performance-test
  (test-suite "tuple unmarshal performance"
    (test-case "wide tuple bytes round trip"
      (def width 256)
      (def repetitions 1000)
      (def UInt8 (UIntN 8))
      (def tuple-type (apply Tuple (for/collect (_ (in-range width)) UInt8)))
      (def value (list->vector (for/collect (i (in-range width)) (modulo i 256))))
      (def bytes (.call tuple-type .bytes<- value))
      (check-equal? (.call tuple-type .<-bytes bytes) value)
      (measure-cpu 30 (lambda () (.call tuple-type .<-bytes bytes)))
      (def samples
        (for/collect (_ (in-range 5))
          (measure-cpu repetitions (lambda () (.call tuple-type .<-bytes bytes)))))
      (displayln "TUPLE_UNMARSHAL_PERFORMANCE_RECEIPT="
                 [width: width repetitions: repetitions samples: samples]))))
