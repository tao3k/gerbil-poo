(export service-configuration-test)
(import (only-in :clan/poo/object .o .get)
        (only-in :std/test test-suite test-case check-equal?)
        "./service-configuration.ss")

(def service-configuration-test
  (test-suite "Service configuration"
    (test-case "Recompute a request budget from the selected tenant and region"
      (def region (.o endpoint: "https://eu.api.example.org" retries: 3))
      (def tenant (service-configuration (.o timeout-ms: 250) region))
      (check-equal? (.get tenant endpoint) "https://eu.api.example.org")
      (check-equal? (.get tenant timeout-ms) 250)
      (check-equal? (.get tenant retries) 3)
      (check-equal? (.get tenant request-budget-ms) 1000)
      (check-equal? (.get service-defaults request-budget-ms) 3000))))
