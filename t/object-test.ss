(export
  object-test)

;; NB: For debugging, use (import :std/interactive)

(import
  :std/format :std/test
  ../support/base ../support/debug ../support/testing
  ../object ../brace)

(def object-test
  (test-suite "test suite for clan/poo/object"
    (test-case "V19 C4 preserves the C3 object precedence subset"
      (def root (.mix))
      (def left (.mix root))
      (def right (.mix root))
      (def diamond (.mix left right))
      (def (precedence-names precedence)
        (map (lambda (object)
               (cond ((eq? object diamond) 'diamond)
                     ((eq? object left) 'left)
                     ((eq? object right) 'right)
                     ((eq? object root) 'root)
                     (else 'unknown)))
             precedence))
      (check (precedence-names (compute-precedence-list! diamond))
             => '(diamond left right root))

      ;; This is the canonical C3 inconsistency: each intermediate object
      ;; requires the two roots in the opposite order.  C4 without suffix
      ;; objects must reject it exactly as C3 does.
      (def first (.mix))
      (def second (.mix))
      (def first-before-second (.mix first second))
      (def second-before-first (.mix second first))
      (def inconsistent (.mix first-before-second second-before-first))
      (check-exception (compute-precedence-list! inconsistent) true))
    (test-case "precedence cycle guard uses object identity"
      (def left (.mix))
      (def right (.mix left))
      (set! (object-supers left) [right])
      (check-exception (compute-precedence-list! left) true))
    (test-case "simple tests from poo.md"
      (check-equal? (object? (.o (x 1) (y 2))) #t)
      (check-equal? (object? 42) #f)
      (.def foo (x 1))
      (.def! foo y (x) (+ x 3))
      (check-equal? (.get foo y) 4)
      (.def bar (x 1))
      (check-equal? (.get bar x) 1)
      (.set! bar x 18)
      (check-equal? (.get bar x) 18)
      (check-equal? (.slot? foo 'y) #t)
      (check-equal? (.has? foo z) #f)
      (def (sort-symbols symbols) (list-sort (λ (a b) (string<? (symbol->string a) (symbol->string b))) symbols))
      (check-equal? (sort-symbols (.all-slots foo)) '(x y))
      (check-equal? (sort-symbols (.all-slots bar)) '(x))
      (def my-point (.o (x 3) (y 4)))
      (.def blued (color 'blue))
      (def my-colored-point (.mix blued my-point))
      (check-equal? (.ref my-colored-point 'x) 3)
      (check-equal? (.ref my-colored-point 'y) 4)
      (check-equal? (.ref my-colored-point 'color) 'blue)
      (check-equal? (.get my-colored-point x) (.ref my-colored-point 'x))
      (def complex (.o (:: @ [] x y) (x+iy (+ x (* 0+1i y)))))
      (.def (polar @ [] x+iy)
         (rho (magnitude x+iy)) (theta (angle x+iy)))
      (check-equal? (.get (.mix my-colored-point polar complex) rho) 5)
    (test-case "slot tests from poo.md"
      (let ((x 1) (y 2))
        (.def point (x) (y))
        (check-equal? (map (cut .ref point <>) '(x y)) [1 2]))
      (.def gerbil-config
        (modules => prepend '(gerbil gambit)))
      (def (prepend x y) (append y x))
      (.def base-config
        (modules '(kernel stdlib init)))
      (check-equal? (.get (.mix gerbil-config base-config) modules)
                     '(gerbil gambit kernel stdlib init))
      (.def (hello @ [] name)
        (language 'en)
        (greeting (format greeting-fmt name))
        (greeting-fmt "hello, ~a"))
      (.def (localize-hello @ [hello] language)
        (name "poo")
        (greeting-fmt (next) (if (eq? language 'fr) "salut, ~a" (next))))
      (.def (french-hello @ localize-hello)
        (language 'fr))
      (check-equal? (.get localize-hello greeting) "hello, poo")
      (check-equal? (.get french-hello greeting) "salut, poo")))
    (test-case "simple hello tests"
      (.def hello
        (name (error "Undefined"))
        (greeting (format "Hello, %a." name))
        (level 0))
      (.def (alice @ hello)
        (name "Alice")
        (level => + 1)
        (language 'english)
        (greeting (previous) (if (eq? language 'french) (format "Salut, %a." name) (previous))))
      (.def (bob @ alice greeting)
        (name "Bob")
        (level => + 1)
        (greet (λ () (displayln greeting))))
      (def french (.o (language 'french) (level => + 1)))
      (check-equal? (.get alice name) "Alice")
      (check-equal? (.get bob name) "Bob")
      (check-equal? (.get alice greeting) "Hello, Alice.")
      (check-equal? (.get hello level) 0)
      (check-equal? (.get alice level) 1)
      (check-equal? (.get bob level) 2)
      (check-equal? (.get (.mix french bob) level) 3)
      (check-equal? (with-output-to-string (λ () (.call bob greet))) "Hello, Bob.\n")
      (check-equal? (with-output-to-string (λ () (.call (.mix french bob) greet))) "Salut, Bob.\n"))
    (test-case "testing side-effects"
      (def foo (.o (x 6)))
      (.def! foo y (x) (* x 7))
      (.def (bar @ foo x y) (z (+ x 3)) (all [x y z]))
      (check-equal? (.get foo x) 6)
      (check-equal? (.get foo y) 42)
      (check-equal? (.get bar x) 6)
      (check-equal? (.get bar y) 42)
      (.set! bar x 1)
      (check-equal? (.get foo x) 6)
      (check-equal? (.get foo y) 42)
      (check-equal? (.get foo x) 6)
      (check-equal? (.get foo y) 42)
      (check-equal? (.get bar x) 1))
    (test-case "cached slots preserve false values"
      (def calls 0)
      (.def cached-false
        (value (begin
                 (set! calls (1+ calls))
                 #f)))
      (check-equal? (.get cached-false value) #f)
      (check-equal? (.get cached-false value) #f)
      (check-equal? calls 1))
    (test-case "keyword and brace syntax"
      (check-equal? 2 (.get (.o a: 1 b: (+ a 1)) b))
      (check-equal? 2 (.get {a: 1 b: (+ a 1)} b))
      (check-equal? 2 (let ((a 0)) (.get (.o a: 1 b: (+ a 1)) b))) ;; proper shadowing
      (check-equal? 2 (let ((a 0)) (.@ {a: 1 b: (+ a 1)} b)))) ;; proper shadowing
    (test-case "referring to another method"
      (def m (.o a: 1+ b: a c: ((lambda (aa) (lambda (x) (aa x))) a) d: (lambda (x) (a x))))
      (check-equal? (map (lambda (x) ((.ref m x) 2)) '(a b c d)) [3 3 3 3]))
    (test-case "nested object methods retain the outer lexical slot scope"
      (.def outer
        (outer-value 41)
        (inner {read: (lambda () outer-value)}))
      (check-equal? (.call (.@ outer inner) read) 41)
      (def (make-outer value)
        (.o (outer-value value)
            (inner {read: (lambda () outer-value)})))
      (check-equal? (.call (.@ (make-outer 7) inner) read) 7)
      (check-equal? (.call (.@ (make-outer 9) inner) read) 9)
      (def shadowed
        (.o (outer-value 41)
            (inner (.o (outer-value 7)
                       (read outer-value)))))
      (check-equal? (.@ (.@ shadowed inner) read) 7))
    (test-case "testing overrides"
      (def m (.o c: 3 b: 2 a: 1))
      (def n (.cc m b: 20 'c 30 d: 40))
      (check-equal? (.alist n) '((c . 30) (b . 20) (a . 1) (d . 40)))
      (check-equal? (.alist/sort n) '((a . 1) (b . 20) (c . 30) (d . 40))))
    (test-case "testing match"
      (def m {a: 1 b: 2 c: 3})
      (check-equal? [1 2 3]
                     (match m ({(a) (b) (c)} [a b c])))
      (def n {(m) d: 4})
      (check-equal? [4 1 3]
                     (match n ({d: a m: {a: c c: d}} [a c d])))
      (check-equal? 'nomatch
                     (match n ({d: {a: _} m: _} 'false-match) (_ 'nomatch))))
    (test-case "testing with-slots"
      (def o {a: 1 b: 2 c: 3})
      (check-equal? (with-slots (a b c) o [a b c]) [1 2 3]))
    (test-case "testing with-prefixed-slots"
      (def o {a: 1 b: 2 c: 3})
      (check-equal? (with-prefixed-slots (o- a) o [o-a]) [1])
      (check-equal? (with-prefixed-slots (o- a b c) o [o-a o-b o-c]) [1 2 3]))
    (test-case "testing def-slots"
      (def o {a: 1 b: 2 c: 3})
      (def-slots (a b c) o)
      (check-equal? [a b c] [1 2 3]))
    (test-case "testing def-prefixed-slots"
      (def o {a: 1 b: 2 c: 3})
      (def-prefixed-slots (o- a b c) o)
      (check-equal? [o-a o-b o-c] [1 2 3]))
    (test-case "testing put!"
      (.def o a: 1)
      (assert-equal! (.@ o a) 1)
      (check-exception (.@ o b) true)
      (.put! o 'a 2)
      (.put! o 'b 3)
      (assert-equal! (.@ o a) 2)
      (assert-equal! (.@ o b) 3)
      (def o2 (.mix o))
      (assert-equal! (.@ o2 a) 1)
      (check-exception (.@ o2 b) true))
    (test-case "testing set!"
      (.def o a: 1)
      (assert-equal! (.@ o a) 1)
      (.set! o a 2)
      (assert-equal! (.@ o a) 2))
    (test-case "testing putslot!"
      (.def o a: 1)
      (.def (p @ o) b: 2)
      (.putslot! o 'c ($constant-slot-spec 3))
      (.putslot! o 'd ($thunk-slot-spec (lambda () (+ 3 4))))
      (.putslot! p 'e ($self-slot-spec (lambda (self)
                                         (map (lambda (slot) (.ref self slot)) '(a b c d)))))
      (.putslot! p 'a ($computed-slot-spec (lambda (self superfun) (+ 1 (superfun)))))
      (assert-equal! (.@ p e) '(2 2 3 7)))
    (test-case "testing .+"
      (def o  (.+ {x: 1 y: 2} {z: 3}))
      (def o2 {x: 1 y: 2 z: 3})
      (assert-equal! (.@ o z) (.@ o2 z)))

    (test-case "testing slot definitions: (slot-name form)"
      (def o {x: 1 y: 2})
      (assert-equal! (.@ o x) 1)
      (assert-equal! (.@ o y) 2))

    (test-case "testing slot definitions: (slot-name => function-form extra-function-args ...)"
      (def p {x: 1})
      (def o {(:: @ p) x: => 1+ y: 3})
      (assert-equal! (.@ o y) 3)
      (assert-equal! (.@ o x) 2))

    (test-case "testing slot definitions: (slot-name =>.+ overriding-prototype)"
      (def p {x: {y: 1 z: 5}})
      (def o {(:: @ p) x: =>.+ {y: 2} })
      (assert-equal! (.@ (.@ o x) y) 2)
      (assert-equal! (.@ (.@ o x) z) 5))

    (test-case "testing slot definitions: (slot-name (inherited-computation) form)"
      (def (f) 1)
      (defrules use-f () (use-f (f)))
      (def o {x: f use-f})
      (assert-equal! ((.@ o x)) 1))

    (test-case "testing slot definitions: slot-name / (slot-name) -- lexical scope for objects"
      (def x 1)
      (def o {x})
      (assert-equal! (.@ o x) 1))

    (test-case "testing slot definitions: (slot-name ? default-value)"
      (def o {x: 1})
      (def o2 {(:: @ o) x: ? 2 y: ? 3})
      (assert-equal! (.@ o2 x) 1)
      (assert-equal! (.@ o2 y) 3))

    (test-case "testing single inheritance"
      (def o {x: 1})
      (def o2 {(:: @ o)})
      (assert-equal! (.@ o x) 1))

    (test-case "testing POO Definition Syntax: extra-slots"
      (def o {(:: @ [] y)
        x: y})
      (defrule (make-o-with val)
        {(:: @ [o]) y: val})
      (def i (make-o-with 1))
      (check-equal? (.@ i x) 1)
      (check-equal? (.@ i y) 1))

    (test-case "testing multiple inheritance"
      (def o {o: ? 0 x: => 1+ l: => (cut cons 'o <>)})
      (def a {(:: @ o) o: ? 1 y: 3 l: => (cut cons 'a <>)})
      (def b {(:: @ o) o: ? 2 x: => 1+ l: => (cut cons 'b <>)})
      (def f {(:: @ [a b]) l: ? '(f) x: ? 4})
      (check-equal? (.alist f) '((x . 6) (l a b o f) (o . 1) (y . 3))))))
