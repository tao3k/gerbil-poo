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

`instance-signature instance precedence watches [combine accept prepare budget]`
derives the actual dispatch input/output Types from checked ground Function
syntax. It recompiles that finite syntax instead of treating a caller-owned
`descriptor` field as authority. The default policy is existing standard method
combination; other existing combiners/carrier checks and optional preparers are
passed directly to the same dispatcher. This bridge accepts fixed Function rows
with **one Result carrier**, including higher-order Function/container/row Types.
Zero/multiple outputs and non-Function outer syntax refuse as `unsupported`.
It does not infer keyword/rest/case-lambda host signatures from procedures.

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
