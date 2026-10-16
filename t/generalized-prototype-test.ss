(export generalized-prototype-test)
(import :std/test ../object (prefix-in ../generalized-prototype gp.)
        (prefix-in ../examples/generalized-checkout checkout.))
;; Exercise actual native protocols and failures; no injected compiled snapshots.
(def generalized-prototype-test
  (test-suite "generalized future-work hooks"
    (test-case "shared diamond and FUN observations preserve independent audit frame"
      (def snapshot (checkout.prepare-checkout))
      (check-equal? (length (gp.prepared-fragments snapshot)) 4)
      (check-equal? (checkout.report snapshot) '(30 33 3))
      (check-equal? (caddr (gp.approximate snapshot checkout.base '(a b untouched) 0)) 'untouched)
      (check-equal? (caddr (gp.approximate snapshot checkout.base checkout.base 3)) 'audit)
      (check-equal? (checkout.total snapshot 3) 33)
      (check-exception (checkout.total snapshot -1) true))
    (test-case "preparation compiles once and never runs a method body"
      (def compiled 0) (def invoked 0)
      (def protocol (.cc gp.Protocol. cook: identity compile:
        (lambda (fragment) (set! compiled (+ compiled 1))
          (lambda (_ parent) (set! invoked (+ invoked 1)) (+ fragment (parent))))))
      (def snapshot (gp.prepare protocol '(1 2 3)))
      (check-equal? compiled 3) (check-equal? invoked 0)
      (check-equal? (gp.observe snapshot 0 99 2) 6)
      (check-equal? compiled 3) (check-equal? invoked 6))
    (test-case "ignoring inherited suffix does not force it and exceptions stop FUN bind"
      (def protocol (.cc gp.Protocol. cook: identity compile: identity))
      (def snapshot (gp.prepare protocol
        (list (lambda (_ parent) 7) (lambda _ (error "must stay delayed")))))
      (check-equal? (gp.step snapshot 0 0) 7)
      (def reached #f)
      (def action ((.@ gp.Observation. .bind)
        (lambda (_) (error "source hook failure"))
        (lambda (_) (set! reached #t) (.@ gp.Observation. .ap))))
      (check-exception (action 0) true) (check-equal? reached #f))
    (test-case "compatible public self extension preserves finite construction"
      (def protocol (gp.reindex-self checkout.protocol car
        (lambda (raw) (cons ((.@ checkout.protocol cook) raw) 'metadata))))
      (def snapshot (gp.prepare-inheritance protocol checkout.root checkout.declarations))
      (check-equal? ((car (gp.observe snapshot checkout.base checkout.base 2)) 'price) 33)
      (check-equal? (cdr (gp.observe snapshot checkout.base checkout.base 2)) 'metadata)
      (check-exception ((gp.sum-compiler identity identity) '(unknown . value)) true))
    (test-case "native C3 inconsistency is retained before fragment compilation"
      (def x (.o)) (def y (.o))
      (def xy (.mix x y)) (def yx (.mix y x))
      (def bad (.mix xy yx))
      (def reached #f)
      (check-exception (gp.prepare-inheritance checkout.protocol bad
        (lambda (_) (set! reached #t) [])) true)
      (check-equal? reached #f))))
