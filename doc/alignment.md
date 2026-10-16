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
| General prototype/class inheritance | C3 / GeneralizedInheritance | existing object.ss / mop.ss | Native C3 reused by `generalized-prototype.prepare-inheritance`; prepared finite hooks covered below |
| Heterogeneous typed multi-dispatch and negative watches | Object.Multimethod / DispatchExtension / GenericFamily | multimethod.ss / dispatch-extension.ss / cyclic-publication.ss | Runtime input/output descriptors, sparse ordered lookup, guarded candidates, bounded immutable caches, completed-candidate watches and per-service cache transport; dependent proof evidence remains Lean-only; GenericFamily.Model drives declared construction and negative checks |
| Prepared effective methods and explicit nested cache owners | PreparedMultimethod; Multimethod.preparedStandard / preparedForwardingStandard / preparedSimple / preparedInner / preparedSimula; NestedMultimethod | multimethod.ss prepared-* / nested; method-combination.ss prepare-* | Implemented on the existing typed sparse dispatcher; one bounded resolution LRU, unconditional effective reuse, guarded reselection, joint invalidation and explicit multi-level child successor transport. Native owner checks definition AND invoker identity; performance remains horizon dependent |
| Declared unconditional shape preparation before joint admission | PreparedMultimethod.prepareShape / prepareShape_preserves / prepareShape_probes / NestedMultimethod.call_retains; ShapePreparationBudget | multimethod.prepare-shape / dispatch-extension.prepare-shape / child-prepared-simula-model / shape-prepared-simula-model | Body/guard-free construction after completed method edits; actual calls retain their Type/C4 checks. Negative certificates transport the unchanged definition. Declared entries consume cache budget; guarded shapes remain unchanged. Explicit per-model selection; no result memoization |
| Shared view-independent Simula definitions with current typed context | contextPreflight_equivalent / contextPreflightGeneric / ContextPreparationBudget | context-preflight / context-simula-model / context-prepared-simula-model | One immutable protected child definition is shared across views; current units/Object view are actual typed arguments. Outer projection/contracts still rebuild on capacity/invoice changes. First factory and added argument checks are explicitly charged; no cached view/result |
| Declarative method/type/logical metadata | DeclarativeMetadata / ServiceMetadata | declarative-metadata.ss / examples/service-metadata.ss | Native POO declarations, Type refinements, composed finite logic, bound invocation wrappers and cooked contract rebuilding; dependent evidence remains Lean-only; native staged models re-admit actual cache successors |
| Selective generic construction and warm-cache retention | GenericFamily.Source / Projection / refresh; StagedPublication.stageRefresh | generic-family.ss / staged-publication.ss / cyclic-publication.ss | Implemented through native closed projections and atomic family refresh; changed source/inputs reconstruct and recheck negative watches; exact warm siblings retained; contract-family.ss now also retains projected contracts and late-bound wrappers |
| Prepared selection and controlled cost comparison | PreparationCosts.SelectionCache / SelectionCacheCosts / Observation / paired_delta | contract-family.ss SelectionCache. / methods.inputs<-cached-selection; t/metadata-paired-* | Immutable prepared choice with arity fallback, first-class function capture, setup/guard amortization and per-pair GC decomposition; fresh-process source-bound native controls |
| Costed preparation and invariant contract specialization | Contract.withMeaning / Contract.Checks.specialize_eq / SharedProjection.direct_source_eq / PreparationCosts / TemplateCosts | declarative-metadata.ss with-meaning; contract-family.ss PreparationCosts. / choose-source; examples/shared-contracts.ss budgeted-workflow-model | Direct/shared projection coherence, selector and initial validation costs, exact original contract semantics, 15-node shared settlement revision; finite native timing and allocation evidence only |
| Shared heterogeneous contract preparation | ContractFamily.SharedProjection / Cache / refresh_project / cached_source_project | contract-family.ss methods.inputs<-shared / examples/shared-contracts.ss | Source-bound common preparation, unchanged-context lookup retention, per-key descriptor/wrapper invalidation and existing cross-service joint approval reuse; matched changed-input regression retained |
| Projected contract construction and binding reuse | ContractFamily.Source / Family / bind / publish | contract-family.ss / staged-publication.ss / cyclic-publication.ss | Implemented; exact descriptor/wrapper retention, constructor/executor/support invalidation, fresh-state invocation and admission provenance; constructors run only on changed inputs/source |
| Safe recursive requests, current admission and source-bound memo | Recursive / RecursiveCache / RecursiveHandling / RecursiveDispatch / CyclicAccess | recursive.ss / recursive-cache.ss / recursive-handling.ss / examples/recursive-catalog.ss / access.start-attested | Explicit requests, source errors, depth/budget separation, cycle paths, sealed program-owned memo, current native Type admission, retained-state FUN actions and atomic attested publication implemented; evaluation proofs remain Lean-only; purity/immutable keys/local callback termination are correspondence premises |
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
| Access construction / revision | `CyclicAccess.start`, `revise` | `access.start-attested`, `revise-attested`, `rebase-attested`; actual evaluated Boolean, owner-bound memo, least re-solve and atomic refusal |
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

The earlier effective-method and bounded recursive request/memo gaps are now
covered by the explicit native APIs below. General MOP interception hooks, arbitrary
cross-type lens/migration adapters and full dependent catalog/wire evidence remain
separate. Native finite DAG rebuilding does not close those broader capabilities. Dependent
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


## Simula construction before discarded admission probes

Joint approval's `probe` intentionally discards cache successors. Previously, a
changed reserve service could compile the same unconditional Simula combination
in that probe and again on its first real call. `prepare-shape` compiles a declared
shape after all method edits, through the SAME bounded resolver; it neither runs
a method/guard/precedence callback nor invents typed arguments. Real calls derive
and validate their own C4 rows. Unknown declarations cannot substitute for them.
Guarded or nonprepared generics remain exact unchanged owners. Edits still clear
the caches, and preparation on a frontmost hit returns the existing owner.

The POO projection's constructor chain captures its existing `.instantiate` and
then transports the prepared certificate. `child-prepared-simula-model` prepares
only the child; `shape-prepared-simula-model` prepares both child and reserve after
negative checking. The existing family/version/contract/admission chain is reused.
A prepared first real call can return the exact old version: bodies/contracts and
readmission still execute, with no new cache owner or private service-table copy.

Preparation allocates real entries. In particular, an initial zero-cache budget
may reject before any real user call; this is not claimed equivalent to admitting
an empty cache. Old versions are retained on refusal. Lean proves method-reference
semantics and cache invariants, not equivalence of every resource-admission result.
Its per-layer `ShapePreparationBudget` prices discarded misses, first entries,
all declaration/owner work, different constructor bases and supplied excess GC.
It never removes probe/body/check costs. Native isolated phases are measured
separately rather than added as an invented full-workflow decomposition.

Current native results and limitations: performance/simula-publication-summary.org.
The previous prepared-transport study is historical after this source change.


The cold-construction follow-up separates method CODE from current view DATA.
`context-preflight` constructs the same two Simula bodies once with a typed
`units, Object` input row and one C4 axis. The current view reaches the prefix /
suffix bodies as an argument. `context-simula-model` can either build this child
fresh or bind an explicitly supplied immutable prepared child. Its steady model
shares that child across revisions, while the existing closed reserve projection
still carries capacity/invoice context and constructs its current outer method.
Typed context validation and every prefix/suffix check still execute. No view,
result, or mutable method-cache cell is captured by the shared definition.

Native tests assert child snapshot identity across a cross-service revision,
then successfully use the new larger capacity and reject the old version's same
request. Revoked release, malformed invoice and invalid Object arguments refuse.
Lean universally proves equivalence with `simulaEffective (preflight view)`;
closed prepared-dispatch controls exercise current/revoked contexts. Its context
budget uses existing TemplateCosts, including first definition construction,
per-view outer binding, every added context argument/check/representation cost,
and supplied excess GC. A cold or call-heavy horizon can keep the ordinary mode.

The cold native control explicitly constructs the shared child AND its model
binding on first use. Steady stage/revision controls reuse that immutable source.
All processes initialize/warm the same control set before timing; process startup
is outside these phase timings. First factory cost is not hidden as a free cache.

### Compiled callback chains and staged Simula lifecycle

This advances generalized-protocol future work. Native `compile-simula` folds
specific-first suffixes and general-first prefixes into one argument-row chain,
extracting callbacks during preparation. Lean `compileParts_correct` and
`compileSimula_correct` prove the transformation for arbitrary lists and lawful
monadic effects; no continuation is executed at construction. Three-level native
traces, repeated current arguments and prefix refusal compare against the original
`simula-effective`. Current Object/units validation and negative watches remain.

`context-simula-template` fuses cold seed/declaration/projection installation into
one generic extension. `compiled-context-simula-model` supports either fresh fused
construction or explicit immutable-template reuse; the latter preserves projection,
contract and admission callback identity while installing the actual supplied child.
Tests exercise separate child identities, capacity/invoice revisions and old refusal.

Pure compiled context did not reliably remove full cold/hot regression. The staged
`simula-workflow-model` instead uses a native Model `.prepare` override to construct
the existing captured-view program initially, then inherits checked publication to
the compiled shared child. Warm calls run the ordinary published-version protocol,
with no selector. The FIRST owner handoff rebuilds/rechecks the entire generic family
even for equal contexts; it does not retag old certificates. Later unchanged contexts
reuse the new owner. A test specifically enforces full handoff then exact reuse,
shared children across later invoice/capacity changes, and atomic negative refusal.
Lean `stagedPreflight_equivalent` / `stagedPreflight_stream` compare every current
request computation across phases, including failure traces. These are not proofs
of identical resource-admission timing or rollback of external effects.

`SimulaFactoryBudget` prices callback/wrapper setup, each child/binding, all calls
and excess GC. `ContextPreparationBudget.staged_bound` additionally requires later
saving to cover the workflow wrapper; its setup must include full owner handoff.
Common captured-view initial work remains explicit base. Module initialization is
outside native phase timings, and must be charged in whole-process reasoning.
Results, A/A drift, unsuccessful pure-context trials and reproducible native command:
performance/simula-factory-summary.org. No dependency on a Lean checkout.

### Capacity-sized family storage and bound Simula context

This advances generalized-protocol future work. Racket's effective-method split
and explicit nonmemoization of results allow immutable current-view binding at
reconstruction. `bind-simula` uses standard folds to compile two-argument callbacks
at a fixed view into unary argument-row callbacks. `bound-preflight` validates the
Object at binding and validates current units and Unit output through the existing
sparse generic at every call. Bodies still check current bound capacity, invoice
and release; Forbidden shape watches are installed/checked normally. It uses the
same immutable declaration source; global declaration setup is not a free operation
in whole-horizon costs. Separate reconstructed views receive separate bound children.
No prepared cache successor or result can substitute for current Type/body checks.

The generic-family protocol already rejects nonsymbol keys. Its opt-in
`methods.refresh<-sized-projection` uses the existing native eq backend with
`make-hash-table-eq size: (length keys)` for private new tables. This changes
representation only. New-owner handoff STILL reconstructs and checks every key;
matching old-owner contexts still follow existing reuse rules. No private receipt
is retagged. Standard runtime hash.ss/table.ss supply the constructor, hashing and
capacity management; no custom hash library or runtime modification was added.
Duplicate support is an upper bound for capacity, not an authorization to omit keys.

`bound-simula-model` composes this storage mixin with the existing FUN/IO staged
Model and typed contract/negative/admission chain. `sized-simula-model` isolates
the table change. Native tests include 25 keys, duplicate/empty/invalid support,
new-owner negative refusal retaining old entries, three-level repeated effect
traces, current/revoked/malformed views and independently revised capacity/invoice.

Lean `compileParts_contramap` and `bindSimula_correct` prove the fused binding for
arbitrary lawful effects. `boundPreflight_equivalent` / `boundPreflight_revoked`
retain current-view failure traces. The certified-family capacity companion proves
preallocated empty tables still contain no entries; capacity supplies no owner
or method certificate. `SimulaBindingBudget` charges every reconstructed binding,
setup, current call and excess GC. Its coverage/selection/table inequalities use
supplied primitive prices; they do not prove native hashing, compiler correctness,
GC behavior or universal acceleration. Few calls per revision can favor shared code.

Native paired controls now measure POST-handoff warm calls separately, first versus
subsequent revision allocations, and unchanged-owner reuse. See
performance/simula-owner-summary.org for current results and limitations.

The final binding path shares an entire `prepared-context` program.
`compile-simula-context` prepares code taking explicit context state once;
`bind-context` validates the new context and copies only private context/invocation
and generic owners. Method index, invoker callbacks and candidate/effective cache
are retained exactly. Applicability/precedence/guards depend on typed Args;
context-sensitive dispatch must remain in Args. A context value is invocation data,
not permission to freeze a guard or retain a successful result. The child template's
negative shape check remains valid because rebinding does not edit that program.

Native `invoke-nested` additionally rejects a changed private context owner: a
method cannot return a rebound view through the cache-only successor channel.
New views must pass ordinary reconstruction and joint publication. Tests cover
same-context identity, guarded current arguments, typed rebind refusal and attempted
nested context replacement. Lean `PreparedContextMultimethod` uses the same prepared
program with typed context data; its call/reference, bind/program/cache and context
retention laws complement `NestedMultimethod.callChecked_context_change`.

The final table path follows the standard Gerbil expander usage: native eq tables
with an explicit capacity hint. The two symbolic-backend trials (random/default
seed and then seed 0 with shared code) increased allocation; both remain adverse
results in simula-owner-summary.org. Their price inequality does NOT justify
selecting that backend. No hash/runtime implementation was changed.

The owner-handoff follow-up stages ALL freshly constructed/negative-checked cells
before choosing service-table storage. Comparable nonempty supports can use a
private copy of previous storage; old-only keys are pruned and every current cell
is overwritten before any new family escapes. Contraction/expansion uses a fresh
sized table. Constructor execution and built traces retain declaration order;
private insertion order is not a public family order. A failed first handoff drops
the pending cells without mutating the previous table. No old receipt authorizes
a current key. Tests also swap one key in a 25-key support (same cardinality),
contract to one/zero keys, and reject a late first-handoff negative extension.

Lean `overwriteStorage_current` and `rebuiltLookup_reference` establish independence
from arbitrary prior storage for the freshly rebuilt domain; pruning makes foreign
keys absent. `rebuiltLookup_certified` transports only certificates of the fresh
reference construction. The typed heterogeneous table signatures are preserved.
Pending cells, copying, support checks and pruning are real work in the supplied
table price; a capacity or copied table is never an applicability certificate.

### Standard empty storage and ordered checked reconstruction

`methods.refresh<-empty-storage` composes the existing projection/refresh chain
with `HashTable.new`, Gerbil's ordinary same-kind empty-table interface. One private
empty eq descriptor supplies fresh context/service storage using positional size;
no custom runtime constructor or hash backend is introduced. It avoids copied old
entries, pending cells and pruning. All ordered constructors, negative watches and
joint approval remain active; later same-owner services retain ordinary COW.

Lean `Partial.rebuild` executes the existing certified key builder. Its
`build_lookup_eq`, `rebuild_lookup_eq` and `rebuild_empty_reference` preserve the
first exact typed failure and arbitrary-list successful observations, including
duplicate keys. `EmptyStorageCosts.covered` charges interface setup and excess GC
against removed construction dispatch/staging/pruning, with binding and approval
explicitly common. This advances concrete generalized-protocol future work; it
does not close the remaining safe-recursion, general MOP hook or migration TODOs.

## Explicit recursive requests and owned memo

The Racket fix--1 construction delays final-self calls while retaining the shared
instance; its memo sketch is in a commented experimental stanza (poof.scrbl
1906–1940), not an automatic effect/result cache required by the paper. The bounded
Interaction evaluator, source proofs and cycle reasoning are Lean extensions of
that construction. This work advances generalized-protocol future work.

`recursive.Interaction.` and `recursive-handling.RequestAction.` compose through
native FUN .ap/.bind/.map; `recursive.close` reuses proto composition. The closed
request nodes distinguish source value/error from pending observations and machine
diagnostics. Source solve depth and memo machine depth are DIFFERENT budgets.
`recursive-cache.run` checks exact descriptor owner, stores only completed sealed
receipts, copies its private standard table once per writing run, and returns the
exact old memo on cycle/exhaustion. Completed source errors are valid cached work.

`call-slot` resolves current POO signature metadata and native Types before memo
lookup; output admission runs again even on a one-step hit. Input/schema/signature
refusal never enters memo. Completed errors/output refusals retain completed memo;
FUN batch/actions stop with that actual state. `result-reused` describes direct root
lookup, not the existence of shared nested hits; composed actions may report unknown.
`examples/recursive-catalog` composes prototype override, shared nested requests and
typed multi-dispatch. Native Type catalogs cover these concrete immutable values;
full Lean Dynamic catalog factories, wire codecs and dependent evidence are not
claimed to have been ported by this module.

`start-attested` seeds the original positive equations from an actual Boolean
evaluation receipt. `revise-attested` reuses only the same program memo and re-solves
least closure; `rebase-attested` explicitly starts a fresh program memo. Any recursive,
source or publication refusal returns the exact old public wrapper/memo. A completed
false removes release. `invoke-attested` threads existing service-cache successors.

Lean reuses RecursiveCacheSemantics, RecursiveHandling and CyclicAccess proofs.
New `runCertified_hit`/`zero` expose exact warm work/budget behavior;
`RecursiveSession.call_warm_current` keeps current registry admission on warm calls.
`RecursiveMemoCosts.covered` charges identical boundary checks and supplied setup/GC
costs; raw memo savings cannot justify skipping admission. Program/keys/results must
be immutable, callbacks pure and locally terminating, and equality extensional.
Native node tagging/provenance is not a kernel evaluation proof. A depth budget is
not a total work/memory quota or termination guarantee for arbitrary Scheme callbacks.
See performance/recursive-summary.org for native controls and explicit scope.


## Generalized prototype hooks (future-work extension)

This advances the generalized-prototype future work explicitly identified in
Racket `poof.scrbl` 2098–2134 (reference commit
`9affa8fbbb4f12cbd98cb97f8b8b84474fc39429`). It does not mark the whole paper or
an unrestricted reflective MOP complete.

| Racket / Lean construction | Native Gerbil counterpart |
| --- | --- |
| `$lens-gen`; `Generalized.lensCompiler` | `generalized-prototype.lens-compiler`: setter/getter/wrapper, delayed inherited focus |
| raw/cooked boundary; `Generalized.Protocol` | `Protocol.` with `cook` and `compile` |
| `sumCompiler`, `reindexSelf` | `sum-compiler`, `reindex-self`; compatible-view law remains a caller premise |
| `GeneralizedInheritance.prepare` and ordered fragments | `prepare-inheritance` reuses `object.ss` checked C4/C3, then captures local declarations |
| `assemble`, `step`, `approximate`, `observe` | same finite semantics; `prepare` hoists compilation once |
| `PreparedHooks.step_eq`, `iterate_eq` | correspondence target for immutable native compiled snapshots |
| `HookCosts.shared_le_repeated` | supplied additive work bound for positive observation counts, independent of timings |

`examples/generalized-checkout.ss` composes a shared-ancestor diamond, price and
rebate lenses, existing prepared sum effective methods, cooked-self dependency,
an unchanged audit frame, and native FUN observation bind/map. The matching Lean
triangular example checks finite depths one/two and the audit frame; it abstracts
the concrete Scheme descriptor representation and does not prove a compiler.

Preparation runs compilation callbacks, but not method bodies. Observations run
callbacks with delayed self and parent, without implicit thunk memoization. A
wrapper can ignore its raw suffix. Host exceptions propagate and stop FUN bind;
there is no rollback of arbitrary callback effects. Public descriptors, fragment
lists, graph and captured callbacks must remain immutable after preparation.
Mutation requires fresh preparation; no automatic mutation tracking is claimed.
A custom compiler can inspect/replace raw state; lens frame laws apply only to
compilers satisfying their stated frame premise.

Remaining gaps include general hook-law checking, arbitrary lawful storage and
cross-type migration adapters, reflective metalevel bootstrapping and automatic
fixed-point closure for arbitrary callbacks. Finite depth never certifies closure
or callback termination. Scheme neither imports Lean nor serializes proof claims.
See `doc/performance/generalized-hooks-summary.org` for bounded native evidence.


### Demand cooking, nested functional lenses and observation binding

`mop.Lens.compose` now correctly calls the outer `.get`. `lens-of-get-set` maps
to `MonoLens.ofGetSet`; `focus-compiler` adapts the existing native Lens to
`Generalized.lensCompiler`. Composition order is outer carrier, inner focus in
both implementations. The nested service example preserves both audit frames
while composing C3 fragments and existing effective-method sums.

`cook-fields` uses standard Scheme promises per selected field. Per-stage shared
cooked self matches the pure `Protocol.stepShared_eq` equation. `bind-observer`
returns a native FUN reader action; `PreparedHooks.bindObserver_eq` covers every
seed and depth, without caching answers. Replacing eager cooking is governed by
`Protocol.observe_withCook`'s extensional interface premise. Arbitrary callback
effects/exception timing are outside that total law; unused field errors remain
delayed by the native demanded semantics.

The test-only prior-algorithm control, untimed operation-count instrumentation,
eleven-scenario native study (three complete 528-child runs; initial 480-child study separate) and adverse A/A/GC results are described in
`doc/performance/generalized-hooks-summary.org`. `ObservationWork.cost_mono`
requires supplied binding/cook/field/hook prices/count bounds; it does not infer
allocator or GC prices from those measurements. This advances the generalized
MOP future work, without claiming completion of the entire TODO list.


### Focused local assembly (generalized-protocol future work)

| Lean / Racket construction | Native Gerbil counterpart |
| --- | --- |
| Appendix B nested lens + local raw/cooked computation | `focus-protocol`, `prepare-focused` |
| `FocusLaws`, `focusDelayed_compose`, `focusDelayed_assemble` | explicit pure extensional lens domain; no automatic native law checker |
| `focusDelayed_lensGen` | existing composed Lens / method constructor interoperability |
| `Protocol.prepareFocused_observe` | same ordered fragments/base/seed with one outer write per nonempty stage |
| `focusedWrites_le` | logical write budget, independent of native allocation/GC |

Nested POO `.cc` objects differ in physical identity/ancestry. The Lean carrier
models immutable selector observations; no identity or introspective MOP
equivalence is claimed. Use the general path for callbacks outside this domain.
The billing envelope composes two surrounding lenses, approval/tenant revision,
C3 shared ancestors, sum methods and FUN observations. Empty assembly bypasses
the lens; refused approval uses the current configuration and retains old bindings.

The three fixed 576-child native studies compare CURRENT fused/unfused paths,
with fixed history perturbation, isolated construction/hook/cooking/binding and
GC-free allocation controls. Their concise source-bound evidence is in
`doc/performance/focused-assembly-summary.org`; old 73.313us data remain historical.
This closes local assembly/write fusion, not arbitrary projection elimination,
reflection, automatic law discovery or native compiler verification.


Approval in the new envelope uses a demanded Boolean check: 0/string truthiness
is refused in both paths, matching the typed Bool domain. Final-source native
proof/control receipts are separate from the initial bce6656 measurements.
