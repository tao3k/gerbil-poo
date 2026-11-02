# Function generation and observation

[Design index](../pbt-design-rfc.md)

These sections preserve their recorded implementation and acceptance history.
Case counts and commit identities belong to the named revision; current CI must
be checked separately. The finite laws retain their stated runtime premises.

On this page:

- [Bounded higher-order Function values](#bounded-higher-order-function-values)
- [Demand-driven FunctionArguments child derivation](#demand-driven-functionarguments-child-derivation)
- [Sound short-circuit admission of supplied Function call fields](#sound-short-circuit-admission-of-supplied-function-call-fields)
- [Inherited authority for finite function observations](#inherited-authority-for-finite-function-observations)
- [Bounded exact-ratio generation and canonical shrinking](#bounded-exact-ratio-generation-and-canonical-shrinking)
- [First-observed Function input declarations](#first-observed-function-input-declarations)
- [First-observed finite Function result tuples](#first-observed-finite-function-result-tuples)
- [Captured finite Function call requests](#captured-finite-function-call-requests)
- [First-return ownership of Function call declarations](#first-return-ownership-of-function-call-declarations)

## Bounded higher-order Function values

`testing/function.ss` generates Function ARGUMENT ROWS. Finite function values
now belong to the generic generator algebra; arbitrary procedures remain outside
the decidable domain. Quickcheck's documented
[`arbitrary-procedure`](https://docs.racket-lang.org/quickcheck/index.html) identifies
a separate useful capability to study after [Composable generation through the typed boundary](generator-control.md#composable-generation-through-the-typed-boundary), [Effective-trial coverage and property diagnostics](diagnostics.md#effective-trial-coverage-and-property-diagnostics), [Portable counterexample replay](replay.md#portable-counterexample-replay). Start with explicit finite
pure input domains, bounded memoization/equality and result generators, then use
existing Function contracts. Repeated equal inputs, multi-value results, keyword
interpretation, shrinking and stale-source refusal need joint acceptance.
Opaque/effectful callbacks and unrestricted higher-order inference remain explicit
boundaries; neither `Any` nor a universal function-correctness claim closes them.

[Effective-trial coverage and property diagnostics](diagnostics.md#effective-trial-coverage-and-property-diagnostics), [Portable counterexample replay](replay.md#portable-counterexample-replay), [Bounded higher-order Function values](function-generation.md#bounded-higher-order-function-values) share the existing runner; acceptance covers the following finite contracts. Each unit needs executable downstream examples,
fault controls, finite Lean laws and the complete existing checks in both PRs.
Concurrent linearizability, arbitrary callback termination, compiler verification
and automatic unrestricted Type derivation are not defects in this finite V1.

## Demand-driven FunctionArguments child derivation

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

## Sound short-circuit admission of supplied Function call fields

The audit found a value-admission defect in the project's `FunctionArguments`
recognizer. `(FunctionArguments (Function [Integer] [Integer]))` accepted the raw
row `("bad")`, while the real checked Function rejected that call with TypeError.
The field conjunction was evaluated and then discarded by a trailing let-body
`#t`. Positional validation also used eager `map`: an early false predicate could
still run a later throwing predicate and replace ordinary refusal with its error.

`testing/function.ss` now returns the actual field conjunction and uses Gerbil's
runtime `andmap` for the paired positional Type/value walk. It is the standard
short-circuit traversal in `src/gerbil/runtime/util.ss`, not another evaluator.
Each supplied positional/optional/rest/keyword field uses the existing source
boundary. A false field stops later predicates; an exception remains exact; a
registered revision refuses before the next field. There is no fallback Type,
new namespace, shape search, value-based clause backtracking or default evaluation.
Selection/encoding/decoding still use the runtime signature protocol, so ordered
case-lambda first match and keyword/escaped-literal interpretation are unchanged.
This guards the project's finite supplied-field walk, not arbitrary operations
inside a user Type predicate or unrelated Type implementations.

Six ordinary cases in the existing representation suite cover required/optional/
rest rejection, keyword ordering/omission and escaped literals, inherited producer
sources, shadowed clauses and exact errors, invalid generated rows rejected before
the property, and complex service integration. Real checked Function wrapping is
an independent rejection control. `service-admission-tests` extends the existing
signature-service example: explicit input domains, optional callback Lists and
keywords compose with actual service defaults, checked nested Functions and FUN.
The correct service passes; a host implementation discrepancy supplies a typed
witness that shrinks and supports concrete and seed replay. PropertyConfiguration
remains the standard Record. No generic-kernel dependency or runner is added; the
independent standard-library package remains 97 cases.

Eight `guardedAll` laws extend the existing PropertyProducts module with the
source-checked Boolean fold: empty admission, stale preflight, exact false/true
head behavior, revision refusal, original causes, equivalence to `List.all` for
fresh pure outcomes, and suppression of subsequent stages after refusal. Source
scope fidelity, fixed ordered supplied fields, accurate pure observers and
terminating predicate calls remain premises. A domain rejection is not a false
property witness; host contracts, arbitrary Type callbacks, termination, GC and
wall-clock behavior are not verified by these laws. Omitted inputs do no predicate
work; active supplied-field source checks still have their ledger cost. No timing
improvement is claimed.

The [Rackcheck filter structure](https://github.com/Bogdanp/rackcheck/blob/ffbddb7a9edef6ce1d9e0930adae1bd7033f1db7/rackcheck-lib/gen/shrink-tree.rkt)
short-circuits before constructing accepted descendants; the Gerbil standard
conjunction expresses the corresponding finite field-admission policy here.
The 1G source-interpreter aggregate-module load failed before suite execution and
is not counted as acceptance. The focused compiled suite runs through the standard
CLI with the same 1G/90-second gate; complete checks run without its focused filter.
Process, depth, search, node and proposal limits remain unchanged.


## Inherited authority for finite function observations

A standard TestSuite control retired an enclosing generation check and then
called a retained finite function. The call returned normally: `function-apply`
checked only its table's own sources. A property/encoder could therefore execute
its continuation after a now-unauthorized nested call, before its outer trailing
check refused. `function-table` had the same omission, while `function-domain`
did not check table ownership at all. This is a missing integration of the existing
checked-action protocol, not unrestricted higher-order function inference.

The existing generator module now has one private hygienic `with-function` form
over `with-sources`. Exact-row lookup, domain observation and portable table export
share its inherited checks and retained table owner before/after normal return.
`function-procedure` still delegates to lookup and Gerbil's multiple-value delivery;
there is no second dispatcher, record, namespace or persistent wrapper chain.
Unknown rows remain errors, keyword order/escapes remain raw row identity, and
observer exceptions retain their exact causes. Rows and result spines are still
copied; mutable payloads still require the application's declared source law.

Call-site authority is transient. A live immutable table can be called in a fresh
scope after an earlier caller retires; old property reports and replay receipts
remain retired. Constructing a table/ordinary procedure does not grant authority
or force it: admission occurs when observing or invoking it. No table constructor
or existing generator random schedule changes.

The pinned [Rackcheck generator core](https://github.com/Bogdanp/rackcheck/blob/ffbddb7a9edef6ce1d9e0930adae1bd7033f1db7/rackcheck-lib/gen/core.rkt)
retains tree ownership through map/bind rather than building another call engine;
its [property executor](https://github.com/Bogdanp/rackcheck/blob/ffbddb7a9edef6ce1d9e0930adae1bd7033f1db7/rackcheck-lib/prop.rkt)
uses dynamically scoped random/label state. We reuse our existing dynamic
source protocol at the retained value's observation boundary. Racket's code is
an abstraction reference, not evidence that it implements mutable POO revisions.

Six generic cases cover transient and retained parent refusal before local
observers, own-table refusal, original observer errors/strict booleans, keyword
rows/multiple values, detached spines, scope restoration, and interrupted property
and codec continuations with zero output. The independent suite requires 127
cases. A downstream Record/Function service composes retirement, explicit fresh
FUN preparation, retained shrinking, seed/concrete replay and portable table
round trips; normal Record initialization owns Function wrapping once.

Seven finite PropertyScopes laws reuse guardedGeneration and lookupFunction:
parent/owner refusal, stable observation, post-return retirement, exact errors,
known-row delivery and unknown-row refusal. Top-level examples show an old caller
rejected while a separately authorized caller uses the same table. Faithful
observers, finite immutable-by-protocol tables, serial terminating actions and
host dynamic-scope fidelity remain premises. No arbitrary Scheme procedure,
runtime, PRNG or concurrency proof is claimed. All existing resource/check gates
remain; this semantic fix makes no wall-clock speedup claim.

## Bounded exact-ratio generation and canonical shrinking

The existing Rational descriptor recognizes Scheme rationals and exposes pair
conversion, but automatic PBT derivation refused it with the explicit-generator
error. This was a missing finite numeric profile, not a request for unrestricted
Number/Real/Float generation. The original descriptor/PBT future-work direction
and [Rackcheck's integer construction](https://github.com/Bogdanp/rackcheck/blob/ffbddb7a9edef6ce1d9e0930adae1bd7033f1db7/rackcheck-lib/gen/base.rkt#L95)
guide the implementation: compose bounded primitive draws, map to the carrier,
then supply one lawful value-shrink policy. Rackcheck's `gen:real` draws inexact
values; this exact-ratio profile does not claim the same numeric coverage.

The existing generic generator module exports `generator-rational`,
`rational-weight` and `rational-shrinks`. Sized products draw a nonnegative
numerator magnitude, sign and positive denominator. Size bounds magnitude and
denominator growth; `max-denominator:` defaults to 128 and must be a positive
exact integer. Normalization uses Scheme division. Zero size gives zero; a cap of
one gives integers; resizing cannot bypass the cap. No new random owner is added.

One canonical rank, `abs(numerator) + denominator - 1`, controls shrinking. The
policy proposes numerator reductions and positive denominator-offset reductions,
normalizes, deduplicates and retains only strictly smaller canonical ranks.
Equivalent spellings cannot fake progress. The existing with-shrink operation
retains root provenance and installs this same policy in generic and typed paths.
Source checks, strict Boolean falsity, proposal budgets and both replays stay with
their current owners.

| Boundary | Accepted/profiled behavior |
| --- | --- |
| Default Rational drawing | Exact ratios; magnitude at most size and denominator at most min(size+1, cap) |
| Rational membership | Existing Scheme `rational?`, including finite inexact rationals |
| Value measure/shrink | Finite inexact inputs use their exact numeric value; proposals are exact ratios |
| Float, Real, Number | Still require explicit samplers; no implicit integer/ratio/Any fallback |

The value policy may change exactness, so representation-sensitive floating-point
properties need their own sampler. There is no uniform-over-rationals, NaN,
infinity, signed-zero representation or IEEE rounding claim. Rational's typed
bridge is a single from-generator call. Explicit `.generator` overrides retain
precedence; existing recursive List/Tuple/Pair/Maybe compilation handles the leaf.

Seven generic cases raise isolated acceptance to 139 cases. They cover bounds,
zero/cap-one profiles, invalid declarations, canonical descent/order, inexact
value policy, both replay forms, pair-codec recovery, original divide-by-zero
refusal before properties, and old-source rejection after fresh preparation.
Three typed cases cover nested carriers, explicit override precedence and an
exact-rate Record/List/Function service. FUN delivery shrinks a truncation defect
to a fractional witness, preserves Function wrapping through integer-pair corpus
replay, refuses retired sampler ownership and validates a freshly corrected action.
No rational atom or procedure is added to the portable envelope.

PropertyNumbers reuses the existing namespace and standard normalized Rat carrier.
Ten kernel laws prove canonical-key injectivity, zero-denominator refusal, pair
round trips, normalization bounds, signed size/cap bounds, zero/integral profiles,
strict candidate descent and rejection of value-equal aliases. Keys use the
canonical pair, avoiding dependent record comparisons in executable candidate
deduplication. Symbolic top-level examples reuse normalization identities; numeric
fixtures execute in Scheme. Existing source inventory and atom coverage include
the new files. No proof-producing literal-rational decision computations or
resource-limit changes are needed.

Faithful host exact arithmetic/exactification, primitive random ranges, finite
proposal lists, codec laws and serial source scopes remain premises. Rank counts
mathematical structure, not bignum bits, allocations, GC or wall time. The unit
advances the paper's future-work protocol, not compiler/runtime verification.

### Runtime acceptance: retained FunctionArguments layouts

`FunctionArguments` previously rebuilt a typed product and its source observers
for every draw, measure and value-only shrink. The report must retain visited
sources, so equivalent new observer identities also increased later trial checks.
The argument sampler now uses Gerbil's `:std/struct/lru`, bounded to 128 entries,
to retain a successfully prepared product and its generic core by selected clause,
positional count and ordered keyword names. This is sampler-owned metadata, not a
global registry. Eviction permits normal preparation again; failures never enter
the cache. No random state or argument values enter its keys or factories.

Unpacking decodes the actual current row, rather than closing over the first
row's values. Cached guards retain their original epochs: hits cannot renew stale
authority. The regression checks distinct value weights, valid strict shrinks,
and refusal of both old samples after a declaration revision. Existing tests
retain ordered-clause selection, omission, escaping, preparation retry, wrapping,
FUN, source interruption and seed/concrete replay coverage.

The 2026-10-31 macOS diagnostic used the unchanged `just check` entry, standard
Gerbil build/test, 12 configured cores and every existing heap/deadline. External
timestamps only observed its output; no runner, scheduling knob or build cache was
added. One successful old implementation run and one successful candidate
verification, both with 145 modules / 2,190 cases, measured:

| Phase, seconds | Old | Candidate verification |
| --- | ---: | ---: |
| Library / executable preparation | 35.22 / 3.33 | 30.13 / 9.37 |
| Test-package preparation | 78.73 | 56.48 |
| Main test CLI, including loading | 186.41 | 180.76 |
| Build-declaration acceptance | 7.77 | 2.67 |
| Collection / generator paired studies | 25.16 / 45.00 | 14.72 / 30.07 |
| Complete entry, including invocation overhead | 384.85 | 328.76 |

These complete-entry observations are not a cold-build speedup claim: the old
source transition rebuilt dependent callers, while the final verification reused
standard compiler products. An intervening candidate transition took 508.98s and
failed the unchanged isolated-library 60s build deadline, so it is **not** a pass
or a successful performance sample. Its test-package preparation spent 171.87s
wall / 77.16s user CPU, compared with 77.47s / 74.59s before. The independent
library inputs were unchanged. The failure and wall residual remain evidence;
neither a larger deadline nor an omitted check explains the successful rerun.

Within the successful complete runs, the same required-keyword/rest 100-trial
case fell from 51.63s to 7.01s. A separate unchanged 100-trial reproduction,
including sampler construction, measured 44.06s to 6.93s wall, 42.94s to 6.91s
CPU, 9.29s to 1.56s GC CPU, and 47.78GB to 8.28GB allocation. Full-process
prepared/executed counters additionally separated initial loading (10.08s versus
20.74s, not exclusive dyld time) from the case phase: CPU 103.63s to 54.93s,
GC CPU 19.13s to 9.46s, GC wall 22.21s to 11.72s and 490 to 230 collections.
The case phase includes independent child builds in wall time but not parent CPU.
Its raw cumulative allocation-counter delta fell from 146.09GB to 97.40GB; that
is not live memory or an exact retained-allocation measurement. Compiler waits,
child work and scheduling residuals are not mislabeled as GC or removed by
subtraction. These receipts demonstrate removed repeated preparation, not a
statistical tail guarantee or verified host/runtime performance.

### Cold admission and shared source-control execution

The source-control forms now lower to private higher-order procedures. Their
lexical body still executes once; pre/post checks, exception identity, nonlocal
exits and parameter unwinding are unchanged. Gerbil compiles that control flow
once rather than expanding it at every use. Generated runtime Scheme for the
property kernel drops from approximately 801KB to 229KB, and its generator from
292KB to 221KB. These are compiler-output sizes, not committed build products or
a proof that arbitrary callbacks execute faster.

Source union reuses Gerbil's `delete-duplicates/hash` and one shared identity table.
Processing right before left preserves its last-occurrence order without first
copying the complete concatenation. The new generic case checks an independent
standard-library union oracle, including repeated observers, and original error
identity/scope cleanup. Isolated admission therefore requires 140 cases.

Typed products intern captured owner identities once, retaining the earliest
revision. Repeated coordinates and shared dependencies no longer multiply pure
revision scans. Per-coordinate domains and user `.current?` hooks remain distinct;
the shared-dependency preparation fault matrix still refuses before later work.

Finite recursive graphs also prepare negative optional-hook metadata under their
existing checked scope. Only graphs with **no** current hook use the stamp-only
path; graphs containing any hook keep the original dynamic path. Every captured
revision is checked on every boundary, including revisions of samplers whose
missing hook was observed. An added own/inherited hook invalidates the old graph
before drawing or invoking that new hook. No hook result, PRNG instance or generated
value is cached. This relies on the existing revision-controlled metadata contract,
not on discovering unregistered dependencies of arbitrary readers.

Cold acceptance uses a fresh, initially empty standard `GERBIL_PATH` for each
implementation and standard `just clean` followed by `just check`. The released
SDK remains installed, as intended; project `.ssi`, objects and executables are
not copied between prefixes. Keep the 300s build, 600s complete-test and 60s
isolated-build/test guards and all existing heap bounds. The old cold entry took
664.88s: library build 97.96s, executable check 7.43s, test packages 180.49s,
main CLI 326.41s, declaration checks 2.53s and paired studies 47.64s, plus invocation
overhead. The main process separated 177.80s startup/preparation from 141.02s after
preparation; startup used only 6.42s CPU and 0.13s GC wall time. This wait is not
misreported as property execution or GC. Complete cold wall time and the same
per-phase counters are required for candidate admission, independently of hot
call measurements and reduced generated-code volume.

The first cold candidate passed 2,193 cases / 145 modules and the independent
140-case library. After-preparation test wall fell from 141.02s to 101.37s,
and independent compilation from 27.02s to 22.93s (68.26s to 58.44s aggregate
CPU). Its complete entry nevertheless grew to 723.14s: package preparation
grew from 180.49s to 280.70s with similar aggregate CPU. That run is not a
whole-entry performance pass. A short startup sample observed dyld `dlopen` /
`mapSegments` waiting in `fcntl`; it does not identify the syscall command or
justify attributing all waits to a particular macOS policy.

The standard compiler inventory is therefore grouped into four make graphs,
removing the two additional frontend launches and sharing their already imported
dependencies. All 25 canonical test packages / 144 main-module declarations,
included-source dependencies, output namespaces and runtime test order remain.
Existing CLI/test 1-GiB and compiler/backend 2-GiB ceilings are unchanged. The
build-declaration suite checks exact inventory coverage and forwards both build
and failure-cleanup actions through the same four standard Just dependencies.
This changes compiler-session lifetime, not test execution coverage. Final cold
admission still requires all checks and the complete entry's natural successful
exit; no failed or partially executed run qualifies because CPU use decreased.

## First-observed Function input declarations

The audit found a preparation defect, rather than a missing generator domain:
a delayed nested signature keyword getter could revise its enclosing Function.
The old FunctionArguments sampler then captured the new epoch and returned current.
The frozen reproduction checks revision/read count 0 immediately before public
`generator` entry; the old result was revision 1 / accepted-current. Effects during
caller-side initialized object construction are outside this boundary.

FunctionArguments now captures the Function before its signature getter, clauses
before clause metadata, and each returned positional/optional/keyword/rest Type
before the next getter. It reuses the typed source ledger and action scope through
normal module imports. Field spines and keyword entry pairs are copied at discovery;
known identities never renew their first epoch. The existing early keyword-mode
pass and ordered clause semantics remain. Metadata callback causes, including
thrown false and MOP's self-mutation error, keep their original precedence.

One source guard on the existing shape generator carries the completed epochs
through bind, the standard 128-entry LRU, products and lazy child promises. There is
no second cache, signature clone, replacement parser, or per-consumer wrapper.
Shadowed and omitted children stay unforced; output Types and optional defaults
are not inspected to generate supplied inputs. A cached layout cannot acquire new
authority by a hit or by clearing a sampler's public dependency list. Fresh retry
requires explicit new preparation, while old reports remain obsolete.

Six regression cases cover Function/clause retirement, earlier positional and
keyword Type retirement, exact callback causes and dynamic-scope restoration,
dormant inputs in ordered signatures and cached-layout renewal refusal. The complex
service example combines nested Function callbacks, List inputs, optional/keyword
shapes, a FUN action, shrinking, concrete/seeded replay, retirement and explicit
corrected retry. Existing unsupported-domain failures remain explicit.

Eight finite Lean laws in PropertyPreparation model guarded discovery, exact
causes, first-observation retention, stale cached work, bookkeeping cardinality and
refusal before construction. Top-level examples include duplicate input IDs,
false causes, obsolete layouts and explicit renewal. Source clocks, faithful
shallow copying, standard MOP behavior and terminating callbacks are premises.
Unversioned mutation of hidden metadata aliases and concurrent heap isolation are
not proved. The size bound counts retained identities, not elapsed time or total
hash-table work. This is the RFC's finite future-work protocol, not a claim about
the compiler/runtime or completion of unrestricted recursive/type generation.
All full acceptance checks and resource limits remain unchanged.

## First-observed finite Function result tuples

Two public probes exposed late aggregate admission. A first result producer
returned an invalid scalar, yet the next row still ran and threw false, replacing
the tuple-protocol error. A later draw could also change a previously returned
tuple spine before the final table copied it: the first row changed from `(7)`
to `(99)`. This is the finite table's ordered result boundary, not unrestricted
procedure inference or a promise to freeze arbitrary generated payloads.

The generic generator now maps one private tuple recognizer/copier over the
result producer before building the existing fixed product. Each normal result
must be a proper finite list and its spine is owned before the next draw.
`function-tree` receives only that checked product and no longer repeats a full
shape scan and tuple copy for every assembled table. This uses the existing
`generator-map` and `generator-sequence` algebra, without another protocol, public
namespace, sampler class, iterator, random-source owner or compatibility path.

Ordinary malformed tuples retain `finite function results must be value tuples`,
now with the first offending tuple as irritant rather than a completed aggregate.
Original draw exceptions, including raised false, remain exact. Source retirement
still wins after a normally returned draw and before tuple admission. Empty tuples
mean zero return values; a tuple containing false remains present data. Malformed
lazy children still fail before returning a proposal and therefore do not acquire
a proposal charge. Existing raw keyword rows, call forwarding and multiple-value
delivery stay with the standard finite-function procedure. Empty input directories
invoke no result producer; the outer generator keeps its own source admission.

This captures stored result tuple spines only. Mutable payload objects and hidden
preimage values retain their declared immutability/source obligations; mapping
does not deep-freeze an advanced producer's original tree. Coordinate shrinking
continues to retain unchanged product siblings and their first-observed sources.
Seed splitting, supplied result neighborhoods and portable table restoration are
unchanged. No wall-clock or universal allocation improvement is claimed.

Four independent cases cover early malformed/cyclic/improper tuple refusal,
shallow spine ownership with payload identity, source/cause/charged-proposal
priority, and seed-state equality, real shrinking, both replays and portable
finite-table restoration. All previous cases remain; the isolated package now
requires 216 cases. A complex Record/Function/FUN service deliberately produces
an invalid first result and a later false cause, repairs explicitly, shrinks a
real finite dispatch table, validates Tuple wire data, restores wrapped Function
fields and rejects old source epochs before fresh retry.

Eight finite Lean laws in PropertyProducts reuse `finiteSequenceParameters` for
the same ordered guarded traversal. They prove empty-row behavior, first refusal,
first tuple retention, no partial table on tail failure, head lookup, exact table
length and complete key/order preservation. Five top-level examples distinguish
malformed results, false causes, source retirement, captured false data and
zero-value tuples. Faithful shallow host copying, the fixed product invariant,
accurate source observers, declared payload laws and terminating sequential
callbacks remain premises. These are finite protocol proofs, not verification of
Gerbil/Gambit, arbitrary mutable preimages or unrestricted Function behavior.
This advances the paper's future work.

The pinned Rackcheck `gen:bind` and shrink-tree mapping remain the source model:
compose admission into the retained producer tree, rather than redraw or validate
an already completed aggregate. This unit changes neither that seed discipline
nor the existing lazy shrinking policy. All checks, heaps, compiler completion
and cancellation behavior remain unchanged.

## Captured finite Function call requests

The audit reproduced a request-ownership defect through public function-apply.
The caller supplied `(declared)` to a table containing declared and retargeted
rows. Its table observer rewrote that caller-owned spine before lookup, and the
call returned the retargeted row's `(2)` instead of the requested `(1)`. The same
ordering allowed malformed direct request spines to enter source observation.
This concerns finite request topology, not inference about arbitrary Functions
or deep immutability of argument payloads.

The generator module now has one private function-results operation containing
the existing with-function source boundary, exact-row lookup and detached result
tuple. Public function-apply admits a proper finite list and shallow-copies its
spine before entering that operation. The ordinary function-procedure passes its
already owned rest row directly to the SAME operation. There is no second lookup,
per-call Type wrapper, new record, module or namespace. The procedure path adds
no request recopy; the direct public path pays for one copy of its row width.
Gerbil still owns rest construction, keyword forwarding and multiple values.
No host allocation/time theorem or latency improvement is claimed.

A malformed direct row refuses through the standard contract before inherited
or table observers. Well-shaped requests retain their existing inherited/table
source priority, strict Boolean judgments and exact callback exceptions. Unknown
rows keep the ordinary finite-domain Error, now carrying the captured request
rather than a retargeted spine. Raw keyword order and escape representation stay
part of row identity; no call-language decoding or value normalization is added.
Source changes still refuse normal publication. Payloads, including false values,
mutable domain objects and procedures, retain their identities and declared source
laws. This does not freeze nested mutable payloads or roll back observer effects.

Four generic regression cases cover source-side head/improper/cyclic spine edits,
pre-observer refusal of malformed direct requests, captured unknown-row diagnostics
with payload identity, and shared direct/procedure behavior for empty rows, zero
and multiple values, raw keywords, false/object causes and stale tables. The cases
join the existing PropertyProducts example module and ordinary kernel suite;
there is no new runner/module inventory. The isolated standard-library package
requires 231 cases. Existing [Inherited authority for finite function observations](function-generation.md#inherited-authority-for-finite-function-observations) inherited-scope and [First-observed finite Function result tuples](function-generation.md#first-observed-finite-function-result-tuples) result-tuple tests remain.

The existing finite-service Record/Function example composes FUN preparation,
first-row malformed-result refusal, real shrinking, seed/concrete replay and
portable Tuple restoration. Its decoder deliberately exposes a raw call row to
the restored table's observer; the direct call must retain the requested first
result before normal Record construction wraps the Function. Owner revision still
rejects the old report/codec and explicit fresh preparation retries. The example
uses the standard codec and existing service factory rather than a new adapter.

Seven finite PropertyProducts laws reuse guardedGeneration and lookupFunction:
malformed requests skip source actions; stale preflight, observer exceptions and
post-observation retirement refuses normal publication; lookup errors keep their
cause without a trailing check replacing it; admitted lookup uses
the initially captured row; missing rows cannot be retargeted into known rows;
and an already owned procedure row delegates to the identical operation. Five
top-level examples distinguish changed caller state, unknown rows, skipped throwing
observers, empty rows and false results. Faithful proper-list recognition/shallow
copying, standard rest ownership, source normalization, terminating sequential
actions and lawful payload equality remain premises. No compiler/runtime or
unrestricted concurrent-mutation proof is claimed. This advances future work.

The Rackcheck/Quickcheck map/bind comparison remains the abstraction reference:
retain the same finite value/tree and ownership boundary rather than introduce
another executor. This unit closes our [Inherited authority for finite function observations](function-generation.md#inherited-authority-for-finite-function-observations) finite-call request boundary, not a
missing Racket feature. The explicit [Source-consistent error classification and terminal diagnostics](diagnostics.md#source-consistent-error-classification-and-terminal-diagnostics) rule that invalid classification symbols
are API errors was audited and retained as a design boundary. Complete checks,
original heaps, natural compiler/test completion and cancellation stay unchanged.

## First-return ownership of Function call declarations

The next audit checked call generation alongside dependency shrinking and replay.
[Bounded exact-ratio generation and canonical shrinking](function-generation.md#bounded-exact-ratio-generation-and-canonical-shrinking) owned declarations before LATER metadata getters, but its read action returned
through inherited source observers before signatures/input/keyword/rest owners
were registered. A supported .set! revision at that exact boundary produced
`changed=#t accepted-current=#t`. A complex optional/keyword CaseFunction probe
then entered an input factory and the target instead of refusing preparation:
`first-status=failed factories=1 properties=2`. This is a declared-source version
hole, not unrestricted inference or an untracked payload-mutation request.

FunctionArguments now performs each metadata capture inside its existing read
action. A complete source row first passes ordinary Object admission, then pure
identity/revision bookkeeping extends the existing ledger before any returning
observer. Required/optional input and clause rows own their copied spines; keyword
capture constructs its owned spine and entry pairs directly with one map, then
registers the Types. Present rest Types use the same action; false remains absence.
There is no speculative child derivation. The early keyword pass and existing
metadata read order, including repeated rest reads, stay intact.

One read operation carries either the captured metadata or its stored preparation
failure using standard multiple values and an explicit refusal Boolean. Raw getter
exceptions remain outside that catch and bypass trailing checks unchanged. Pure
shape/member errors are raised only after the original source gate; observer
causes retain priority, including a thrown false. Whole-row member admission
precedes stamp publication, so invalid later members do not partially publish a
new row. The previous nested snapshot/observer passes in retain! are removed;
the getter boundary now owns those checks. No new registry, record, namespace,
framework, public API or compatibility path is introduced.

Four focused cases cover signatures, inputs, optional, keywords and rest; first
return revision before all factories; exact getter/observer false and object
causes; Object member refusal before later fields; and one shared promised Type
across multiple positional, optional, rest and keyword positions. The existing
signature-service suite adds a complete ordered CaseFunction with optional nested
Function callbacks, keywords, host defaults, layout caching and a shadowed unsupported
input Type. Initial retirement is a stale preparation report with zero factories,
properties, defaults and attempts. Fresh preparation genuinely shrinks the input,
reuses one child factory, never forces the shadowed child, preserves checked target
admission, replays both seed and concrete failure, rejects old owners and retries
a corrected property through FUN. Generic kernel code and its 239-case independent
standard-library suite are unchanged; module registration/entrypoints are reused.

Eight PropertyDiscovery laws model successful pure capture with source rows and
owned payloads, or failed capture with no published new stamps. They prove exact
successful delivery, retirement before publication, delayed member failure,
observer priority over failed and successful capture, known-epoch retention,
prior-stale refusal and suppression of dependent factories/targets. Five top-level
examples distinguish newly revised Types, duplicate identities, false observer
causes, false capture causes and ordinary false rest metadata. Existing
captureSources_cost supplies ledger growth bounds. Object recognition, primitive
revision reads, pure bookkeeping, faithful row copying and terminating sequential
callbacks remain premises; validation of arbitrary redefined fundamental Object
behavior or compiler/runtime semantics is not claimed.

Shape selection and runtime Function admission still use the declared Function
under the existing explicit revision discipline. This does not freeze arbitrary
Type payload mutation without revision, clone the entire call language, infer
opaque callback dependencies or prove callback termination, GC/RSS or latency.
The source-epoch gate is the concrete future-work construction being closed here.

The author/Racket composition reference remains one owned declaration boundary,
then the existing promise, product, LRU and replay algebra. Gerbil using, with-catch,
values and standard hash/list operations implement it; Record/Function and FUN
express the downstream workflow. Complete checks, 2 GiB main/1 GiB isolated guards,
cancellation and authorized natural compiler/test completion remain unchanged.
No upstream edits, versioned JSON, full benchmark artifacts or subagents are added.
