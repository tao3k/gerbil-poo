# Using the property-testing modules

The generic library is a standard Gerbil project at `testing/core/`. Its
`gerbil.pkg` declares `clan/property-testing`; it imports no POO modules.
From that directory, use the ordinary `gerbil build` command. The POO root
build invokes this same standard build before compiling typed consumers.

Import the modules you use directly:

```scheme
(export arithmetic-test)
(import :std/test
        (prefix-in :clan/property-testing/generator generator.)
        (prefix-in :clan/property-testing/property property.))

;; Draw and shrink signed integers with one explicit random source.
(def integers
  (generator.make-generator
    (lambda (random size) (- (random (+ (* 2 size) 1)) size))
    generator.integer-shrinks))
;; Domain admission and shrink measure are supplied by this application.
(def integer-domain
  (property.make-specification exact-integer? abs))

;; Standard Gerbil TestSuite discovery owns execution.
(def arithmetic-test
  (test-suite "integer arithmetic"
    (test-case "addition identity"
      (check (property.report-status
        (property.check-property integers (lambda (x) (= (+ x 0) x))
          integer-domain seed: 42 cases: 100 size: 50))
        => 'passed))))
```

The example is exported as a normal `*-test` suite for `gerbil test` discovery.
See `examples/property-kernel.ss` for dependent packets, non-injective maps,
lazy bounded shrinking, source invalidation and a model with logical handles.
`testing/core/model.ss` owns model execution and repair; it does not instantiate
a POO object or prescribe an application representation.

POO users import `:clan/poo/testing/type` for descriptor-driven generators and
reports, `:clan/poo/testing/function` for signature derivation, and
`:clan/poo/testing/recursive-generation` for bounded recursive derivation.
Those modules own Type validation, wrapping and revision observations. They
supply these operations to the generic library through explicit callbacks.
There is no `api.ss` forwarding module or alternative dynamic import mechanism.

A generator's shrink callbacks must preserve its intermediate domain. The final
specification additionally checks domain admission, a natural-valued measure and
strict Boolean properties. Reports distinguish failure, errors, stale sources
and exhausted generation. Shrink fuel counts forced proposals, including rejected
ones; zero fuel does not invoke a shrink callback. A minimum refers only to an
observed exhausted immediate neighborhood, not a globally smallest value.

Seed replay regenerates under the recorded configuration; concrete replay checks
the retained witness without drawing or shrinking. Mutable callback dependencies
must be declared through accurate source observers. The isolated regression builds
the actual generic package and executes twenty-eight cases without any POO modules in
its package directory, under the existing heap and timeout limits.

Model normalization is an explicit boundary: `check-trace` first prepares the
entire command list and executes exactly those normalized objects. Its mismatch
report carries the prepared command. A late domain/precondition refusal or
normalization exception opens no fixture. `valid-trace?` projects the same
preparation; do not use it as a substitute for `check-trace`'s own preflight.
The POO facade supplies already-wrapped commands with identity normalization.

Interrupted shrink reports retain the last confirmed witness and charged work.
A returned proposal counts even when admission, cost, property or source checks
fail; EOF and an iterator exception produce no proposal. The error's cause is
retained, `minimal?` is false, and concrete replay requires a `failed` report.
A diagnostic reduced value on an `error` or `stale` report is not certified evidence.

## Composing domain generators

`generator-choice` and `generator-frequency` select explicit generator branches.
Weights are captured nonnegative integers with a positive total; zero-weight
branches cannot be selected. `generator-sized`, `generator-resize` and
`generator-scale` reuse the same lazy tree. `generator-delay` spends an explicit
construction depth shared by nested delayed forces. `bind-generators` is hygienic
syntax over the existing bind/unit algebra, not a separate execution language.

`generator-filter` has a finite draw-attempt budget. A rejected shrink child is
pruned and charged by the ordinary shrink consumer, including under map/bind.
Its value is never passed to downstream selectors or properties. Descendants
of that rejected node are not searched: minimality still means only the supplied
pruned immediate neighborhood. Callback exceptions remain errors; exhausted draw
or delay budgets report `exhausted`. Construct valid dependent inputs directly
when possible instead of relying on filtering.

`generator-no-shrink` and `generator-with-shrink` retain the drawn root's sources.
Neither forces a child factory during preparation or zero-fuel checking.
`make-tree-generator` / `make-sample` expose the existing owned-tree protocol for
advanced composition. The consumer validates every returned proposal.

Sources are flat observer leaves, deduplicated by callback identity using the
standard list/hash helpers. Separately captured epochs remain distinct. Both
supplied/exported source lists are detached from node ownership. Optional POO
currentness hooks are prepared once, with source revision checks before every
call. The finite `mergeSources_mem` / `mergeSources_current` Lean laws justify
identity union without discarding old branches; observer accuracy remains a premise.

## Sized named properties and typed integration

`define-property` defines an ordinary callable check entry:

```scheme
(property.define-property (small value)
  (generator.generator-sized generator.generator-unit)
  integer-domain
  (< value 3))

(small seed: 42 cases: 5 size: (lambda (trial) trial) size-limit: 5)
```

A per-trial size policy requires an explicit natural `size-limit`; constant sizes
default to their own limit. An invalid or excessive result refuses before drawing.
Reports retain `report-trial-size` and `report-size-limit`, and seed replay uses
the same policy and observer. A policy that raises before producing a size leaves
the diagnostic trial size false. Concrete witness replay invokes no size policy.
This limits driver-supplied sizes, not arbitrary work inside user callbacks or
an explicitly resized generator; existing depth/search/process guards still apply.

POO's `from-generator` supplies a Type, core generator and measure; `generator-core`
retains the sample tree through typed products, recursive carriers and Function
argument rows. Record construction still owns Function wrapping. Replacing a
sampler's draw/shrink callback retires its inherited tree binding. Value-only
shrinking requires an explicit callback when the original sample is unavailable;
the library never guesses an inverse of a non-injective map.

`examples/generated-batches.ss` demonstrates weighted dependent payloads, inherited
source invalidation, size scheduling, Reader/FUN, nested Function wrapping and
seed/witness replay. Import its suite through ordinary Gerbil modules. The generic
example's twenty cases also build and run in a separate stdlib-only project.

`just benchmark-generators` uses the existing shared executable and paired timing
helpers. It compares callback/tree strategies on one fixed injective workload,
with prepare/draw/workflow phases, AB/BA, A/A and B/B, natural GC and charged
post-GC first calls. It does not establish statistical PRNG quality or a general
speedup for non-injective or application-specific generators.
See [the generator cost receipt](performance/generation-summary.org), including
the remaining complete-shrink regression rather than only allocation changes.


Bind regeneration reuses SRFI-27 initial-state checkpoints owned by one draw's
sample tree. Every child still receives a fresh mutable random source and invokes
its selector/draw; a later check owns fresh preparation. Nested binds share only
deterministic seed expansion, never sample values or observer verdicts. Public
source lists stay detached; empty/identical internal source lists may be shared.
See `doc/performance/generation-summary.org` for the full paired controls and
remaining provenance costs. No process limit or check was removed.


## Effective coverage and portable failure data

```scheme
(import (prefix-in :clan/property-testing/property property.)
        (prefix-in :clan/property-testing/replay replay.))
(def policy (property.make-policy name: 'revision
  labels: (lambda (commands) (map (cut vector-ref <> 0) commands))
  required: '((install . 10) (undo . 10)) discard-budget: 100))
;; Pass policy: policy to the existing core or POO check-property/property-action.
(def codec (replay.make-codec '(revision 1 command-schema-2 generator-1)
  encode-commands decode-commands current?: command-schema-current?))
;; Keep generated corpora outside the repository unless deliberately curated.
(call-with-output-file failure-path
  (cut replay.write-counterexample failed-report codec <>))
(call-with-input-file failure-path
  (lambda (port) (replay.read-counterexample codec port specification property)))
```

`report-accepted`, `report-discarded`, `report-labels` and `report-name` expose the
run-owned diagnostic ledger. `coverage` and `exhausted` are refusals, not passes.
The snippets' encoders, schema guards and finite requirements are application-owned.
A codec identity must change when its domain/property/precondition interpretation
changes. Persist data only, never a report's closures or backend owner objects.

For higher-order properties, `generator-function` takes finite raw argument rows
and a generator of result tuples. Map `function-procedure` through the existing
generator algebra to derive a sampler for a POO Function descriptor. Calls outside
those rows refuse. Multi-value and keyword calls use Gerbil's ordinary call path;
there is no generated evaluator or second argument parser. See the executable
[property workflows](../examples/property-workflows.ss) and the PBT RFC for bounds.

## Standard TestSuite assertions and named arguments

Import the report API and the standard assertion module separately:

```scheme
(export balance-test)
(import :std/test
        (prefix-in :clan/property-testing/generator generator.)
        (prefix-in :clan/property-testing/property property.)
        (only-in :clan/property-testing/test define-property check-property))
;; The application owns its finite domain and decreasing measure.
(def domain (property.make-specification exact-integer? abs))
;; Later draws may depend on earlier arguments; fixed domains are prepared once.
(define-property balanced
  ((left (generator.make-generator
           (lambda (random size) (- (random (1+ (* 2 size))) size))
           generator.integer-shrinks) domain)
   (right (generator.generator-unit (- left)) domain))
  (= (+ left right) 0))
;; Standard Gerbil discovery and TestCase failure propagation remain unchanged.
(def balance-test
  (test-suite "balanced amounts"
    (test-case "dependent arguments" (balanced seed: 42 cases: 100 size: 20))))
```

`property.check-property` returns data for inspection, shrinking and replay.
The `check-property` macro exported by `:clan/property-testing/test` instead
registers one ordinary `:std/test` check. It evaluates its report and diagnostics
formatter once, preserves the caller location through `do-check!`, and raises a
standard TestError for every non-passing outcome. Diagnostics retain status,
property name, seed, trial/size, effective counts, labels, named original/reduced
arguments, shrink accounting and original cause identity. A previously passing
report is refused if its captured sources are no longer current.

For an existing report, use `(check-property report)`. For a POO report, import
`report-diagnostics` from `:clan/poo/testing/type` and use
`(check-property typed-report diagnostics: report-diagnostics)`. This also handles
Type/generator preparation refusals with no generic execution report. The generic
library imports no POO module; the POO projection adds no test-runner dependency.

Property bodies return strict Booleans. An exception from a body, including a
nested standard assertion, is an error rather than a generated falsification;
keep assertions around the returned report or use the named Boolean property.
Specifications are fixed within a check, while generator expressions can depend
on earlier arguments. This is not unrestricted dependent-type inference.

The installed compiled Gerbil CLI can print `ERROR HARNESS` while returning zero
(the dispatcher does not propagate the tool's numeric result). The standard
TestResult still records the failure. This repository's existing Just admission
requires case/harness success and rejects ERROR markers; downstream CI must use
an entry that preserves those checks until its Gerbil release propagates failure
status. The ordinary `examples/property-refusals.ss` module verifies all six PBT failure categories
through the same public entry. It is invoked explicitly by the positive workflow
suite; no temporary Scheme source, custom runner or fixture lifecycle is generated.

## Characters, bytes and spellings

The generic generator module exports inclusive `generator-integer lower upper`,
`generator-character lower: char upper: char`, and `generator-byte` (0–255).
The default character domain is Unicode scalar values, excluding surrogates.
`generator-string` and `generator-symbol` accept an optional character generator;
`generator-bytes` produces Gerbil u8vectors. All three accept `min-length:` and
`max-length:` (defaults 0/128). Size controls extra elements above the minimum;
`min-length: 4 max-length: 4` always produces four bytes, even at size zero.

```scheme
;; Application alphabet and spelling bounds are explicit domain choices.
(def letters (generator.generator-character lower: #\a upper: #\z))
(def names (generator.generator-symbol letters min-length: 1 max-length: 12))
(def payloads (generator.generator-bytes min-length: 4 max-length: 4))
;; Depend on the exact generated spelling without a second source or PRNG.
(def rows (generator.bind-generators
  ((name names) (payload payloads)) (vector name payload)))
```

Use an explicit specification accepting the same alphabet/length domain. A
natural measure such as length plus the sum of character codes/octet values
allows both deletion and coordinate shrinking. For fixed widths use the content
sum. The existing runner rejects nondecreasing proposals and charges them;
there is no promise that every structural proposal has smaller content weight.
POO `generator` now derives String, Symbol, Bytes and BytesN from these same
families, including recursive container leaves. Custom scalar domains use
`from-generator` with their own descriptor, measure and source dependencies.
Concrete replay codecs may retain u8vectors directly; byte lengths count toward
the codec's existing node budget. Symbols are interned spellings rather than
identifiers; escaped reader spellings are preserved by ordinary write/read.
