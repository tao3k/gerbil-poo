(export service-configuration-test)
(import (only-in :clan/poo/object .o .get)
        (only-in :std/test test-suite test-case check-equal?)
        "./service-configuration.ss")

(def service-configuration-test
  (test-suite "Service configuration"
    (test-case "A tenant overrides timeout and inherits the endpoint and retries"
      (def tenant (service-configuration (.o timeout-ms: 250)))
      (check-equal? (.get tenant endpoint) "https://api.example.org")
      (check-equal? (.get tenant timeout-ms) 250)
      (check-equal? (.get tenant retries) 2)
      (check-equal? (.get service-defaults timeout-ms) 1000))))
