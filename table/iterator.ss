(defstruct %mapped-iterator (source transform guard) final: #t)
;; Pull through the standard Iterator exactly once; preserve EOF without mapping it.
(def (%mapped-next source transform)
  (using (source :- Iterator)
    (def value (source.next!))
    (if (eq? value #!eof) #!eof (transform value))))
(implement Iterator %mapped-iterator
  (next! (lambda (self)
    (if self.guard (self.guard (lambda () (%mapped-next self.source self.transform)))
      (%mapped-next self.source self.transform)))))

;; Optional guards cover the complete pull, even EOF. Ordinary iterator mapping
;; keeps its original unguarded path and allocates no per-pull guard thunk.
(def (iterator-map transform source (guard #f))
  (Iterator (%mapped-iterator (iter source) transform guard)))
