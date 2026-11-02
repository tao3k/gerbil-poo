;;; End-to-end Class.proto construction through the public POO slot dispatch.

(import :clan/poo/object
        :clan/poo/mop
        :std/format
        :std/iter
        (only-in :std/list/list-builder with-list-builder)
        :std/time/time)
(export main)

;; Reject invalid workload sizes before allocating any slot descriptors.
(def (required-positive-integer text)
  (let (value (string->number text))
    (unless (and (exact-integer? value) (positive? value))
      (error "invalid benchmark input" text value))
    value))

;; Use deterministic field names for equal-width construction controls.
(def (slot-name index)
  (string->symbol (format "slot-%d" index)))

;; Build the workload through the project's object and list-builder protocols.
(def (class-slots width)
  (object<-alist
   (with-list-builder (add)
     (for (index (in-range width))
       (add (cons (slot-name index)
                  (object<-alist (list (cons 'constant index)))))))))

;; Derive each measured class from the existing Class metaobject.
(def (class-with-slots slots)
  (object<-alist (list (cons 'slots slots)) supers: [Class.]))

;; Read the wall clock used by this benchmark.
(def (now-seconds)
  (InexactTime-time (current-time-inexact)))

;; Explicit arguments define the workload without hidden environment settings.
(def (main width-text samples-text)
  (def width (required-positive-integer width-text))
  (def samples (required-positive-integer samples-text))
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
