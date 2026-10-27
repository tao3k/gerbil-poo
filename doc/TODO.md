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
| Data representation / usual object optimizations | Implemented protocol: persistent ordered prototype maps, shared symbolic shapes, opt-in receiver-local vectors and guarded inline sites integrated into object reads/writes and descendant invalidation | Concrete protocol closed; full hash removal, Patricia layouts and automatic JIT/PIC policy remain optimization work. See [representation.md](representation.md). Historical speed measurements do not close these. |
| Positional parameter specialization | Implemented: `parameters.ss` validates `.parameters` and performs persistent prefix binding with `.cc`; partial/full closure, malformed/excess refusal and checked FUN consumption tested | Explicit positional API closed with 13 Lean semantic laws. Specialization does not implicitly run hooks/effects or perform type inference. See [parameters.md](parameters.md). |
| Type system for POO | Executable Type descriptors, structural contracts and guarded publication; Function optional/keyword/rest and ordered CaseFunction signatures implemented | Finite rank-one Self/Super schemes, explicit subtype bounds, structural Function variance and finite-candidate inference implemented in `types/relation.ss` / `prototype-types.ss`. Controlled guarded Mu approximants, open/closed Object rows, disjoint row substitution and finite row inference are implemented; see [row-types.md](row-types.md). Higher ranks, arbitrary predicates/unrestricted recursive/row/effect inference remain open; recognition alone does not prove host arity. See [prototype-types.md](prototype-types.md). |
| Generic data structure library | Shared finite validation, explicit revisions/isomorphisms, aggregates, indexes, projections and five-style publication have concrete implementations; constructor delegation preserves independently partial empty/singleton/bulk operations. Set admission now shares Table's dynamic receiver/snapshot reentry guard. See the [source-grounded composition audit](collection-composition-audit.md). | General automatic discovery remains open. Recognition reuse requires explicit refinement/purity evidence; finite reentry detection does not establish arbitrary callback termination. |
| Type-driven property-based testing | Implemented finite protocol: descriptor samplers, products, seeded replay, strict-domain bounded shrinking and stale-source refusal | Derived scalar leaves, guarded recursive List/Tuple/Pair/Union/Maybe/OrFalse graphs and Function call rows; explicit generators for other/refined Types and Function values. Automatic guarded recursive generators are implemented; unrestricted recursive carriers and universal verification remain open. See [recursive-generators.md](recursive-generators.md). See [generated-testing.md](generated-testing.md). |
| Jsonnet/Nix implementation | Open, separate interpreter-scale future work | No interpreter or equivalence claim is supplied by current object examples. |

### Global acceptance audit: compact prototype representation

The next concrete acceptance unit after the finite type protocol is the explicit
small-map representation item under Data representation. It is implemented in
the EXISTING prototype-map protocol: explicit compact-policy vectors through eight contributions (default: tree),
standard RBTree promotion, deletion/demotion, ordered duplicate contributions,
owned snapshots and unchanged object invalidation/FUN admission. Universal Lean
revision-trace/policy-preservation and compact source-operation bounds accompany the independent
96-revision oracle and complete service workflow. See [representation.md](representation.md).

This closes that concrete representation subitem, not the whole original TODO.
Full-vector/hash removal and measured strategy qualification remain optimization
work. The proposed general incremental/isomorphism-aware collection library remains
partial, with concrete supported units and open acceptance targets tracked below.
The Jsonnet/Nix interpreter remains a separate unimplemented project.
Alternative-order certification, unrestricted inference, arbitrary adapter laws
and unrestricted recursive metalevel closure retain their stated research bounds;
they are not being relabeled as reproducible bugs or closed by this work unit.

### P2 retained bindings through source refresh and construction

A residual schema's earlier Type parameter could be replaced during a later
`.parameters` getter, while its remaining names stayed unchanged. Pure construction
returned `(Pair (List UInt) Bool)` with actual T=Bool; immediate bound inspection
then rejected that already-returned instance. A direct revision edit to the retained
composite descriptor exposed the same omission.

One private `with-checked-bindings` continuation now reuses existing identity and
revision admission around the whole consumer, followed by its callback-free final
revision fence. Schema preparation, actual positional binding and public bound
inspection share it. No getter runs after the fence; no second grammar walk or
new constructor is introduced. Supported slot-definition changes and direct Type
revisions refuse bounds before a successful result escapes. Original failures
keep their cause and prior effects; repair/retry never lowers a revision stamp.

Nine typed entry paths cover each relevant parameter-read phase for retained
identity and revision changes, with no early builder. A higher-order residual
service retains an Input Function, infers its Output Function and returns a
converter producing another checked Function. Fresh reconstruction, policy
refusal, recursive wrapping and exact evidence publication use the existing
qualified declarations/refine/FUN/IO chain.

Parameters.specializeCurrent composes existing retained-binding and checked-name
models. Its five laws prove stale/order refusal, reuse, exact new fields/suffix
and preservation of every disjoint retained identity/revision, plus original
inspection errors. The existing prepareDeclaredSignature laws supply the enclosing
before/after-callback admission; no parallel effect model is added. Faithful host
snapshots and revision propagation for supported edits are premises. Arbitrary
raw/concurrent mutation, transitive callback discovery and compiler correctness
remain outside this finite future-work protocol. Full checks and resource limits
remain unchanged.

### P2 coherent Type parameter binding

A source `.parameters` list could change order after schema admission but before
ordinary positional specialization read it again. Pure instantiation then returned
`(Pair UInt Bool)` with actual fields T=Bool and U=UInt. Prefix and inferred
assembly now share `bind-type-parameters`, which compares the original variable
order with the SAME name snapshot consumed by the existing positional binder.
Reordered/added/removed valid names refuse `bounds` before cloning. No second
getter follows admission; generic `specialize` also uses this single implementation.
Gerbil's multi-binding `using` handles the new continuation's ordinary contracts;
standard take/drop and existing persistent `.cc` still own construction.

Eight typed entry paths and three metadata changes exercise the complete boundary.
A generic control edits the source after snapshot admission and proves construction
still uses that snapshot. Original getter/admission failures retain their cause.
Repair through the supported slot protocol permits an independent request; the
shared signature-service action then composes prefix specialization, inference,
qualified declarations, recursive Function wrapping, refine and exact evidence/FUN/IO
publication. Nonunique reports remain explicit application errors, not guessed Types.

Lean's existing Parameters namespace proves original order, exact residual suffix,
field mapping, excessive-argument refusal and incremental composition. The generic
positional model's `declaration` refusal represents the typed host's `bounds` gate;
source errors are transported separately. Host snapshot/admission/descriptor
interpretation are premises, not compiler/heap/concurrent-mutation proofs. This
advances the finite type future work without extending its research boundary.

### P2 original field selection during signature preparation

A computed parameter getter could rewrite a caller-owned Object method path
before `instance-signature` selected its Function. A different valid sibling
therefore supplied the descriptor and private origin stamp. Signature preparation
now admits and copies the complete finite symbolic path before any instance or
binding getter. Selection and provenance use the same owned path; later requests
observe subsequent buffer edits. Shared Function path admission replaces the two
walkers' duplicate checks. Cycles, malformed paths and exhausted requests refuse
before source effects; getter errors retain their original cause. Negative-watch
payload immutability/purity remains the existing dispatch precondition.

The nested run/audit example combines candidate inference, whole declaration
admission, returned Function wrapping, refinement and exact evidence publication
through FUN/IO, including approval/policy refusal and retry. Lean proves capture
and refresh failure order and successful selection at the original path, under
faithful host capture/refresh/compiler interpretation. This advances finite type
future work; it proves neither arbitrary mutation/rollback nor Scheme compilation.

### P2 joint final-source admission

Closed a success-time omission: a final computed parameter getter could change
the instance expression after it had been compared, yet signature preparation
still returned a certificate. A later binding getter could also invalidate an
earlier descriptor after its individual check. Binding inspection now composes
its consumer with one shared final direct-revision/metadata fence. Signature
preparation performs no source getter after that joint gate, and whole nested
catalog walking is its consumer: one admission surrounds all catalog getters,
followed by pure postconditions without another grammar/Type validation pass.
Required compiled signature origins receive their joint pure revision check too.
Raw pair metadata receives a final held-value comparison; supported edits reuse
the existing object revision protocol. Original callback failures retain their
cause, effects are not rolled back, and all visits retain the request quota.
Staged finalization, nested catalogs, fresh inference, recursive Function wrapping
and refine/bind-evidence/FUN publication have integrated regression controls.
Lean reuses existing source and binding gates with explicit post-getter source
interpretation premises. Arbitrary transitive callback stability remains outside
this finite future-work protocol; no whole read-dependency closure is traversed.

### P2 complete request capture before source refresh

Closed the complementary request-input omission: computed parameter getters
could replace caller-owned candidates, raw constraints, call observations or
explicit/prefix Type arguments before those inputs were copied. The four shared
checked entry paths now capture their finite input spines before touching the
schema. One existing bounded copier serves schema and request preparation;
candidate canonicalization and raw/call admission reuse the owned rows instead
of cloning them again. Pure and unified declared APIs retain the original finite
universe, constraints, call metadata and Type identities through publication.
Cycles/exhaustion refuse before getters/builders; later requests see new buffers.
The observed descriptor-call example composes recursive wrapping, declaration,
refine/bind-evidence/FUN/IO and refusal/retry. Lean proves original-universe
membership and original constraints under faithful host capture/projection;
arbitrary concurrent raw mutation, callback purity and rollback remain outside
this finite future-work protocol. See finite-inference-audit.md.

### P2 schema capture before computed metadata

Closed a preparation-order omission: computed `.parameters` could modify the
caller's variables, expression and bounds before they were copied, including
weakening `Self <: Super` into `Self <: Self`. One shared preparation gate now
bounds and owns all four syntax/binding spines before any getter or Type
admission. Initial schemas, residual prefixes, explicit instances and both
inference paths use that same captured data. Complete qualified declaration,
refine/bind-evidence/FUN publication and failure/retry controls remain under the
existing protocols. This advances the article's finite type-system future work;
it does not establish arbitrary callback purity or rollback. See
method-declarations.md for the capture/host correspondence boundary.

### P2 constructor-owned Function declarations

Closed an executable call-language omission: Function construction retained
caller-owned rows/keyword pairs, including the required-key list borrowed by
expression-type. Reusing that list could weaken an already wrapped function's
required-key gate without changing its descriptor revision. Function now captures
all declaration list topology before admission; CaseFunction owns its ordered
clause spine. Existing Type identities, host defaults, structural selection,
wrapping, causes and result/cache transport remain under the same mechanisms.
Finite catalog/inference/refinement/evidence publication, supported invalidation
and fresh reconstruction have integrated controls. Public Type edits and arbitrary
callback stability are still governed by the existing source protocol. See
method-declarations.md for the conditional Lean and heap-copy boundary.

### P2 request-owned constraint evidence

Closed a raw-query ownership omission: mutating or reusing the caller's query
buffer could rewrite a completed report and every alternative's inequalities.
Raw queries now receive one admitted finite snapshot before search; the solver,
classification and diagnostics use that same snapshot. The call-observation path
reuses its already owned constraints without another copying/validation pass.
Unique, ambiguous and no-solution reports, declaration callbacks and later FUN
requests retain their original evidence. Public report editing remains allowed;
this is request ownership, not permanent authentication of mutable metadata.
`signature-request-action` reuses existing prefix binding, declaration factories
and Reader/FUN composition; tests continue into refine/bind-evidence publication.
See prototype-types.md and finite-inference-audit.md for conditional proof scope.

### P2 signature preparation source admission

Closed a real phase gap: standalone `instance-signature` accepted a stale bound
instance that `bound-parameters` and whole declaration publication rejected.
Signature preparation and final installation now share one source gate for
current syntax, captured binding metadata, descriptor identity/revision and closed
positional parameters. Successful negative-call callbacks are checked again;
original callback errors remain unchanged and failed preparations publish nothing.
Observed conversion declarations reuse the existing qualified stream and FUN
workflow. This advances the article's finite type-system future work; arbitrary
callback termination, transitive semantic stability and principal inference remain
outside the proved scope. See method-declarations.md for the proof boundary.

### P2 tagged-object carrier acceptance

CLOSED for Sum-to-open-Object/Record readable interfaces through the shared row
protocol. Every original variant supplies its exact symbol tag and payload under
the same quota. Closed targets, unknown optional extras, reverse replacement and
codec/index casts remain refused; direct Sum/Union/Map-key identities remain.
Complete tagged worker inference, prefix binding, qualified declarations and
FUN/refine/evidence publication are covered by container-inference-test.ss.
row-types.md states the literal-tag/child interpretation and normalized payload
proof boundary. This closes the finite carrier omission, not the full type TODO.

### P2 callable source alternatives

CLOSED within the finite relation: Function/CaseFunction targets now participate
in the common all-original-branch source-Union rule. This fixes nested callback
containers through inference, prefix specialization and unified declarations,
without another dispatch or wrapping implementation. Existing rich signature
coverage, keyword origins, ordered case selection, exact result counts and shared
quotas remain authoritative. Complete callback-directory publication and refusal/
retry controls are in union-inference-test.ss; prototype-types.md states the
conditional Lean proof scope. Direct Union/Map keys and opaque target bounds are
unchanged; empty alternatives do not create runtime procedures. This advances
the article's future work and does not close the unrestricted type-system TODO.

### P2 finite data source alternatives

One shared source-Union judgment now includes optional, dependent and tagged
views alongside the previous ordinary containers and flat views. Every original
branch must meet the same complete target; sentinel and empty-carrier evidence
reuse existing rules. Direct Union identity, opaque targets, Sum tag
skeletons, keyword/escape transport and distinct failure categories remain.
The availability factory composes all these views with complete inference, prefix
specialization, declarations and FUN/refine/evidence publication. Lean success
extraction and existing optional/catalog laws prove actual normalized membership
and carried-token identity, without a raw-identity assumption. This closes the
finite-data protocol omission, not arbitrary predicate or unrestricted inference.

### P2 container source alternatives

Ordered source Union candidates now cover one ordinary readable container only
when every original branch satisfies that same target's existing carrier and
child rules. List/Tuple/Pair/Map/Record/Object compose with inference, prefix
specialization and qualified declarations, including nested Function wrappers.
Direct Union identity and opaque-target bounds remain unchanged; callable
targets use the shared rule described above.
The worked worker factory reuses FUN/refine/bind-evidence and preserves selected
branch failure, source syntax, ambiguity and approval retry. Lean proves both
branch derivability and coverage of actual normalized results without a raw-value
identity assumption. See prototype-types.md and union-inference-test.ss.

### P2 necessarily empty Map acceptance

A positive finite empty key or value witness now admits readable replacement by
another Map layout through the shared relation, complete inference, prefix
specialization and qualified declarations. Possible entries still require
invariant keys and covariant values. The Map itself remains inhabited by an
empty hash table; nested empty Maps and optional sentinels cannot prove an
outer component empty. Existing wrappers, hash policy, failure categories,
FUN/refine/evidence publication and complete checks remain in force.
See prototype-types.md and container-inference-test.ss for scope and controls.

### P2 empty dependent directory acceptance

The zero-entry `(TypeValuePair)` directory now feeds the shared positive empty-Type
witness, rather than a parallel inference rule. Mandatory products/rows, singleton
List carriers and necessarily absent optional fields inherit it. Nonempty catalogs
remain opaque even when a recognizer always returns false. Empty List/Map values
and Maybe/OrFalse sentinels are inhabited and remain distinct from empty Types.
`infer-plugin-service` exercises finite inference, specialization, qualified
declarations and the existing FUN/refine/bind-evidence publication chain with
active Function plugins, retired metadata, ambiguity, retry and stale-source refusal.
This closes this finite P2 omission, not the unrestricted type-system TODO.

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
| Representation optimization | Qualify full-vector/JIT policies after the integrated persistent mapping, guarded shape/index and supported-invalidation protocol | Protocol: `prototype-map.ss` / `slot-layout.ss` / `object.ss`; [representation.md](representation.md) |
| Types and generated tests | Closed: optional/keyword/rest/case-lambda Function signatures; finite descriptor generators, bounded shrinking and replay. Closed: automatic guarded recursive container graphs, bounded generation/membership/shrinking and source-bound replay. Closed within the explicit finite algebra: rank-one prototype polymorphism, structural subtyping and budgeted complete candidate inference. Closed within bounds: guarded Mu expansion via safe recursion, observational Object field replacement and finite disjoint row inference. Open: unrestricted/higher-rank/recursive/row/effect inference and unrestricted recursive carrier generation; see [prototype-types.md](prototype-types.md) | Type-system/Property-based testing below; `type.ss` / `object-contract.ss` |
| Collection protocol | Constructor delegation is closed across derived collections and five styles. Direct Set observation now shares complete admission and guarded delayed pulls; conditional recognition reuse still requires independent refinement/purity evidence. General automatic discovery remains a separate research goal. | [Composition audit](collection-composition-audit.md); Generic Data Structure Library below |
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

The acceptance unit is the complete **finite declaration/type protocol**, not
one new container example per iteration. The following families consolidate the
previous P0/P1/P2 findings; their detailed derivations and negative controls remain
in [finite-inference-audit.md](finite-inference-audit.md), [prototype-types.md](prototype-types.md),
[row-types.md](row-types.md) and the existing regression modules.

| Priority / family | Implemented acceptance | Explicit remaining boundary |
| --- | --- | --- |
| P0: one complete declaration | Call observations derive original input/output inequalities; all named generics share one candidate assignment and one whole builder. Missing siblings or changed signatures refuse admission. | No implicit method discovery or independent per-sibling solve. |
| P1: request quota / final admission | All three declared entry points share one existing work counter from binding/inference through captured sources, live bindings, signature forcing and final admission. Compiled Map/Record children are captured before lazy fields, preventing runtime counter reuse. Exact-boundary, late-refusal, independent nested request and retry controls cover complete metadata/FUN/refine/evidence publication. | Counts protocol-owned visits; callback/descriptor factory execution and GC remain under existing process limits. Independent public requests retain independent quotas. |
| P1: ownership / diagnostics | Direct descriptor revisions invalidate declaration ownership; captured queries, alternatives and source syntax retain their provenance. | Transitive callback semantics need explicit dependencies; public metadata is not a permanent certificate. |
| P2: whole-request directory admission | Grammar, compilation, finite inference, specialization and declaration share one success-only source fence, including unused candidates and negative/nonunique results. Independent directory edits, builder mutation, original exceptions, nested public requests and FUN/refine/evidence retry have controls. | Finite recorded sources, faithful snapshots and supported sequential mutation; no arbitrary callback discovery, rollback or concurrent heap theorem. |
| P2: retained catalog binding sources | Compiled directory Types register authenticated read owners in the existing weak dependency graph. Source, unused-member, explicit-root and Class-Slot revisions reach retained prefix stamps even when absent from residual syntax; nine entry paths, shared-path once-only invalidation, unaffected sources and pending publication/recapture have controls. | Only known captured sources are registered. Supported sequential mutation and faithful graph registration remain premises; arbitrary callback discovery and GC behavior are not inferred. |
| P2: public Type request ownership | All operands of expression-type, subtype-expression? and function-covers? are captured before live directory admission. The original recursive compiler/relation, shared quota, nested wrappers and declaration/refine/evidence composition remain authoritative; both operand directions, shape edits, erased-invalid-sibling attempts and retry have controls. | Existing internal inference owns its syntax. Callback effects remain observable; faithful copying/host Type interpretation are proof premises, not arbitrary heap or callback guarantees. |
| P2: shared metadata transformation | Substitution, canonicalization and normalization share types/syntax.ss child traversal. Ordinary transforms retain literal names, Function option order, Map arrow spelling and Mu scope; canonicalization alone normalizes spelling. The 39-template directory compares identity, staged/full substitution, canonical idempotence, direct/staged assembly and complete residual inference. | Ground substitutions only; no unrestricted binder rewrites, callback execution or semantic equivalence inferred from metadata. |
| P2: intrinsic descriptors / catalogs | Null/Unit, literal-width numbers/bytes and aliases, scalar/Enum/range coverage and finite named TypeValuePair directories use shared intrinsic and interval judgments. Captured Class/Schema tokens retain identity, source replay and guarded validators. | Dynamic widths, mutable literal semantics, arbitrary descriptor discovery and opaque structural implication remain unsupported. |
| P2: intrinsic numeric families | Existing Number/Real/Rational/Float and literal positive Z/ descriptors now share the syntax registry, recursive compiler and numeric relation. Intrinsic predicates supply exact membership; integer ranges/widths embed into Real/Number, and Float embeds into Real/Number without coercion. Real joint Rational/Float coverage retains exceptional flonums; Z/ reuses bounded metadata admission and interval/Enum/Union inclusion without normalization. Full rational/residue and real-relay declarations retain Map keys, nested callbacks, keyword/case coverage and FUN/refine/evidence retry. | No ancestry-derived subtyping, numeric conversion by inference, floating literal metadata, complement coverage or arithmetic correctness theorem. See scalar-coverage.md. |
| P2: containers / rows / alternatives | Pair/List carrier laws keep vector/nil distinct; positive emptiness handles impossible products/rows, singleton Lists, absent optional fields and necessarily empty Maps. Record/Object readable views, Sum tag/value views, optional sentinel/payload coverage, source Union/Or branch obligations and recursive wrappers reuse existing protocols. | Inhabited empty collections/sentinels are not empty Types. Direct ordered alternatives, inhabited Map keys, closed-row presence, codecs and mutable writes retain their documented restrictions. |
| P2: uninhabited call rows | Existing finite emptiness witnesses discharge only supplied inputs of the original selected target clause; live cells retain shape, input/result variance and exact counts. Nested handler/refresh declarations share one assignment through prefix specialization and FUN/refine/evidence; first-case, presence, refusal and retry have controls. | Public shape-only coverage is unchanged. Omitted defaults, inhabited containers/sentinels and unknown predicates do not qualify. No new host-arity, totality or unrestricted emptiness inference. |
| P2: complete call languages | Candidate signatures/fields decide finite layouts before constraints; same-mode case coverage retains first selection, optional/rest/key partitions and exact return counts. Supported cross-mode raw coverage retains value-sensitive Keyword/Exactly/Enum origins, intrinsic Or/Maybe/OrFalse views, correlated infinite tails and complete graph certificates. | Opaque/wrapping ordinary refinements outside the admitted view, effectful defaults/recognizers and unrestricted recursive/higher-rank language inclusion remain outside the decidable rules. |
| Integration: one publication chain | MetadataServiceType combines partial specialization, a disjoint row, Pair/List/Map, optional tagged tuples and nested callbacks through the existing qualified declarations, catalog FUN/refine/bind-evidence action, exact context and refusal/retry. Other family controls remain registered and run in full. | Runtime tests establish executable correspondence; Lean laws require the stated host leaf/decoder/row/binder interpretation. |
| Outside the current decidable boundary | Principal/higher-rank/effect inference, arbitrary predicate implication/emptiness, unrestricted recursion and transitive callback semantic discovery remain OPEN. | These are explicit research boundaries, not regressions to repair with Any. |

Lean proves structural substitution composition and identity, complete bound/query
specialization, row-label/splice preservation and transformation of finite recursive
approximants under explicit bottom/body laws. Original declaration provenance is
retained by complete unique publication. The directory is finite executable
acceptance, not a universal proof of all host Types or completion of every TODO.
Existing checks, resource limits and the full single-process regression suite are
required for this work unit; focused matrix success alone does not close it.

### Whole observation admission and declaration continuation

The concentrated P2 audit found a phase inconsistency: fixed signatures could
reject an early call shape before a later sibling's malformed/unsupported Type
metadata was admitted; candidate-dependent signatures preflighted that metadata.
Both now snapshot and preflight the complete batch through the existing
`signature.decode-arguments` and `type-expression` before projecting any queries.
Projection reuses those checked payloads under the same work counter; undecoded
wire tokens still refuse in the selected signature's interpretation mode.

`infer-declared` and `infer-declared-calls` share one private higher-order
continuation for unique-instance declaration. No builder runs on malformed input,
exhaustion, ambiguity or no-solution. Known impossible shapes still refuse bounds;
a well-formed incompatible candidate still contributes no solution. This closes
an admission inconsistency, without extending the finite inference boundary.

The shared report/recovery example binds Self, jointly infers Super from optional,
keyword/rest and ordered case observations, retains a recursively wrapped return
callback, and invokes both declared generics through the existing FUN approval
and IO consumer. Regression controls cover empty universes, late bad metadata,
failure-before-builder, first-error order, exhausted budgets and fresh retry.
Lean proves complete observation admission, late-refusal propagation and exact
projection preservation, composed with the existing declaration driver. Host
keyword decoding/Type checks remain interpretation premises, not verified parser
or compiler claims. Existing full checks and resource limits remain required.

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

**Complete default Table observation** now closes whole-root admission and
cursor invalidation across RationalDict, Trie, generic tables and the existing
represented/ordered/indexed views. Backend `.list/key` and `.iter/key` retain
standard materialization/traversal; public `.list<-` and `.iter<-` own complete
receiver recognition. A shared guarded Iterator checks source/child/origin stamps
before each delayed default pull, including EOF, without rescanning per element.
Derived cursors intentionally retain their admitted-snapshot, lazy per-row
conversion contract and original guard failures; full receiver recognition must
not force those conversions or destroy positioned traversal. Reader/FUN/IO
covers no-order-assumption observation, all five styles, Function identity,
refusal and fresh retry. Lean shares Table observation/issuance with Set and
reuses existing pull laws. Full admission costs and backend laws remain explicit;
see [table-representations.md](table-representations.md).

**Representation request/result capture** now closes a separate Wrapper boundary:
seek owns its Option bound before carrier/inverse callbacks, and one shared
entry translator receives both original children before key conversion. Iteration,
seek and bulk construction reuse that translator; key conversion cannot rewrite
or repair an original payload through a reused producer Pair. Existing guards,
encountered inverse checks, conversion order and Function identity remain intact.
The positioned-ledger Reader/FUN/IO example exercises late refusal and fresh
retry through a represented source. Finite Lean laws reuse cursor translation and
bound capture, not a second engine; mutable leaf internals, host fidelity and
effect rollback remain outside the claim. See [table-representations.md](table-representations.md).

**Ordered producer row capture** closes validation-before-selection in the
existing checked cursor. Each emitted Pair shell is captured and recursively
recognized before lower-bound comparison, including rows that would be filtered
out. Reused buffers and comparator effects cannot rewrite accepted bindings or
repair invalid originals. The same cursor, comparer and metadata guard remain;
Function payloads retain identity. Reader/FUN/IO covers late refusal and fresh
retry. Finite Lean laws separate admission failure, filtering, selection failure
and original-entry delivery; arbitrary mutable leaf contents and producer order
remain declared premises. See [table-order.md](table-order.md).

**Direct Set observation** now closes the admission and invalidation bypass in
`.iter<-` and RationalSet's raw `.list<-` override. List observation inherits the
existing Set boundary. Cursor issuance admits the complete root once and retains
Set/Elt/backend/policy stamps; the existing mapped Iterator checks them before
every pull, including repeated EOF. It does not rescan the root per element or
introduce another Iterator class. Reader/FUN/IO examples cover whole-root refusal,
opaque Function grants, invalidation and fresh retry. Finite Lean laws cover
issuance refusal/order and zero backend pulls after invalidation; host dispatch,
persistent carriers and arbitrary callback behavior remain explicit premises.

**Constructor delegation implemented:** [the composition audit](collection-composition-audit.md#constructor-delegation-acceptance) records the complete repair across Set, order, representation, indexes and all five styles. Empty, singleton and bulk retain independent refusal domains. Shared Wrapper admission, complete-root refinement and metadata guards remain in place. The same audit separates measured repeated recognition from any proven safe optimization, and distinguishes the original paper from later author proposals.

**Incremental view composition** now closes the missing chain between
existing projection, joint join and grouped-aggregate caches. `table-projection-compose`
requires an identical declared middle descriptor and delivers its exact delta,
without snapshot `.diff` or repeated wrapping. Both immutable successors remain
private until the whole chain accepts; stale/foreign caches, no-op origin
invalidation, downstream collision/refusal, batch coalescing, inverse recovery,
explicit retry and five-style Reader/FUN/IO publication have integrated controls.
Lookup/group joins retain one `.apply-deltas` admission through nested chains:
both source requests must accept before downstream maintenance and one final
publication. Shared policy revisions, many-to-many migration, source conflicts,
downstream failure, retained Function identity and inverse recovery have controls.
See [table-mapping.md](table-mapping.md) for admission costs and the conditional
Lean connection/invariant laws and semantic reassociation. Arbitrary view discovery,
distributed source synchronization and destructive/effect rollback remain outside
this explicit persistent revision protocol.

**Checked predicate observation** now closes the query family across Table, Set,
five styles and Gerbil receivers: first/last optional or required search and
any/every share strict Boolean short-circuit traversal, complete input admission
and nonconsuming snapshot observation. The Trie key-only monotone override is
removed from the general two-argument protocol. Recognition uses the raw internal
traversal to avoid recursive query admission. Nonmonotone finite masks, invalid
tails, false elements, Function identities, failure/retry and Reader/FUN/IO have
regressions and Lean source/short-circuit/admission/ownership/work-bound laws.
See [table-selection.md](table-selection.md) for declared order, full admission
costs and backend premises; automatic predicate/algorithm discovery remains a
research boundary.

**Finite Iterable import** now closes seedless/seeded `.<-iter` across Table,
Set, all five styles and receivers. An explicit backend key registry captures every
admitted row, coalesces last writes and feeds one bulk constructor or final-state
delta installer, including unique-index swaps without seed listing or `.diff`.
Malformed/late failures, shared Pair shells, Function retention, reentrant winners,
complete refinements, inverse recovery and fresh-stream retry have regressions and
Lean finite stream/delta/admission/ownership laws. See [table-batches.md](table-batches.md)
for capability, finite-input and consumed-progress boundaries; arbitrary streams
and automatic equality/algorithm discovery are not claimed complete.

**Ordered whole-collection comparison** now closes the explicit-order protocol
across Trie paired traversal, generic order/representation views, Set, all five
styles and receivers. Existing union-key absence-before-presence semantics and
explicit Integer value comparison share complete root admission and origin guards,
without constructing a merged carrier. Finite exhaustive oracles, shared producer
shells, short-circuit demand, nonempty refinements, Function identity and
Reader/FUN/IO/revision retry have regressions and Lean comparison/transport/failure/
work-bound laws. See [table-order.md](table-order.md) for caller ordering/backend
premises and charged costs. Unordered data, automatic comparator discovery and
joint atomic reads are not silently claimed supported.

**Logical emptiness observations** now close public Table/Set `.empty?`, all five
styles and receivers without comparing an empty constructor's identity. Complete
admission and strict Boolean decisions surround existing structural predicates;
Trie/internal bucket construction retains its private nonrecursive path. Indexed
empty construction is deferred with an existing computed slot. Partial refinements,
group migration/undo, Function identity and FUN/IO retry have integrated controls
and finite Lean zero-cardinality/refusal/ownership laws. See
[table-selection.md](table-selection.md). Primitive counts, backend shape laws and
arbitrary refinement termination remain explicit boundaries.

**Checked endpoint observations** now close required/optional Table min/max/choice
and Set element min/max/choice through the existing query kernel and all five
styles/receivers. Complete admission, false-versus-absence, empty refusal,
nonconsuming ownership, Function identity, represented/indexed partial refinements
and FUN/IO retry have integrated controls and finite Lean laws. Set optional choice
uses `.choose/opt` with no legacy alias; see [table-selection.md](table-selection.md).
Traversal/order laws remain explicit; unordered backends do not infer numeric extrema.

**Complete collection IO** now closes Table/Set JSON, bytes and port operations
under one metadata/admission boundary, retaining List/Pair wire formats and
complete constructors. Five styles share nonconsuming encoders and fresh decoders;
Gerbil receiver observations, represented/indexed refinements, explicit finite
Function handle codecs and FUN/IO failure retry have integrated controls. Lean
proves refusal order, conditional roundtrip and retained port effects. See
[collections.md](collections.md). Parser correctness, automatic closure encoding
and port rollback are explicit boundaries, not inferred guarantees.

**Checked whole-collection equality** now places RationalDict/Trie structural
algorithms behind the existing common root/metadata boundary, with strict Boolean
leaf/result decisions. Five Table styles and Gerbil receivers share nonconsuming
relation reads; Set equality retains its existing semantics. Refusal/retry, invalid
identity shortcuts, represented/indexed refinements, Function identity and FUN/IO
have integrated controls and finite Lean soundness/completeness/work laws. See
[table-merge.md](table-merge.md). Backend/equality laws and stable leaves remain
premises; joint atomic reads and inferred Function equality are not claimed.

**Checked optional association** now closes the existing `.acons/opt` protocol
through the shared captured modifier, exact point delta and all five Table styles
and Gerbil receivers. The redundant unchecked Trie `.update/opt` zipper override
is removed in favor of the same common update protocol and existing backend writes.
Absent requests retain the binding but cannot skip key/root/
metadata admission; present false values remain distinct. Function identity,
mutable Option capture, indexed/refinement refusal, reentrant winners and FUN/IO
retry/inverse have integrated regressions and finite Lean laws. See
[table-focus.md](table-focus.md). Empty requests retain ordinary no-op delta
semantics; no destructive ownership or callback-termination guarantee is inferred.

**Checked list/singleton construction** now closes direct Table construction and
fresh five-style factories through one boundary: proper-list/Pair capture before
child recognition, every occurrence checked before a backend call, and complete
root admission after the existing bulk or Trie singleton strategy. Order,
representation, indexes and Set retain their own constraints and Function leaves.
Backend duplicate precedence remains unchanged; raw normalization is separate.
Modular constructor regressions, Reader/FUN/IO retry and Lean admission/observation/
row-work laws are documented in [collections.md](collections.md). Backend/persistent
laws and physical capture remain explicit premises, not automatic discovery claims.

On top of Gerbil-POO, build an
[Efficient, Incremental, Generic, Isomorphism-aware, Correct Data Structures](https://github.com/fare/projects/issues/10)

The first concrete unit is implemented: `methods.table` finite persistent deltas,
old-value conflict checking, inverse installation and lookup-preserving transport
between existing RationalDict/Trie carriers with identical Key/Value descriptors.
Optional-key lenses compose with existing service lenses; admitted nested Function
wrappers are retained without repeated wrapping during installation. Gerbil
regressions include 48 mixed revisions, late conflict, rebase/retry and FUN IO
consumption. See [collections.md](collections.md) for admission preconditions,
metadata invalidation, the changed-key (not global snapshot/ABA) conflict boundary
and the companion Lean completeness/inverse/frame/transport/lens proofs.

**Finite set algebra** is now closed over the existing Unit-valued table
presentation: union/intersection/difference/symmetric difference, subset,
disjointness and extensional equality share complete admission and origin guards.
The existing Trie subset specialization remains, with admission before shortcuts.
Boolean membership lenses now follow the same value-before-state convention as
service lenses. Set policy revisions reuse ordinary table deltas, cross-backend
installation, styles, inverse recovery and Reader/IO. The implementation, 512-pair
independent oracle, failure/retry controls and Lean laws are documented in
[set-algebra.md](set-algebra.md). Explicit backend ordering remains a capability;
automatic comparison or destructive storage is not inferred.

**Set style derivation** now closes the element-level presentation gap:
`set-styles` reuses the exact table ownership/installation engine for all five
styles and 25 transfers. Membership/insertion, finite algebra and relations,
element Iterable/folds, explicit ordered queries and original table deltas compose
without exposing Unit pairs. Binary updates commit only the left owner; distinct
right owners are observed. Custom set recognition and declared set/table origins
are checked before installation and during deferred pulls. See
[set-algebra.md](set-algebra.md) for aliasing, failure/retry, examples and SetStyle
proofs. This does not introduce a static ownership checker or destructive backend.

**Finite traversal prefixes** now provide table/set `take` and `drop` in all five
styles, reusing one checked filter algorithm and the existing ownership installer.
Exact nonnegative counts, clamping, complete-result refinements, inverse recovery,
Function identity and stale/reentrant refusal are covered; full traversal and
recognition costs remain explicit. See [table-split.md](table-split.md).

**Checked selection and atomic partition** now close the dangling set
`.filter`/`.partition` declarations through `methods.table`, all five table/set
styles and Gerbil receivers. Complete branch admission precedes one ownership
installation; strict Boolean classification, late refusal/retry, wrapper retention
and stale-owner rejection share the existing guards. See [set-algebra.md](set-algebra.md)
for ownership, finite Lean laws, complexity and callback-effect boundaries.

**Typed key focuses** now complete required/optional table lenses and the
five-style point-update protocol. Required setters use value-before-state order;
optional writes reject invalid keys, payloads and Option shells. Lens modification
and composition retain one captured-generation update, preventing a reentrant
winner from being overwritten. See [table-focus.md](table-focus.md) for metadata,
Function preservation, partial-refinement boundaries and the Lean observation laws.

**Key-preserving bulk mapping** now supplies checked `.map/2` and
`.filter-map/2` over the original snapshot, with the same complete protocol across
five styles and receiver calls. Existing Trie traversal is reused; the generic
path submits one changed-binding delta, preserving final-state unique swaps even
through explicit representation Wrappers. Function identity, strict Option semantics,
late refusal/retry, reentrant winners and FUN/IO have integrated controls and
finite Lean laws. See [table-mapping.md](table-mapping.md) for callback order,
root refinements, ownership, declared backend premises and charged costs.

**Checked binary combination** now closes `.merge`, `.union`, `.join` and
`.join/list` through typed Option decisions, both original snapshots and five
styles. Existing Trie paired traversal is retained; the generic path installs one
final-state delta, including indexed swaps through representation Wrappers.
Batch joins retain their existing later-source priority without a fabricated empty seed;
generic equality observes roots instead of constructing a forbidden empty merge.
Alias shells, Function identity, metadata/owner refusal, reentrant winners,
constraint failure/retry and FUN/IO have integrated controls and Lean laws.
See [table-merge.md](table-merge.md) for effect order, partial refinements and costs.

**Ordered decomposition** now closes the existing table/set `.split` protocol:
explicit comparers, typed pivot Option/presence, original-snapshot side preparation,
correlated indexes and five ownership styles share the existing checked mapping
and multi-result installer. The erroneous Trie pivot/prefix recursion is removed.
Function preservation, late refusal/retry, reentrant winners and Reader/FUN/IO have
integrated regressions and finite Lean laws; see [table-split.md](table-split.md).
The fallback charges two traversals and full admission; no logarithmic split,
physical ownership or automatic comparator discovery is claimed.

Ordered multi-round revision batches are now a complete additional unit:
`.compose-deltas` retains all intermediate expectations and origin dependencies,
including empty origins, repeated keys and deletion/reinsertion. Ordinary
installation, inverse, typed isomorphism, fold and FUN share this same delta.
Endpoint-only transport and premature fold key-owner removal are corrected;
conflict/refusal suppresses aggregate projections and consumers. Universal finite
batch laws and integrated Scheme/Lean examples are described in
[table-batches.md](table-batches.md). This does not close the proposed general library.

Explicit representation-driven **algorithm derivation** is now implemented by
`table-wrapper`: one source backend plus typed carrier/key/value Wrappers supplies
a complete new `methods.table`, with FUN Wrap, guarded metadata, both traversal
orders, lenses, deltas, batches and incremental aggregates. A raw target only
recognizes its carrier and declares child Types; it need not implement a tree.
Sixteen Lean laws cover conjugated read/write/install, inverse and multi-stage
derivation, ordered folds and source guards. See
[table-representations.md](table-representations.md). This is explicit law-governed
derivation; explicit comparator transport and finite ranges are implemented below;
backend-specific seek requires explicit capability admission; bounded backend cost acceptance is documented in table-representations.md.
Arbitrary symmetry/optimization discovery is a research boundary. The concentrated
remaining-acceptance table is in table-representations.md.

Pure/mutable/linear **style derivation** now shares one admitted persistent backend
through `table-styles`: all nine conversions, nonconsuming snapshot reads, atomic
ordered batches, owned-reference transfer, generation conflict rejection and
explicit retry. `Wrapper` / Reader / IO retain the existing checked Functions;
normalization is separate from ownership transfer. See [table-styles.md](table-styles.md)
for failure, observation, concurrency and proof boundaries. Destructive backend
reuse and automatic ownership inference are not asserted.

**Posh/classy receiver derivation** is implemented through the same factory:
`Posh` attaches pure style and `Classy` attaches mutable style using Gerbil's
standard class-method dispatch. All 25 transfers preserve admitted roots and
Function wrappers; target construction precedes source retirement. Receiver-bound
point operations, reads, ordered batches, inverse recovery and Reader/IO share the
existing guarded installer. See [table-styles.md](table-styles.md) for the complete
protocol, failure semantics, examples and Lean observation/ownership laws. This
advances the collection proposal's future work; exclusive physical ownership,
destructive backend selection and automatic symmetry discovery remain explicit
research boundaries.

**Style observation** now retains the whole existing read protocol: standard
Gerbil Iterable/Iterator, both backend folds, explicit seek/range and correlated
index queries. All five styles share snapshot capture; deferred pulls retain
metadata checks through EOF even after ownership transfer. Missing backend
capabilities refuse explicitly rather than inventing order or scanning to restore
seek. The checked service example composes snapshot-bound FUN observation,
correlated ranges, wrapped Function invocation and Reader/IO. Finite cursor,
refusal and snapshot laws are in `TableObservation.lean`; detailed costs and
failure/retry boundaries are in [table-styles.md](table-styles.md).

Declarative correlated **indexes** now share one primary and atomic installation
protocol through `table-indexes`: typed unique-owner and grouped tables, multiple
backends, final-state uniqueness, ordered primary conflicts, inverse observations,
empty-delta origins and all existing table styles. See [table-indexes.md](table-indexes.md)
for explicit laws, equality/admission premises and cost boundaries.

Explicit **order and range queries** now compose with these indexes and all styles:
`table-comparer` captures a lawful comparer; `table-comparer-wrapper` transports it
through typed key isomorphisms; `table-order` derives ordered table methods and
`.index-range` delegates bounds to the declared backend. Complete queries reject
stale origins, malformed/reversed bounds, broken encountered inverses and invalid
signs. Functions retain identity through revision, conflict retry and inverse
recovery. See [table-order.md](table-order.md) for laws and the explicit finite
sort/filter cost. Explicit Trie positioning and its typed Wrapper transfer now remove full sorting
from matching-order warm queries, including correlated indexes and all styles.
First shape admission remains explicit; successful persistent roots use Gerbil
weak keys, and invalidated or failed admissions are not silently reused. The shared
paired study includes cold, seek, range and complete publication/undo phases.
Declared shape-preserving persistent point updates now reuse constructor output
admission, eliminating repeated whole-prefix shape checks in cold index building.
Undeclared backends retain full checks; metadata invalidation, typed Key checks,
exception retry and Function identity remain covered. The paired study separates
factory declarations, cold index preparation and complete construction and retains
reference A/A plus candidate B/B controls and GC history. This proves no universal
backend or GC bound; see table-order.md.
Shared Trie delta discovery now reuses ordered pair recursion after complete
admission, preserving the generic old-changes-then-inserts sequence, errors and
inverse installation. The original generic callback stream remains an oracle;
full publication has separate discovery/index/ownership/factory controls. See
table-order.md for the immutable backend/alignment laws and cost boundaries.
Finite multikey indexes are implemented below. Other backend-specific seek and
automatic query optimization remain separate work.



Here incremental also means sharing an algorithm layer between existing typeclass
implementations, as in the original proposal; data revision alone does not close
its automatic translation/symmetry goals. This closes this finite delta unit,
not the proposed general library. Explicit typed key/value Wrapper isomorphisms
now lift to collection and paired-base delta conversion. The same target-backend
registry covers both snapshot domains, rejects collisions, preserves edit order
and admitted Function leaves, and retains origin/converter invalidation lineage.
FUN composition covers conversion, installation, consumer suppression and retry.
Lean proves roundtrips, injectivity and discovery/write/install/undo commutation,
including the first mapped conflict key. Automatically inferred isomorphisms,
inferred laws and backend complexity qualification remain open. The next unit is
implemented: `table-fold` initializes owner-bound states and maintains retractable
aggregates through checked deltas, inverse recovery, isomorphism transport and
failure retry. It reuses `.zero/.add/.sub`, existing Wrapper, metadata guards and
FUN consumption. Complete conflict checks precede projections; accepted updates
visit only edit contributions, retaining source/aggregate and origin lineage
together. Lean proves the general optional-write law sufficient, derives exact
finite integer sums, and proves transport/inverse and projection-work bounds.
Arbitrary order-sensitive folds and automatically inferred retractable algebras
are outside this unit, not silently approximated; see collections.md for costs.
Aggregate-state transport now derives the target score through explicit inverses,
retains one source/target pair and live key-owner registry, skips repeated full
initialization, and applies mapped writes only to changed bindings on warm paths.
Source aggregates survive unrelated converter invalidation; dependent target and
chained states refuse. Full inverse fallback retains origin lineage. Tests cover
scanner refusal, pointer reuse, shared Functions, collisions and failure retry;
Lean proves sparse/full equivalence and dependency framing. A paired Scheme study
retains AB/BA and A/A controls across GC regimes and full workflow/undo/retry phases.
Cold conversion and original source shape admission retain their stated costs. Direction preparation
is now shared without allocating an unused ordinary/Delta transport inside each
fold bridge. The collection study compiles as a standard module and reuses the
existing linked test runtime; no second shared-library link is required per study.
Shared setup, workload compilation and execution retain their original bounds.
Finite metadata-preparation fusion is proved separately from allocation/GC costs.
Benchmark consumers now use the existing t/ source root and clan/poo/t prefix
through defbuild-script, after the complete public library check. This avoids
re-expanding producer sources during unchanged benchmark checks. Mutation scopes
reuse only exact list sharing or an empty outer scope; all instantiation checks
remain. A membership-filtering experiment regressed hot calls and was rejected.
The companion finite proof preserves protection membership and metadata refusal;
compiler freshness and allocation/GC behavior remain independently measured.
The linked test-program consumer now uses that same standard t/ graph after
complete producer checking. Source-relative inventory and runtime linked-root
admission remain mandatory. Paired complete-entry timing and GC-wall/history
diagnostics are recorded in collections.md; metadata relabeling and stale-producer
refusal have separate finite Lean proofs. This changes preparation cost, not the
completion boundary of the proposed general collection library.
Whole-module runtime imports now retain the existing facade stamp/initializer
while selecting used aliases. Public exports, dependency order and loader code
are audited unchanged; facade invalidation and finite regrouping/work bounds have
regression/proof coverage. Paired whole-entry results retain adverse cases and
do not establish stable wall-time improvement; see collections.md.
As before, arbitrary predicates and mutable hidden
callback state are explicit proof premises, not newly inferred capabilities.


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

### Finite multiple-key correlated indexes

The concrete multiple-key unit is now implemented in `table-indexes`:
`multiple?: #t` admits a finite proper projection list, checks every typed key,
and reuses Gerbil's stable duplicate elimination plus the original unique/grouped
backend operations. Atomic alias swaps, shared team migration, empty memberships,
ordered ranges, shared Function identities, linear FUN consumption, exact late
conflicts, refusal/retry and inverse restoration share the existing installer.
Declaration cardinality changes retain existing metadata invalidation.

The companion finite index laws establish membership correlation, sparse delta
rebuilding, duplicate stability, single-key correspondence and ordered claim
failure. Arbitrary projection termination/purity, callback-effect rollback,
automatic query discovery and concrete backend complexity remain boundaries;
this advances the general collection proposal rather than declaring it complete.

### Ordered cursor composition

The ordered collection protocol now retains `.seek<-` through nested `table-order`
views and existing typed Wrapper transfer. This closes the accidental capability
loss that forced a composed view back through full enumeration/sorting. Existing
Gerbil Iterator guards cover each delayed pull and EOF; no parallel cursor engine
or namespace is introduced. Nested service publication, inverse/retry, callback
identity and stale-origin regression controls accompany finite Lean guard and
observation laws. Backend-specific positioning complexity and automatic query
optimization remain their stated separate boundaries; see table-order.md.

### Captured single-key revision protocol

`methods.table .delta/opt` now closes the single-key request path shared by batches,
explicit isomorphisms, incremental folds, index installation and style/FUN workflows.
Correlated point writes no longer construct a trial primary or run whole-table
difference discovery. Typed optional capture, stable private Option shells,
non-replayed callbacks, exact conflict/refusal, no-op origin retention, inverse
and explicit retry have executable controls and finite Lean laws; see collections.md.
Admission and backend complexity qualification remain explicit separate costs.


### Backend cost acceptance

The explicit RationalDict/Trie source/derived workflow now charges cold protocol
preparation, conversion, structural equality, capture/install, complete observation,
conflict/restaging and undo. Local sharing removes duplicate carrier
conversion calls without dropping either encountered inverse check. See [table-representations.md](table-representations.md)
for matched controls, concrete receipts and conditional Lean cost laws. This closes
this bounded acceptance unit; it does not close arbitrary optimization discovery or
assert that a guarded representation has zero overhead relative to its raw source.

Child Type selection now reuses guarded identities only outside slot-read
observation. Observed conversion retains live getter refusal and dependency
provenance. The same acceptance suite adds preparation/observation/equality
slices and post-GC workflow/retry controls; these do not replace full publication
or make field-access counts a timing proof.

Complete-entry accounting now retains fixed-prefix and whole-loaded-entry costs.
Prepared receiver scopes reuse the existing complete-scope fast path, preserving
all revision checks. A paired-list revision candidate was withdrawn after adverse
whole-workflow measurements; retry tails and full-entry variability remain bounded
evidence limits, not closed performance guarantees. See table-representations.md.

Represented persistent point-update outputs now reuse the already declared
shape-preservation/admission law from ordered tables. Full initial/refusal checks
remain; GC/first/batch cost means, paired loss counts and empirical upper tails are
reported separately. Full-entry stability remains an evidence limit. See the
final persistent-output receipt in table-representations.md.


### Declared index preparation closure

Closed a construction-time consistency omission in the incremental collection
unit: later computed declaration getters could rewrite already compiled peer
recipes before revision stamps were captured. `table-indexes` now owns the request
spine, discovers backends under declaration/source protection, then compiles the
whole family under backend/child/origin protection using the existing object
mutation protocol. Refusal, repaired fresh preparation, unique conflict, retry,
Function retention, inverse restoration and later invalidation share the existing
FUN/IO publisher and installer. Lean supplies protected-frame and current-stamp
laws under supported-edit/source interpretation premises; see table-indexes.md.
This advances the proposed collection library; arbitrary symmetry discovery,
backend complexity and interpreter work retain their explicit separate scope.

The whole-entry fixture-pruning experiment was withdrawn after adverse cold-call
tails, despite its lower aggregate mean. All default preparation/checks remain;
setup work is separately visible. The bounded investigation is complete without
claiming stable future wall latency; see table-representations.md.

### Shared translation-declaration preparation closure

Table transport, representation derivation and fold isomorphism now protect the
complete endpoint-admission/callback-selection interval. Later computed getters
cannot rewrite a previously checked converter, table or child Type and then capture
apparently current stamps. The shared source-discovery/complete-scope continuation
reuses existing object guards and `using`; original getter failures, incompatible
endpoint priority, fresh retry and Function identity share one protocol. The
Reader/FUN `prepare-ledger-transport` example reparses no grammar and creates no
alternate publisher: it prepares a fresh current mapping per request, then reuses
ordinary delta transport, conflict refusal, IO consumption and inverse recovery.

Lean's exact finite endpoint/frame law is conditional on faithful metadata and
supported writes; raw mutation, arbitrary callback termination, inferred
isomorphisms and runtime/compiler verification retain their separate scope.
Twelve constructor/victim combinations and the complete service flow are in
`t/table-validation-test.ss`. This closes this concrete preparation unit, not the
whole proposed collection library. The complete-entry heap-policy experiment is
retained but not enabled: whole wall improved in four pairs while individual
workflow tails still regressed. See table-representations.md for the full-cost
split, paired maxima, same-policy controls and unmodified resource limits.

### Observation-scope cost acceptance

The existing observation protocol now shares one standard dynamic parameter and
reuses capture-only frames. Exact failure, precheck order, continuation and thread
controls accompany the Lean representation/conditional primitive-cost laws.
Two benchmark-target-cold complete-entry pairs improved 3.08 / 4.65 seconds;
module splitting was withdrawn. Physical off-CPU workflow tails remain unresolved
and are not closed by lower CPU, a favorable maximum or an added example. See
[slot-observation.md](slot-observation.md). Feature completion and performance
qualification remain separate; no check or resource limit is reduced.


### Shared checked selection closure

Closed a backend protocol omission: Trie's public filter/partition previously
bypassed strict Bool and complete-root admission. Both operations now inherit the
shared checked boundary while declared structural capabilities retain subtree
sharing. The generic path stages only removals and reuses final-state delta
installation, rather than rebuilding from an empty seed. Explicit Wrappers
transfer the whole source selection; correlated indexes, partial refinements,
five ownership styles and FUN/IO refusal/restaging use the same protocol.

The finite Lean laws cover admission/error order, late-refusal owner retention,
opaque-leaf deletion observations, edit counts and representation transfer.
Complex service examples and complete regression controls are documented in
[table-selection.md](table-selection.md). This closes this concrete collection
unit; inferred symmetry, arbitrary backend costs and unrestricted callback
termination remain research boundaries rather than missing checked behavior.


Local full acceptance of this unit passed all 136 modules / 1,354 cases in the
standard single-process test program with the unchanged 1 GiB / 300 s bounds.
All 12 selection cases and the companion 346 Lean check invocations passed.
These are semantic/check receipts, not a matched wall-time speedup claim.


### Complete declared cache admission

Closed a cold/warm publication omission in `table-indexes`: prepared caches were
never recognized through their declared complete table Types. The shared entry
boundary now checks carrier, owners, custom root constraints and grouped source
buckets before later recipes and before family publication. Gerbil `for/collect`,
the existing installer, five ownership styles, Wrappers and FUN/IO retain failure
order, old-owner retry, inverse restoration and admitted Function identities.

The companion heterogeneous-cache Lean laws and cohort examples cover complete
admission and atomic refusal. Sparse changed-key projection work remains separate
from full source/cache recognition cost. See [table-indexes.md](table-indexes.md).
This is a concrete finite protocol closure, not completion of automatic symmetry
discovery, arbitrary backend cost qualification or the whole collection proposal.


Local full acceptance of complete cache admission passed all 136 modules / 1,359
cases in the standard single-process program, retaining the 1 GiB / 300 s bounds.
All 22 index cases and 346 companion Lean check invocations passed. These receipts
do not establish a matched end-to-end performance improvement.


### Composed collection cursor protocol

Closed the derived `.iter<-` omission across ordered views, correlated indexes
and explicit representation Wrappers. Each reuses Gerbil Iterator and existing
positioning/checked conversion; representation conversion is demand-driven.
Metadata invalidation refuses before every pull, including repeated EOF, while
owner publication preserves issued snapshots. Conversion failure retains its
cause and consumes the already pulled row; fresh-request retry restarts the
original immutable snapshot rather than assuming cursor rollback.

The complete cohort flow combines atomic indexed publication, all five styles,
checked Function identity, FUN/IO consumer suppression and inverse restoration.
Six regression cases and the companion finite pull/translation laws are detailed
in [table-cursors.md](table-cursors.md). Ordered fallback sorting, complete cache
admission and backend/GC cost laws retain their explicit scope; they are not
silently removed or reported as whole-library completion.

Local full acceptance passed all 137 modules / 1,365 cases in the standard
single-process program with unchanged 1 GiB / 300 s limits. All six cursor cases
and the companion 346 Lean check invocations passed. These receipts qualify the
semantic unit and its finite demand counts, not an end-to-end speedup.


### Complete aggregate-state publication admission

Closed both reproducible whole-root omissions: compatible unrefined deltas no
longer bypass a source fold's final refinement, and warm fold isomorphism replay
no longer bypasses the target's independent complete constraint. The existing
recognizer runs before source contributions or target pair publication. Ordered
batches retain private intermediate roots; refusal preserves the accepted pair,
suppresses IO and supports fresh-request retry and inverse recovery.

The complete capacity-ledger chain accepts descriptor refinements through standard
Gerbil keyword arguments, retaining checked Function identity, existing FUN/IO
and child isomorphisms. New regressions and companion `TableFold` laws cover the
whole protocol, not just another container example. The cost model now charges
both complete admissions instead of conflating aggregate reuse with zero scans.
See [table-fold.md](table-fold.md) for proof premises and callback-effect limits.

Local full acceptance passed all 138 modules / 1,370 cases in the standard
single-process program with the unchanged 1 GiB / 300 s limits. The five new fold
cases, all 44 existing collection-validation cases and 346 companion Lean check
invocations passed. Complete admission work is charged; these are semantic and
finite source-work receipts, not an end-to-end latency improvement claim.


### Atomic fold transfer through closed derived targets

Closed a complete construction/installation omission: fold transport now honors
target bulk construction and submits one ordered target delta. Order views retain
that atomic installer rather than rebuilding it as point writes. Indexed and
represented targets provide a typed `.key-table` capability for private owner/edit
registries, preserving backend equality without interpreting owner IDs as service
rows or copying their business indexes.

The existing indexed service factory, presentation function and FUN/IO compose
cold family admission, dual identifier swaps, shared-team migration, retained
Function identities, genuine conflict refusal, retry and inverse recovery.
Repeated edits, stored false, collisions, stale/empty-origin requests and invalid
capability metadata retain explicit negative controls. Fold code lives in the
existing table module's `table/fold.scm` include. Companion overlay/transport/index
proofs and charged preparation boundaries are in [table-fold.md](table-fold.md).
Automatic equality/capability discovery remains a separate research boundary.

Full local acceptance passed 138 modules / 1,378 cases in the standard single-process
program (55.05 s execution), with unchanged 1 GiB / 300 s limits. Eight added
regressions cover the complete derived-target protocol and failure order. The
companion full Lean gate passed all 346 check invocations. These are semantic
acceptance and bounded source-work receipts, not a measured speedup claim.

After integrating the concurrent issued-read changes, a full dependency rebuild
exceeded the unchanged 1 GiB compiler heap in one four-way compilation partition.
The failed run is not an acceptance receipt. The existing compiler partitioner now
uses eight disjoint groups, retaining two compilation workers, standard make/core
budgets, all modules and the single-process runtime suite. Inventory regressions
check exact coverage for both four and eight groups and reject invalid indices.
No heap/deadline increase or new scheduling/environment mechanism is introduced.

### Complete set descriptor construction and publication

Closed the Set-versus-Table admission omission as one protocol unit: normalization,
empty/singleton/list/iterator construction, all algebra results and relation inputs,
selection/decomposition and membership focuses now retain the Set refinement as
well as backing laws. Bulk construction delegates once to the existing complete
Table constructor; a seedless iterator does not fabricate an invalid empty seed.
Trie subtree shortcuts retain input admission. Focus revisions include Set and
explicit dependencies. Five-style refusal/retry and Function-principal approval
publication reuse the existing ownership and FUN/IO chain. See set-algebra.md for
partial lens laws, first-failure order, scan/constructor costs and proof premises.
Arbitrary refinement closure, destructive storage and automatic law discovery
remain research boundaries, not defects claimed closed by these examples.

### Explicit heterogeneous collection projection

Closed the previously separate key/type-changing finite mapping unit through
`methods.table` and the existing five-style observation protocol. Required and
optional entries share one Type/Option admission boundary, callback shell capture,
target-equality owner registry, first-collision refusal and one complete target
constructor. Represented/refined targets and final correlated indexes retain their
existing laws, instead of being reconstructed as unchecked point operations.

The service workflow combines different source/target child Types, checked
Functions, independent source/target ownership, shared indexes, Reader/FUN/IO,
refusal/retry and ordinary target inverse deltas. Universal finite laws in the
existing `TableMapping.lean` cover uniqueness, order/payload correspondence,
output size and failure/publication. See table-mapping.md for capability admission,
logical equality, costs and proof premises. Automatic projection inverses,
collision-policy inference, destructive storage and whole-library completion are
not claimed by this explicit constructor.

### Incremental heterogeneous collection projection

Closed the finite warm-maintenance unit over explicit stable key-local projection:
source deltas retain full ordered conflict checks, first-touch coalescing demands
only final present rows, and private typed source/output plus target/owner registries
permit key swaps while rejecting untouched-owner and new-owner collisions. One
ordinary final-state target delta retains index/refinement admission and Function
identities. Immutable successor publication keeps failure/retry and inherited origin
invalidations aligned with FUN/IO and target styles. See table-mapping.md for
32-round full-oracle regressions, complex service migration and Lean cache/frame,
uniqueness, publication and callback-work laws. Full recognizer/backend costs remain
charged; automatic dependency/inverse discovery and destructive storage remain
research boundaries rather than claims closed by this unit.

### Direct projected target delta delivery and style publication

Closed the finite delivery/publication unit without rediscovering target changes:
`table-projection .apply-delta` optionally invokes a standard continuation with
the admitted successor and its exact target delta; Gerbil `values` retains both.
The existing target style installer handles old-value/new-key conflicts, final
constraints, generation races and inverse edits. The Reader/FUN/IO service path
returns the new state only after public installation; precommit failure retains
the predecessor for corrected retry. All five styles, unrelated-row rebase and
public-only refinement refusal have integrated controls. See table-mapping.md for
identity/no-diff regressions, indexed Function-bearing service swaps, Lean delivery/
style/conflict/inverse/frame laws and costs. Complete validation and a separate
public backend installation remain charged. No automatic inverse projection,
global publication credential or rollback of postcommit IO is claimed.


### Set many-to-one image and incremental deduplication

Closed this finite protocol unit using existing grouped table indexes, structural
key spaces and direct target-delta delivery. Shared owner deletion retains the
image until the last owner disappears; all five style presentations reuse the
existing conflict/install discipline. Explicit inverse deltas restore source or
target snapshots, without inferring an inverse projection. Complete Set
refinements, Function identity, declared/inherited metadata invalidation and
precommit failure/retry are retained. See set-algebra.md for API, charged work,
stability/equality premises, regional grant examples and companion Lean laws.
No arbitrary dependency discovery, destructive rollback, inferred inverse or
whole-library completion is claimed.


### Two-input incremental Set algebra

Closed the maintained binary-result protocol missing from the existing snapshot
Set algebra: union/intersection/difference/symmetric difference now consume two
ordered source deltas, coalesce edited keys by the declared backend equality,
install one exact target delta and publish through existing styles and FUN/IO.
Whole source/target refinements, joint compensation, inverse observations,
Function identities, origin invalidation and conflict/refusal retry are retained.
See set-algebra.md for complete API, independent four-operation revision oracles,
grant/revocation publication and companion finite Lean laws. Existing automatic
symmetry discovery and destructive-storage research boundaries are unchanged.


### Finite multivalued Set image

Closed the finite relation unit absent from the single-output image: explicit
`multiple?: #t` reuses `table-indexes` multikey grouping rather than introducing a
parallel deduplication engine. Empty and duplicate memberships, shared-owner
retraction, exact target deltas, Function identity, metadata refusal and immutable
failure/retry share one protocol. Typed service-catalog migration uses the existing
five-style Reader/FUN/IO publisher; no target snapshot `.diff` is rediscovered.
Companion finite Lean laws cover relation membership, singleton alignment,
idempotence, empty output, selective/delta repair and inverse recovery. See
set-algebra.md for full admission costs, stable finite projection premises and
research boundaries. This implements explicit finite relations, not automatic
symmetry discovery or arbitrary mutable dependency tracking.


### Selective grouped aggregation and summary publication

Closed the per-group summary protocol missing between global `table-fold` and
correlated indexes. `table-group-fold` shares the existing fold kernel and grouped
index engine; only affected final buckets are refolded, while exact target deltas
reuse the existing five-style Reader/FUN/IO publisher. Zero-valued live groups,
last-owner removal, group migration, original/final admission, inherited origins,
immutable refusal/retry, inverse observations and wrapped service callbacks have
integrated controls. Ordered aggregation does not require `.sub` or an inferred
commutative law. The finite Lean group/frame/delta/inverse laws and full cost
boundary are in collections.md. Refolding a large affected bucket remains charged;
automatic algebra/query discovery and destructive storage remain research
boundaries, not implementation defects declared closed by this unit.


### Two-source indexed lookup join

Closed the foreign-key lookup maintenance unit absent from single-source
projection and same-key `.join`: typed left/right heads, shared dependency buckets,
old/final reference invalidation and coalesced enriched-row edits now feed the
existing projection/collision and five-style Reader/FUN/IO publication protocol.
Missing versus stored false, different source key Types, key swaps, complete source
and target admission, callback/refinement/collision refusal, immutable retry,
inherited origins and inverse recovery have integrated controls and finite Lean
laws. See table-mapping.md for API, ordering, group/preparation/recognition costs and
precise proof premises. Automatic query discovery remains a research boundary;
finite many-to-many expansion is covered by the following explicit unit. This
lookup does not claim whole-library completion.


### Finite many-to-many grouped expansion

Closed the explicit finite equijoin unit with two existing grouped indexes and
Pair-key identities feeding the shared projection/collision/delivery protocol.
Old/final buckets on both sides cover incremental insertion, deletion and shared
dependency migration; pair-key coalescing preserves untouched projections. Cold
and warm collisions, source admission order, original callback failure, immutable
retry, metadata invalidation, source/target inverse recovery and five-style FUN/IO
publication have regressions and finite Lean laws. See table-mapping.md for the
API, faithful group/pair equality and purity premises, finite bounds and complete
preparation/validation costs. Automatic query optimization is a research boundary,
not an omitted implementation of this explicit finite protocol.

### Finite multivalued entry projection

Closed the explicit one-to-many projection unit: `table-projection` accepts
`multiple?: #t`, sharing its existing source/cache/owner, collision, exact delta
and five-style publication boundaries. Finite entry lists retain checked Function
leaves and reject every duplicate logical output key, including within one owner.
Warm changes coalesce source edits, release all affected old outputs and expand
only final present rows; empty lists, key swaps, inverse recovery, refusal/retry,
metadata invalidation and FUN/IO have integrated regressions and finite Lean laws.
See table-mapping.md for the API, purity/equality/persistence premises and output,
registry, preparation and full recognition costs. Automatic expansion discovery
remains a research boundary; this does not declare the collection proposal complete.

### Finite multivalued grouped aggregation

Closed the concrete composition gap between multikey indexes and grouped fold:
`table-group-fold multiple?: #t` reuses finite membership admission, existing
grouped indexes, aggregate kernel, owned state and exact five-style publication.
Duplicate/empty memberships, zero-valued live groups, old/final selective repair,
Function identity, inverse recovery, malformed membership, origin invalidation
and final-refinement refusal/retry have integrated regressions and finite Lean
laws. See collections.md for stable callback/key and persistent backend premises,
classifier spine ownership costs and complete affected-bucket refolding. Automatic
aggregate/dependency discovery remains a research boundary, not this finite unit.

### Finite multivalued grouped joins

Closed the explicit association gap between multikey indexes and grouped joins:
`table-group-join multiple?: #t` matches pairs sharing any cohort, coalesces common
witnesses before projection and retains a match despite later nonmatching groups.
Existing indexes, pair registries, exact projection deltas and style/FUN/IO
publication remain the implementation. Mixed two-source revisions, Cartesian
oracles, checked Functions, inverse recovery, malformed membership, collision
refusal/retry, origins and single list-valued keys have regressions and finite
Lean laws. See table-mapping.md for complete affected-pair coverage, pure stable
classification/equality/persistence premises and dense/multiple-bucket costs.
Automatic relation discovery remains a research boundary; the general proposal
is not marked complete by this finite composition unit.

### Incremental value-table combination

Closed the value-carrying counterpart of snapshot `.merge` and incremental Set
algebra: `table-combination` accepts heterogeneous payload Types under one declared
key space and an explicit key-local optional resolver. Both source requests install
before resolution; touched keys coalesce, unchanged outputs omit writes, and
both-absent removes without invoking a resolver. The original Set combination
engine is now shared rather than duplicated. Function identity, all five styles,
Trie/RationalDict full-merge oracles, grouped-fold composition, source conflict,
refinement/malformed response/exception refusal, origins and inverse/retry have
regressions and finite Lean laws. See table-mapping.md for exact delta, admission,
logical equality, callback/persistence and complete cost boundaries. Automatic
resolver/dependency discovery remains research work, not an implemented claim.

### Demand-driven bounded range cursors

Closed the missing upper-bounded streaming observation in `table-order`:
`.range<-` reuses positioned traversal, standard Gerbil coroutine Iterator and
the existing per-demand guard; `.range` now collects the same cursor. Table/Set
styles and Posh/Classy receivers share deferred observation without consuming
ownership. Bound-shell capture, all flags, seek/fallback observations, no-prefetch,
terminal pull counts, stale EOF, comparator refusal/retry, Function identity and
Reader/FUN/IO inspection have regressions and finite Lean cursor/window laws.
See table-order.md for persistent-root/order/admission premises, initial fallback
sorting and guard/positioning costs. Automatic backend/order discovery and host
coroutine/compiler verification remain research boundaries.

### Deferred named-index observations

Closed the named traversal gap for associated indexes: ordinary, positioned and
bounded index cursors delegate the selected backend and retain complete family
guards on every pull, including EOF. Name resolution for point/fold/range queries
now shares one private continuation. Existing index-fold and the new iterators
flow through all styles/receivers and bounded Reader/FUN/IO inspection. Unique and
shared buckets, atomic swaps/migration, inverse recovery, Function identity, old
snapshots, sibling invalidation, unknown names, unsupported capabilities and
foreign state refusal have regressions and finite Lean admission/nested-guard laws.
See table-order.md for stamps/persistence/order premises and full admission,
positioning/fallback costs. Automatic index selection remains research work.

### Checked finite collection division

Closed the existing divide/divide-list admission/representation gap: public Table
division uses shared complete admission, existing partition or Trie structural
capability, nonempty strict progress and exact count checks. Empty/singleton input
needs no invented empty result. Set refinements and all styles/receivers share
the existing multi-result installer, including zero-result linear consumption.
Cross-representation reconstruction, indexed shared buckets, Function identity,
late branch refusal/retry, invalid progress, original failures and Reader/FUN/IO
have regressions and finite Lean reconstruction/progress/admission/ownership laws.
See table-split.md for count/partition/persistence premises and complete costs.
Arbitrary callback termination or automatic parallelism remains research work.

### Checked single-entry decomposition

Closed the concrete `decons` interface item previously listed in `table.ss`:
required/optional Table and Set extraction now shares ordinary old-value guarded
removal, whole-remainder admission, correlated indexes and the existing five-style
single-generation installer. Backend choice order is retained, false is present,
empty required extraction refuses before commit, optional empty extraction follows
the ordinary one-step ownership policy. Reentrant losers expose no selected value;
metadata invalidation, Function identity, failure/retry, inverse recovery and
Reader/FUN/IO have integrated controls and finite Lean laws. See table-split.md
for APIs, equality/persistence premises and choice/preparation/admission costs.
This closes explicit extraction, not arbitrary destructive storage or algorithm
and comparison discovery.

### Independently partial collection constructors

Closed a factory-composition gap: deriving ordered or represented descriptors no
longer eagerly requests the source `.empty`. These views use the existing computed
slot mechanism, matching indexed descriptors. First materialization retains source
business admission, metadata protection and original failures. Finite construction
can succeed even when empty construction is forbidden; failure is not cached as a
successful field. See table-representations.md for successful computed-field cache
semantics, nested indexed Function workflows, all five styles, inverse recovery
and retry. The finite Lean constructor laws are conditional on checks/converters;
they do not certify the object evaluator or discover business refinements.

### Whole-primary validation through ordered and indexed views

Closed the complete-normalization gap for views that retain the source Key/Value
Type identities. Ordered views delegate source validation; indexed views normalize
the primary and initialize complete caches once, without demanding a business empty
or valid indexed prefixes. Unchanged primaries retain their original snapshot and
caches. One existing table-validation boundary owns metadata and final receiver
membership, including inherited refinements. Child-Type overrides keep ordinary
validation; no isomorphism/normalizer commutation is inferred. Paired unique swaps,
Function wrappers, all five styles, Set elements, exact child/index failures,
metadata refusal and retry have integrated controls and finite Lean primary-fidelity
laws. See collections.md for source-validator/index-builder laws and complete costs.

### Standard rational backend order and key equivalence

Closed the missing rational backend order declaration: standard RBTree enumeration
now supplies an explicitly numeric comparer and guarded linear positioning to the
existing table-order, Wrapper, index and five-style protocols. Numeric key aliases
retain backend equality; comparer transport and seek matching carry equality as
well as order. Rational Table/Set comparison and split therefore reuse existing
algorithms. Unordered negative controls remain explicit alist backends. Mixed
representations, fractional/bignum bounds, source admission, stale/EOF refusal,
Function identity, shared indexes, inverse recovery and retry have regressions and
finite equivalence/window/cost laws. See table-order.md; this adds no balancing
algorithm and does not claim logarithmic positioning or a wall-clock speedup.

### Backend-equivalent incremental index work

Closed the mismatch between structural membership deduplication and declared
backend key equality. Existing Unit-valued `.key-table` registries now own stable
work scheduling and multivalued membership coalescing for indexes, projections,
group folds and group joins. The original ordered edit list still checks every
intermediate expectation before any index callback; inverse recovery retains it.
Numeric alias migrations, genuine unique-owner conflicts, stale intermediate
requests, failure retry, Function identity and five-style publication have controls
in table-index-equivalence-test.ss. Finite Lean laws state coverage, unique logical
work, first-representative retention, scheduling bounds, observation equivalence
and unchanged sequential refusal. Lawful declared backend equality and congruent
pure classifiers are explicit premises, not automatically inferred laws. This
closes an equality mismatch, not the general collection research proposal.

### Logical source ownership in isomorphism histories

Closed the source/target equality mismatch in shared snapshot, delta and fold
transport. Existing target registries own collision classes; a prepared source
key registry recognizes repeated logical owners across physical aliases. Strict
physical inverse checks and ordered intermediate expectations remain unchanged.
The rational capacity example combines nested Function handles, Tuple/Pair rows,
negated keys, aggregate reuse, inverse restoration and five-style FUN publication.
Regression controls distinguish genuine collapse, source conflicts and invalid
physical inverses from safe alias revisions. Finite Lean laws connect alias
registration and exact collision causes to explicit logical-bijection injectivity.
The implementation reuses the existing translator and standard backend empty / point-insertion /
membership protocol. Registry construction/probing and complete admission retain
their costs; inferred quotients and arbitrary converters remain research boundaries.

### Owned change capture across provider and callback reuse

Closed mutable Option-shell aliasing in snapshot/point delta capture. `.diff`
captures both event shells before any child recognizer and admits each event;
point requests own old lookup values before callbacks and replacements before
recognition. Seeded import, merge argument and Set-image retained-result boundaries
follow the same existing Option capture discipline. Private composition, inverse,
transport and installation need no additional wrapping. Reusable provider controls
cover stored false, Function identity, late refusal, retry, unique-index swaps,
aggregate/representation workflows and all five publication styles. The new
functional Lean module proves owned-history, ordered capture, replay/inverse and
recognition-interference laws without enlarging the existing revision module.
Stable admitted leaves and synchronized emission remain explicit premises;
arbitrary deep copies and runtime heap verification are not claimed. See
[table-batches.md](table-batches.md) for scope, costs and design reflection.

### Owned focus observations and captured payload admission

Closed the optional focus getter/setter/modifier chain across raw roots, five
styles and receiver methods. Getters own returned Option shells; setters own
requests before source admission; both writes delegate one payload admission to
the existing point installer. Removing the pre-owner setter recognizer also closes
reentrant winner overwrite, without a second ownership engine. Regression controls
cover borrowed reads, recognizer interference, admission counts, late refusal and
retry, consumed owners, Function-valued service composition and inverse recovery.
The existing service example selects required/optional focuses explicitly and keeps
one Lens/FUN/IO publication. Focus proofs reuse owned-capture, lens-write and stale-
generation laws in the existing namespace. Complete root checks and resource limits
remain intact. See [table-focus.md](table-focus.md) for failure order, laws, costs
and design reflection; these are not joint multi-owner transactions or heap proofs.

### Owned collection dependency declarations

Closed caller-owned origin-spine aliasing across comparers, focus/delta source
capture, projections, lookup/group joins, combinations, grouped folds and Set
images. Constructors snapshot finite declarations before subsequent getters can
reuse the buffer; existing source guards protect declared objects during discovery.
No separate invalidation engine or per-operation wrapper was added. Regression
controls cover same-revision replacement objects, delayed cursors, empty deltas,
five ownership styles, malformed declarations and metadata writes during discovery.
The policy capacity-fold example composes revisioned metadata, shared groups,
Function leaves, FUN/IO refusal/retry and inverse restoration. Finite Lean laws
prove identity retention, ordered composition and unchanged fresh/stale decisions.
Stable leaves, explicit dependency declarations and supported metadata writes remain
premises; arbitrary closure mutation and runtime heap proofs are research boundaries.

### Complete Set observation admission

Closed the raw Set read-family gap: left/right folds, forward/reverse visits,
count, list conversion and membership now retain complete backing/Set admission
and the existing metadata scope. One fold adapter erases Unit values, retains
opaque accumulators and discards visit results. Dedicated count/list/membership
delegates are preserved rather than replaced by extra traversals. Five styles
and receivers now expose both visit directions through the existing query path;
custom Set delegates and predicate failure order remain intact.

The access-fold example composes an admitted read with Reader/FUN/IO. Regression
controls cover excluded/malformed roots, empty callback contracts, directional
order, specialized delegates, checked Function identity, guarded metadata, original
callback causes and prefixes, consumer suppression/retry and reentrant publication.
Finite Lean laws prove admission/delegation, original refusal, ordered Unit erasure
and first-callback/consumer refusal. Backend laws, stable admitted snapshots/leaves
and supported metadata updates remain explicit premises. This does not infer
callback termination or roll back effects; all public-boundary admission costs
remain charged. See collections.md for scope and design reflection.

### Explicit ordinary-fold origins and transitive aggregate scope

Closed the ordinary fold declaration gap: `table-fold` now accepts a finite origin
list through its existing private constructor, like grouped folds and projections.
Origins are owned before descriptor/algebra discovery and exposed on the public
fold. Isomorphism derivation passes the private complete source scope into its
Codomain fold, so independently initialized target states cannot certify a stale
source policy merely because converter stamps are fresh. No second invalidation
engine or source-descriptor clone is introduced.

The weighted capacity ledger combines Tuple/Pair storage, checked callbacks, XOR
keys, sparse updates, FUN/IO, inverse recovery and fresh policy reconstruction.
All five represented-data styles remain independent of score-only policies.
Regressions cover caller buffer reuse, malformed/cyclic declarations, guarded zero
getters, independent Codomain initialization, converter framing, no-op delta lineage,
conflict-before-projection, original causes, consumer suppression and retry/undo.
Finite Lean laws reuse stamp preparation/capture to prove transitive refusal,
deduplication, identity retention, revision framing and exact fresh callback results.
Stable explicit dependencies and faithful host revisions remain premises; hidden
closure-state discovery and runtime cost/GC proofs remain research boundaries.

### Complete comparer-origin attestation

Closed the revision-only comparer seal gap. Constructor seals now include their
captured key/origin version snapshot; unchanged comparer revision or copied callback
fields cannot authorize a positioned backend after a dependency change. The existing private comparison guard remains; a shared
declaration boundary covers ordering/wrapper construction and
backend cursor construction. Existing per-pull checks include EOF. Seals retain
only numbers in the weak-key registry, without extra descriptor references.

Unsealed custom comparers retain reference sorting under their declared laws;
edited comparer metadata revokes positioning evidence while preserving private
comparison semantics; stale declared origins require a fresh declaration. The service index
factory's order policy selects the original backend order or explicit reverse
fallback, invalidates old five-style workflows, and supports fresh reconstruction,
checked Function identity, sparse revision, inverse recovery and Reader/FUN/IO.
Eight regressions cover zero-comparison paths, empty/singleton roots, EOF, callback
and producer suppression, protected discovery, key revisions and custom fallback.
Finite Lean laws prove full-seal admission, exact callback results and stale pull
refusal without claiming runtime/GC correctness or automatic comparison-law discovery.
Constructor-owned metadata remains read-only; supported edits use revisioned slots.

### Reference-order admission across comparison and decomposition

Whole comparison now separates lawful reference observation from structural-backend
capability. Custom or label-edited comparers may use the existing checked Iterator
comparison; only a complete current constructor seal selects `.compare/key`.
Both complete roots and strict Integer callback results retain their original
admission/failure order. No sorting or order discovery is inferred for a backend:
the declared Iterator order must agree with the comparer.

Ordered decomposition now shares comparer-origin admission before key metadata,
pivot lookup and either successor construction, including empty roots. Table, Set
and five ownership styles reuse that boundary. Current custom protocols retain
their existing private comparison guard; edited labels do not acquire positioning
evidence. Stale declared origins require explicit reconstruction. Both source
snapshots, Function leaves and failed owners remain available for retry.

The service example composes comparison and linear decomposition with Reader/FUN,
then invokes one IO consumer after both sides accept. Indexed swaps, reverse custom
order, original callback failures, inverse recovery and consumer suppression have
regressions. Finite Lean laws prove callback selection, stale-origin suppression,
exact delegation and empty/opaque-payload examples. Lawful ordering, faithful host
revisions and persistent carriers remain premises; no runtime/GC theorem is claimed.
Design reflection: share the established comparer boundary and observation kernels,
keep backend evidence distinct, and add no per-method validation wrappers.

### Owned finite batch requests

`methods.table` now captures `.join/list` roots and `.compose-deltas` requests
before metadata discovery, recognition or validation can reuse the caller's list
cells. Style `.join/list` captures right-owner identities before entering the
existing generation-captured update. One standard `map identity` at each public
batch boundary owns only the finite spine: persistent roots, delta objects and
checked Function leaves remain shared. No new namespace, cache, lock or per-method
validation wrapper is introduced.

Previously a first-root recognizer could replace the caller's second request:
joining roots containing 10 and 20 could silently install 10 and 90. The same
interference could change a validated delta batch after origin collection. Capture
now preserves order, repetitions, later-source join priority, intermediate delta
expectations and origin lineage. An invalid original root/owner still refuses even
if the caller list is later repaired; failure leaves update ownership available
for an explicit fresh batch retry. Existing complete admission and single-commit
publication remain unchanged.

`join-ledger-action` is the existing Reader/FUN map over this shared join boundary.
The worked scenario combines checked Function leaves, unique indexes, inverse
swaps, retractable folds, consumer suppression and policy invalidation. Regressions
also cover metadata getters, root-recognizer interference, five styles and
right-owner retention. `TableCapture.lean` reuses ordinary finite list capture and
the existing batch correctness theorem to prove original-request delegation,
preparation/installation failure preservation, exact order/count and intermediate
conflict semantics after caller-buffer reuse.

Capture costs one spine cell per request at each crossed public batch boundary;
roots and payloads are not copied or normalized. All original recognition, lookup,
index preparation and conflict costs remain charged. Stable leaves, faithful
revision/ownership checks and serialized caller-cell capture remain premises.
Arbitrary simultaneous writes during the copy and callback-effect rollback are
outside these finite future-work laws. Design reflection: own the existing request
boundary before callbacks, instead of cloning data or introducing another executor.

### Constructor requests captured before metadata and delegation

`capture-table-bindings` owns a finite request spine and its binding Pair shells.
The raw Table constructor invokes it before discovering descriptor sources or
child Types. Existing style factories reuse it before invoking a custom public
Table constructor. Set factories copy only the outer element list: Pair-valued
elements are opaque leaves, not binding shells. Original keys, values and checked
Functions retain identity. The backend still owns duplicate-key precedence,
bulk/singleton construction and complete-result recognition.

Previously metadata or a custom factory delegate could rewrite caller-owned Pair
fields before the constructor took its snapshot. Now changing a requested value
from 20 to 90 cannot alter the captured constructor request. Repairing an original
invalid occurrence cannot make it acceptable either. Malformed outer requests in
styles retain the existing guarded delegation order, including stale-factory refusal
before the downstream list contract. Unexpected delegate/backend errors retain
their original causes; fresh explicit requests can retry.

The existing `construct-ledger-action` accepts raw descriptors and all existing
Table/Set style factories through the same Reader/FUN map. The worked indexed
service scenario composes complete construction, checked Function identity, unique
index refusal, consumer suppression, retry, atomic swaps and inverse recovery.
Seven regressions cover metadata interference, invalid original entries, five
Table/Set factories, Pair-valued Set identity and stale/failure precedence.
`TableCapture.lean` composes the existing batch capture with finite child/backend/
root admission, proving failure suppression, exact delegation, original Pair-field
observations and identity recapture. This advances finite collection future work;
stable leaves, serialized capture and faithful backend/type protocols are premises.

A crossed public Table constructor boundary copies one list cell and one binding
Pair shell per valid request entry. Set factories copy only list cells. Private
captured lists are passed through ordinary delegates; no deep copy, cache or new
validation-wrapper layer is introduced. Existing recognition, index preparation
and backend costs remain charged. These laws do not prove arbitrary mutable-leaf,
runtime/GC or concurrent-heap correctness. Design reflection: share the request
capture kernel, preserve each representation's leaf semantics, and keep backend
algorithms and standard contract failure boundaries intact.

### Owned finite Set-image outputs

The multivalued `set-image` boundary now owns the callback's proper output-list
spine before any target `Elt` predicate runs. Previously a recognizer could reuse
the response buffer: an original `(7 8 8)` request could publish `(7 8 9)`. One
standard `map identity` in the existing multiple-output branch prevents that request
substitution. Single-output mappings already own their private singleton list and
retain the original path. Elements, including checked Functions and list-valued
single keys, remain shared opaque leaves.

Every original output occurrence is recognized before backend-equivalent keys are
coalesced. A recognizer cannot repair an invalid original member by replacing its
caller cell; an inexact representation rejected by an explicit exact-only Elt
contract still refuses even when numerically equivalent to an accepted key.
Type/backend errors and first-failure order remain unchanged. Callback writes to
the external response buffer are retained, without publishing partial caches or
consuming a target owner on failure.

Cold indexing and warm touched-key discovery share this same boundary. Existing
grouped indexes still implement shared witnesses, deleting one owner, last-owner
retraction, exact target deltas and inverse recovery. The existing permission
publication example composes all five styles, conflict refusal, a fresh-owner
retry and inverse target installation through Reader/FUN/IO. Six regressions also
cover cold/warm malformed responses and Function-wrapper identity.

`SetAlgebra.lean` reuses the existing finite request capture and constructor
admission laws. It proves original-output delegation, refusal before coalescing,
original membership, empty output and compatibility with the existing existential
image semantics. Those image repair/inverse laws remain conditional on faithful
backends and stable finite mapping observations. This advances the collection
proposal's future work; it does not prove runtime/GC, arbitrary concurrent writes
during capture or mutable-leaf correctness.

Each multivalued callback adds one shallow spine cell per emitted occurrence;
validation still visits all occurrences before deduplication. Existing registry
capture, source/target admission, indexing and publication costs remain charged.
No target snapshot diff, cache engine, wrapper layer or namespace is added. Design
reflection: capture at the existing Elt boundary and reuse grouped-index ownership,
rather than clone keys or bypass the more specific Set contract.

### Trie Set element contracts reach the backing key protocol

`TrieSet.` now follows the existing `RationalSet` declaration pattern: its element
descriptor supplies the backing Table's `Key`, while `Value` remains `Unit`. The
explicit `UInt` element default preserves the ordinary family and breaks the
inherited Elt/Table.Key alias cycle. `SimpleTrieSet` keeps its existing public
constructor and unsigned carrier; no wrapper, namespace or alternative tree is added.

Previously `SimpleTrieSet (UIntN 8)` exposed an eight-bit Elt but retained unrestricted
UInt backing keys. A bulk request containing 256 could be accepted, while five-style
derivation refused the mismatched descriptor identities. Now the identical declared
contract governs bulk/Iterable construction, complete-root recognition, Set algebra,
codecs, backing key registries and all five existing presentations. Shared-root
shortcuts still follow complete admission; an out-of-contract raw Trie cannot gain
admission merely because its unsigned representation is structurally valid.

Supported element rebinding updates the backing key contract through existing
prototype dependencies. Old factories/owners refuse through their existing revision
guards; a fresh factory admits only compatible persistent roots, without normalizing
or copying them. Existing 25 style transfers and failed-update ownership rules are
unchanged. The multivalued-image example now directly uses the public Trie Set
factory instead of manually assembling Set<-Table over a typed Table.

The bounded service-permission scenario uses an eight-bit permission Set, a typed
catalog, shared permission 255, source revision and exact five-style publication.
Conflicting target owners suppress IO, fresh owners retry, and inverse target deltas
restore the prior permissions. Six regressions also cover UInt256 bounds, refined
UInt predicates, codecs, default construction and element rebinding.

`SetAlgebra.lean` proves shared-predicate recognition, finite row/element equivalence,
complete refusal, explicit contract refinement and read/consumer suppression. The
service examples demonstrate eight-bit and four-bit admission boundaries. Faithful
backend enumeration, supported host revision checks and UInt-compatible key
representations remain premises; arbitrary key encodings and automatic subtype
inference are outside this parameter-forwarding unit. These are finite future-work
laws, not compiler/runtime/GC verification.

The change routes the existing declaration to its existing backend slot. It adds
no collection traversal or validation-wrapper layer: prior key recognition now uses
the correct predicate, and its actual cost remains charged. Design reflection:
reuse the established Set/Table declaration pattern and preserve descriptor identity,
rather than bypass style admission or widen a requested contract to UInt.

### Ordered query request ownership across styles and indexes

Closed a request-capture ordering gap in `.seek`, `.seek<-`, `.range` and
`.range<-`: source recognition could rewrite caller-owned Option cells before
bounds were copied. Named index queries and all five Table/Set styles now capture
bound cells before snapshot admission or computed backend method discovery.
Existing `map/option identity` performs the shallow capture; no new wrapper,
namespace, validation policy or backend algorithm is introduced.

Seven regressions exercise admission/getter effects, the complete eager/deferred
Table/Set style matrix, named indexes, invalid original bounds, stale failure
priority, delayed EOF admission, and Reader/FUN/IO inspection of checked Function
rows through conflict/retry and inverse revision. Keys, Function payloads, index
names and inclusive flags retain their existing meaning and identity. Capturing
an invalid request does not repair it or suppress an earlier stale-source error.

Finite Lean laws in `TableObservation.lean` prove original endpoint retention,
preparation/query refusal, absent-bound semantics, identity handoffs and reuse of
the existing range predicate. Examples distinguish `[2,4]` from a later `[4,5]`,
refuse an originally invalid key despite repair, and retain a present false key.
Stable opaque key leaves, persistent roots, lawful comparers and faithful host
revision checks remain premises. Arbitrary callback mutation of key payloads,
thread races, compiler and GC behavior are not proved by this finite future-work
model. Capture starts at an owned query entry, not before arbitrary external
method lookup performed by the caller.

Design reflection: move the existing Option capture ahead of effectful admission
rather than adding per-query contracts. Each crossed ownership boundary allocates
at most one shallow cell per present endpoint. All existing validation and cursor
guards remain charged; this correctness change claims no elapsed-time speedup.

### Independent Set Elt admission and recursive validation

Closed the complete independent-Elt protocol over existing Table backends:
whole-root recognition, original-occurrence bulk/iterator admission, membership
and lens/split/bounds, ordered recursive normalization, normalized-key collision
refusal, exact returned Function/container keys and failure retry. Backing cooking
runs first; final recognition cannot recook an Elt wrapper. Unchanged children
retain the backing result without key-registry or bulk-constructor preparation.
The existing exact-identity boundary for five-style derivation is intentional and
unchanged. See collections.md and collection-composition-audit.md for costs,
complex approved service publication, eight regressions and finite Lean laws.

### Coherent Set source capture and retained-consumer invalidation

Closed the shared source protocol over eager Set operations, membership focuses,
iterators, incremental images/combinations and five-style factories. Declared
origin spines are owned before Table/Elt discovery; the exact captured family,
including independent Elt and backing origins, reaches retained consumers.
A changed original origin or Elt refuses before deferred work; an unrelated
replacement revision does not manufacture staleness. Fresh construction is the
explicit retry. See collections.md and collection-composition-audit.md for the
counterexamples, composed Function publication, finite Lean scope and costs.

### Boolean membership focuses across Set presentations

Closed the Set `.lens` presentation gap: all five styles and Gerbil receivers now
expose Boolean membership over the existing optional Table focus. The project
Lens composition protocol preserves the underlying captured-generation modifier,
so composed service updates cannot overwrite a reentrant winner. No new ownership,
validation, delta or lens engine is introduced. The original Table focus domains
remain unchanged. False keys, strict Boolean replacement, custom Set refinements,
source invalidation, Function identities, failure/retry and inverse recovery have
integrated controls and finite Lean laws; see set-algebra.md and the composition
audit for scope and premises.

### Owned multi-result collection groups

Closed result-spine ownership before root admission in direct Set division and
the shared five-style multi-result installer. A lawful producer's original root
group is captured before recognizers can recycle its returned list. Partition,
split and division retain their existing algorithms and one-install ownership
rules; no root or checked Function is cloned or normalized. Original admission
order, exact failure causes, reentrant-winner refusal and explicit retry remain.
Table/Set and FUN/IO examples plus finite capture/admission/publication laws are
documented in table-split.md and the composition audit. Persistent roots and
faithful backend decomposition laws remain premises, not inferred algorithms.


### Owned encoder observations

Closed the shared Table/Set encoder boundary across JSON, bytes, ports and all
five presentations: capture the finite observation before child codecs can reuse
its list/Pair shells. Reuse existing capture and List/Pair codecs, preserving root
admission and encoder lookup priority. Controls cover false elements, opaque
Function handles, original late causes/port prefixes, nonconsuming owners, FUN/IO
retry, indexed publication and inverse recovery. Finite Lean laws establish the
boundary with backend fidelity and stable leaves as premises. Decoder semantics
and mutable payload internals remain explicit scope boundaries; see the
composition audit. Capture allocation remains charged, without a speedup claim.


### Final-state grouped bucket construction

Closed cold construction and warm grouped-index maintenance over independently
partial business constructors: existing key spaces stage all membership edits,
then one finite constructor admits each complete nonempty bucket; empty groups
disappear without business `.empty`. Five-style cohort and represented-carrier
controls cover migration, inverse splitting, exact refusal/retry, Function
identity, equivalent memberships and FUN/IO. Unique indexes retain their conflict
protocol. Finite materialization/admission and ordered family-stage Lean laws
state the capabilities and failure boundary. Projection work remains selective,
but affected-bucket copying/reconstruction is charged; see table-indexes.md.


### Captured projection retraction

Closed cached-output retirement across single/multivalued projections, composed
views and five-style exact target-delta publication. Capture the borrowed ledger
Option before eviction; reuse its already owned rows to release every original
key before new claims. Six regressions expose the old leak/collision behavior and
cover false values, Function identity, late refusal, retry and inverse recovery.
reroute-service-action composes owned finite requests with existing FUN/IO. Finite
capture/deletion/inverse laws retain backend and stable-cache premises; output
traversal, one present Option allocation and complete admission remain charged.
See table-mapping.md and the composition audit; this is not automatic discovery
or general mutable-payload ownership.


### Captured sparse translation expectations

Closed represented delta installation and sparse fold transfer over borrowed
endpoint reads: capture the original backend Option before old-value checks and
replacement queries; reuse already owned prefix-overlay Options. Six original
conflict failures cover pure queries, five styles, ordered/cancelled batches,
false values/keys, Function identity, aggregate preservation and FUN/IO retry.
The capacity-ledger value Wrapper refinement reuses the existing transport.
Finite capture/check/conversion/inverse laws state backend and stable-leaf
premises. Only present backend expectations add a shell; no full scan/refold or
VM speedup is claimed. See table-representations.md and the composition audit.


### Captured grouped-join payloads

Closed warm pair construction over shared read-response buffers: bind the left
payload before dependent group/right queries and reuse existing joint indexes,
projection and publication. Failing numeric/false/rederived-view controls expose
the original silent corruption; the six-case unit additionally checks collisions
and distinct Function placement schemas. Controls cover
multi-group migration, deduplication, exact deltas, inverse, five styles, false
values and stale-origin retry. revise-placement-action reuses typed point delta
capture and FUN/IO. Finite payload/presence/refusal laws keep backend, stable-leaf
and classification premises explicit. Pattern binding adds no wrapper; ordinary
candidate, validation, construction and GC costs remain charged. See table-mapping.md.

### Owned finite ordered observations

Closed the finite materialization boundary used by fallback ordering and both
reverse-fold paths. Existing binding capture owns list/Pair shells before sorting
or user fold callbacks can recycle producer scratch cells; it does not copy roots
or checked Function leaves. Standard sorting, positioned cursors, bounds, metadata
guards and five-style observation remain unchanged. Numeric, false and Function
regressions expose the prior corruption; bounded Reader/FUN/IO inspection covers
original comparison refusal and retry. Finite Lean laws reuse request capture for
original-row delivery, sorting refusal, reverse folds and permutation cardinality.
Faithful backend observations, stable leaves and lawful ordering remain premises.
The O(n) shell capture/allocation and existing sort/admission costs stay charged;
see table-order.md. This closes a concrete boundary, not automatic discovery.

### Actual receiver admission for ordered queries

Closed inherited/edited receiver admission across `.iter<-`, `.seek<-`, `.seek`,
`.range<-` and `.range`. One query boundary admits a changed receiver before
backend positioning or callbacks and retains its child/origin revisions through
all pulls, including EOF. Recursive admission reuses the existing finite guard.
Only the exact unchanged constructor result reuses its original source admission;
its declared deferred representation semantics and seek work bounds remain intact.
A copied or edited receiver cannot borrow that evidence. Range materialization
consumes the same cursor without a second receiver refinement. Integrated controls
cover source/receiver refusal, narrowed invalid tails, false values, Function
identity, bounds capture, origin invalidation, FUN/IO and five styles. Lean reuses
the complete observation gate and proves the explicit identity/revision selection.
Full changed-receiver admission and per-pull metadata work remain charged; no
arbitrary callback termination, purity inference or VM proof is claimed. See
table-order.md and the composition audit.

### Shared-shape access and lazy evaluation acceptance

The layout protocol now separates a reusable shape/name offset from the successful
owner/revision/layout value guard. Switched accesses read current receiver cells,
delegate observed access to the existing ordinary reader before layout preparation, and fall back to ordinary lazy evaluation
only for an uncomputed cell. False/Function values, failures, parent invalidation,
read replay and checked multi-service FUN/IO have integrated controls. Standard
cached module loading preserves recipe identity; it does not force fresh-clone
business slots. No duplicate loader or evaluator is introduced.

Representation proofs cover shape/index fidelity, current values, lazy/refusal
and explicit named-resolution work; new paired phases charge preparation, cold
construction, hot/switch/tracked reads, revision and cached-load workflows. See
representation.md. Full hash removal, automatic PIC/JIT/policy selection and
fresh module expansion/link/initialization performance are NOT completed by this
unit. They remain explicit optimization/acceptance boundaries rather than claims
inferred from cache hits or primitive operation counts.
