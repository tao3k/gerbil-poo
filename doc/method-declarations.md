# Method fragments in the declaration protocol

## Prototype recipe composition

`summary-prototypes` returns ordinary first-class prototype extensions, and
`prototype-summary-action` assembles them over the existing typed summary and C3
charge. Standard `reduce-right` owns long suffix reduction. The outer head is
captured at construction; later suffix edits are selected on the next application.
The small zero/one/two-layer paths retain their original capture behavior.

The four Reader layers sequence approval and current reflected policy before
the method workflow, then tag publication and observation after success. Hidden
metadata refuses without caching an earlier admission. Restoring metadata and
changing the offset permits a fresh retry. A post-result refusal retains earlier
method effects. The finite-list contract rejects revised improper/cyclic suffixes;
this is separate from unrestricted recursive fixed-point termination.

Use typed defaults for a revisable policy, for example
`(public offset (.o (type Integer) (default 1)))`. A `constant` declaration also
constrains admission to that exact value; it is appropriate for the false tag,
but correctly refuses an offset update. `write-slot!` validates the current
descriptor before editing; a rejected false offset leaves the original value.

## Prepared whole-form expansion

`batch-expander` and `batch-action` in `examples/declared-methods.ss` prepare one
FUN traversal of static and spliced declarations, then derive a family above the
existing shared C3 diamond. A form may contribute a complete before/primary/after
group. The current context supplies tenant, surcharge and final approval; only a
complete approved stream reaches construction, public reflection and combined
dispatch. A rejected context can be retried with the same action. Revising the
expander requires fresh preparation. Private fields remain unforced.

The expansion driver uses standard ordered mapping and right-fold collection.
It checks each fragment before the suffix, captures the original form bindings,
and preserves deferred copying of returned chunks. Finalization also runs for
empty input. Callback side effects preceding refusal are retained. These controls
and the companion Lean traversal laws advance the article's future MOP work.

Racket's “Combining Method Fragments” specifies standard qualifier order; the
following “Generalized Prototype Combination” proposes fragments beyond records
as future work. This module advances that proposal by connecting existing native
declarations, Slot inheritance and method interpreters to `.defgeneric`. It does
not claim a literal Racket declaration API or completion of arbitrary carriers.

## One declaration stream

`method-declaration.ss` exports `MethodDeclaration.` and `method-fragment`.
`MethodDeclaration.` inherits `Declaration.`; both expansion and finalization
use inherited continuations. The normal `.declare` macro already supports the
new `method` form alongside record `public` / `private` forms.

```scheme
(.defgeneric (cost self units) slot: .cost combination: standard-combination)
(def service (.declare MethodDeclaration. (.o)
  (public label (.o (constant 'billing)))
  (method .cost (.o (contributions
    [(combination.primary (lambda (_ units) (* 10 units)))])))
  (method .cost (.o (contributions
    [(combination.after (lambda (units) (displayln units)))])))))
(cost service 2) ; returns 20, after prints 2
```

The `combination.` prefix above denotes the existing `method-combination.ss`.
Runtime/computed names use `(method-fragment name contributions [admit hidden?])`.
The metadata fields are `contributions`, optional `admit` (default standard
contribution admission) and optional `hidden` (default false). Slot descriptors
and method contributions remain ordinary extensible POO objects.

Finalization merges compatible same-name local method fragments in source order,
placing each name at its first local occurrence. Mixed record/method names,
ordinary duplicate records, unequal admission callbacks or visibility conflicts
refuse before a receiver is returned. Two distinct but extensionally equivalent
admission functions need a common callback identity to combine. Arbitrary custom
finalizers must still return valid distinct named Slot descriptors.

The generated Slot computation appends local contributions to its delayed parent
group. Existing C3 supplies most-specific owner order and includes shared ancestors
once; it is not a second graph traversal. Within each qualifier the source order
is retained. Both original fragment metadata and merged descriptors have registered
dependency edges. Editing supported `contributions`, `admit` or `hidden` fields
invalidates compiled groups/catalogs; revised local policy/visibility conflicts
raise again. New declaration membership requires fresh elaboration. Source lists
and contribution bodies follow existing immutable/pure compilation premises.

`RecursiveDeclaration.` can be mixed with `MethodDeclaration.`: safe recursive
roots expand first, then the same finalizer coalesces their method contributions.
Ordinary recursive record collisions still refuse. No special evaluator, memo
ownership rule or global registry is introduced by this bridge.

## Generic invocation

`.defgeneric` accepts `combination: combine`, where `combine` is a native function
`(contributions arguments) -> result`. Its slot resolves through ordinary `.ref`;
the complete argument list then goes to the supplied interpreter. `from: type`
resolves on `.type` and prepends the original instance exactly once. `slot:`,
`default:` and `compute-default:` keep their existing lookup meanings. A default
with a combiner supplies raw fragments, e.g. `default: []` for a simple sum.

The native adapters are:

- `standard-combination`: standard qualified contributions, error on no primary.
- `(simple-combination policy)`: existing simple item/around interpreter.
- `(forwarding-combination payload-type)`: existing forwarding interpreter, with
  current replacement payload admission through the given native Type.
- `(inner-combination terminal)`: procedure bodies, with the existing inner chain.
- `simula-combination`: existing Simula prefix/inner/suffix interpreter.

Each adapter admits its complete group before executing a body; selecting an
incompatible combination cannot silently discard qualifiers. Custom combiners
retain their own semantic obligations. This receiver-selected generic bridge
does not add argument-based multiple dispatch or automatic signature inference.

A zero-argument generic WITH a combiner calls the effective method; the historical
zero-argument property getter WITHOUT a combiner still returns its slot value.
Fixed and rest argument forwarding are covered. Optional/keyword formal grammar
is not expanded here. Hidden metadata is reflected under the existing trusted
raw-slot access boundary; `.defgeneric` does not add capability security.

Only an actual queried receiver/slot absence activates a generic default or an
empty inherited fragment group. Nested missing-slot errors propagate. Around may
skip its inner computation; primary failure suppresses after methods as before.
External effects are sequenced, never rolled back. The adapter caches neither
results nor approvals. Preparation/invocation performance tuning is deferred.

## Proof and executable controls

Lean `Object.MethodCombination.collectFragments_append/coalesce` proves exact
source-order preservation for every selected method name. `fragmentSpecification_append`
connects local fragment blocks to the existing inherited SlotSpec semantics;
`declaredGeneric_standard/fragments` connects assembly to generic invocation with
the same complete receiver and established qualifier interpreter.

`Examples/DeclaredMethods.lean` proves the two-branch service's full standard trace,
current receiver result, around omission, primary refusal and missing-primary
behavior. It assumes a supplied correct C3 owner order; existing C3 proofs handle
linearization separately. It does not prove Gerbil macro expansion or all custom
policy callbacks. Gerbil `examples/declared-methods.ss` and
`t/method-declaration-test.ss` separately execute shared C3, descriptor invalidation,
actual `.defgeneric` syntax, recursive roots, every adapter, and negative admission.
No Lean checkout, serialized proof constant or compiler/runtime verification is
part of Scheme execution. No benchmark data or performance claim accompanies
this functional integration.

### Current combination selection and direct calls

`configured-summary-action` supplies the existing typed Reader workflow with
`configured-summary`, whose `combination:` expression reads the current public
`.summary-combination` slot. Hiding it refuses before method effects; restoring
or revising it permits the same retained action to retry using fresh context.
The normal fragment lookup and POO qualifier interpreters are unchanged.

The generic macro now lowers the whole transport directly through Gerbil's core
formal projection and `list`/`apply`, without constructing a temporary variadic
relay per call. Combiner selection precedes raw lookup, and raw lookup precedes
procedure admission even for a nonprocedure. The combiner receives the same
canonical keyword/rest application row and may return multiple values. Body and
lookup exceptions are never converted into missing-method defaults.

## Constructor admission and current callbacks

The exported existing `contribution` builder accepts a qualifier and procedure;
`make-family` and `make-reporting-family` accept it as a shared higher-order
builder for audited registration across the C3 diamond. Its revision-checked
admission uses standard weak-key tables. Current body grouping, Type/prototype
mutation and reflection refusal/retry remain observable; see
[the mechanism ledger](gerbil-mechanisms.md#revision-checked-contribution-admission).
The current workflow benchmark uses the same FUN action and generic on both
sides; its control constructs ordinary descriptors without registration evidence.

## Certified typed declarations

The existing `method` descriptor accepts a `signature`: an existing
`dispatch-extension.check` certificate. It fixes input/output Types, dispatch
arity, precedence, combination policy and negative watches in one shared seed.
Set `admit` to `metadata.declaration?`; `contributions` contains the existing
`declarative-metadata` declarations (`replace`, `contribute`, `guarded`, `remove`).
`typed-method-fragment` constructs exactly this same descriptor for computed names.
No second macro, dispatcher, edit interpreter or namespace is introduced.

```scheme
;; metadata., dispatch. and extension. denote the existing modules.
(def certified (extension.check
  (dispatch.prepared-standard [Integer] Integer (lambda (_) [['Number]])) []))
(def owner (.declare MethodDeclaration. (.o)
  (method .charge (.o (signature certified) (admit metadata.declaration?)
    (contributions [(metadata.replace "base" [(dispatch.prototype 'Number)]
      (combination.primary (lambda (_ n) (* n 10))))])))))
(.defgeneric (charge self units) slot: .charge combination: invoke-declared)
(defvalues (amount next) (charge owner 2))
(defvalues (again after) (invoke-declared next [3]))
```

Same-name typed fragments must share the **same certificate identity**, admission
callback and visibility. Inheritance also checks signature identity. Untyped and
typed groups cannot silently mix. Distinct certificates are distinct signatures,
even when their callbacks happen to agree on sampled arguments. Stored false is
invalid signature metadata; absence retains the ordinary untyped method protocol.

The ordinary Slot computes the complete inherited declaration stream. Ancestor
edits execute before derived edits, so a local replacement or erasure wins at its
path. Each batch keeps existing `declarative-metadata` edit order: `contribute`
prepends, `replace` replaces, and guarded contributions rerun their guards.
Gerbil `delay`/`force` owns one lazy installation and completed negative check per
assembled group. Intermediate inheritance groups remain unforced. Compilation
runs no method bodies; failed registration/negative admission returns no group
certificate, preserving existing failure phase/cause. It does not undo effects
of arbitrary user compile callbacks.

`.defgeneric` uses its existing `combination:` path and Gerbil formal binding,
including `from: type`'s original instance. `invoke-declared` validates the complete
argument row and result using the existing dispatcher, returning **two values**:
result and complete immutable successor group. Retain that successor for warm
calls. `declared-snapshot` exposes its existing dispatch certificate for ordinary
revision/publication; it forces compilation but invokes no method. No hidden
receiver mutation, dropped nested cache, result cache or cached guard approval
is introduced. Supported declaration edits invalidate the receiver's group;
explicitly retained old groups keep their immutable snapshot semantics. New
fragment membership still needs fresh elaboration. Source rows, watches, Types,
precedence and callbacks retain the existing immutable/pure certificate premises.

`make-dispatch-family` / `typed-charge-action` combine a shared C3 diamond,
two dispatch axes, standard qualifiers, a value-sensitive guard, FUN approval and
an IO consumer. `t/typed-method-declaration-test.ss` also checks every existing
combination policy, warm successor transfer, derived replacement/erasure,
completed-batch cancellation, refusal/retry, metadata invalidation, signature
conflicts, arity, output and original-instance binding. The Lean companion proves
transaction acceptance, batch equivalence, cache soundness, transported absence
and refusal retention; finite executable controls exercise two-axis cached calls.
These are generalized-prototype **future work**, not a claim that the article's
Racket code already supplies this declaration syntax. General carrier inference,
arbitrary compile-time multi-dispatch specialization and runtime/compiler
verification remain outside this closure.

## Type inference and parameter specialization

`instantiate-declared scheme arguments build [budget]` and
`infer-declared scheme candidates queries build [budget]` use the existing
prototype type constructors. Only a complete ground binding or a uniquely
completed finite search calls `build(instance)`. That ordinary higher-order
callback returns existing declaration forms; the usual MethodDeclaration
expander/finalizer elaborates them over the specialized prototype. No extra DSL
or independent inference engine is added.

`instance-signature instance precedence watches [combine accept prepare budget arity path]`
derives the actual dispatch input/output Types from checked ground Function
syntax. It recompiles that finite syntax instead of treating a caller-owned
`descriptor` field as authority. The default policy is existing standard method
combination; other existing combiners/carrier checks and optional preparers are
passed directly to the same dispatcher. Function options, ordered CaseFunction
and exact multiple outputs enter the same invocation/cache protocol (details
below). Non-Function outer syntax refuses as `unsupported`. Host signatures are
explicit descriptors, never inferred from procedures.

After expansion, finalized declarations cannot replace bound type-parameter
names or `.parameters`. The entry points prepare every typed group, including
hidden ones, without invoking method bodies or forcing unrelated computed fields.
The existing construction guard freezes context, source and completed receiver
during this work. Before returning, the entry points check that positional
parameters remain closed and every bound descriptor still has its captured
identity and direct revision. Compile callbacks therefore cannot silently change
the Types whose constraints were admitted. These checks do not certify arbitrary
transitive Type/callback dependencies; existing purity/stability premises remain.

Failure boundaries:

| Phase | Result |
| --- | --- |
| Type syntax/bounds/work | Existing `TypeRefusal`: malformed, unsupported, bounds or exhausted; no published declaration instance |
| Complete search | Existing no-solution/ambiguous report with `instance = #f`; builder is not called |
| Unique assignment | Builder runs once, after existing positional specialization |
| Expansion/registration/negative admission | Existing cause/phase propagates; no partially returned report or candidate |
| Bound field/descriptor revision or parameter reopening | `bounds` refusal before publication |
| Invocation | Existing current input/output validation, guard checks and complete cache successor |

Type requests retain their shared existing work counter. Prefix specialization,
residual inference and `instance-signature` are separately bounded requests,
with explicit budgets on each; arbitrary builder/validator/compile callback costs
are not claimed to be bounded by type-work units. Process heap/deadline limits
remain in the test/check harness. Earlier external callback/IO effects are not
rolled back on refusal.

`examples/polymorphic-services.ss` adds prefix/residual inference, prepared
qualified dispatch, FUN approval and an IO consumer. The focused regression
module covers nonunique/exhausted suppression, higher-order wrappers, literal
field labels, full/empty parameter suffixes, stale bindings, nonlocal overrides,
compile-time Type revisions, eager typed admission and ordinary laziness.


## Rich declared Function signatures

The explicit finite expression grammar now accepts the existing constructor
options and ordered `CaseFunction`, for example:

```scheme
(Function (Self (Function (Self) (Super))) (Super)
  optional: (Super) keywords: ((scale: . UInt))
  required-keywords: () rest: Super)
```

Each optional option can be omitted; defaults match `Function`. Keyword alists
use literal keyword names and Type expressions in their cdrs. These names and
`required-keywords:` never undergo Type substitution. Unknown/duplicate options,
invalid required keys and empty/nested CaseFunction clauses are malformed. A
CaseFunction contains a nonempty ordered sequence of ordinary Function terms.
Nested Functions in any input category or output retain recursive wrappers.

The existing finite candidate inference and ordered prefix specialization visit
all these Type positions. The subtype rule now checks complete ordered call-language
coverage under a shared keyword wire interpretation, exact-count covariant outputs,
and contravariant supplied positional/key inputs. Distinct required/optional/rest
layouts and disjoint reordered cases may replace each other when every selected
region passes. Overlapping cases preserve first selection; no failed type check
falls through. This does not infer host signatures/default effects or arbitrary
semantic predicate inclusion. See [the complete coverage protocol](prototype-types.md#ordered-case-call-language-coverage-and-replacement).

`instance-signature` uses the same sparse multi-dispatch and completed-candidate
negative checks. Its final optional `arity` argument selects the fixed number of
dispatch axes (default: first clause's required positional count), independently
of varying call lengths. Precedence/guards see the checked, keyword-escaped
supplied row; they must implement the same fixed axes for every admitted case.

The structural selector chooses the first matching case before Type checks. A
bad argument never falls through to another case. Missing/unknown/duplicate keys,
dangling keys and bad arity refuse before method bodies. Optional defaults stay
in the actual binding site: the target owns omitted defaults in a rest-forwarding
generic, while explicit `.defgeneric` formals resolve their own defaults once.
The target owns its actual procedure arity. Body/default exceptions preserve
identity. Output count and each output Type are checked after the effective
method returns; failures expose neither partial checked results nor a successor.
External effects are not rolled back.

`invoke-declared` returns **all user values followed by one group/cache owner**.
Zero user outputs therefore return only the owner. Direct `multimethod.call` on
`make-function` returns a checked result **list** plus owner; its immutable
certificate protocol always has those two transport values, even for a one-output declared signature. Existing low-level `make`
retains its scalar Result carrier; declarations uniformly use Function validation
and exact value counts through `make-function` in that same dispatcher.
Prepared and uncached standard/forwarding/inner continuations retain all results;
simple reductions still aggregate one policy result, and Simula returns Unit.
Those policies do not invent extra values for an incompatible output signature.

`examples/polymorphic-services.ss` connects residual inference, qualified methods,
`.defgeneric` optional/keyword/rest binding, a returned checked Function, FUN
approval and IO consumption. `t/inferred-declaration-test.ss` also covers varying
case result counts on one warm effective cache, zero values, literal keywords,
negative-watch refusal, explicit contexts, unchanged-owner retry and original
exception identity. These are regression controls, not performance measurements.

The companion `Functional.FunctionSignature` proves substitution preserves call
shape and ordered selection, conservative variance yields structural subtype
derivations, and result validation retains exact cardinality and successor only
on complete success. `invokeValues` proves selected input/body/count failures do
not enter a later overload. `Examples/TypedMethodDeclarations.lean` combines the
same rich schema with complete finite inference and original Self/Super bounds.
Host decoding, compiler expansion, arbitrary callback termination and transitive
Type stability remain premises; there is no Scheme dependency on a Lean checkout.
This advances the article's type-system/generalized-prototype future work, based
on Appendix B method combinations and Appendix C Self/Super constraints.

## Joint call inference and complete interface admission

`infer-prototype-calls scheme candidates observations [budget]` and
`infer-declared-calls scheme candidates observations build [budget]` collect
constraints from ordinary Function/CaseFunction syntax, then reuse the same
complete finite search and whole-receiver declaration driver. An observation is:

```scheme
(field-path supplied-Type-arguments expected-output-Types)
```

For example, the shared service in `examples/polymorphic-services.ss` uses:

```scheme
'(((.report) (Integer Integer scale: UInt Integer)
      (UInt (Function (UInt) (Integer))))
  ((.recover) (UInt UInt) (Integer Integer)))
```

The signature catalog is an existing `Object` Type expression whose explicit
fields contain Function/CaseFunction expressions. The empty path selects a root
Function; nested paths select explicit Object fields. The same `instance-signature`
accepts a final optional `path` after `arity`, so a builder can derive both typed
groups from the one completed instance and its shared bound parameters.

Gerbil's existing argument decoder, first structural selector and normalization
visitor handle required/optional/keyword/rest positions. Each supplied input Type
produces `actual <: formal`; each expected user result produces
`formal <: expected`. Missing optional arguments insert no defaults/constraints.
`#f` expected outputs means no return obligation; `()` requires exactly zero
outputs. Multiple outputs and higher-order Function variance use existing rules.
Actual/expected observations are explicit ground Type expressions, not inferred
from arbitrary values or host procedure bodies. Low-level `infer-prototype`
queries now allow declared variables on either side of an inequality.

All observations share ONE assignment and original subtype bounds. The selected
case is fixed by structural shape before candidate Type checks; rejection does
not try a later overlapping case. Signature projection needs an explicit known
Function kind/field path before binding: a root signature variable or a field
available only through an unresolved row tail is unsupported. Observation parsing,
constraint extraction, candidate enumeration, checking, Type compilation and
parameter binding consume one shared inference work counter. Declaration builders
retain their own existing admission budgets and the full watchdog/heap limits.

Successful, ambiguous and no-solution reports retain captured `calls` and generated
`queries`, in call order, with positional inputs, supplied keywords and expected
outputs ordered within each call. These are diagnostic snapshots,
not mutable proof authority. Changes to caller-owned lists after capture cannot
change the chosen assignment or recorded obligations.

### Whole interface, not just supplied fragments

In a declaration constructor, Function/CaseFunction leaves reached through Object
fields are REQUIRED typed method slots, including unobserved, nested and inherited
ones. A root Function requires a matching factory-derived typed group. Publishing
an Object catalog does not validate its ordinary data fields; those values remain
under the existing contract/recursive validation protocol and stay lazy here.

`instance-signature` stamps the newly compiled Function through the existing Type
MOP before publication. A private immutable record retains checked expression,
field path, exact descriptor identity and its final direct revision. No global
weak table or additional public namespace is used. A receiver is returned only
when every required group has the corresponding factory source, expression/path
and descriptor/revision. Missing siblings, plain procedures in typed method slots,
wrong paths, copied origin metadata and descriptor edits refuse as bounds.

The constructor captures expression and bound-parameter metadata BEFORE the
builder, retains the original bound-name frame, and rechecks the capture after
installation. Dropping a public snapshot entry cannot authorize overwriting its
parameter. Changing syntax temporarily while compiling, even if restored later,
cannot justify a method with a different private factory source.

Factory-owned groups retain the exact stamp across cache successors. Both
`declared-snapshot` and `invoke-declared` reject a directly revised descriptor.
Snapshot access rechecks after forcing its certificate too: deferred edit-compilation
hooks cannot revise a signature during cold admission and still expose a certificate.
A successful invocation rechecks before exposing user values/owner. A change
inside successful work therefore returns bounds, with no result/cache successor.
Body/validator exceptions keep their original cause. A retry must construct a
fresh checked group. External callback effects are not rolled back. These checks
do not certify transitive global Type/callback semantics or atomic revocation
against unsynchronized concurrent writes; those remain explicit premises.

### Acceptance and proof boundary

The worked service shares Self/Super across rich report and ordered recovery
signatures, derives the Integer/Super and return/Self inequalities automatically,
then composes both generics through FUN approval and IO consumption, retaining
both cache owners. Regression controls cover conflicting siblings, output-directed
inference, nested paths, ambiguity, refusal/exhaustion, incomplete catalogs, source
forgery/revision, callback-side mutation, inherited reuse and fresh reconstruction.

`Functional.FunctionSignature` proves no supplied input/result disappears from
collected obligations, first-case selection and complete joint collection.
`Functional.DeclarativeMetadata` proves unique builder provenance, original and
call-derived constraints under one environment, no contradictory accepted joint
solution, complete catalog coverage via the existing Parameters snapshot law,
captured source preservation and exact pre/post revision refusal/result transport.
Top-level `Examples/TypedMethodDeclarations.lean` combines actual specialization,
finite inference and two certified generic installations/invocations with these
admissions. Parser/descriptor projection, genuine host identities and faithful
revision observations are premises; there is no compiler or runtime proof or
end-to-end speed claim. This advances the article's type-system/generalized-
prototype future work from Appendix B combinations and Appendix C constraints.

Candidate-dependent call inference now resolves whole signature Types and Object
field/row layouts before invoking the same declaration builder. Alternatives keep
their own queries and normalized catalog, and complete sibling/source admission
is unchanged. See [prototype-types.md](prototype-types.md#candidate-dependent-signatures-and-field-layouts)
and `t/candidate-inference-test.ss` for finite scope and failure categories.


Cross-mode callback bounds now use the same two controlled coverage witnesses as
shared-mode inference: stable supplied outer Types for keyword source / positional
target, or clamped raw-length regions with actual ordered source selection for positional
source / keyword target. Fixed/optional and multiple case-lambda clauses may combine;
direct no-key minimum rows keep ordinary input variance, while other regions require
Any only at supplied positions. Candidate comparison neither constructs a
wrapper nor changes the original call row. Exact result count/variance, complete
search, prefix specialization, sibling/source admission and cache-owner gates
remain mandatory. See [prototype-types.md](prototype-types.md#ordered-case-call-language-coverage-and-replacement)
and `t/keyword-coverage-test.ss` / `t/keyword-prefix-test.ss` for FUN/refine/bind-evidence examples and refusal,
shadowing, escape and no-builder controls. General mixed-wire inclusion is outside
this conservative finite decision. This is hypothetical type-system future work.
