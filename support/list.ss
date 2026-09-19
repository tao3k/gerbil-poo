;;; Small list adapters required by the POO object model.

(export pair-tree-for-each!)

(def (pair-tree-for-each! x f)
  (let loop ((x x))
    (match x
      ([head . tail] (loop head) (loop tail))
      ([] (void))
      (_ (f x)))))
