(export public-api-test)
(import (only-in :std/test test-suite test-case)
        (only-in :clan/poo/object .o .mix .get)
        (only-in :clan/poo/mop clos-class clos-direct-slot-definition
                 clos-make-instance clos-reinitialize-instance clos-slot-value)
        (only-in :clan/poo/io bytes<- <-bytes marshal)
        (only-in :clan/poo/type List OrFalse Tuple)
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

(def public-api-test
  (test-suite "Properties of the public POO APIs"
    (test-case "Prototype overlays preserve precedence and inherited slots"
      (overlay-precedence seed: 17 cases: 64 size: 8))
    (test-case "Reconfiguration uses the first alias and preserves the untouched slot"
      (reconfigure-quota seed: 29 cases: 64 size: 8))
    (test-case "Typed packet encoding matches field order and round trips"
      (packet-wire-order seed: 43 cases: 64 size: 8))))
