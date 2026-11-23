(export public-api-test)
(import (only-in :std/error Error? Error-message)
        (only-in :std/test test-suite test-case)
        (only-in :clan/poo/object .o .mix .get .setslot!
                 $constant-slot-spec object-read-current?)
        (only-in :clan/poo/mop clos-class clos-direct-slot-definition
                 clos-make-instance clos-reinitialize-instance clos-slot-value
                 call-with-slot-read-observer slot-read-key slot-read-receiver replay-slot-reads!)
        (only-in :clan/poo/io bytes<- <-bytes marshal)
        (only-in :clan/poo/type Bool List OrFalse Tuple)
        (only-in :clan/poo/number UInt)
        (prefix-in :clan/poo/support/testing pbt.))

(def OptionalQuota (OrFalse UInt))

(def (quota-overlay? base regional tenant regional? tenant?)
  (def defaults (.o quota: base route: 'default))
  (def config (.mix (if tenant? (.o quota: tenant) (.o))
                    (if regional? (.o quota: regional) (.o))
                    defaults))
  (and (equal? (.get config quota)
               (cond (tenant? tenant) (regional? regional) (else base)))
       (eq? (.get config route) 'default)
       (equal? (.get defaults quota) base)))

(pbt.define-property overlay-precedence
    ((base OptionalQuota) (regional OptionalQuota) (tenant OptionalQuota))
  (and (quota-overlay? base regional tenant #f #f)
       (quota-overlay? base regional tenant #t #f)
       (quota-overlay? base regional tenant #f #t)
       (quota-overlay? base regional tenant #t #t)))

(def LimitPolicy
  (clos-class 'LimitPolicy
    direct-slots:
    (list (clos-direct-slot-definition 'quota initargs: (list quota: limit:) type: UInt)
          (clos-direct-slot-definition 'window initargs: (list window:) type: UInt))))

(pbt.define-property reconfigure-quota
    ((initial UInt) (first UInt) (second UInt) (window UInt))
  (def rule (clos-make-instance LimitPolicy quota: initial window: window))
  (and (eq? (clos-reinitialize-instance rule quota: first limit: second) rule)
       (= (clos-slot-value rule 'quota) first)
       (eq? (clos-reinitialize-instance rule limit: second quota: first) rule)
       (= (clos-slot-value rule 'quota) second)
       (= (clos-slot-value rule 'window) window)))

(def Payload (List OptionalQuota))
(def Packet (Tuple UInt Payload UInt))

(pbt.define-property packet-wire-order
    ((first UInt) (payload Payload) (last UInt))
  (def value (vector first payload last))
  (def encoded (bytes<- Packet value))
  (def field-stream
    (call-with-output-u8vector
      (lambda (port)
        (marshal UInt first port)
        (marshal Payload payload port)
        (marshal UInt last port))))
  (and (equal? encoded field-stream)
       (equal? (<-bytes Packet encoded) value)))

(def Edit (Tuple Bool OptionalQuota))

(def (capture-quota receiver)
  (def read #f)
  (def value
    (call-with-slot-read-observer
      (lambda (record)
        (when (and (eq? (slot-read-receiver record) receiver)
                   (eq? (slot-read-key record) 'quota))
          (set! read record)))
      (lambda () (.get receiver quota))))
  (values value read))

(def (replay-matches? receiver read current?)
  (def delivered 0)
  (def quota-reads 0)
  (def result
    (with-catch values
      (lambda ()
        (replay-slot-reads! (list read)
          (lambda (owner key)
            (set! delivered (+ delivered 1))
            (when (and (eq? owner receiver) (eq? key 'quota))
              (set! quota-reads (+ quota-reads 1)))))
        #t)))
  (and (eq? (object-read-current? read) current?)
       (if current?
         (and (eq? result #t) (= quota-reads 1))
         (and (Error? result)
              (equal? (Error-message result) "stale slot dependency")
              (zero? delivered)))))

(pbt.define-property inherited-quota-replay
    ((source-value OptionalQuota) (peer-value OptionalQuota) (generated (List Edit)))
  (def source (.o quota: source-value))
  (def consumer (.o inherit: [source]))
  (def peer (.o quota: peer-value))
  ;; Both owners are edited even when shrinking removes the generated suffix.
  (let loop ((edits (cons (vector #t source-value)
                         (cons (vector #f peer-value) generated)))
             (expected-source source-value)
             (expected-peer peer-value))
    (if (null? edits)
      (and (equal? (.get consumer quota) expected-source)
           (equal? (.get peer quota) expected-peer))
      (let (edit (car edits))
        (def source? (vector-ref edit 0))
        (def new-value (vector-ref edit 1))
        (defvalues (old-source source-read) (capture-quota consumer))
        (defvalues (old-peer peer-read) (capture-quota peer))
        (.setslot! (if source? source peer) quota ($constant-slot-spec new-value))
        (and source-read peer-read
             (equal? old-source expected-source)
             (equal? old-peer expected-peer)
             (replay-matches? consumer source-read (not source?))
             (replay-matches? peer peer-read source?)
             (loop (cdr edits)
                   (if source? new-value expected-source)
                   (if source? expected-peer new-value)))))))

(def public-api-test
  (test-suite "Properties of the public POO APIs"
    (test-case "Prototype overlays preserve precedence and inherited slots"
      (overlay-precedence seed: 17 cases: 64 size: 8))
    (test-case "Reconfiguration uses the first alias and preserves the untouched slot"
      (reconfigure-quota seed: 29 cases: 64 size: 8))
    (test-case "Typed packet encoding matches field order and round trips"
      (packet-wire-order seed: 43 cases: 64 size: 8))
    (test-case "Only reads affected by an edit become stale"
      (inherited-quota-replay seed: 57 cases: 64 size: 8))))
