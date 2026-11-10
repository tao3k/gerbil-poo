;;; The existing SCC matrix runs inside the official TestSuite lifecycle.
(export scc-benchmark-test reachability-benchmark-test compact-benchmark-test)
(import :std/test (prefix-in (only-in :clan/poo/t/feedback/feedback-graph-test main) study.)
        (prefix-in (only-in :clan/poo/t/feedback/graph-algorithms-test main small-reachability-study compact-study shared-cyclic-study) scale.))
;; Existing construction module owns the same DAG update workload as its tests.
(import (prefix-in (only-in :clan/poo/t/construction/graph-order-repair-test main) rank.))
;; Retain the complete 320-observation matrix and original failure propagation.
(def scc-benchmark-test
  (test-suite "complete paired SCC workload"
    (test-case "every existing topology and regime" (study.main))
    (test-case "100000/1000000 Graph nodes with bounded semantic controls" (scale.main))))

;; The official suite filter can run this bounded setup study independently.
;; Full benchmark-scc still runs every original suite plus this one.
(def reachability-benchmark-test
  (test-suite "prepared small reachability index costs"
    (test-case "same captured rows, list versus indexed membership"
      (scale.small-reachability-study))))

(def compact-benchmark-test
  (test-suite "compact Graph storage and complete cold query costs"
    (test-case "same input rows, charged CSR encoding and ordered traversal"
      (scale.compact-study))
    (test-case "paired Algorithm T completion on the million-node cyclic band"
      (scale.shared-cyclic-study))))

(export rank-revision-benchmark-test)
;; This complete fixed-input study has one owner. Running rank.main again in
;; scc-benchmark-test duplicated every observation and large source preparation.
(def rank-revision-benchmark-test
  (test-suite "separate rank revision and explicit order output"
    (test-case "100K and 1M fixed support revisions" (rank.main))))

(import (prefix-in (only-in :clan/poo/t/construction/graph-order-repair-test owned-delta-study) delta.))
(export owned-delta-benchmark-test)
(def owned-delta-benchmark-test
  (test-suite "source-owned rank revision"
    (test-case "100K and 1M source-owned versus unrestricted" (delta.owned-delta-study))))

(import (prefix-in (only-in :clan/poo/t/construction/graph-order-repair-test owned-cache-study reverse-bucket-study) delta.))
(export owned-cache-benchmark-test)
(def owned-cache-benchmark-test
  (test-suite "affected-only ConstructionCache"
    (test-case "100K and 1M revisions before explicit reuse output" (delta.owned-cache-study))))

(export reverse-bucket-benchmark-test)
(def reverse-bucket-benchmark-test
  (test-suite "persistent reverse bucket"
    (test-case "100K and 1M edits and separate reader demand" (delta.reverse-bucket-study))))

(import (prefix-in (only-in :clan/poo/t/construction/graph-order-repair-test local-components-study) delta.))
(export local-components-benchmark-test)
(def local-components-benchmark-test
  (test-suite "local SCC merge and split"
    (test-case "100K and 1M fixed support revisions" (delta.local-components-study))))

(import (prefix-in (only-in :clan/poo/t/construction/graph-order-repair-test local-component-pressure-study) delta.))
(export local-component-pressure-benchmark-test)
(def local-component-pressure-benchmark-test
  (test-suite "structural SCC pressure"
    (test-case "100K and 1M ring deletion" (delta.local-component-pressure-study 'ring))
    (test-case "100K and 1M reverse hub deletion" (delta.local-component-pressure-study 'hub))))

(export owned-quotient-benchmark-test)
(import :std/iter :clan/poo/object :clan/poo/mop :clan/poo/support/option
        (only-in :clan/poo/component-closure component-group-builder)
        (only-in :clan/poo/generalized-closure closed-raw)
        (only-in :clan/poo/feedback-cache group-closed)
        (only-in :clan/poo/feedback-graph publish-owned-feedback-graph graph-cache-values graph-cache-ref graph-cache-partition)
        (only-in :clan/poo/benchmarks/closure-measure measure qualified-metrics)
        (prefix-in :clan/poo/generalized-graph graph.)
        (prefix-in :clan/poo/dependency-analysis code.)
        (prefix-in :clan/poo/construction-cache cache.)
        (prefix-in :clan/poo/component-revision edit.)
        (prefix-in :clan/poo/component-publication publication.)
        (prefix-in (only-in :clan/poo/strong-components partition-work) scc.))

(extern namespace: clan/poo/feedback-graph graph-cache-guard graph-cache-owned)
(extern namespace: clan/poo/feedback-cache guard-index-root)
(extern namespace: clan/poo/generalized-graph %component-source-code-witnesses)
(def (witness-update-count old next)
  (if (or (not next) (eq? old next)) 0
    (+ 1 (witness-update-count (and old (graph.%witness-tree-left old)) (graph.%witness-tree-left next))
         (witness-update-count (and old (graph.%witness-tree-right old)) (graph.%witness-tree-right next)))))
(def (guard-update-count before after)
  (witness-update-count (guard-index-root (graph-cache-guard before))
                        (guard-index-root (graph-cache-guard after))))
(def (code-witness-update-count before after)
  (witness-update-count (%component-source-code-witnesses (graph-cache-owned before))
                        (%component-source-code-witnesses (graph-cache-owned after))))

;; Same-predecessor publication, with real scalar anchor/reader groups and
;; independent inert group receipts for the remaining independent owners. Complete
;; approval still traverses every group. This is not an Interface workload.
(def (owned-quotient-study count)
  (def names (append '(anchor reader) (for/collect (index (in-range (- count 2)))
    (string->symbol (string-append "quotient-owner-" (number->string index))))))
  (def initial-source (graph.declaration names [(cons 'reader (code.need 'anchor identity))]
    [(cons 'anchor (some (code.make-success 0)))]))
  (def real-build (component-group-builder '(anchor reader) (lambda (_) (.lens)) 0 0 8))
  (def (build members source resolve)
    (if (memq (car members) '(anchor reader)) (real-build members source resolve)
      (real-build '(anchor) initial-source (lambda (_) (error "unexpected inert read")))))
  (def (accept _ __) #t)
  (def (read-value state) (closed-raw (group-closed (graph-cache-ref state 'reader))))
  (defvalues (initial cold)
    (measure (lambda ()
      (defvalues (head failure) (publish-owned-feedback-graph initial-source build accept))
      (when failure (raise failure))
      head) 1))
  (unless (= (read-value initial) 0) (error "cold publication oracle"))
  (displayln (list 'QUOTIENT-COLD count (qualified-metrics cold)))
  (def fragment (edit.fragment [] [] [] [(cons 'anchor (some (code.make-success 7)))]))
  (for (side '(noop patch patch noop))
    (def publication (publication.publication initial))
    (def patch? (eq? side 'patch))
    (defvalues (accepted timing)
      (measure (lambda ()
        (def request (publication.stage publication (if patch? [fragment] []) build accept))
        (defvalues (head failure) (publication.submit! publication request))
        (when failure (raise failure))
        head) 1))
    (def work (cache.cache-work (graph-cache-values accepted)))
    (def checked (.get work graph owner-checks))
    (def buckets (.get work inverse-buckets))
    (def writes (.get work value-patch-writes))
    (def guards (guard-update-count initial accepted))
    (unless (and (= (read-value accepted) (if patch? 7 0))
                 (= checked (if patch? 1 0))
                 (= buckets (if patch? 2 0))
                 (= writes (if patch? 2 0))
                 (zero? (code-witness-update-count initial accepted))
                 (if patch? (<= 2 guards 30) (zero? guards))
                 (zero? (.get work graph order-materialized)))
      (error "publication did not stay within exact affected work" count side checked buckets writes guards))
    (displayln (list 'QUOTIENT-UPDATE count side (qualified-metrics timing)
      (list 'source-rows checked 'inverse-buckets buckets 'value-writes writes 'guard-node-writes guards))))
  (defvalues (value demand) (measure (lambda () (read-value initial)) 1000))
  (unless (= value 0) (error "historical demand changed"))
  (displayln (list 'QUOTIENT-DEMAND count 1000 (qualified-metrics demand))))

(def owned-quotient-benchmark-test
  (test-suite "owned feedback publication with opaque group approval"
    (test-case "1000 and 10000 group publication, no-op, edit and demand"
      (owned-quotient-study 1000)
      (owned-quotient-study 10000))))

(def (published-hub-study count)
  (def readers (for/collect (index (in-range (1- count)))
    (string->symbol (string-append "published-reader-" (number->string index)))))
  (def names (cons 'hub readers))
  (def target (car readers))
  (def untouched (cadr readers))
  (def code (code.need 'hub identity))
  (def initial-source
    (graph.declaration names (map (cut cons <> code) readers)
      [(cons 'hub (some (code.make-success 0)))]))
  (def (build members source resolve)
    (def support (if (eq? (car members) 'hub) members (cons 'hub members)))
    ((component-group-builder support (lambda (_) (.lens)) 0 0 8) members source resolve))
  (def (accept _ __) #t)
  (def (read-value state key) (closed-raw (group-closed (graph-cache-ref state key))))
  (defvalues (initial cold)
    (measure (lambda ()
      (defvalues (head failure) (publish-owned-feedback-graph initial-source build accept))
      (when failure (raise failure))
      head) 1))
  (unless (= (read-value initial target) 0) (error "hub cold value"))
  (displayln (list 'PUBLISHED-HUB-COLD count (qualified-metrics cold)))
  (def fragment (edit.fragment [] [] [(cons target (code.pure 7))]))
  (for (iteration (in-range 4))
    (def publisher (publication.publication initial metadata: (.o version: 0)))
    (def metadata (.o version: 1))
    (defvalues (accepted timing)
      (measure (lambda ()
        (def request (publication.stage publisher [fragment] build accept metadata: metadata))
        (defvalues (head failure) (publication.submit! publisher request))
        (when failure (raise failure))
        head) 1))
    (def values-work (cache.cache-work (graph-cache-values accepted)))
    (def partition-work (scc.partition-work (graph-cache-partition accepted)))
    (def guards (guard-update-count initial accepted))
    (def code-guards (code-witness-update-count initial accepted))
    (unless (and (= (read-value accepted target) 7) (= (read-value initial target) 0)
                 (eq? (graph-cache-ref initial untouched) (graph-cache-ref accepted untouched))
                 (eq? metadata (publication.snapshot-metadata (publication.snapshot publisher)))
                 (= (.get values-work graph owner-checks) 1)
                 (= (.get values-work inverse-buckets) 1)
                 (= (.get values-work value-patch-writes) 1)
                 (<= 1 guards 15)
                 (<= 1 code-guards 15)
                 (= (.get values-work graph order-materialized) 0))
      (error "published hub changed unaffected work" count iteration))
    (displayln (list 'PUBLISHED-HUB-DELETE count iteration (qualified-metrics timing)
      (list 'reverse-writes (.get partition-work reverse-writes)
            'reverse-rewrite-edges (.get partition-work reverse-rewrite-edges)
            'affected-buckets (.get values-work inverse-buckets)
            'guard-node-writes guards 'code-witness-writes code-guards))))
  (when (= count 1000)
    (let* ((publisher (publication.publication initial))
           (expected (publication.snapshot publisher))
           (request (publication.stage publisher [fragment] build (lambda (_ __) #f))))
      (defvalues (_head failure) (publication.submit! publisher request))
      (unless (and failure (eq? expected (publication.snapshot publisher))
                   (= (read-value initial target) 0))
        (error "rejected hub edit published a candidate")))))

(export published-hub-benchmark-test)
(def published-hub-benchmark-test
  (test-suite "owned hub deletion through feedback publication"
    (test-case "1000 and 10000 real reader groups retain the old snapshot"
      (published-hub-study 1000)
      (published-hub-study 10000))))
