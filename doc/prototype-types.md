# Bounded prototype polymorphism, subtyping and inference

For the Object/row and guarded Mu extensions, see [row-types.md](row-types.md).

This implements a decidable part of the original type-system **future work**.
The Racket discussion in “Prototypes are Useful Even Without Subtyping”, “Type
Descriptors” and Appendix C/D motivates explicit universal Self/Super parameters,
subtype constraints and `(Proto A B) = (Fun A B -> A)` with `A <: B`.
It does not provide the following solver as an existing paper implementation.

Map-key invariance below applies to potentially inhabited entries; the final
necessarily-empty Map section gives the explicit positive-witness exception.

## Module interfaces

The `types/` directory owns the shared type protocol: `syntax.ss` admits and
transforms bounded metadata, `relation.ss` checks inclusion and compiles existing
descriptors, and `validation.ss` performs recursive container validation. Import
the module for the required responsibility; the root `type.ss` remains the
executable descriptor interface. Build inputs and CI cache keys include `types/`.

## One composable protocol

`types/relation.ss` admits this finite expression grammar:

```scheme
Any | Never | Bool | Integer | UInt | Keyword | String | Symbol | declared-variable
(List T)
(Tuple T ...)
(Pair T T)
(Map Value <- Key) | (Map Key -> Value)
(Sum tag: T ...)
(Union T ...)
(Record ((name T required-or-optional) ...) open-or-closed)
(Function (output ...) (input ...))
```

The Function ordering is exactly the existing descriptor constructor's outputs,
then inputs; the corresponding paper notation is `(Fun input ... -> output ...)`.
There is no second executable Function representation. `expression-type` compiles
only ground expressions through the existing Type/List/Tuple/Function constructors.
`UInt` now checks nonnegative exact integers rather than inheriting Integer's
recognizer unchanged; zero and negative output controls exercise this distinction.

`subtype-expression? source target [budget]` decides **derivability in this
algebra**. Rules are reflexivity, Any as top, UInt <: Integer, covariant List/Tuple
observations, and Function argument contravariance/result covariance. Tuple width
and Function input/output counts match exactly. It does not treat mutable slot
writes as covariant or infer semantic relations from prototype ancestry.
A negative judgment means no derivation here, not a counterexample to an arbitrary
semantic implication. Unsupported descriptors are refused even against Any.

`prototype-types.ss` connects that algebra to `parameters.ss`:

```scheme
(prototype-type prototype '(Self Super)
  '(Function (Self) (Self Super)) '((Self Super)))
```

Variables are unique and exactly match the prototype's `.parameters`. Constraints
are two-expression lists, representing the paper's `<:` relation. Explicit
`instantiate-prototype` checks complete ordered ground substitutions and every
bound before compiling the descriptor and calling ordinary persistent `specialize`.
The instance retains `prototype`, `descriptor`, `expression` and `substitution`.
Inherited/computed fields continue to use the final specialized receiver.

`infer-prototype scheme candidates queries [budget]` enumerates the Cartesian
product of a **finite, explicit ground universe**, deduplicating equal candidates.
Queries are `(source target)` inequalities; either side may contain declared
variables. These join the scheme's bounds. Only complete unique
inference constructs an instance. Several valid assignments remain ambiguous;
there is no first-match guess, sample-based inference, principal-type assertion,
implicit widening, or inference of arbitrary predicate implication.

`examples/polymorphic-services.ss` supplies both the appendix's higher-order
function prototype and a service whose output is narrower than its input. Existing
`checked-action` Reader/FUN sequencing recursively wraps Function fields before
`refine` whole-object checks. Exact `bind-evidence` subject/descriptor/context
identity then guards the existing publisher. Stale context refuses publication and
preserves the old state. There is no new monad, evidence authority or global cache.

## Bounds and failure semantics

The default shared work budget is 8192; admitted range is 1..1048576. One counter
covers input-pair preflight, expression/constraint checks, structural comparisons,
substitution, candidate search nodes, and descriptor compilation across the whole
request. Checking and compilation do not reset the inference counter. Syntax
preflight has maximum pair-tree depth 64, including list spines; cyclic syntax
refuses before list traversal, substitution or descriptor callbacks.

| Outcome | Meaning / exposed result |
| --- | --- |
| subtype true / false | Derived / not derived within the admitted algebra |
| unique | Exactly one complete candidate assignment; carries one instance |
| no-solution | Completed finite search with no assignment; no instance |
| ambiguous | Completed finite search with multiple assignments; no instance |
| TypeRefusal `exhausted` | Work or syntax-depth limit; no partial candidate/instance |
| TypeRefusal `unsupported` | Unknown atom, constructor or unsupported signature form |
| TypeRefusal `malformed` | Invalid declaration, variable set, arity or configuration |
| TypeRefusal `bounds` | Explicit substitution violates a declared inequality |
| Existing validation/body error | Original exception propagates; no retry/fallback |

`type-refusal?` / `type-refusal-kind` inspect controlled refusal without parsing
messages. Every schema is revalidated and its expression/bounds copied on entry;
mutable public metadata is not a durable proof token. Original source lists cannot
silently rewrite the captured syntax. Stable schema/prototype metadata and standard
Type definitions during each sequential request remain premises. There is no atomic
concurrent mutation claim. Previously returned instances never grant fresh evidence
for a different descriptor/context identity.

Rank-two/higher polymorphism, unrestricted recursive type equations/carriers,
unbounded row inference, dependent/effect inference, user-defined predicate
implication and optional/keyword/rest/CaseFunction **subtyping** remain outside this
algebra. Those existing executable Function forms still work through their own
validators; this judgment refuses unsupported syntax. Runtime values are always
validated/wrapped through their instantiated descriptor: a subtype result never
bypasses validation or proves host arity, termination, effects or cached evidence.
Finite bookkeeping bounds do not bound arbitrary computed-slot/consumer callbacks;
process timeouts and heap limits remain mandatory and unchanged.

## Three-way evidence and acceptance

The Gerbil focused suite covers primitive inclusion and negative UInt values,
nested Function variance, exact output counts, explicit bound refusal, higher-order
Proto specialization, complete unique/ambiguous/empty search, recursive Function
wrapping in containers, refine/FUN consumption, and exact evidence publication.
Resource and unsupported controls are distinct from negative derivability.

The companion Lean module `Functional.PrototypeTypes` independently defines the
finite algebra, declarative Subtype, sound bounded checker, substitution, complete
finite inference and refusal. Proofs establish checked derivations, **conditional**
semantic replacement, every inferred constraint, unique candidate validity,
no-solution exclusion within the supplied universe, and incomplete-search refusal.
Its interpretation explicitly requires behavioral Function variance; Scheme's
`procedure?` recognizer alone cannot discharge that premise. A separate mathematical
arrow theorem states input/output replacement directly. `Examples/PrototypeTypes`
uses the same nested service signatures and finite Self/Super candidate constraints.

This is a correspondence of named rules and controlled outcomes, not a verified
Gerbil compiler, exact runtime cost model, or proof of all Type-system future work.
Lean's fuel bounds derivation depth / abstract assignment scans; Gerbil additionally
charges syntax, search and compilation visits. No Scheme test or library imports a
Lean checkout. Full existing single-process tests and Lean resource-guarded checks
remain required; focused controls do not replace either gate.

## Residual prefix schemas

`specialize-prototype-type scheme prefix [budget]` binds only a ground ordered
Type prefix using the existing positional `specialize`. It substitutes that
prefix into the expression and **each side** of every bound, preserving field
labels and binders through existing capture-free substitution. Remaining names
must still match the specialized prototype's `.parameters`.

A partial schema is a residual obligation, not an approved instance: constraints
that still depend on the suffix are enforced by complete instantiation/inference.
A complete prefix checks all bounds before binding. Residual queries use remaining
variable names or ground syntax; fixed parameter names remain receiver fields,
but are no longer free variables in the residual syntax. An empty variable list
has one empty assignment, even with an empty candidate universe.

Schemas and completed instances retain `bound-parameters` metadata. Private
binding records store each assigned descriptor identity and direct revision;
`bound-parameters(instance)` returns copied names after current checks. Every
later specialization/inference rechecks the binding snapshots. Supported changes
of a bound field or its descriptor reject as stale bounds rather than borrowing
an earlier type derivation. Direct raw setters and arbitrary transitive callback
semantics are outside this source discipline.

The complete declaration bridge is documented in
[method-declarations.md](method-declarations.md). Its finite search has no
principal-type or unrestricted predicate/recursive inference claim. Lean proves
prefix environment preservation, original-constraint entailment, suppression on
incomplete/nonunique searches, successful builder provenance, positional frame
laws and final identity/revision admission under the supplied source model.


## Rich declared Function signatures

Finite expressions also accept Function optional/keyword/rest options and ordered
CaseFunction clauses. Prefix specialization and finite inference traverse every
Type position while preserving literal keyword metadata. Call-language inclusion now admits different required/optional/rest regions and
ordered case layouts under shared or certified cross-mode keyword interpretation, with exact covariant
outputs and contravariant supplied inputs. Arbitrary host signature/default
inference remains outside scope.
See [the declaration protocol](method-declarations.md#rich-declared-function-signatures)
for grammar, failure phases, full examples, cache transport and Lean boundaries.

## Calls and shared declarations

`infer-prototype-calls` derives bidirectional subtype obligations from a finite
batch of explicit ground-Type call observations and an existing Function/Object
signature expression. `infer-declared-calls` admits the resulting whole named
interface only after a unique complete assignment, required signature coverage,
captured source preservation and current factory descriptors. The report retains
captured `calls` and generated `queries`; no source/default/method body executes
during constraint collection. See [joint call inference](method-declarations.md#joint-call-inference-and-complete-interface-admission)
for grammar, failure kinds, shared quotas, source discipline and proof premises.

## Pair, Map, Sum and ordered Union admission

This advances the paper's type-system future work (Type Descriptors and Type
Constraints), using its explicit type-constructor/constraint vocabulary. The
paper's Racket prototype construction does not supply a general-purpose inference
solver or the rules below. These are a deliberately finite extension.

All four constructors have Type kind. Pair takes exactly two Types; Map takes two
Types and exactly one literal `<-` or `->`; Sum takes unique keyword/Type pairs;
Union takes an ordered Type list, including empty and duplicate alternatives.
Tags and arrows are never substituted. Sum labels correspond to the runtime
symbol tags via the existing constructor; descriptor `sexp` retains keyword/Type
order. No new executable container representation or validator is introduced.

| Constructor | Admitted replacement | Normalization / failure |
| --- | --- | --- |
| Pair | Both positions covariant | Existing validator preserves both normalized positions, including improper tails and Function wrappers; child errors propagate. |
| Map | Key syntax invariant **after normalization**; value covariant | Both arrows canonicalize to `(Map Value <- Key)`. Runtime validation keeps source hash/equality policy and normalized keys/values; collisions refuse the whole rebuild. No source mutation. |
| Sum | Exact ordered tag skeleton; each payload covariant | Never sort tags; unknown tags gate payload evaluation; selected payload errors do not try another tag. Empty Sum has no admitted values. |
| Union | Exact normalized ordered branches | Never sort/deduplicate alternatives or lift component subtyping through Union. First structural branch remains committed, including errors and returned wrappers. Empty Union has no admitted values. |

These are rules for validated observations. Hash tables, pairs, tagged objects and
procedures remain host values; a positive judgment does not authorize covariant
writes or prove procedure behavior. Runtime validation is required on every
contract boundary, even when key syntax or Union branches are unchanged.

Ground candidates canonicalize Map arrows **before** ordered duplicate elimination,
so arrow aliases cannot produce spurious ambiguous assignments. Mu binders and row
tails remain explicit until complete substitution has rechecked recursion and kind;
early expansion must not erase a newly nested Mu refusal. Literal Sum order and
Union duplicate branches remain significant. Subsequent finite Mu expansion and
row normalization share the existing quota. Recursive Map payloads are guarded positive
positions; recursive Map keys are refused because their relation is invariant.
Malformed arities/arrows/duplicate tags give `malformed`; unsupported constructors
or negative recursion give `unsupported`; explicit row kind mismatch gives `bounds`
(inference filters assignments with invalid bounds);
quota/depth exhaustion gives `exhausted`. Completed conflicting constraints return
`no-solution`; no incomplete search can publish a prefix solution. A fresh request
can retry after failure. Syntax/canonicalization errors or exhaustion propagate
before search; unsupported substituted recursion also propagates, without being
silently discarded as a false subtype judgment. No such failure exposes a partial
descriptor or builder result.

`RoutingServiceType` and `infer-routing-service` in
`examples/polymorphic-services.ss` bind Key as a prefix and jointly infer Self/Super
from a Map-of-Sum-of-Function argument and Pair/Union expected result. The existing
`.defgeneric` installs qualified typed fragments; `routing-service-action` composes
Reader/FUN, a refined object root, exact `bind-evidence` publication and IO consumption.
Tests cover every rule and refusal, Function keys and values, no premature method
execution, cache ownership, failed refinement and retry. The existing variant and
table suites continue to cover collision admission and carrier reconstruction.

`Functional.PrototypeTypes` now carries corresponding Pair/Map/Sum/Union syntax,
substitution and derivability rules. `same_sound`, `map_key_invariant`,
`sum_tags_invariant`, `union_branches_invariant`, `check_sound` and
`inferred_constraints` prove the finite judgments. Sum's unique labels/payload
lengths are parser premises; the proof algebra represents labels with finite Nat
IDs. Canonical Gerbil surface syntax must be projected faithfully to these Types.
Existing `VariantValidation` laws separately establish returned-child retention,
collision rejection and committed branch failures. Conditional semantic
replacement still requires the explicit interpretation laws; these proofs do not
verify Gerbil's compiler, hash implementation, arbitrary callbacks, or mutable
writes. Implicit arbitrary Class/Slot callback inference and candidate-dependent method
paths remain outside this acceptance. The following section admits explicit Record fields.

## Explicit Record fields and Class construction

`(Record ((name Type required-or-optional) ...) open-or-closed)` is a finite Type
expression. Field names are unique literal symbols, presence is exactly `required`
or `optional`, and the tail is exactly `open` or `closed`. No callback, mutable Class
descriptor, default value, nominal superclass or arbitrary Slot policy is embedded
in inference syntax. Malformed metadata gives `malformed`; an unsupported Type
still gives `unsupported`, even against Any. Recursive field Types reuse guarded Mu
and the shared quota. Literal names/presence survive prefix substitution; Record
cannot be a parameter or Mu binder name.

Compilation produces the existing **Class.** with ordinary **RecordSlot** entries,
not a new record implementation. Closed means `sealed: #t`; optional means the
existing Slot `optional: #t`. Required absence, unknown sealed fields and child
failures retain Class validation behavior. Recursive Function wrappers remain in
the returned fields. A positive inference does not supply defaults, execute
computed getters/hooks, certify host arity or allow mutable covariant writes.

Replacement uses one named-field protocol for Record and Object, with standard
Gerbil symbol-keyed hash tables. Readable fields are covariant and independent of
field order; an open target permits additional declared source fields. Optional
source fields cannot promise required target fields. A missing optional target
field is safe only when the source is closed: an open source could contain that
undeclared name with an incompatible value. Closed targets require closed sources
and forbid extra observable source fields. An optional field with a positively
witnessed empty child is necessarily absent and may be omitted; see row-types.md.
A closed source may omit optional target fields. Record/Object cross-constructor relations
use the same finite named-field protocol; opaque Class/Schema tokens remain
nominal. Neither normalization nor Class construction sorts field lists
or changes validator/default/hook order. These are observational derivations,
not mutable-write permission or effectful validator equivalence.

`RecordServiceType` in `examples/polymorphic-services.ss` returns a Record containing
required run/limit/bias and an optional callback. After fixing Self as a parameter
prefix, the actual Integer argument, original Self <: Super bound and expected
Record jointly select Super = Integer from the finite universe. The same inferred
signature feeds the existing prepared method combination and `.defgeneric`.
`record-service-class` reuses ordinary multiple inheritance, effective Slot types,
a computed child override and checked initialization. Its hook runs only when a
method constructs an instance; inference/installation runs no hook or method body.
The declared result boundary independently validates the actual constructed Class
value. A bad hook result refuses; a fresh construction can retry.

`record-service-action` sequences approval and declared construction through FUN,
then reuses `publication-action` for ObjectContract/refine, exact `bind-evidence`
and IO consumption. Rejected refinements never call the consumer. Earlier hook or
method effects are not rolled back. Optional callbacks are not invented by the
inference engine; when supplied, their wrappers still check each call.

A **data callback** in a Record is a procedure validated by Class. A **declared
method group** in an Object catalog carries dispatch/certificate provenance. Record
is admitted in Function arguments/results and standalone data construction; a root
Record is explicitly refused as a declared-method catalog before its builder runs.
Methods should use the existing explicit Object signature paths. This prevents
optional Class fields or initialization hooks from silently becoming mandatory
method groups. Candidate-dependent paths and arbitrary Class reflection remain open.

`Functional.ClassValidation.RecordType`, `recordFieldsCheck_sound`,
`recordCheck_sound` and `record_field_replacement` prove exact metadata matching,
presence/sealedness requirements and replacement of the same finite observed value
snapshot under an explicit child interpretation. `Examples/ClassContracts.lean`
uses the matching field layout and prefix-fixed constraints with
`Functional.PrototypeTypes.infer`, plus existing checked-initialization and evidence
proofs. These laws do not verify C3, host descriptor identity, arbitrary getters,
compiler behavior, default computation or GC. Syntax admission and faithful label
projection are premises. Existing source revision and resource limits stay intact.
The concentrated tests are `t/inference/record-inference-test.ss`; complete single-process and
all existing test groups remain required.

## Candidate-dependent signatures and field layouts

`infer-prototype-calls` and `infer-declared-calls` also accept schemas whose
whole expression, named field Type, or Object row tail is a free Type parameter.
An explicit finite candidate universe determines each complete ground expression;
recursive syntax admission and row normalization precede projection of its named
Function paths. Existing Function shape selection then extracts inequalities, and
all sibling calls and original bounds must hold under that **same** assignment.
Known signature shapes retain the existing precollection path. No body, optional
default, Type recognizer or declaration builder executes during enumeration.

```scheme
(def catalog-type
  (prototype-type (.o .parameters: '(Catalog)) '(Catalog) 'Catalog []))
(infer-prototype-calls catalog-type
  '(UInt (Object ((run (Function (UInt) (Integer)))) closed))
  '(((run) (Integer) (UInt)))) ; unique Object candidate
```

Each `alternatives` entry carries `arguments`, its own normalized `expression`,
and its own ordered `queries`. The report's `solutions` remains the assignment
list. For unique call inference, top-level `queries` is that selected alternative's
queries. For nonunique dependent inference it is empty; inspect `alternatives`
rather than merging incompatible layouts. For known shapes the precollected
queries remain available even when the result is nonunique.

Wrong candidate kind, absent candidate field, disallowed row overlap, rejected
call shape/output count or unsatisfied inequalities reject that candidate. Complete
search returns `no-solution`, `unique`, or `ambiguous`; only `unique` may invoke
the builder. Malformed/unsupported syntax or exhaustion aborts the entire request,
even after a valid candidate. All observations, whether their signature is fixed
or candidate-dependent, are snapshotted and preflighted through the existing
keyword decoder before any shape/path projection, including with an empty universe.
An early fixed shape refusal therefore cannot hide later unsupported/malformed
metadata. Projection reuses admitted payload Types under the same counter; raw
wire markers still need the selected signature's interpretation.
Dangling/duplicate keyword rows are malformed; payloads must be ground supported
Types. Literal missing paths in an already known schema remain unsupported.
The shared quota, depth guard and recursive admission rules remain enforced.

Publication still checks source identities/revisions, negative assumptions and
**every** required named signature, including unobserved siblings. Builder/approval
errors propagate; there is no fallback to another candidate after builder failure,
no partial artifact and no rollback of arbitrary builder effects. A new request
may retry. `infer-shared-catalog-service` reuses both existing qualified factories;
`catalog-service-action` composes recursive callback validation, refinement and
exact evidence binding through the existing FUN/publication protocol.

This is finite rank-one future-work inference, not an implementation attributed
to the Racket appendix. Explicit `.parameters`, Type/Function descriptors and
Self/Super constraints follow the existing protocol. It does not discover arbitrary
Class/Slot callback layouts, principal host types, higher ranks, unrestricted
recursive/effect types or value-directed dispatch and arbitrary semantic predicate inclusion.
Root Record remains a data Type rather than a certified method catalog.

## Ordered case call-language coverage and replacement

`(function-covers? source target [budget])` decides whether the source covers
the target's complete declared shape language within the admitted wire domain.
`subtype-expression?` additionally checks safe replacement. Both ordinary Function
and ordered CaseFunction terms can occur on either side, including nested Type
positions. For example, one `(Function (UInt) (Integer) rest: Integer)` safely
replaces a CaseFunction requiring a UInt argument, or two UInt arguments followed
by any number of UInt rest arguments, with Integer results.

The checker reuses the existing first-shape selector and supplied-argument
normalizer. It enumerates counts from zero through one beyond the largest fixed
required/optional prefix on either side, and every subset of target-declared keys.
Those counts partition the entire arity language: selection and rest input Types
stabilize after that boundary. Keys are deduplicated through Gerbil's standard
library; subsets stream under the same work quota. This is exhaustive finite
partitioning, **not** inference from a few observed calls.

For every target-accepted region, the actual first source clause must exist.
Replacement requires the source's exact-count outputs to be subtypes of that
selected target's outputs, and each provided target input/key Type to be a subtype
of the corresponding source Type. Optional defaults are not executed or checked
as supplied values. A shadowed later clause imposes no independent obligation
and cannot repair a failed earlier one. Disjoint cases may safely reorder, and a
source may accept additional calls. The ordering of overlapping cases is retained.

Keyword mode is determined by whether **any** clause declares a keyword. Shared
modes retain the original path. Different modes now have two sufficient rules:

- Keyword source / positional target: every **supplied** Type of the first selected
  target clause must exclude outer keyword, `#!key` and `#!rest` tokens. UInt,
  Integer and Bool are stable. List/Tuple/Pair/Map/Sum/Object/Record/Function carriers
  are stable even with Any payloads; Maybe exposes its payload (plus ordinary void),
  and Union requires every exposed alternative to be stable. Any supplies no outer-token stability witness.
  Ordinary input contravariance and exact-count output covariance still apply.
- Positional source / keyword target: each selected target region with `n`
  positions and `k` keys generates the raw length interval `n+2k .. 2n+2k+1`.
  The upper endpoint includes escaping every position and a trailing `#!rest`.
  The precision ceiling includes all bounded target raw spellings and all fixed
  prefixes; only the remaining unbounded tail uses a stationary envelope.
  select the **actual first source clause by raw length** at each region. Fixed,
  optional and several ordered case-lambda clauses may jointly cover that interval.
  No source rest is needed when the target's raw language is bounded.
  A non-tail row of length `n` with no keys has no escapes: compare supplied input
  Types by ordinary contravariance. Other bounded rows trace each data origin
  and exact protocol marker through the decoder grammar. UInt payloads can
  therefore occupy Integer slots; marker slots use Keyword, Exactly or Enum.
  Unused optional fields impose no obligation. Every selected pair
  retains exact-count covariant results. A failed first Type/result never falls
  through to another source case. Different target decoded cases may share one
  source raw arity: all those output obligations must hold independently.

Neither rule rewrites an incoming row or makes a keyword optional by dropping it.
Gerbil's existing decoder, normalizer, keyword lambda and case selection remain
responsible for runtime calls. Direct-source wrapper controls test all token rows
up to length five, independently of the finite partition algorithm; positive
examples exercise keyword order and both escape markers. A target wrapper is not
inserted ahead of the source to conceal an interpretation difference.

The decision is conservative, not maximal inclusion for arbitrary raw languages.
Key order does not change structural admission; no claim is made about effectful
recognizer/default ordering, host arity or totality. Type relations remain the
explicit finite structural algebra; arbitrary predicates, higher ranks, effects
and unrestricted recursive language inclusion remain outside scope.

Malformed/unsupported syntax and exhausted work raise their existing TypeRefusal
causes. The public coverage entry refuses non-Function kinds with `bounds`. False
means coverage/replacement is not established in this domain; shape coverage
alone cannot authorize replacement after a variance/output mismatch. A request
that exhausts after checking a prefix returns no coverage certificate.

Original bounds and call-derived inequalities use the same replacement judgment,
so prefix specialization, candidate-dependent signatures, nested callbacks and
`infer-declared-calls` compose without another declaration API. False comparisons
reject candidates; an exhausted search aborts before any builder or artifact.
Existing source/negative/sibling admission remains mandatory. `CoveredServiceType`
and `infer-covered-service` demonstrate a prefix-bound scalar and inferred callback,
qualified method invocation, recursive wrapping, FUN/refine and exact evidence
publication through `catalog-service-action`. See `t/signatures/function-coverage-test.ss`.


`PositionalCallbackServiceType` / `infer-positional-callback-service` and
`KeywordCallbackServiceType` / `infer-keyword-callback-service` use the same fixed
Value prefix, candidate inference, whole declaration builder and
`catalog-service-action` FUN/refine/bind-evidence chain. Runtime callbacks retain
ordinary default execution and exact raw token sequence respectively. See
`t/signatures/keyword-coverage-test.ss`, including no-solution/exhaustion before builder calls,
outer-versus-exposed carriers, shadowing, required keys and raw-minimum controls.

Lean's `Functional/KeywordArguments.lean` and `Functional/KeywordCoverage.lean`
use the existing `Functional.FunctionSignature` namespace. They prove decoding
agreement, lower/upper raw lengths, direct minimum-row identity, complete clamped
raw regions, actual ordered selection, output variance and direct-input/Any
obligations for all raw spellings, plus finite-to-unbounded rest stability.
The positional-to-keyword theorem requires the explicit runtime carrier law and
input recognition premise; finite Type projection, host behavior and arbitrary
recognizers are not verified. This advances the article's hypothetical type-system
future work, not a claim that its Racket implementation has these static checks.


`KeywordPrefixCallback` / `infer-keyword-prefix-service` specialize the same Value
prefix and infer a real Gerbil case-lambda: a fixed UInt case and a bounded optional
Any case. Existing declaration admission and `catalog-service-action` carry it
through FUN/refine/bind-evidence. `t/signatures/keyword-prefix-test.ss` checks fixed-only case
unions, unused optional Types, trailing escape upper bounds, shared raw arities
across target cases, stationary rest refusal, nested callbacks/Map-key invariance,
full publication and no-builder quota/failure paths. Its independent runtime oracle
enumerates 1365 unmodified token rows, not the coverage algorithm's cells.

This remains a conservative finite decision. Non-direct raw rows now use the
value-sensitive traversal below; no Type is enlarged to Any to repair a refusal. False means unproved coverage/replacement; malformed/unsupported
syntax and exhausted shared work retain their TypeRefusal causes. Shape coverage
alone does not establish direct-row input variance; subtype replacement does.
Neither incomplete region traversal nor failed/ambiguous inference enters a builder.


## Value-sensitive raw rows

`types/syntax.ss` admits existing `Keyword`, `(Exactly literal)` and `(Enum literal ...)`
for immutable bool/integer/keyword/escape literals. These are metadata, not Type
variables: normalization and prefix/residual substitution retain them unchanged.
`expression-type` constructs the existing Type descriptors and validators. Enum
literal lists are copied before entering lazy descriptor slots, so subsequent
caller syntax mutation cannot alter the first literal-set observation. This
validation grammar does not extend JSON encoding to escape-token values.

`types/relation.ss` checks each bounded region against the actual first source
case. A request-local standard hash table memoizes completed suffix decisions by
remaining positional Types, remaining supplied key/Type entries and raw offset.
Ordinary data consumes one slot; key-escaped data consumes two; a keyword consumes
its exact label and its own payload Type; rest escape consumes its marker and the
remaining positional suffix. All key orders participate, each key is removed on
use, and infeasible suffix lengths are pruned **before** checking their prefixes.
The shared work/depth limits remain mandatory. No defaults or inferred Any appear.

The current graph rule below supersedes the earlier all-slots stationary envelope.
It retains each raw position's own origins at arbitrary rest lengths, with distinct
raw and decoded counters. An explicit broad flat envelope remains a sufficient
contract, but the checker does not require that envelope at every prefix slot.

Only raw-origin admission compares identity-preserving flat scalar/literal Union
alternatives extensionally. Public subtype/inference bounds retain ordered Union
invariance, including flat Unions. Function/container/wrapper-bearing Union never
uses this raw-only inclusion; earlier
branch wrapping cannot silently replace later branch behavior. Ordinary Function
inputs and exact-count outputs retain their existing variance rules.

`KeywordValueCallback` and `infer-keyword-value-service` compose the Any-free
five-token endpoint with original prefix specialization, complete unique inference,
unified declarations and `catalog-service-action`'s FUN/refine/bind-evidence chain.
`t/signatures/keyword-values-test.ss` independently enumerates 9331 raw rows of length at most
five over numeric/false/key/escape values, retaining malformed/dangling/duplicate
controls. It also checks two distinct key payload Types, exact labels, a required
nested Function's two raw spellings, checked callback result failures, stationary
Any-free rest, first-case refusal, exhaustion and no-builder failure semantics.

The companion `RawArguments.lean` uses the existing FunctionSignature namespace.
`rawCovers_sound` proves admission for **every** RawSpelling derivation, with payload
Types and marker evidence retained separately; `rawSlots_sound` lifts supplied
origin-admission laws to all slots. Enum/Keyword laws exclude invented labels and
escape-as-keyword certificates. `stationaryRaw_sound` retains its explicit complete
origin-envelope premise. The publication example reuses existing finite inference
and the two-generic builder. Decoder-to-typed-origin assignment and host validator
interpretations are explicit premises, not proved compiler/runtime correspondence.
These advance the article's hypothetical type protocol (Appendices C/D), not a
claim that its original Racket implementation already supplied a static type system.


## Literal ordinary values and correlated rest positions

The complete `raw-inputs-related?` judgment now builds a finite product graph. Its
states retain decoded position, remaining supplied key/Type pairs, raw offset and
whether rest escape has ended interpretation. Edges retain one/two ordered origin
Types. `Keyword` has no ordinary-data edge; `Exactly` and `Enum` filter out keyword,
key-escape and rest-escape literals exactly. Flat identity-preserving Union arms
and Maybe's ordinary restriction reuse existing constructors. Opaque carriers and
wrapper-bearing Unions retain conservative overapproximations, not guessed Types.
Escaped values and the suffix after rest escape keep their **full** payload Type.

Raw and decoded positions have independent finite limits. Source selection still
partitions every raw arity beyond all source prefixes. Target selection needs only
its own fixed/optional prefix; beyond that point its rest Type repeats. Counters
saturate after those prefixes while preserving the source slot of every edge.
A decoded tail visits every later raw arity cell through the raw sentinel, rather
than stopping at the upper bound of the shortest decoded row. A late arity-12 bad
source result is independently rejected by `t/signatures/keyword-rest-test.ss`.

Standard equal?-hash tables record reachable edges and backwards predecessors.
Only legitimate endings seed backwards closure. The final certificate independently
checks every ending is live and every edge into live starts live; its origin checks
use each edge's exact raw offset. Cycles without endings do not invent calls, and
cycles with an exit retain all their input obligations. A graph lacking a complete
certificate cannot publish, even if some visited states looked compatible.

A genuinely empty raw region may skip a missing source clause or an incompatible
unused output only after closure validation. Every inhabited region still requires
its actual first source clause, exact output count and covariance. Type failure
cannot fall through. Shared Type-work, depth, heap and timeout guards remain active;
exhaustion raises the existing typed refusal and no partial graph/memo is published.
Both complete new service examples fit the original default 8192 work budget.

`CorrelatedRestCallback` excludes Bool from the first raw slot while admitting the
Boolean enabled-key payload in later slots. `LiteralRestCallback` carries a first
positional rest-escape literal through an arbitrarily long numeric tail. Their
existing Value/Callback schemas, prefix specialization and complete unique inference
feed the original unified declaration and FUN/refine/bind-evidence pipeline.
`t/signatures/keyword-rest-test.ss` adds nine cases, an independent 3906-word runtime oracle,
long tails through 257 positions, exact Keyword/Exactly/Enum controls, dead arity
result controls, late-case selection, quota refusal and failure-before-builder.
Public ordered Union bounds and wrapper semantics retain their invariant judgment.

The companion existing `RawArguments.lean` adds exact finite ordinary-literal laws,
independent counter-transition/slot-lookup laws and complete raw tail-cell coverage.
`rawGraphCheck_sound` proves the certified origin law for **all** finite accepting
paths, including arbitrarily many cycles. `rawGraph_empty` proves the empty witness
excludes all such paths. The top-level declaration example links unique inference
and the original builder to that universal law. Concrete graph-construction/typed
origin correspondence and host validator interpretations remain explicit premises;
this is Appendix C/D future work. Arbitrary predicates, effects and opaque ordinary
refinement remain outside this decidable subset. Infinite rest means arbitrary
finite call lists, not execution on a physically cyclic/infinite argument list.

## Graph implementation and library reuse

The cross-mode judgment composes product construction, backwards closure and
independent certificate checking inside `types/relation.ss`. Both traversals use
one private arrow/target traversal, following the higher-order protocol in
Gerbil `std/struct/dag`, while allowing finite cycles that `walk-dag` rejects.
Visited nodes only record outgoing arrows; they never certify a subtype.
`std/hash/misc`'s `hash-ensure-ref` caches completed ordinary restrictions and
origin comparisons (including false), and `hash-update!` collects shared reverse
dependencies. Exceptions leave no completed answer; all tables remain local to
one judgment. Work accounting and default budgets are unchanged.

The existing FUN/refine/bind-evidence pipeline consumes the final checked result;
pure graph traversal does not introduce a separate effect or declaration protocol.
The companion `rawRegionCovers_ext` law makes the certificate judgment independent
of live-set ordering and duplicates when membership agrees. This is not a proof
of Gerbil's hash implementation or of the concrete graph producer's completeness.
The keyword/rest regression repeats false, exhausted and successful requests to
check that an interrupted traversal cannot poison subsequent inference.

## Shared named-field replacement

`RecordServiceView` and `infer-record-view-service` use the original Record factory
with a fixed Self prefix and finite Super candidates. A narrower, reordered open
view fixes Super through the nested callback while hiding internal fields. The
original declaration builder, inherited Class initialization and
`record-service-action` carry recursive wrapping through FUN/refine/bind-evidence;
no additional declaration, container or effect protocol is introduced.

`t/inference/record-inference-test.ss` checks required/optional presence, both closed-key
directions, hidden incompatible optional values, Function input contravariance,
Map value covariance and key invariance. An independent oracle compares nine
layouts and sixteen concrete observations (including absent fields); it uses
actual Class validators rather than the field-index implementation. This finite
oracle supplements the universal conditional record observation theorem in
`Functional/RowTypes.lean`, `recordCheck_sound`. `recordFieldCheck_missing` proves
that an accepted absent field requires both a closed source and an optional target.
`inferred_record_sound` reuses complete finite inference, and the top-level
`inferredRecordView_sound` connects the original specialization/declaration builder
to that observation law under existing scalar/Function interpretation premises.
ClassValidation and RowTypes also share the original `(key, Type, optional)`
metadata and one `slotAdmits`/`slot_replacement` law. Class structural replacement
uses the same named checker; only ordered value-snapshot pairing retains a
separate positional rule. These extend Appendix C/D future work; host effects and
mutable writes remain outside the proved relation. Shared work refusal still aborts before publication.


### Effective Function metadata

Function admission, negative-input traversal, inference views and descriptor
construction now share `call-with-function-types`. It uses Gerbil's `agetq`;
source-preserving substitution uses `map-in-order` and `alist->plist`, rather
than another positional option protocol. The existing Function descriptor still
owns argument/default/result checking and the existing FUN/refine/bind-evidence
chain owns consumption and publication.

Semantic candidate identity and subtype normalization use the same effective
schema: option binding order and explicit empty defaults do not create distinct
candidates. A rich signature has all four metadata bindings in descriptor order;
an all-default signature has no metadata tail. Captured source expressions retain
the original spelling. Case order, field construction order, keyword declaration
order, required-key payload order, Map key invariance and ordered Union branches
are preserved. Duplicate/unknown/malformed options and exhausted admission retain
typed refusal before builder execution; normalization supplies no Any fallback.

`t/signatures/function-options-test.ss` checks all 24 option orders, explicit defaults,
prefix substitution, nested callbacks, invariant Map keys, ordered Union/cases,
and a rich service callback through refinement and evidence binding. The Lean
FunctionSignature model proves permutation invariance for unique option kinds,
default elimination, normalization idempotence and substitution commutation.
Its typed input premise excludes unknown raw syntax; Gerbil admission tests cover
that boundary. These extend the article's type/MOP future work, not host compiler
or effect semantics, arbitrary predicate equivalence or unrestricted inference.


### Sentinel optionals in the finite type protocol

`OrFalse` now follows the same syntax admission, Type-child traversal, positive
recursion guard, specialization, observational covariance and descriptor compilation
as `Maybe`. Compilation calls the original `OrFalse` constructor; `optional-validation`
remains the sole runtime selected-child/sentinel validation protocol. No second
optional wrapper or generic dispatcher is introduced. The constructor-name predicate
is shared between prototype parameters and Mu binders, so the phases cannot admit
different free-variable vocabularies.

Only false is absent for OrFalse; only void is absent for Maybe. Nested optionals
retain both sentinels. The two constructors do not replace each other. Map keys
remain invariant and ordered Union branches remain literal; sentinel alternatives
are not erased or used as an Any fallback. Keyword-mode coverage inspects an
optional's exposed child: OrFalse UInt is token-stable, OrFalse Keyword is not.
Ordinary-origin restriction retains the optional constructor even when its child
reduces to Never, because the sentinel is still inhabited.

`OptionalRoutingServiceType` fixes the invariant Key prefix, jointly infers Self
and Super from nested callback inputs/results, then uses the original route method
fragments and FUN/refine/bind-evidence publication. Its regression controls include
unchanged false Map entries, wrapped present callbacks, missing Maybe values,
refinement refusal, ambiguity, bounded exhaustion and a complete fresh retry.
Controlled Mu expansion uses the existing decreasing approximant program: depth
zero remains Never, not false and not resource exhaustion. Negative recursion
through Function inputs still refuses. No arbitrary TypeValuePair-carried descriptor,
Class callback, semantic predicate or unrestricted recursive inclusion is inferred.

The Lean finite algebra now has distinct Maybe/OrFalse constructors, with recursive
identity, child covariance, substitution and conditional interpretation laws.
OptionalValidation proves sentinel-preserving inclusion and selected-child
membership after successful present normalization. The top-level route example
uses original bounded inference and the specialization/declaration builder and
proves publication retains both a complete replacement derivation and builder
result. Wrapper behavior/host effects remain interpretation premises. This is
Appendix C/D future work, not a claim about the original Racket implementation's
static inference or the correctness of Gerbil's compiler and collector.


### Scalar families and immutable labels

The finite language now includes the existing String and Symbol Types and
immutable Symbol values in Exactly/Enum. It compiles to the original runtime
descriptors. `scalar-recognizer` is one private table of built-in Gerbil predicates:
syntax admission, constructor reservation, flat literal inclusion and keyword-wire
stability use that shared lookup. Unknown names do not fall back to Any. This is
finite POO policy, not another implementation of Gerbil contracts: host `using`
admits the example observer, and the original descriptors own runtime validation.
Mutable/derived POO recognizers are not evaluated during finite derivation.

String and Symbol are separate families; their conversion methods imply no
replacement relation. Symbol data is distinct from keywords, #!key and #!rest.
Exactly/Enum literal names remain data during prefix substitution, even when they
spell a parameter or constructor. Uninterned symbol identity survives capture;
changing the caller's Enum list cannot change the compiled snapshot. Mutable
strings are accepted as String *values*, but remain unsupported literal metadata
for Exactly/Enum, preventing mutable keys from entering the finite literal algebra.
Map key invariance and ordered Union selection remain unchanged.

`TextServiceType` prefix-binds Label=Symbol and infers Value=String among explicit
Bool/Symbol/String candidates from input/result/callback observations. It uses the
original qualified fragment builder. Numeric and text services now share one
`signature-publication-action`: FUN approval, generic call, root refinement and
exact bind-evidence publication. Their policies supply their own descriptor; no
parallel effect interpreter or fallback dispatcher is introduced. Tests cover the
original scalar descriptors against independent host predicates, literal capture,
keyword transport, nested finite recursion, complete publication and fresh retry.

Lean extends the existing Atom algebra rather than adding a new type judgment.
`atom_inclusion` proves that an accepted scalar relation is identity or UInt <:
Integer; `text_distinct` excludes implicit text conversion. Original checker
soundness, substitution and finite inference laws continue to apply. The top-level
prototype example runs the original prefix/residual parameter binder and declaration
driver and proves successful publication retains all constraints and its builder
result. Its Symbol-family observation abstracts the finite literal label set; it
does not prove host predicates, symbol interning, conversion, parser or macro
implementation. These are Appendix C/D type-protocol future work. Arbitrary Class
callbacks, mutable literal semantics and unrestricted inference remain OPEN.


### Inclusive IntegerRange constraints

Finite syntax now admits `(IntegerRange min: lower max: upper)` using the original
number.ss constructor. Each endpoint is a literal exact integer or false; omitted
or false bounds are unbounded. Duplicate, unknown, dangling and nonliteral bounds
refuse before candidate building. Reversed endpoints describe the original empty
range and are not malformed metadata or exhausted work. False is not an integer
inhabitant. The fixnum-only core `in-range-inclusive?` cannot replace this existing
arbitrary-precision/unbounded descriptor.

Integer, UInt and IntegerRange share a symbolic numeric judgment. Inclusion checks
at most two endpoint orders, including one-sided and empty intervals, without
enumerating their inhabitants. Exactly/Enum integer literals may be admitted into
a range. Nonnumeric range inclusion, arbitrary endpoint expressions and general
Boolean-union coverage remain conservative; finite range-to-Enum coverage is\nextended below. Public ordered Union
branches and Map keys remain invariant. Only keyword order and explicit unbounded
metadata canonicalize; IntegerRange is never erased into Integer/UInt merely
because its integer membership coincides. Their descriptor/arithmetic protocols
are distinct. Metadata positions are not Type-substitution positions.

Function and range metadata now share the checked `literal-options` protocol:
Gerbil's `plist->alist` supplies source order, `agetq` supplies literal defaults,
and `alist->plist`/ordered mapping preserve source spelling during substitution.
The former private reverse-list convention has been removed from Function's
consumer, without a compatibility path. Function's 24 option-permutation controls
still pass. Admission policy remains POO-specific typed refusal; neither a host
binding error nor a duplicate key is silently accepted.

`RangeServiceType` reuses the original rich SignatureServiceType parameter and
Function schema, adding Super's inclusive upper/lower bound. Self=[0,10], observed
inputs=[0,100] and Super<:[0,100] force one complete residual candidate. Existing
optional/keyword/rest forwarding, qualifiers, callback wrappers and cache owners
remain explicit. The same catalog publication action accepts a configurable root
maximum; a result can pass its Function range yet fail refinement before IO or
evidence escapes. Tests also retain ambiguity across distinct descriptor kinds,
failure/exhaustion before builders, large exact endpoints and fresh retries.

Lean adds an IntegerRange value to the existing PrototypeTypes algebra. Universal
endpoint inclusion preserves every exact integer observation, and empty ranges
refuse every integer. The original checker soundness/interpretation proof now
uses those range laws, with a declared numeric interpretation premise. The top-level
example reuses bounded inference and prefix/residual declaration binding and
retains every original/call constraint plus the whole builder result. These laws
advance the article's type-system future work; parser/macro implementation,
mutable descriptor semantics, integer bit-operation costs and host GC/runtime
performance are not proved. Full time/heap/work bounds and checks remain required.

### Range inclusion in finite literal targets

IntegerRange now replaces Enum/Exactly when the target contains every integer in
the interval. Empty intervals fit even an empty or nonnumeric finite target;
nonempty unbounded intervals refuse. Bounded intervals wider than the number of
target literals refuse before indexing. Otherwise Enum's existing first-index-hash<-vector prepares its equal? table
from the captured literals, then a quota-charged traversal checks each
integer in the interval. Duplicate, unrelated and noninteger literals never fill
holes; order and duplicates in descriptor data are retained. Exactly is the same
finite-target rule with one member. Public Union branches and Map keys remain
invariant, and semantically equivalent range/Enum candidates remain distinct.

This is a decision within admitted immutable literal syntax, not an arbitrary
predicate/union solver. Unsupported literals retain the existing `unsupported`
refusal; bad range metadata remains `malformed`; work depletion raises `exhausted`
and never becomes a negative judgment. A complete negative inclusion yields no
solution, and multiple matching descriptor kinds yield ambiguity. No builder is
called in either case; fresh retries use the original bounded declaration driver.

The existing infer-range-service accepts an explicit schema and reuses its full
rich Function, qualifier, forwarding and wrapper construction. EnumServiceType
only changes Super's declared bound to a finite alphabet. A range selected from
heterogeneous candidates is installed with its original descriptor and passes the
same FUN/refine/bind-evidence chain. Recursively wrapped callbacks, invariant
parents, output violations, refinement refusal and failure retries are covered by
t/scalars/range-inference-test.ss (12 cases total, five added for this increment).

Lean's existing algebra adds an integerEnum view of the target's exact integer
members; arbitrary noninteger literals and host hash internals are not modeled.
coverFrom_sound and coveredBy_sound establish universal membership preservation.
coverFrom_complete establishes completeness when the probe budget spans the
interval and every member belongs to the target. The traversal structurally
consumes at most target length probes. The Scheme width precheck is a rejection
optimization; the formal proof does not certify host hash complexity or integer
bit costs. Checker/replacement and the original complete inference/declaration
proofs include this edge under explicit interpretation premises. The top-level
example retains the exact bound artifact and all derived constraints. General
predicate discovery, dependent endpoint expressions and Boolean-union coverage
remain outside this Appendix C/D type-protocol future work.

### Joint range/Enum coverage by ordered flat Union

The P2 gap was distributed coverage: no single alternative may contain a range,
although several alternatives jointly cover it. The finite relation now admits a
Bool, Integer, UInt, IntegerRange (including either unbounded endpoint), or keyword-stable finite Exactly/Enum source into an ordered Union whose
entire tree consists of known built-in flat validators. Numeric branches are
projected with their original optional endpoints, exact integer literals become singleton pieces, and other
intrinsic scalars contribute no integer coverage. Nested branches are traversed
in declaration order using Gerbil append-map/foldl. Each projected interval is
subtracted from the residual intervals; a successful check leaves none. Huge
ranges are not enumerated, sorted or materialized. Duplicates, overlap, reversed
empty ranges and source holes retain their exact membership meaning.

Keyword-stable finite mixed scalar Enum sources use the existing literal-in-type? protocol,
checking every literal against the original ordered tree. No fallback Type is
manufactured. All syntax is admitted before coverage: unsupported metadata and
work exhaustion keep their typed refusals. A complete gap is false/no-solution;
ambiguous descriptor kinds never enter builders; a fresh request can retry.
Projection and every residual visit consume the existing shared work quota.

Only this cross-kind read/validation relation is extended. Union-to-Union branch
identity/order, Map keys and other invariant positions retain their old checks.
The public target descriptor is never flattened, sorted or coalesced. Trees with
Function/container/refinement wrappers or arbitrary custom recognizers refuse
this rule, even if an earlier flat branch covers the source or the source Enum
is empty. Keyword/escape-token sources retain their dedicated raw-transport judgment.
General Boolean/predicate discovery and dependent endpoints remain outside this rule.
Integer/UInt sources use their existing symbolic interval views in this same
judgment. Their public descriptor kinds remain distinct from IntegerRange. This is not a serialization, arithmetic-method,
JSON or complete object-protocol equivalence claim.

Union's existing select-union/validate-union path remains authoritative: select
the first structurally matching branch, validate it once, and propagate its error
or failed postcondition. Coverage does not permit fallback after failure. The
new UnionServiceType changes only Super's bound in the existing rich service;
prefix/call inference, parameter specialization, original qualifiers and generic,
callback wrapping, cache owner and FUN/refine/bind-evidence publication are shared.
t/scalars/union-inference-test.ss contains fourteen integrated cases, independent descriptor
witnesses, huge exact endpoints, selected-error controls and retry checks.

Lean puts interval subtraction and its universal coverage theorem in the existing
VariantValidation module. union_identity/union_finite_identity state exactly when
ordered flat validation preserves the original value; the existing union_error
law still forbids retry after a selected error. PrototypeTypes adds fuel-bounded
all-branch projection, its membership proof, checker/replacement edges and complete
inference/declaration provenance. Numeric certificates cover bounded and unbounded integer
sources and integer Enum projections; mixed scalar normalization has the generic
identity theorem under explicit recognizer/shape/validator premises. Host lowering,
mutable Type overrides, primitive bit costs, hash/GC behavior and asymptotic
allocation bounds are not proved. This advances Appendix C/D type-protocol future
work; full resource limits and complete acceptance checks remain required.

Unbounded-source acceptance uses the same residual algorithm: a false lower
endpoint denotes negative infinity and a false upper endpoint positive infinity.
Only finite endpoints undergo predecessor/successor arithmetic. Finite covers
cannot erase an infinite residual; a missing single integer remains a gap even
at arbitrarily large endpoints. There is no finite cutoff or Any fallback.
`UnboundedUnionServiceType` reuses the rich declaration factory with optional,
keyword and rest inputs, bounded results and callbacks, then the original
FUN/refine/bind-evidence publication. Negative and positive unbounded inputs,
refinement refusal, ambiguity, quota exhaustion and fresh retry are executable
controls. Keyword/escape sources keep the public transport restriction.

This is an Appendix C/D type-protocol extension, not a claim that the Racket
reference implements this inference algorithm. Lean generalizes the existing
interval projection/subtraction proofs to optional endpoints and proves every
integer in an accepted source belongs to the original ordered alternatives.
The complete inferred specialization retains every constraint and builder
artifact. Ordered validation still needs the explicit identity/shape agreement
premise; a selected error never authorizes a later branch. Host parsing,
serialization, custom predicates, GC and primitive bit costs are outside these
proofs. The finite endpoint-partition oracle complements rather than replaces
the universal Lean soundness theorem.

### Atomic numeric sources in the same coverage protocol

Integer and UInt now enter the existing Union-source admission gate through
`numeric-bounds`, as all-integer and nonnegative unbounded intervals. Projection,
ordered residual subtraction, quota accounting and all-branch flat admission
are shared with IntegerRange; there is no second numeric checker, finite cutoff,
Any fallback or conversion of the public descriptor. The fixed intrinsic scalar
recognizers remain authoritative; custom validators are not inferred equivalent.

`UnsignedUnionServiceType` supplies the zero/positive-tail bound to the original
rich signature factory. Paired Integer/UInt cases reuse the same complete
specialization, declarations, optional/keyword/rest forwarding, nested Function
wrapper, FUN/refine and evidence-bound publication. Runtime negative-input and
keyword/escape-token failures remain enforced. An equivalent range candidate
still creates genuine ambiguity; unsupported candidates yield no-solution and
quota exhaustion stays a typed refusal before the builder, followed by fresh
retry. Public Union-to-Union order/identity and Map key invariance are unchanged.

Lean's numericUnion derivation records the existing numeric view explicitly.
`numericBounds_contains` proves source observation preservation, and
`numericUnion_sound` composes it with universal unbounded coverage. Conditional
replacement composes the existing numeric-view and range-to-Union model laws;
it adds no semantic model assumption. Shared inferred declaration proofs retain
all constraints and the exact atomic descriptor in the built artifact. The
integer projection does not model host keyword parsing, serializers, custom
recognizers or GC/bit-operation costs; those claims are not made. This continues
the article's type-protocol future work, rather than claiming the Racket
reference already provides this static inference algorithm.

### Bool coverage through its complete finite domain

Bool enters the same flat source protocol using the private literal view
`(Enum #f #t)`. Exactly/Enum membership and ordered Union traversal perform the
check; no second literal recognizer, Any fallback or public descriptor rewrite
is introduced. Both values must be covered, including false as ordinary data.
Bool can also replace an explicit Enum containing both values. That supporting
finite judgment preserves genuine ambiguity between Bool and an equivalent
literal candidate; a singleton or missing value still gives no-solution.

The full tree must remain intrinsic and flat. An earlier Bool alternative does
not hide a Function/container/custom validator; public Union branch order and
Map key identity stay invariant. Keyword and escape origins retain the existing
transport judgment, and no runtime selected-branch error permits fallback.
Coverage consumes the original quota and exhaustion cannot become false or a
partial declaration. The finite oracle independently checks both Boolean values;
false/zero, keyword/escape, selected-error and malformed/incomplete controls remain.

`BooleanServiceType` uses the original rich signature with optional/keyword/rest
inputs, a duplicate true alternative, both result values and nested Function
wrapping. Numeric, text and Boolean factories now share `infer-signature-calls`
and the original typed fragments, generic owner and FUN/IO publication. Gerbil's
grouped using contracts check host callbacks. A Boolean refinement can approve
false, bind evidence to the exact context, or refuse before the consumer; retry
starts a fresh inference request. Examples exercise both values and rejection.

Lean adds a Boolean literal projection beside the existing integer projection,
retaining the same all-branch flat admission. booleanCheck_total is exhaustive
for every Bool, and booleanUnion_validate composes it with the existing ordered
identity-validation theorem. Conditional replacement explicitly requires the
Boolean finite-view interpretation law; it does not prove mutable host Type
overrides, keyword parsing or arbitrary validators. The complete specialization
proof uses the same generic signature builder for numeric and Boolean prefixes
and preserves the exact Bool artifact and every declared/call constraint.
Homogeneous Boolean literal leaves model Exactly/Enum via singleton/general
lists; mixed scalar behavior retains the generic identity/shape premises. No
serialization, primitive-cost/GC or general predicate implication claim is made.
This continues the article's type-protocol future work, not a claim that the
Racket reference implements this static coverage algorithm.

See [intrinsic scalar Union coverage](scalar-coverage.md) for String/Symbol/Keyword,
its exact decidable scope, shared publication chain and proof interpretation bounds.

See [finite inference audit and emptiness](finite-inference-audit.md) for remaining P2 coverage and the required-field witness protocol.

See [literal intrinsic descriptors](intrinsic-descriptors.md) for singleton, width, byte, alias and admission coverage.

## Necessarily empty Map carriers

The common replacement rule keeps keys invariant and values covariant whenever
source entries may exist. It now also accepts another Map layout when the existing
positive finite empty-Type witness proves the source key **or** source value
uninhabited. In that case every admitted table has zero entries. Its empty hash
carrier is inhabited: it does not become String, Never or an empty element for
List. A nested necessarily empty Map therefore cannot justify emptiness of an
outer Map. Direct ordered Union replacement and keyword/escape rules are unchanged.

This is observational readable replacement, not permission to insert target keys
or mutate a table. Candidate syntax, original key/value descriptors and comparator
policy are retained. No opaque recognizer is queried to infer emptiness; hidden
unsupported syntax still refuses admission, and work exhaustion is distinct from
negative coverage. Unknown callback semantics and nonempty finite catalogs supply
no witness. No Any is synthesized.

`infer-retired-route-service` reuses the complete descriptor-service solver,
prefix specialization, qualified declarations and descriptor-service-action's
FUN/refine/bind-evidence chain. A live handler remains recursively wrapped beside
a retired table with its original impossible-key metadata. Integrated controls
cover unique selection, distinct original candidates remaining ambiguous,
nonempty insertion refusal before consumer admission, clearing/retry, exact
subject/context evidence, and intact raw callbacks. Existing Map validation uses
Gerbil hash snapshots/new-table policy through validate-bindings; an empty source
is retained by identity and invokes no child validator. No extra table traversal,
cache or descriptor registry is added.

Lean's existing checker, Subtype derivations and replacement theorem include the
same empty-key/value rule. `map_key_or_empty` exposes the exact alternatives;
`map_key_invariant` now requires nonempty component semantics. The interpretation's
emptyMap law is explicit. `VariantValidation.map_empty_snapshot` derives zero
entries from complete per-entry membership and either uninhabited component;
`map_empty_replacement` derives success for arbitrary target key/value validators
without executing them or a collision comparison. Top-level PrototypeTypes and
VariantContracts examples exercise complete inference, prefix substitution,
universal replacement and Function-bearing snapshots. Faithful host snapshots,
carrier/comparator preservation, callback behavior and supported source stability
remain explicit boundaries; this advances finite type-protocol future work,
not unrestricted predicate inference or a proof of the host runtime.

## Source Union coverage for readable containers

A source Union may replace one ordinary List, Tuple, Pair, Map, Record or Object
view when **every original branch** passes the existing complete carrier/child
relation for that same target. This extends the earlier flat scalar rule; it does
not reorder, flatten, delete or rewrite alternatives. Direct Union-to-Union
comparison stays invariant. Root Function/opaque-target inclusion is not expanded
by this rule. Incompatible vector/list carriers, improper Pair tails, missing
fields and live Map-key changes still refuse through their existing judgments.
Nested Function fields use their existing variance and wrapping obligations.

An empty source Union is uninhabited and vacuously covers an admitted ordinary
container; its runtime validator still refuses every value. Complete syntax
admission precedes comparison, so an unsupported late branch cannot be hidden by
an earlier successful branch. Each branch comparison shares the existing work
quota. Exhaustion remains distinct from a completed false result, no solution
or genuine ambiguity. No Any is synthesized.

The existing infer-worker-service factory now accepts original ordered
Record/Object alternative candidates. The worked regression retains UInt8 and
UInt callback layouts, inherited Record/contract field validation, nested
Map/List callbacks, complete prefix inference and qualified declarations. Its
FUN/refine/bind-evidence chain retains exact subject/context evidence, original
candidate syntax, approval refusal/retry and raw callbacks. A first-selected
UInt8 callback still refuses an out-of-range result even when a later UInt layout
would accept it; validation never retries that later branch. Reversed original
candidate trees remain genuinely ambiguous. Public ObjectContract sexp is a
nominal display, so provenance uses captured finite syntax rather than display
identity. Existing validators, Gerbil collection mechanisms and publication
abstractions are reused without another dispatch or cache layer.

Lean's existing Subtype/check/check_sound/replacement chain now covers ordinary
List/Tuple/Pair/Map targets using all original branch derivations and the existing
Union shape interpretation law. Row-bearing host views additionally use their
existing field laws. VariantValidation.union_normalized_member proves membership
of the **actual normalized result** in an original selected branch;
sourceCoverage_wrapped transfers that result through complete branch coverage.
Unlike the earlier flat identity law, it does not assume normalization leaves
raw values unchanged. Existing union_error still preserves selected failure.
Top-level PrototypeTypes/VariantContracts examples compose complete declaration
inference, original artifact provenance, prefix substitution, universal inclusion
and normalized Function-bearing payloads.

This advances the article's finite type-protocol future work. Branch membership,
faithful host carrier/row interpretation and behavioral Function inclusion remain
explicit premises; procedure recognition alone does not certify behavior. No
mutable-write permission, arbitrary predicate inference, unrestricted recursion,
effect rollback or host runtime/compiler verification is claimed.

## Complete source-branch checks for finite data views

Source Union decomposition now uses one common branch judgment for admitted
ordinary finite data targets: built-in flat scalars, List/Tuple/Pair/Map,
Record/Object, Maybe/OrFalse, TypeValuePair catalogs and Sum. This closes the
previous whitelist omission for optional/dependent/tagged views. Every original
branch must replace the SAME complete target through its existing rules; known
sentinel and empty-carrier evidence can therefore compose across nested layouts.
No new implication between arbitrary predicates or opaque descriptors is inferred.

Direct Union-to-Union identity, opaque token targets and direct Sum tag-skeleton
rules retain their existing bounds. Callable targets are covered below. Neither
alternative order nor original directory identities are rewritten. Unsupported
late metadata refuses complete admission, budget exhaustion is distinct from a
negative judgment, and original candidate trees remain distinct for ambiguity.
Keyword and escape origins still use the existing dedicated transport relation;
that private flat-origin relation is not replaced by data-view coverage. No Any
is synthesized. An inhabited optional/container sentinel is never bottom.

`infer-availability-service` builds on the existing descriptor-service schema,
complete prefix inference and qualified declaration builder. Its packet pairs a
live handler with a tagged ready/idle state. Ready payloads preserve void, false
or an exact captured Type; idle payloads preserve false or checked handler lists.
Original candidate Union layouts combine all these views before existing
FUN/refine/bind-evidence publication. Regression cases exercise both actual
Function Type identities and bounds, every sentinel, nested callback wrapping,
returned callbacks, exact evidence/context, strict tag order, genuine ambiguity,
approval failure/retry and rejection after a captured source-directory change.
Gerbil validation and hash/collection mechanisms are reused unchanged.

Lean's common source-Union checker case now covers every corresponding finite
Ty data target while preserving direct Union bounds; callable targets are covered
below. Existing
Subtype derivations and replacement remain the proof path; the additional host
sentinel, row and dependent carriers use their established interpretation laws.
`VariantValidation.union_success` exposes the actual selected branch, successful
child normalization and normalized membership. `union_normalized_member` reuses
that success law, so `sourceCoverage_wrapped` still applies without raw-value
identity. OptionalContracts examples combine it with the existing void/false
protocol and catalogTyped_sound/catalog_replacement to prove wrapped payload
membership AND exact carried-token preservation. PrototypeTypes examples cover
complete Sum/optional declaration inference, original artifacts, prefix binding
and universal behavioral inclusion. Later invalid Function results remain errors.

This advances the article's finite type-protocol future work. Faithful host
carrier/sentinel interpretation, behavioral Function contracts, source-read
stability and callback effect/termination obligations remain explicit. No
mutable-write permission, unrestricted recursive inference, effect rollback,
parser equivalence or host runtime/compiler verification is claimed. The full
TODO/P2 ledger is not declared complete.

## Callable source alternatives inside container interfaces

The P2 audit found that the common source-Union rule excluded Function and
CaseFunction targets even when every original branch passed their existing
replacement judgment. This blocked callback directories such as
`(Map (List (Union callback-a callback-b)) <- UInt)` from satisfying a shared
callable interface. The rule now uses the SAME all-branch traversal and shared
quota for these explicit targets. It delegates each child to the existing
ordered call-language checker: inputs are contravariant, outputs covariant,
multiple-value counts exact; optional/keyword/rest transport and first matching
case selection retain their original checks. No new callable representation,
user recognizer implication, branch reordering or Any fallback is introduced.

This is a decidable part of the article's Type Descriptors/Appendix C future
work; the Racket reference does not already implement this finite solver.
Gerbil's case-lambda performs actual procedure dispatch, existing recursive Type
validators install wrappers, and the shared whole-declaration builder composes
FUN/refine/bind-evidence. The implementation adds no second dispatch engine.

`infer-callback-directory-service` publishes a Map/List callback directory and a
Tuple fallback through a Pair packet. Complete inference rejects a candidate
whose optional first case shadows a later two-result case. The selected original
Union stays in the report; an equivalent reversed candidate is ambiguous rather
than silently canonicalized. Tests cover checked calls and multiple results,
invalid argument suppression, first narrow result failure without later fallback,
exact consumer evidence, unchanged raw references, policy failure and retry.
A separate matrix covers Record fields, rich keyword/rest signatures, unsupported
late metadata, exhaustion and empty alternatives.

Direct Union-to-Union and inhabited Map-key layouts remain invariant. A Union
containing a present-or-absent Function cannot become unconditionally callable.
An empty Union has vacuous inclusion but cannot validate a procedure or publish a
runtime inhabitant. Opaque target discovery and unrestricted recursive/effect
inclusion remain unsupported. Static false means no derivation in this algebra;
malformed/unsupported metadata and budget exhaustion retain typed refusals.

Lean's `check_union_function` proves the exact bounded all-branch equation,
including vacuity without fabricating a procedure witness. Existing check_sound,
sourceUnion/replacement and declaration inference laws compose through Map/List
covariance and prefix substitution; Examples/PrototypeTypes.lean supplies positive,
negative and exact-artifact controls. The behavioral inclusion theorem explicitly
requires faithful Union and Function interpretations. Procedure recognition alone
proves neither totality nor output behavior. Gerbil regression tests separately
exercise CaseFunction's richer call language; the Ty checker models fixed arrow
rows, not the whole Scheme decoder, effects, GC or compiler.

### Finite Or admission and readable replacement

The existing runtime `Or` is now admitted by the finite constructor vocabulary,
recursive child traversal, capture-free substitution and descriptor compilation.
It retains its own kind and original ordered children. A source Or replaces one
ordinary admitted scalar/container/Function interface only if every original
child passes the same existing replacement judgment under the shared quota.
Direct Or/Union targets and Map keys retain identity rules; this does not add a
conversion between their serialized discriminants or widen keyword wire modes.
Empty Or has no inhabitant; unsupported children and exhausted budgets still
refuse before a declaration builder can run. Guarded Mu remains an explicit
finite approximant, not unrestricted recursive language inclusion.

Runtime Or retains its original first actual member, matching its discriminant.
Gerbil's `find` supplies the ordered lookup. Union keeps first structural
selection. Both feed one selected-child validator: recursive Function wrappers
are retained, the exact child error propagates and a returned nonmember refuses
without retrying another branch. Or's existing recognition/diagnostic and codec
policies are unchanged. Custom recognizer exceptions propagate; arbitrary callback
effects, global stability and codec correctness are not proved by finite inclusion.

`infer-callback-directory-service` now has the same complete higher-order scenario
exercised for Or and Union: Map/List overloaded callbacks plus a Tuple fallback,
UInt8/UInt outputs, prefix specialization, whole candidate inference, qualified
method declarations and FUN/refine/bind-evidence. Controls retain the selected
narrow wrapper, exact evidence, untouched source procedures, original reordered
candidate ambiguity, invalid calls and policy refusal/retry. Membership/structural
selection and selected-error controls are in variant-validation-test.ss.
The existing bounded alternative generator also recognizes Or, retaining its
descriptor identity and the same depth/node/search limits, shrinking and replay;
opaque callback generation still needs its existing explicit sampler.

Lean's existing VariantValidation namespace specializes its ordered engine as
orValidate, proves exact selected normalization/original failure and transfers
complete branch coverage to the actual wrapped result. Top-level
Examples/VariantContracts.lean distinguishes membership from structural choice
and composes unique declared inference with universal wrapped replacement while
retaining the original branch catalog and artifact. Host recognizer/child behavior
is explicit. This extends the article's type-protocol future work; the Racket
reference does not supply this finite inference algorithm.

### Singleton-empty List coverage through the existing Null judgment

A witnessed impossible element makes `(List Element)` inhabited by exactly `()`,
not an empty Type. Previously List-to-Null succeeded and Null-to-intrinsic-Union
succeeded, but their composition was refused. The shared replacement rule now
requires the existing positive `empty-type?` child witness and delegates to the
same `Null` comparison under the original quota. It retains the List AST in the
inferred assignment, descriptor, signature and declaration artifact.

Only entirely intrinsic identity-validating targets use this view. For example,
`(List (Pair Never (Function (UInt) (Integer))))` covers
`(Union Bool (Union Keyword Null))`, including inside Pair/Map values and Function
results. No payload or child callback can run on nil. An empty vector or Map is
another carrier; a List of empty Lists, optional sentinels or empty vectors has
possible nonempty lists. Neither can borrow this witness. Map keys and direct
ordered alternative descriptors remain invariant. A Union containing Function
or other wrapping branches stays outside this rule, even if it contains Null.

The existing `infer-descriptor-service` factory and `descriptor-service-action`
compose the whole workflow: prefix-bind the intrinsic Union input, infer the
original impossible-element List output from complete call observations, install
qualified methods, wrap the returned callback, refine publication policy and
bind exact context evidence. Policy refusal does not consume the observer;
a fresh action can retry. Two distinct singleton-List descriptions remain
genuinely ambiguous. Invalid callback arguments, nonempty batches, unsupported
late branches and quota exhaustion retain their original failure semantics.
`t/inference/empty-inference-test.ss` exercises this complete chain without another driver.

Lean's `emptyListCheck_into_iff` proves that target membership of nil is both
necessary and sufficient, using the existing witness and actual List membership.
`emptyListCheck_normalized` preserves the exact value under the intrinsic target's
explicit identity-on-nil law. `inferEmptyList_into` preserves the original complete
unique declaration artifact and transfers every actual source value. Top-level
`Examples/PrototypeTypes.lean` includes ordered flat-view, normalization and
ambiguity controls. Host carrier interpretation and child emptiness soundness
remain explicit; arbitrary recognizers, effects, mutable writes, codecs and
compiler correctness are not proved. This advances the article's finite type
protocol future work, not an existing Racket inference solver.

Raw keyword coverage now shares the existing finite emptiness witness for
impossible container origins. The original descriptor remains intact; actual
empty collections/sentinels stay live and complete closure still gates every
call region. See [finite-inference-audit.md](finite-inference-audit.md#impossible-container-origins-in-raw-keyword-coverage)
for the retired-keyword publication example, failure semantics and proof scope.

## Shared request quota through declaration admission

Call projection owns admitted copies of actual/formal constraints; the private
solver reuses their syntax judgment instead of traversing those copies again.
Public raw queries retain complete bounded shape and grammar admission. Final
source admission rechecks mutable builder output and live catalog revisions,
then requires exact equality with
the private checked snapshot. Successful declaration reports finish installation
before returning; their lazy fields capture artifacts rather than request work.

The concentrated audit found a concrete cross-phase reset: the three declared
entry points metered initial binding/inference with the caller's quota, then
`declare-instance`, live-bound inspection and `admit-signatures` created fresh
8192 counters. Successful inference could therefore bypass the caller's remaining
budget during final admission. A second lifetime bug was exposed by the exact
sufficient-quota regression: Map syntax and Record .cc fields retained child
compiler calls, which spent an already completed request counter on first runtime
observation. Both are implementation gaps within the existing type algebra.

The checked compiler now captures compiled Map Key/Value and Record Slots before
entering those lazy constructors. Runtime validation, clones and nested Function
wrapping reuse those exact descriptors without invoking the compiler again. The
regression closes a counting callback immediately after compilation, then checks
first observation, cloning, wrapped calls and input/output failure controls.

`instantiate-declared`, `infer-declared` and `infer-declared-calls` now create one
existing `type-work` closure and thread it explicitly through the checked workers,
captured source syntax, live binding checks, reflected signature forcing and final
admission. The checked workers compose existing algorithms; they do not introduce
another solver, Type namespace or fallback. A standalone public inspection still
owns its own request. Independent nested public requests have independent counters.
The default 8192, maximum 1048576 and depth 64 are unchanged.

Exhaustion before the declaration builder prevents that callback. Exhaustion after
the builder returns no published instance; prior callback effects are not rolled
back. A builder failure precedes later admission and retains its original cause.
No-solution/ambiguous complete reports return without entering declaration
admission. Retry starts a fresh request, rechecks current sources and may succeed
at the exact sufficient quota. Nothing caches approvals or failed balances.

`metadata-service-request` prepares the explicit prefix as a separate bounded
specialization and returns the existing budgeted residual inference/declaration
operation. Repeated attempts revalidate and capture live candidates/observations.
Its worked regression exhausts final admission, then retries with the exact
sufficient quota and follows the original nested Pair/List/Map/optional callback
validation, qualified method combination, FUN, refine and bind-evidence chain.
A shared three-entry regression directory checks the pure-stage boundary, exact
complete boundary, late refusal, reentrancy, original causes and fresh retry.

The quota counts protocol-owned structural work, not arbitrary builder/computed
callbacks, descriptor factories called by those callbacks, wall time or GC.
Declaration expansion retains its existing recursion/construction guards; process
limits still bound host execution. Lean `declarationStage_compose`,
`completeDeclaredWork_sound`, early/late refusal, builder-refusal and larger-budget
laws establish balance/provenance for explicit abstract stage charges.
observeDeclaredWork_balance retains the ended-request balance when observing a
captured descriptor; host closure independence remains the executable
poison-counter correspondence premise.
`Examples/Parameters.lean` composes these laws with the existing complete metadata
publication. Its illustrative 7/5 charges are not measured Scheme costs and do not
prove every runtime visit is metered. This advances the article's type-protocol
future work; the Racket appendix does not already implement finite inference.

## Request-owned query evidence

Raw `infer-prototype` / `infer-declared` queries are admitted as a complete finite
pair batch and copied before Type admission and candidate enumeration. The same
request-owned snapshot supplies the solver, selected/alternative inequalities and
top-level diagnostics for unique, ambiguous and no-solution reports. Reusing the
caller's buffer, even inside a declaration callback, cannot silently rewrite the
constraints reported for an earlier solve. Original literal names, keyword markers,
branch order and catalog token identities are preserved by existing `copy-type`;
no canonicalization is applied to query evidence. Known call projections already
own their constraints and do not gain a redundant copy or admission traversal.

The existing bounded pair traversal rejects deep/cyclic input before copying;
syntax failures, unsupported Types, bounds refusal, work exhaustion and callback
errors keep their phases. Standard ordered traversal and the existing shared
work counter remain in use. This does not promise an exact copying/GC cost model,
thread-atomic capture of concurrently mutated input, immutable public reports,
transitive Type purity or a permanent authorization certificate.

`signature-request-action` reads each query batch through existing Reader/FUN
bind and reuses a checked prefix and the complete declaration factory. Its
regression workflow reuses one buffer across successful publication, no-solution,
fresh requests and refinement refusal, retaining nested Function wrapping and
exact bind-evidence contexts. Ordinary declaration callback reuse and all three
classification results have independent controls.

`LeanPoo.Functional.InferenceReports` extends the existing DeclarativeMetadata
namespace and delegates to `inferDeclared`, rather than implementing another
solver. `inferDeclaredQueries_sound` proves original reported-query equality,
selected-candidate membership, all original bound/query subtype obligations and
successful builder provenance. Companion laws preserve nonunique classifications, exhaustion and the exact
builder cause even if the builder returns arbitrary changed caller state. Lean's
lists model faithfully captured Scheme syntax; the actual heap copy and host Type
interpretation are explicit correspondence premises, tested in Gerbil. This
continues the article's finite type-system future work; unrestricted inference
and semantic discovery remain outside the claim.

## Retained bindings through source refresh and construction

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

## Public Type request ownership

A live finite-directory observer could rewrite another public operand during
admission: a false Tuple replacement became true, and nested Function compilation
could accept a Bool after its caller syntax was edited. Public `expression-type`,
`subtype-expression?` and `function-covers?` now share `call-with-type-inputs`:
Gerbil's ordered map captures EVERY operand with the existing bounded copier
before invoking the original consumer. Internal inference already owns its input
and continues to use its existing checked operations without another copy.

Source order, leaf/token identity, ordered clauses, errors and one request quota
remain. Copy visits consume that quota; exhaustion before admission invokes no
observer. Callback edits remain visible to later independent requests, and their
original exceptions are not replaced. Existing catalog invalidation still refuses
stale sources; this is not a permanent metadata certificate or a rollback policy.

`checked-operation-action` composes an explicit compiled operation contract with
prefix specialization, finite constraint inference, qualified declarations and the
existing refine/bind-evidence/FUN/IO service. Controls cover both binary operands,
shape changes, an invalid sibling that an observer tries to erase, nested wrapper
inputs/results, policy refusal and fresh retry. Lean `withCapturedInputs` proves
original-input consumption, error preservation and composition with `check_sound`,
conditional on faithful host capture and Type interpretation. It does not prove
Scheme heap copying, arbitrary callback behavior or compiler correctness. This
advances the article's type-protocol future work, not a missing Racket theorem.

## Retained catalog bindings and source revisions

An explicit directory token guarded runtime validation, but its compiled Type did
not register the known directory sources in the existing reverse dependency graph.
A prefix-bound Type could therefore keep revision zero after a directory edit.
When that parameter disappeared from the residual signature, ordinary binding
inspection, inference and declaration preparation could accept the stale snapshot.

`capture-type-values` now owns one deduplicated list of authenticated read owners.
`catalog-contract` registers those owners through `depend-on-object!`, charging
links to the original construction quota. It reuses weak dependency storage and
whole-closure invalidation; registration runs no getters and does not rediscover
metadata or replay approval. Alias/shared paths advance each owner only once.
Each newly compiled parameter is stamped immediately, before compiling later
parameters or running the binding getter. The existing pure revision fence checks
these new stamps before returning; it never refreshes an invalid stamp after a
callback. Independent-directory and binding-window controls cover this ordering.
Unused directory entries and explicit external roots still belong to the complete
snapshot. Unrelated sources remain unaffected, and runtime source guards preserve
original callback failures. No arbitrary transitive callback dependency is inferred.
The compiler carries provenance through catalog-derived container/Function children,
checks each child stamp before linking its parent, and links TypeValuePair owners
without changing carried Type identity. The emitted result descriptor is stamped
before argument compilation and checked before return. Ordinary scalar-only
constructors acquire no dependency edges. All added links/checks share the original
quota; no source observer or metadata rediscovery runs in the final pure checks.

`catalog-service-type` retains a Policy Type independently of its Input/Output
signature. The existing specialized-action supplies inference, qualified methods,
refine, bind-evidence and FUN/IO publication. `catalog-inference-test.ss` covers nine
residual entry paths, directory/unused-member/root/Class-Slot edits, pending action
refusal before body/IO effects, policy denial and recapture/retry with nested
Function wrappers. The new module is included in the complete test inventory.

Lean composes registered finite reverse paths and cache revision laws with the
existing bindingsCurrent/specializeCurrent gates, including shared invalidation
and unaffected-frame controls. Faithful capture/edge registration, finite bounded
paths and sequential supported mutation are explicit premises. This advances the
article's type-protocol future work; it proves neither Gerbil heap/GC behavior nor
unknown callback sources or compiler correctness.


## Whole-request finite directory admission

Individually current catalog tokens were insufficient: reading a later independent
directory could revise an earlier one, leaving a successful negative judgment or
no-solution report based on incompatible snapshots. The same gap affected query
and candidate directories absent from the selected signature during declaration
construction. This is a finite known-source coherence omission, not unrestricted
callback dependency inference.

`call-with-current-catalogs` encloses grammar admission, recursive compilation,
finite inference, specialization and declaration construction in one request.
It retains actually admitted directory snapshots in first-read order and deduplicates
aliases by their private snapshot identity. Successful completion, including false,
no-solution and ambiguous reports, reuses the existing authenticated pure source
replay under the original quota. Final checks do not invoke observers, rerun
inference, rediscover metadata or cache approval. Internal composition shares the
frame; nested public requests retain their own final check and budget. Original
callback exceptions propagate unchanged, and callback effects are not rolled back.

`staged-service-action` composes the existing Reader/FUN declaration pipeline with
refine, bind-evidence and IO publication. Regression controls cover independent
source drift, unused candidate mutation during construction, refusal before body/IO,
recapture and retry, nested request isolation and exact original exceptions.

Lean's `finishTypeRequest` composes existing binding admission with the original
consumer result. Its laws establish exact healthy results, refusal of every stale
successful classification, original error precedence and currentness of every
recorded source. Host replay retains its exact `stale slot dependency` error;
the model represents source refusal through the existing `.bounds` admission
outcome, without identifying host exception objects. Top-level
`Examples/Parameters.lean` includes cross-directory
replacement and publication controls. Host-faithful recording, source identities,
revisions and supported sequential mutation are explicit premises. This advances
the article's type-protocol future work; it does not prove arbitrary callbacks,
concurrent host heaps, GC behavior or the Gerbil compiler.

## Uninhabited selected call rows

Function replacement now distinguishes structural call shapes from their legal
supplied values. After the original first target clause is selected, a positive
existing empty-Type witness for any supplied positional/keyword formal can
exclude that row from replacement obligations. Optional defaults and unused rest
positions are not supplied inputs. A live row still requires a source shape,
contravariant supplied inputs and covariant results with the exact output count.
The public `function-covers?` gate remains a structural shape-language check;
it does not drop these rows or become a value-sensitive replacement certificate.

This is a finite decidable omission in the existing protocol, not arbitrary
predicate emptiness. `types/relation.ss` reuses `empty-type?`, the shared quota,
standard presence-aware hash lookup and `function-signature.ss` normalization.
Positive and negative witnesses are cached only inside one replacement request;
exceptions/exhaustion cannot install a partial witness. Empty Lists/Maps/vectors,
Maybe/OrFalse sentinels and procedures remain inhabited or unknown. A Never
result does not make a Function empty. No Any, default execution or arity adapter
is manufactured, and every syntax sibling is admitted before emptiness is used.

Selection commits before this check. An impossible first case does not expose a
later case with the same shape. Keyword decoding/escape modes and saturated
rest regions retain the existing call-language engine. Omitted optional inputs
remain live; supplied impossible optional/rest/key cells can be discharged.
Unknown predicates, unrestricted recursion and host procedure arity/totality
remain outside the checker. Failed supplied validation still refuses before the
body, output validation or overload fallback.

`examples/signature-service.ss` now publishes a closed handler directory whose
Map values and refresh results share one Callback assignment. Gerbil case-lambda
implements actual zero/two-argument callbacks; declared reserved one-argument and
optional/rest slots are provably impossible. The whole declaration is inferred
only after Value prefix specialization, then the existing Reader/FUN, refine and
bind-evidence workflow wraps every nested callback. Regression controls cover
unique/ambiguous/no-solution inference, exact context/subject evidence, refusal,
retry, selected-case ordering, mandatory keyword impossibility, optional omission,
live container/sentinel counterexamples and malformed/exhausted requests.

Lean keeps the existing PrototypeTypes namespace. `emptyCallRow_refuses` reuses
EmptyLaws and the original emptyCheck witness; `selectedCallCheck_live/first`
retain live coverage and first selection. `emptyCallRow_invoke_refused` composes
the existing invokeValues rule to exclude body/fallback after faithful input
validation. `inferCallRows_sound` composes the original complete declaration
solver, retains the exact built artifact and proves every inhabited cell's
original obligation. The top-level GeneratedCalls examples exercise dead/live
selection and whole unique/ambiguous declaration construction. These laws require
faithful supplied-Type projection, intrinsic emptiness/shape interpretation and
live-cell coverage; they do not prove a new parser, all host predicates, arbitrary
callbacks or runtime/GC behavior. This advances the article's type-protocol future
work while retaining complete checks and their original resource limits.
