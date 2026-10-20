# Finite inference audit and witnessed emptiness

This extends the article's Appendix C/D type-protocol future work. The Racket
reference motivates explicit subtype and modular-extension obligations; it does
not implement this finite candidate inference algorithm. An empty record value
used as a composition seed is inhabited and is not an empty Type.

## Remaining substantive coverage

| Priority | Finding | Acceptance / next boundary |
| --- | --- | --- |
| P2 finite Or protocol | Runtime Or lacked recursive wrappers and inference admission | CLOSED through existing ordered selection, shared selected-child normalization and all-branch source coverage. Original Or membership selection, Union structural selection, descriptor kinds, Map keys and codec boundaries remain distinct. Complete callback-directory publication and conditional Lean laws are covered. |
| P2 impossible tagged payloads | Retired Sum variants with positively impossible payloads still blocked readable views | CLOSED by the shared empty-Type witness before each complete row obligation. Runtime validation and original tag metadata remain; inhabited empty containers/sentinels do not qualify. Complete tagged-worker publication and conditional universal Lean proofs retain the original artifact. |
| P2 tagged object carrier | Sum values already have required tag/value fields but could not replace a readable Object/Record | CLOSED through one open row per exact symbol tag/original payload and the existing complete row rule; declaration/refine/evidence integration, recursive wrappers, extra inherited data, refusal/retry, ambiguous layouts and Lean observation/normalization laws are covered. Closed targets, unknown optional extras, reverse replacement and codec casts remain bounded. See row-types.md. |
| P2 callable source alternatives | Closed the shared source-Union target omission for Function/CaseFunction, including nested Map/List/Tuple/Record callbacks | Every original branch uses complete ordered signature replacement under the same quota; optional shadowing, multiple results, keyword/rest, first selected result failure, full declaration/refine/evidence, ambiguity and retry are checked. Direct Union and Map keys remain invariant; opaque targets remain bounded. See prototype-types.md. |
| P2 optional/dependent/tagged alternatives | The container-only source Union whitelist still refused finite optional, dependent and tagged target views | Closed through one shared finite-data branch rule: built-in flat views, Maybe/OrFalse, TypeValuePair and Sum reuse existing sentinel, directory/tag and child judgments. Opaque and direct Union bounds remain; callable targets are closed above. Availability publication and selected-token/normalized-result proofs compose the whole chain; prototype-types.md and union-inference-test.ss. |
| P2 container source alternatives | Only flat source alternatives could cover one ordinary target, blocking Record/Object and nested Function-bearing container interfaces | Closed for explicit ordinary List/Tuple/Pair/Map/Record/Object targets through the existing all-branch recursive relation. Source order and normalized wrappers remain; direct Union targets and opaque targets retain their bounds; callable targets are closed above. Full worker declaration/publication controls and normalized-result proofs are in union-inference-test.ss and prototype-types.md. |
| P2 necessarily empty Maps | Key identity blocked replacement even when a key or value had a positive empty-Type witness | Closed through the common Map relation: zero possible entries may use another Map layout; inhabited entries retain key identity/value covariance. No Map becomes an empty Type. Complete retired-route publication covers wrappers, original metadata, ambiguity, insertion refusal and retry; prototype-types.md and container-inference-test.ss. |
| P2 empty dependent directories | Empty TypeValuePair catalogs rejected every runtime value but were missing from the common emptiness witness | Closed for zero catalog entries through the existing finite relation: mandatory products, singleton lists and absent optional fields share the witness. Nonempty directories remain opaque; callback failure is not emptiness evidence. Integrated plugin publication retains carried Type identity, Function wrappers, original metadata, retry and stale-source refusal. |
| P2 absent optional fields | Impossible optional payloads still blocked closed layouts and unrelated optional target children | Closed through the existing positive finite empty-Type witness and one shared row protocol: forgotten keys/bypassed children need actual absence, not sample omission. Required targets and source closure remain strict; inhabited containers/sentinels, opaque tokens, Map keys and ordered Union retain their boundaries. Sealed worker inference/declaration/FUN/refine/evidence covers retry, present-field failure and genuine ambiguity; row-types.md and t/descriptor-inference-test.ss. |
| P2 named carrier bridge | Record and Object could not replace one another despite their shared POO object carrier and existing field protocol | Closed for explicit finite layouts in either direction: one common presence/closure/child judgment, preserved descriptor kinds, guarded optional absence and original recursive validators. Opaque Class/Schema tokens remain nominal; Map keys/ordered Union stay invariant. Worker publication covers inherited defaults, nested callbacks, inference, specialization, declaration/refine/evidence, ambiguity and retry; row-types.md and t/descriptor-inference-test.ss. |
| P2 source alternatives | Flat Union sources were refused even when every branch fit an ordinary intrinsic target | Closed through the existing shared all-branch flat relation, preserving original branch trees, direct Union-to-Union/Map-key invariance and keyword origins. Wrapper-bearing sources refuse; empty Union remains uninhabited. Measurement-service integration covers Map/Pair fields, wrapping, inference, specialization, declarations and FUN/refine/evidence; t/union-inference-test.ss. |
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


### Source alternatives into ordinary intrinsic targets

A completely intrinsic flat Union source can now replace an ordinary intrinsic
flat target only when EVERY original branch replaces that same target. The shared
flat-subtype? rule already owns ordered andmap traversal, literal/interval/byte
judgments and quota charging; the public replacement dispatcher now admits this
direction. For example, negative-range/zero/UInt alternatives replace Integer,
and Exactly/Enum Boolean alternatives replace Bool. Nested and overlapping source
branches retain their original order and syntax. An empty Union has no values;
vacuous coverage does not make runtime validation accept a fabricated value.

This is a read/validation inclusion, not a serialization conversion. Direct
Union-to-Union replacement remains invariant, including semantically equivalent
reorderings. Map keys keep exact syntax. Any wrapper-bearing or non-flat source
branch refuses this path even if another branch would match a particular sample.
Missing coverage is false; malformed/unsupported syntax and shared work exhaustion
retain distinct typed refusal semantics. Keyword/escape origin restrictions and
first-match validation errors are not relaxed, and no Any is introduced.

infer-measurement-service puts the rule inside UInt-indexed Map values and Pair
fields next to a recursively wrapped Function. It reuses complete inference,
prefix specialization, qualified declarations and descriptor-service-action's
FUN/refine/bind-evidence chain. Regressions check source/Map identity, false data,
returned callbacks, policy failure/retry, bad branches and genuine ambiguity of
original candidate descriptors. Ordinary subtype observations do not rewrite the
selected output declaration to its target.

VariantValidation.sourceCoverage_exact/sourceCoverage_sound prove exhaustive
branch obligations and universal membership. sourceCoverage_normalized reuses
committed Union validation to retain the exact value under explicit source and
target identity premises; selected-error controls retain the original cause.
DeclarativeMetadata.inferSourceUnion_sound connects complete unique search to
both original ordered artifact provenance and universal inclusion. Top-level
Examples/PrototypeTypes.lean exercises overlapping branches and failure controls.
These generic interpretation laws complement the restricted Ty checker; they do
not claim its completeness, Scheme parser correctness, arbitrary callback effect
equivalence or host compiler verification. This advances the article's type
protocol future work; Racket does not supply this finite inference algorithm.

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
`t/empty-inference-test.ss` exercises this complete chain without another driver.

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

### Impossible container origins in raw keyword coverage

A reproduced mismatch remained between ordinary replacement and the raw decoder
product graph: `Never` keyword payloads were recognized as impossible, while
`(Pair Never Function)`, impossible Tuples/rows and empty TypeValuePair directories
were treated as potentially supplied. This refused valid positional callbacks
for keyword callers whose retired keyword cannot carry any actual value.

The duplicate scalar-only `empty-origin?` algorithm is removed. The graph now
reuses the same positive finite `empty-type?` witness as ordinary replacement for
positional, ordinary and keyword payload origins. Gerbil `hash-ensure-ref` caches
only completed true/false results within this graph; quota/host exceptions never
install an answer. The existing work counter covers witness preparation and
traversal. No successful coverage, approval or source snapshot is cached across
requests or revisions.

This is not permission to discard empty collections. Nil inhabits List Never;
empty Maps/vectors and optional void/false sentinels remain live keyword payloads.
Unknown Class/Schema descriptors cannot supply emptiness evidence. Source clause
selection, raw/rest position correlation, marker/keyword boundaries, exact output
variance and original ordered descriptor metadata remain unchanged. Complete
backwards closure is still required even for a region claimed to have no calls.
Unsupported syntax and work exhaustion remain typed request failures.

`RetiredKeywordServiceType` and `infer-retired-keyword-service` reuse the existing
prefix solver and qualified declaration factory. The returned positional callback
uses the existing Gerbil argument decoder, rather than another parser. The
`keyword-rest-test.ss` workflow combines inferred metadata, raw escapes, infinite
rest tails, recursive callback wrapping, FUN/refine/bind-evidence, exact context,
policy refusal/retry and genuine candidate ambiguity. Actual retired payloads and
live incompatible outputs refuse before consumer admission. The original retired
keyword stays in the target contract; it is not removed from the declaration.

Lean's existing FunctionSignature protocol adds `rawPruneEdges_mem` and
`rawGraphPath_prune`: under a sound positive witness, every realizable original
trace retains exactly its ordered edges, including arbitrarily many rest cycles.
`rawGraphCheck_pruned_sound` composes this with the existing complete closure
certificate, retaining a selected source and every slot law for each actual call.
Top-level `Examples/RawArguments.lean` includes complete unique
publication with the original graph, dead/live edges, fuel and missing-source
controls. Host decoder correspondence and child-witness interpretation remain
explicit; arbitrary predicate implication, compiler/runtime correctness, effects
and performance are not proved. This advances the article's finite type-protocol
future work, rather than an already implemented Racket inference solver.

### Intrinsic alternative origins in raw keyword transport

A reproduced P2 omission affected flat Or/Maybe/OrFalse arguments: the same
keyword callback was accepted with Union but refused with an intrinsic Or.
`flat-origin-view` now shares the existing flat inclusion solver and ordinary
restriction across these identity-validating alternatives. It visits children in
order with Gerbil's `map-in-order`, admits only a complete view, and represents
void/false sentinels explicitly. No recognizer executes during this projection.
The view is private to raw transport: public descriptor kinds, ordered branch
replacement, original metadata, Map key identity and selected validation errors
retain their existing judgments. A wrapping/opaque child refuses the complete
view and keeps the original comparison. Shared request work exhaustion remains
a typed refusal; no Any or universal complement is manufactured.

`TokenCallbackServiceType` and `infer-token-callback-service` use the existing
prefix inference and qualified declaration builder. The integrated regression
publishes the original CaseFunction through FUN/refine/bind-evidence, checks
false/void, escaped keyword/marker values, keyword placement and long rest tails
against independent Gerbil keyword/rest formals, and exercises validation refusal,
policy failure/retry and bound-only candidate ambiguity. The ambiguity control
uses the complete declared bound; the successful publication also solves call
observations. Unsupported children, insufficient work, wrapper-bearing branches,
real ordinary Boolean data and invariant Map keys have explicit negative controls.

Lean's existing FunctionSignature module proves ordered all-child projection,
no partial success after a refused child, universal membership preservation and
intersection with the decoder's ordinary-data predicate. The top-level example
models all keys and optional Boolean values, proves its intrinsic interpretation,
and composes complete unique declaration provenance with exact identity validation.
Projection applies compositionally at each alternative layer. Host intrinsic
recognition/identity and decoder correspondence remain explicit interpretation
obligations; general predicates, wrapping alternatives and compiler/runtime
verification are not claimed. This advances the article's finite type-system
future work; it is not a Racket implementation claim.

## Concentrated finite protocol acceptance

The main TODO now groups the accepted P0/P1/P2 work by complete protocol family,
with explicit outside boundaries. A new `candidate-inference-test.ss` directory
contains 39 templates spanning current intrinsic families, every structural
constructor, both Map spellings, literal metadata, rich Function/case signatures,
row tails and guarded Mu. For each template, the same checks retain source syntax,
compare staged/full substitution and canonical idempotence, then compare direct
assembly, partial prefix binding and complete residual inference. Catalog/owner,
raw keyword and container runtime controls remain in their existing full groups.
This finite directory does not claim exhaustive value generation or unrestricted
subtype completeness; explicit Any is not used to make a template pass.

`substitute-type` now delegates all ordinary constructor traversal to the existing
`map-type-children`. Only Mu binder shadowing remains substitution-specific.
The shared ordinary mode preserves Map arrow spelling as well as field/tag names,
presence, Function option order and recursive binder/depth; canonical mode alone
normalizes the spelling. Map semantics were already the same in either direction;
this is a coherent metadata transformation contract, not a new carrier conversion.
Gerbil's standard ordered maps and plist/alist conversions remain the substrate.

`MetadataServiceType` and `infer-metadata-service` reuse the existing signature
solver, qualified declaration builder and catalog FUN/refine/bind-evidence action.
One publication integrates a disjoint row extension, Pair/List/Map values, nested
optional Sum/Tuple callbacks and a callback-bearing service result. Regressions
check deferred execution, literal field identity, all nested call wrappers, exact
context evidence, invalid-input suppression, invalid returned data, policy refusal
and retry. No second validator, method engine or publication path is introduced.

Lean's existing PrototypeTypes protocol proves identity and composition for every
structural expression, including complete lists of constraints. RowTypes proves
field transforms preserve names/lookups and commute with accepted disjoint
splicing. RecursiveTypes proves finite unfolding commutes with transforms under
explicit bottom/body substitution laws; those premises include binder safety.
Top-level Examples/Parameters.lean composes specialization, complete unique
inference and original declaration provenance for the composite service packet.
Rich host metadata interpretation and primitive/decoder/binder correspondence
remain explicit obligations. The article's future-work boundary is unchanged.

## Shared request quota through declaration admission

The concentrated audit closed fresh default-counter resets between inference and
final declaration admission in all three declared entry points, and delayed
Map/Record child compilation that reused a completed request counter. Binding/search,
source capture, live checks and admission now share one existing work closure.
Exact-boundary, late-exhaustion, reentrancy, original-cause and fresh-retry controls
compose the metadata/FUN/refine/evidence workflow; Lean proves explicit ledger
composition and artifact provenance. Callback execution and GC are not visit costs.
See [the complete protocol and proof boundary](prototype-types.md#shared-request-quota-through-declaration-admission).
