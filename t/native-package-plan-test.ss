;;; SPDX-License-Identifier: Apache-2.0 AND LGPL-2.1-or-later
;;; Real SDK specification and executable boundary, without a compiler substitute.
(import :std/test
        (prefix-in "../build.ss" package.))
(export native-package-plan-test)
(def native-package-plan-test
  (test-suite "One native package compilation plan"
    (test-case "Libraries and representation executable share the native specification"
      (def output (call-with-output-string (lambda (port)
                    (parameterize ((current-output-port port)) (package.main "spec")))))
      (call-with-input-string output
        (lambda (port)
          (read-line port) ; Existing resource declaration precedes the native spec.
          (def spec (read port))
          (check (eof-object? (read port)) => #t)
          (for-each (lambda (root) (check (and (member root spec) #t) => #t))
                    '("object" "mop" "type" "testing/property/generator"
                      "testing/property/model" "testing/property/replay"))
          (def programs (filter (lambda (entry) (and (pair? entry) (eq? (car entry) exe:))) spec))
          (check (length programs) => 1)
          (check (cadar programs) => "examples/representation-main")
          (check (pgetq bin: (cddar programs)) => "representation-main")
          (check (and (member "-D___SINGLE_HOST_LIMIT=10000" (car programs)) #t) => #t))))))
