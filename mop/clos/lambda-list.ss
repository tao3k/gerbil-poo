;;; -*- Gerbil -*-
;;; SPDX-FileCopyrightText: 2026 tao3k team and Contributors
;;;
;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later

;;; Functional argument binding helpers for hygienically lowered CLOS methods.

(import :clan/poo/object
        (only-in :std/list/list drop)
        "funcs.ss")

(export clos-positional-supplied? clos-positional-argument
        clos-rest-arguments clos-key-argument
        clos-method-combination-options-valid?
        clos-combination-required-argument
        clos-combination-optional-supplied?
        clos-combination-optional-argument
        clos-combination-rest-arguments
        clos-combination-key-argument)

;; : (-> [SchemeValue] Natural Boolean)
(def (clos-positional-supplied? arguments index)
  (< index (length arguments)))

;; : (-> [SchemeValue] Natural Thunk SchemeValue)
(def (clos-positional-argument arguments index default-value)
  (if (clos-positional-supplied? arguments index)
    (list-ref arguments index)
    (default-value)))

;; : (-> [SchemeValue] Natural [SchemeValue])
(def (clos-rest-arguments arguments start)
  (drop arguments (min start (length arguments))))

;; : (-> [SchemeValue] Natural InitargName (Pair Boolean SchemeValue))
(def (clos-key-argument arguments start name)
  (call-with-values
   (lambda ()
     (clos-initarg-ref (clos-rest-arguments arguments start) name))
   cons))

;; : (-> [SchemeValue] Natural Natural Boolean Boolean [InitargName]
;;        Boolean Boolean)
(def (clos-method-combination-options-valid?
      arguments required optional rest? key? keys allow-other-keys?)
  (let* ((count (length arguments))
         (start (+ required optional))
         (open-tail? (or rest? key?)))
    (and (>= count required)
         (or open-tail? (<= count start))
         (or (not key?)
             (let* ((tail (clos-rest-arguments arguments start))
                    (valid-index (clos-identity-index keys)))
               (and (clos-initarg-list? tail)
                    (or allow-other-keys?
                        (clos-allow-other-keys? tail)
                        (not
                         (clos-first-invalid-initarg
                          tail valid-index
                          clos-allow-other-keys-name?)))))))))

;; : (-> ClosGenericFunction [SchemeValue] Natural SchemeValue)
(def (clos-combination-required-argument generic arguments index)
  (let (generic-required (.ref (.ref generic 'lambda-list) 'required))
    (if (and (< index generic-required) (< index (length arguments)))
      (list-ref arguments index)
      #f)))

;; : (-> ClosGenericFunction [SchemeValue] Natural Boolean)
(def (clos-combination-optional-supplied? generic arguments index)
  (let* ((lambda-list (.ref generic 'lambda-list))
         (required (.ref lambda-list 'required))
         (optional (.ref lambda-list 'optional))
         (position (+ required index)))
    (and (< index optional) (< position (length arguments)))))

;; : (-> ClosGenericFunction [SchemeValue] Natural Thunk SchemeValue)
(def (clos-combination-optional-argument generic arguments index default)
  (if (clos-combination-optional-supplied? generic arguments index)
    (list-ref arguments (+ (.ref (.ref generic 'lambda-list) 'required) index))
    (default)))

;; : (-> ClosGenericFunction [SchemeValue] [SchemeValue])
(def (clos-combination-rest-arguments generic arguments)
  (let (lambda-list (.ref generic 'lambda-list))
    (clos-rest-arguments
     arguments (+ (.ref lambda-list 'required) (.ref lambda-list 'optional)))))

;; : (-> ClosGenericFunction [SchemeValue] InitargName
;;        (Pair Boolean SchemeValue))
(def (clos-combination-key-argument generic arguments name)
  (let (lambda-list (.ref generic 'lambda-list))
    (clos-key-argument
     arguments (+ (.ref lambda-list 'required) (.ref lambda-list 'optional))
     name)))
