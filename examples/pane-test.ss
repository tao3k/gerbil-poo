(export pane-test)
(import (only-in :clan/poo/object .get)
        (only-in :clan/poo/mop clos-compose-method-bundle clos-make-instance
                 clos-reinitialize-instance clos-remove-method clos-change-class
                 clos-class-of clos-class-precedence-list clos-shared-initialize-generic)
        (only-in :std/test test-suite test-case check check-equal?)
        "./pane/pane.ss" "./pane/theme.ss")

(def pane-test
  (test-suite "Extend and migrate a pane across modules"
    (test-case "Compose an inspector with terminal rendering and a theme extension"
      (def shared clos-shared-initialize-generic)
      (check-equal? (render-pane (clos-make-instance Pane) 'terminal)
                    '(plain terminal "Inspector" 80))
      (dynamic-wind
        (lambda () (clos-compose-method-bundle shared pane-theme))
        (lambda ()
          (def pane (clos-make-instance Pane width: 120 theme: 'dark))
          (check-equal? (render-pane pane 'terminal) '(dark terminal "Inspector" 120))
          (clos-reinitialize-instance pane label: "Request trace" theme: 'light)
          (check (eq? (clos-change-class pane InspectorPane) pane) => #t)
          (check-equal? (render-pane pane 'terminal)
                        '(light terminal "Request trace" 120 properties "Object details"))
          (check-equal? (render-pane pane 'gui) '(light "Request trace" 120))
          (def precedence (clos-class-precedence-list (clos-class-of pane)))
          (check-equal? (list (car precedence) (cadr precedence) (caddr precedence))
                        (list InspectorPane Pane Accessible)))
        (lambda ()
          (for-each (lambda (method) (clos-remove-method shared method))
                    (.get pane-theme methods)))))))
