(export type-performance-test)

(import
  :std/format
  :std/iter
  :std/test
  ../object
  ../number
  ../type)

(def (scaled-sum variant-count)
  (def UInt8 (UIntN 8))
  (def tags
    (for/collect (tag-n (in-range variant-count))
      (string->symbol (format "variant-%d" tag-n))))
  (def variants
    (foldr (lambda (tag plist) [(make-keyword tag) UInt8 . plist]) [] tags))
  (values (apply Sum variants) tags))

(def (measure-cpu repetitions thunk)
  (def started (cpu-time))
  (for (_ (in-range repetitions)) (thunk))
  (- (cpu-time) started))

(def type-performance-test
  (test-suite "POO type performance receipts"
    (test-case "Sum uses the public bytes protocol at scale"
      (def variant-count 1024)
      (def repetitions 20000)
      (defvalues (ScaledSum tags) (scaled-sum variant-count))
      (def value (.call ScaledSum make (list-ref tags (1- variant-count)) 42))
      (def bytes (.call ScaledSum .bytes<- value))
      (def decoded (.call ScaledSum .<-bytes bytes))
      (check-equal? (.@ decoded tag) (.@ value tag))
      (check-equal? (.@ decoded value) (.@ value value))
      (def encode-seconds
        (measure-cpu repetitions (lambda () (.call ScaledSum .bytes<- value))))
      (def decode-seconds
        (measure-cpu repetitions (lambda () (.call ScaledSum .<-bytes bytes))))
      (displayln
       "SUM_TAG_PERFORMANCE_RECEIPT="
       [variants: variant-count
        repetitions: repetitions
        encode-cpu-seconds: encode-seconds
        decode-cpu-seconds: decode-seconds]))))
