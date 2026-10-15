# Lean / Scheme implementation alignment

This map concerns the generalized-protocol future work used by the current
closure workflow. A Lean proof/type is not mechanically reproduced as an extra
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
| Declarative method/type/logical metadata | DeclarativeMetadata / ServiceMetadata | declarative-metadata.ss / examples/service-metadata.ss | Native POO declarations, Type refinements, composed finite logic, bound invocation wrappers and cooked contract rebuilding; dependent evidence remains Lean-only; native staged models re-admit actual cache successors |
| Safe recursive attestation and certified recursive memo | RecursiveCacheSemantics / CyclicAccess | no equivalent bounded request program in this addition | Open; Boolean seed is currently supplied explicitly |
| General lenses, lossy cross-type migration and incremental component invalidation | ProjectedSelf / CarrierMigration / ConstructionCache | cooked snapshots / exact old bundle retention here | Partial; arbitrary adapters and selective component rebuilds remain open |

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
read as data, never loaded as Scheme programs. Historical v1-v4 JSON controls
remain preserved for reference at their original commits.

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

The [standalone native matrix](performance/history.org) records 960
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
[the rejected control](performance/history.org); it is not accepted
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

The [current dispatch matrix](performance/history.org) uses the
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
has construction-only admission. The selective fifteen-node graph and kernel
proof receipts remain separate boundaries.

The extended native study is `doc/performance/composition-benchmarks.scm`. Older
studies retain their historical source hashes and must not be read as current
measurements after the model changes.
