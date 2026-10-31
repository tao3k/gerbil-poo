# Literal singleton, integer-width and byte descriptors

This advances the article's Appendix C/D type-protocol future work. The Racket
reference supplies modular subtype obligations, not this finite candidate solver.
Runtime validation, finite syntax admission, inference and proof interpretation
remain separate obligations.

## Decidable coverage

| Descriptor | Admitted metadata and meaning |
| --- | --- |
| Null | The empty list, distinct from void and a zero-length byte vector |
| Unit | The void singleton; accepted by Maybe without evaluating its child |
| UIntN | Literal integer width 0..4096; inclusive 0 through 2^width - 1 |
| IntN | Literal integer width 1..4096; inclusive -2^(width-1) through 2^(width-1)-1 |
| Bytes | Any u8vector; identity validation, no copy/freeze of its mutable contents |
| BytesN | Literal integer length 0..65536; exact vector length |
| UInt256, JsInt, Bytes32, Bytes64 | Existing runtime descriptors, with their existing fixed width/length views |

Compilation calls the existing POO constructors and named descriptors. Gerbil's
std/number/misc predicates define the width membership used by named scalar
recognition. No modular normalize operation, byte conversion or host coercion is
used to make an invalid value pass. Metadata admission precedes exponentiation
or construction. Each width charges max(1, ceil(width/64)) shared work units;
syntax/search/normalization still consume their existing units. Large composed
requests can exhaust the default quota even when each individual descriptor is
supported. Callers retain the existing explicit budget APIs.

Widths are metadata, never Type variables or callback expressions. Whole Type
candidates can choose among different widths. Wrong arity, negative/nonintegral
widths and IntN zero are malformed; over-limit widths are unsupported; insufficient
work is exhausted. Neither incomplete inference nor refusal calls the declaration
builder. Negative completed comparisons, no solution, ambiguity and user callback
exceptions remain distinct. No Any is synthesized.

## Replacement and identity

Numeric widths reuse the existing inclusive interval and finite literal/ordered
Union coverage machinery. Exact endpoint checks include UIntN zero, which accepts
only zero. BytesN includes Bytes and the same fixed length; unbounded Bytes needs
a whole Bytes branch, since finitely many fixed lengths cannot cover every vector.
Null/Unit use intrinsic singleton recognition. Null is an empty list; the empty
Tuple is an empty vector, so neither replaces the other. Unit supplies Maybe's void sentinel. Other optional payload
rules remain conservative, and public Union branch/Sum tag/Map key rules remain
unchanged. Wrapper-bearing Union alternatives still fail complete flat admission.

Aliases and interval views are not syntax normalization. Original source names,
widths and order remain in captured metadata and declaration artifacts. Invariant
Map keys do not change even for two extensionally equivalent spellings. Runtime
BytesN's existing descriptor cache can expose Bytes32/Bytes64 display aliases;
source identity is the captured syntax, not a forced rewrite of that cache.
Exactly/Enum's existing literal vocabulary is unchanged: named Unit/Null do not
admit mutable vectors or arbitrary literal expressions into metadata.

## Integrated acceptance and proof boundary

DescriptorServiceType prefix-binds Input and infers Output under Output <: Input.
Existing call observations constrain nested callbacks, then the same complete
qualified fragment builder installs the method. Null, Unit, signed-to-unsigned
and byte-buffer scenarios reuse infer-signature-calls and the common FUN/IO,
refinement, publication and exact evidence chain. Tests cover overflow and length
failures before callback effects, qualifier order, refinement failure/retry,
no-solution/ambiguity, malformed/exhausted admission, aliases and invariant keys.
Small widths additionally use an independent finite membership enumeration oracle.

PrototypeTypeDescriptors keeps the existing PrototypeTypes namespace and models
intrinsic descriptor identities, tagged value carriers, interval observations and
literal admission. intrinsicCheck_sound proves universal same-carrier inclusion
via existing IntegerRange.replacement; numericView_exact connects integer widths
to the existing range interpretation. Byte length never becomes an integer value.
metadataUnits_bounded proves the explicit width preparation charge is at most
1024, independently of value enumeration; it does not measure allocation or GC.
inferIntrinsic_sound reuses complete declaration inference to preserve both bounds
and the exact original descriptor pair, including alias identity. Integrated guards
and endpoint counterexamples are in the top-level Examples/PrototypeTypes.lean.

The new model is an intrinsic descriptor interpretation alongside the existing Ty
algebra, not a proof of the Scheme parser or every runtime Type constructor.
Projection/recognizer correspondence, optional wrapping, host calling conventions,
compiler behavior, serialization, mutation and cache implementation remain explicit
runtime premises and regression obligations. Arbitrary width expressions, host
predicate implication, implicit Class/Schema callback discovery, dependent
parameter-dependent TypeValuePair catalogs, general Boolean algebra and unrestricted recursion remain
open or outside the current decidable boundary. Full resource limits and complete
local/exact-head CI checks remain enabled; no Lean checkout is used by Scheme.

## Proper-list coverage and carrier safety

Proper-list coverage uses the existing recursive replacement judgment: Null
replaces any List, and Pair replaces List only when its head replaces the element
Type and its entire tail replaces the same List. Fixed prefixes and unbounded
List tails are supported without flattening, coercion or Any. Improper tails,
vectors and incompatible mandatory heads refuse; Map keys and ordered Union
branches retain exact identity. Shared work exhaustion remains a typed refusal.
`infer-handler-batch-service` prefix-binds a List of checked Functions and infers
a nonempty Pair/List result, using the existing qualified declaration and
descriptor-service-action chain. Wrapping, policy refusal/retry and exact evidence
are covered by regression. Lean proves universal proper-list inclusion from child
inclusion, distinct zero-length carriers and exact inferred declaration provenance;
runtime projection and wrappers remain implementation obligations.

## Finite dependent TypeValuePair catalogs

`(TypeValuePair UInt Bool String)` restricts the existing dependent carrier to
those exact shared descriptor objects. The payload is still validated through
its carried Type. The finite grammar admits distinct literal intrinsic names or captured directory tokens,
excluding Any/Never, and an empty catalog. It does not admit parameter-dependent
catalog entries, width expressions, predicate callbacks or arbitrary descriptor
objects. A whole catalog expression can still be a prototype type argument.
Compilation, substitution, candidate search and declaration admission retain the
same shared syntax/work limits; source order is preserved, not sorted or erased.

Replacement requires each source identity in the target catalog. In particular,
`(TypeValuePair UInt)` is covered by `(TypeValuePair Bool UInt)` but not by
`(TypeValuePair Integer)`: payload subtyping cannot replace the carried tag. Map
keys and ordered Union trees retain their existing stricter identity rules.
The empty catalog rejects every runtime value; missing catalog membership is a
TypeError before any payload callback, not a request to infer another Type.
Malformed/unsupported syntax, exhausted work, no solution and ambiguity remain
different results. A duplicate name or nonliteral entry refuses admission.

`optional-validation.ss` supplies the shared `type-value-catalog` lowering helper,
with a bounded caller-supplied Type list (at most 64). This runtime helper may
capture explicit Function or custom Types; that does not extend the finite
inference grammar. It snapshots the list, uses Gerbil's eq? membership and reuses
`type-value-shape` / `validate-type-value` for dependent traversal and recursive
Function wrapping. The original pair survives unchanged when its payload does;
a wrapped payload keeps the exact carried Type. Public descriptor sexp equality
is never an authority to run an unlisted validator.

The helper captures actual Slot observations with the existing recording/replay
protocol, including the base validator and each descriptor recognizer. Replay
before and after successful observations rejects supported source/ancestor edits.
Ordinary source reads are reissued between the replay guards, so enclosing cache
observers also receive unselected catalog members; replay alone is not treated
as an observed read. Its original stale-slot error and child exceptions remain distinct from catalog
membership failure. Rebuilding the catalog is the explicit retry. Raw mutation,
unregistered external dependencies and arbitrary concurrent edits have the same
existing unsupported boundary; there is no process-wide catalog approval cache.

`infer-type-value-service` composes the existing rich declaration builder with
finite catalog inference, around/before/after combination, returned callback
wrapping, FUN/refine and exact bind-evidence publication. Regressions cover false
payload data, different carried identities, forged equal-looking descriptors,
parent-source invalidation, rebuilding, ambiguous reordered catalogs, no solution,
policy refusal after method effects and successful retry before IO consumption.

Lean extends `OptionalValidation`'s existing dependent-pair model, rather than
inventing a second validator. `catalogCovers_sound` and `catalog_replacement`
prove readable inclusion for arbitrary payload predicates under stable host
identity. `catalogTyped_missing` proves refusal before payload work;
`catalogTyped_sound` retains the exact tag and normalized payload membership.
`catalog_stale` states guard short circuit; host replay detecting a mutation is a
separate implementation obligation. These are conditional denotational laws,
not a proof of the Scheme parser, Type registry, compiler or unrestricted dependent
type inference. The examples stay in top-level `Examples/OptionalContracts.lean`.
This explicitly advances the article's type-protocol future work; its Racket
reference does not already implement this finite inference extension.

## Dynamic Class and external Schema directories

`capture-type-catalog provider names sources: roots` resolves at most 64 distinct
symbol names through ordinary POO getters, once, into private snapshot-local Type
tokens. Use Gerbil's `agetq` to select a token. Every selected value must satisfy
the existing Type protocol. No Schema namespace, provider language or global Type
registry is introduced: an external Schema is its existing well-formed Type.
Aliases of the same descriptor within one capture share a token; independent
captures remain separate scopes even when a name, Type object or sexp is equal.
Gerbil opaque equality and standard identity tables enforce that boundary.

Tokens can occur as complete Type arguments or nested TypeValuePair entries.
Existing containers, Function wrapping, prefix specialization, finite-candidate
inference and unified qualified declarations compile them through the actual
captured descriptor. Direct Type use receives a guarded delegation, retaining
custom diagnostics, recursive normalization and original child exceptions.
TypeValuePair retains the *actual* carried Type, rather than a proxy identity.
Catalog narrowing never retags values. Replacement is exact token identity;
no structural Class ancestry or equal-looking Schema metadata grants widening.
Opaque keyword-mode conversion is conservatively refused. Existing intrinsic
judgments, invariant Map keys and ordered Union behavior stay unchanged.

Standard Class capture reads both declared and effective Slot inventories and
follows their declared child Types within a 64-descriptor bound. This includes
original Slot metadata even when effective composition copies specifications.
Other Schema/custom-Type dependencies must be declared as explicit source roots
or present in registered observed reads; no arbitrary callback dependency or
predicate implication is discovered. Cached computed selectors must register
external dependencies with the existing `depend-on-object!` discipline. Merely
passing roots does not repair an already stale, unregistered provider cache.
Callbacks must terminate; metadata work counters do not meter arbitrary host code.

The existing Slot observation module now owns `reobserve-slot-reads!`: the same
checked replay walk exposes its complete actual dependency closure through the
ordinary cache-hit delivery path, then rechecks it. Thus nested getter reads,
unselected catalog entries and Type-admission reads reach enclosing collectors.
Metadata preparation and cold getters do not rerun during admission. Traversal
uses the existing depth-first replay order; this is not an assertion that an
effectful observer sees the same trace as cold computation. Edits from an observer
refuse after delivery. No successful approval is memoized across calls.

Malformed capture arguments, unsupported metadata graphs larger than 64 Types,
Type admission failures, missing getters and exhausted shared work remain distinct
failures. Capture resolves/adopts the complete directory before returning usable
tokens. Supported source/ancestor/Slot or declared-root changes raise the existing
stale-slot error on old tokens, even before callback work. Re-capture and
re-specialization are required; new tokens cannot silently replace old ones.
A successful validator followed by source drift refuses its result. A validator
that raises keeps its original cause; its effects are not rolled back. A fresh
snapshot whose Schema policy rejects data returns its original TypeError.

`infer-schema-service` composes this capture with the existing rich declaration
builder, method combination and descriptor-service FUN/refine/bind-evidence action.
Regressions cover computed Class selection and aliases, caller/source revisions,
original Slot edits, nested Function fields, external Schema policy changes,
old-call refusal before method effects, incomplete capture, budget refusal,
custom Schema errors, complete-closure observation and fresh retry/publication.
Duplicate aliases in this example are coalesced before constructing its input
catalog; user Union trees and explicit catalog declaration order are not rewritten.

Lean `OptionalValidation` models snapshot-local identity, complete finite
resolution followed by admission, and guarded calls under exact before/after
source stamps. `catalogIdentity_sound` / `catalogIdentity_scope` prove nominal
replacement and scope separation; `captureCatalog_sound` / `captureCatalog_error`
exclude partial successful materialization; the catalogCall laws preserve exact
normalized artifacts and original errors or refuse old/changed stamps. A stamp
must actually represent the complete declared source set. Host identity, correct
read recording/replay, registration, hidden dependencies, callback termination,
parser correctness and concurrent mutation are explicit implementation premises.
These proofs do not infer arbitrary Class/Schema structural subtyping or extend
the original Racket reference into a proved dependent-type compiler. This is the
article's type-protocol future work, now closed within the stated finite scope.

### Empty dependent directories

The exact zero-entry `(TypeValuePair)` directory supplies positive finite
emptiness evidence to the common replacement relation. Mandatory products and
rows inherit that evidence; a List with this element type contains only nil,
and an optional field with this payload must be absent. Descriptor metadata is
retained in the inferred original candidate. No payload recognizer is consulted
to establish emptiness. Nonempty directories, including captured Types whose
recognizers always return false, remain opaque. Empty List/Map, Maybe's void and
OrFalse's false remain inhabited; invariant Map keys and ordered Union trees
retain their existing rules.

`infer-plugin-service` in `examples/polymorphic-services.ss` composes the complete
finite solver with existing specialization, typed declarations and the shared
FUN/refine/bind-evidence publication action. Its regression fixture keeps a live
Function-valued dependent plugin, removes only a provably absent optional layout
obligation, retains carried Type identity and recursive wrappers, and exercises
failure/retry, ambiguity and source-edit refusal. The validators themselves are
unchanged: malformed pairs, invalid Types and missing catalog membership retain
original diagnostic priority before payload validation.

The companion Lean laws `OptionalValidation.catalogEmpty_sound` and
`catalogTyped_empty` establish uninhabited membership and missing-Type refusal.
`Examples/OptionalContracts.lean` composes these with `catalog_replacement`,
`inferRowView_sound` and `absentField_observe` to derive unique original-layout
selection, semantic replacement and actual absence. Live callback behavior and
host descriptor interpretation remain explicit premises of their existing laws.
This is finite type-protocol future work beyond the article's Racket construction,
not a completeness theorem for arbitrary predicates or a proof of the host runtime.

## Rational and literal modulus protocol

The existing `Rational` descriptor uses Gerbil `rational?`: integers, exact
noninteger rationals and finite flonums are accepted; NaN and infinities are not.
It includes into Real/Number. Float does not include into Rational. Real can
include into a completely admitted flat ordered Union when both Rational and
Float are covered. This checks two obligations without changing branch order,
wrapper selection, invariant Map keys or carried descriptor identity. A missing
family, unsupported sibling or exhausted quota cannot become successful coverage.
Floating/complex literal metadata remains unsupported; no Any is synthesized.

`(Z/ n)` admits a literal positive exact modulus with at most 4096 bits. Admission
uses standard `positive-integer?`, and compilation constructs the existing Z/
descriptor whose recognizer is `uint-below?`. Its exact integer view is [0,n-1],
so endpoint, Enum and ordered flat Union rules reuse the existing interval solver.
No residue enumeration or modular `.normalize` is performed by validation or
inclusion. Whole finite candidates may choose different moduli; a modulus itself
is not a Type variable. Zero, negative, inexact, missing or extra arguments are
malformed; larger metadata is unsupported; insufficient work is exhausted. Each
parser pass charges one visit per 64 metadata bits, at most 64 visits, separately
from the shared syntax/search/compilation work. Catalog and wrapper quotas persist.

`examples/numeric-services.ss` now includes rational sensor batches converted to
residue tables, checked calibrators and checked batch callbacks. Conversion is
explicit producer behavior using standard hash mapping and composition. A second
real relay preserves exceptional flonums through the joint Rational/Float view.
Both reuse Input prefix specialization, whole Output inference, qualified method
fragments and the existing FUN/refine/bind-evidence action. Tests cover unique,
ambiguous and unsuccessful search, malformed/exhausted metadata, independent
host-predicate membership, immutable snapshots, nested argument/result refusal,
policy refusal and fresh retry. An invalid producer result is rejected, not reduced.

Lean extends the existing PrototypeTypes namespace: `numericFamilyCheck_sound`
separates finite/exceptional flonums; `numericFamilyUnionCheck_sound` proves joint
coverage with an actual member of the original target list. `residueRange_exact`
connects interval membership to 0 <= value < n; `residueRange_includes_iff` and
`residue_replacement` prove safe readable replacement for arbitrary admitted
moduli. `residueMetadataUnits_bounded` bounds metadata word visits without value
enumeration, and `inferNumericFamily_union` composes complete unique declaration
inference with ordered joint coverage while retaining the exact artifact. Existing
Function variance laws apply to nested calibrators. Host numeric classification,
faithful wrappers/binders, fixed input snapshots and source behavior are premises;
these theorems do not establish arithmetic/conversion/serialization correctness,
primitive allocation or GC costs, concurrent heap safety, or the host compiler.
This is an extension of the article's Appendix C/D type-protocol future work.
