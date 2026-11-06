;;; Module-level standard HashTable test fixture; no separate runtime module.
;; A test-only standard HashTable delegate exposes legal source enumeration
;; effects. All other methods retain the standard backing table implementation.
(defstruct seed-input (table before))
(for ([method . operation]
      (list (cons 'HashTable::ref hash-ref) (cons 'HashTable::set! hash-put!)
            (cons 'HashTable::update! hash-update!) (cons 'HashTable::delete! hash-remove!)
            (cons 'HashTable::copy hash-copy) (cons 'HashTable::clear! hash-clear!)
            (cons 'HashTable::length hash-length)
            (cons 'HashTable::new (lambda (_table (size #f)) (make-hash-table size: (or size 0))))))
  (bind-method! seed-input::t method
    (lambda (self . arguments) (apply operation (seed-input-table self) arguments))))
;; Only enumeration is effectful; the official interface owns dispatch and errors.
(bind-method! seed-input::t 'HashTable::for-each
  (lambda (self consume)
    ((seed-input-before self))
    (hash-for-each consume (seed-input-table self))))

