(export Pane)
(import (only-in :clan/poo/mop .defclass))

(.defclass Pane ()
  ((width (initarg width:) (initform 80))
   (decoration (initform 'plain))))
