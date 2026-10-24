# Intrinsic scalar coverage in ordered Union

This advances the article's Appendix C/D type-protocol future work. It does not
attribute this finite inference procedure to the Racket reference.

## Decidable fragment

The source is the intrinsic String, Symbol or Keyword family. The target is a
finite ordered tree containing only known flat intrinsic families, literal
Exactly/Enum and integer intervals. For the fragment without Any, coverage holds
exactly when some nested branch contains the same complete intrinsic family.
Earlier finite alternatives may select individual members; they cannot cover
an infinite family collectively. Cross-family conversion is never inferred.

| Target | Checked result |
| --- | --- |
| Same-family primitive, possibly nested among flat alternatives | Covered |
| Finite literal alternatives and other disjoint families only | Not covered |
| Function/container/refinement/custom validator inside the tree | Outside this rule; no shortcut through an earlier matching family |
| Malformed/unsupported metadata | Typed syntax refusal, even after a matching branch |
| Work quota exhausted | Typed exhaustion, never a successful or partial result |

String literal metadata remains unsupported because strings are mutable. Known
Symbol/Keyword literals retain exact identity. An explicit Any retains its
existing semantics, but no Any is manufactured and the exact-family theorem is
stated for the admitted positive fragment without Any. Complements, arbitrary
predicates, dependent type implication and general set-algebra inference remain
outside this criterion.

## Keyword transport and failures

Gerbil's string?, symbol? and keyword? predicates identify distinct families.
Neither #!key nor #!rest is a Keyword value. Keyword-to-Union value inclusion does
not change keyword-stable-type? or permit conversion between positional and
keyword-interpreting signatures. Public literal token origins keep their prior
guard, and Union-to-Union order/duplicates and Map key identity remain invariant.

A Keyword value passed to a rich keyword signature must use the existing
encode-arguments/decode-arguments protocol. The shared publication action now
encodes its semantic positional input according to the declared keyword mode;
it does not treat a keyword value as a named parameter. Unescaped values and
escaped marker payloads remain subject to shape/type failure. Callback signatures
without keyword parameters continue to accept Keyword data directly.

Selection still commits to the first matching branch. A selected validation
error never tries a later branch. Full-tree intrinsic admission is required
before coverage, and all normalization/comparison work uses the existing quota.
False/no-solution, ambiguity, typed exhaustion and user callback failures remain
distinct; no incomplete or nonunique assignment reaches a declaration builder.

## Shared workflow and verification

scalar-union-service-type and infer-scalar-service use the original rich
Self/Super signature and shared call/declaration factory. The existing
optional/keyword/rest host binder supplies a missing bonus from the checked input.
The same identity callback is recursively wrapped. Numeric, text, Boolean and
scalar policies share one signature-refinement-action and the existing FUN/IO
publication/evidence action. Scalar refinement can refuse before its consumer;
evidence remains bound to the exact current context, and a fresh request retries.

Tests cover all three families, ordinary/fresh uninterned symbols, fresh keywords,
mutable String values without String literal metadata, duplicate/order controls,
finite-only gaps, wrapper shortcuts, keyword and escape boundaries, selected
errors, complete declarations, nested callbacks, inference ambiguity/exhaustion
and refine/evidence success and refusal. No test requires a Lean checkout.

Lean keeps the existing namespace and separates PrototypeTypeSyntax,
PrototypeTypeCoverage and PrototypeTypes by function. Homogeneous Symbol/Keyword
Enum leaves use abstract natural-number literal IDs. scalarWhole_iff proves the
necessary and sufficient whole-family criterion. scalarFresh constructs a missing
member beyond every finite literal cutoff, rather than sampling a finite test
set. scalarCheck_sound/complete retain family classification and complete flat
admission. scalarUnion_validate reuses first-selected identity validation;
inferredScalar_sound preserves every constraint and the exact bound artifact.

Host name encoding and the connection from abstract IDs to intrinsic family
values are explicit interpretation premises. The proofs do not verify the host
keyword parser, arbitrary/mutable Type overrides, String/Symbol conversion,
serialization, GC or primitive bit costs. Ordered validation requires fixed
shape/membership and identity behavior. Full resource limits, complete local
checks and exact-head CI remain required independently of the model proofs.

## Intrinsic numeric families and complete publication

The runtime already supplied Number, Real and Float in number.ss, but the finite
syntax registry rejected those names. They now use the same private registry and
recursive compiler as the other built-ins, with Gerbil's number?, real? and
flonum? predicates. No replacement class/interface protocol or type namespace is
introduced. The shared numeric judgment admits Float <: Real <: Number and every
existing exact integer interval/width <: Real <: Number. These are intrinsic
predicate facts, never general consequences of prototype ancestry.

The complete syntax on both sides is admitted before comparison. A Float or Real
source can use a matching Real/Number leaf in an entirely flat ordered Union.
Finite literals and integer intervals cannot cover all Real or Number values:
exact noninteger rationals and nonreal numbers remain distinct. Integer does not
become Float, Bool does not become Number, direct Union order and inhabited Map
keys stay invariant, and TypeValuePair retains actual descriptor identity. The
existing literal language still rejects mutable strings and floating/complex
literals; no numeric rounding, coercion, predicate implication, complement
reasoning or serialization conversion is inferred. Keyword and escape tokens
remain outside all three intrinsic numeric families.

examples/numeric-services.ss uses the existing qualified declaration factory,
prefix specialization and complete finite solver for a measurement Map paired
with a higher-order calibrator. Gerbil's hash-key-value-map and compose implement
explicit value conversion in the producer. Recursive Function wrappers protect
both returned calibrators and the returned batch converter; inference does not
execute them. descriptor-service-action retains the existing refine,
bind-evidence and FUN/IO publication chain. Regressions cover independent host
recognizers (including rational, nonreal, infinite and NaN inputs), unchanged
values, variance, optional/keyword/rest and ordered case signatures, exact return
counts, invariant keys/direct alternatives, stale-free independent retry,
nonunique/no-solution requests and policy refusal before consumer effects.

Lean's existing PrototypeTypes namespace adds NumericFamily and
NumericObservation in PrototypeTypeDescriptors. numericFamilyCheck_sound proves
universal inclusion, numericFunction_replacement composes the existing arrow
variance theorem, and inferNumericFamily_sound reuses inferDeclared to retain
both original bounds and the exact published artifact. Top-level
Examples/PrototypeTypes.lean contains the corresponding controls. The abstract
observation classes require faithful host predicate classification; these proofs
do not verify floating-point arithmetic, conversion accuracy, codecs, arbitrary
mutable descriptor overrides or the Scheme compiler/runtime. This advances the
article's type-protocol future work, not a claim that its Racket reference already
implements finite inference. Full checks and existing resource limits remain
independent acceptance gates.
