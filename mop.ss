;;-*- Gerbil -*-
;;; Public POO MOP with JSON serialization support.

(import ./mop-core
        (only-in ./support/json string<-json json<-string))
(export (import: ./mop-core))

(install-mop-json-adapters! string<-json json<-string)
