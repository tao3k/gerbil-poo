#!/usr/bin/env gxi
;;; End-to-end Class.proto construction through the public POO slot dispatch.

(import :clan/poo/object
        :clan/poo/mop
        :std/format
        :std/iter
        (only-in :std/list/list-builder with-list-builder)
        :std/time/time)
(export main)

(def (required-positive-integer name)
  (let (value (and (getenv name) (string->number (getenv name))))
    (unless (and (exact-integer? value) (positive? value))
      (error "invalid benchmark input" name value))
    value))

(def (slot-name index)
  (string->symbol (format "slot-%d" index)))

(def (class-slots width)
  (object<-alist
   (with-list-builder (add)
     (for (index (in-range width))
       (add (cons (slot-name index)
                  (object<-alist (list (cons 'constant index)))))))))

(def (class-with-slots slots)
  (object<-alist (list (cons 'slots slots)) supers: [Class.]))

(def (now-seconds)
  (InexactTime-time (current-time-inexact)))

(def (main . _)
  (def width (required-positive-integer "POO_SLOT_BENCH_WIDTH"))
  (def samples (required-positive-integer "POO_SLOT_BENCH_SAMPLES"))
  (def slots (class-slots width))
  (for (index (in-range samples))
    (def class (class-with-slots slots))
    (def start (now-seconds))
    (def proto (.ref class 'proto))
    (def elapsed (- (now-seconds) start))
    (unless (= (length (.all-slots proto)) width)
      (error "wrong prototype width" width))
    (displayln "CLASS_PROTO_SAMPLE=" (1+ index) "/" samples
               " wall-seconds=" elapsed)
    (force-output)))
