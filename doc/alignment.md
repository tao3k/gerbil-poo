# Lean / Scheme implementation alignment

This map covers concrete original constructions and explicitly labelled
generalized-protocol future work used by the current closure workflow. A Lean proof/type is not mechanically reproduced as an extra
Scheme wrapper. Scheme implements the corresponding executable operation and
checks the runtime premises at its public boundary.

| Construction/publication capability | Lean owner | Scheme owner | Alignment |
|---|---|---|---|
| Finite positive least closure; strict evaluation | PositiveEquations, IncrementalClosure | closure.ss | Implemented; exact core/native controls and independent scalar oracles |
| Append/chunked/hybrid queues and topology selection | ClosurePolicy, QueueSelection, ClosureLifecycle | closure.ss | Implemented; same reference ceilings/threshold, explicit cold/fixed modes |
| Private syntax/index construction | ClosureConstruction | indexed/copy-only walkers | Implemented; fused index specification and declared layout saving |
| Delayed and idempotent preparation | ensureAdaptive | prepare-closure | Implemented; cached calls preserve object identity and do no new scan |
| Dependency-equal syntax reshaping | reshape / reconfigure | reconfigure-closure | Implemented; ordered occurrences, fresh solve, new size admission |
| Cooked snapshot and heterogeneous service family | CyclicPublication / StagedPublication | cyclic-publication.ss | Named procedures and checked typed generics; duplicate checks and exact old identity on refusal |
| Ten-fact cyclic access and lossy view | CyclicAccess | examples/cyclic-access.ss | Implemented and tested over 32 configurations; active is a list of indices |
| General prototype/class inheritance | C3 / GeneralizedInheritance | existing object.ss / mop.ss | Existing Scheme implementation reused; generalized hook equivalence needs separate coverage |
| Heterogeneous typed multi-dispatch and negative watches | Object.Multimethod / DispatchExtension / GenericFamily | multimethod.ss / dispatch-extension.ss / cyclic-publication.ss | Runtime input/output descriptors, sparse ordered lookup, guarded candidates, bounded immutable caches, completed-candidate watches and per-service cache transport; dependent proof evidence remains Lean-only; GenericFamily.Model drives declared construction and negative checks |
| Prepared effective methods and explicit nested cache owners | PreparedMultimethod; Multimethod.preparedStandard / preparedForwardingStandard / preparedSimple / preparedInner / preparedSimula; NestedMultimethod | multimethod.ss prepared-* / nested; method-combination.ss prepare-* | Implemented on the existing typed sparse dispatcher; one bounded resolution LRU, unconditional effective reuse, guarded reselection, joint invalidation and explicit multi-level child successor transport. Native owner checks definition AND invoker identity; performance remains horizon dependent |
| Declarative method/type/logical metadata | DeclarativeMetadata / ServiceMetadata | declarative-metadata.ss / examples/service-metadata.ss | Native POO declarations, Type refinements, composed finite logic, bound invocation wrappers and cooked contract rebuilding; dependent evidence remains Lean-only; native staged models re-admit actual cache successors |
| Selective generic construction and warm-cache retention | GenericFamily.Source / Projection / refresh; StagedPublication.stageRefresh | generic-family.ss / staged-publication.ss / cyclic-publication.ss | Implemented through native closed projections and atomic family refresh; changed source/inputs reconstruct and recheck negative watches; exact warm siblings retained; contract-family.ss now also retains projected contracts and late-bound wrappers |
| Prepared selection and controlled cost comparison | PreparationCosts.SelectionCache / SelectionCacheCosts / Observation / paired_delta | contract-family.ss SelectionCache. / methods.inputs<-cached-selection; t/metadata-paired-* | Immutable prepared choice with arity fallback, first-class function capture, setup/guard amortization and per-pair GC decomposition; fresh-process source-bound native controls |
| Costed preparation and invariant contract specialization | Contract.withMeaning / Contract.Checks.specialize_eq / SharedProjection.direct_source_eq / PreparationCosts / TemplateCosts | declarative-metadata.ss with-meaning; contract-family.ss PreparationCosts. / choose-source; examples/shared-contracts.ss budgeted-workflow-model | Direct/shared projection coherence, selector and initial validation costs, exact original contract semantics, 15-node shared settlement revision; finite native timing and allocation evidence only |
| Shared heterogeneous contract preparation | ContractFamily.SharedProjection / Cache / refresh_project / cached_source_project | contract-family.ss methods.inputs<-shared / examples/shared-contracts.ss | Source-bound common preparation, unchanged-context lookup retention, per-key descriptor/wrapper invalidation and existing cross-service joint approval reuse; matched changed-input regression retained |
| Projected contract construction and binding reuse | ContractFamily.Source / Family / bind / publish | contract-family.ss / staged-publication.ss / cyclic-publication.ss | Implemented; exact descriptor/wrapper retention, constructor/executor/support invalidation, fresh-state invocation and admission provenance; constructors run only on changed inputs/source |
| Safe recursive attestation and certified recursive memo | RecursiveCacheSemantics / CyclicAccess | no equivalent bounded request program in this addition | Open; Boolean seed is currently supplied explicitly |
| General lenses, lossy cross-type migration and incremental component invalidation | ProjectedSelf / CarrierMigration / ConstructionCache | generalized-graph.ss / construction-cache.ss / staged-publication.ss | Finite inspectable DAG rebuilding and source-bound invalidation implemented; arbitrary adapters and dependent evidence remain separate |

## Current construction API

`compile-closure`, `prepare-closure`, `reconfigure-closure`, `construct-closure`
are the costed closure operations. `closure-index-shared?` checks private reverse
index identity for two plans. `cyclic-publication.prepare` and `cyclic-publication.publish`
return two values: admitted version (or identical old version/#f) and failure/#f.
Failures retain the stage and original cause. `cyclic-publication.invoke` returns
two values: result and updated immutable version. A checked generic warms only
its own service entry; a named procedure returns the unchanged version. Input,
output or source exceptions return no tentative cache/version. The method index
and family hash table are private.

The default retained publication requires equal ordered read occurrences. Pass
`#f` for the final retain argument to request a fresh compile after topology
changes. Source/cook/service/admission callbacks must not mutate published values;
external side effects are outside atomic value publication.

The example reuses real POO `.o` objects and the existing object/type machinery.
It covers shared membership, two cycles, a quorum, release branch join, consent,
revocation and old-view/service retention. No user-visible flow relies on benchmark
metadata or internal counter structures.

## Fixed native benchmark files

`t/closure-cases.ss` is the case/column definition. Active tools use Scheme
`read`/`write` only; there is no new JSON record format or version series. The
matrix driver emits common metadata once and streams result vectors. Files are
read as data, never loaded as Scheme programs. Complete measurements and diagnostic stdout remain local ignored outputs.

```
GERBIL_PATH=<package-env> just benchmark-closure-phases
GERBIL_PATH=<package-env> just benchmark-closure-paired
GERBIL_PATH=<package-env> just benchmark-closure
GERBIL_PATH=<package-env> gxi t/closure-report.ss .build/closure/closure-benchmarks.scm
```

These commands require only this Scheme package and its declared toolchain.
Cross-project counter comparison is an optional tool in the Lean repository; it
accepts explicit executable and checkout arguments, with no fixed build layout.
Each measured child retains the 20s/1GiB limits. Initial allocation/probe/GC costs
are visible in native CPU, wall, GC CPU, collection and allocation measurements.
Minimum source ceilings remain distinct from fastest native execution.

The [standalone native matrix](performance/results.org) records 960
Scheme observations with source/executable identities. It requires no companion
repository. `gxi t/closure-parity.ss <study>` validates that Scheme-only matrix;
for current-source validation, call `read-study` with its second argument `#t`.
Historical dual-runtime observations retain their original driver at the recorded
commit. This separation changes benchmark orchestration, not closure semantics
or claim additional semantic coverage beyond the controls recorded there.

## Terminology and module naming

The package namespace remains `clan/poo`. Reuse the existing `object`, `mop`,
`type`, `proto` and `fun` modules for the responsibilities they already own.
A Lean proof module does not by itself justify another Scheme module or wrapper.
Group executable operations by their existing owner; a new module needs a
separate executable responsibility and an explicit correspondence here.

Use the paper's terms for the concepts it names: prototype, instance, generic
function, multi-method, multiple dispatch, method combination, lens, raw and
cooked representation. The paper's **Future Work** and Appendix B **Generalized
Prototype Combination** motivate generalized prototypes and MOP. The finite
positive cyclic publication construction below is a later Lean extension of that
future work; its module/type names are not names claimed to occur in the paper.

| Owner / meaning | Lean definition | Scheme spelling / qualification |
|---|---|---|
| Cyclic publication module | `LeanPoo.Functional.CyclicPublication` | `:clan/poo/cyclic-publication` |
| Published version | `CyclicPublication.Version` | `version`, public predicate `version?` |
| Initial construction | `CyclicPublication.prepare` | `cyclic-publication.prepare` |
| Revision | `CyclicPublication.publish`, `publishRetained` | `cyclic-publication.publish`: retain `#f` selects `publish`, `#t` (default) selects `publishRetained` |
| Named operation on a version | `CyclicPublication.Version.invoke` | `cyclic-publication.invoke`; result plus updated version, per-service checked cache transport |
| Access example module | `LeanPoo.Functional.CyclicAccess` | `:clan/poo/examples/cyclic-access` |
| Access configuration / equations / cooked view | `CyclicAccess.Config`, `equations`, `cook` | `access.config`, `access.equations`, `access.cook` |
| Access construction / revision | `CyclicAccess.start`, `revise` | `access.start`, `access.revise`; supplied Boolean seed, without recursive attestation/memo |
| Multiple dispatch implementation | `Object.Multimethod`, `Specializer`, `MethodIndex` | `multimethod.ss`, private `specializer` / `method-index` records; `prototype`, `any` specializers |
| Negative extension assumptions | `DispatchExtension.Watch`, `check`, `guard`, `Conflict` | `dispatch-extension.ss`: `shape` / `call` watches, `check`, `guard`, `conflict`; private runtime `certificate` is a checked receipt, not a Lean proof |

For these new runtime modules/records, CamelCase owner names become Scheme
kebab-case; operation names keep their meaning. Existing Scheme conventions
such as `Type`, `Class` and `.defgeneric` remain authoritative in their modules. Import qualification is local Scheme syntax, not an additional package
namespace. For example:

```scheme
(import (prefix-in :clan/poo/cyclic-publication cyclic-publication.)
        (prefix-in :clan/poo/examples/cyclic-access access.))
(defvalues (version failure) (access.start (access.config) #t))
(defvalues (active updated) (cyclic-publication.invoke version 'explain))
```

The runtime `version-view`, `version-facts` accessors and `failure-stage` /
`failure-cause` diagnostics expose the runtime publication state. They do not claim Lean's
dependent snapshot approvals or proof-bearing error evidence. Files, exports,
imports and the build graph migrate together; there are no old-name aliases.
New filenames and namespaces omit `Paper`; benchmark data keeps native Scheme
fixed filenames, with no versioned JSON additions. Naming correspondence does
not add a dependency on the Lean checkout.


## Typed multi-dispatch and protected extension

`multimethod.make inputs output precedence [combine [arity]]` reuses MOP `Type`
descriptors and `validate`. Inputs are a fixed row of Scheme arguments, output
is one Scheme value (a tuple/list descriptor can represent a composite result).
The dispatch arity is independent: the example has three inputs but two axes;
amount affects guards, not candidate cache keys. The default combination calls
the first applicable method; callers may supply an ordered combination.

`prototype` names are symbols; `any` is a distinct private specializer. The C4
adapter reuses `object.ss` linearization. Its name map must be stable and injective
on that graph. A complete ordered tuple of precedence lists keys the cache; the
key's list spines are privately copied. Prototype names, watches and edits do
not borrow caller-mutable spines. Candidate lookup visits sparse branches in
lexicographic precedence order, preserving same-path contribution order.

`register` replaces an exact tuple, `contribute` prepends an unconditional
contribution, `register-when` prepends a Boolean guard, and `erase` clears that
tuple. Every edit creates a new index path and clears only the new version's
cache. Eight immutable association entries implement the model's bounded LRU;
this differs from Lean's persistent hash representation. A most-recent hit reuses
the exact generic. Selection and type validation still run on warm calls.

`dispatch-extension.shape` forbids all candidates, including false guards;
`dispatch-extension.call` forbids applicable methods for its fixed typed
arguments. Checks never execute method bodies or combine. `check` raises the
first `conflict` (watch position, arity/method kind and first conflicting method)
or returns a private checked receipt. `guard` patches all edits before checking
the completed candidate. Registration failures take precedence over negative
checks. `publish` returns two values: accepted receipt or identical previous
receipt, and failure/#f. A temporary registration followed by erase can succeed.

`dispatch-extension.invoke` returns result plus updated receipt. Definition and
watch identity are preserved while warming a cache, so the negative checks are
not repeated. Construction admission is checked during prepare/publish; invocation
transports negative receipts, not arbitrary cache-dependent logical approvals. This transport requires pure guards/precedence/validators and
unchanged watched payloads, type descriptors and C4 graphs. Published nested
values and callback captures must remain immutable. Arbitrary external effects
or mutation are not rolled back or certified by this receipt.

The `protected-dispatch` example corresponds to Lean `Examples/ProtectedDispatch`:
a document diamond, channels, amounts, guarded risk methods, broad extension
refusal and independent library contributions. The family example publishes a
fee generic (`Object × Object × Nat → List Nat`) and an enabled generic
(`Unit → Bool`) with cyclic cooked state. It verifies per-service warming,
revocation, old snapshot usability and atomic negative-check refusal. Existing
procedure services remain ordinary procedures; typed generics are explicitly
checked entries, not inferred from a procedure table.

### Model evidence and standalone measurements

Lean `DispatchExtension.selectCounted_cached` proves counted selection parity and
one visit per candidate. `observedCounted_result` matches the independent ordered
reference; shape watches have zero selection visits, call watches visit the full
candidate list. `cacheComparisons_capacity` bounds association lookup to eight
shape comparisons, without making shape equality constant time. Existing
`publish_refused`, `guard_ok_iff`, `Certificate.afterCall` and `GenericFamily` laws
supply definition-bound transport and rollback. `Examples/ProtectedDispatch`
reuses `DeclarativeMetadata.Contract` to prove input refusal before execution
and output refusal without exposing a tentative cache. These are model theorems
and runtime premises, not a verified Scheme compiler/runtime refinement.

```
GERBIL_PATH=<package-env> just benchmark-dispatch
GERBIL_PATH=<package-env> gxi t/dispatch-report.ss .build/dispatch/dispatch-benchmarks.scm
```

The native driver owns the phase/dimension/repetition declaration. It records
264 rows: widths 0/64/256, natural/collected GC, four rotating rounds and eleven
phases (signature/index construction, cold/warm calls, check, accept, refuse,
cancel, alternating guarded values, family preparation, cold/warm family calls). Construction and checking are measured
separately from invocation. Type/C4 preparation for the reusable call fixtures
is outside the timed calls; construction includes each new signature and method
registration, not compiler startup. `guard-values` performs two calls per
repetition. Every phase checks its result; source/binary identities and common
metadata occur once. The reader rejects changed definitions/sources, duplicates,
invalid row shapes and incomplete matrices. Compilation stays bounded to 90s,
measurement to 20s/1GiB. No Lean checkout or JSON is needed.

Native CPU/GC/allocation values are measurements. Predicate, validator, method,
combination, C4/name lookup, structural equality and family hash-copy costs are
not erased by the model's candidate-visit/comparison bounds. No universal speedup
or total memory bound is claimed.


### Allocation-counter admission

The first 264-row dispatch control completed its semantic checks, but its reader
refused two negative allocation deltas. The unchanged signed data is retained in
[the rejected control](performance/results.org); it is not accepted
allocation evidence. On the installed Gambit `ea114fc` runtime, the allocation
counter was also observed to decrease across a direct GC. The existing
`closure-measure` formula follows Gambit's `##exec-stats` subtraction of the end
statistics object's space; changing a negative number to zero would hide the
invalid observation.

The dispatch driver therefore preserves the raw signed allocation delta and
marks allocation **unavailable** for every interval crossing GC or yielding a
negative delta. This rule applies to all such rows, including positive deltas;
it does not selectively retain favorable GC samples. The report prints an
allocation median only when all four rows in that group are admitted. CPU,
wall, GC CPU and collection counts retain their native observations. The
reader checks this admission rule and refuses forged numeric replacements.
Earlier GC-crossing closure allocation receipts remain historical observations,
not retroactively qualified allocation evidence. No runtime/compiler repair or
verification is inferred from this measurement guard.

The [current dispatch matrix](performance/results.org) uses the
explicit admission policy above. Neither rejected data nor missing allocation
values are used to claim a speedup or allocation saving.

## Declarative metadata expression protocol

See [DeclarativeMetadata](declarative-metadata.org) for native MOP protocols,
wrapper composition, the heterogeneous service example, rejection guarantees
and the standalone native metadata benchmark. Existing dispatch measurements
remain historical receipts at their pinned source identities.

## Complete native model composition

`GenericFamily.Model` and `StagedPublication.Model` now bind declaration
compilation, existing typed dispatch, completed-candidate absence checks,
contracts and exact-successor joint admission through native POO methods.
`publication.probe` returns the checked result only; it discards tentative caches.
The new [ServiceBundle example](../examples/service-bundle.ss) uses a real C4
diamond, dynamic guards and a cross-service cache budget. A successful method
can therefore be refused by joint admission without returning a new version.
Lower-level cyclic publication without the optional readmission procedure still
has construction-only admission. The selective settlement graph is now implemented through native construction hooks; kernel proof receipts remain separate.

[Benchmark output policy](performance/results.org): complete results and diagnostics stay in ignored `.build/` output; archives are not committed.
New complete matrices and binaries stay under ignored `.build/` output.
See [selective component construction](construction-cache.org) for the native
protocols, shared settlement graph, reuse guarantees and measured scope.

`SelectionCache` caches a preparation strategy by support size under immutable costs.
This is an implementation extension of the future work, not a term introduced
by the paper. The paper uses DAG for dependency/inheritance edges and C3
linearization; this cache contains no dependency edges.

| Shared closed generic reconstruction | `GenericFamily.SharedExpansion.shared_eq / patch_eq / negative_eq`; `PreparationCosts.ExpansionCosts` | `generic-family.Projection.` / `methods.instantiate<-shared-expansion`; shared-contracts expanded models | Opt-in pure immutable reconstruction, unchanged registration/watches, explicit extra guard and GC budget; no fresh-identity or mutation equivalence claim |

## Racket construction, Lean laws, native Scheme implementation

The correspondence is checked in three directions. The source reference is the
reviewed `poof.scrbl` from `fare/poof`, commit
`9affa8fbbb4f12cbd98cb97f8b8b84474fc39429`.
Reading the reference is development work; this package needs neither that
checkout nor Lean to build, run or benchmark.

| Reference construction | Lean owner / proof | Native operation / executable control |
|---|---|---|
| Appendix B, Method Combinations: primary/before/after/around order | `Object.MethodCombination.effective`, `MethodCombinationSemantics` | `method-combination.ss` native `Contribution.`; `multimethod.standard`; effect-order/next/warm-guard tests |
| Appendix B alternative combinations, sorted labelled fragments | `SimplePolicy`, `SimplePolicies`, `SimpleCombinationSemantics` | `multimethod.simple`; sum, collect, persistent append, all/any, optional last/max/min; suffix short-circuit and empty-result controls |
| Multiple dispatch and absent-method assumptions, immediately before Method Combinations | `Multimethod`, `DispatchExtension` | Same existing sparse C4 index, typed input/output, guarded carriers and complete-candidate negative watches; no second dispatcher |
| `$lens-gen` Racket definition: setter/getter/wrapper, cooked self and delayed raw super | `GeneralizedPrototype` / `ProjectedSelf` | Existing `object`/`mop` composition is reused. This addition does not claim arbitrary generalized lens/migration hooks are complete |
| Generalized Prototype Combination explicitly described as future work | `DeclarativeMetadata.Contract.withMeaning`, `Contract.Checks.specialize_eq` | `with-meaning` shares invariant checks under exact input/output/rule source stamps; derived source overrides force fresh checks; current meaning/executor/state never memoized |
| Preparation policy, a later cost-model extension | `SelectionCacheCosts.choose`, `selected_bound`, `workflow_bound` | `SelectionCacheCosts.` and `choose-source`, with setup, actual preparation misses, fallback, guard and extra-GC budgets |

The reference gives executable Racket prototype/lens definitions and describes
the qualified method combinations; it does not provide a complete Racket
qualified dispatcher that can be cited as a differential execution oracle.
Native tests therefore check its described order and reuse the existing sparse
index. Lean proves the abstract effect semantics and reservation equivalence;
it does not certify the Scheme compiler or arbitrary external side-effect rollback.

`Contribution.` is extensible native POO data, not a new tag interpreter in a
parallel dispatch engine. `standard` admits primary/before/after/around;
`simple` admits item/around. Primary/around bodies receive a zero-argument
`next` followed by the original argument row. Side/item bodies receive only
that row. The ordinary `make` carrier stays procedure-valued. Registration
validates the carrier without executing any body; shape watches inspect the
same qualified data. Guard results still must be Boolean on each invocation.
`append-policy` is persistent append, not destructive CLOS `nconc`.

The complex `examples/service-combination.ss` models combine these constructors
with shared expansion, specialized reserve/cancel checks, selection budgeting,
cross-service revision, current invoice binding and joint approval. Refusal
preserves the exact published version. Lean's `Examples/AlignedServices` proves
the corresponding standard/simple arithmetic and refusal laws using existing
combinators, plus complete conditional selector-budget bounds.

Remaining executable alignment gaps are explicit: precompiled unconditional
effective-method dispatch,
general safe-recursive attestation/memo programs (the cyclic seed is still a
supplied Boolean), and arbitrary cross-type lens/migration adapters. Native
finite DAG rebuilding does not close those broader capabilities. Dependent
proof evidence itself remains a Lean responsibility, not another Scheme wrapper.


## Forwarding, inner and Simula control

The original Appendix B admits user-defined combinations of sorted labelled
fragments and shows the Racket `$lens-gen` wrapper/cooked-self/delayed-super
construction. It does not specify these three complete dispatch APIs verbatim.
The following are executable counterparts of the existing Lean extensions of
that direction; the unified generalized protocol remains future work.

| Control | Lean owner | Native API / boundary |
|---|---|---|
| Fixed-dispatch payload forwarding | `ForwardMethod`, `callForwardChain`, `forwardEffective`, `Multimethod.forwardingStandard` | `ForwardContribution.`, `forward-primary/before/after/around`, `multimethod.forwarding-standard` |
| Superclass-controlled descendants | `innerChain`, `Multimethod.inner` | `method-combination.inner-chain`, `multimethod.inner` |
| Automatic inner prefix/suffix order | `SimulaBody`, `simulaEffective`, `Multimethod.simula` | `SimulaBody.`, `simula-body`, `multimethod.simula` (native Unit result) |
| Cold/shared check preparation | `TemplateCosts.choose`, `selected_bound`, `cold` | `TemplateCosts.`, `choose-checks`; `with-meaning` optional Boolean share argument |
| Hoisted fixed budget arithmetic | `SelectionCacheCosts.compiled_eq` | immutable weights validated/captured once; each `.choose` entry validates only selection-cost |

Forwarding accepts one typed dispatch value and one typed payload. An arity
parameter allows the dispatch value to carry several C4 axes. Before/after bodies
receive `(dispatch payload)`; primary/around receive `(next dispatch payload)`.
`next` takes one Option: `#f` retains payload, `(some payload)` replaces it,
including `(some #f)`. Replacement payloads are Type-validated before the suffix.
Neither continuation nor replacement can supply a different dispatch argument.
Candidate lookup and guards use the INITIAL typed pair once per call; guards are
not rerun after enrichment. Around changes reach the complete inner computation;
primary changes affect its remaining suffix, so after observes the inner entry
payload. Registration and negative inspection never invoke these bodies.

Inner reverses the selected C4 contribution sequence. A superclass omitting its
zero-argument inner thunk prevents descendants and the innermost default from
running. Simula runs general-first prefixes then specific-first suffixes. Any
exception stops all subsequent parts; suffixes are not guaranteed finalizers.
Native tests and Lean effect laws explicitly preserve executed effects on failure.
The enclosing atomic publisher separately retains its old admitted snapshot.

The new service models reuse closed generic projections, shared expansion,
declarative edits, Type predicates, protected candidates, checked contracts and
joint revision. Forwarding/preflight read invoice, so their reserve projection
now explicitly carries that dependency and reconstructs it. Invoice-only changes
rebuild reserve/cancel and retain quote; other combinations keep their smaller
original dependency support. Tests verify actual rebuild traces, current results,
negative cancellation refusal and exact old-version identity.

The reference models deliberately discard nested helper successors as a measured
control. `compiled-forwarding-model` / `compiled-simula-model` compile child
combinations but retain that control; `prepared-forwarding-model` /
`prepared-simula-model` additionally transport the child successor through
`multimethod.nested`, the existing certificate, family and admitted version.
`cached-*-model` isolates candidate-cache transport without child precompilation.
The child may itself own a child. Every successful invocation returns both cache
levels explicitly; failures return no tentative owner. No hidden body cache exists.

`prepared-*` reuse current typed arguments, not invocation results. A cached
resolution stores candidates and an effective method together in the existing
8-entry LRU. Any guard prohibits effective reuse for that shape; edits empty the
LRU. The open invoker descriptor specializes once to a compact private callback /
state record. A successor carries that record, without rebuilding a lazy POO
descriptor. Child definition and invoker callback identity must both remain equal
before negative-watch certificates may be transported. An invoker replacement
cannot disguise itself as a cache hit. The nested constructor is an explicit
stateful calling convention, not an implicit effectful standard qualifier.

Lean `call_correct`, `call_preserves`, fresh/edit invariant laws, the four prepared
combination equality laws, and nested success/failure laws cover these operations.
The native suite separately covers typed warm arguments, repeated next, prefix
failure, three nested owners, changed-definition/invoker refusal and invoice/joint
revision. Closed Lean request examples are executable checks; generic semantic
and cache invariants are proofs. Neither establishes Scheme compiler correctness.

For a single cold specialization, `with-meaning descriptor meaning #f` avoids
forcing shared checks and clears a retained record if necessary. Changed invariant
sources still force fresh checks. The single-use source factory selects the
existing ordinary clone constructor under `TemplateCosts.choose`; the sustained
workflow uses a separate descriptor horizon and can retain shared checks. It does not
interpret costs on every descriptor. Repeated-use callers can select sharing
explicitly. Budgets are illustrative operation weights, not embedded Lean output
or measured timings. Fresh/shared modes preserve current meaning and the ordinary
input/source/output/logic checks.

All new laws/examples are added to existing Lean owners
`Object.MultimethodCombination`, `Functional.ContractFamily` and
`Examples.AlignedServices`. The saved original-source inventory and its coverage
flags remain unchanged. There are no new audit/benchmark JSON files or changes.


`configured-source selector-calls check-uses` keeps selector and descriptor
horizons independent. Identity tests establish cold fresh source = selected-source,
steady source = shared-checks-source under the example weights; no extra runtime
source wrapper is introduced. A nonzero first policy fee still needs coverage;
known single-use clients can directly use the ordinary source. The historical control-horizon study is recorded in
performance/control-combination-summary.org. Current prepared/nested controls,
including regressions and A/A spread, are in performance/prepared-invocation-summary.org.
