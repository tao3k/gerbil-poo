;;; Generic forwarding reuses core lambda bindings and standard keyword encoding.
(export (for-syntax call<-formals))
(import (for-syntax (only-in :std/list/plist alist->plist)))

(begin-syntax
  ;; Keep only the bound identifier. Core lambda owns optional/default admission;
  ;; forwarding must neither reevaluate defaults nor reconstruct their expressions.
  (def (parse-formal formal)
    (syntax-case formal ()
      (_ (identifier? formal) formal)
      ((name default) (identifier? #'name) #'name)
      (_ (error "Invalid formal parameter" formal))))
  ;; Separate supplied binding categories without inventing another lambda grammar.
  ;; The enclosing core lambda still checks ordering, duplicates and keyword rules.
  (def (parse-formals formals)
    (let loop ((formals formals) (positionals []) (keywords []))
      (syntax-case formals ()
        (rest (identifier? #'rest) (values (reverse positionals) (reverse keywords) #'rest))
        (() (values (reverse positionals) (reverse keywords) #f))
        ((keyword value . more) (stx-keyword? #'keyword)
         (loop #'more positionals (cons (cons #'keyword (parse-formal #'value)) keywords)))
        ((value . more) (loop #'more (cons (parse-formal #'value) positionals) keywords))
        (_ (error "Invalid formals" formals)))))
  ;; Keywords precede the core #!rest escape; every remaining value is positional,
  ;; including keyword-valued receivers/arguments and keyword tokens in rest data.
  ;; The target receives the resolved bindings once; apply is used only for rest.
  (def (call<-formals prefix formals)
    (defvalues (positionals keywords rest) (parse-formals formals))
    (with-syntax (((target leading ...) prefix)
                  ((keyword ...) (alist->plist keywords))
                  ((positional ...) positionals)
                  ((escape ...) (if (pair? keywords) #'(#!rest) []))
                  ((tail ...) (if rest [rest] []))
                  ((apply* ...) (if rest #'(apply) [])))
      #'(apply* ... target keyword ... escape ... leading ... positional ... tail ...))))
