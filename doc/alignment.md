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
| Cooked snapshot and heterogeneous service family | CyclicPublication / StagedPublication | cyclic-publication.ss | Implemented for callback families; duplicate checks and exact old identity on refusal |
| Ten-fact cyclic access and lossy view | CyclicAccess | examples/cyclic-access.ss | Implemented and tested over 32 configurations; active is a list of indices |
| General prototype/class inheritance | C3 / GeneralizedInheritance | existing object.ss / mop.ss | Existing Scheme implementation reused; generalized hook equivalence needs separate coverage |
| Arbitrary heterogeneous typed multi-dispatch and negative watches | GenericFamily / DeclarativeMetadata | current bundle only indexes named procedures | Open: this is not implemented by the callback table |
| Declarative type/logical metadata, proof-bearing generic caches | DeclarativeMetadata / StagedPublication | existing runtime Type descriptors cover a subset | Open: do not treat ordinary Scheme descriptors as those proofs/contracts |
| Safe recursive attestation and certified recursive memo | RecursiveCacheSemantics / CyclicAccess | no equivalent bounded request program in this addition | Open; Boolean seed is currently supplied explicitly |
| General lenses, lossy cross-type migration and incremental component invalidation | ProjectedSelf / CarrierMigration / ConstructionCache | cooked snapshots / exact old bundle retention here | Partial; arbitrary adapters and selective component rebuilds remain open |

## Current construction API

`compile-closure`, `prepare-closure`, `reconfigure-closure`, `construct-closure`
are the costed closure operations. `closure-index-shared?` checks private reverse
index identity for two plans. `cyclic-publication.prepare` and `cyclic-publication.publish`
return two values: admitted bundle (or identical old bundle/#f) and rejection/#f.
Rejections retain the stage and original cause. `cyclic-publication.invoke` applies a
named procedure, preserving its own argument shape; the method index is private.

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

The [standalone native matrix](performance/closure-standalone.scm) records 960
Scheme observations with source/executable identities. It requires no companion
repository. `gxi t/closure-parity.ss <study>` validates that Scheme-only matrix;
for current-source validation, call `read-study` with its second argument `#t`.
Historical dual-runtime observations retain their original driver at the recorded
commit. This separation changes benchmark orchestration, not closure semantics
or the open typed-dispatch implementation row above.

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
| Named operation on a version | `CyclicPublication.Version.invoke` | `cyclic-publication.invoke`; callback-only subset, without typed generic/cache approval transport |
| Access example module | `LeanPoo.Functional.CyclicAccess` | `:clan/poo/examples/cyclic-access` |
| Access configuration / equations / cooked view | `CyclicAccess.Config`, `equations`, `cook` | `access.config`, `access.equations`, `access.cook` |
| Access construction / revision | `CyclicAccess.start`, `revise` | `access.start`, `access.revise`; supplied Boolean seed, without recursive attestation/memo |
| Multiple dispatch vocabulary, pending implementation | `Object.Multimethod`, `Specializer`, `MethodIndex` | Use the corresponding `multimethod`, `specializer`, `method-index` terms when implementing those owners |
| Negative extension assumptions, pending implementation | `DispatchExtension.Watch`, `check`, `guard`, `Conflict` | Preserve these meanings; a checked runtime observation is not Lean's proof-bearing `Certificate` |

For these new runtime modules/records, CamelCase owner names become Scheme
kebab-case; operation names keep their meaning. Existing Scheme conventions
such as `Type`, `Class` and `.defgeneric` remain authoritative in their modules. Import qualification is local Scheme syntax, not an additional package
namespace. For example:

```scheme
(import (prefix-in :clan/poo/cyclic-publication cyclic-publication.)
        (prefix-in :clan/poo/examples/cyclic-access access.))
(defvalues (version failure) (access.start (access.config) #t))
(cyclic-publication.invoke version 'explain)
```

The runtime `version-view`, `version-facts` accessors and `failure-stage` /
`failure-cause` diagnostics expose this callback subset's state. They do not
claim the full Lean snapshot, typed family or error evidence. Files, exports,
imports and the build graph migrate together; there are no old-name aliases.
New filenames and namespaces omit `Paper`; benchmark data keeps native Scheme
fixed filenames, with no versioned JSON additions. Naming correspondence does
not add a dependency on the Lean checkout.
