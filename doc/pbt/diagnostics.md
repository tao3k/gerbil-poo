# Property diagnostics and test integration

[Design index](../pbt-design-rfc.md)

These sections preserve their recorded implementation and acceptance history.
Case counts and commit identities belong to the named revision; current CI must
be checked separately. The finite laws retain their stated runtime premises.

On this page:

- [Effective-trial coverage and property diagnostics](#effective-trial-coverage-and-property-diagnostics)
- [Standard test integration and named multi-argument properties](#standard-test-integration-and-named-multi-argument-properties)
- [Bounded generator and shrink diagnostics](#bounded-generator-and-shrink-diagnostics)
- [Default POO test and debug workflow](#default-poo-test-and-debug-workflow)
- [Source-consistent error classification and terminal diagnostics](#source-consistent-error-classification-and-terminal-diagnostics)
- [Authoritative standard assertions and checked diagnostic rendering](#authoritative-standard-assertions-and-checked-diagnostic-rendering)
- [Diagnostic request admission before typed preparation](#diagnostic-request-admission-before-typed-preparation)
- [Prepared named diagnostics across report observation](#prepared-named-diagnostics-across-report-observation)
- [Captured preparation refusals across diagnostic rendering](#captured-preparation-refusals-across-diagnostic-rendering)

## Effective-trial coverage and property diagnostics

Original [Effective-trial coverage and property diagnostics](diagnostics.md#effective-trial-coverage-and-property-diagnostics) finding: reports had trial counts but no effective-trial classification
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

## Standard test integration and named multi-argument properties

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

## Bounded generator and shrink diagnostics

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

## Default POO test and debug workflow

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

## Source-consistent error classification and terminal diagnostics

Audit reproduced a completed `unsupported` report whose `report-current?` was
already false: the original draw threw, the error classifier revised its own
specification source, and `failure-status` checked currentness only before calling
that classifier. Inspection used the same exit. A classifier could also start a
nested generator after retiring the current run and execute its mapper before
publication was eventually checked.

`failure-status` now reuses the existing hygienic `with-current` action. A local
refusal continuation returns `stale`; the standard dynamic checker also protects
nested generator/domain callbacks. Normal return observes the same currentness
again. No new report, exception type, wrapper per callback or classification engine
is added. Run-local scopes unwind normally and are not stored on reports.

The original callback cause always remains the report's cause. A secondary
classifier or source-observer exception yields `error` with that original cause;
a classifier's normal return after source revision yields `stale`. Precise stale
and built-in bounded-generation exhaustion keep their precedence and do not invoke
the application classifier. Stable lawful classifications remain `error`,
`exhausted` or `unsupported` (and the existing allowed `stale` outcome). Invalid
classification symbols remain API errors; they are not accepted as reports.
Interrupted shrinking retains the last confirmed witness, charged attempts and
accepted steps, but cannot certify a minimum or authorize concrete replay.

Six generic regression cases in `examples/property-scopes.ss` cover execution and
inspection, nested effect suppression/unwinding, secondary errors, built-in outcome
precedence, partial shrink progress and explicit seed replay. They register in the
existing independent standard TestSuite; the isolated stdlib-only library grows
from 97 to 103 cases. There is no new module inventory or test runner.

`service-classification-action` in `examples/generated-products.ss` provides the
complete downstream composition. POO owns a strict service Record with UInt count
and checked Function, typed sampler sources and validation. The independent runner
owns the application error classifier and generic report. Reader/FUN bind delivers
that report once. Negotiation replaces a declared recipe while classifying its
service failure; the obsolete normal classification is refused, the original
cause is retained and old seed replay is rejected. Explicit fresh preparation
then draws validated Records, shrinks the service discrepancy, retains Function
argument checks and supports both concrete and seed replay. Reusing the old action
still refuses without another classification. PropertyConfiguration is unchanged.

Six `classifyFailure` laws in `PropertyScopes.lean` reuse `guardedGeneration` and
the existing CheckStatus vocabulary. They establish stale preflight, revision
refusal, secondary-error handling, exact stable classification, preservation of
the original cause and non-passing/non-falsified outcomes under a lawful classifier.
Top-level examples exercise recipe replacement and explicit fresh epochs. Accurate
pure total source predicates, faithful host dynamic scope, terminating serial
callbacks and valid classification outputs are premises. Observer exceptions and
host continuation cleanup remain executable tests; no Scheme evaluator, arbitrary
callback termination, GC or wall-clock behavior is proved.

The pinned [Rackcheck property executor](https://github.com/Bogdanp/rackcheck/blob/ffbddb7a9edef6ce1d9e0930adae1bd7033f1db7/rackcheck-lib/prop.rkt)
separates property execution and shrink-tree descent but intentionally maps property
exceptions through `pass?` to falsification while retaining the exception. This RFC
keeps its established stricter failure vocabulary; dynamic source authority is our
extension, not a missing Rackcheck promise. Lazy tree structure, forcing policy,
random schedule, domains, quotas, independent library ownership and process/heap
limits are unchanged. Classification source checks have a cost; no wall-clock
speedup is inferred from suppressed callbacks.


## Authoritative standard assertions and checked diagnostic rendering

A standard TestSuite reproduction ran a false property, then supplied a custom
formatter returning `((status . passed))`. The old assertion marked the case OK:
`require-passed` admitted formatted fields rather than the actual report. A second
path allowed formatting to retire a previously passed report's sources and still
return a passing label. These are false-success defects in the standard assertion
boundary, not a claim to sandbox arbitrary Scheme code.

`testing/property/test` now takes the actual kernel report. The formatter supplies
finite symbolic diagnostic fields only. Canonical status/cause replace every
formatter copy of those reserved fields; duplicated labels cannot change truth.
Passed reports check their sources before and after formatting and install the
existing inherited checked-action scope, so nested work is interrupted after
retirement. Already obsolete passed evidence skips rendering. The assertion macro defers
formatter expression preparation until the owned callback; ordinary eager
argument evaluation by a direct function caller remains outside that call. Nonpassing historical
reports remain diagnosable but cannot authorize success. Original report failures
outrank rendering errors, which are retained separately as `diagnostic-cause`.
Renderer/observer exceptions on passing evidence retain their original identity.
No property, draw, shrink or replay is repeated to decide the assertion.

POO's existing `support/testing` consumes the execution retained by its Record
report. `require-property-passed` also accepts reports delivered through FUN/Reader.
Missing execution always refuses; its static typed preparation receipt supplies
the original status/cause independently of a custom renderer. The generic
`refusal:` option is diagnostic context for missing execution and cannot authorize
passed. There is no diagnostics-as-authority compatibility path, new namespace,
report class, test runner or POO dependency in the independent kernel.

The pinned [Rackcheck RackUnit integration](https://github.com/Bogdanp/rackcheck/blob/ffbddb7a9edef6ce1d9e0930adae1bd7033f1db7/rackcheck-lib/rackunit.rkt)
branches on `result-status` and uses rendering to construct failure messages. We
follow that separation while retaining this RFC's distinct error, stale, coverage
and exhaustion outcomes and Gerbil's standard do-check!/TestError ownership.
The complete-source/parent checks and process/heap/depth/proposal limits remain
unchanged. Callback termination, truthful source observers and faithful report
metadata remain premises; private-record forgery is not a security boundary.

Six generic cases cover forged/doubled status and cause, nested interruption,
stale preflight, secondary formatting faults, exact observer/renderer exceptions,
malformed fields and missing execution. The isolated stdlib-only suite now requires
121 cases. Three typed cases preserve execution/preparation failure and inherited
ownership. The standard refusal fixture grows from eight to eleven cases, explicitly
requiring all eleven failures and zero CASE-OK markers. A Record/Function service
example composes FUN reports, shrinking, both replay forms, forged formatting,
retirement and fresh preparation without another report abstraction.

Seven finite laws in PropertyScopes separate report presence, nominal status and
source authority from arbitrary rendered payloads. They prove missing/nonpassed
refusal, stale preflight, post-render retirement, stable admission, precise renderer
causes and the necessary authority for success. The model concerns admission and
protected status/cause; arbitrary presentation fields and the host's exception/
TestResult machinery are not verified. It extends the paper's future-work protocol,
not the original concrete evaluator or a compiler proof.

## Diagnostic request admission before typed preparation

The audit reproduced a diagnostic ordering defect through the public typed
inspect-generator entry: count -1 still forced a computed generation getter. Its
exception replaced the configuration refusal, with one metadata evaluation and no
legitimate inspection. Static diagnostic requests must be admitted before source
observation, descriptor discovery, owned factories or raw binding.

The existing generic configuration conjunction now has one exported module owner,
check-inspection-request. Both generic inspection and the typed bridge call it;
there is no new request record, wrapper stack, namespace, scheduler or observer
registry. It recognizes exact nonnegative seed/count/size/depth/proposal-budget
values and callable label/classifier hooks without invoking them. The same ordinary
Error and message remain the request failure. Zero count and zero traversal fuel
are legal; arbitrary-size exact seeds remain legal. This preserves the deliberate
difference from Rackcheck's pinned gen/core.rkt contract-out, whose sample count
is positive: we follow its contract-before-execution separation, not its API or
random schedule. PBT remains future work beyond the author's concrete constructs.

Five regression cases cover every numeric control with negative, fractional,
inexact and wrong-type values; malformed callbacks in both layers; zero controls
with no draws/labels; exact false/object preparation causes and stale sources; and
a complete callback-service workflow. The latter inspects bounded FunctionArguments
with optional/keyword parameters and nested List/Function callbacks, compares
wrapped calls, then runs FUN-delivered failure shrinking and seeded/concrete replay.
Owner revision invalidates the old diagnostic and witness; a fresh corrected
service passes. Static rejection performs no metadata or source callbacks, while
valid preparation errors remain ordinary exceptions and execution retains existing
inspection status, budget and cause behavior. This adds no property evaluation to
the diagnostic engine: the example explicitly supplies a label callback.

Ten Lean laws normalize exact integers into optional Int controls, establish
nonnegative/malformed/callable admission and legal zero budgets, and compose the
existing admitReplayRequest and guardedGeneration boundaries. Invalid requests skip
all preparation, valid requests keep the original guarded result, stale/revised
sources refuse, and original causes and stable results remain exact. Top-level
examples include a large exact seed and stale authority behind an invalid request.
Faithful host normalization, callable recognition, source accuracy, callback
termination and standard FUN/IO delivery remain premises; this is not a proof of
Gerbil expansion/runtime, elapsed cost or arbitrary effect rollback. All complete
checks and process resource limits remain unchanged. No latency claim is made.

## Prepared named diagnostics across report observation

The audit reproduced a presentation ownership defect: report-diagnostics admitted
caller-owned binding names, then report-current? could invoke a source observer
which rewrote those names. A request for `declared` consequently rendered
`retargeted`. The typed facade also read computed `execution` metadata before
admitting the binding directory; preparation-only reports ignored invalid names.

The existing generic property module now owns prepare-report-diagnostics. It
admits a finite, unique symbolic directory and copies its spine once, returning
an ordinary reusable formatter. report-diagnostics delegates to it; the typed
facade prepares it before reading computed report metadata and passes a completed
execution directly to the same formatter. Standard :std/test consumers can bind
this formatter once and reuse it without a POO dependency. This follows the
existing higher-order FUN style; there is no new namespace, report record, source
cache, authority protocol or additional value wrapper. Generated payloads remain
shared. Empty or width-mismatched rows remain ordinary data, never truncated zip
bindings. A prepared formatter captures names, not report status or currentness.

Four independent regressions cover cyclic caller edits during observation,
reusable vector/false binding, stale standard assertions, malformed/duplicate
requests before observers, exact historical causes and unmatched rows. Independent
acceptance increases from 196 to 200 cases. Two typed service cases reject invalid
names before computed report reads and combine inherited getters, FunctionArguments,
nested List/Function service calls, Record PropertyConfiguration, FUN delivery,
failure shrinking and both replay forms. No callback exception becomes a false
property, no stale report becomes passing, and historical failures remain readable.

Eight finite Lean laws model full-row binding and capture-before-observe: invalid
names skip observation, old names survive state revision, original causes and
false currentness remain exact, empty/mismatched rows remain undecorated and fresh
invocations capture fresh names. Executable examples include a false payload,
duplicate rejection and an observer replacing the caller directory. Faithful
finite host copying, symbol recognition, observer accuracy, callback termination
and existing FUN/IO/standard-test delivery remain premises. This advances the
paper's future work, not compiler/runtime verification. All complete checks,
compiler guards and process resource limits remain unchanged; no timing claim.

A downstream suite can prepare its renderer before any assertion observations:

```scheme
(import :std/test
        (prefix-in :clan/poo/testing/property p.)
        (prefix-in :clan/poo/testing/property/test property.))
(def render-request (p.prepare-report-diagnostics '(request)))
;; Inside an ordinary test-case, report is the existing completed kernel report.
;; (property.check-property report diagnostics: render-request)
```

The formatter does not run a generator or authorize a passed assertion. Reuse
with another report always observes that report's own authority.

## Captured preparation refusals across diagnostic rendering

The audit reproduced a break in [Authoritative standard assertions and checked diagnostic rendering](diagnostics.md#authoritative-standard-assertions-and-checked-diagnostic-rendering)'s original-cause guarantee. With no kernel
execution, `require-passed` admitted a finite symbolic `refusal:` alist and retained
its caller-owned directory. A formatter could replace one field with a symbol and
then raise a secondary cause. Fallback traversal subsequently raised a host
RuntimeException rather than the standard TestError carrying the preparation
cause and the separate rendering fault. This is a library-owned presentation
boundary, not a request to sandbox arbitrary Scheme effects.

The existing assertion owner now captures the fallback directory AND each field
pair with one ordinary map before invoking the formatter. Header selection uses
that same captured receipt; there is no new record, wrapper, runner, namespace or
second renderer. Copies are shallow: payload identities, including false causes,
Function values and mutable domain objects, remain shared under their declared
ownership laws. The boundary admits a finite symbolic alist before copying it;
malformed/cyclic initial requests still refuse before any formatter callback.

Only fallback ownership changes. A present current passed report still follows
its original source checks and error behavior. Missing execution never passes;
canonical status/cause cannot be replaced by display fields. A valid formatter's
returned display fields still take precedence over fallback details. A malformed
return or thrown rendering cause keeps the original refusal, and the secondary
fault remains `diagnostic-cause`. No property, generation, shrinking or replay is
repeated for diagnostic delivery. User effects and nested mutable payload writes
are not rolled back or deep-copied.

Three generic regression cases exercise field-pair edits, improper/cyclic spine
edits, exact primary and secondary identities, payload identity, malformed alias
returns, valid replacement display fields and pre-callback request rejection.
The isolated standard-library package requires 227 cases; all previous cases stay.
A complex existing Record/Map/Function service uses a FUN-produced preparation
refusal, corrupts its supplied presentation fields and throws while rendering,
and verifies the standard TestError still retains the preparation phase and both
causes. Correct configuration starts a fresh run, really shrinks the service
state, preserves nested Function contracts and both replay paths, rejects an old
source epoch, and admits an explicitly freshly prepared retry.

Six finite laws extend the existing PropertyScopes model: initial-field retention,
exact rendering result/cause, unchanged fields after state changes, renderer
noninterference and composition with the existing missing-execution assertion
rule. Three top-level examples retain field order, duplicate display names, false
data and false causes. Faithful host shallow allocation, finite admitted fields,
source-observer laws, terminating sequential callbacks and standard TestError
transport are premises. These laws do not prove host mutation/exception machinery,
arbitrary concurrent writes, or immutability of shared payloads. This advances
the paper's future work.

The Rackcheck/Quickcheck comparison retains the existing generator/tree algebra;
this unit closes our [Authoritative standard assertions and checked diagnostic rendering](diagnostics.md#authoritative-standard-assertions-and-checked-diagnostic-rendering) standard-test ownership guarantee rather than claiming a
missing Racket feature or changing its shrinking policy. Gerbil's existing module,
map, error class and :std/test boundary own delivery. Design review deliberately
kept capture at the one assertion boundary rather than adding copy/validation
wrappers to typed reports or FUN consumers. Complete checks, original heaps,
natural compiler/test completion and cancellation behavior remain unchanged.
No latency or universal allocation improvement is claimed.

