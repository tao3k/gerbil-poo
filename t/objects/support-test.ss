(export support-test)

(import :std/test
        (only-in :clan/poo/support/object-syntax deduplicate-slot-identifiers)
        (for-syntax (only-in :std/list/list delete-duplicates/hash))
        :clan/poo/support/io
        :clan/poo/support/repr)

(def (roundtrip writer reader value)
  (def bytes
    (call-with-output-u8vector
     (lambda (port) (writer value port))))
  (call-with-input-u8vector bytes reader))

(def support-test
  (test-suite "test suite for clan/poo support"
    ;; Keep suite-private expansion helpers out of the published interface.
    ;; Compare actual compiler-table output with the former constant-hash oracle.
    ;; Same-name identifiers from distinct macro marks must remain separate entries.
    (defsyntax (slot-identifier-control stx)
      (def first #'shared)
      (def scoped (syntax-local-introduce first))
      (when (bound-identifier=? first scoped)
        (error "control must contain distinct hygienic identifiers"))
      (def wide (map (lambda (index)
        (datum->syntax (stx-car stx) (string->symbol (string-append "field-" (number->string index)))))
        (iota 256)))
      (def input (append (list first scoped first scoped) wide wide))
      (def expected (delete-duplicates/hash input
        table: (make-hash-table test: bound-identifier=? hash: (lambda (_) 0)) from-end?: #t))
      (def actual (deduplicate-slot-identifiers input))
      (unless (and (= (length actual) 258) (andmap eq? actual expected)
                   (eq? (car actual) first) (eq? (cadr actual) scoped))
        (error "slot identifier ordering, identity or hygiene changed"))
      (datum->syntax (stx-car stx) (list 'quote (length actual))))
    (test-case "compiler identifier table preserves first syntax identity and distinct scopes"
      (check-equal? (slot-identifier-control) 258))
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
