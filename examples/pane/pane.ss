(export Pane InspectorPane Accessible ResizeEvent SelectSection render-pane handle-pane-event)
(import (only-in :clan/poo/object .get)
        (only-in :clan/poo/number Integer IntegerRange)
        (only-in :clan/poo/type String Symbol)
        (only-in :clan/poo/mop .defclass .defgeneric .defmethod
                 call-next-method clos-reinitialize-instance))

(def Width (IntegerRange min: 20 max: 400))

(.defclass Pane ()
  ((label (initarg label:) (initform "Inspector") (type String))
   (width (initarg width:) (initform 80) (type Width))
   (decoration (initform 'plain))))

(.defclass Accessible ()
  ((description (initform "Object details") (type String))))

(.defclass InspectorPane (Pane Accessible)
  ((section (initarg section:) (initform 'properties) (type Symbol))))

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

(.defclass ResizeEvent ()
  ((requested-width (initarg width:) (type Integer))))

(.defclass SelectSection ()
  ((selected-section (initarg section:) (type Symbol))))

(.defgeneric handle-pane-event (pane event))

(.defmethod (handle-pane-event (pane Pane) (event ResizeEvent))
  (clos-reinitialize-instance pane width: (.get event requested-width))
  (render-pane pane 'terminal))

(.defmethod (handle-pane-event (pane InspectorPane) (event SelectSection))
  (clos-reinitialize-instance pane section: (.get event selected-section))
  (render-pane pane 'terminal))
