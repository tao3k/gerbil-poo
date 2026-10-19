# TODOs for POO

In the future, we may add the following features and optimizations.

## Current implementation boundary

This design TODO is not a declaration that the whole paper or every Lean model
has been implemented. `alignment.md` maps executable native counterparts separately
from proofs. Multiple inheritance and the listed method combinations are available,
but the unified extensible MOP remains future work. Bounded explicit recursive requests and program-owned memo now have native
implementations, current Type admission and attested cyclic publication. Their
purity/immutability/local termination premises and Lean-only evaluation proofs
are explicit in alignment.md; a literal seed API alone is not the attestation path. Checked inherited C3/slot hooks and registered-source invalidation now have native
controls. Unrestricted inheritance-hook equivalence, arbitrary lens
adapters and cross-type migration also need further native coverage. Finite DAG,
metadata, invalidation and joint-publication examples do not close these general
items. Storage/binding performance progress below does not change their status.

## Functional completion audit (2026-10-17)

**No: this TODO is not fully implemented.** Performance studies below establish
neither feature completion nor native implementation of every Lean abstraction.
The following ledger takes priority over the historical optimization notes.
“Implemented” means the concrete API in the stated scope; “partial” and “open”
remain work to do. Proposed language/library projects are not silently removed
from scope or marked complete by a small example. Feature closure comes before
further tuning of the corresponding workflow.

| Original TODO | Implementation status and evidence | Remaining acceptance boundary |
| --- | --- | --- |
| Explicit instantiation assertions / side effects | Implemented explicitly: `mop.ss` `instantiate`, `make-instance`, `.new/checked`; `class-validation.ss` recursively wraps effective Slot fields before and after hooks; `t/lifecycle-test.ss`, `t/class-validation-test.ss` | Existing `.new`/`instance` stay lazy. Custom validators and callback effects remain caller obligations; no effect rollback or automatic recursion into nested construction hooks. |
| Automatic lens path syntax | Implemented: `mop.ss` `.lens`, `slots-lens`; persistent nested update and empty-path tests | General lawful/dependent representation adapters and cross-type migration remain partial. |
| Undefined method handling / lazy delegation | Implemented: `object.ss` `no-applicable-method`, `fallback-to`; receiver-local first-miss tests, cached false and refusal/recovery | Delegate changes need fresh receivers; this is not automatic discovery or mutable delegate invalidation. |
| Circular slot diagnostics | Implemented for repeated receiver/slot computation: `CyclicSlot`, `compute-slot-value`; slot/delegate/hook cycle and retry tests | Not a termination checker for arbitrary callbacks or chains of fresh receivers. |
| Multiple inheritance and method combination | Implemented concrete C3, standard/simple/forwarding/inner/Simula APIs, `MethodDeclaration.` record/method stream, certified typed declaration groups and `.defgeneric` `combination:` invocation with retained cache successors. `generalized-declaration.ss` now supplies extensible lens/wrapper/method descriptors and `.prototype` for arbitrary explicit raw/cooked carriers. | The generic lens-based fragment protocol/macro is implemented and tested on nested vectors and procedures. Automatic law discovery, unrestricted recursive closure, compile-time specialization and arbitrary inferred multi-dispatch syntax remain future work; explicit certified typed declarations now use the same method form, inheritance and generic invocation protocol. Generic optional/keyword/rest formals are now admitted by the existing Gerbil forwarding path and tested with from:type, defaults and method combinations; see parameters.md. |
| General inheritance MOP | Concrete interception implemented: `inheritance-hooks.ss`, ordinary inherited protocol objects, `compute-precedence-list` and `compute-slot`; `t/inheritance-hooks-test.ss`. `meta-prototype.ss` now closes finite positive recursive metalevel equations before cooking/bootstrap. | Accepted precedence retains checked C3; custom slot transformations need their own semantic laws. Constant-base self-hosting and finite Boolean least closure are implemented; arbitrary alternative orders, negative/nonmonotone recursion and unrestricted recursive meta fixed points remain open. |
| User-selected storage and focused computation | Explicit lens/wrapper protocol accepts non-record raw/cooked storage. `lens-laws.ss` adds finite get-put/put-get/put-put counterexample checks, paired with universal custom/composed lens laws in Lean. `generalized-closure.ss` adds bounded actual-raw stabilization; `t/generalized-closure-test.ss`. | Arbitrary custom adapters still require laws; finite samples are not universal certificates. General callback termination, automatic storage/layout/law discovery and primitive proxies remain open. |
| Record/class reflection | Concrete declaration protocol implemented: `reflection.ss` reuses Slot / Class, effective metadata, public read/write admission, `make-declared-instance`; metadata edits recompile declarations | Trusted raw `.ref` and generated struct setters can bypass this API. Nonlocal expansion/finalization and public/private catalogs are implemented in `declaration.ss`; global capability security and arbitrary lexical/compiler macro effects remain open. |
| Conditional/computed slot names | Implemented concrete protocol: `.declare`, computed `declaration-form` / splicing, inherited Reader/FUN expansion/finalization, multiple-slot contributions and visibility catalogs; `t/meta-prototype-test.ss`. `recursive-declaration.ss` adds named forward/shared requests with owned memo and whole-object finalization; `t/recursive-declaration-test.ss`. | Form specifications are captured sources; fresh membership needs fresh elaboration. Positive metadata cycles use least closure; repeated active expansion requests refuse. Unrestricted lexical rewrites, arbitrary callback termination and I/O rollback remain outside this protocol. |
| Object keyword syntax / lexical slot bindings | Implemented: `.o` leading self/super/inherit/bind/bind-these options lower through the existing slot engine; legacy forms and match patterns retained; `t/parameters-test.ss` | Declared lexical grammar closed. Arbitrary lexical rewrites are not part of this grammar. See [parameters.md](parameters.md). |
| Prototype mutability discipline | Explicit invalidating protocol implemented: registered weak reverse edges, once-per-owner clearing across diamonds, topology preflight, active-evaluation rejection and optional sealing; original parent-mutation tests retained | Sequential supported APIs only; external callback dependencies must be registered. Raw struct setters are internal escape hatches. Sealing locks direct source/instance edits, not all unsealed ancestors. |
| Data representation / usual object optimizations | Implemented protocol: persistent ordered prototype maps, shared symbolic shapes, opt-in receiver-local vectors and guarded inline sites integrated into object reads/writes and descendant invalidation | Concrete protocol closed; full hash removal, small-map specialization, Patricia layouts and automatic JIT/PIC policy remain optimization work. See [representation.md](representation.md). Historical speed measurements do not close these. |
| Positional parameter specialization | Implemented: `parameters.ss` validates `.parameters` and performs persistent prefix binding with `.cc`; partial/full closure, malformed/excess refusal and checked FUN consumption tested | Explicit positional API closed with 13 Lean semantic laws. Specialization does not implicitly run hooks/effects or perform type inference. See [parameters.md](parameters.md). |
| Type system for POO | Executable Type descriptors, structural contracts and guarded publication; Function optional/keyword/rest and ordered CaseFunction signatures implemented | Finite rank-one Self/Super schemes, explicit subtype bounds, structural Function variance and finite-candidate inference implemented in `type-relation.ss` / `prototype-types.ss`. Controlled guarded Mu approximants, open/closed Object rows, disjoint row substitution and finite row inference are implemented; see [row-types.md](row-types.md). Higher ranks, arbitrary predicates/unrestricted recursive/row/effect inference remain open; recognition alone does not prove host arity. See [prototype-types.md](prototype-types.md). |
| Generic data structure library | Shared finite collection-validation protocol closed: methods.table / RationalDict / Trie / derived sets / Map retain recursively normalized keys and values, Function wrappers, carrier admission and refusal/retry; t/table-validation-test.ss | A general collection library with the proposed protocol and laws is open. |
| Type-driven property-based testing | Implemented finite protocol: descriptor samplers, products, seeded replay, strict-domain bounded shrinking and stale-source refusal | Derived scalar leaves, guarded recursive List/Tuple/Pair/Union/Maybe/OrFalse graphs and Function call rows; explicit generators for other/refined Types and Function values. Automatic guarded recursive generators are implemented; unrestricted recursive carriers and universal verification remain open. See [recursive-generators.md](recursive-generators.md). See [generated-testing.md](generated-testing.md). |
| Jsonnet/Nix implementation | Open, separate interpreter-scale future work | No interpreter or equivalence claim is supplied by current object examples. |

### Gerbil standard mechanism audit

The contract interoperability pass delegates ordinary predicate/list/range checks
to Gerbil core `using` and its contract rules, preserving POO-specific recursive
normalization and refusal policy in the existing support module, without a
separate contract module or namespace. The integrated typed
host consumer composes `refine` with exact `bind-evidence`. The broader mechanism
reuse ledger covers inheritance, interfaces, collections, caches, concurrency,
syntax, IO and testing; see [gerbil-mechanisms.md](gerbil-mechanisms.md).
The prepared method-chain follow-up proves a whole `std/func compose1`
continuation assembly candidate equivalent, but rejects default adoption after
paired construction/GC regressions. Live reflection retains current Slot
admission across shared source revisions. The mechanism ledger records why direct host class reflection
is not an equivalent replacement, the new FUN workflow and bounded paired study.
The brace frontend now uses core `defalias` to the existing match-aware `.o`
binding, removing both duplicate forwarding transformers. Constructor, nested
pattern, renamed-import, host-method escape and live metadata refusal/retry
controls cover the complete combined-method/FUN workflow; see the same ledger.
The complete declaration driver now delegates ordered expansion to standard
`map-in-order` and delayed flattening to `foldr append`, retaining FUN finalization,
captured forms, refusal/retry and current reflection. Whole-batch inherited method
examples and effectful traversal laws cover this replacement in the same ledger.
The prefixed binding follow-up lowers entire lexical/snapshot groups through core
binding and definition forms, retaining nested aliases, current reads and ordered
snapshots. The same ledger records the whole FUN/reflection/combination workflow,
regressions and ten binding/sequence laws, plus a rejected mutable-spine fold substitution.
The generic forwarding follow-up delegates complete formal projection and keyword
splitting to core signature/dispatch mechanisms at expansion time. Core contract
binders now compose with current reflection, FUN and method policies; the ledger
records complete-projection refusal, runtime controls and eight forwarding laws.
The prototype-list follow-up delegates complete long-suffix reduction to standard
`reduce-right`, retaining small-chain identities and captured-head/current-suffix
behavior. Its Reader/method workflow, finite-list laws and refusal controls are
recorded in the same ledger; unrestricted fixed-point termination stays open.
This audit does not mark the open type/library/interpreter projects complete.

### Consolidated acceptance, not scenario accumulation

**The original TODO is still incomplete.** New graph topologies or timing reports
must not be used to mark an original feature complete. Each feature needs one
public composable protocol, refusal/retry behavior, an integrated example, native
regressions and corresponding Lean laws with explicit premises. The original
specifications below are retained; interpreter/library projects remain open.

The recursive publication lifecycle now has one integrated acceptance chain:
checked recursive closure → selective revision/SCC regrouping → complete source
and approval guards → named incarnation fences → scoped submission/exit → explicit
same-name recovery → current `refine` / exact `bind-evidence`. It is implemented
by `recursive-validation`, `recursive-staging`, `recursive-publication`,
`recursive-approvals` and `recursive-coordination`, not a separate engine per
scenario. `examples/recursive-coordination.ss` covers two names repeatedly failing,
recovering and exiting while a survivor remains live. Twelve Lean incarnation
laws and 1112 checked attempts exercise the complete declared boundary; unchanged
head/approval controls prevent lifecycle bugs being hidden by unrelated drift.
See [recursive-coordination.md](recursive-coordination.md).

The syntax/specialization workstream is now CLOSED for its declared acceptance:
keyword grammar, independently selected lexical imports, current-slot inherited
aliases, positional prefix closure and existing generic optional/keyword/rest
forwarding. One C3/FUN checked service chain and eight acceptance cases accompany
thirteen Lean semantic laws. See [parameters.md](parameters.md). The remaining
original feature backlog is explicitly grouped as follows:

| Workstream | Concrete remaining acceptance target | Current anchor |
| --- | --- | --- |
| Representation optimization | Qualify small-map/full-vector/JIT policies after the integrated persistent mapping, guarded shape/index and supported-invalidation protocol | Protocol: `prototype-map.ss` / `slot-layout.ss` / `object.ss`; [representation.md](representation.md) |
| Types and generated tests | Closed: optional/keyword/rest/case-lambda Function signatures; finite descriptor generators, bounded shrinking and replay. Closed: automatic guarded recursive container graphs, bounded generation/membership/shrinking and source-bound replay. Closed within the explicit finite algebra: rank-one prototype polymorphism, structural subtyping and budgeted complete candidate inference. Closed within bounds: guarded Mu expansion via safe recursion, observational Object field replacement and finite disjoint row inference. Open: unrestricted/higher-rank/recursive/row/effect inference and unrestricted recursive carrier generation; see [prototype-types.md](prototype-types.md) | Type-system/Property-based testing below; `type.ss` / `object-contract.ss` |
| Collection protocol | Proposed generic incremental/isomorphism-aware collection library and its laws, beyond existing containers | Generic Data Structure Library below |
| General MOP extension | Alternative-order certification and lawful custom adapters; general fragment/generic syntax beyond concrete bridges. Unrestricted recursion/termination is not certified by finite closure | Meta-Object Protocol below; `generalized-declaration.ss` / `meta-prototype.ss` |
| Interpreter project | A real Jsonnet/Nix implementation and its language-level correspondence/acceptance, not object examples | Classes below |

These rows remain OPEN/PARTIAL. The earlier lifecycle, reflection, computed
normalization and finite declared closure APIs keep the scoped implemented status
in the main ledger. No all-TODO completion or universal host-correctness claim is
made. Complete each workstream against these acceptance targets before using
optimization studies to claim functional closure.

The first four rows form one tested functional chain in `examples/lifecycle.ss`:
checked nested Account construction → persistent focused revision → fresh
constraint admission → current-tenant Reader/FUN observation → lazy delegate.
`doc/alignment.md` records the Racket/Lean/native correspondence and proof limits.
The Lean model proves input refusal, successful output admission, absence versus
stored values and active-key cycle selection; native tests separately check
receiver sharing, dynamic unwinding and callback behavior.

All generalized MOP extensions here advance the paper's **future work**. They
are not claims that the paper's Racket implementation already specifies this
complete class lifecycle, nor proofs of the Scheme compiler or runtime.
The concrete inherited-hook → invalidating source revision → declared reflection
chain now has implementation, native controls and Lean laws (see
[inheritance-hooks.md](inheritance-hooks.md)). Constant-base self-hosting and nonlocal declaration protocols are now implemented
(see [meta-prototype.md](meta-prototype.md)). Remaining work includes unrestricted
meta fixed points beyond finite positive Boolean equations, alternative-order certification, global security policy and
arbitrary lexical rewriting; these are not marked complete by this chain.
Performance tuning of the earlier factory workflow is paused for functional work.

### Recursive metalevel and declaration closure

`meta-prototype.ss` `close-protocol` reuses `closure.ss`: inherited `equations`
are solved from false, then inherited `cook` receives that exact least solution
and builds the ordinary kernel passed to `bootstrap-protocol`. Facts describe
finite positive metalevel components; a supported mutual dependency is allowed,
but an ungrounded cycle cannot invent or retain old metadata after revocation.

`recursive-declaration.ss` inherits `Declaration.` and adds
`expand-recursive-declaration`. Its explicit Interaction requests can refer to
later fragments and share completed dependencies. A Reader/FUN action owns fresh
memo for each current context, checks captured source revisions, then runs the
existing finalizer and descriptor/catalog checks. No partial prefix is returned
as an object on source failure, cycle, budget exhaustion or final admission error.

The recursive service example combines cyclic metalevel feedback, two service
branches, shared forward leaves, private revision annotations and a nonlocal
computed total. Controls include seed removal, current approval refusal/recovery,
stale metadata, source mutation rejection, root suffix suppression and isolation
between contexts. Lean `RecursiveMetaprotocol` and `RecursiveDeclarations` prove
the corresponding pure closure and source/publication laws. See
[recursive-declarations.md](recursive-declarations.md) for exact premises.

## Meta-Object Protocol

### General fragment protocol and non-record macro

`generalized-declaration.ss` provides ordinary extensible `Fragment.` metadata:
each descriptor chooses its own `focus`, `wrapper` and `method`, plus explicit
extra `sources`. Compilation reuses the existing Appendix B lens compiler and
generalized assembler. There is no closed tag enumeration of supported carriers.
`.prototype` uses the SAME declaration-form grammar/Reader expansion/finalization
as `.declare`, then admits and prepares the complete non-record fragment stream.
Labels identify contributions, while lenses may target overlapping raw components.

The concrete example combines heterogeneous scalar and method-group foci through
native Lens composition on nested vectors, cooked final-self dependency, existing
standard method combination and an independent audit frame. The same protocol and
macro also construct a procedure carrier. Source versions and registered callback
metadata are checked even for zero-depth/cooking observations. Changed source
requires fresh preparation; previously returned cooked values remain snapshots.

Lean generalizes the existing Reader expansion to arbitrary entry types, packages
heterogeneous typed focus/method descriptors, proves exact lens compilation,
membership-scoped frame preservation and complete-source finalization. Examples
prove finite observations for both carriers and seed-independent charge after
three stages for the triangular service. No general raw fixed-point or arbitrary
callback/lens correctness follows. See [generalized-declarations.md](generalized-declarations.md).

### Controlled raw closure and custom lens laws

`generalized-closure.ss` now closes a generalized declaration only after actual
adjacent raw states compare equal, within a fixed raw-step budget. It reuses the
existing source-guarded step/cook operations and returns a receipt bound to its
prepared owner/base. Budget, finite law and source/cooking refusals expose no
partial candidate; publication retains the exact old receipt. A native Reader/FUN
action composes successful closure with downstream observation.

`lens-laws.ss` checks get-put, put-get and put-put on supplied immutable states
and focus values. Check sources stay protected across raw steps and final cooking.
These are finite counterexample controls. Lean `LensLaws` states the universal
laws, proves their composition and discharges custom nested-product examples.
`Generalized.closeWithin` proves actual fixedness, the raw-step bound, origin in
the original seed and stability of every later original-seed unfolding.

`examples/closed-declarations.ss` places comparable data in nested vector raw
state, closes a three-component dependency chain, then cooks existing standard
method policy into a callable interface. Four raw evaluations include the final
equality check. This does not assert equivalence of earlier finite observations
to the older freshly allocated method-closure representation. Arbitrary fresh
procedure identities cannot be certified from sampled calls; budget exhaustion
remains inconclusive about divergence. See [controlled-closure.md](controlled-closure.md).

### Focused recursive components and final family admission

`focused-closure.ss` now closes narrow components inside a wider non-record raw
carrier, using captured outer lens checks and the existing bounded local closure.
Actual old/new child values extend the finite law domain. Ordered stages compose
with native FUN Reader `.map` and standard `foldr`; every source stays guarded
through the whole chain, final equation validation and family cooking.
All final projected equations are checked again: separate lawful lenses need not
be independent. Conflicting overlap refuses the complete publication; compatible
overlap can pass. Every final check costs one extra raw step beyond local search.

`examples/focused-services.ss` closes two nested-vector services with distinct
policies and existing primary/around methods, preserving sibling/shared audit
data. Native controls cover actual replacement laws, overlap, budget, stale
metadata, later source mutation, final cooking and Reader suffix suppression.
Lean proves focused fixedness/frame preservation, final admission soundness,
independent lens pairing and concrete family results. See
[focused-closure.md](focused-closure.md).

Still open: automatic proof/law discovery, unrestricted recursive feedback beyond
the controlled whole-carrier component equations below, generic convergence for nonmonotone equations,
arbitrary procedure equality and automatic dependent/cross-type adapters. The new
protocol is explicit ordered local closure plus final admission, not a general
global fixed-point solver. Functionality here precedes performance tuning.

### Controlled component feedback

`feedback-closure.ss` now searches a single wider raw state so cyclic components
read the same previous cooked global self. It reuses generalized declaration,
bounded actual-raw closure, lens controls and FUN Reader composition. The complete
declaration is finalized once. After whole-raw stabilization, EVERY named component
equation is checked independently against that same cooked self and original base;
cancelling overlapping updates cannot pass merely because the assembly is stable.
One declared fragment denotes a complete component, with internal method policy
grouped inside it or cooking. This does not change ordinary incremental inheritance.

The capped three-service ring combines cyclic allocations, joint approval,
primary/around methods and an independent audit. Lean proves concrete convergence
and acceptance from every typed seed within five raw steps at cap=3, as well as
generic conditional completeness, provenance, fixedness, component residuals,
frame preservation and budget bounds. Native controls cover oscillation,
cancellation, refusal/old publication, stale sources and nonlocal finalizer reuse.
See [feedback-closure.md](feedback-closure.md) for API, residual costs and premises.

Arbitrary convergence/leastness, unrestricted higher-order recursive knots,
automatic dependency/law discovery and callback termination remain open. A finite
budget is not a proof of divergence. Functional closure here precedes optimization.

### Shared feedback and cross-service revision

`feedback-revision.ss` composes fresh feedback closure with current joint approval
inside one source guard. Old raw is only a seed; no old fixedness or approval is
reused, even if the raw value is unchanged. Registered preparation/check sources
stay protected until approval finishes. Strict Boolean approval and exact old
publication retention cover closure, source, residual and callback failures.

`examples/shared-feedback.ss` connects one shared quota node to two nested service
branches in a four-node feedback ring, joint readiness, primary/around methods
and current cross-service commitment/permission checks. Quota increases/decreases,
approval rejection/retry and old snapshots have native controls and paired Lean
examples. `reviseFeedback` proves new closure, exact-candidate approval, component
equations, seed provenance and budget bounds; `admitted_joint` proves current
permission/coherence/commitment for any accepted example revision. Product lens
laws and explicit frame preservation are universal. See
[feedback-revision.md](feedback-revision.md) for preparation/refusal boundaries.

This closes the explicit shared-feedback revision workflow; generic convergence,
selective cyclic recomputation, automatic dependencies/laws and unrestricted
higher-order knots remain open. No performance or compiler/runtime claim follows.

### Selective reconstruction of feedback groups

`feedback-cache.ss` now combines whole feedback closure with the EXISTING DAG
construction cache. Shared input/body edits invalidate transitive reader groups;
unaffected groups reuse exact closed objects and skip their builders. Each cycle
group is atomic, with all component residuals checked at construction. Stale
retained group sources refuse final publication; rebuild them by explicit graph
source edits. All required groups and registered approval sources stay protected
through ALWAYS-fresh joint approval. Failed candidates never become reuse bases.

`examples/cached-feedback.ss` covers shared quota, two reader groups, a cross-group
edge, an independent feedback group, source increases/decreases, joint refusal/
retry and permission-only edits. Refusing builders and identity checks verify
skipping. Native negative controls include removed inputs, illegal inter-group
cycles, stale retained metadata, source writes and FUN suffix suppression.
Lean `Functional.FeedbackCache` reuses ranked cache invalidation, proves retained
reference equality/current approval and packages actual closed group equations.
The reusable `Prototype.Generalized.CappedFeedback` supports both the earlier
ring examples and new selective-vs-fresh construction controls. See
[feedback-cache.md](feedback-cache.md) for hypotheses and functional boundaries.

Automatic SCC grouping and merge/split invalidation are now implemented in
`strong-components.ss` / `feedback-graph.ss`. Shared quota, two services, final
settlement, an independent loop and current joint approval cover graph revisions
through existing whole-group closure and DAG caching. See
[strong-components.md](strong-components.md) for the Racket/Lean/native mapping,
accepted-certificate proof scope and executable controls.

Simultaneous split/merge, shared-input migration and cross-service joint batches
now compose through `generalized-graph.revise`, native FUN revision bind and the
reusable lens-based `component-closure` builder. The twelve-node service example
checks unchanged monitors, equal-value migration, detached old inputs, new-source
invalidation, current joint approval and retry after partial failure. See
[service-revisions.md](service-revisions.md) for typed laws and functional scope.

Component insertion/deletion now uses an explicit erasing `graph.reconfigure`
batch before the same FUN graph revision chain. Bridge insertion merges several
SCCs; removal plus rewiring splits them, clears providers and invalidates shared
readers. Dangling reads, latent resurrection, removed representatives, isolated
new nodes and current support-aware joint approval have controls and typed laws.
See [component-membership.md](component-membership.md) for exact scope.

Still open: automatic discovery of hidden callback dependencies, cycle-interior
selective reconstruction, general convergence/leastness and unrestricted
higher-order knots.
Only immutable/extensional DAG metadata and declared dependencies authorize reuse;
no runtime speed, allocation or GC improvement follows from these controls.

Multi-service membership contributions now join through `component-revision` and
existing support revision/FUN publication, rejecting conflicting or stale edits
before construction. `examples/component-migration.ss` replaces endpoints in two
SCCs, migrates their shared input and changes two inputs in one jointly approved
source. It checks partial deployment, detached old dependencies, provider erasure,
exact clean reuse, conflicts and refusal/retry. This is finite generalized-protocol
future work; see [component-migration.md](component-migration.md) for correspondence
and proof limits. It does not close unrestricted mutation/recursion TODOs.

Multi-round component recreation, interleaved SCC merge/split and repeated shared
input migration now reuse the same contributions and whole-group closure. Staged
`component-revision.revision-action` binds to the exact expected publication,
rejecting old requests even after supported names and values return. Cross-service
approval metadata changes still require freshly prepared lens checks; refusal
retains the last publication. See [component-rounds.md](component-rounds.md) for the
seven-state native/Lean scenario, repeated cycles and explicit proof premises.

Competing staged component requests now use `component-publication` to arbitrate
one authoritative current head. Final installation rechecks expected identity,
refusing late candidates and returning current rival state rather than restoring
a stale predecessor. Current-policy retry and fresh staging after topology changes
reuse existing FUN revision/closure/approval. See
[component-publication.md](component-publication.md) for native bounded-thread and
interleaving controls, abstract Lean installation laws and explicit concurrency
premises. This does not claim arbitrary mutable-object thread safety or rollback.

Approval metadata invalidation is now serialized with final installation via
`component-publication.revise-approval!` and guard validation inside the same lock.
Several paused requests, policy change-back, metadata-only drift and six rounds
of fresh restaging compose with existing service closure and native versions.
See [approval-revision.md](approval-revision.md) for same-coordinator write premises,
abstract revision laws and bounded thread controls. Foreign-domain/raw metadata
writes and arbitrary mutable-object transactions remain outside this protocol.

Multiple endpoints can now share an explicit `approval-domain` while retaining
independent graph heads and request ownership. Shared native object revisions
invalidate all observing guards; local-only policy changes remain selective.
Related shared/local revisions, two paused owners, independent domains and fresh
restaging on different topologies are covered in
[shared-approvals.md](shared-approvals.md). The domain orders individual policy
updates and installations; atomic multi-head publication or multi-object rollback
is not claimed.

Atomic shared policy replacement and consistent endpoint publication now use
`joint-publication`: one immutable authoritative snapshot, all endpoint closure
and approval, final joint consistency and one guarded pointer installation.
Refusal preserves all old fields; stale work returns the current whole winner;
fresh restaging reuses current graphs and proposed native policies. See
[joint-publication.md](joint-publication.md) for heterogeneous Lean bundle laws,
real native closure/thread controls and reader/immutability premises. This is a
joint snapshot interface, not atomic mutation of old independent coordinator handles.

Multiple atomic joint requests now interleave across merge/split/restore rounds.
`joint-publication.stage-at` binds explicit expected bundles and `stage-with`
prepares contributions from one captured current snapshot without silent rebasing.
Old batches remain stale after field-value round trips; fresh preparation after
failure or a rival publication reuses current source and policy objects. See
[joint-rounds.md](joint-rounds.md) for bounded native competing workers, six-round
retry controls, arbitrary stale-batch and finite validity-preservation proofs.

Atomic joint revisions now allow asymmetric endpoint phases: insertion/deletion,
SCC merge/split and shared input migration at different services in the same
bundle, with a shared total-budget policy instead of equal-settlement assumptions.
Seven native rounds preserve independent cache receipts and reject old siblings;
failed total budgets require explicit fresh preparation. Dependent universe-
polymorphic Lean replacements retain actual sources/graph/closure receipts. See
[joint-topology.md](joint-topology.md) for exact scenarios and proof scope.

Competing requests now explicitly distinguish local refusal from unanimous local
success followed by joint budget refusal. Denied requests preserve same-round
sibling freshness; successful rivals invalidate old requests across split/merge,
component restoration and equal-valued approval round trips. Fresh preparation
and retained independent feedback receipts are checked natively. Lean adds
composable admission and refusal-prefix laws with actual certified topology heads.
See [joint-admission.md](joint-admission.md); this remains generalized-prototype
future work with explicit finite/purity/identity premises.

Post-admission installation now has an explicit native `approve` / `install!`
boundary with private receipts; `submit!` composes both. Competing approved SCC
changes, shared proposed-policy revision drift, equal-value revision round trips
and their combination refuse before installation, then explicitly restage from the
actual winner. Whole typed bundles reuse the Lean checked-installation laws. See
[joint-installation.md](joint-installation.md) for native lifecycle controls,
exact API failure conventions and the immutable-installed-policy boundary.

Multiple already-approved receipts now compose through `install-sequence!`, with
ordered per-attempt outcomes and independent guarded installations. Six native
merge/delete/split/restore rounds invalidate two receipts sharing one proposed
policy, allow an independent same-round winner, then replay all older receipts.
Fresh approvals, equal-valued revision round trips, component erasure and stable
feedback reuse are covered. Lean adds certified receipt traces, arbitrary-order
validity, obsolete batches and drifted-attempt elimination. See
[joint-receipts.md](joint-receipts.md); sequence-wide atomicity is not claimed.

Already-approved receipts now also install on real Gerbil worker threads, with
standard ready/release channels and bounded joins. Six SCC lifecycle rounds race
shared-invalidated receipts against independently approved alternatives, including
duplicate receipts and concurrent replay of prior rounds. Fresh policy-only
publication restores original values, then all older receipts remain obsolete.
Coordination failure and worker cleanup are covered. Lean proves either valid
lock-order winner and replay refusal, with actual certified topology controls.
See [joint-concurrency.md](joint-concurrency.md) for the native/formal bridge premises.

Mixed-generation waves now release all historical and current approved receipts
together, preserving receipt identity with a pure higher-order `report:` mapping.
Six native SCC rounds directly reject each historical receipt while one independent
current receipt wins; an entirely refused asymmetric wave explicitly restages and
continues component deletion/restore. Lean adds mixed-head/guard refusal and winner
laws plus all-order certified controls with historical receipts. See
[joint-generations.md](joint-generations.md) for exact scenarios and premises.

Cross-round preparation can now continue inside one scoped native worker group,
while older approved receipts remain waiting. Six SCC phases retain a late worker
across next-phase admission, shared-policy drift refusal and explicit restaging;
old/new workers then install in either order before the next pending generation.
The one-shot concurrent interface reuses the same standard-channel worker scope.
Unobserved results, escaped operations and duplicate release refuse. Lean binds
successful new preparation to the observed prefix head and proves late-attempt
preservation. See [joint-restaging.md](joint-restaging.md) for precise boundaries.

Independent native coordinators now own separate continuing worker scopes while
concurrently preparing and publishing through one owner. Standard thread groups
supervise both coordinators and their nested workers. Six SCC phases share a
proposal, refuse its revision drift, then concurrently restage independent valid
candidates while older siblings remain pending; exactly one primary publishes.
Supervisor-failure recursive cleanup and original error propagation are covered.
Lean proves competing same-prefix factories, superseded observations and source
preservation after refused prefixes. See [joint-coordination.md](joint-coordination.md).

Local normal exits and caught coordinator errors can now be isolated explicitly
through `on-exit:` after per-coordinator child-group cleanup. The default still
propagates the original exception and closes the scope. Two survivors continue
shared-policy invalidation, explicit fresh approvals and six competing SCC phases
while two other coordinators fail/return with pending nested installations. Shared
workflow and assertion modules avoid duplicating the earlier scenario. Lean adds
lifecycle projection, stop preservation, explicit preparation and validity laws.
See [coordinator-recovery.md](coordinator-recovery.md) for controls and proof scope.

A failed coordinator can explicitly rejoin the SAME supervisor via `restart:`
after its old children are cleaned, parent joined and original outcome handled.
Three recoveries interleave with six SCC phases and persistent competing peers;
replacements replay/refuse old receipts, then freshly capture/construct/approve.
Old replies cannot reach a replacement, unhandled errors prevent restart and final
joins cannot launch unsupervised work. Lean records no-write rejoining, current-head
preparation and head/guard-stale receipt rejection. See
[coordinator-rejoining.md](coordinator-rejoining.md) for premises and native controls.

Named recovery decisions now compose through `call-with-rejoining-coordinators`.
Two failed names interleave five recoveries across six SCC phases, including both
orders of a common exit wave, a delayed replacement while another fails again,
four-way current competition and mixed historical receipt refusal. A later failed
recovery handler cleans another name's live replacement and child. Lean adds
arbitrary lifecycle-wave erasure, whole-owner preservation, historical refusal and
fresh factory observation laws. See
[coordinator-interleaving.md](coordinator-interleaving.md) for the exact scenario,
callback contract and conditional proof scope.

`rejoin-after` now composes fallible preparation with the existing service chain.
Two recovering names fail four times BEFORE rejoining while persistent peers keep
publishing across six SCC phases; three further failures occur after fresh service
approval. Preparation resources clean on both paths, original errors retain identity,
and only successful preparation enters the continuation with its whole value tuple.
Shared checkpoint assertions use standard nonblocking channel reads and FIFO
buffering. Lean adds fallible checked preparation, exact errors, failed-attempt
projection and whole-state preservation/validity laws. See
[coordinator-retry.md](coordinator-retry.md) for the exact scenario and premises.

### Inference and specialization in the declaration protocol

Explicit ground/prefix Type binding now feeds the same declared generic protocol.
`specialize-prototype-type` produces residual syntax/bounds using the existing
positional specialization; `instantiate-declared` and `infer-declared` call the
ordinary builder only after complete binding or uniquely completed finite search.
`instance-signature` derives the dispatch Types from checked Function/CaseFunction
syntax, including optional/keyword/rest and exact multiple outputs. Existing
standard/forwarding/inner continuations preserve all user values; reduction
policies keep their declared one-value policy semantics. Effective preparation
and explicit context retain the existing cache owner and negative watches.
Typed groups are installed/negatively checked before returning an instance.
Finalized declarations cannot overwrite bound parameters or reopen `.parameters`;
current descriptor identities/revisions are checked before inference and again
before publication. No-solution, ambiguity, exhaustion and builder/registration
failure remain distinct. See method-declarations.md and prototype-types.md.

The bridge is complete for explicit finite candidate schemas and ground ordered
prefixes in the existing algebra. Arbitrary principal types, host signature
inference, unrestricted recursion/effects and transitive Type semantic discovery
remain outside this boundary. Lean proves prefix/constraint, builder-provenance,
phase/refusal, positional-frame and final source-admission laws. `FunctionSignature`
additionally proves shape preservation under Type substitution, ordered selection,
conservative rich variance and exact all-or-error output/cache-owner completion. Tests cover the
complete FUN/IO chain and stale/override/retry controls, not only added examples.

### Concentrated declaration/type/specialization acceptance

| Priority | Audited protocol gap | Current acceptance |
| --- | --- | --- |
| P0 | Inputs/expected results had to be lowered to handwritten inequalities | Closed within explicit finite syntax: `infer-prototype-calls` / `infer-declared-calls` reuse Function first-shape selection and argument normalization, generating supplied input and reversed output obligations under one quota. |
| P0 | Named generics could not infer one shared assignment from their calls | Closed for known explicit Object signature paths: all observations share original bounds, one complete search and one whole declaration builder. `instance-signature` projects the same completed catalog. |
| P0 | A builder could omit required siblings or bind a different signature | Closed at declaration admission: all named Function leaves (and a root Function's implementation) require matching factory expression/path/descriptor sources; source metadata is captured before callbacks, and original bound names cannot be dropped. |
| P1 | Direct Function revision could outlive a declared cache owner | Closed for factory-owned direct descriptors: immutable source stamps are retained by owners and checked before snapshot/call and after successful work. Original exceptions/effects retain their defined semantics. |
| P1 | Joint inference lacked captured call/query diagnostics | Closed: success/nonunique/no-solution reports retain the captured observations and derived inequalities in order. |
| P2 | Inference grammar is narrower than the runtime Type/container library | Pair/Map/Sum/Union CLOSED within the finite observational algebra: exact kind/arity checks, literal tags/arrows, canonical Map arrows and normalized candidate deduplication; Pair component covariance, invariant Map keys/covariant values, exact Sum tag skeleton/covariant payloads, invariant ordered Union branches. Existing validators retain recursive Function wrappers and atomic collision refusal. Integrated prefix/call inference/declaration/FUN/refine/evidence controls are in t/container-inference-test.ss. IntegerRange CLOSED for literal inclusive min:/max: endpoints (integer or false), symbolic numeric inclusion, finite literal membership, source-ordered metadata canonicalization, prefix specialization and original rich typed declarations/publication; t/range-inference-test.ss. Empty intervals remain descriptor data; range-to-Enum/Exactly inclusion CLOSED for admitted immutable literals: empty intervals, inclusive finite coverage with Gerbil equal? indexing, width rejection before preparation, quota-charged membership, no descriptor-kind collapse, and complete specialization/declaration/FUN/refine/evidence integration. Joint range/Enum-to-Union coverage CLOSED for bounded integer-range and keyword-stable finite literal sources into entirely intrinsic flat ordered trees: interval residual subtraction, complete literal membership, unchanged public descriptor order, invariant Union-to-Union/Map keys, no wrapper-bearing shortcuts, and original specialization/declaration/FUN/refine/evidence publication; t/union-inference-test.ss. Public unbounded source ranges, arbitrary dependent endpoints, general Boolean/predicate coverage and nonnumeric emptiness discovery remain OPEN. String/Symbol scalar families and immutable symbol Exactly/Enum literals CLOSED through admission, shared intrinsic recognition, finite variance, prefix specialization, keyword-wire exposure and original typed declarations. A shared catalog publication action removes the duplicate numeric/text FUN/refine/evidence chain; t/scalar-inference-test.ss. Mutable String literals remain unsupported. OrFalse CLOSED through the same finite unary protocol as Maybe: distinct false/void sentinels, child covariance, fixed Map keys/ordered Union branches, capture-free specialization, keyword-token exposure, finite guarded Mu expansion and the existing recursive wrapper/publication chain; t/optional-inference-test.ss. The constructor vocabulary is shared by prototype and Mu binder admission. Finite Record field inference CLOSED for explicit `(name Type required/optional)` fields and open/closed policy, compiled directly through Class/RecordSlot. Record and Object share one named-field replacement protocol: order-independent readable coverage, width for open targets, required/optional presence and closed-source absence for missing optional targets; closed targets reject open sources and extra declared keys. Descriptor field order is retained during normalization and construction. Record outputs compose with prefix specialization, call inference and declared generics; actual inherited defaults/computed overrides/hooks are checked by existing Class construction. Implicit inference from arbitrary Class/Slot callbacks and nominal ancestry remains OPEN; no covariant mutable-write permission is inferred. |
| P2 | Candidate-dependent signature kinds/fields and wider case-language replacement | Candidate-dependent signatures/fields CLOSED for explicit finite candidates: whole Type variables, substituted field Types and disjoint Object row tails determine callable paths before shared call constraints are checked. Each accepted alternative retains its own normalized layout and inequalities; only complete unique inference enters existing typed declaration and full sibling admission. See t/candidate-inference-test.ss. Effective Function option identity is CLOSED: shared descriptor projection canonicalizes binding order and explicit empty defaults throughout candidate inference, substitution and invariant container relations, while retaining captured source syntax and ordered cases/fields/keyword payloads. See t/function-options-test.ss. Declared case call-language coverage/replacement CLOSED within the common keyword wire mode and finite structural Type algebra: complete arity/key partitions preserve first selection, support different optional/rest regions and disjoint reordered cases, and check exact-count covariant results/contravariant supplied inputs. Function/CaseFunction cross-kind and nested callback relations feed the existing inference/declaration chain; see t/function-coverage-test.ss. Different raw keyword modes CLOSED within two sufficient rules: keyword-source/positional-target supplied outer-carrier stability, and positional-source/keyword-target clamped lower/upper raw-length regions with actual ordered source selection, fixed/optional and case-lambda combinations, typed direct minimum rows and value-sensitive non-direct origin traversal using existing Keyword/Exactly/Enum; known literal ordinary origins are restricted exactly, and independent raw/decoded counters retain position-specific rest correlations through a certified finite product graph; exact outputs and first-match semantics remain mandatory. The existing inference/specialization/declaration/FUN/refine/evidence chain is exercised in t/keyword-coverage-test.ss, t/keyword-prefix-test.ss, t/keyword-values-test.ss and t/keyword-rest-test.ss. Opaque/wrapper-bearing ordinary refinements beyond the supported finite restriction, effectful recognizer/default behavior, arbitrary semantic predicates and unrestricted recursive/higher-rank language inclusion remain OPEN. |
| Outside current decidable boundary | Implicit host/principal/higher-rank/effect inference, arbitrary predicates, unrestricted recursive types and transitive callback semantic discovery | OPEN; explicit finite candidate inference and runtime wrappers do not certify these. |

This closes the integrated finite interface protocol, not every type-system TODO.
The source/descriptor checks are bounded admission and direct revision discipline,
not global security or atomic concurrent Type revocation. Data fields stay under
existing contract validation. See method-declarations.md for exact failure phases
and prototype-types.md for the finite algebra; resources/full checks are retained.

### Certified typed method declaration closure

The existing `method` form now admits a certified `signature` plus existing
`declarative-metadata` edits; `typed-method-fragment` constructs that same form.
Same-signature coalescing/inheritance, ancestor-before-local installation,
completed-candidate negative admission, `.defgeneric` argument forwarding,
input/output validation and explicit immutable cache succession form one protocol.
Gerbil promises compile a demanded whole group once, while current guards rerun.
Supported declaration revisions invalidate groups; mismatched signatures, bad
carriers/arity, forbidden methods and bad results retain refusal boundaries.
See [method-declarations.md](method-declarations.md), the shared diamond/two-axis
FUN/IO example and `t/typed-method-declaration-test.ss`. Lean `MethodDeclarations`
proves acceptance, batch parity, cache soundness, transported absence and refusal
retention; `Examples/TypedMethodDeclarations.lean` checks finite workflow controls.
This closes explicit certified declarations, not arbitrary inferred syntax or
unrestricted MOP/recursive compilation. It advances the article's future work.

### Declared method fragments and receiver generics

`method-declaration.ss` extends the ordinary inherited declaration protocol.
The SAME `.declare` handles `public`, `private` and `method` forms; computed
`method-fragment` names and recursive declaration roots share the finalizer.
Same-name compatible method contributions coalesce in source order, while record
collisions, malformed groups and conflicting visibility/admission policies refuse.
Existing Slot computation prepends local methods to the delayed inherited group.
Registered descriptor edits invalidate both the metadata and receiver caches.

`.defgeneric` `combination:` receives the raw group and complete argument list;
`from: type` still supplies the ORIGINAL instance exactly once. Standard, simple,
forwarding, inner and Simula adapters reuse existing method interpreters. Empty
raw groups can be explicit defaults; nested missing-slot errors are not treated
as missing generic slots. No result or approval is cached by this bridge.

`examples/declared-methods.ss` composes a shared base, two service branches,
before/primary/after/around fragments and current-context Reader observation.
Lean's `MethodDeclarations` proves source collection, coalescing, inherited block
composition and equivalence to standard generic invocation. Native tests cover
all adapters, descriptor edits, recursion, zero/rest arguments and failure effects.
See [method-declarations.md](method-declarations.md). This concrete integration
advances generalized-prototype future work; functional completion precedes tuning.

Redefine POO using
[a compositional MOP for Prototype Inheritance](https://github.com/fare/projects/issues/7),
i.e. a Meta-Object Protocol in the spirit of the CLOS MOP.

### Sources of Inspiration

Get inspired by the specification of [AMOP](https://cliki.net/AMOP), except without classes.
As reference implementation code, see for instance
[Closette](https://github.com/binghe/closette/blob/master/closette.lisp)

Start from something minimal, in the spirit of
[POP](https://github.com/divnix/POP/blob/main/POP.md),
and/or of these two functions:
```
(def (instantiate p b) (def f (p (λ a (apply f a)) b)) f)
(def ((inherit p q) f s) (p f (q f s)))
```
Or instead of having an eta-converted function `(λ a (apply f a))` we could use lazy evaluation:
```
(def (lazy-instantiate p b) (def f (lazy (p f b))) f)
```

### A MOP for inheritance

Primitives that we may want to intercept include:
  - method computation from some point in the hierarchy (`compute-slot`),
  - linearization the inheritance DAG (`compute-precedence-list`),
  - etc.

Also get inspired by Racket-style proxies and impersonators so even basic types
can carry prototype information, and be modified or instrumented through prototype mechanisms,
e.g. to trace all arithmetic operations in parts of a program.

Allow user-defined storage strategies, so the storage optimizations described below
could be done purely "in userland".

For instance, allow users to select which optimizations and constraints their object hierarchies use,
e.g. single-inheritance, static strong typing with a given system, etc.

Allow handling of undefined methods with a mechanism akin to
CLOS's `no-applicable-method` or smalltalk's `doesNotUnderstand`.

Use that mechanism to implement "lazy delegation" like
[Fisher's and Shivers' Ziggurat](https://www.ccs.neu.edu/home/shivers/papers/ziggurat-jfp.pdf),
by inheriting from `(fallback-to ,lazy-expr)` or something,
which implements the `no-applicable-method` protocol by
having it delegate messages to some `.fallback-handler` field lazily initialized
with the provided expression.

### MOP for method-combination

Allow for compositional definition of method-combination, and more generally of non-record objects:
effectful procedures (or, with a tweak, monadic functions) can be defined from many fragments
(primary, before, after, around methods, etc.).

But values of other kinds of types can also be made of many fragments.
Indeed, records of values in as many "slots", i.e. "records", "structures", "objects",
are the prime example of something being defined from many fragments (or slots, fields, components, etc.).
Surely, these two kinds of computations follow a common pattern, and
should be defined according to a same set of macros, as well as further such incremental definitions?

Actually, just like method qualifiers or object slots are a way to incrementally define part of an object,
method specialization is also a way to incrementally define part of a function.
More generally, this is all about incrementally defining part of "the universe".
How do you divide the universe into parts and reconstruct it from it,
and further divide these parts into subparts, etc.?
There should be a general mechanism to define a program recursively
in terms of such composable incremental fragments.
(Bonus: then, how do you deal with "degeneracy" in the sense of Gerald J. Sussman?)

Primitives that we may want to intercept include:
  - partial specification of a fragment of an object or sub-object
    (see in CLOS, `(defmethod foo :qualifier ((x specializer) ...) ...)` or in Nix, `a.b.c = d;`).
  - computation of the function / object from the fragments.
  - general inlining to skip over from chasing the sub-component back from the complete universe
    to directly computing with the sub-component without computing the whole universe,
    i.e. instead of `universe.a.b.c` directly deal with `b.c`;
    instead of computing the entire `generic function`, deal with the "component" that handles
    the arguments at hand, only.
  - method lookup (`.ref`), e.g. for debugging, transactional persistence or access control,
    or just for reconstituting the sub-component of an object from its fragments.
  - method side-effects (`.putslot!` and `.put!` or whatever replaces them), for same reasons,
    and not the "reverse" operation of setting the fragments right from the composed value, too.

### Design and implementation of the MOP

As in POP, start from distinct and general notions of prototype and instance
(indeed, the most type-parametric notion of prototype function).
Then, combine them into a notion of object, and
add the MOP as another layer of fixed point to the design.
Indeed, experiments in POP to add multiple inheritance to prototype objects
suggest that the prototype function, direct and effective super class lists, etc.,
and other meta-information, should be be grouped together in a single entity
that generalizes the prototype as a function strictly speaking.
I suppose that in the general case, this entity that contains all this information,
is what gets to be called "prototype", whereas the function from the simple case,
now only a component of the prototype, gets a different name, like "prototype function".
In any case, this "prototype" entity is itself subject to being computed
as the instance of a prototype fixed-point. And since it has several components,
it can be organized as a combined instance-and-prototype object rather
than an instance detached from its prototype, hence the MOP bootstrapping.

Maybe the meta-object may be a record that caches together
both the prototype function and its lazy fixed point,
together with a meta-object, itself a prototype that describes how instantiation and composition work,
as well as additional type-specific accessors or extension points, encoding information, etc.
```
(defstruct poo (meta prototype instance) constructor: :init!)
```

### More efficient internal object representation

The "prototype" is itself an object, that specifies more than simply a function (see above).

*If* semantically the instance type is a table from resolved-identifiers to values,
rather than symbol to values,
then maybe the "prototype" field is such a value with
a special identifier `prototype` defined in the MOP.
In the meantime, we just reserve a special symbol, e.g. `.prototype`.

With a separate meta-object, we can compositionally build up the meta-object
to refine how the prototypes are instantiated and composed, how they can be built in terms
of "extension points" each of which will be its own prototype, etc.
With "objects", an extension point is further refined to specify a record of extension points;
with "method combinations", some extension point will control the flattening of individual prototypes;
with "prototype linearization", super prototypes are a dependency graph, not a mere list,
and a list is first extracted from that graph (based on some external global well-ordering
of all prototypes?).
The "object" reference would provide context for the lazy evaluation of whatever "attributes"
(each the cached computed fixed-point value of some "extension point"), etc.

## Syntax

The proposed keyword grammar is implemented, including independent local-slot
binding selection. The legacy `::` grammar still lowers through the SAME engine.
`super:` means the paper's delayed current-slot inherited computation, not a
reified parent object. Prefix `.parameters` specialization is persistent and
composable; default/keyword/rest generic forwarding is verified on the existing
Gerbil formal parser. See [parameters.md](parameters.md) for the complete grammar,
API, receiver/closure semantics, executable acceptance and proof correspondence.

## Simple Features

Constraint-checking assertions and other instantiation-time side-effects
as part of the `.instantiate` function.

## Classes

Our `mop.ss`, `type.ss`, `number.ss`, already have large chunks of it, but
we could and should probably better support class-based object orientation
using POO as the object system used at its meta-level to represent classes.

The same descriptor meta-object, viewed as a prototype is a class descriptor,
and viewed as an instance is a type descriptor.

Its element template prototype can specify provide default slot values
as well as constraints on slot types and slot values.

A special slot in each object contains the type-descriptor
(it is `.type` in our current setup; it semantically analogous to the `vtable` in C++,
though the current implementation is less efficient,
though it might be simpler start to experiment with meta-object protocols).

  * Constraint-checking assertions and other instantiation-time side-effects,
    and a function `.instantiate` to invoke them without accessing a slot.

  * Enforcement of a discipline on prototype mutability.
    Objects must not be modified after having been used as super-prototypes.

  * Reflection on objects, to view a list of slots, to intercept how slots are computed,
    or determine who has access to which slots when.

  * Support for conditionally-defined slots, or slots for computed names.

  * Support for slot definition macros with non-local effects to the rest of the object,
    e.g. to declare a slot as "public" or "private",
    and have that reflected in a list of either kind of slots, and/or in slot-property meta-slot;
    similarly, slot combination methods as meta-information, similar to method combination in CLOS.

  * A better implementation of Jsonnet and/or Nix in Gerbil, based on POO (?)

  * Identify and implement the "usual" optimizations that e.g. SBCL uses for CLOS.

## Data representation

The use of mutable hash-table's is a poor man's solution to organizing data.
For non-mutable use, represent prototypes as pure persistent maps instead.

Make sure these maps are merged in a way that maximizes sharing of state.
Maybe even with hash-consing.

For performance, have an optimized representation for tables with few entries
(under 4? 8? 16?), e.g. a flat vector with a linear search.
For extra performance, maybe automatically keep it sorted by access frequency?

Specially represent prototype methods that ignore their super-method in
an efficient way such that multiple successive overrides of a same method
won't create an indefinitely growing chain of forgotten values.
For instance, one linked list of methods per slot name, or instead of a list,
"just" composing functions including "lossy" ones like the K combinator.

Represent the instance (or its base layer, if there are many layers) as a vector,
wherein the indexes are based on the hash-consed "shape" of the prototype,
the shape being the sorted list of its slot names.

Maybe intern the symbols used as prototype slot names into a table assigning each a unique integer
(at load time? or based on tree walking the entire program?), and use some hash-consed word-granular
(rather than bitwise) patricia tree data structure for shapes.

For the mutable case, a tree might work too, though a hash-table is simpler.
For a real efficient use, we would like an array containing the values,
but then comes the question of the mapping from slot name to array index,
especially in presence of multiple-inheritance, where it is not enough to know
a constant super-object to assume a constant array index.

The mapping from slot-name to array index given object can be refactored to
mapping given "shape", when the shape forgets other irrelevant details about the object
and can share data between objects of same shape (e.g. variants of a same super-object).

This mapping is typically itself a immutable tree.

For higher performance, we can have cache the mapping from object and slot to array index,
taking advantage of common cases where the slot is constant, and/or the shape is constant
or varies little. Possibly, each access site could have its own inline cache, as in SBCL.

Beware that proper detection of the optimizable cases (e.g. constant shape) is non-trivial,
that caching all the time is costly, and that JITing to do it only where it matters is complex.

Make sure this works well with constant-folding in the underlying compiler.

A Meta-Unquote Protocol (MUP) could provide at the same time reader/printer information,
mapping between "virtual" structure (accessor function) and "real" structure (physical layout),
an object structure description that enables runtime as well as compile-time optimizations.

## Better Debugging

Detect circular definitions with a suitable variant of hash-ensure-ref,
and report them nicely.

In Slate a mixin is an object with behavior and no state.
In Squeak, a Trait has a protocol that has modular requirements and provisions.
Records, delegation. Object/Meta delegation flag attached to the slot.
e.g. for "new", you want a new object, not a new class.

Multimethod dispatch: the earlier arguments would take priority over later one for method-not-found;
    in DSLs, the method-not-found would do autodiscovery from e.g. the filesystem.
    Subjective dispatch vs objective dispatch.
    Performance: Method inline caching.

  * Look what we can save from [TinyCLOS](https://github.com/ultraschemer/gambit-tiny-clos/blob/master/tiny-clos/core.scm) ?

##

  * Design and implement a type system that works well with POO.
    https://github.com/fare/projects/issues/3
    This type system probably would have some notion of subtyping, such that
    a function prototype has type `(forall a (forall b < a (b <- (b <- a) <- a)))`.
* [A good type system for prototype inheritance](https://github.com/fare/projects/issues/3)


## Notes

We have to start with a gambit: we pay a price for our choice of representation,
so we can gain the advantage of uniform reasoning and optimizations later. Possibilities:
- Make everything a lazy value, and directly use the same formulas as in Nix.
- Make everything a closure, and be more like the original Yale T object system.
- Make everything a hash-table, and be more like JavaScript objects(?).
- Make everything a struct, and be more like C++ objects.
- Add a hidden "meta" field to everything, and be more like Clojure objects.

Since we're a Scheme, we'll opt for everything is a closure.
How then do we represent magic meta-information?
- A call with a special magic argument?
  Works well if e.g. usual first argument is a symbol, but this one isn't.
- A global weak hash-table keyed by the closures? Rather slow.
- Some implementation-specific extension field. Not portable, and not available on Gerbil.
Normal: ← ⇐ Long: ⟵ ⇐

Possible representations for objects of schema A_ (fun from Symbol to Type):
- (Fun (A_ msg) <- msg:Symbol)
  Good: very simple. Bad: makes introspection hard, or must be separate,
  or the function also accepts special magic input parameters.
- (Fun (PureTable|Table (Fun|Lazy (A_ msg)) <- msg:Symbol))
  Basically, break down the previous into a table, per slot.
  Good: "functorially" maps the structure of prototype onto that of desired
  values.
- (Fun (Fun|Table|PureTable SlotInfo <- Symbol))
  An object computes a table from symbol to SlotInfo.
  Here, SlotInfo would be as follows:
(SlotInfo A B) = (Record ;; should this "just" be a (Meta A B) object?
  ;; or maybe we need a lens-like (Meta S T A B) object?
  instance-value: [(Maybe A)]
  flags: [Nat] ;; 1: cached? 2: default? 4: ignores-self? 8: ignores-super?
  direct-proto-fun: [(Fun A <- A D)] ;; meta
  parents-proto-superfun: [(Fun D <- B)] ;; computed during instantiation
  direct-default-value: [(Maybe B)])

In practice, using (case ...) make should implementation relatively efficient
for plenty of keys at once.

### Old internals

Internally, in the current implementation, an object, or poo, is `Poo` struct, with two slots:
a list of elementary prototypes and an instance.

Each elementary prototype is a hash-table mapping each defined slot name to a function
that computes the slot value from two arguments:
  1. a reference to the object itself,
  2. the list of super-prototypes.

The instance is a hash-table mapping for each slot name the value computed
by using the prototypes, or otherwise explicitly set as a side-effectful override.

Note that this model is not capable of supporting a slightly more expressive object model
where computations can access arbitrary slots of the super-object,
or a reified version of the super-object itself.
If such an extension is considered useful, it may be implemented by resurrecting
a notion of "layers" present in a previous version of the code, wherein each instance
contains a list of layers, one for each prototype in the list, that maps slot names to values
for the definitions present in that given prototype.
The first layer can also serve to cache all slot computations and
hold values of slots modified by side-effects.

## Generic Data Structure Library

On top of Gerbil-POO, build an
[Efficient, Incremental, Generic, Isomorphism-aware, Correct Data Structures](https://github.com/fare/projects/issues/10)

## Property-based testing

The finite protocol, including automatic guarded recursive container graphs
(`generation-graph.ss` / `recursive-generation.ss`), is implemented in `property-testing.ss` and
`function-testing.ss`, using Gambit's isolated SRFI-27 source, ordinary descriptor
extensions and Reader/FUN composition. Acceptance tests cover actual optional and
keyword invocation, nested callbacks, overlapping clauses, seeded replay, strict
shrinking budgets, exceptions and descriptor revision refusal. See
[generated-testing.md](generated-testing.md) for the supported families and
remaining open scope; the broader inspiration below is retained.

Use type descriptors as the basis for a property-based testing library,
in the style of
[Hypothesis](https://github.com/HypothesisWorks/hypothesis/tree/master/hypothesis-python),
[QuickCheck (Haskell)](https://www.cs.tufts.edu/~nr/cs257/archive/john-hughes/quick.pdf),
[QuickCheck (Racket)](https://docs.racket-lang.org/quickcheck/index.html),
[rackcheck (Racket)](https://docs.racket-lang.org/rackcheck/index.html),
[guile-quickcheck (Guile)](https://ngyro.com/software/guile-quickcheck.html),
[test-generative (Chicken)](https://wiki.call-cc.org/eggref/5/test-generative),
[check-it (Common Lisp)](https://github.com/DalekBaldwin/check-it)...

Other type descriptors
[GNU Poke](http://www.jemarch.net/poke)

## Implementation history

Historical alignment, scenario and performance notes are preserved in
[implementation-history.md](implementation-history.md). They do not override
the functional completion ledger above.

Direct combined-generic transport now reuses the core formal projection and
standard list/apply lowering, removing the temporary per-call variadic relay.
Current metadata, boundary order, full Reader/C3 retry and paired cost controls
are documented in [gerbil-mechanisms.md](gerbil-mechanisms.md). This bounded
bridge replacement does not close the general extensible-MOP TODO.

### Current contribution-admission cost study

Default method contributions may reuse revision-checked constructor admission via
Gerbil weak-key tables; current interpreters, Type edits, reflection and callbacks
retain their existing semantics. The complete-chain reuse, mutation controls and
explicit proof premises are recorded in `gerbil-mechanisms.md`. The paired study
now compares the same current FUN/generic implementation with and without that
evidence, including cold registration/family construction. This cost study does
not close any of the open feature rows above.

### Persistent collection validation acceptance

`methods.table` now separates carrier-only `.validate-shape`, non-normalizing
membership and recursive binding normalization. RationalDict, Trie and derived sets
share `validate-bindings` with Map; every normalized key/value is retained and
backend-policy collisions refuse. Value=Any never skips Key admission. Child
failures precede reconstruction; builder/collision/postcondition failures retain
their actual order and never expose a partial table. Source persistence and
snapshot/rebuild fidelity are explicit obligations; arbitrary IO is not rolled back.
The nested ledger example connects FUN, schema refinement and checked callbacks
to IO without revalidating the normalized ledger. The corresponding Lean table
laws and executable tests close this concrete validation protocol, not the general
incremental/isomorphism-aware collection library. See object-contracts.md.
