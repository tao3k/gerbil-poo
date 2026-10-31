# Declarative signatures and generated tests

This extends the descriptor construction described in the original Type
Descriptors / I/O Validation and Beyond section. That section names input/output
validation, pseudo-random generators and value compressors. The new concrete
Gerbil protocols advance that direction of future work; they are not presented
as an implementation already supplied by the Racket listings.

## Three-way correspondence

| Concern | Gerbil | Lean |
| --- | --- | --- |
| Required / optional positions, rest, declared and required keywords | `mop.ss` Function descriptors; `function-signature.ss` uses the host keyword escapes | `Functional.FunctionSignature.Signature`, `Call`, `accepts` |
| Ordered case-lambda shapes | `CaseFunction` selects first structural match; no fallback on type/body failure | `select_first`, `select_sound`, `invoke_type_error` |
| Supplied-only normalization | Child Types wrap nested Function values before one target invocation; defaults stay in the target | `supplied_length`, `invoke_shape_error` |
| Descriptor generation | `testing/type.ss`, explicit `.generator` extension, higher-order products | `samples`, `samples_length` under stable draw premises |
| Call-row generation | `FunctionArguments` in `testing/function.ss`; overlapping shapes draw the first selected clause's types | Structural selection laws, finite controls in `Examples/GeneratedCalls.lean` |
| Shrinking | Domain membership, strict natural measure decrease, retained falsity, finite attempt budget | `admissible_sound`, `shrink_preserves`, `shrink_budget` |
| Reuse | Reports capture descriptor/sampler/dependency revisions; stale outcomes and replay are refused | `admit_stale` |

The property model's candidate list is the observed stream, including candidates
generated after restart. Its fuel counts every proposal, not just accepted
shrinks. The model assumes callbacks terminate and return finite proper candidate
lists; host callback termination is protected operationally by the existing
process watchdog and heap limit, not proved by fuel.

## Acceptance and boundaries

`Examples/GeneratedCalls.lean` belongs in the top-level Examples directory.
The Scheme `examples/signature-service.ss` combines optional List callback fields,
keyword defaults, recursive Function wrapping, descriptor-driven call generation
and Reader/FUN consumption. Both repositories retain their complete checks and
resource limits. No Scheme runtime or test imports a Lean checkout.

Generators derive Bool, Integer, UInt, IntegerRange, UIntN, IntN, Z/, Rational,
String, Symbol, Keyword, Bytes, BytesN, Exactly/Enum and bounded recursive
List, Tuple, Pair, Union, Maybe and OrFalse graphs. Other opaque Types,
refined Types and Function *values* supply an explicit `.generator`; the example
supplies a semantically chosen identity callback. Arbitrary closure synthesis,
inference and subtyping remain open. Automatic guarded recursive data generation
is now implemented; see [recursive-generators.md](recursive-generators.md).
Function call shrinking currently preserves the supplied shape and shrinks its
values. It does not promise deletion of optional parameters or global minimality.

A property must return a Boolean. Generation, validation, measure and property
exceptions remain errors with their original cause; they cannot produce a pass.
Zero trials are refused. Every trial and shrink result checks source revisions;
custom samplers must register additional mutable callback dependencies, or pass
those sources explicitly through `check-property`'s `dependencies:` argument.
Constructor-produced samplers retain their declaration binding. Changing only
`descriptor` on an inherited sampler is refused; construct a new sampler (or use
`from-generator` with an explicit checked value projection). Replacing `sources`
never erases sampler/actual-Type ownership. Trace model/List metadata are fixed
at construction; prepare a fresh trace sampler after revising those declarations.
Already discovered recursive graph owners retain first-observation snapshots.
Undeclared ambient state remains outside the stable callback premise. This is sequential revision admission, not an atomic
concurrent publication protocol.

Replay fixes seed, trial count, size, shrink budget and sampler. Repeatability
requires the same host PRNG/runtime and stable callbacks/ambient state; it is not
a cross-runtime distribution theorem. A passed sample is not a universal proof.
`minimal?` describes only exhaustion of the supplied immediate smaller candidates;
budget exhaustion never certifies that minimum.

Recognition of a Function remains procedure recognition. Its checked invocation
requires a host procedure compatible with the declared formal signature. The
wrapper does not introspect or prove native arity, termination or side effects;
host defaults/body errors propagate. A declared keyword API uses Gerbil's standard
`#!key`/`#!rest` forwarding; signatures with no keyword API preserve legacy raw
positional keyword values. Source callback dependencies must be declared.

Exact interval descriptors use a nearest-to-zero admitted anchor, a size-limited
inclusive window and segment-preserving shrinking. An omitted IntegerRange bound
is unbounded; malformed endpoints fail preparation and empty finite domains exhaust
without drawing. Fixed/modular endpoints must be exact finite integers. A draw
has at most twice size plus one choices; arithmetic cost still depends on endpoint
bit widths. Capture invalidation retires old samplers and reports; prepare a fresh
sampler to observe changed bounds. See the numeric cases and Record/Function/FUN
service in `examples/property-numbers.ss` and `examples/generated-products.ss`.

Keyword spelling generation uses the same Unicode scalar list tree as String and
Symbol. Empty keywords are values, not missing parameters. Use the ordinary
FunctionArguments descriptor for positional/optional/keyword/rest rows; it owns
the escape boundary. The keyword-routing action in `examples/generated-products.ss`
shows Record/Function/FUN composition, corpus replay and fresh repair. Content
shrinking preserves exact carriers; symbolic refinement still requires an explicit
sampler. No string is evaluated or treated as module syntax.

Explicit `map-generator` requests own their original finite key and dependency
spines. Key/Value metadata is observed in order under first-version authority;
a getter that revises an earlier participant refuses preparation. A failure
preserves its original callback cause and effects; prepare a new Map sampler to
retry. `map-service-action` in `examples/collection-properties.ss` demonstrates
how a custom two-service tree retains that same Map guard through typed FUN,
Function wrappers and portable replay. No new parser or validator chain is used.

All typed entrypoints share first-observation sampler snapshots. A later sources
getter cannot revise an earlier actual/bound Type and silently renew it. Explicit
dependency spines and returned source spines are copied before later preparation;
source identities retain their earliest versions. Original getter exceptions and
binding errors remain distinct from stale refusal. Prepare a fresh bridge/action
after correction. `service-value-generator` and `service-batch-action` in
`examples/collection-properties.ss` show shared Record/Function producers, FUN,
shrinking, portable replay and fresh retry. No hidden dependency inference or deep
payload snapshot is promised.

Bridge and specification binding use the same captured stamp set. Metadata getters,
owned recipes and fallback binding are checked before the next stage; a factory
returning #f may use the raw path only while its sources remain current. A generic
tree yielding false is a present tree, not a missing recipe. Nested core probes
inherit the preparation scope, which is released before ordinary execution.
`service-factory-action` in `examples/collection-properties.ss` shows a deferred
Record/Function recipe, bounded probe, FUN, shrinking, three replay forms and
fresh corrected preparation. Direct arbitrary host effects are not transactional.

Reader recipes freeze dependency identities at construction, capture current
configuration/Type/sampler sources before library-owned getters, and thread those
identities into automatic-generator preparation. Each explicit fresh invocation
may capture new epochs; replacing the caller's dependency spine cannot erase old
owners. Configuration size is read once through standard dynamic slot access.
Configuration exceptions precede report/consumer creation; incomplete automatic
generation retains existing non-replayable typed reports. Consumer IO and direct
caller argument evaluation stay outside preparation. See P52 in the design RFC.

Named properties now share ordered fixed specification preparation. Use the
existing `testing/property` report-form `define-property` or
`testing/property/test` multiargument assertion form: each fixed specification is
prepared once before generator construction. Later generator expressions can
still depend on earlier generated arguments through the original bind tree.
`call-with-specifications` also exposes the same construction scope to explicit
compositions, using constructor thunks and one callback over the admitted domains.
A failed construction has no run report; standard assertions retain Gerbil's
TestResult behavior. Ordinary invocation options are caller-evaluated arguments.
The named service case in `examples/collection-properties.ss` shows typed Record/
Function generators, FUN delivery, three replay forms and fresh correction without
retaining a transient construction checker. See P53 of the RFC for the boundary.

Generated model traces now use owned lazy neighborhoods. The generic
`testing/property/model` `trace-generator` takes a model, two-value draw callback,
finite parameter shrink callback and step bound; ordinary generator source options
are forwarded unchanged. The typed `testing/type` factory supplies the same tree
through its existing generation field. A proposal budget controls demand instead
of merely stopping after a complete batch has already been built. Explicit
`shrink-trace` calls retain the finite-list inspection contract. Each reached
parameter callback must still return a finite proper list. Exact exceptions and
previously charged work are retained on interruption; budget cutoff is not EOF.
`collection-request-action` in `examples/collection-properties.ss` composes this
with an indexed backend, a Record/Function product, FUN, replay and fresh repair.
See P54 in the RFC for the finite proof and work-count boundaries.

Finite value neighborhoods and model preflight snapshot their input pair spine
before callbacks. A callback may edit its caller's outer list without changing
the already captured coordinates. This is shallow preparation: command payloads
remain shared, and callbacks must obey declared source and payload ownership.
Neither deep copying nor rollback of callback effects is provided. See P55 in
[pbt-design-rfc.md](pbt-design-rfc.md#p55-owned-finite-sequence-preparation).

Generic model.check-trace accepts an optional prepare-system: procedure mapping
a raw fixture into make-system's ordinary fixture record. It runs only after
one-use lifetime admission, under the existing source/dynamic-check scope.
POO check-trace supplies its existing TraceSystem validation here; downstream POO
callers keep their usual with-system/use interface. Do not catch a duplicate-use
error and return an earlier observation: the whole session refuses delivery.
Escaped callbacks refuse before metadata reads after cleanup. See
[P56](pbt-design-rfc.md#p56-fixture-lifetime-admission-before-typed-preparation).

A product unpacker must return a proper list with exactly one value per declared
child. Measurement and finite shrinking reject mismatched rows before invoking
field callbacks. The packer receives a private outer row and may consume it (the
consuming-product-sampler example uses standard reverse!). Finite POO child lists
are admitted and copied before packing or iterator publication. Arbitrary payloads
remain shared under their Type/source contracts; no inverse law is inferred for a
custom pack/unpack pair. See
[P57](pbt-design-rfc.md#p57-fixed-product-row-and-finite-expansion-ownership).


P58 closes portable handoff configuration and physical framing admission.
Gerbil parameter contracts run before observers/computed metadata; standard
reader EOF and a separately guarded physical EOF probe precede decoding. Invalid
requests leave caller ports untouched; malformed input may be consumed and needs
explicit fresh input. Revision/exception behavior and nested Function wrapping
remain with their existing owners. Eleven finite Lean laws model request/source/
framing order, assuming faithful host port operations rather than proving the
reader or I/O rollback. See [P58](pbt-design-rfc.md#p58-portable-handoff-request-admission-and-physical-framing).


P59 closes static trace request admission before computed declarations and
fixture acquisition. Standard Gerbil contracts cover generic/typed check requests,
typed finite limits/dependencies and trace-property binding. Existing model folds,
source checks, Record/Function wrapping and FUN delivery remain the execution
owners. Eleven finite Lean laws reuse Boolean admission and guarded preparation;
callback arity, termination and host cleanup are premises. See
[P59](pbt-design-rfc.md#p59-trace-request-admission-before-declarations-and-fixture-scope).


P60 captures typed trace ingress before computed metadata and registers explicit
owners in the existing first-observation ledger. Validation, repair, checking and
generation reuse the existing Record, source and FUN protocols. Caller spine edits
cannot retarget commands or dependency identities; payloads remain shared. Eight
finite Lean laws model the original request handoff and guarded preparation;
faithful host copying/observers and callback termination remain premises. See
[P60](pbt-design-rfc.md#p60-owned-trace-ingress-and-first-observed-explicit-dependencies).

P61 guards FunctionArguments metadata from its first Function/clause/input Type
observation and carries that authority through cached layouts and lazy children.
See [P61](pbt-design-rfc.md#p61-first-observed-function-input-declarations).

P62 routes fixed recursive carrier fields through ordered edge discovery: quota
precedes metadata, and each returned Type is captured before the next getter.
See [P62](pbt-design-rfc.md#p62-ordered-fixed-carrier-edge-discovery).

P63 shares opaque sampler constructor/source admission between recursive graphs
and typed bridges before optional availability metadata. See
[P63](pbt-design-rfc.md#p63-shared-opaque-sampler-admission-before-optional-metadata).

P64 shares the core's strict Boolean source contract across graph participants,
direct typed checks and cached guards; malformed replies cannot authorize later
work. See [P64](pbt-design-rfc.md#p64-strict-boolean-source-admission-across-typed-composition).
