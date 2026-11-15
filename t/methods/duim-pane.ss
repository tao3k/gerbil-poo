;;; -*- Gerbil -*-
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

(import :clan/poo/mop)
(export Gadget Pane InspectorPane)

(.defclass Gadget ()
  ((label (initarg label:) (initform 'untitled))))

(.defclass Pane (Gadget)
  ((width (initarg width:) (initform 80))
   (decoration (initform 'plain)))
  (default-initargs (label: 'pane)))

(.defclass InspectorPane (Pane)
  ((side (initform 'right))))
