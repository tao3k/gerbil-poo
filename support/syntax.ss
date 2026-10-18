;;; Generic forwarding reuses core lambda bindings and standard keyword encoding.
(export (for-syntax call<-formals))
(import (only-in :gerbil/core signature-arguments-out)
        (for-syntax (only-in :std/list/plist alist->plist)
                    (only-in :gerbil/core keyword-dispatch symbolic-table-ref)))

(begin-syntax
  ;; Delegate the complete formal grammar/projection and keyword split to core.
  ;; Defaults and predicate contracts stay in the enclosing core definition; only
  ;; already bound identifiers enter this syntax-only expansion-time dispatcher.
  ;; Its private mapped spine may be rewritten by keyword-dispatch. Preserve the
  ;; source keyword order separately; table enumeration would change call syntax.
  ;; POO adds only its leading receiver and #!rest escape: keyword-valued positional
  ;; data stays positional, no runtime parser is added, and apply is used for rest.
  (def (call<-formals prefix formals (row? #f))
    (defvalues (head rest) (syntax-split-splice formals 0))
    (unless (or (stx-null? rest) (identifier? rest)) (error "Invalid formals" formals))
    (def bound (signature-arguments-out head))
    ;; The core projection may return a recognized prefix for unsupported syntax.
    ;; Admit only a complete projection; never silently drop a #!key collector or
    ;; malformed binder. Every supported binder/key occupies one projected token.
    (unless (= (length head) (length bound)) (error "Unsupported generic formals" formals))
    (def keywords (filter stx-keyword? bound))
    (apply keyword-dispatch #f
      (lambda (table . positionals)
        (with-syntax (((target leading ...) prefix)
                      ((keyword ...) (alist->plist (map (lambda (key)
                        (cons key (symbolic-table-ref table (syntax-e key) #f))) keywords)))
                      ((positional ...) positionals)
                      ((escape ...) (if (pair? keywords) #'(#!rest) []))
                      ((tail ...) (if (identifier? rest) [rest] []))
                      ((apply* ...) (if (identifier? rest) #'(apply) [])))
          (if row?
            ;; The fixed prefix is known at expansion time. Standard append
            ;; copies the rest spine before callbacks can mutate their owned row;
            ;; nested cons avoids runtime apply/list argument redistribution.
            (foldr (lambda (value tail)
                     (with-syntax ((value value) (tail tail)) #'(cons value tail)))
              (if (identifier? rest)
                (with-syntax ((rest rest)) #'(append rest '())) #''())
              (syntax->list #'(keyword ... escape ... leading ... positional ...)))
            #'(apply* ... target keyword ... escape ... leading ... positional ... tail ...))))
      (map (lambda (binding) (if (stx-keyword? binding) (syntax-e binding) binding)) bound))))
