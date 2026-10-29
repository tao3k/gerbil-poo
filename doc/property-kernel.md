# Using the property-testing modules

The generic modules live under `testing/property`, within the ordinary POO
package build. Run `gerbil build` from the package root. They import only the
Gerbil standard library; typed derivation stays in `testing/type`.

Import the modules you use directly:

```scheme
(export arithmetic-test)
(import :std/test
        (prefix-in :clan/poo/testing/property/generator generator.)
        (prefix-in :clan/poo/testing/property property.))

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
`testing/property/model.ss` owns model execution and repair; it does not instantiate
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
the actual generic package and executes thirty-six cases without any POO modules in
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
(import (prefix-in :clan/poo/testing/property property.)
        (prefix-in :clan/poo/testing/property/replay replay.))
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
        (prefix-in :clan/poo/testing/property/generator generator.)
        (prefix-in :clan/poo/testing/property property.)
        (only-in :clan/poo/testing/property/test define-property check-property))
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
The `check-property` macro exported by `:clan/poo/testing/property/test` instead
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

## Bounded sample and shrink inspection

Import the ordinary property module and call `property.inspect-generator` with
an existing generator and specification. No test property or fixture is run.

```scheme
;; Sampling observes the same owned source without forcing shrink factories.
(def samples (property.inspect-generator rows row-domain seed: 42 count: 10 size: 8))
;; The global proposal quota is shared by all root trees.
(def tree (property.inspect-generator rows row-domain seed: 42 count: 3 size: 8
  depth: 3 proposal-budget: 50 labels: (lambda (_) '(packet))))
(property.inspection-events tree)   ; #(path kind value) entries
(property.inspection-attempts tree) ; returned proposals, including tombstones
(property.inspection-counts tree)   ; admitted-root empirical labels only
```

Paths start with the zero-based root index and append returned child indices.
Events distinguish `root`, `value`, `pruned`, `outside-domain`, `nondecreasing`.
Only valid decreasing children authorize expansion. `inspection-status` is
`complete` after requested roots, or `error`/`stale`/`exhausted`/`unsupported` on
interruption; `inspection-cause` retains the original exception. `inspection-count`, `inspection-depth`, and `inspection-budget` retain the
requested bounds. `inspection-draws` counts attempted calls to generate, including an interrupted call, rather than
individual PRNG requests or internal filter retries. `inspection-truncated?`
conservatively marks unexpanded neighborhoods, even at depth zero. It is not a
minimality verdict. Event count is at most count + proposal-budget; EOF is free,
a returned stale proposal is charged, and zero fuel/depth never forces children.
Labels are counted once per admitted root and cannot satisfy property coverage.

POO's `testing/type` module exports the same operation over an existing sampler:
`(inspect-generator (generator descriptor) seed: 42 count: 3 depth: 2 proposal-budget: 20)`.
The returned generic inspection retains the sampler's Type/source stamps.
Use `inspection-current?` before treating old diagnostics as current; rebuilding a
sampler after a supported revision is explicit. These are caller-owned diagnostic
values, not portable counterexample reports. See the dependent packet inspection
and interruption controls in `examples/property-kernel.ss`.

## Default POO test and debug workflow

PBT is built by default and included in complete acceptance. Import
`:clan/poo/support/testing` with a local prefix alongside `:std/test` to use
`(pbt.check-property descriptor predicate seed: 42 cases: 100)` or
`(pbt.define-property name ((argument descriptor) ...) boolean-body ...)`.
Named arguments are a fixed Tuple of Types, using the existing typed generator.
Dependent/refined domains continue to compose explicit generators, including
Record construction and Function wrapping. The helper executes one standard
check; all refusal/error statuses become TestError with original diagnostics.
`testing/type` still owns the report-returning API for inspection and replay.

`PropertyConfiguration` in that Type module is initialized with ordinary
`make-instance`. Defaults are seed 0, cases 100, size 20, shrink budget 100 and
the existing recursion limits. A procedural size requires `size-limit:`; a fixed
size uses its own bound when no explicit limit is supplied. The Record validates
field Types while the runner enforces trial/quota constraints. Existing Reader
actions now declare the configuration as a revision source automatically.

Import `property-debug-action` from `:clan/poo/debug`, prepare the action once,
and call it with a PropertyConfiguration Record. DDT formats report diagnostics
when the tag is enabled and preserves the returned report. With tag #f the run
still happens exactly once and no rendering occurs. Failed data remain available
for the same shrinking and replay protocol. Debugging does not assert a passing
property. See `examples/generated-batches.ss` for the full Record/FUN workflow.
The installed CLI exit-status caveat described above still applies; project
acceptance retains its existing error admission guard.

## Retained structural shrinking

`generator-list` chooses its length once, then composes retained element sample
nodes through `sample-sequence`. Structural candidates delete aligned blocks,
halving block widths down to every single position before coordinate shrinking.
`min-length:` constrains length, not which prefix must survive. Input list spines are snapshotted; retained elements
keep their identities/preimages; deletion never draws replacement values. String,
Symbol and byte-vector families inherit the same tree policy through map.

`list-deletions` is the lazy value/subsequence policy; `list-deletion-count`
counts its finite proposal positions without inspecting payloads. Equal values
at different positions remain distinct proposals because provenance may differ.
Fixed-length sequences have no deletion candidates. Every resulting node gets
structural shrinking again after a coordinate step. Deleted branch observers
remain attached to descendants and stale replay is refused.

Typed recursive Lists and nullable carriers use the same sample-tree operation;
Tuple/Pair/Union constructors retain their mandatory arity. Value-only List
shrinking uses the same deletion policy and refuses before materializing a batch
larger than the remaining construction quota. No candidate list is silently
truncated. Core lazy proposals still use the ordinary property/inspection budget.
This is finite operation coverage, not a promise of global minimality. Mapping
and arbitrary callback execution retain their own cost/purity obligations.

Recursive collection callbacks reserve structural deletion work before walking
child shrinkers. Exhausting that shared construction quota refuses with `search`;
a completed batch exceeding the candidate ceiling refuses with `candidates`.
Both retain the original false witness, refuse a minimality claim and replay the
exact failure kind. The six-element/15-token regression and a four-element input
distinguish work exhaustion from cardinality exhaustion without relaxing
either quota. Lazy sample children are consumed with standard `for` and a lexical
`let/cc` escape, preserving short-circuiting without materializing the Iterator.

## Source-current typed corpus handoff

Use the existing modules directly; application codecs carry only logical data:

```scheme
(import (prefix-in :clan/poo/testing/type typed.)
        (prefix-in :clan/poo/testing/property/replay corpus.))
(def codec (corpus.make-codec '(batch 1) encode-batch decode-batch
  current?: batch-schema-current?))
(call-with-output-file failure-path
  (cut typed.write-counterexample failed-typed-report codec <>))
(call-with-input-file failure-path
  (lambda (port) (typed.read-counterexample sampler codec port batch-correct? policy: batch-policy)))
```

`decode-batch` uses ordinary Record construction to restore validation and Function
wrapping, not serialized closures. See `examples/generated-batches.ss` for an
executable downstream FUN/debug-to-corpus workflow. Import returns the property's
Boolean result, with no sampling or shrinking. A stale sampler/codec refuses before
decoding; a decoder that invalidates either source refuses before property effects.
Both stages check sources after a normal return. Callback exceptions keep their
original cause. Export rejects source changes during preparation before writing
any bytes. Ordinary port failures remain ordinary I/O failures and may leave a
partial write; applications own durable file replacement and codec semantic laws.

### Concrete witness policies

`read-counterexample` in both the generic replay and typed sampler modules accepts
`policy:` (the existing `make-policy` record). Supply the same semantic precondition
used by the property and include its interpretation in codec identity. If omitted,
the normal always-eligible default applies; no policy closure is decoded from disk.
`check-counterexample` in the property module is the shared Boolean witness path.
It performs guarded precondition/domain/property calls, not a generation run.
Rejected or non-Boolean preconditions cannot reach recognition or property effects.
Labels, coverage thresholds, PRNG state, size policies and shrinking are untouched.
Seed replay still owns complete generation/coverage behavior. See
`examples/generated-batches.ss` for the Record/FUN-to-corpus policy workflow.

## Callback stage admission

Producer, map/filter, dependent-selection/drawing, size/delay construction and
sequence packing reuse one source bracket in the existing generator module.
A normally returning callback that revises its declared sources raises the existing
stale-generation refusal before dependent work. An exception keeps its original
identity; no post-return observer masks it. Flat leaves, sample trees, child seeds
and resource budgets are unchanged. Dynamic sample leaves still belong to their
node/consumer admission; this does not certify undeclared mutable payloads or
undo effects already performed by a callback. Observers must be pure and accurate.

See the 41-case independent `examples/property-kernel.ss` and the Record/FUN repair
workflow in `examples/generated-batches.ss`. The latter explicitly rebuilds a sampler
after revision rather than silently refreshing an old generation closure, performs
real shrinking and checks that concrete replay draws nothing while seeded replay
repeats the full dependent construction schedule.

Inherited source lists use Gerbil's standard dynamically scoped parameter inside
this same boundary. Selected child graphs see parent leaves before their own
mapping/selection callbacks. Already shared context identities skip a new dynamic frame; no
parameter environment leaks after success, refusal or exceptions. `generate`
retains the inherited leaves on its returned node for later lazy consumers.
The source-union laws justify joint parent/child admission. Regression controls
cover nested child maps under bind, size, delay and an advanced producer, and
confirm an unrelated draw remains valid after an interrupted context unwinds.

Standard value generators capture the invocation's inherited leaves in their
recursive sample factory. Separately retained lazy children therefore keep those
leaves after dynamic scope unwinds. Advanced handwritten sample producers retain
their existing obligation to declare accurate source leaves for their own nodes.

## Finite-key HashTable / Map workflows

```scheme
(import (prefix-in :clan/poo/testing/property/generator gen.)
        (prefix-in :clan/poo/testing/type typed.))
(def counts (gen.generator-integer 0 8))
(def partial-table (gen.generator-hash '(read write audit) counts domain-limit: 3))
;; With the ordinary POO Type/number modules imported:
(def map-type (Map (Enum read write audit) -> UInt))
(def sampler (typed.map-generator map-type '(read write audit) (typed.generator UInt)))
```

`generator-hash` copies/validates its finite domain once, draws only selected values
and materializes fresh standard tables from retained sample nodes. Structural
shrinks delete entries without redrawing; value shrinks keep keys. Size bounds the
number of entries, not arbitrary callback execution or bytes. Hash key payloads
must remain stable while used as keys; mutable payloads are not deep-frozen.

`map-generator` reuses the existing Map validator and Record sampler contract.
Value sampler descriptor identity must match the Map's Value; key validation must
be representation-preserving, not an implicit key normalization. `dependencies:`
declares application source objects and `domain-limit:` bounds admitted keys.
Its currentness hook remains tied to preparation; a revised sampler requires explicit
new preparation. Value measures must accept the validated value representation.
No automatic arbitrary Map/Record derivation is claimed. A custom refinement that
rejects generated subsets is a domain error unless the application supplies a
suitable explicit generator/filter; it is not silently retried.

See `examples/generated-batches.ss` for a Record/FUN workflow containing Maps of
Records with Functions, an aggregate falsification, structural/value shrinking,
zero-draw inspection, source revision/refusal, fresh retry and portable logical
entry encoding. Codecs own logical field/format identity and restore ordinary
validated Records; they do not serialize hash order or closures.

Finite declared alternatives use `generator-elements`, for example
`(generator-elements '(read write admin))`. Its lazy index tree simplifies toward
earlier declarations without redrawing. Use an explicit natural rank in a generic
specification. POO `Enum` derivation supplies its existing first-occurrence index
as that rank, including nested collections and replay. Empty Enum is uninhabited;
an empty generic alternatives list is a constructor error.

Generic model users supply `(shrink-trace model commands shrink-command)` from
`:clan/poo/testing/property/model` as their ordinary generator's shrink callback.
It shares collection block/coordinate proposals, then repairs dependent commands.
POO `trace-generator` uses the same policy automatically. No draws or actual
fixture transitions run during candidate preparation; model callbacks remain
explicit and finite. The runner still checks each repaired proposal's domain,
strictly smaller measure and falsification before accepting it.

Policy preconditions and each fixed product field are separate source-checked
stages. A precondition that revises a declared dependency stops before property
entry, including during shrinking. A product field that invalidates any captured
domain stops before later fields. Reports retain the previous witness and charged
proposal count; fresh execution is required after revision. Pure stable observers
and explicitly declared dependencies remain caller obligations.

Portable export rechecks codec and report sources after witness reconfirmation,
before encoding. Import preflights codec and specification sources before reading:
a stale prepared codec leaves input untouched. Prepare a new codec after its
revision changes; old codec instances remain refused. Normal Record constructors
restore Function wrapping during decode. Once actual port I/O starts, errors may
leave consumed input or emitted output; source checks do not provide rollback.

Lazy child iterators may be paused, but each resumed pull still checks its owned
sources before producer effects and after normal return, including EOF. A retained
`bind` descendant carries the original branch's source leaves as well as its new
branch. Lifting it into a new typed sampler cannot refresh those epochs. Generate
a new root when sources change. The implementation reuses standard Iterator/for
and the existing source boundary; source-free traversal keeps its direct loop.

Independent `generator-sequence` products now retain every field's original sample
while shrinking another coordinate. They share `sample-sequence` at a fixed width;
List/hash roots share the same capture helper and keep their structural policies.
For example, a stateful second producer is drawn once: `(2 1)` shrinks to `(0 1)`,
not `(0 2)`. Repeating child traversal or concrete replay draws nothing. Seed
replay starts a new run and draws fields again. Use `generator-bind` or
`bind-generators` when a later field actually depends on an earlier field; those
selected children must still be rebuilt. Existing guards, budgets and mutable
payload ownership apply unchanged. See P18 of the RFC for laws and cost limits.

Call-input derivation now follows demand. `generator (FunctionArguments fn)`
captures declarations without forcing a generator for an omitted input or a
shadowed clause. Required/supplied optional/keyword/rest values use the actual
first selected clause. Their Type generators are prepared once on successful
demand through the existing `defonce`, and draw a fresh value for each occurrence.
A selected unsupported Type still raises its original cause; it never becomes
Any or triggers a type-based branch fallback. Unforced Type revisions and forced
child dependencies still invalidate old reports. See P19 of the RFC and the
keyword/rest/multiple-return FUN workflow in `examples/generated-batches.ss`.

Typed `check-trace` now binds one execution to captured model and fixture
**declarations**. Actual State still evolves; replacing a step/observer, editing
its declared Type or changing model metadata refuses subsequent stages through
the existing stale-generation signal. A revision after `use` returns also refuses
publication. Original exceptions and first-difference diagnostics remain intact,
and the caller's ordinary scope owns cleanup. Retry prepares a fresh execution;
there is no backend rollback. See P20 in the RFC and the indexed-collection/FUN
revision example in `examples/generated-batches.ss`.
Fixture epoch checks end with `use`, so teardown may normally retire its methods;
model declarations remain checked until the fixture factory returns.

`specification-weight` evaluates an already appropriate value with the domain's
checked natural measure. It shares the runner's measure implementation and source
checks; it does not repeat recognition or generation. Product specifications can
name a `current?:` owner, including for zero fields. Typed `product-generator`
uses this same domain, captures its child directory once, and shares its guard
with raw coordinate shrinking and retained-tree packing. Parent/child revision
stops later callbacks, while fresh construction is the explicit retry boundary.
See P21 of the RFC and the Record/Function/FUN product workflow in generated-batches.

Fixed `generator-sequence` fields now own their declared source leaves before
the first draw. A stale later field makes `generator-current?` false and refuses
generation before randomness or any earlier field effect. Nonempty finite Function
tables share that product admission; empty result domains and unselected dynamic
branches remain independent. Draw seeds, retained shrinking and replay do not
change. Use explicit fresh preparation after a revision; reopening an old sampler
does not refresh it. See P22 and the Record/FUN retry example in generated-batches.

`generator-filter` carries every previously rejected branch's declared sources
into later drawing, selection and mapping through the same source scope. A retry
that revises an earlier owner cannot continue construction after that callback.
Its exact local attempt count, fixed size, random schedule, shrink tombstones and
original exceptions are unchanged. Prefer constructing the intended domain when
possible; filter keeps bounded generation and Type admission. Nested
filters retain separate local quotas. See P23 and the Record/FUN workflow for
fresh retry, wrapped Function shrinking and source-consistent replay.

To copy the independent worked suite into another standard Gerbil project, include
`examples/property-kernel.ss`, `examples/property-products.ss` and
`examples/property-filters.ss`, `examples/property-scopes.ss` and `examples/property-sizes.ss` alongside the generic modules. The small
functional groups register cases in the kernel's existing `:std/test` suite;
the isolated package acceptance builds all ordinary helper modules and executes
79 cases without installing POO.

Checked property actions now install a run-local `with-generation-check` scope
from the generator module. A nested draw/map/selector/iterator cannot continue
after retiring a source already observed by an earlier trial or replay. The
existing action still owns stale status, original causes and proposal accounting.
Checks are zero-argument assertions that raise or escape on refusal; binding the
scope alone does not evaluate arbitrary body code as a new property runner.
They are never added to sample source lists. New replay reports therefore keep
their own observed ownership, and twelve repeated replays have stable observer
work in the regression. See P24 for the model/continuation and cost boundaries.

Known-input size scaling retains input sources before any scale callback or
sibling draw. Use the ordinary resize/scale combinators; do not add a second
currentness wrapper in the typed layer. See P25 for dynamic selection boundaries,
invalid-size causes and Record/FUN replay controls.

`generator-sized` accepts `sources:` for declared common leaves, just like the
base constructors. The list family uses this when a positive minimum guarantees
element participation. String/Symbol reuse it without another validator. A zero
minimum leaves unused element owners unobserved. P26 records callback/seed,
shrinking, wrapped Function, replay and explicit revision retry controls.

Every returned proposal, including a filtered tombstone, admits its newly observed
sources before terminal-budget publication. A stale node cannot be reported as a
completed false search. Returned nodes still consume one token; EOF and iterator
errors consume none. See P27 and the Record/FUN example for identity-sharing delivery, producer-side refusal,
concrete/seed replay and explicit fresh retry.
