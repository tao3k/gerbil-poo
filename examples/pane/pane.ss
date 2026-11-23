(export Pane InspectorPane Accessible render-pane)
(import (only-in :clan/poo/object .get)
        (only-in :clan/poo/number IntegerRange)
        (only-in :clan/poo/type String)
        (only-in :clan/poo/mop .defclass .defgeneric .defmethod
                 call-next-method))

(def Width (IntegerRange min: 20 max: 400))

(.defclass Pane ()
  ((label (initarg label:) (initform "Inspector") (type String))
   (width (initarg width:) (initform 80) (type Width))
   (decoration (initform 'plain))))

(.defclass Accessible ()
  ((description (initform "Object details") (type String))))

(.defclass InspectorPane (Pane Accessible)
  ((section (initform 'properties))))

(.defgeneric render-pane (pane target))

(.defmethod (render-pane (pane Pane) target)
  (list (.get pane label) (.get pane width)))

(.defmethod (render-pane (pane Pane) (target (eql 'terminal)))
  (cons 'terminal (call-next-method)))

(.defmethod (render-pane (pane InspectorPane) (target (eql 'terminal)))
  (append (call-next-method)
          (list (.get pane section) (.get pane description))))

(.defmethod (render-pane (pane Pane) target)
  (qualifier around)
  (cons (.get pane decoration) (call-next-method)))
