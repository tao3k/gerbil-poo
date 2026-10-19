# Finite inference audit and witnessed emptiness

This extends the article's Appendix C/D type-protocol future work. The Racket
reference motivates explicit subtype and modular-extension obligations; it does
not implement this finite candidate inference algorithm. An empty record value
used as a composition seed is inhabited and is not an empty Type.

## Remaining substantive coverage

| Priority | Finding | Acceptance / next boundary |
| --- | --- | --- |
| P2 optional sources | Optional sources could not replace ordinary flat targets even when both sentinel and payload were covered | Closed by the shared two-branch source decomposition: original sentinels and payloads must each replace the same intrinsic flat target, including entirely flat ordered Union targets. No wrapper-bearing shortcut, Map-key widening or Any fallback; decision-service integration and refusal/retry controls are in optional-inference-test.ss. |
| P2 optional coverage | Payload lifting, finite Bool/Enum coverage and cross-sentinel composition were refused | Closed within the admitted finite relation: both original sentinel and payload obligations must hold; Bool and immutable Exactly/Enum enumerate every source value. Existing runtime validation, Map-key identity, Union order and keyword-origin restrictions remain intact. See optional-inference-test.ss. |
| P2 singleton lists | A List with a witnessed empty element could not satisfy Null bounds or singleton Pair tails | Closed via the existing empty-type? witness and shared replacement quota. The List is inhabited by nil, not an empty Type. Descriptor metadata, Map keys and ordered Union branches stay unchanged; singleton-handler inference/declaration/publication has end-to-end controls. |
| P2 carrier safety | Null was incorrectly equated with the empty vector Tuple; Pair spines could not satisfy List bounds | Corrected to distinct carriers. Null-to-List and Pair-to-List reuse the existing child/tail replacement judgment and shared quota; handler-batch inference, qualified declaration, refinement and evidence publication have integrated controls. No Tuple/list conversion or structural implication of opaque Types is added. |
| P2 first | Impossible mandatory products/rows were refused across kinds | Implemented here: positive finite emptiness witnesses feed the existing replacement judgment, shared inference, ordered parameter specialization and whole declaration admission. |
| P2 covered | Runtime Null/Unit and fixed-width numeric/byte descriptors | Closed for literal bounded UIntN/IntN/BytesN, Bytes, singleton names and existing fixed aliases; see intrinsic-descriptors.md for admission, interval/carrier and artifact laws. Dynamic widths remain unsupported. |
| P2 bounded catalog | TypeValuePair carries an actual Type identity | Implemented for explicit finite intrinsic-name catalogs: shared identity membership, live read replay, recursive normalization and exact-tag inclusion; see intrinsic-descriptors.md. Dynamic Class/Schema Types now use explicit stable snapshot-local tokens from capture-type-catalog; see intrinsic-descriptors.md. Arbitrary discovery, callback implication and structural widening of opaque Types remain open. |
| Outside current boundary | Arbitrary predicate implication/emptiness, implicit principal or higher-rank inference, unrestricted recursive language inclusion | Unsupported; neither samples nor an Any fallback establish these laws. |

Existing finite Function/case language, keyword-origin, Pair/Map/Sum/Union and
explicit Object/Record protocols retain their documented bounds. This audit does
not claim complete runtime Type coverage or mark every TODO complete.

## Implemented judgment

### Optional sentinel and payload coverage

`optional-related?` replaces the earlier small Null/Unit exception with one
shared rule for Maybe/OrFalse targets. Successful same-kind covariance keeps its
existing fast child proof. Broader optional sources then require BOTH their
original sentinel and their payload to replace the target. Ordinary carriers
lift through the original child relation. Bool and immutable Exactly/Enum sources
check every literal, treating false as successful OrFalse absence and checking
every remaining value through Exactly and the same child judgment. Void is
Maybe's sentinel, not an Enum literal. Missing coverage is false; malformed or
unsupported syntax and work exhaustion remain distinct typed refusals.

The rule compares finite metadata; it does not invoke caller-defined recognizers or rewrite
the candidate AST. Maybe/OrFalse may exchange nesting only when each original
sentinel is explicitly covered. A bare Maybe UInt still cannot replace OrFalse
Integer, nor the reverse. Optional Functions remain optional, not unconditionally
callable. Map keys and direct ordered Union replacement retain their identity
rules. A lifted Union retains its original complete tree in the child proof;
no committed branch is reordered. Keyword/escape origin restrictions stay under
the existing function coverage algorithm. No Any is synthesized.

`infer-optional-handler-service` composes this with prefix specialization, whole
candidate inference, qualified method fragments and the existing
descriptor-service-action FUN/refine/bind-evidence chain. Mixed void/false/list
results and returned callbacks retain recursive Function wrapping. Regressions
cover incomplete finite coverage, both missing sentinels, escape values, invalid
callback batches, exact selected nesting and evidence, policy failure/retry and
genuine ambiguity between two equivalent original optional representations.

Runtime `validate-optional` is unchanged: absence returns its original value
without demanding the child; present values lock the original child normalizer
and retain its errors and post-membership check. Coverage proves readable
inclusion, not equality of arbitrary custom-validator effects or mutable writes.
Existing source admission and descriptor revision obligations remain in force.

Lean's existing OptionalValidation namespace proves payload_replacement,
sentinel_replacement, finiteCoverage_sound and inferOptional_sound, reusing its
Admits/normalize protocol and the existing complete declaration search. The
proofs require actual child inclusion and complete host Bool/Enum interpretation;
they retain both obligations and the original captured signature/candidate pair.
Top-level Examples/OptionalContracts.lean includes exhaustive Bool controls,
different-sentinel compositions and exact declaration artifacts. Host syntax
projection, recognizers, wrappers and effects remain separate runtime obligations.


Optional sources now also replace ordinary intrinsic flat targets through the
same two-branch obligation. `(OrFalse (Exactly #t))` covers Bool;
`(Maybe Never)` covers Unit, while `(OrFalse (Enum))` covers exactly false.
Empty children never erase their source sentinel. Entirely intrinsic flat Union
targets can jointly cover both branches, including nested void/false optionals,
numeric intervals and Keyword leaves. Each check retains the original candidate
AST and shared work quota. Wrapper-bearing Union targets, invariant Map keys,
direct ordered Union relations and keyword/escape origins are not widened.
Optional Functions remain non-callable without checking their present branch.

`infer-decision-service` exercises this inside Pair fields with a recursively
wrapped Function, a concrete Bool decision and Unit acknowledgement. It reuses
the complete prefix-specialization/declaration/FUN/refine/bind-evidence chain;
invalid sentinels, returned callback inputs, policy retry and genuine equivalent
candidate ambiguity are checked. No Any is synthesized. Missing coverage is false;
unsupported metadata and exhaustion keep their typed refusal semantics.

Lean's replacement_into_iff proves both source obligations are necessary and
sufficient. normalized_replacement establishes membership of the exact returned
value under the existing normalizer, preserving its checked Function wrapper;
inferOptional_replacement retains the original completed declaration artifact.
Host descriptor interpretation and the flat target's identity validation remain
premises. These are readable inclusion laws, not arbitrary effect equivalence or
compiler verification. This finite type protocol advances the article's future
work; it is not attributed to the reference Racket implementation.

### Container carrier audit

The following concrete paths were compared against their actual validators;
this is not a claim of unrestricted runtime Type or callback soundness.

| Family | Carrier and replacement boundary retained |
| --- | --- |
| Tuple / List / Pair | Exact vector arity / proper lists / cons pairs including improper tails. No vector/list coercion; Pair-to-List checks the entire tail. |
| Map | Hash-table carrier; keys keep exact normalized syntax, values have readable variance. Existing shared binding validation preserves returned wrappers and refuses normalized collisions. |
| Sum / Union | POO tag/value objects with the declared tag skeleton / ordered alternatives with committed first structural selection. Payload covariance does not reorder tags; Union equality is invariant. |
| Maybe / OrFalse | Distinct void/false sentinels; present payloads use their actual validators. A sentinel is an inhabitant, never evidence of an empty payload Type. |
| Object / Record | POO objects with explicit field presence and open/closed policy. Optional presence cannot supply a required field; opaque Class ancestry grants no structural implication. |

A prior carrier-audit gap was singleton-list admission: an empty
element witness proves that every accepted proper list is nil, but the old
replacement judgment still rejected List-to-Null. The shared judgment now uses
that positive witness, including nested impossible products/required rows and
all-empty alternatives. It does not reinterpret a failed emptiness search as a
proof, and it does not make List itself an empty Type. Existing Pair recursion
propagates the result into exact singleton tails without another normalization
engine. Empty Tuple, List, Map, byte vectors and optional sentinels are explicitly
tested as inhabited child Types and cannot justify this rule.

`infer-single-handler-service` composes the new tail judgment with prefix
specialization, one whole candidate solve, qualified method installation and the
existing descriptor-service-action FUN/refine/bind-evidence chain. Source
descriptor identities remain in the solution: equivalent Null and empty-element
List candidates remain genuinely ambiguous. Failed and ambiguous requests do not
run a builder; invalid callbacks and multi-element tails refuse; failed approval
does not consume evidence and a fresh action can retry. Original exceptions and
effects retain their existing semantics; no rollback or compiler proof is claimed.

Lean's existing PrototypeTypes namespace adds emptyListCheck_sound,
emptyListCheck_inhabited, singleton_tail and inferEmptyList_sound. These prove
universal nil inclusion, nonemptiness of the accepted Type, preservation of the
one original head, and exact declaration provenance. Soundness of the child
empty-Type witness and correspondence of host constructors remain explicit
premises; the existing empty-type witness model and runtime regressions cover
their separate obligations. Checks and resource limits are unchanged.

The parser first admits both complete finite expressions. Comparison retains its
existing fast successful path; only a failed judgment attempts empty-replacement?.
empty-type? consumes the existing shared work counter and reuses range-bounds,
empty-range?, field-required? and Gerbil's short-circuit list combinators:

- Never, empty Enum and reversed finite integer ranges have no accepted value.
- Tuple/Pair need one empty mandatory child.
- Nested Union/Sum need every alternative payload empty, including zero alternatives.
- Object fields are mandatory; Record requires an explicitly required empty field.
- List/Map can be empty collections. Maybe/OrFalse have sentinel inhabitants.
  Optional fields, procedures, opaque Types and unknown predicates cannot prove
  emptiness. A negative witness search does not prove inhabitation.

Direct Union and Sum sources keep their existing branch/tag replacement protocol,
even if empty. Union targets still require complete flat intrinsic admission;
an empty source cannot hide wrapper-bearing alternatives. Map keys retain exact
normalized identity. No descriptor is
rewritten to Never, deduplicated, reordered or replaced by Any. A witnessed empty
enclosing product may cross carrier kinds: this is vacuous readable inclusion,
not a permission to convert values, mutate slots or bypass validation.

Explicit Mu uses its existing finite approximant only. Nothing here discovers
emptiness of an unrestricted recursive fixed point. Both admission and witness
work remain bounded; malformed/unsupported syntax, negative judgments, exhaustion,
no solution, ambiguity and callback exceptions retain distinct outcomes. An empty
candidate can satisfy a bound; inference does not claim that an observed Type has
a realizable runtime value. Builders run only after complete unique inference.

## Integrated checks and proof scope

EmptyCallbackServiceType prefix-binds Value and infers a structured Dead callback
input under Dead <: String. It reuses infer-signature-calls, the typed qualified
fragment builder and the common refinement/publication/evidence action. A real
UInt call succeeds; its returned callback retains the impossible input wrapper.
The regression checks refusal before callback effects, negative refinement before
consumer admission, retry, no solution, ambiguity, admission/quota failures,
required/optional rows and inhabited empty-container/sentinel controls.

Lean's EmptyType and emptyCheck_sound prove finite witnesses. EmptyLaws exposes
scalar emptiness and carrier projection/selection premises; EmptyType.refuses
then proves universal rejection, not a finite sampling claim. requiredField_refuses
states the required-field projection law independently of row representation.
The existing check/check_sound, Subtype and replacement theorem include the new
rule, while Union branch, Sum tag and Map key invariants remain proved.
Examples/PrototypeTypes.lean proves the disabled callback fixture and exact
inferred declaration artifact after prefix specialization.

These are conditional denotational laws. Host predicate identity, required-field
projection, parser behavior and runtime wrappers are separately tested; the Lean
model does not prove the Gerbil compiler, callback termination, GC or allocation
costs. The row lemma requires an actual required-field projection premise, not
an inference from nominal Class ancestry or a proof of the Scheme row compiler.
No Scheme source or test depends on a Lean checkout.
