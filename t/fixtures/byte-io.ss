;;; Exact bounded byte transfer composed through the existing FUN Reader.
(export copy-bytes-action)
(import (only-in :clan/poo/fun Observation.)
        (only-in :clan/poo/object .get .call)
        (only-in :clan/poo/io object-read-bytes object-write-bytes))

;; Read exactly count bytes before writing them through the SAME environment.
;; The caller owns its input/output ports or standard Reader/Writer objects.
;; A read failure prevents output; a write failure retains ordinary stream effects.
;; Reusing the action with fresh endpoints retries without retaining prior bytes.
(def (copy-bytes-action (count :~ nonnegative-fixnum?))
  (.call Observation. .bind
    (lambda (environment) (object-read-bytes count (.get environment input)))
    (lambda (bytes)
      (.call Observation. .map (lambda (_) bytes)
        (lambda (environment) (object-write-bytes bytes (.get environment output)))))))
