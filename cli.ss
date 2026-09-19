(export #t)

(import
  (only-in :std/cli/getopt getopt getopt-parse getopt-display-help flag
           call-with-getopt-parse)
  (rename-in
   (only-in :std/cli/multicall
            ->getopt-spec call-with-processed-command-line current-program-string)
   (->getopt-spec std:->getopt-spec)
   (call-with-processed-command-line std:call-with-processed-command-line))
  (only-in :std/hash/misc hash-ensure-removed!)
  (only-in :std/list/list flatten)
  (only-in ./support/list pair-tree-for-each!)
  (only-in ./object .has? .@ object?)
  (only-in ./brace @method))

(def getopt-spec/backtrace
  [(flag 'backtrace "--backtrace" help: "enable backtraces for debugging purposes")])
(def process-opts/backtrace
  [(lambda (options)
     (let-values (((enabled? _) (hash-ensure-removed! options 'backtrace)))
       (when enabled? (dump-stack-trace? #t))))])

(def (->getopt-spec x)
  (if (object? x)
    (cond
     ((.has? x .type .getopt-spec) (->getopt-spec ((.@ x .type .getopt-spec) x)))
     ((.has? x getopt-spec) (->getopt-spec (.@ x getopt-spec)))
     (else (error "No getopt-spec" x)))
    (std:->getopt-spec x)))

(def (call-with-processed-command-line x command-line function)
  (if (object? x)
    (let* ((process-opts
            (cond
             ((.has? x .type .process-opts) ((.@ x .type .process-opts) x))
             ((.has? x process-opts) (.@ x process-opts))
             (else (error "No getopt-spec" x))))
           (gopt (apply getopt (->getopt-spec x)))
           (h (getopt-parse gopt command-line)))
      (pair-tree-for-each! process-opts (cut <> h))
      (call-with-getopt-parse gopt h function))
    (std:call-with-processed-command-line x command-line function)))

(def options/base {getopt-spec: ? [] process-opts: ? []})

(def (make-options getopt-spec_ (process-opts_ []) (super options/base))
  {(:: @ super)
   getopt-spec: => (cut cons <> getopt-spec_)
   process-opts: => (cut cons <> process-opts_)})

(def options/backtrace (make-options getopt-spec/backtrace process-opts/backtrace))

(def options/help
  {(:: @ [options/base])
   getopt-spec: => (cut cons <> (flag 'help "-h" "--help" help: "Show help")) ;; or should it be -? or both?
   process-opts: => (cut cons <>
                         (lambda (opt) (when (hash-get opt 'help)
                                    (let (gopt (apply getopt (flatten getopt-spec)))
                                      (getopt-display-help gopt (current-program-string))
                                      (force-output)
                                      (exit 0)))))})
