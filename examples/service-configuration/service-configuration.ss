(export service-defaults service-configuration)
(import (only-in :clan/poo/object .o .mix))

(def service-defaults
  (.o endpoint: "https://api.example.org" timeout-ms: 1000 retries: 2
      request-budget-ms: (* timeout-ms (+ retries 1))))

(def (service-configuration tenant-settings region-settings)
  (.mix tenant-settings region-settings service-defaults))
