;;; Small list adapters required by the POO object model.

(export index-of alist<-plist pair-tree-for-each!)

(def (alist<-plist plist)
  (match plist
    ([key value . rest] (cons (cons key value) (alist<-plist rest)))
    ([] [])
    (_ (error "expected a proper property list" plist))))
(def (index-of xs x)
  (let loop ((xs xs) (index 0))
    (cond ((null? xs) #f)
          ((equal? x (car xs)) index)
          (else (loop (cdr xs) (1+ index))))))

(def (pair-tree-for-each! x f)
  (let loop ((x x))
    (match x
      ([head . tail] (loop head) (loop tail))
      ([] (void))
      (_ (f x)))))
