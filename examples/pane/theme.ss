(export pane-theme)
(import (only-in :clan/poo/object .get)
        (only-in :clan/poo/mop .defmethod .defmethod-bundle
                 clos-shared-initialize-generic clos-set-slot-value!)
        "./pane.ss")

(.defmethod-bundle pane-theme (.get clos-shared-initialize-generic protocol)
  (.defmethod (shared-initialize (pane Pane) slots &key ((theme: theme) #f theme?))
    (qualifier after)
    (when theme? (clos-set-slot-value! pane 'decoration theme))))
