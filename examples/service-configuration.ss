(export service-defaults service-configuration)
(import (only-in :clan/poo/object .o .mix))

(def service-defaults
  (.o endpoint: "https://api.example.org" timeout-ms: 1000 retries: 2))

(def (service-configuration tenant-settings)
  (.mix tenant-settings service-defaults))
