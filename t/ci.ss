;;; Preserve the standard native harness result as the CI process exit status.
(import (prefix-in :gerbil/tools/gxtest runner.))
;; gxtest.main returns 42 for failures. An imported module's return value alone
;; cannot fail its host process, so explicitly forward that status to exit.
(def (main) (exit (runner.main "-v" "5" "t")))
(main)
