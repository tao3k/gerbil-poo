# RFC: model-driven collection property tests

- Status: finite V1 and P0–P30 implemented within the finite domains below; CI is checked per revision.
- Date: 2026-10-27.
- Targets: Gerbil-POO PR #13 and Lean-POO PR #13.
- Implementation acceptance: reusable protocol, collection controls and downstream integration are implemented; CI is checked independently for each submitted revision.

## Module ownership and independent-library boundary

The generic library uses ordinary modules under `testing/property`, with direct
imports. The runner is `testing/property.ss`; generator, model, replay and test
support live in `testing/property/`. The root `defbuild-script` builds them with
all other package modules. There is no separate package or forwarding facade.

| Module | Responsibility | Dependencies |
| --- | --- | --- |
| `testing/property/generator.ss` | Invocation-local random sources, unit/map/bind/sequence, lazy value-and-shrink provenance | Gerbil standard library |
| `testing/property.ss` | Explicit domain specifications, finite checks, bounded child consumption, reports and both replay forms | Generic generator module and standard library |
| `testing/property/test.ss` | Standard check registration, named argument binding and source-aware diagnostics | Generic property/generator modules and :std/test |
| `testing/property/replay.ss` | Bounded portable witness data with explicit codec identity | Generic property/generator modules and standard ports |
| `testing/property/model.ss` | Pure model folds, dependency retirement, bounded trace draw, scoped first-difference comparison | Generic generator module and Gerbil standard library |
| `testing/type.ss` | Type-driven derivation, Record contracts, bounded membership, POO source observations, typed reports and Reader/FUN actions | POO and generic modules |
| `testing/function.ss` | FunctionArguments derivation from checked signatures | POO function/signature modules and testing/type |
| `testing/generation-graph.ss`, `testing/recursive-generation.ss` | Bounded descriptor graph compilation and safe recursive derivations | POO type/recursive constructions |

Top-level `property-testing.ss`, `function-testing.ss`, `generation-graph.ss` and
`recursive-generation.ss` are moved, with all importers/build inventories migrated.
There are no compatibility forwarding files. Existing `support/testing.ss` and
`t/table-testing.ss` keep their distinct support/test-only ownership.

The generic modules import no POO object, Type, Record, lens or revision APIs.
Their records are Gerbil structs; domain admission and cost are mandatory caller
callbacks. POO retains its Record declarations and supplies bounded typed
admission, normalization and source-current callbacks at the boundary. Generality
is parametric; it is not a fallback to an unconstrained POO `Any` descriptor.

The independent-library acceptance copies these five generic source modules and
`examples/property-kernel.ss` and its ordinary product/filter/scope/size/trace helpers
into a temporary standard Gerbil package, declares
`clan/poo/testing`, and compiles with `defbuild-script`. The compiled suite runs
through `gerbil test`. It requires all 92 case receipts, an error-free result and
correct process exit status under the existing heap and timeout limits. The
isolated installation has no object, MOP or typed testing modules. Sharing a
module path does not import parent modules. This demonstrates code dependency
independence; it is not an upstream publication.

## Checked actions and interrupted shrink receipts

The execution layer uses one private hygienic `with-current` form around domain
actions. It evaluates an action once and checks its declared sources before and
after it. Admission, strictly decreasing cost and Boolean falsity compose as
short-circuiting judgments. The search driver handles only proposal consumption
and confirmation; it no longer duplicates source checks around each callback or
passes positional progress vectors between nested loops. A single invocation-owned
Gerbil record holds the confirmed witness and counters. POO retains its existing
Record report projection and Reader/FUN report delivery.

Every returned non-EOF proposal is charged before admission, measurement, property
execution or the trailing source check. EOF and an iterator exception return no
proposal and add no attempt. A candidate is confirmed only after all judgments
and freshness checks succeed. Thus an interruption retains the previous confirmed
witness, charged attempts, accepted steps and the original exception. It reports
`error`, `stale` or the caller's explicit refusal classification, never a new
`failed` witness or a minimum. An error in a source observer while classifying an
earlier error cannot replace that original cause. Error/stale reports keep useful
progress but cannot authorize concrete counterexample replay.

This follows the existing FUN/IO style of composing owned actions and the Racket
libraries' separation of lazy shrink trees from property execution. It does not
copy Rackcheck's `pass?` exception-to-falsified policy: our RFC keeps host errors
separate from Boolean false. Gerbil's existing Iterator/in-coroutine protocol
remains the lazy representation. No new stream framework, scheduler, namespace or
POO dependency is added to the generic library. Filtering is not allowed to hide
proposal consumption or introduce unbounded search between budgeted attempts.

The independent example interrupts child creation, iteration, admission,
measurement, properties and observers after a confirmed reduction. It checks
cause identity, original/reduced values, counters, seeded replay and stale replay
refusal. The typed Record example delivers the same receipt once through FUN.
Lean's finite `auditShrinks` distinguishes failed returned proposals from iterator
exceptions. `auditShrinks_budget`, `interrupted_shrink_preserves` and
`callback_error_retains` reuse the established shrink laws to prove accounting,
retained validity/falsity and exclusion of the pending failed proposal. Runtime
callback termination, source-observer accuracy and PRNG behavior remain premises.

## Canonical trace admission and execution

Whole-prefix admission retains its exact normalized command list. The generic
model previously checked normalized commands but executed the original inputs;
POO's prevalidated List path concealed that discrepancy. `prepare-trace` now
reuses the existing model fold to return either the complete prepared list or
refusal. `valid-trace?` is its Boolean projection. `check-trace` executes and
reports those same prepared command objects, without another normalization pass.
An empty prepared list succeeds; refusal is separate from a command whose payload
is false. No prepared prefix is handed to a fixture after a late rejection.

The typed facade still owns its existing List/Record/Function validation boundary
and supplies the identity normalizer to generic execution. This preserves nested
Function wrappers without installing an additional wrapper chain in the kernel.
Dependency repair uses the same model fold; shrinking and both replay forms use
the ordinary property runner and fresh scoped fixtures.

`examples/property-kernel.ss` combines shared producers, normalized contracted
callbacks, dependency repair, a faulty consumer, shrinking and both replays.
Separate late-domain/normalization-failure controls require zero fixture opens.
The POO Record regression rejects an invalid callback argument before its body
and refuses a missing producer before opening a fixture. Callback setup/cleanup
remains balanced on both success and errors.

Lean's `prepareTrace_sound` proves successful preparation preserves decoded
order, input length and state-dependent validity. `prepareTrace_identity` covers
the typed facade's already-normalized path; `prepared_observations` states the
exact execution handoff. The concrete collection example decodes command codes
through the existing conflict, inverse, stale and retry lifecycle and refuses a
malformed final code. These are pure finite laws: truthful normalization, model
callback purity/termination, runtime wrapping and the fixture simulation premise
remain separate executable obligations.

## Next acceptance units

Audit date: 2026-10-28. Scheme source: `bb9729df2aa23a90869924c88e1f860cfd7f9991`.
Lean proof source: `d4654df01516b134de6ce4171f961241795107ea`.
These revisions identify the audited implementations; the historical receipts
below keep their original source identities.

The finite V1 checklist is not a claim of feature parity with Racket. Its
dependent generation, lazy shrinking, source checks, normalized model traces,
dependency retirement and replay already exist. The current Lean source also
contains `mapped_candidate_preimage`, `dependentCandidates_relation`,
`forceChildren_bounded` and interrupted-shrink preservation, in addition to the
trace laws. Do not describe these as missing implementations or proofs.

The comparison retains the two pinned Racket sources in the following section.
Rackcheck's [core combinators](https://github.com/Bogdanp/rackcheck/blob/ffbddb7a9edef6ce1d9e0930adae1bd7033f1db7/rackcheck-lib/gen/core.rkt)
include choice, size control and shrink control; its
[base generators](https://github.com/Bogdanp/rackcheck/blob/ffbddb7a9edef6ce1d9e0930adae1bd7033f1db7/rackcheck-lib/gen/base.rkt)
compose those operations. Quickcheck's
[generator algebra](https://github.com/ifigueroap/racket-quickcheck/blob/0b6902d8d79973ec959f99e56ccba038beca8fe9/quickcheck/private/generator.rkt)
separates bind/sequence from its binding syntax. The next work should extend our
existing algebra and modules rather than import a second runner or framework.

### P0: composable generation through the typed boundary

Original P0 finding (now resolved): generator composition was not retained through
the typed product boundary and size was constant. The implemented protocol below
records the shared tree algebra, typed integration and bounded size policy.

Complete one unit across the existing generator, property and Type modules:

- Add explicit choice/weighted choice and sized/resize/scale operations, plus
  bounded delayed construction and shrink control on the SAME lazy sample tree.
  Introduce bounded filtering only with explicit attempt accounting; construct
  valid dependent inputs directly where possible. Do not hide descriptor errors
  by retrying them or count a refused draw as a successful property test.
- Let typed sampler composition retain the core tree and captured branch sources,
  while keeping Type recognition/wrapping and revisions at one existing boundary.
  Reuse the bounded recursive derivation rather than replacing it.
- Provide one hygienic dependent-binding form lowering to existing bind/map,
  and a thin named-property form usable inside ordinary `:std/test` suites.
  The generic package retains standard Gerbil records; the POO layer retains
  its existing Record contracts. No new module facade or testing namespace.
- Permit an explicit bounded per-trial size policy and retain the failing trial's
  actual size for seed replay. Validate size results and observe policy sources;
  a size policy must not evade depth, node, search or shrink budgets.

Acceptance uses a downstream typed batch whose declared length determines its
payload, with weighted operation alternatives and inherited descriptor revisions.
Exercise ordinary checks, a real injected fault, dependent shrinking, unchanged
replay and stale-source rejection through the same FUN/IO flow. Retain the
existing non-injective-map and zero-fuel controls. Include rejected weights,
empty choices, filter exhaustion and invalid size policies. Extend the existing
Lean namespace with finite choice-membership, size/budget and provenance laws;
do not substitute a PRNG-quality or host-termination claim. Compare preparation,
draw and shrink costs with the current protocol under equal workloads.

### P1: effective-trial coverage and property diagnostics

Original P1 finding: reports had trial counts but no effective-trial classification
or coverage requirements. The new run-owned policy closes this finite protocol.
Collection examples currently guarantee required lifecycle coverage with explicit
prefixes; the generic runner does not infer that guarantee from random suffixes.

Build on [Rackcheck labels](https://docs.racket-lang.org/rackcheck/index.html)
and [Quickcheck classification/configuration](https://docs.racket-lang.org/quickcheck/index.html):
add run-owned classifications, effective-trial counts, explicit coverage
requirements and useful named-property failure context in `:std/test`. Coverage
requirements are our proposed admission policy, not a claim that Rackcheck's
labels enforce thresholds. Explicit precondition discard, if added, has a separate
finite budget; errors, stale sources and Type violations retain their meanings.
All-discard or unmet required coverage must not become a passed run. Shrink probes
and replay must not inflate generation coverage. Prove finite counter accounting
and coverage admission under explicit classification premises.

### P2: portable counterexample replay

Live reports retain generators, callbacks and source observers for in-process
replay. The new explicit codec complements them with portable finite data.
Add explicit application codecs for finite data commands and logical handles,
plus specification/generator identity checks before opening a fixture. Use Gerbil
ports and ordinary Scheme data; do not serialize closures, infer fresh-object
identity from an old revision number, evaluate stored code, or automatically
commit generated corpora. Test a fresh-process replay, codec refusal, changed
specification refusal and cleanup on failure. Codec round-trip and finite replay
correspondence are conditional laws, not proofs of arbitrary host serializers.

### P3: bounded higher-order Function values

`testing/function.ss` generates Function ARGUMENT ROWS. Finite function values
now belong to the generic generator algebra; arbitrary procedures remain outside
the decidable domain. Quickcheck's documented
[`arbitrary-procedure`](https://docs.racket-lang.org/quickcheck/index.html) identifies
a separate useful capability to study after P0-P2. Start with explicit finite
pure input domains, bounded memoization/equality and result generators, then use
existing Function contracts. Repeated equal inputs, multi-value results, keyword
interpretation, shrinking and stale-source refusal need joint acceptance.
Opaque/effectful callbacks and unrestricted higher-order inference remain explicit
boundaries; neither `Any` nor a universal function-correctness claim closes them.

P1-P3 share the existing runner; acceptance covers the following finite contracts. Each unit needs executable downstream examples,
fault controls, finite Lean laws and the complete existing checks in both PRs.
Concurrent linearizability, arbitrary callback termination, compiler verification
and automatic unrestricted Type derivation are not defects in this finite V1.

### P0 implemented protocol

The existing generator module now owns choice/frequency, sized/resize/scale,
bounded delay/filter, shrink-policy control and `bind-generators`. It retains
the same lazy sample/provenance representation. Filtered child branches yield
charged pruned proposals rather than secretly searching behind the shrink
consumer. Pruning defines a smaller supplied neighborhood, not global minimality.

The property module adds an ordinary callable `define-property` binding and
per-trial size policies with a mandatory explicit `size-limit`. Constant size
arguments retain their own default bound. Invalid sizes refuse before drawing;
the report retains the trial's resolved size and the original policy/observer.
Concrete witness replay calls no size policy. An interrupted policy retains no
previous trial size as evidence for the current trial.

`testing/type.ss` keeps its Record contract and owns `from-generator` /
`generator-core`. Typed products and Function rows delegate sample composition
to the generic core. Recursive derivations retain scalar sample trees, with
structural shrinking reattached after every accepted product shrink. Replacing
a sampler's draw/shrink callback retires its inherited tree binding. An explicit
value-only shrink callback remains necessary when no original sample is available;
neither cached output lookup nor an inferred inverse substitutes for provenance.

`examples/generated-batches.ss` covers weighted routes, length-dependent payloads,
Record-owned nested Function wrapping, Reader/FUN, bounded size scheduling,
recursive Tuple/Pair carriers, Function argument rows, both replays and stale
configuration refusal. The stdlib-only generic example now has twenty independent
cases; no POO import is needed for that project.

`LeanPoo/Functional/PropertyGenerators.lean` extends the existing PropertyTesting
namespace with finite weighted-selection membership/totality, scheduled size
ownership, delay-force bounds and charged-pruning preservation/budget laws.
Top-level `Examples/PropertyGenerators.lean` has positive and negative controls.
These augment the existing map/bind/provenance and trace laws; they do not prove
host PRNG quality, callback termination or generated semantic properties universal.

`just benchmark-generators` reuses the existing shared executable and paired
measurement helpers. Preparation, reused drawing and complete failing workflows
have AB/BA, A/A and B/B controls, natural GC and charged post-GC first calls.
The common injective fixture admits both callback and tree strategies; it is not
a claim that output-only shrinking can recover arbitrary mapped inputs.

## Quickcheck and Rackcheck source comparison

The source references are pinned independently of the local compiler:

- [Racket Quickcheck](https://github.com/ifigueroap/racket-quickcheck/tree/0b6902d8d79973ec959f99e56ccba038beca8fe9):
  `quickcheck/private/generator.rkt` combines return/bind/sequence and splits the
  random source; `quickcheck/generator.rkt` expands `bind-generators` into that
  algebra. Ordinary Racket generators do not require Typed Racket.
- [Rackcheck](https://github.com/Bogdanp/rackcheck/tree/ffbddb7a9edef6ce1d9e0930adae1bd7033f1db7):
  `rackcheck-lib/gen/core.rkt` maps and binds shrink trees, retaining a child random
  state for dependent regeneration; `gen/base.rkt` builds lazy list shrink trees.

We adopt composition of generated values AND their provenance. A non-injective
map retains its preimage tree without asking for an inverse. Bind first explores
parent shrinks, regenerating each dependent child with the same captured child
seed, then explores that child's own shrinks. Gerbil's standard `in-coroutine` /
Iterator protocol provides lazy children; no thread, custom stream framework or
process-global sample cache is introduced. Seed splitting follows the compositional
idea, not byte-for-byte random sequence compatibility with either Racket library.

A generic generator and its intermediate shrink nodes must honor its declared
semantic domain; a malformed selector/callback is an error, not a false property.
The final property specification explicitly admits values and supplies a natural
measure. POO-specific generation-refusal classification stays in testing/type.
The kernel never classifies an exception as a passed or falsified property.

Source freshness is rechecked after iterator EOF before certifying exhaustion.
Zero shrink fuel invokes no shrink callback. A child is pulled only inside the
budgeted consumer body; no tail lookahead occurs after the final allowed attempt.
`minimal?` requires observed EOF and certifies only the supplied immediate
neighborhood. POO-derived raw shrink callbacks keep their finite proper-list
contract at one boundary; their own preparation cost remains subject to the
existing graph/search budgets and process guards.

Reports retain observers for all generated trial roots and forced shrink branches,
including earlier successful trials and rejected candidates. A changed original
branch cannot become authorized merely because the final witness moved elsewhere.
Seed replay keeps those observers live throughout rerun, and the new report owns
only the rerun's observations rather than accumulating replay closure chains.
Concrete replay performs no draws, selectors or child forcing. Observer accuracy,
callback purity/termination and runtime PRNG correctness remain explicit premises.

## Decision

Extend the existing descriptor-driven property-testing protocol with finite,
state-dependent command traces. Reuse its generator objects, PRNG ownership,
strict shrinking, revision admission, reports and Reader/FUN integration.
Use `:std/test` as the downstream test runner. Do not introduce another runner,
DSL, package namespace, scheduler, module loader or serialization framework.

The first complete unit exercises declarative unique indexes and persistent table
deltas: conflicting installation, successful installation, inverse recovery,
stale collection metadata/deltas and explicit repair/retry. It provides a reusable
trace protocol plus an executable collection example, rather than one hard-coded
random test or a general runtime/FFI verification framework.

## Source basis and existing capabilities

The author's [I/O Validation and Beyond discussion](https://github.com/metareflection/poof/blob/9affa8fbbb4f12cbd98cb97f8b8b84474fc39429/poof.scrbl#L1361)
explicitly includes pseudo-random value generators and value compressors among
type-descriptor operations. His dictionary examples compose algorithms through
final-self extension points. Stateful trace generation and dependency-preserving
shrinking are proposed extensions of that direction, not algorithms claimed to
already exist in the Racket listings. The fixed-point use of the word generator
elsewhere in the paper is distinct from a pseudo-random test sampler.

| Existing owner | Reused responsibility |
| --- | --- |
| `testing/type.ss` | Typed generator/product preparation, Type/source admission, report projection and `property-action`; execution delegates to the generic modules |
| `testing/generation-graph.ss` / `testing/recursive-generation.ss` | Existing bounded recursive value generation; not replaced by a second recursion engine |
| `Type`, `List`, `Tuple`, `Union`, `Exactly`, `Enum` | Command and trace membership; no `Any` fallback |
| Existing table/index protocols | `.delta/opt`, `.apply-delta`, `invert-table-delta`, index observations and supported metadata invalidation |
| FUN / IO and `:std/test` | Composition, fixture resource lifetime and ordinary suite discovery/checks |
| `LeanPoo.Functional.PropertyTesting` | Shrink admission, descent, retained falsity, budgets and stale-evidence laws |

The audit used Gerbil commit `7b2ead60d52c3648a26e65ca149636f5ab6f39dc`
and Lean commit `7f2f71e1463b99151f23994d1b1fcc1acd5a7696`. Uncommitted
representation/cache work is outside the audit and must not be overwritten.
See the existing `generated-testing.md`, `recursive-generators.md` and
`table-indexes.md` in each repository's documentation directory.

## Scope and explicit boundaries

V1 uses finite, sequential command traces, pure reference-state transitions,
explicit logical handles and finite canonical observations. Commands are owned,
stable data values. Every trial, shrink probe and replay gets a fresh actual
fixture. Model hooks and observation callbacks must terminate and produce finite,
stable values; process watchdogs and heap limits remain necessary.

The initial oracle uses ordinary association lists and logical receipt records,
independent of the implementation's indexed table algorithms. It must not call
`.apply-delta`, index construction or inverse application to compute expectations.
An oracle is fallible: Lean proves stated source-model laws, not the complete
Scheme implementation, compiler, collector or physical memory behavior.

Concurrent scheduling, arbitrary FFI pointer graphs, universal callback synthesis,
portable closure serialization and automatic contract/law discovery are outside
this unit. The first collection adapter qualifies the pure protocol on two
existing backends. Other ownership styles require their own execution/ownership
checks; pure results alone cannot certify mutable or linear publication.

## Proposed public surface

These are proposed signatures, not claims about the currently released API.
The typed entrypoints are in `clan/poo/testing/type`; generic execution is
owned by the directly imported `clan/poo/testing/property` modules above.

```scheme
(trace-generator command-type model steps: 64 dependencies: [])
(check-trace model commands with-system same?: equal?)
(trace-property model with-system same?: equal?)
(replay-counterexample report)

(property-action descriptor property consume
  sampler: #f dependencies: [])
```

`trace-generator` returns an ordinary `make-generator` object. Its descriptor is
`(List command-type)` and its `.accept?` additionally validates state-dependent
prefixes. Callers use that exact descriptor identity with `check-property`.
`trace-property` only turns `check-trace`'s explicit comparison result into the
Boolean required by the existing runner. `replay-property` retains seeded replay;
`replay-counterexample` executes the stored concrete witness without drawing or
shrinking it. `property-action` gains the same supplied-sampler/dependency inputs
as `check-property`, retaining the existing Reader/FUN chain.

The existing `Record` contract defines `TraceModel`; `TraceGenerator` inherits
that contract and adds generation/shrink hooks. Construct models with
`make-instance TraceGenerator`, retaining normal POO field initialization and
validation. No separate model interpreter or package namespace is introduced.

`Command`, `State`, `Result` and `Observation` are explicit Type descriptors.
The transition boundary validates dependent state/results and the comparison
boundary validates observations. Callable fields recognize procedures; they do
not infer host arity or termination, or preempt the shrinker's candidate gate.

The model exposes these extension points:

| Field | Contract |
| --- | --- |
| `initial` | `() -> reference-state`; returns a fresh pure state |
| `enabled?` | `(state command) -> Boolean`; whether this prescribed operation is admissible now |
| `advance` | `(state command) -> (values next-state expected-result)`; pure, deterministic transition |
| `observe` | `(state) -> stable finite canonical observation` |
| `draw` | `(state random size) -> Option command`; `some` carries a command, `#f` ends the trace |
| `shrink` | `(command) -> finite proper list of parameter candidates` |
| `measure` | `(command) -> natural number`; parameter complexity |

A false command, when allowed by its Type, is `(some #f)`, not end-of-trace.
Hook exceptions are errors, not disabled commands. Non-Boolean preconditions or
comparisons are errors rather than truthy successes. Invalid command descriptors
or callback configuration refuse before actual fixture effects.

`with-system` is a scoped fixture function, `(use -> result)`. It creates a fresh
actual system, calls `use` once and owns cleanup through standard call-with/IO
mechanisms. The supplied system is an ordinary object exposing:

| Field | Contract |
| --- | --- |
| `State` | Actual state descriptor, including any deliberately retired snapshots |
| `initial` | Initial actual state, validated through `State` |
| `step` | `(actual-state command) -> (values next-actual-state actual-result)` |
| `observe` | `(actual-state) -> owned/stable canonical observation` |

Construct the fixture with `make-instance (TraceSystem ActualState)`. The scoped
callback is used exactly once. Its result cannot be replaced or reused after the
scope ends.

Pure prefix admission and dependency retirement share one typed state fold;
selection chooses whether to reject or omit a disabled command. Generation and
differential checking use bounded state folds; checking exits at the first
mismatch. `property-action` composes the run and consumer through the existing
Reader/FUN bind rather than introducing an effects framework.

Logical handles resolve only in the fixture that created them. No pointer,
mutable PRNG, table owner or cached receipt may escape one trial and become the
initial state of another trial or shrink probe. Fixtures can own files or other
resources without making the PBT runner a resource manager.

## Generation and domain admission

1. Admit `command-type`, model hooks, positive descriptor configuration and a
   finite nonnegative step cap. Create one ordinary trace sampler.
2. For each draw, call `initial`; consume the existing run-local random source.
3. Until `min(size, steps)` commands have been drawn, ask `draw` for a command
   enabled in the CURRENT reference state. The adapter chooses from enabled
   alternatives directly, rather than generating arbitrary syntax until it passes.
4. Check the command Type and Boolean `enabled?`, then use `advance` to construct
   the next reference state. A malformed/disabled draw is a generator error;
   it is never silently dropped or retried without a budget.
5. Return an owned finite trace spine. A normal `#f` from `draw` ends a valid
   prefix; it does not prove that the whole domain is exhausted.
6. Sampler admission replays the whole reference trace. A deleted producer or
   changed prerequisite cannot be hidden by accepting each command independently.

A valid empty trace checks initial-state equivalence; it does not demonstrate
command coverage. The collection example must separately assert coverage of its
required lifecycle prefix, with seeded random state-dependent suffixes.

## Stepwise differential execution

Preflight the complete command trace against the pure model before opening the
actual fixture. Invalid externally supplied traces are errors, not false
counterexamples or successful skipped tests.

Compare initial canonical observations. For each command, compute the expected
transition/result, run the actual operation once, compare the reply and then
compare the next canonical observation. Stop at the first mismatch. Do not
continue executing potentially dependent commands after divergence.

`check-trace` returns an ordinary diagnostic object containing `matched?`, phase
(`initial`, `result`, `state`, `complete`), command index, optional command and
expected/actual observations. It retains no actual fixture or live table owner.
`same?` must return Boolean; applications with representation-specific equality
supply it explicitly. Backend allocation identity or raw memory layout is not
the default oracle.

Expected protocol refusal is an ordinary modeled result. Only the collection
adapter classifies declared failures such as `table-index-conflict?`,
`table-conflict?` and the specific documented stale-source conditions. It retains
original diagnostic fields needed by the oracle. Unexpected exceptions propagate
unchanged to the existing `error` report; catching everything as conflict, false
or success is prohibited. Failed operations must leave the observed old state
and usable ownership unchanged before any retry is admitted.

## Dependency-preserving sequence shrinking

Reuse the existing runner's admission/descent/falsity/budget loop. Add only trace
candidate construction:

1. Propose deleting one command, and reuse existing coordinate shrinking for
   parameter replacements supplied by `model.shrink`.
2. Replay each proposed sequence from a fresh reference state. Retain a command
   only when it is typed and enabled at its new prefix. Omit commands whose
   producers/prerequisites were removed, then continue replaying the suffix.
3. Never rename a logical handle to another surviving handle, invent a producer,
   regenerate a random suffix or silently turn an expected refusal into success.
   Prescribed reply labels are part of collection commands and their preconditions.
4. Replay/admit the resulting whole trace again before running the actual system.
5. Use `length(trace) + sum(command-measure)` as the natural measure. A parameter
   replacement must reduce the whole measure; deletion plus dependent retirement
   cannot increase it. The existing runner retains only valid, strictly smaller
   traces that still falsify the differential property.

This is semantic dependency retirement, not text deletion or an inferred global
minimal sequence. An independent command survives removal of unrelated producers.
Deleting a producer can retire several dependent consumers; later commands that
remain enabled are preserved in order. A retired mismatch that no longer fails is
rejected by the existing falsity check, retaining the previous valid witness.

The first implementation may replay each candidate in O(n) reference steps and
propose O(n) single deletions, plus finite parameter candidates. It must charge
these costs; the shrink attempt budget does not prove callback execution time,
byte allocation or globally minimal counterexamples. No hidden unbounded search
or replacement scheduler is introduced.

## Revisions, failures and replay

Specification sources and system-under-test state have different roles:

- Descriptor/model/factory recipes are stable specification dependencies. Their
  mutation makes the PBT result `stale` and refuses old witness/seed replay.
- Per-trial table metadata, pending deltas and collection revisions are fixture
  state. Intentional changes to them are tested operations, not specification
  mutation. Do not register every mutable fixture as a stable PBT dependency.

Retain the existing `passed`, `failed`, `error`, `stale`, `exhausted` and
`unsupported` distinctions. Only valid Boolean-false observations create shrinkable
`failed` witnesses. Zero cases are refused. Unsupported generation, stale
specifications, process limits and unexpected exceptions never mean pass.
An ordinary stale TABLE result may be expected by a command; it must not be
confused with a stale PBT specification.

Reports retain their original and reduced concrete traces, seed, trial, effective
limits and source snapshot through the current property-report mechanism.
Concrete replay checks current sources and trace admission before opening a fresh
fixture; it does not consult the PRNG. Seed replay remains runtime/PRNG dependent.
V1 reports are in-process Scheme values, not portable closure bundles. Data-only
commands may be printed/read with standard Scheme tooling for explicit reproduction;
no versioned JSON, full benchmark datasets or archives are committed. Replaying on
changed code is a new experiment and cannot inherit an old report's authority.

## First complete collection adapter

Use typed data commands over integer keys/values and explicit logical ticket IDs.
The reference state contains primary bindings, logical metadata generation,
current/stale family status and captured before/after delta expectations.
It computes uniqueness independently with association lists.

| Operation | Required differential checks |
| --- | --- |
| Stage | Capture the old expectation and generation without publishing a table update |
| Install | Old-value validation, unique-index result and atomic primary/index observation |
| Undo | Existing inverse delta restores the prior observation or reports the prescribed conflict |
| Put/remove | Update reference bindings and every observed index; unblock a refused install when appropriate |
| Expire metadata | Leave the old collection state available only as a stale observation/control |
| Read old | Require the documented old-family refusal; no fallback to unchecked primary data |
| Refresh | Reconstruct through existing public index/table constructors, preserving valid primary content |
| Install old-generation ticket | Require stale delta refusal after refresh |
| Restage/retry | Create a fresh ticket; success must follow the same ordinary install path |

A deterministic valid prefix guarantees unique-index conflict, repair/retry,
old-value conflict, inverse restoration, stale family and stale delta rejection.
State-dependent random suffixes vary keys, values, pending-ticket selection and
revision order. Both RationalDict and the existing trie backend must agree with
the independent oracle. No new table, hash, index or ownership algorithm is part
of the test harness.

Inject known faulty adapters: admit a stale ticket, mutate primary state before
index refusal, lose an inverse update, or return a wrong index owner. The runner
must fail, shrink to a valid witness and reproduce it. Successful tests alone are
insufficient acceptance of the PBT implementation.

## Abstraction and implementation review

The implementation uses the existing POO `Record` contract for sampler/model/
fixture data rather than hand-written field-presence loops. `TraceGenerator`
inherits `TraceModel`, so generation and checking declare one domain.

A shared typed reference fold supports two selection policies: strict admission
rejects disabled commands; repair retires them. Both invoke the same state/result
boundary and preserve retained command order. Bounded generation carries its
state through `for/fold`; differential checking folds paired reference/actual
states and uses one escape continuation for the first mismatch. The scoped
fixture owns resource cleanup, while `property-action` uses the existing
Reader/FUN bind to hand its report to the caller's consumer.

This keeps policy separate from traversal without adding a monad, interpreter or
namespace solely for testing. Host exceptions stay errors. Invalid shrink
proposals still reach the existing budget/domain gate, rather than being hidden
by a new callback wrapper. The fixture's actual-state contract may intentionally
include expired snapshots; command preconditions and stale-version observations
remain part of the domain model.

The executable examples are `examples/collection-testing.ss` and
`t/representations/collection-testing-test.ss`. They exercise both existing RationalDict and trie
backends, including adapters deliberately broken at stale admission, index
observation, inverse installation and atomic failure. Their reference oracle uses
logical handles and ordinary lists, independent of backend mutation algorithms.

## Complex executable examples

[`collection-properties.md`](collection-properties.md) explains three runnable
examples in `examples/collection-properties.ss`: interleaved unique-owner handoff,
two-round service upgrades with retained receipts, and same-epoch ABA versus
cross-epoch rejection. Each uses both backends and multiple seeded runs through
`property-action`, with random suffixes after its required domain prefix.

Known faulty adapters must produce smaller dependency-valid counterexamples and
reproduce them through both replay paths. Custom-prefix controls additionally
verify owned scalar commands and fresh producer selection from retained IDs,
rather than assuming that the trace step number is unused. The corresponding
`freshHandle_lower`, `freshHandle_gt` and `freshHandle_not_mem` laws extend the
existing Lean testing model. These are finite design controls, not universal
runtime correctness or serializability claims.

## Downstream Scheme integration

The library additions below are implemented on PR #13. Users need a revision
containing them; older releases must not be described as providing these exports. Declare the package through the
project's normal Gerbil dependency workflow, with no Lean checkout or special
load-path/environment variables.

The downstream project owns its command Type, pure model and scoped actual fixture.
The following proposed test file delegates generation, shrink budgets and replay
admission to Gerbil-POO, and execution/discovery to `:std/test`:

```scheme
(export collection-model-test)
(import :std/test :clan/poo/object :clan/poo/testing/type
        (only-in "support/collection-model.ss" Command model with-system))

;; One standard suite fails on mismatch, stale sources, exhaustion or callback error.
(def collection-model-test
  (test-suite "collection model"
    (test-case "stateful differential traces"
      (let* ((sampler (trace-generator Command model steps: 64))
             (descriptor (.get sampler descriptor))
             (property (trace-property model with-system))
             (report (check-property descriptor property sampler: sampler
                       dependencies: [model] seed: 41 cases: 100
                       size: 40 shrink-budget: 200)))
        (check-equal? (list (.get report status) (.get report counterexample)
                            (.get report cause))
                      '(passed #f #f))))))
```

If `with-system` captures mutable factory/adapter recipes, include those stable
recipe objects in `dependencies:` as well; do not include the fresh mutable
fixture itself. A downstream project can first adopt the supplied collection
example, then replace only its command Type, model and actual adapter.

Export suite names ending in `-test`, retain the project's standard build/test
entry (`gerbil build` / `gerbil test`), and use its existing process/heap guards.
No PBT-specific runner is required. The implementation example will expose the
same model/fixture to a normal suite and a Reader/FUN `property-action` consumer.

For an expected regression failure, call `check-trace` on the stored minimized
trace for step diagnostics and `replay-counterexample` to reproduce Boolean false
with current sources and a fresh fixture. `replay-property` reproduces the seeded
search. A library mismatch is a failed test; no test should accept `error` or
`stale` merely because it was expecting a counterexample.

## Lean proof and implementation placement

Extend the existing `LeanPoo.Functional.PropertyTesting` namespace, rather than
creating a parallel testing namespace. Keep executable Lean controls in top-level
`Examples/` and `Tests/`; keep Gerbil functions in `testing/type.ss` and the
collection adapter in a functionally named `examples/` file. Each `def` documents
its contract/failure boundary. Split by existing functional boundaries if needed;
no code file should grow beyond the agreed modularity limit.

Required finite source laws:

1. Enabled draw/advance preserves valid prefixes and the declared step bound.
2. Dependency retirement returns a valid ordered subsequence under pure,
   deterministic model transitions and command admission premises.
3. Accepted shrink steps retain validity and falsity and strictly decrease the
   natural measure, reusing the existing budget/preservation theorems.
4. Step simulation plus initial observation agreement implies finite-trace
   agreement, including the first prescribed refusal and unchanged-state cases.
5. Stale specification snapshots refuse replay; concrete witness replay does not
   require a PRNG stream equality assumption.

Faithful backend observations, equality, stable callbacks and actual adapter
refusal classification remain explicit assumptions. These proofs do not verify
Gerbil, C++, FFI memory safety, arbitrary callback termination or concurrent
linearizability. Performance acceptance is measured separately.

## Verification matrix

| Obligation | Implementation / executable evidence |
| --- | --- |
| Typed model and fixture data | `TraceModel`, inherited `TraceGenerator`, `TraceSystem`; examples declare one reusable fixture Record and create fresh instances |
| State-dependent draws and dependency repair | Shared typed `fold-trace`, bounded generator fold, existing shrink budget/domain gates; invalid-draw, false-command and independent-suffix controls |
| Fresh resource scope | Distinct fixture identity across trials, shrink probes and both replays; cleanup counters remain balanced after comparison exceptions |
| Canonical handoff | Exact normalized command identity, one normalization per check, contracted callbacks through repair/replay, and late rejection before fixture effects |
| First difference | Initial/result/state fault controls reject later steps and count only required observations |
| Adapter contracts | Malformed actual state, result and observation are Type errors, not counterexamples |
| Collection semantics | RationalDict and trie lifecycle plus stale-admission, index-owner, inverse and premature-publication fault injections |
| Finite Lean laws | `retire_valid`, `retire_sublist`, `retire_deletion`, `drawTrace_sound`, `trace_simulation`, `replayTrace_stale`, `replayTrace_failed` |
| Concrete collection proofs | Top-level `Examples/CollectionTesting.lean` reuses `applyIndexed` and `inverseChanges`; proves complete two-key enumeration and checks conflict/retry/inverse/old-value/stale outcomes, final primary/index restoration and detection of premature primary publication |
| Local full workflow | The complete 149-module workflow and linked paired collection benchmark pass under existing limits; The existing focused PBT cases plus the independent-library cases pass |
| Published baseline CI | Lean `7932410a339dadc7d3736e286cbc6750c689d220`: 17 successful checks; Gerbil `4be7c411120cce18436fc35875a62da8e420f16a`: 53 successful checks, including single-process acceptance |

The local full-workflow row records the earlier accepted workflow. In the
interrupted-shrink follow-up, macOS `just check 2 1 4` stopped at the existing
90-second `build-shared` executable-construction gate. That is an unpassed local
build gate, not a falsified property or a paired-performance receipt. The existing
standard build configuration and limits are retained. Standalone kernel tests,
Record/FUN regressions, complete compiled-suite execution and exact-head CI are
reported separately; none substitutes for a missing full-entry receipt.

The subsequent macOS build repair was accepted from an entirely empty standard
`GERBIL_PATH`: `just check 2 1 4` exited zero, all 150 modules / 1,856 cases passed
in one process, and the complete study emitted `COLLECTION-PAIRED-OK`. Its 584.52
seconds cover compilation, test preparation/execution and the paired study;
the startup executable stage separately passed its unchanged 90-second gate.
The current shared module entry avoids the former duplicate collection link.
This closes that local build gate without retroactively accepting the failed
run or proving a host adapter simulation premise. See the macOS receipt in
`performance/build-summary.org` for the cache-cohort and timing boundaries.

The published baseline CI was checked before this follow-up. Every later revision
must pass the same CI; that baseline is not evidence for unsubmitted edits. Full
Lean submission checks and exact-head remote CI remain separate from target proof
checks. No source law proves a host adapter simulation premise automatically.

The three delayed Gerbil baseline jobs were waiting in GitHub artifact download,
not running a failing compiler/test. They completed without reruns or changed
limits. Local `pkg-config-libs "openssl"` uses the selected system `pkg-config`;
the Nix tool without OpenSSL metadata is distinct from Homebrew's configured tool.
No library paths are hard-coded to hide that environment distinction.

## Acceptance checklist

- [x] Reusable trace generation/admission, with typed invalid-draw and bound controls.
- [x] Fresh-fixture initial/step/result/state comparison and first-divergence reports.
- [x] Dependency-retiring structural and parameter shrinking; independent suffix retention.
- [x] Original-cause errors, expected refusal and specification-vs-fixture stale controls.
- [x] Seed and concrete-witness replay; old-source refusal before fixture effects.
- [x] Complete indexed collection lifecycle on two backends, including failure/retry.
- [x] Fault injection demonstrates false witnesses, valid shrinking and exact reproduction.
- [x] Standard downstream test example and FUN/IO composition, using the implemented public API.
- [x] Finite Lean laws and executable examples, with assumptions stated beside claims.
- [x] Focused regressions, the COMPLETE Scheme inventory and COMPLETE Lean checks pass.
- [x] Published baseline commits in both PRs have separately verified full CI results; later revisions retain the same required gate.
- [x] Resource limits, existing checks and progress remain; no SubAgent or committed raw datasets.

The finite V1 protocol is complete within the stated scope. Keep universal
correctness claims separate from generated evidence, and verify each submitted
revision through the unchanged full gates. The matrix identifies reproducible
checks; it does not turn this document into a replacement for their results.


## Effective coverage, portable replay and finite functions

`make-policy` names a run, supplies a Boolean precondition and a label callback,
sets minimum effective counts via `required:`, and bounds discards. Labels are
symbols, deduplicated once per effective trial. `accepted` counts eligible trial
roots (including a falsifying root), `discarded` counts explicit precondition
refusals, and `trial` counts draws. The first over-budget discard is counted and
refused; the run draws at most `cases + discard-budget` roots. Descriptor errors,
callback errors, generation exhaustion and stale sources are not discarded tests.
All-discard gives `exhausted`; unmet minima give `coverage`; neither means passed.
Shrinking preserves preconditions and contributes no labels. Concrete replay
contributes no coverage; seed replay owns a new ledger. Named syntax retains the
property name. POO `check-property` and `property-action` accept the same policy
and project effective counts/labels without a second runner.

`testing/property/replay.ss` uses explicit application codec identity (include format,
specification and generator revisions), encode/decode callbacks, a source guard,
and node/depth limits. It serializes finite Scheme trees: pairs, vectors, strings,
characters, symbols, keywords, Booleans, integers and nil. It neither serializes
closures nor evaluates persisted code. Identity is checked before decoding or
opening a fixture. Encoding and bounded envelope construction precede writing;
I/O itself can still fail after a partial write. Decoding reuses domain/currentness
admission and invokes the property once with zero shrinking. Reader allocation
stays under existing process limits, not a fictitious post-read byte bound.
Application decoders reconstruct logical handles, not runtime owners; precondition
semantics and schema revisions must be included in the explicit replay contract.

`generator-function` builds one result tuple per distinct finite raw argument row
(default maximum 256), reusing `generator-sequence` and each result's lazy sample
tree. `function-procedure` delivers ordinary Gerbil multiple values; existing POO
Function contracts validate calls/results. Typed consumers use finite Exactly/Enum
argument descriptors matching their observed rows. Unknown rows are refused, never mapped
to a fallback. Domain/result payloads must be immutable or covered by explicit
source guards. Raw keyword order and escape markers are part of a row's identity;
this does not claim equivalence of arbitrary keyword languages or infer an
unbounded function. Result-only shrinking preserves the finite input domain and
branch currentness. Domains may be empty; every call then refuses.

`examples/property-workflows.ss` is a downstream `:std/test` suite, with fresh-process
replay through the existing module-action executable. The typed boundary is checked
in `t/representations/property-testing-test.ss`. Lean models generation accounting,
coverage thresholds from actual labels, bounded prefixes, identity refusal before
fixture binding, conditional codec round trips, absent-row refusal and preservation
of lookup under result mapping. These are finite protocol laws, not verification
of Scheme callbacks, readers, PRNG quality or global counterexample minimality.

Finite function codecs can compose `function-table` with `function-from-table`.
The former exports fresh row/result spines under the function's source guard; the
latter validates finite row count, unique rows and tuple shape before restoring a
value. The existing collection scenario suite uses per-run operation coverage on
both RationalDict and Trie and replays reduced logical command data through fresh
scoped fixtures after serialization.

## Next acceptance units after finite P1-P3

### P4: standard test integration and named multi-argument properties

Implemented in `testing/property/test.ss` through the installed Gerbil `do-check!`,
`test-check!` and TestError protocol. Report APIs remain data APIs. The separate
assertion module owns standard check registration, caller location and named
binding diagnostics; it does not execute another property runner. Every status
other than a currently valid `passed` is a standard test failure with the original
PBT status and cause retained. No error/refusal is rewritten as falsification.

Named argument syntax lowers directly to existing generator bind and a fixed
product specification. Shape/domain admission, measure sums and source guards
reuse existing boundaries. Generator branches may depend on earlier values;
per-value domain inference is outside this interface. The POO report projection
lives in `testing/type.ss` and handles both full execution and preparation refusal.

Acceptance includes one-time evaluation, dependent generation, macro hygiene,
wrong product shape, delayed source invalidation, original cause identity,
independent stdlib-only compilation, and six intentionally failing properties
in the ordinary `examples/property-refusals.ss` module under the standard CLI
plus the existing Just admission guard. No Scheme fixture source is generated. The current SDK's
CLI can return zero despite ERROR HARNESS; the test does not confuse that with
TestResult success or claim to repair the compiler/CLI in POO. Lean proves check
admission, preservation of non-passing status/cause/arguments, and fixed product
domain soundness and row length. It does not certify operating-system exit status.

### P5: reusable data generation families

Implemented: `generator-integer`, `generator-character`, `generator-byte`,
`generator-list`, `generator-string`, `generator-symbol` and `generator-bytes`
reuse bind, sized, sequence and map. Unicode scalar ranks exclude surrogates;
explicit character endpoints are inclusive. The default covers all Unicode
scalars, unlike Rackcheck's default character domain. Octets cover 0–255.
Sequences have explicit natural minimum/maximum lengths (default 0/128); size
bounds the additional suffix, so fixed widths survive size zero. Structural
length proposals precede coordinate proposals. Domain admission and strict
measure decrease still belong to the existing property runner.

POO String, Symbol, Bytes and BytesN derive from this algebra, retaining source
observation and nested container compilation. `character-shrinks` and
`data-list-shrinks` supply the same value-level policy to typed callers.
No Char Type is invented; custom character Types can use `from-generator`.
Symbols mean interned spellings, including empty/reader-sensitive spellings,
not generated identifiers or gensyms. Mutable data are values within the existing
caller-owned trial protocol; arbitrary property mutation is not made pure.

Portable replay now copies and budgets u8vectors using Gerbil primitives, just
as it already does strings. Codec identity is still checked before decode;
failed encoding/budget admission writes no prefix. Tests cover Unicode endpoints,
fixed/variable widths, shrink-domain preservation, source invalidation, callback
errors, nested Type derivation, seed replay and mixed-data concrete replay.
Lean proves interval membership/descent, scalar validity/order, sequence bounds
and fixed widths. Carrier membership remains conditional on the representation
law; PRNG distribution, symbol interning and Gerbil encoders/readers are outside
the proof. This continues the paper's future-work direction.

References: [Rackcheck](https://docs.racket-lang.org/rackcheck/index.html)
(character families, list structural/coordinate shrinking, string composition)
and [Quickcheck](https://docs.racket-lang.org/quickcheck/index.html)
(character-generator-driven string construction). No separate generation engine
or implicit filter/retry policy is introduced.

### P6: bounded generator and shrink diagnostics

Implemented in the existing property module: `inspect-generator` owns one
`random-at` source and returns an `inspection` record. `count:` bounds root
attempts, `depth:` bounds descendant edges, and `proposal-budget:` is a global
budget across all roots. Size is an explicit fixed natural for this diagnostic
interface; scheduled sizes remain the property runner's separate protocol.
Defaults (`depth: 0 proposal-budget: 0`) sample roots without forcing children.

Flat events are `#(path kind value)`, with zero-based draw/child paths. Kinds are
`root`, `value`, `outside-domain`, `nondecreasing`, and `pruned`. Only admitted,
strictly decreasing children are expanded; refusals do not hide traversal.
`next-proposal` is shared with real shrinking: returned tombstones and a proposal
that triggers a trailing stale check are charged; EOF and iterator exceptions
produce no charged proposal. A positive budget is required before constructing
an iterator or pulling its next item. Cutoffs do not probe EOF. `truncated?`
therefore conservatively describes unexpanded neighborhoods, including a depth-zero
sample; `complete` only means requested root attempts finished, never minimality.
Events are bounded by count + proposal-budget, even for infinite neighborhoods.

Optional `labels:` counts each label once per admitted root. It never classifies
shrink proposals and owns a separate table from property coverage. No property,
precondition, fixture or assertion is executed by inspection. Statuses `error`,
`stale`, `exhausted` and `unsupported` retain partial events, charged attempts and
the original callback cause; diagnostic values are not falsification witnesses.
`inspection-current?` observes every visited source, including refused branches.
Callbacks must satisfy the existing purity/currentness obligations. Values remain
caller-owned; the inspector does not serialize or freeze arbitrary Scheme objects.

The POO module's `inspect-generator` accepts an existing typed sampler and supplies
its normal generator bridge, specification, revision snapshots and refusal mapping.
Preparation Type errors remain ordinary errors. Generic records/diagnostics import
no POO modules. Equal seeds/configurations repeat diagnostics under deterministic
callbacks; source invalidation cannot be repaired by silently refreshing old samplers.

Acceptance covers bounded infinite iterators, tombstone charges, domain/descent
refusals, exact child paths, EOF, zero fuel/depth/count, stale-after-return charges,
original iterator causes, generation exhaustion, coverage isolation, dependent
symbol/byte packets, unaffected later root draws, and typed recursive containers.
The independent compiled library now executes 33 cases without POO.
Lean proves domain/descent admission, total proposal/event bounds, zero-fuel and
zero-depth expansion independence, and depth bounds in the finite worklist model.
It does not certify PRNG distribution, arbitrary callback termination or the host
iterator implementation. Existing process limits remain the execution guard.

[Rackcheck sample/shrink](https://docs.racket-lang.org/rackcheck/index.html)
informs the diagnostic separation and explicit depth limits. Unlike its optional
per-term/unbounded exploration, this interface always has a finite global proposal
budget, so broad and infinite neighborhoods cannot evade the bound. This continues
the paper's future-work direction; no separate runner or namespace is added.

### P7: default POO test and debug workflow

Audit finding: PBT was already in the root build and complete standard test
entry. The missing integration was the existing developer-facing modules:
`support/testing` required manual typed report/diagnostic composition, `debug`
had no property action, and Reader configurations were not revision sources.
This is a concrete integration/admission gap, not a claim that unrestricted
Function synthesis, arbitrary recursive objects, or exception-as-falsification
are missing promised features. Strict Boolean bodies remain the finite contract.

Implemented: `support/testing` supplies typed `check-property` and hygienic
`define-property` with fixed named Type products. Tuple derivation owns the
argument layout, and the existing generic `require-passed` is reused through
Gerbil's `do-check!`. No second check context or runner is added. Explicit names
reach successful and preparation-refused typed reports while existing policy
coverage is retained. The generic admission function is exported by its owner.

`PropertyConfiguration` is an ordinary Record with natural seed/count/budget
fields, a fixed/procedural size Type, optional explicit size bound, policy record
recognition and the existing recursion quotas. Construction owns field Types;
the runner retains positive-count and finite-range validation. A missing size
bound is inferred for a fixed size only. Reader actions snapshot the configuration
as a normal dependency, so a callback returning true after an edit becomes stale.

`property-debug-action` composes the existing property Reader action and DDT.
It evaluates the property run once and returns its original report. A false tag
suppresses rendering, not that explicitly requested execution. Rendering does not
assert a pass; test assertions use the same strict admission boundary. Formatter
and I/O failure follow DDT's existing behavior rather than becoming falsification.
No import-time property execution, environment switches or discovery registry is
introduced. Root build, standard suite discovery and complete resource guards
remain unchanged. The README documents the default downstream entry.

Acceptance includes typed named/unnamed checks, macro hygiene, policy coverage,
Record configuration validation, scheduled-size refusal, debug output and disabled
rendering, callback-count controls, stale Reader configuration, Record fields with
wrapped Functions, shrinking/replay, and eight intentionally failing standard
checks (the previous six plus named typed failure/preparation refusal).
Lean extends the existing check admission model with configuration revision
admission/preservation, finite size-limit selection, and report-preserving debug
delivery under a returning renderer premise. It does not verify host I/O or
Gerbil's compiler. This remains the paper's future-work direction.

[Rackcheck's test integration](https://docs.racket-lang.org/rackcheck/index.html)
and [Quickcheck's RackUnit check form](https://docs.racket-lang.org/quickcheck/index.html)
inform the standard-check ownership. The remaining comparison is not a blanket
parity checklist: optional domain families need explicit application requirements;
current documented finite/Boolean/termination boundaries are retained as boundaries.

### P8: retained structural collection shrinking

Audit finding: generic Lists shrank a length seed and regenerated the payload;
typed recursive Lists offered empty/tail deletion only. A failure requiring both
endpoints could therefore retain unrelated middle data. This is missing deletion
operation coverage in the finite collection protocol, not a demand for global
minimality, arbitrary Record derivation or unrestricted recursive values.

`sample-sequence` now owns retained structural and coordinate proposals for both
families. It snapshots input list spines, preserves retained node identity and scalar preimages, never redraws
siblings, and retains all observed source leaves even when their values are
removed. A rejected coordinate stays a charged tombstone. Structural deletion is
lazy and uses aligned blocks with halving widths, finishing at every single
position. `list-deletions` supplies that same policy to value callbacks;
`list-deletion-count` allows typed value-only search to refuse oversized candidate
batches before allocation. Structural reservations count as construction work; the completed candidate ceiling retains its distinct refusal tag. Minimum lengths are preserved; fixed arities have no
deletion proposals. Selected Union branches remain fixed.

List/string/byte/symbol roots use the existing draw algebra. Pack/map callbacks
still run to produce each consumed candidate and retain their own costs. All
proposals remain subject to domain admission, strict measure descent, source
checks and the unchanged resource budgets. Duplicate visible values are not
collapsed across different retained source positions. Portable codecs still own
application format/specification/generator revision identity.

Acceptance includes endpoint-preserving middle/tail deletion, minimum/fixed
lengths, retained identities and no extra draws, historical removed-source
refusal in independently retained subtrees and reports, deterministic replay,
typed recursive List value/tree paths, and Record/FUN pipelines with wrapped
Function fields. Independent compilation executes 36 generic cases. Lean proves
block length/descent, subsequence order, map commutation and retention of old
observer identities. These finite laws do not certify arbitrary callbacks or a
runtime-wide cost model.

[Rackcheck's list shrinking](https://docs.racket-lang.org/rackcheck/index.html)
informs the removal-before-coordinate policy. The implementation reuses the
existing modules, iterators, sample records, domain gates and check runner.

### P9: source-consistent portable corpus handoff

Audit finding: export checked a failed report before encoding but did not bracket
encoding with its source observers. Import bracketed decoding and execution as
one action, allowing a decoder that revised its codec to reach the property.
These were gaps in the existing explicit source protocol, not a requirement for
closure serialization or unrestricted codec inference.

The existing replay module now brackets each application stage with codec and
domain/report observers. Export preflights before rechecking the false witness,
prepares the entire bounded envelope, and rechecks before entering ordinary port
writing. A preparation revision or exception writes no prefix. Import retains
identity/trailing-data admission before callbacks, then separates guarded decoding
from guarded execution. A decoder revision cannot invoke the property or open
its fixture. Application exceptions retain their exact cause; they are not masked
by a post-return stale check. Non-Boolean observers remain errors.

The existing `testing/type` module exposes the same write/read operations for a
typed report or sampler. It snapshots the sampler's declared sources without
drawing. Application codecs reconstruct ordinary Record values, so nested Function
fields use the normal constructor's validation and wrapping. No additional runner,
source registry, serialization evaluator or namespace is introduced.

Acceptance covers before/during-stage revisions, codec and domain changes,
zero property calls after decoder refusal, no output prefix on preparation
failure, exact exceptions and balanced cleanup, plus a downstream Record/FUN
debug failure exported and replayed through an existing sampler. The same finite
stage model proves preflight refusal, original-cause priority, post-return
refusal, exact current values and continuation suppression after failed preparation.
Observers must accurately describe application revisions; callbacks must terminate.
Port I/O failures or concurrent mutation during a write may leave partial bytes:
this protocol does not promise an atomic filesystem transaction or arbitrary
application codec round-trip laws. Identity must change with semantic revisions.

[Rackcheck's documented generator/property separation](https://docs.racket-lang.org/rackcheck/index.html)
remains the comparison point. This source-current corpus handoff is our explicit
protocol obligation, not a claim that Racket requires POO revision observers.

### P10: shared policy-admitted concrete witness replay

Audit finding: portable import used a one-case generation check with a fresh
default policy, so it could not enforce the application's original precondition.
In-memory concrete replay checked sources around the complete admission pair,
allowing a precondition revision to reach domain recognition before refusal.
P1 already requires replay not to inflate generation coverage; portable replay
therefore needs concrete admission, not a second trial disguised as replay.

`check-counterexample` in the existing property module now owns one callback chain:
currentness, precondition, domain recognition, and strict-Boolean property execution.
Every callback is checked before and after normal return. In-memory replay supplies
its captured policy and complete report sources; portable import supplies explicit
`policy:` and codec/domain sources. The existing typed sampler bridge forwards that
policy and its captured descriptor sources. No runner, framework, namespace or
independent policy representation is added. A callback exception retains its cause;
false/non-Boolean preconditions refuse before domain/property effects. Invalid
policy records refuse before application decoding.

Concrete replay returns the property's Boolean without sampling, shrinking,
measuring, size scheduling, label classification or required-coverage admission.
Coverage remains a generation-run obligation. Seed replay still regenerates the
original run with its original coverage policy. A codec identity must name the
property/precondition interpretation; application policy closures are not serialized.
Import's omitted `policy:` retains the existing always-eligible default.

Acceptance includes admitted true/false outcomes under deliberately unsatisfied
coverage requirements, classification callbacks that must never run, source changes
inside preconditions (codec, domain and typed configuration), ineligible and malformed
Boolean results, exact callback causes and zero downstream effects after refusal.
The Record/FUN/debug corpus example stores logical fields and reconstructs its
known Function through ordinary initialization. Lean models the same ordered
judgments with `admitWitness`/`checkWitness` and the prior guarded `replayStage`:
refusal suppresses later callbacks, stale and application causes stay distinct,
and admitted property results are exact. Truthful terminating callbacks/observers,
codec semantics and host resource/I/O behavior remain explicit premises.

[Rackcheck](https://docs.racket-lang.org/rackcheck/index.html) separates generator
and property execution; this work preserves that ownership while satisfying our
explicit source-bound replay protocol. It does not claim a universal policy
serializer or unrestricted higher-order inference.

### P11: source-current generator callback composition

Audit finding: producer draw, mapping and dependent/dynamic selector stages did
not consistently recheck their sources after a normal callback return. A selector
could revise its parent source and still run the selected child draw before the
property runner eventually refused the stale result. This violates compositional
source admission; it is not a demand for callback termination or effect rollback.

One hygienic `with-sources` form in the existing generator module brackets declared
flat observer lists without constructing another node guard or source registry.
Producer draw, map/filter, dependent selection and child drawing, sized/delayed
construction and retained sequence packing reuse it. Each normally returning stage
must remain current before its result can reach a subsequent stage. Callback
exceptions retain their exact cause. Producer admission owns producer leaves;
returned dynamic sample leaves retain their existing node/consumer admission.
No new generator, property runner, namespace, PRNG owner or retry policy is added.

The standalone callback matrix covers draw, map, bind, sized, delay, pack and a
child that revises its inherited parent source. It checks source refusal before
unstarted child effects, original exceptions after revision, deterministic repeated
seeded values and lazy child preparation. Independent compilation now runs 41 cases.
The downstream Record/FUN example refuses construction after a selector revision,
explicitly prepares fresh typed sources, performs real dependent shrinking, checks
Function wrapping and tests both replay forms. Seed replay repeats the whole
construction schedule; concrete replay invokes no generator or selector.

`guardedGeneration` models value plus resulting source/random state. Its finite
laws prove preflight refusal, post-return revision refusal, cause preservation,
unchanged admitted result/state and suppression of dependent stages after refusal.
Source accuracy/purity and callback termination remain premises. Effects already
performed inside callbacks are not undone, and no concurrent linearizability,
PRNG-quality or host/GC timing theorem is claimed. Existing resource limits,
flat source identity, proposal budgets and captured child seed semantics remain.

[Rackcheck's map/bind algebra](https://docs.racket-lang.org/rackcheck/index.html)
informs composition through the same retained shrink tree. Revision observers are
our additional explicit protocol, not an assertion that Racket mandates POO sources.

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

### P12: finite-key HashTable and typed Map generation

The next finite collection capability is a HashTable with an explicit finite key
domain. Racket provides hash generation, while our supported container algebra
previously required applications to hand-build unique entries and reconnect their
shrinks. This unit extends that finite algebra; unrestricted key inference,
recursive hash-key synthesis and arbitrary mutation remain outside it.

`generator-hash keys values` uses standard HashTable equality to reject duplicate
keys once at preparation (`domain-limit:` defaults to 256). The key-list spine is
copied. A nonzero-size root considers every key and keeps at most size selected
keys; zero size draws no keys or values. Only retained values are drawn, using the
existing sequence/sample protocol. `sample-sequence` provides structural deletion
before value coordinates, retaining original samples and all observed sources.
Keys never shrink or normalize. `list->hash-table` materializes a fresh table per
node with an explicit seed; no second hash implementation or collision retry loop
is introduced. Mutable value payloads remain caller-owned. Hash iteration order is
not the generation, shrink or portable-corpus order; declared key order is.

`map-generator descriptor keys value-sampler` in the existing Type module requires
an existing Map descriptor and exactly its declared value sampler descriptor. Key
validators must leave supplied representations unchanged. Their own source boundary
refuses a revision before another key validator runs. Constructor errors (including
duplicate keys and limit/mismatched Types) are not hidden by resampling. The existing
Map validator alone owns recursive value validation and nested Function wrapping.
The measure combines cardinality with child value weights, so both deletion and
strictly smaller value coordinates can advance falsification. Dependencies and the
existing currentness hook capture prepared Map/Key/Value/sampler/application epochs;
stale preparation is never silently refreshed. Derived Record/FUN samplers forward
that child hook through their existing protocol.

Acceptance includes equal-but-distinct duplicate strings, false values versus
absence, detached key spines, size bounds/zero draws, fresh tables, deletion without
redrawing, value coordinates, retained-source refusal and exact callback causes.
Typed tests cover key normalization refusal, descriptor mismatch, collision refusal before key validation and value drawing, source revision during key preparation, raw Function wrapping
and a Record of Maps of linked Records/Functions. That workflow shrinks an aggregate
fault to one key/value, exercises bounded empty-map inspection, both replay forms,
explicit fresh preparation and data-only corpus handoff. Independent generic
compilation executes 45 cases without POO.

Lean's `selectedHashKeys`/`hashEntries` prove subset/order, size/domain bounds,
uniqueness, finite lookup including false-like values, deletion commutation and
value transformation preserving keys. The standard hash protocol's equality/hash
compatibility, stable key payloads, pure stable validators, accurate observers and
terminating value callbacks remain explicit premises. No global uniform sampling,
arbitrary codec law, hash iteration ordering, constant hash lookup cost, host GC
bound or compiler verification is claimed. Accepted preparation traverses the finite domain and performs two hash operations
per key, excluding Type/validator costs. Nonzero roots test all domain keys and
draw at most min(size, domain length) values. Fresh packing inserts one entry per
retained key. Hashing, source checks, seed preparation and validation retain their
own costs; these counts are not constant-time or wall-clock bounds.

[Rackcheck hash generators](https://docs.racket-lang.org/rackcheck/index.html)
provide the comparison point. This implementation intentionally declares unique,
stable key identities rather than silently collapsing generated duplicate keys;
existing value-generation and shrinking protocols remain the only runner algebra.

## P13: declared finite enumeration simplification

Finite Enum values previously had no shrink candidates and zero measure. A
nested collection could reduce its shape but could not simplify an Enum field.
`generator-elements choices` now maps the existing integer shrink tree through a
captured vector of declared values. It requires a nonempty proper list, draws one
index regardless of size, and never redraws while shrinking. Equal payloads retain
their distinct position preimages. Mutable payloads remain caller-owned; only the
list spine is detached. Existing observer ownership and exact error causes apply.

The POO scalar bridge reuses Enum's existing `.uint<-` and `.<-uint` metadata.
The first equal declaration position is the natural measure. Value-only shrinking
maps smaller indices through the same descriptor; generic tree shrinking retains
its original index preimages. A duplicate proposal with equal canonical rank is
charged and refused by the existing strict-descent gate. Empty Enum remains an
uninhabited leaf and does not invalidate an otherwise inhabited Union. Declaration
order is an explicit simplification policy, not an inferred semantic ordering.

Regression acceptance covers false payloads, equal duplicates, detached spines,
no redraws, stale retained descendants, original callback causes, minimum failing
ranks, concrete/seed replay and a nested List/Tuple/Enum FUN workflow. Changes to
the role descriptor reject old reports. Independent generic acceptance now runs
48 cases. No equality implementation, RNG, shrink runner or namespace is added.

Lean proves selected values belong to the finite domain, out-of-range selection
refuses, first-occurrence rank is no larger than the selected index, and earlier
positions strictly lower canonical rank even with duplicates. Host equality/hash
agreement, stable payloads, truthful observers and terminating callbacks remain
premises. Index generation does not prove PRNG distribution or wall-clock costs.
Preparation copies N positions; each draw selects one index; shrink work and
source checks retain the existing lazy tree and budget costs.

[Rackcheck's finite-choice generator](https://docs.racket-lang.org/rackcheck/index.html)
also supplies shrinking. Its removal-of-previous-choices policy differs from our
explicit declaration-order policy; byte-for-byte tree parity is not claimed.

## P14: dependency-repaired block trace shrinking

Audit finding: the typed trace sampler enumerated only single-command deletions
and separately rebuilt parameter coordinates. A failure requiring zero or two
independent noise commands can disappear after every single deletion, so that
neighborhood can stop before a smaller valid witness is reachable. This is a
concrete missing structural neighborhood, not a promise of global minimality.

`testing/property/model` now exports `shrink-trace model commands shrink`. It
composes the existing `data-list-shrinks` policy with `repair-trace`: aligned blocks
halve to single positions, then parameter-coordinate proposals follow; each raw
candidate is normalized and dependency-repaired once. The typed `trace-generator`
uses this function with its existing prepared model and raw parameter callback.
There is no separate block algorithm, identity search, handle renaming or fixture
execution. Generic downstream code uses the same function. Callback errors retain
their original cause, and empty proposals remain successful candidate sequences.

The existing runner still owns membership, strict cost descent, retained failure,
source checks, zero-fuel behavior and replay. Repair can retire more dependents;
strict descent is guaranteed for nonempty structural deletions with natural
parameter weights. Parameter replacements still require the runner's cost check.
The normalizer must be stable and preserve the intended command interpretation;
Lean's retirement laws model already-normalized commands, not arbitrary decoder
effects. Parameter callbacks and normalizers remain terminating premises.

Acceptance includes a single-deletion control that cannot cross a parity barrier,
the block policy reducing to the required producer/consumer pair, dependency
retirement, parameter normalization errors, balanced scoped fixtures, zero-budget
no-shrink behavior, FUN execution, seed/concrete replay and old-source refusal.
The generic isolated suite now executes 50 cases. Existing real collection model
fault injections and their dependency/replay regressions remain in the full check.

Lean composes existing block and retirement laws to prove valid dependency order,
retained-sublist identity, at least the deleted block's length decrease, and strict
complete trace-weight decrease. The concrete parity model matches the executable
control. No arbitrary callback, runtime scheduler or host-GC theorem is claimed.

The value-only callback boundary still materializes a finite proper candidate
list. For length N, structural proposals are counted by `list-deletion-count N 0`;
repairs traverse retained prefixes, and parameter proposal costs are additional.
We do not claim lazy preparation, linear wall-clock complexity, all possible
subsequences, or a globally minimal witness. The supplied neighborhood becomes
stronger without changing fuel accounting or inventing another shrink runner.

## P15: source-consistent policy and product admission

Audit finding: shrink admission wrapped the policy precondition and property as
one action. A precondition that returned true after revising a declared source
could therefore enter the property before the outer stale check. Fixed products
similarly checked sources around the aggregate predicate/measure, allowing later
field effects after an earlier field invalidated their captured specification.
Negative controls reproduced all three forbidden downstream calls before repair.
These are sequential source-admission defects, not unrestricted effect inference.

The existing hygienic `with-current` form now brackets shrink eligibility before
property entry, reusing the run's own nonlocal stale exit. Stable exclusion remains
non-falsification and adds no generation coverage. Products reuse that same form
around each field predicate and weight, checking every captured domain source
between callbacks. Gerbil's standard `map-in-order` supplies ordered measurement;
there is no new callback framework, namespace or source cache. Generator, root,
shrink and concrete replay retain their existing owners and reports.

A refusal never installs the in-flight proposal. Its already returned attempt
remains charged, the previous confirmed witness survives, no minimum is certified,
and callback exception identity is retained even if the source also changed.
Fresh execution may capture revised sources; seed replay of stale reports may not.
Already executed callback effects are not rolled back. Observers must be accurate,
pure and terminating; each application must declare its mutable dependencies.

Regressions cover true/false stale eligibility, cross-field recognition and
measurement invalidation, skipped later callbacks, original policy exceptions,
retained witness/attempt accounting, stable exclusions and unchanged coverage.
The FUN/Record example revises shared policy rules during shrinking, rejects the
old report, then prepares a new execution that shrinks and replays successfully.
The isolated generic suite now runs 55 cases without POO modules.

Lean composes the existing guarded state callback model into ordered product
stages and a shrink-policy judgment. Seven laws cover immediate and arbitrary
prefix refusal, original causes, stale Boolean policy returns, stable exclusion
and admitted evaluation. Concrete controls use effect markers for forbidden
later fields/properties. These finite laws require a faithful host interpretation;
they do not prove arbitrary source observers or concurrent atomicity.

With N product fields, successful full recognition/measurement adds two aggregate
source checks per visited callback, each checking up to N domains. This may cost
O(N²) observer calls; arbitrary observers offer no invalidation notification that
would justify caching a once-true result. Host callback and observer costs remain
explicit, and all existing runtime limits and proposal budgets remain unchanged.
No speedup or global effect safety is claimed.

[Rackcheck](https://docs.racket-lang.org/rackcheck/index.html) supplies the lazy
generator/property composition comparison. Revision observers are this protocol's
additional responsibility; this change does not claim Rackcheck implements them.

## P16: source-consistent portable handoff stages

Audit finding: export reconfirmation and encoding shared one codec boundary. A
property could invalidate codec metadata while leaving its witness domain stable,
then still invoke that stale codec's encoder. Import likewise consumed an envelope
before its first provenance preflight, even when the codec or specification was
already stale. Negative controls reproduced one forbidden encoder invocation and
an unexpectedly consumed input datum before the fix.

The existing `with-codec` now owns distinct confirmation, encoding and delivery
stages. A normally returning confirmation checks both application and codec
provenance before encoding starts. Encoder refusal still precedes every output
prefix. Import preflights both sources before its first read, then checks the
bounded envelope read, trailing-data check, decode and concrete-witness admission
at their existing boundaries. Invalid policy configuration remains first; stale
preflight now precedes input parsing and identity admission. For current sources,
identity and trailing-data errors still precede decoder/property callbacks.

No codec registry, port wrapper, serializer or runner is introduced. Standard
Gerbil ports and the existing explicit data codec retain format identity, payload
budgets and Function reconstruction. An already stale read leaves input untouched;
once I/O has started, consumed/emitted bytes are not rolled back. A port or
callback exception keeps its own cause even if sources also changed. Atomic
publication, arbitrary reader allocation and concurrent source changes between
checks remain outside these finite sequential guarantees.

Acceptance covers confirmation invalidation, zero encoder/output effects, stale
input preflight, original confirmation exceptions, and fresh codec preparation.
The typed FUN example shrinks a Record with a Function field, retires codec
metadata during export reconfirmation, retries using a new codec, rejects the old
codec without consuming input, and reconstructs the checked Function through the
ordinary Record constructor. Generic coverage/decoder/encoder/corpus tests remain
unchanged in scope; the isolated generic kernel inventory stays at 55 cases.

Lean composes existing guarded callbacks into confirmation/encoding/delivery.
Seven laws prove preflight refusal, confirmation source/cause refusal, encoder
source/cause refusal, exact stable payload handoff and original port causes.
Controls distinguish skipped later actions from post-delivery refusal. Faithful
witness confirmation, observer accuracy and callback termination remain premises;
no host I/O rollback or compiler correctness is asserted.

Export adds one constant codec/context boundary between reconfirmation and encoding;
import adds guarded read/trailing-data stages. Existing data-copy node/depth budgets
are unchanged. Observer, serialization and host port costs are not claimed zero,
and no wall-clock speedup is asserted. This preserves the generator/property
separation learned from [Rackcheck](https://docs.racket-lang.org/rackcheck/index.html)
while enforcing this library's additional revision protocol.

## P17: source-owned resumable shrink traversal

Audit finding: standard value shrink factories checked their source leaves only
when a coroutine first started. A paused iterator could resume producer effects
after its source changed. Combinators could detect stale results after that extra
pull, while dependent bind reconstruction could omit the originally selected
child's source leaves on a separately retained smaller node. Negative controls
reproduced an unchecked next value, an extra producer effect and a descendant
that incorrectly reported its old origin as current.

One private `for-sources` form now composes the existing `with-sources` boundary
with Gerbil's ordinary Iterator protocol. It guards factory evaluation and every
`next!`, including EOF. Value generation, mapping, bind, filtering, sequence
coordinates and finite-function tables use the same form. No new public DSL,
iterator implementation, coroutine framework, scheduler or source registry is
added. If both owned and inherited source lists are empty, the form lowers to the
standard `for` loop directly; a currently true observer never qualifies for that
fast path merely because of its current truth value.

Bind nodes merge original/parent/selected-child leaves before admission and pass
that flat ownership to parent regeneration and child shrinking. Mapped descendants
retain the enclosing observed leaves. Retained subtrees cannot drop old authority
by selecting a fresh branch, including when lifted through the ordinary typed
`from-generator` bridge into a separate FUN run. Fresh invocation may capture a
new epoch; old retained nodes and old replay remain refused. Unvisited alternative
branches are not scanned or added. Advanced handwritten sample producers still
must declare accurate source leaves on their own nodes.

Regressions cover paused primitive and map/filter/bind/sequence/function traversal,
original iterator causes after source mutation, historical bind ownership and
fresh invocation. The Record/Function/FUN example retains a smaller dependent
subtree, rejects it after the original branch changes, then regenerates, shrinks
and replays under the new epoch. Existing seed checkpoints, parent-before-child
order, zero-fuel behavior, EOF checks, proposal accounting and corpus tests remain
in the full workflow. Independent generic acceptance stays at 55 kernel cases;
additional public workflow and typed cases run under the standard suite.

Lean reuses source unions and guarded callback transitions. Eight laws establish
rebuilt membership/currentness/stale refusal and per-pull preflight, EOF refusal,
exact exception/value preservation and the source-empty fast path. Accurate pure
observers, faithful host callback interpretation and termination remain premises.
This is sequential resume admission, not concurrent linearizability, coroutine
runtime verification or arbitrary closure dependency inference.

Guarded pulls add before/after source walks and reuse the existing inherited
context-sharing fast path. Source identity deduplication retains all distinct
captured epochs, never deduplicating by Boolean truth. Origin lists may grow with
visited reconstruction ancestry; this is not an O(1) source-check or host-heap
bound. Source-free data keep the standard loop; no wall-clock improvement is
claimed. Proposal budgets count returned composed proposals; an interrupted pull
that returns no proposal cannot certify a minimum. Existing heap/deadline guards
still bound arbitrary callback work.

[Rackcheck bind](https://docs.racket-lang.org/rackcheck/index.html) provides the
parent-first lazy tree comparison. Original child seeds and regeneration order
are unchanged; source ownership is our additional explicit protocol.

## P18: retained independent product shrinking

The concentrated audit reproduced a distinction missing from the composition
implementation: `generator-sequence` used dependent bind for both drawing and
shrinking. Shrinking the first coordinate of `(2 1)` produced `(0 2)` when the
second producer counted its draws. Even with pure callbacks, the suffix was
constructed again, discarding its original sample identity and doing unnecessary
work. This is a defect in independent product retention, not a demand to freeze
arbitrary mutable values or eliminate dependent regeneration.

`sampled-sequence` now captures original nodes through the same bind/map draw
schedule. Public `generator-sequence` hands these nodes to the existing
`sample-sequence` at their fixed width. Lists and finite-key hashes share the
same root capture directly, with their existing structural policies; finite
Function tables inherit fixed-product retention. No second shrink traversal,
cache, iterator, namespace or retry policy is introduced. Explicit `generator-bind`
and named dependent bindings still regenerate selected children when the parent
changes. A collection's structural shrink never becomes product field deletion.

Acceptance checks stateful sibling draw counts, repeated child traversal, the
original split-seed schedule and outer random checkpoint for twelve seeds, empty
products, untouched finite Function rows, original sibling source rejection and
absence of a redraw exception. A downstream Record example composes independent
fields, Function contract wrapping, FUN execution, shrinking, concrete replay and
seed replay: shrinking/concrete replay draw nothing; seed replay draws once per
field again. The ordinary workflow and typed suites now have 34 and 21 cases;
the independent generic-library fixture remains 55 cases.

Eight finite Lean laws establish width, chosen-coordinate replacement, exact
sibling-preimage retention, carrier mapping, commuting distinct updates, unchanged
external draw state, empty products and strict descent of the existing sum measure.
The host correspondence assumes faithful retained sample nodes and the declared
measure; callback purity, termination, mutable payload ownership, PRNG quality,
allocation and GC are not inferred. Root capture still costs linear work in the
product width, and a coordinate proposal still packs a full product. This removes
suffix drawing, not all preparation or source-observer costs.

[Rackcheck's tuple examples](https://docs.racket-lang.org/rackcheck/index.html)
show fixed heterogeneous products shrinking one coordinate while keeping the
others; its bind documentation separately prioritizes dependent parent shrinking.
We preserve that distinction with Gerbil's existing tree algebra and the project's
additional revision protocol. Random bitstreams need not match Racket.

## P19: demand-driven FunctionArguments child derivation

The audit reproduced a real automatic-derivation refusal: a later case-lambda
input Type was completely shadowed by the first clause, yet its `.generator`
constructor ran during call-sampler preparation. An exception there made the
whole property report `error`, although every reachable call used supported
Integer inputs. An empty rest suffix had the same unnecessary requirement.
This differs from an actually supplied unsupported input, which must still fail.

`testing/function.ss` now captures all declared input Type identities immediately,
then uses the existing `support/base` `defonce` (standard delay/force) to derive a
child only after structural first-match selection and supplied-field decoding.
The already imported standard `map-in-order` fixes constructor order and stops
before later input hooks after an exception; plain mapping owns only pure setup.
Successful derivations are shared by descriptor identity within that call sampler,
including repeated required/optional/keyword/rest occurrences, measurement,
shrinking and seed replay. Omitted fields invoke no constructor. The underlying
child generator still draws fresh samples per occurrence; no generated-value
cache, Type substitution, Any fallback, namespace or alternate dispatcher exists.
Output Types remain outside call-input generation, as before.

All declared input Types remain explicit parent dependencies, even if unforced.
Once demanded, each child's own descriptor/sampler/transitive dependencies remain
in the existing product and generic sample-tree source guards. Old reports refuse
a dormant Type edit or a selected child's external-source edit. Fresh explicit
preparation can retry. A selected constructor exception is now an execution-time
preparation error with its exact cause, before the property runs; it is not a
false witness or an invitation to choose another Type. No promise about caching
constructor exceptions, callback rollback or concurrent promise forcing is added.

Regressions cover a shadowed required/optional/rest/keyword family, dormant Type
revision rejection, zero-length rest without a child generator, exact selected
constructor causes, ordered first-error suppression, reuse of an earlier successful
promise after a later refusal, and a fresh retry. The downstream example combines optional,
required keyword and rest calls, multiple return values, real Function contract
wrapping, Record configuration, FUN execution, shrinking and both replay paths.
It verifies zero constructors before demand, one successful preparation for a
reused input Type, retained external-source refusal and explicit fresh retry.

Eight finite Lean laws model demand by descriptor identity, successful cache
reuse, exact refusal, locality to the demanded Type, empty rows, repeated inputs,
first-error suppression and retention of previously prepared entries. Structural
signature selection is justified by the existing signature laws. Faithful
identity lookup, current source guards and ordinary sequential promise semantics
are premises; the model does not certify the Gerbil promise runtime or arbitrary
constructor effects/termination. First demand can still be expensive under the
existing process limits. Each Type has one small promise, and ordinary identity
lookup remains linear in the captured finite Type directory.

[Rackcheck's delayed generators and dependent generation](https://docs.racket-lang.org/rackcheck/index.html)
inform separating preparation from actual demand. This is a correction in the
POO Type-driven layer, not an assertion that Racket has our descriptor/revision
protocol. General inference and arbitrary Type generation remain explicit bounds.

## P20: revision-bound scoped differential trace execution

A direct typed `check-trace` could execute both commands and return `matched? #t`
after its actual fixture revised the model's observation declaration. No model
or fixture declaration snapshot owned that execution. Through an outer property
run some revisions were eventually refused, but later fixture effects and
comparisons could already have used a different declaration. This is a concrete
coherence defect, distinct from the documented purity of the reference model or
from arbitrary hidden callback dependencies.

The typed boundary now captures the original model, normalized owner, TraceModel
schema and Command/State/Result/Observation Types before execution. On entering a
fixture it retains the original/normalized fixture, its State Type and its schema,
without refreshing any previous stamp. Fixture stamps own only the active `use`;
the model ledger is restored before teardown, so ordinary resource retirement is
allowed. Model declarations stay checked through factory return. `prepare-model` captures callbacks and
validation adapters once, and accepts one internal wrapper shared by all stages.
The existing generic model fold still owns prefix admission, scope, first
mismatch and step ordering; it is not replaced or given a new namespace.

One local checked-action function brackets reference callbacks, normalization,
actual steps, actual observations, result/observation validation, equality and
fixture-factory return. Even an apparently matching comparison or an already
computed report cannot cross a revised declaration boundary. Source refusal uses
the existing `GenerationRefusal` stale kind; it never becomes a false witness.
Exceptions retain their original cause because a failed callback does not execute
a trailing check that could replace it. Malformed scalar models retain normal
Type refusal. Stable first-difference phase/index/expected/actual data are unchanged.

Declarations are fixed for one execution; the actual State may evolve normally.
Backend roots, pending deltas, invalid caches and mutable fixture state are not
mistaken for immutable declaration metadata. A rejected execution does not undo
an already performed backend operation. Fresh explicit preparation is the retry
boundary; an old report cannot acquire fresh source stamps.

Regressions revise declarations before fixture entry, in initial observation,
equality, a step, and after a completed use but before factory return. They verify
that later steps/observations stop and user scope cleanup runs once. Further
controls cover fixture declaration edits, exact exceptions after a revision,
malformed input, unchanged first-difference diagnostics and normal fixture retirement
after use. The complex example
uses the existing real indexed-collection lifecycle plus its state-dependent
random suffix, wrapping the actual fixture's first step. FUN returns stale after
one operation, old replay refuses, and a freshly prepared full trace plus seed
replay passes without altering the original collection model.

`PropertyTraces.lean` keeps this unit separate from generator algebra while
retaining the existing PropertyTesting namespace. Eight finite laws establish
preflight refusal, reference/fixture/comparison revision refusal, exact causes at
each stage and unchanged stable match/mismatch results. Host cleanup is verified
by executable scope controls, not asserted as a Lean theorem about continuations.
Faithful owner epochs, sequential observation, callback termination and the
fixture/model simulation relation remain premises. Hidden heap mutation,
concurrent linearizability and effect rollback remain outside the proof.

Each checked callback walks the retained finite declaration ledger. This adds
correctness checks, not a zero-cost or wall-time improvement claim. Wrappers are
prepared once per trace; no per-command object protocol or source registry is
created. Existing heap/time/proposal limits and complete checks remain unchanged.
[Rackcheck's separation of generators and property execution](https://docs.racket-lang.org/rackcheck/index.html)
informs keeping the oracle/fixture boundary outside the generator algebra. The
revision-bound model protocol is this project's extension, not a Rackcheck API.

## P21: shared typed-product observation and directory ownership

The audit reproduced a typed/generic mismatch in the explicit `product-generator`
factory: a first typed field measure
changed a later field's source, yet that later measure still ran before the whole
report finally became stale. The generic product specification already stopped
between field callbacks (P15), but `product-generator` duplicated its measure
with a plain map/sum. Value-only coordinate shrinking similarly could continue
to packing and later child callbacks. A caller could also mutate the supplied
child-list spine after construction, making draw use the old children while
measure/shrink used a different directory.

Typed products now copy the child spine once and reuse the existing generic
product specification for natural field measures and joint source checks.
`specification-weight` is the checked operation on that opaque domain: it shares
the existing natural-measure helper, checks sources, and never exposes raw record
fields or redraws values. It expects a domain-appropriate value; recognition
remains the runner's existing admission stage rather than being repeated by
measurement. `make-product-specification` accepts an explicit `current?:` common
owner, following the existing source-observer convention. It protects empty
products and parent metadata as well as each child domain.

One typed checked-action function brackets unpack, each value-only shrink and
pack, using the same product-domain currentness. `map-in-order` preserves field
and packing order. Ordinary retained-tree drawing/packing uses `generator-map`'s
existing `current?:` boundary. The sampler retains that same `.current?` hook, so
opening another core view cannot refresh an obsolete product. No new namespace,
record hierarchy, value cache, property runner or compatibility path is added.
Children and payloads retain their identities; only the caller-owned directory
spine is captured, not arbitrary mutable heap contents.

Regressions cover parent and child revisions during measures, unchanged charged
attempts and last witness, refusal before packing/later shrink callbacks, explicit
fresh retry, directory mutation across draw/measure/shrink and empty-product
owner refusal. Generic controls cover common-owner and Boolean/natural admission
and exact callback causes. The Record/FUN example retains nested Function wrapping,
refuses the stale run before a later handler measure, prepares fresh ownership,
shrinks a real failure, replays it and rejects later stale replay. Generic and typed
layers share the same implementation rather than separate product cost folds.

Eight laws in `PropertyProducts.lean`, under the existing PropertyTesting namespace,
reuse guardedStages/guardedGeneration: common preflight, early field refusal,
original field/packing causes, empty ownership, packing revision refusal, stable
field order and unchanged natural sum. Faithful captured topology and pack/unpack
representation laws, truthful epochs, sequential callbacks and termination are
premises. Host list copying is tested, not claimed as a universal Lean heap theorem;
GC, alias discovery, concurrent mutation and wall-time bounds are not inferred.

The existing generic product checks all field owners around each callback; its
observer work can be quadratic in product width. The common owner adds one guard
per check and the factory captures field domains/stamps once. This is a coherence
fix, not a constant-time or universal speedup claim. All checks and existing
heap/time/proposal limits remain required.
[Rackcheck's product/tree composition](https://docs.racket-lang.org/rackcheck/index.html)
informs keeping generation algebra separate from domain observation. Common
revision owners and typed sampler evidence are this project's explicit extension.

## P22: fixed-product source admission before drawing

The next audit reproduced a producer-level gap distinct from P21's typed domain
measures. `generator-sequence` already knows every fixed field, but the bind/map
implementation exposed none of their source leaves at the product boundary. If a
later field was obsolete before generation, `generator-current?` still returned
true and an earlier field drew once before the eventual stale refusal. An earlier
draw could also revise that later source and still enter its own mapping callback.
Finite Function result products inherited the producer-currentness mismatch.

`sampled-sequence` now assembles the declared fixed-field leaves once with Gerbil's
`append-map` and the existing identity-deduplicating observer boundary. It shares
the existing bind/map run procedure unchanged. `generator-sequence` and finite
Function generation forward those leaves through their existing constructors.
The existing `generate`/`with-sources` boundary therefore rejects before the first
random split or draw, and between field callbacks. There is no new guard closure
tree, source registry, generator representation or special typed execution path.
Retained child ownership, draw order, seed splitting and coordinate shrinking stay
with the same implementation. Typed `from-generator`/Record/FUN observes the
generic admission directly rather than duplicating it.

This rule applies to fields that are statically part of a fixed product. Dynamic
bind selectors, weighted choice, zero-result-row Functions and absent Map keys do
not acquire sources from unselected producers. An explicit function/domain owner
still protects empty domains. Captured lists describe topology; mutable payload
ownership and hidden callback dependencies remain the existing application laws.

Four independent-library cases cover nested stale preflight without randomness or
draws, immediate mapper suppression after revision, exact observer causes/strict
Boolean refusal, shared Function sources, equal-seed replay, empty domains and
zero-weight branch independence. The Record/Function/FUN example rejects a stale
generic field before drawing, explicitly reprepares, retains wrapping through
shrinking and concrete/seed replay, and refuses both old samplers and later stale
reports. The standalone library check now executes all 59 cases without POO.
Product cases live in `examples/property-products.ss` and register with the
existing standard suite; the aggregate kernel stays below 1000 lines. The empty
independent package copies and builds both ordinary modules, with no new namespace
or test runner.

Six additional laws in `PropertyProducts.lean` prove flattened field conjunction,
stale leaf refusal before all draws/packing, nested/shared source equivalence and
empty-result independence. They reuse `guardedProduct` and stable source identity;
Boolean observers, truthful epochs, faithful directories, sequential callbacks and
termination are premises. Runtime observer exceptions are regression-tested, not
represented as pure Boolean functions in the model. PRNG implementation, arbitrary
heap aliases, concurrency and GC remain outside these laws.

Preparation adds a linear pass over the field directory and its declared leaves,
including a copy and an expected-linear identity hash pass over those leaves. Complete known-source checks now occur before and
after field callbacks, including nested products; repeated observation is not
claimed constant-time. No wall-clock speedup is claimed. The full checks, paired
generator/collection workflows and all existing process/resource bounds remain
required. Rackcheck's pinned `gen:bind` composes retained trees and a captured child
random source; we retain that algebra. Epoch-based fixed-product admission is our
explicit extension, not a missing feature attributed to Racket.

## P23: source-consistent bounded rejection sampling

The filter audit reproduced a hole between retry iterations: a rejected dynamic
branch's leaves were checked at the next loop entry and retained by a later
accepted tree, but were not inherited by the next draw's nested graph. That draw
could invalidate the earlier branch and still invoke a mapper/selector before
the final filtering boundary refused it. The baseline performed one forbidden
map in the second attempt; the corrected run performs none and remains stale.

The existing `generator-filter` now enters each retry's `generate` through
`with-sources observed`. This is the same dynamically scoped, flat, identity-based
ownership used by ordinary generator composition. No new record, guard chain,
retry runner, PRNG owner, namespace or registry is added. Old and newly returned
leaves still merge through the existing boundary before the predicate. A normally
returning revision suppresses the next stage; exceptions retain their exact cause
and unwind the dynamic context. Failed or exhausted generation never supplies a
property witness. This change does not add portable provenance to exceptions that
occur before a sample tree is returned.

The source scope ends before the tail retry call. The search therefore keeps its
existing tail recursion rather than growing one dynamic-scope frame per attempt.

The quota remains an exact nonnegative local number of generator entries. Zero
performs no entry; source refusal still precedes quota exhaustion. Rejection spends
one token, acceptance stops immediately, and callback errors are never retried.
The supplied size and random-source schedule are unchanged; there is no hidden
size growth or fallback domain. Nested filters keep independent quotas: two outer
entries can each spend three inner entries. Shrink tombstones remain separately
charged against the property consumer's existing shrink budget.

`examples/property-filters.ss` groups the older quota/shrink controls with the new
retry matrix under the existing standard suite. Coverage includes draw, map,
selection and inner-predicate revisions; multiple rejected owners; exact exception
identity and scope restoration; nested quotas and strict Boolean predicates;
accepted shrinking, identical seed replay, concrete replay without draws, obsolete
report refusal and explicit fresh retry. The independent library now runs all 63
cases without POO. The Record/Function/FUN workflow rejects construction after a
retry revises an earlier owner, then reprepares, shrinks, retains Function wrapping
and exercises both replay paths. No existing case is removed.

`PropertyFilters.lean`, in the existing PropertyTesting namespace, composes
`guardedGeneration`, `mergeSources` and `guardedStages`. Ten laws cover source
preflight, draw revision and exact causes, rejected/accepted history, zero fuel,
one-token retry continuation, early acceptance, a local entry-count bound and
nested-pipeline suppression. The draw explicitly receives its complete source
directory. Accurate/pure Boolean observers, faithful dynamic scope, faithful
returned directories and terminating sequential callbacks remain premises.
Runtime exceptions, wrapping, parameter unwinding and PRNG replay are separately
tested; they are not host heap, concurrency, GC or wall-clock theorems.

The added checks scale with retained source leaves and nested callback boundaries;
no constant-time or speedup claim is made. All resource limits and full/paired
checks remain required. Rackcheck's pinned `gen:filter` likewise composes a bounded
search with shrink-tree filtering. Its retry size policy differs; byte-for-byte
Racket behavior is not our contract. Its [documentation](https://docs.racket-lang.org/rackcheck/index.html)
also recommends direct domain construction when possible. This work repairs the
already supported finite filter protocol, not unrestricted rejection sampling.

## P24: transient admission throughout checked generator actions

The replay audit reproduced an action-boundary gap. A prior report had observed
a source on a rejected shrink branch. Replaying the root draw retired that source,
yet a following mapper ran before the outer replay guard finally reported stale.
The baseline mapper count rose from 2 to 3; the corrected replay remains stale at
2. The same gap affected a later ordinary trial, discarded-trial ownership and
multi-root generator inspection. This violates the existing visited-source rule;
it does not require the new generation to permanently inherit an old report.

The generator module now provides `with-generation-check`, a hygienic form backed
by Gerbil's standard dynamically scoped parameter. It installs a zero-argument
**interrupting check**, which raises or escapes on refusal; its return value is
not a Boolean predicate. The caller still owns action admission and publication.
Checks run outer-to-inner at the existing generator source boundaries, before
retained source leaves. They unwind with normal return, exceptions and the
runner's existing continuation-based refusal.

The property module's existing `with-current` action form installs its own check
for nested generation. Runs, seed/concrete replay, domain actions, shrinking and
inspection therefore reuse the same boundary without per-combinator wrappers.
The iterator fast path remains available when both retained ownership and active
checks are empty. With an active run check, even a source-empty iterator guards
factory calls, each pull and EOF. Original exceptions are not replaced by a
post-check; ordinary stale exits keep their original status/cause accounting.

Transient checks are deliberately separate from sample source ownership. A run's
checker can inspect its mutable visited-source ledger, so storing it in that
ledger would create recursive observation. Storing prior replay checkers on new
trees would instead accumulate old report chains. The implementation does neither:
producer/node leaves retain their existing flat identity protocol, and a new
report owns its newly observed leaves. Nested scopes compose while they are
active; no new record hierarchy, namespace, runner, PRNG or persistent registry
is introduced. Standard Gerbil continuation/iterator lifetimes remain in force;
arbitrary user-captured continuations and payload aliases are not certified.

Four generic controls in `examples/property-scopes.ss` cover earlier accepted and
discarded trials, inspection roots, rejected shrink provenance during replay,
exact causes, nested outer-refusal priority, empty-source paused iteration,
ordinary child demand after the scope ends and stable observer work across twelve
replays. The independent package runs all 67 cases without POO. The Record/FUN
example refuses late reconstruction after a replay retires an old branch, then
reprepares, retains Function wrapping and exercises fresh/stale replay. Resumable
iterator pulls are evaluated outside assertions so the coroutine does not capture
an assertion's private exception context. All prior cases and budgets remain.

`PropertyScopes.lean` uses the existing PropertyTesting namespace. Nine laws reuse
`guardedProduct`, `guardedStages` and source unions: empty and nested scope checks,
preflight/revision refusal, exact stage causes, empty observation, exact new-ledger
publication, stable value order and agreement of admitted scopes on published
ownership. Accurate pure observers, faithful source ledgers and host dynamic
scope, sequential callbacks and termination are premises. Runtime parameter
unwinding, repeated-replay costs and Function validation are separate regressions;
these are not proofs of arbitrary continuations, heap retention, GC or wall time.

Active actions add scope/check-list work and source walks at nested boundaries.
This is a correctness repair with no speedup or O(1) claim. Full and paired checks
and all process/heap limits remain required. Rackcheck's pinned map/bind and lazy
shrink-tree algebra remains the composition reference; run-local revision
admission is this project's explicit extension rather than an asserted Racket gap.


## P25: size control retains known input ownership

Audit of Rackcheck's `gen:sized`, `gen:resize` and `gen:scale` confirmed the
existing size algebra. Our revision-aware extension had a distinct implementation
hole: scale delegates to a statically known input but exposed only its explicit
owner. With that input retired, both scale and its enclosing fixed product
reported current; an earlier sibling draw and scale callback each ran once before
refusal. This is not a missing Rackcheck feature or a dynamic selection boundary.

Scale now reuses the exact sized/resize run procedure and merges the known input
leaves at construction, using existing source identity sharing. There is no new
wrapper per retained sample, random draw, size schedule or shrink regeneration.
Resize, map, fixed product, finite Function tables and shrink controls preserve
these leaves. A genuinely open sized selector does not acquire unselected branches.

Four independent generic cases cover all static compositions, explicit and input
owners, normal callback revision, original exception identity, invalid natural
sizes, nested callback order, identical seeds, retained shrinking, and zero-count
inspection. The independent standard-library package now executes 71 cases.
The Record/FUN example combines scaled counts and Function fields, failure
minimization, concrete replay without regeneration, seed replay, and stale refusal
before sibling preparation. Function wrappers remain owned by Record admission.

The eight laws in `PropertySizes.lean` establish pure resize/scale algebra,
exact delegated value/seed, and guarded preflight, revision, cause and admitted
execution. Total natural transformations are the pure algebra's premise; they do
not license fusing effectful Scheme callbacks. Explicit internal resize may exceed
the outer trial size: no new blanket bound is introduced. Existing process,
heap, generation, shrinking and inspection budgets are unchanged. No termination,
host PRNG quality, GC or wall-clock speedup is proved. Existing `mergeSources`
sharing avoids another ownership mechanism. At P25 construction reused the sized run
closure in a replacement generation descriptor; P26 below consolidates that
metadata into the sized constructor. No timing improvement is claimed.


## P26: mandatory collection ownership under size selection

The next audit reproduced a cardinality-dependent hole: an element generator
whose owner was already stale could be used to construct a nonempty List producer
that still reported current. Its enclosing fixed product ran an earlier sibling
draw once and used the random source twice before refusing. A positive minimum
always uses the element; this is not the intentional independence of an unselected
branch or empty result.

`generator-sized` now accepts `sources:` through the same observer-list boundary
as `make-generator` and `make-tree-generator`. Common leaves are validated, copied
and identity-deduplicated before selection. Dynamic branches still add only their
selected leaves. `generator-scale` delegates directly to that constructor,
removing P25's replacement generation descriptor. `generator-list` supplies element
leaves exactly when `min-length` is positive. String and Symbol inherit the same
behavior through their existing map composition. No separate carrier validators,
new generator representation, random schedule, namespace or retry system is added.

Size zero still produces the positive minimum, so it still needs those leaves.
With minimum zero, an actual empty result draws no element and acquires no element
owner. If that optional producer selects a nonempty result, its existing dynamic
selection boundary checks the selected element before drawing it. Arbitrary
unselected weighted/delayed branches, handwritten node ownership and mutable
payload aliases keep their documented boundaries.

Four generic cases cover nonempty List/String/Symbol preflight (including an
unstarted product prefix), empty selection, copied/deduplicated explicit source
lists, invalid metadata, identical seeds, retained minimum lengths and shrinking
without element redraw. The independent package runs 75 ordinary std/test cases.
A Record/FUN workflow generates bounded nonempty payloads with a wrapped Function,
shrinks both cardinality and element values, performs concrete/seed replay, refuses
stale work before preparing a sibling handler, and explicitly prepares a fresh
revision while the old sampler/report remain rejected.

Eight additional laws in `PropertySizes.lean` establish the bounded length offset,
positive-minimum participation, size-zero behavior, exact source selection,
conjunctive authority, stale preflight and preservation of an admitted result/state.
Random offsets satisfying their bound, pure accurate source observers and
terminating callbacks are premises. These are not PRNG-quality, host heap/GC,
concurrency or wall-clock proofs. Existing process and search limits are unchanged.
Source lists are captured once; runtime retains the existing flat source checks
and shrinking trees. Removing the replacement descriptor is not a timing claim.

Rackcheck's pinned [base generator implementation](https://github.com/Bogdanp/rackcheck/blob/ffbddb7a9edef6ce1d9e0930adae1bd7033f1db7/rackcheck-lib/gen/base.rkt)
selects a length once, retains element trees and derives mapped carriers from
that list protocol. We reuse that decomposition. Positive minimums and revision
observers are our explicit extension; no cross-language random-seed parity is claimed.


## P27: observed proposal admission before terminal publication

The shrink-consumer audit reproduced a terminal-budget inconsistency. A returned
filtered tombstone with a newly stale leaf was charged and recorded, but the scan
skipped value classification and published `failed` when its last token ran out.
The report already had `current = false`. Inspection of the same tree correctly
returned `stale`. Handwritten trees had declared accurate node leaves; consumer
admission, not hidden callback inference, was missing.

The scan now admits newly observed leaves through the existing `with-current`
action before classifying any proposal or publishing quota exhaustion. Both live
and pruned nodes share that boundary. No new tree representation, source registry,
runner, namespace or retry policy is added. A returned proposal is charged once
before refusal; EOF and iterator exceptions still produce no proposal to charge.
Zero fuel forces no factory or iterator. Exact exhaustion still performs no EOF
lookahead and does not claim local minimality. Original observer/iterator causes
are preserved, and the in-flight proposal never replaces a confirmed witness.

Four generic cases compare checking with inspection at budgets 0/1/2, verify live
pruning and EOF accounting, strict Boolean source judgments, observer/iterator
cause identity, and several independently owned pruned proposals. The isolated
standard-library package executes 79 cases. The Record/Function/FUN workflow
covers stale evidence, identity-sharing delivery, actual mapping's earlier
refusal, fresh preparation,
retained smaller witnesses and both replay forms. Actual child mapping refuses before
returning its stale child (zero charge); identity sharing and raw delivery return
the tombstone and consume one.
This distinction is preserved rather than hidden by changing the accounting.

Nine laws added to `PropertyFilters.lean` reuse `ShrinkEvent`, `auditShrinks`,
source union and the existing shrinking engine. They establish terminal refusal,
exact cause/charge, live pruning without value admission, unchanged real values,
zero fuel, attempt bounds, preservation of a valid false witness, and refusal of
new stale leaves despite earlier live metadata. `Option.none` is the pruned tag;
`some false` remains an ordinary value. The model covers finite observed events
and accurate pure source observers. It does not prove host callback termination,
iterator/continuation implementation, PRNG quality, global minimality or GC/time.
The runtime adds the existing flat admission checks at the missing consumer
stage; no performance improvement is claimed. All resource and search limits stay.

Rackcheck's pinned [filtering tree implementation](https://github.com/Bogdanp/rackcheck/blob/ffbddb7a9edef6ce1d9e0930adae1bd7033f1db7/rackcheck-lib/gen/shrink-tree.rkt)
filters lazy branches. Our already-established bounded protocol keeps charged
tombstones so filtering cannot hide work. Source refusal and terminal accounting
are our extension, not a claim that Rackcheck mandates revision observers.


## P28: exact bounded model draw configuration

The generic trace draw accepted non-natural steps and size directly as iterator
bounds. Before repair, steps `-1` and `1/2` each generated a command and invoked
initialization instead of refusing. Gerbil's standard range iterator intentionally
supports reverse and fractional ranges; it cannot supply this protocol's natural
step contract. Infinite bounds could also bypass the promised finite quota. This
is an implementation admission gap, not unrestricted callback termination.

`draw-trace` now uses Gerbil's existing parameter contracts for model identity,
draw/random procedures and exact natural limits. A shared private `trace-limit?`
serves both dimensions. Invalid configuration refuses before model initialization
or command callbacks. The same for/fold owns state and command order, the original
size is passed unchanged, and at most `min(steps,size)` draws may succeed. No
coercion, fallback limit, new framework, namespace, scheduler or PRNG owner is added.
A valid zero cap retains initialization once, including its original exceptions,
then performs no draw; this preserves the existing model initialization semantics.
Explicit stop still omits its unused payload. Disabled/invalid commands and
non-Boolean continuation judgments remain errors, never silently dropped inputs.

Four generic cases cover negative, fractional, inexact, NaN/infinite and malformed
limits in both dimensions; callable/model admission before effects; exact caps,
large natural limits capped by a small size, original callback size/state order,
false command payloads, early stop and exact initializer/draw causes. The independent
standard-library suite now executes 83 cases. A typed Record command with a wrapped
Function exercises state-dependent open/use generation, invalid size-policy refusal
before initialization, zero command cap, FUN differential fixture cleanup,
dependency-preserving minimization and both replay forms. The same action can retry
with a valid configuration; generation and concrete replay keep their distinct costs.

Nine laws in `PropertyTraces.lean` stage validated limits and initialization over
the existing `drawTrace` engine: invalid admission, original initializer cause,
zero steps/size, unchanged-size delegation, explicit stop, disabled command refusal,
valid prefixes bounded by both limits, and exact enabled payload delivery. The
existing remaining-fuel argument remains a finite observation index, allowing
different random choices at an unchanged logical state while size stays fixed. An
absent validated configuration models refusal; accepted limits are Nat values.
Runtime contract fidelity, normalized/faithful choices and callback termination
remain premises. These laws do not prove Gerbil contracts/compiler/iterators,
PRNG quality, arbitrary callback termination, host GC or wall-clock speedups.
The typed steps ceiling and all process, heap and search limits remain unchanged.

Rackcheck's pinned [generator contract](https://github.com/Bogdanp/rackcheck/blob/ffbddb7a9edef6ce1d9e0930adae1bd7033f1db7/rackcheck-lib/gen/core.rkt)
requires an exact nonnegative generation size. We retain that contract discipline
using Gerbil mechanisms; this project's finite model-trace API is an extension,
not a claim that Rackcheck implements the same state-machine protocol.


## P29: finite sequence preparation without prefix salvage

The audit reproduced two silent truncations. `valid-trace?` rejected a dotted
command spine while `repair-trace` initialized the model and returned its apparent
proper prefix. A parameter shrinker returning `(0 . bad)` likewise contributed a
candidate instead of refusing. A third control revised a declared source in the
first parameter callback: preparation still invoked the second callback before
the enclosing action eventually returned stale. These are observable preparation
defects, not inference of hidden dependencies or arbitrary callback termination.

The existing finite sequence policy now owns one spine boundary. `list-deletions`
uses Gerbil's standard `using`/`list?` contract before length/copy/traversal.
`data-list-shrinks` obtains structural proposals through that boundary once, then
uses the existing `with-sources` around each parameter callback and admits its
returned proper list with `using`. Model shrinking delegates to the same policy;
it adds no second input-spine check. Independent repair validates its own finite
input before folding. Model identity and callback procedure contracts stay with
Gerbil. Valid structural/coordinate ordering and callback invocation counts stay.
No partial candidate batch is delivered when preparation fails; already performed
host effects are not rolled back.

Only finite outer spines are constrained. Invalid trace predicates still return
false, and complete checking refuses before fixture entry. Proper inputs still
retire invalid/disabled commands according to the existing model policy, preserving
false command payloads and dependencies. Cyclic payload graphs are not deep-
traversed by a spine check. General lazy sample shrinkers still accept Iterators,
including infinite neighborhoods consumed under the unchanged proposal budget.
A cyclic cdr chain is malformed list data, not such an Iterator. No global eager
list conversion, compatibility layer, namespace or new shrinking engine is added.

Four generic cases cover improper, cyclic and non-list spines; no initialization
or prefix effects on refusal; malformed callback outputs; exact causes and charges;
source revision before the next coordinate; unchanged finite proposal order; and
bounded lazy Iterator admission. The independent package runs 87 standard cases.
`examples/generated-traces.ss` keeps new typed evidence separate from the large
batch module: Record commands with Function fields reject malformed parameter
batches before candidate repair, retain diagnostic witnesses with zero delivered
attempts, and replay/retry explicitly. A single codec-parametric Record/FUN fixture
covers String/Symbol/Bytes, rejects improper/cyclic outputs, interrupts shared-source
revision before the next parameter, preserves wrapping, and retries/replays valid
shrinking. Typed packing starts only after the complete finite policy returns.

Nine laws in `PropertySequences.lean` reuse the existing source-checked callback,
Except bind and dependency retirement: malformed input refusal, exact proper-input
forwarding, stale preflight, normal revision, original callback cause, malformed
result refusal, ordered proper-result delivery, suppression of later stages, and
valid order-preserving dependency repair. The host shape conversion represents
malformed spines by none; proper empty/false-containing lists remain present data.
Accurate source observers, faithful normalization and terminating callbacks remain
premises. This does not prove Gerbil contracts/list?, arbitrary payload graphs,
callback termination, host GC or wall-clock behavior. All guards and checks stay.
Shape checks add finite spine walks, and each parameter action walks its active
source ledger; no zero-cost or timing improvement is claimed. Existing identity
sharing avoids introducing a separate source wrapper per data carrier.

Rackcheck's pinned [shrink-tree contract](https://github.com/Bogdanp/rackcheck/blob/ffbddb7a9edef6ce1d9e0930adae1bd7033f1db7/rackcheck-lib/gen/shrink-tree.rkt)
requires stream-shaped general shrink results. We preserve that lazy-protocol
separation using Gerbil Iterators while enforcing the narrower proper-list
contract of this project's finite value policy. Revision checks remain our extension.

## P30: source-consistent generic model actions

The audit reproduced a missed action boundary, rather than expanding the model's
research scope: an ordinary source-owned generator called `draw-trace`, whose
initializer revised its declared owner. The outer generator eventually refused
stale, but three draws and three advances had already run. The same generic
model pipeline could continue through normalization, observations and actual
steps after a registered source or a run-local specification became obsolete.
The fixed control refuses with zero draws and advances after that initializer.

`testing/property/model.ss` now uses the existing `with-sources` form at caller
actions: model initialization/admission/normalization/preconditions/transitions,
draw callbacks, expected and actual observations, actual steps, equality, and
fixture entry/normal return. The generator module exports that existing hygienic
form for ordinary module reuse. No extra callback objects, source directory,
model evaluator, scheduler or POO-dependent kernel is introduced. Explicit
`let*` sequences expected observation before actual observation, so refusal can
suppress the latter during argument evaluation. Exceptions keep their original
cause and multi-value transitions are unchanged. Standard `try`/`finally` still
owns cleanup; refusing a source does not roll back earlier effects. General lazy
Iterator consumption, finite trace caps and shrink delivery accounting stay.

Five independent cases exercise all six drawing stages, shared admission and
retirement, reference/actual/equality/setup/teardown revisions, original causes,
false data and multi-values, and transient specification refusal with balanced
cleanup and a fresh retry. The independent standard-library package now runs 92
cases. `examples/generated-traces.ss` adds one Record/FUN scenario across initial,
draw, precondition and advance revisions: no property is entered after refusal,
repeat runs retain the same stage boundary, and a fresh preparation successfully
checks commands whose nested Function fields still reject invalid arguments.
A new run may capture a new snapshot; this does not renew an old report's replay
authority or require permanent invalidation of a sampler object.

Seven additional laws in `PropertyScopes.lean` compose the existing
`guardedGeneration` for two dependent actions: stale preflight, first-action
revision, original cause, exact continuation, final revision refusal, unchanged
fresh results/state, and suppression of all later continuations. Repeated finite
composition gives the action-chain interpretation. Accurate pure observers,
faithful stage/state encoding, serial terminating actions and pure model
transitions remain premises. The laws do not verify Gerbil contracts, host
unwinding, hidden mutations, arbitrary callback termination, concurrency, GC or
wall-clock performance. Executable cleanup controls are separate evidence.

The design retains Rackcheck's [stream-based shrink-tree composition](https://github.com/Bogdanp/rackcheck/blob/ffbddb7a9edef6ce1d9e0930adae1bd7033f1db7/rackcheck-lib/gen/shrink-tree.rkt)
and callback-oriented mapping rather than replacing it with an eager runner.
Registered revision checks are this project's extension, not a claimed missing
Rackcheck feature. Every newly protected action walks its active observer ledger;
no timing or zero-cost improvement is claimed. Existing resource limits and the
complete local/remote checks remain the acceptance gate for this revision.
