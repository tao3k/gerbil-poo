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
the actual generic package and executes twelve cases without any POO modules in
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
