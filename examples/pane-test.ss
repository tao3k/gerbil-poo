(export pane-test)
(import (only-in :clan/poo/object .get)
        (only-in :clan/poo/mop clos-compose-method-bundle clos-make-instance
                 clos-reinitialize-instance clos-remove-method
                 clos-shared-initialize-generic clos-slot-value)
        (only-in :std/test test-suite test-case check-equal?)
        "./pane/pane.ss" "./pane/theme.ss")

(def pane-test
  (test-suite "Pane extension"
    (test-case "An independent theme module extends creation and reconfiguration"
      (def shared clos-shared-initialize-generic)
      (check-equal? (clos-slot-value (clos-make-instance Pane) 'decoration) 'plain)
      (dynamic-wind
        (lambda () (clos-compose-method-bundle shared pane-theme))
        (lambda ()
          (def pane (clos-make-instance Pane width: 120 theme: 'dark))
          (check-equal? (clos-slot-value pane 'decoration) 'dark)
          (clos-reinitialize-instance pane theme: 'light)
          (check-equal? (clos-slot-value pane 'decoration) 'light)
          (check-equal? (clos-slot-value pane 'width) 120))
        (lambda ()
          (for-each (lambda (method) (clos-remove-method shared method))
                    (.get pane-theme methods)))))))
