# Bounded prototype polymorphism, subtyping and inference

For the Object/row and guarded Mu extensions, see [row-types.md](row-types.md).

This implements a decidable part of the original type-system **future work**.
The Racket discussion in “Prototypes are Useful Even Without Subtyping”, “Type
Descriptors” and Appendix C/D motivates explicit universal Self/Super parameters,
subtype constraints and `(Proto A B) = (Fun A B -> A)` with `A <: B`.
It does not provide the following solver as an existing paper implementation.

## One composable protocol

`type-relation.ss` admits this finite expression grammar:

```scheme
Any | Bool | Integer | UInt | declared-variable
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

Replacement is conservative: exact ordered field names/counts, covariant readable
Types, and required-to-optional weakening only. An optional source cannot promise
a required target; an open source cannot replace a closed target. Width/permutation
inclusions and Record/Object cross-constructor relations are not guessed, and
Record field lists are not sorted or erased during normalization. This rule is
complete only for the documented finite derivability relation, not every possible
semantic record inclusion or Class inheritance relation.

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
The concentrated tests are `t/record-inference-test.ss`; complete single-process and
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
even after a valid candidate. Invalid candidate-dependent observations are
preflighted through the existing keyword decoder, including with an empty universe.
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
  and Union requires every exposed alternative to be stable. Any is unsafe.
  Ordinary input contravariance and exact-count output covariance still apply.
- Positional source / keyword target: each selected target region with `n`
  positions and `k` keys generates the raw length interval `n+2k .. 2n+2k+1`.
  The upper endpoint includes escaping every position and a trailing `#!rest`.
  Clamp raw lengths beyond the largest fixed prefix to its one rest representative;
  select the **actual first source clause by raw length** at each region. Fixed,
  optional and several ordered case-lambda clauses may jointly cover that interval.
  No source rest is needed when the target's raw language is bounded.
  A non-tail row of length `n` with no keys has no escapes: compare supplied input
  Types by ordinary contravariance. Every other region requires Any only at
  **supplied** source positions, not unused optional fields. Every selected pair
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
publication through `catalog-service-action`. See `t/function-coverage-test.ss`.


`PositionalCallbackServiceType` / `infer-positional-callback-service` and
`KeywordCallbackServiceType` / `infer-keyword-callback-service` use the same fixed
Value prefix, candidate inference, whole declaration builder and
`catalog-service-action` FUN/refine/bind-evidence chain. Runtime callbacks retain
ordinary default execution and exact raw token sequence respectively. See
`t/keyword-coverage-test.ss`, including no-solution/exhaustion before builder calls,
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
through FUN/refine/bind-evidence. `t/keyword-prefix-test.ss` checks fixed-only case
unions, unused optional Types, trailing escape upper bounds, shared raw arities
across target cases, stationary rest refusal, nested callbacks/Map-key invariance,
full publication and no-builder quota/failure paths. Its independent runtime oracle
enumerates 1365 unmodified token rows, not the coverage algorithm's cells.

This remains a conservative finite decision: non-direct regions require supplied
Any positions even where a richer value-sensitive token analysis might succeed.
Direct minimum rows use the existing finite Type algebra, not a new restricted-value
subtyping engine. False means unproved coverage/replacement; malformed/unsupported
syntax and exhausted shared work retain their TypeRefusal causes. Shape coverage
alone does not establish direct-row input variance; subtype replacement does.
Neither incomplete region traversal nor failed/ambiguous inference enters a builder.
