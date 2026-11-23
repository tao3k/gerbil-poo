(export #t)

(import
  (only-in :gerbil/runtime/loader load-module)
  :std/assert
  (only-in :std/error raise-premature-end-of-input)
  (only-in :std/io/interface/base Reader Reader-read Writer Writer-write)
  :std/format
  (only-in :std/func compose)
  :std/iter
  :std/list/walist
  :std/encoding/json
  ./support/repr
  ./support/base
  ./support/io
  ./support/json
  ./object
  (only-in ./object/prototype-map prototype-map-keys)
  ./mop/prototype)

(extern namespace: "clan/poo/io" writeenv-style)
(begin-foreign
  (include "~~lib/_gambit#.scm")
  (define (clan/poo/io#writeenv-style environment)
    (macro-writeenv-style environment)))

;; Capture one runtime entry as a Reader-compatible IO action, without loading it.
;; The private path copy cannot drift away from the caller's explicit binding.
;; Gerbil owns discovery, dependency preparation and initialization/error caching.
;; Resolve the binding on EVERY invocation so successful reloads are visible;
;; tail apply preserves all values and the original loading/entry exceptions.
;; Binding is an explicit runtime identifier, including canonical reexport targets;
;; this boundary does not infer export aliases or retain a second module registry.
(def (module-action module binding)
  (using ((module :~ string?) (binding :~ symbol?))
    (let (path (string-copy module))
      (lambda (arguments)
        ;; Admit a finite call row before initialization effects. Own its spine
        ;; across loading/lookup; payloads, including Function values, stay shared.
        (using (arguments :~ list?)
          (let (request (list-copy arguments))
            ;; Standard loader diagnostics may expose the supplied string.
            ;; Hand off a copy so error inspection cannot retarget this action.
            (load-module (string-copy path))
            (apply (eval binding) request)))))))

(include "io/bytes.ss")

(include "io/representation.ss")

(include "io/serialization.ss")


(include "io/gambit-writer.ss")
