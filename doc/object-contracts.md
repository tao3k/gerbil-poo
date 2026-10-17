# Structural value contracts

`clan/poo/object-contract` exports `ObjectContract.`, `TypeContract.`,
`as-value-contract` and `diagnose`. These are ordinary POO Types and slot methods.
They have no dependency on POO Flow, module publication, graphs, provider schemas
or an admission-receipt framework.

For binding an existing invocation result to a subject, descriptor and context,
see [invocation evidence binding](evidence-binding.md). That operation belongs to
`declarative-metadata`; structural object contracts remain context-independent.

## Ordinary fields first

```scheme
(import :clan/poo/object :clan/poo/mop
        (only-in :clan/poo/type String)
        :clan/poo/object-contract)

(define-type (Port @ Type.)
  .element?: (lambda (value) (and (exact-integer? value) (<= 1 value 65535))))

(def ServiceContract
  (.cc ObjectContract.
       identity: 'service
       responsibilities: (.o host: String port: Port)))

(.def Service host: "127.0.0.1" port: 8080)
(element? ServiceContract Service) ; => #t
(diagnose ServiceContract Service) ; => ()
(eq? (validate ServiceContract Service) Service) ; => #t

(.def (Production @ Service) port: 443)
(diagnose ServiceContract Production) ; => ()
(diagnose ServiceContract (.o host: "127.0.0.1" port: "bad"))
;; => one type-rejected issue, path (port)
(diagnose ServiceContract (.o host: "127.0.0.1"))
;; => one missing-field issue, path (port)
```

Direct assignment replaces the complete port value. The other inherited fields
remain available. Responsibilities are a POO map of required field names to
existing Types. A Type without diagnostics is adapted automatically; a diagnostic
Type is reused. Unknown candidate fields are rejected by default, without forcing
the unknown field's value. Nested diagnostic paths are prefixed by the caller's
optional path: `(diagnose contract value '(config service))`.

`diagnose` returns a list of POO objects with Symbol `kind` and list `path` slots.
Additional fields can carry expected Types or domain diagnostics. It does not
add raw candidate values to generic diagnostics. Empty means conformance; a
nonempty list means rejection. Invalid declarations, malformed diagnostic
callbacks and unexpected exceptions remain programming errors, not user-field
failures. Custom diagnostic Types must make their membership and diagnostic
decisions agree; supplying a method cannot prove its correctness.

## Existing Type and invocation contracts remain authoritative

`TypeContract.` delegates `.element?` **and `.validate`** to its `expected-type`.
For a Function Type, membership can only recognize a procedure; validation keeps
the existing checked input/output wrapper. `diagnose` and `.element?` remain
recognizers. Explicit `validate` recursively validates declared ObjectContract
responsibilities and installs any changed fields in a persistent derived object;
consumers must use that returned value. Untouched scalar objects keep identity.

The existing `declarative-metadata` invocation Contract composes directly:

```scheme
(import (prefix-in :clan/poo/declarative-metadata metadata.))
(def ServiceCall
  (metadata.contract (metadata.typed "service input" ServiceContract)
                     (metadata.typed "boolean output" Bool)
                     (lambda (_atom _args _result) #t)
                     metadata.truth))

(metadata.invoke ServiceCall
  (lambda (_service) (values #t 'current-state)) Production)
;; => #t, current-state
;; Invalid service input is refused before the callback executes.
```

This uses the existing input/output checks and refusal phases. There is no second
invocation wrapper, predicate registry, effect system or method-registration path.
`ObjectContract.` checks a value; invocation `Contract.` checks a call. Neither
alone establishes source authenticity, current deployment state or authorization.

## Extensible data and relationships

The default `extra-fields: 'reject` policy checks exactly the required field
inventory. Optional/default semantics are not inferred from missing slots.
For an external Schema Type that owns the full field policy, use:

```scheme
;; ExternalInput is a well-formed Type supplied by a separate schema library.
;; No Schema compiler or provider policy is implemented in object-contract.
(.cc ObjectContract.
     identity: 'external-input
     extra-fields: 'delegate
     constraints: (list ExternalInput))
```

Delegation requires at least one explicit constraint. Plain Types in constraints
are adapted too; diagnostic Types retain their methods and paths. Whether a
constraint permits extra fields is its own policy, not an automatic guarantee
of closed Schema checking. A schema adapter can retain provider diagnostic data
in each issue without coupling this public library to its representation.

`obligations` is a named pure function or ordinary procedure taking the final
candidate and diagnostic path. It returns the same issue-list format and runs
only after structural and whole-value constraints succeed. Use it for relations
among fields; domain libraries own cloud/network/service policies. Test counters
do not make effects part of the production obligation contract.

## Prototype requirements are optional

`required-prototype: #f` is the default. Independently authored objects may conform
without inheriting a shared default object. Set a prototype only when a consumer
requires its inherited implementation family:

```scheme
(def FamilyContract (.cc ServiceContract required-prototype: Service))
(element? FamilyContract Production) ; => #t
(element? FamilyContract (.o host: "127.0.0.1" port: 443)) ; => #f
```

The ancestry check happens before candidate field demand. Shape checking still
runs on a correctly derived object. Ancestry is not proof that arbitrary behavior
is safe, nor is it a module origin or contract-publication association.

## Laziness, inheritance and evidence

Prepared responsibility/constraint maps are lazy slots on the effective Contract
receiver. Deriving a descriptor uses its current declarations even after a parent
map was forced. Candidate values are demanded by declared fields and explicit
constraints, not by a global catalog traversal. A schema constraint may deliberately
demand a whole selected input. First preparation and field inventory checks have
costs; no startup or constant-time performance improvement is claimed.

For immutable configuration, ordinary derived objects retain receiver-aware
resource calculations. A fixed value explicitly captured from a parent remains
that parent's value. This module does not cache accepted results, authenticate
receipts, discover external dependencies or invalidate a consumer's cache. Those
policies belong to the consuming application. Mutation after observation and
custom MOP overrides require the corresponding object's normal revision rules.

Generic method implementations can be extended like other POO behavior. Such
extensions must preserve the documented protocol; the library cannot prove that
arbitrary overrides retain mandatory application requirements.

## Scheme controls

`t/object-contract-test.ss` covers positive/negative Type adaptation, Function
validation, spelling/missing/nested fields, optional ancestry, parent/child
prepared maps and constraints, external diagnostic Types, malformed callbacks,
existing invocation Contract integration and a parent-cached resource projection.
Run it through the repository's existing `just test-file` entrypoint. Tests are
Scheme `:std/test`; no Python or additional shell test runner is introduced.

Local qualification on base `ebe17df` passed all 14 object-contract cases from
source and again with the newly compiled module selected. An import-path control
confirmed the compiled SSI, rather than a fallback source copy. Existing MOP
(6 cases), Type (10 cases) and declarative-metadata (6 cases) suites also passed.
These are focused local results, not a full-package or remote CI result. The new
test is registered in the existing Bazel contracts group; no Bazel build was run
as part of this qualification.

These controls establish the tested library behavior. They do not qualify a
live provider Schema, complete dependency discovery, higher-order blame theory,
automatic provenance capture, runtime Loader or deployment consumer.

## Diagnostic phases and FUN composition

`object-diagnostics` exports `diagnostic-all` (ordered accumulation) and
`diagnostic-then` (gate the next phase). Both are higher-order procedures prepared
once for immutable declarations. Ordinary diagnostic lists accumulate; unexpected
exceptions propagate unchanged, and malformed callback results remain errors.
`ObjectContract.` prepares its whole-value constraints and obligations through
these combinators in a receiver-local slot, including for derived descriptors.

`object-contract-flow` exports `checked-action`. It uses the existing `Observation.`
Reader/FUN bind: validate this invocation's candidate, then invoke the consumer on
that exact validated/normalized value. There is no accepted-value cache. Function
Types therefore retain their wrapped function at this explicit execution boundary;
multiple consumer return values and original validation exceptions are preserved.

`examples/object-contracts.ss` combines existing Json I/O, key-preserving object
construction, shape admission, persistent lens revision, two accumulated relations
and checked output. Shape admission precedes arithmetic; relation repair can happen
before the complete contract is demanded. Invalid data never reaches the consumer.
`t/object-contract-flow-test.ss` adds eight composed cases to the original fourteen.

The companion `ObjectDiagnostics` / `ObjectContract` models prove ordered
accumulation, phase gating, exact required-field existence, strict inventory,
independence from undeclared lookup values, recognizer/diagnostic equivalence under
an explicit law, and original-error/exact-normalization handling. The existing
invocation Predicate is reused. Scheme has no build dependency on that checkout.

Descriptor inheritance is not automatic logical refinement: overrides can weaken
requirements. Compose independent obligations explicitly to retain them. Callbacks
must satisfy their Type recognition and diagnostic path laws, and declarations
must remain immutable while used. The model proves finite observations and pure
reports, not arbitrary callback termination, subtype inference or runtime behavior.
This develops section 5's type-descriptor operations and Appendix B's future work;
the remaining general type-system and generator TODOs stay open.

The companion service fixture uses all five fields, Int-valued capacity/use and
the exact 1–65535 port interval. A separate port-recognizer equivalence theorem
and paired lower/upper-bound and negative-use controls prevent the worked examples
from silently accepting different domains. These do not prove the JSON parser.

## Explicitly strengthen an effective descriptor

`(refine descriptor additional-diagnostics)` retains the original structural
contract and adds a gated obligation phase. Unlike ordinary override, it cannot
admit a value the original contract refused. Existing issue lists are retained
exactly; the new callback sees the same value and path only after success. The
callback can use `diagnostic-all` to accumulate independent new obligations.

The implementation uses the existing `=>` inherited-computation syntax. It does
not capture a prepared parent's callback; later receiver-dependent declarations
remain effective. `.cc` metadata copies are supported through the existing
structural descriptor slots, without assuming nominal ancestry. Arbitrary custom
`.diagnose` overrides must obey this protocol; no runtime subtype inference is
provided. Added callbacks remain pure and descriptors immutable during use.

`examples/contract-publication.ss` combines explicit capacity strengthening,
`checked-action` FUN admission and the existing `bind-evidence` / `publish`
protocol. Invalid input suppresses the producer; stale context refuses the
tentative result and returns the old state; a newly bound current invocation can
retry. A producer's external effects are not undone. See
[evidence-binding.md](evidence-binding.md) for identity and authority boundaries.

Lean `ObjectContractRefinement` proves exact phase composition, acceptance
conjunction, rejection preservation and associativity. `EvidenceBinding` proves
original-rule preservation, exact reference association and old-state retention
on mismatch, assuming identity carriers and a total pure projection. These are
future-work extensions of the paper's descriptor constructions, not claims that
the original Racket API contained these helpers.

## Nested Function fields, refinement and publication

`object-contract-validation` prepares the effective field validators once per
receiver. Validation has three stages:

1. Recursively check object/prototype/inventory and leaf membership, without
   running nested whole-object obligations on raw procedure fields.
2. Validate inherited field results through their existing Type `.validate` on
   one fresh receiver. Computed dependencies request checked siblings through the
   ordinary slot cache; a dependency may force a later declared field first.
   Nested ObjectContracts recurse; Function Types supply their existing wrappers.
   Force every selected check before final admission. Inheriting the source
   preserves ancestry; no changes return the original object.
3. Run complete diagnostics, constraints and `refine` on the final object. Nested
   refinement therefore observes wrapped fields. A refusal returns no candidate.

`examples/function-publication.ss` composes JSON service input, a nested engine,
multiple returned values, a callback factory, cross-object refinement and FUN
publication. `bind-evidence` receives the actual normalized root. An evidence
record naming the raw source, a different descriptor or an old context fails;
retry starts from the current invocation template. Callback errors preserve the
old returned state, without undoing effects that the callback already performed.
`t/object-contract-validation-test.ss` includes these negative controls, input
and output arity, higher-order inputs/results, original exception identity,
prototype preservation and derived-descriptor preparation.

The corresponding Lean modules are `FunctionValidation` and
`ObjectContractValidation`. They prove pure input/source/output gating, exact
error retention, all-or-error field batching, normalized final refinement and
composition with exact-reference evidence. Representation lookup laws and the
mapping from model references to immutable Scheme identities are explicit
premises. The executable example models dynamic scalar rows and checked callbacks;
it does not verify the JSON parser or host runtime.

This advances the generalized-prototype future work using the paper's section 5
recognizer/validator distinction and existing Function descriptors. It does not
provide general higher-order blame, wrapper deduplication, variadic/keyword
Function descriptors, unregistered recursive cyclic object closure, or automatic validation
inside every possible container family. Custom validators/getters retain
their effects and termination obligations. Revalidation may wrap again; no
accepted-value cache is added. Nested obligations may be checked more than once.

## List, Tuple and finite named-field schemas

Existing `type.List` and `type.Tuple` now supply `.validate`, `.diagnose` and
`.diagnose-shape`. Their public constructors and representations are unchanged:
List uses proper Scheme lists; Tuple uses vectors with exact heterogeneous arity.
`type-validation` shares recursive structural traversal with ObjectContract.
Diagnostics append zero-based indices to field paths, including across nested
containers and schemas. Recognition never installs wrappers.

Explicit validation first checks the complete reachable structure, then validates
children in order using their existing Type methods, then checks final membership.
List uses the standard `map-in-order`; Tuple uses the existing indexed vector
iterator and a private vector. Source carriers are not mutated. A changed batch
returns its complete normalized container; unchanged children retain the source
container identity. There is no returned prefix on failure. Prepared descriptor
methods remain receiver-local, including after parent preparation.

A finite named-field schema is the existing ObjectContract responsibilities map,
not a second schema language or registry. Its whole-object obligations and `refine`
run after its nested container fields are normalized. Schema descriptors can also
appear inside List and Tuple; structural traversal defers their whole-object
obligations until wrapping. External schema Types must provide their own validation
and structural traversal adapters; this does not implement an external Schema DSL.

`examples/container-publication.ss` composes JSON input with List → TaskSchema →
Tuple → List of Function transforms, multiple callback results, cross-task tenant
refinement, and FUN publication bound to the actual normalized root. Tests cover
deep paths, empty containers, improper lists, wrong tuple carrier/arity, complete
shape gating, first exception identity/order, higher-order results, raw/stale
binding refusal and repair/retry. Custom callback effects are not rolled back.

Lean `ContainerValidation` proves ordered per-position normalization, preserved
length, unchanged-value preservation, arity refusal before zip/validation, exact
tuple positions, final-check acceptance, child refusal and schema refinement.
It reuses `Validation`, `ObjectContractValidation` and existing binding laws.
`Examples/ContainerContracts.lean` runs a matching nested dispatch/transform batch
and refusal/retry controls. The tagged finite model uses rows for vectors and IDs
for Scheme identities; it does not prove host representation, GC, parser or runtime.

The paper's section 5 Racket `ListOf` supplies recursive membership, while its
more elaborate Type discussion covers functions and objects with typed slots.
Recursive wrapping here advances the generalized-prototype future work. Remaining
work includes arbitrary external schema adapters, unregistered cyclic object/container closure, wrapper deduplication, optional
or keyword arities and higher-order blame. Caller immutability and custom Type
agreement/termination remain required. No persistent validation cache is added.

## Pair, Map, Sum and ordered Union normalization

`variant-validation` reuses the shared structural/Type validation protocol;
`type.Pair`, `Map`, `Sum` and `Union` keep their existing representations.

- Pair accepts proper or improper cons cells. It checks the full reachable
  structure before validating car then cdr; changed components produce one cons.
- Map checks every key/value shape before wrapping. Each snapshot entry validates
  key before value. `hash-new` retains the source table's comparison/hash policy.
  Changed keys are installed only if none collide under that policy. Failure
  exposes no replacement table and never overwrites the source. Validation order
  across entries is the host snapshot order, not a portable scheduling guarantee.
  Paths use snapshot index then `key`/`value`, without retaining raw keys.
- Sum checks carrier and symbol tag before demanding payload. Only that tag's
  Type validates the payload, and the returned value is actually installed. A
  replacement inherits the source, retaining ancestry and other lazy fields.
  The selected tag is frozen alongside the checked payload so a computed tag
  cannot silently reselect a different branch after wrapping.
- Union retains existential membership for recognition. Validation commits to
  the first structurally matching alternative in declaration order; whole-object
  refinement is deferred until wrapping. After selection, an exception or Type
  refusal cannot fall through to Any or another branch. The normalized result
  must satisfy the selected branch, even if a later branch would accept it.

Thus Union recognition and validation have deliberately different roles: raw
membership does not imply successful committed normalization. Broad alternatives
should be declared after specific ones when checked wrapping is desired. This
also handles overlapping Function branches deterministically; it does not infer
which future call signature the caller intended. Union JSON conversion retains
its existing separate dispatch; this change does not serialize executable values.

`examples/variant-publication.ss` composes Pair → Map → Sum → Union → refined
named Function schema, a separate approval Function, data-only JSON configuration,
root tenant refinement and FUN/bind-evidence publication. Explicit route names
control execution order. Tests cover improper Pairs, Function keys/values, custom
table comparison, normalized-key collisions, unknown/non-symbol tags without
payload demand, Sum ancestry, ordered Union overlap, selected-error preservation,
selected-result rejection, complete structural gating, raw/stale binding refusal
and callback repair/retry. No accepted-value or branch-choice cache is introduced.

Lean `VariantValidation` proves Pair components/errors, collision exclusion and
position/length preservation for normalized map snapshots, Sum tag retention and
payload errors, ordered Union selection, no-match refusal and no failure fallback.
The existing final-refinement and exact-reference binding laws compose with these
normalizers. `Examples/VariantContracts.lean` exercises the corresponding routing
batch, data variants, collisions, committed refusal, output failure and publication
retry. Its fixed configuration uses tenant `api`; table equality and immutable
reference correspondence remain adapter premises. The snapshot model does not
certify the host hash implementation or portable hash traversal order.

These normalizers advance the paper's generalized-prototype future work using
its section 5 Type/recognizer and dict/object/function constructions. Other Type
families, arbitrary external schema adapters, unregistered cyclic closure, wrapper deduplication,
optional/keyword arities, higher-order blame and effect rollback remain open.

## Maybe, OrFalse and dependent TypeValuePair

`optional-validation` reuses shared structural traversal and the existing Type
methods. `Maybe` keeps `(void)` as absence; `OrFalse` keeps `#f`. Their absent
branches return the original sentinel without even looking up the child Type.
Maybe Bool therefore retains `#f` as a present Boolean; OrFalse's representation
cannot distinguish a false payload from absence. No new tagged representation
or serialization format is introduced.

Present branches recursively validate their selected child and recheck THAT
child's returned membership before outer admission. A broken Function validator
cannot return void/#f and thereby escape into outer absence. A child that itself
accepts such a sentinel may intentionally normalize to it; presence preservation
is not asserted for arbitrary custom normalizers. Original child exceptions remain
unchanged. Void and false branches do not call custom validators; effects from previously
executed callbacks are not undone.

TypeValuePair previously validated the whole pair as its carried Type. It now
checks the Type before payload traversal, validates the cdr, and returns a pair
with the exact original Type and actual normalized value. An unchanged payload
keeps pair identity. Invalid Types gate payload work; diagnostics retain car/cdr
paths. Nested refinements receive checked callback fields, including when the
carried Type is itself an ObjectContract or another container. TypeValuePair has
no global catalog of permitted Types: each consumer owns its accepted interface.

`examples/optional-publication.ss` composes Maybe → List → Tuple → TypeValuePair
plugins with OrFalse → Maybe fallback, JSON configuration, root `refine`, ordered
FUN execution and `bind-evidence` on the exact final root. The worked consumer
explicitly allows its Transform interface, independently of generic Type validity.
Tests cover sentinel distinction and lazy child bypass, bad-result erasure,
original exceptions, complete shape gating, higher-order/multiple outputs, refined
carried schemas, unknown interfaces, raw/stale evidence refusal and repaired retry.

Lean `OptionalValidation` proves absent identity, present shape/error gating,
selected-child membership and acceptance, invalid-Type refusal, exact descriptor
retention and successful/failed dependent payload normalization. Existing final
refinement and binding laws compose with it. `Examples/OptionalContracts.lean`
executes the corresponding pipeline and no-plugin/fallback paths, including
unchanged reference IDs when no known Function wrapper is introduced. Descriptor
and reference tokens are supplied interpretations; host identity and allocation,
JSON parsing, the runtime and external effect rollback are not proved.

This advances the paper's section 5 descriptor/generalized-prototype future work.
Arbitrary external schema adapters, unregistered cyclic closure, wrapper deduplication, optional/keyword Function arities,
higher-order blame and general callback termination remain open. Existing I/O
capabilities/limitations, including executable value serialization, are unchanged.


## Record / Class recursive initialization

`class-validation.ss` reuses the effective Slot protocols and recursive structure
visitor. `.slot.shape` checks required/optional fields and constants; the complete
structure pass precedes all `.slot.validate` calls. Present fields normalize
through their selected child Type on one persistent derived receiver, retaining
computed dependencies rather than installing frozen getter results. Final Class membership retains custom Slot checks, sealing and
constant equality. Unknown sealed fields are rejected by inventory without forcing
their getters. `value-diagnostics.ss` keeps this protocol below the MOP dependency.

`make-instance` / `.new/checked` receive prototype defaults and overrides, validate
them, invoke `.instantiate` with the checked instance, then validate its result.
Returning the same object does not skip validation: a hook may have mutated it.
`instance` / `.new` remain lazy constructors. Type's bootstrap validation preserves
the original descriptor identity and does not wrap its metalevel `.element?`.
Record's existing single/multiple C3 metadata composition is reused; overrides,
diamonds and parent-prototype-first observations have executable controls. This
is structural inheritance, not an additional nominal ancestry guarantee.

`examples/class-publication.ss` combines inherited callable defaults, a computed
audit, optional Function plugin lists, initialization replacement, root refinement
and FUN publication with exact `bind-evidence`. Tests include nested List/Tuple/
TypeValuePair defaults, refined nested schemas, custom Slot dispatch, same-object
hook mutation, wrong Function rows, raw/stale evidence refusal and repaired retry.

These additions advance section 5 type descriptors and the generalized MOP future
work. The Lean companion proves finite pure Slot/initialization/refinement laws
and executes a corresponding service workflow; Scheme has no Lean checkout
requirement. Supplied C3 resolution, prototype defaults, host identity, arbitrary
lexical capture rebinding, unregistered cyclic closure, callback termination, GC and external
effect rollback are not proved. The original example's computed audit captures
unchanged scalar state; the extension below covers final-self dependencies. Constants keep exact equality before and after normalization: if wrapping
changes that equality, validation refuses (including such Function constants).
Wrapper canonicalization/deduplication, arbitrary external adapters and optional/
keyword Function arities remain open. Executable-value serialization is unchanged.


## Receiver-bound computed validation

`validation-rebinding.ss` now supplies one higher-order normalizer for Class and
ObjectContract. Each selected field is an ordinary `$computed-slot-spec` layer:
its inherited result is validated with the final receiver. Inherited formulas,
computed closure capture and custom Slot dependencies all use checked siblings.
Every selected field is forced before final membership/refinement; normal object
caches share repeated reads and `CyclicSlot` rejects active cycles. No old computed
cache is copied. Explicit `.put!` instance assignments are retained as constant
specifications by `object-override-specifications`; ordinary inheritance semantics
for those assignments is unchanged. Source ancestry is retained, and all-unchanged
validation returns the source.

Slot `.slot.validate` takes `(slot name original receiver)`: `original` is the
inherited raw value, while `receiver` supplies checked siblings. This directly
replaces its earlier candidate-read convention, which would recursively read the
currently active slot. Custom Slot implementations in the tests use this protocol.
Validators can run in dependency order, not necessarily declaration order.

`examples/computed-publication.ss` composes Record metadata selection and an
explicit inherited prototype/super formula, hook replacement of backend/bias,
computed captured delegates and Function lists, a Function returning a Function,
root `refine`, FUN and `bind-evidence`. Record metadata does not implicitly gain
new super-thunk semantics. Controls cover source caches, inherited overrides,
hook mutation, repeated admission, custom sibling reads, cycles, original context
on callback refusal, repaired retry and raw/stale evidence refusal.

Paper correspondence: section 2's shared final `self` / late binding supplies the
receiver rule; section 5 supplies callable/typed-slot descriptors. This generalized
MOP extension advances future work. The independent Lean module
`Functional.ValidationRebinding` proves eleven request/validation, dependency,
inheritance, memo and batch-refusal laws using existing recursive interactions and
certified memo. `Examples/ComputedContracts.lean` proves its concrete alias law
and executes the matching 46/8 workflow, nested Function guard and publication
controls. Neither the Scheme build nor its tests require a Lean checkout.

Limits: global structural getters still run on the raw source before wrapping.
Getter/validator effects and general callback termination are caller obligations;
a callback may retain its private receiver, and external effects do not roll back.
Arbitrary lexical snapshots cannot be rebound. Existing constants retain strict
equality; unregistered cyclic object closure and wrapper canonicalization are still open.
Fresh immutable source/descriptor/context correspondence and finite terminating
getters remain required. This is not mutable freshness after admission, automatic
revalidation after revision, or a host/runtime/GC performance proof.


## Controlled recursive graph closure

Finite explicitly named recursive object graphs now use `recursive-validation.ss`:
Class and ObjectContract share field preparation, all receiver identities are
allocated before edge normalization, and nested whole-value obligations wait for
all node batches. Canonical references preserve named sharing/backedges; all nodes,
including unobserved targets, must finally pass. Later Reference validation retains
canonical identity and rechecks admission/current revision stamps. Ordinary
validation outside this explicit scope remains immediate.

`examples/recursive-validation.ss` combines productive computed peer Functions,
existing positive least closure, safe recursive memo, FUN, root refinement and exact
evidence. Immediate eager getter cycles still reject. Cross-owner descriptors,
missing targets, failed deferred queues and stale graphs cannot return a closed
value. Scope, API and Racket/Lean/Gerbil correspondence are documented in
[recursive-validation.md](recursive-validation.md). This advances generalized MOP
future work; unregistered/coinductive recursion, arbitrary callback termination,
external effects and concurrent mutation remain outside the proof.


## Continuing request admission during publication

`recursive-approvals.call-with-submissions` now admits fresh explicitly staged
requests while older requests remain queued, using the standard queue and existing
per-attempt publication/receipt path. Eight actual SCC/provider/computed rounds
exercise 64 attempts, repeated installed/proposed approval ABA, joint refusal,
stale competitors, dirty old references and effect-only refine/bind-evidence retry.
Scope controls reject reentrancy, escaped operations and unconsumed normal exit;
exceptions retain installed prefixes. Eight Lean FIFO/monotonicity/staleness laws
and the matching finite fixture cover this serialized generalized MOP future work.
See [recursive-submissions.md](recursive-submissions.md) for API and proof limits.
