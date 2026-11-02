# Data generation and retained products

[Design index](../pbt-design-rfc.md)

These sections preserve their recorded implementation and acceptance history.
Case counts and commit identities belong to the named revision; current CI must
be checked separately. The finite laws retain their stated runtime premises.

On this page:

- [Reusable data generation families](#reusable-data-generation-families)
- [Retained structural collection shrinking](#retained-structural-collection-shrinking)
- [Finite-key HashTable and typed Map generation](#finite-key-hashtable-and-typed-map-generation)
- [Declared finite enumeration simplification](#declared-finite-enumeration-simplification)
- [Retained independent product shrinking](#retained-independent-product-shrinking)
- [Shared typed-product observation and directory ownership](#shared-typed-product-observation-and-directory-ownership)
- [Fixed-product source admission before drawing](#fixed-product-source-admission-before-drawing)
- [Exact bounded model draw configuration](#exact-bounded-model-draw-configuration)
- [Finite sequence preparation without prefix salvage](#finite-sequence-preparation-without-prefix-salvage)
- [Finite fixed-product preparation and retained trees](#finite-fixed-product-preparation-and-retained-trees)
- [Portable vector copy preparation and shared resource credits](#portable-vector-copy-preparation-and-shared-resource-credits)
- [Automatic exact integer carrier profiles](#automatic-exact-integer-carrier-profiles)
- [One spelling protocol for text carriers and keyword call values](#one-spelling-protocol-for-text-carriers-and-keyword-call-values)
- [Owned finite sequence preparation](#owned-finite-sequence-preparation)
- [Fixed product row and finite expansion ownership](#fixed-product-row-and-finite-expansion-ownership)

## Reusable data generation families

Implemented: `generator-integer`, `generator-character`, `generator-byte`,
`generator-list`, `generator-string`, `generator-symbol` and `generator-bytes`
reuse bind, sized, sequence and map. Unicode scalar ranks exclude surrogates;
explicit character endpoints are inclusive. The default covers all Unicode
scalars, unlike Rackcheck's default character domain. Octets cover 0–255.
Sequences have explicit natural minimum/maximum lengths (default 0/128); size
bounds the additional suffix, so fixed widths survive size zero. Structural
length proposals precede coordinate proposals. Domain admission and strict
measure decrease still belong to the existing property runner.

POO String, Symbol, Bytes and BytesN derive from this algebra, retaining source
observation and nested container compilation. `character-shrinks` and
`data-list-shrinks` supply the same value-level policy to typed callers.
No Char Type is invented; custom character Types can use `from-generator`.
Symbols mean interned spellings, including empty/reader-sensitive spellings,
not generated identifiers or gensyms. Mutable data are values within the existing
caller-owned trial protocol; arbitrary property mutation is not made pure.

Portable replay now copies and budgets u8vectors using Gerbil primitives, just
as it already does strings. Codec identity is still checked before decode;
failed encoding/budget admission writes no prefix. Tests cover Unicode endpoints,
fixed/variable widths, shrink-domain preservation, source invalidation, callback
errors, nested Type derivation, seed replay and mixed-data concrete replay.
Lean proves interval membership/descent, scalar validity/order, sequence bounds
and fixed widths. Carrier membership remains conditional on the representation
law; PRNG distribution, symbol interning and Gerbil encoders/readers are outside
the proof. This continues the paper's future-work direction.

References: [Rackcheck](https://docs.racket-lang.org/rackcheck/index.html)
(character families, list structural/coordinate shrinking, string composition)
and [Quickcheck](https://docs.racket-lang.org/quickcheck/index.html)
(character-generator-driven string construction). No separate generation engine
or implicit filter/retry policy is introduced.

## Retained structural collection shrinking

Audit finding: generic Lists shrank a length seed and regenerated the payload;
typed recursive Lists offered empty/tail deletion only. A failure requiring both
endpoints could therefore retain unrelated middle data. This is missing deletion
operation coverage in the finite collection protocol, not a demand for global
minimality, arbitrary Record derivation or unrestricted recursive values.

`sample-sequence` now owns retained structural and coordinate proposals for both
families. It snapshots input list spines, preserves retained node identity and scalar preimages, never redraws
siblings, and retains all observed source leaves even when their values are
removed. A rejected coordinate stays a charged tombstone. Structural deletion is
lazy and uses aligned blocks with halving widths, finishing at every single
position. `list-deletions` supplies that same policy to value callbacks;
`list-deletion-count` allows typed value-only search to refuse oversized candidate
batches before allocation. Structural reservations count as construction work; the completed candidate ceiling retains its distinct refusal tag. Minimum lengths are preserved; fixed arities have no
deletion proposals. Selected Union branches remain fixed.

List/string/byte/symbol roots use the existing draw algebra. Pack/map callbacks
still run to produce each consumed candidate and retain their own costs. All
proposals remain subject to domain admission, strict measure descent, source
checks and the unchanged resource budgets. Duplicate visible values are not
collapsed across different retained source positions. Portable codecs still own
application format/specification/generator revision identity.

Acceptance includes endpoint-preserving middle/tail deletion, minimum/fixed
lengths, retained identities and no extra draws, historical removed-source
refusal in independently retained subtrees and reports, deterministic replay,
typed recursive List value/tree paths, and Record/FUN pipelines with wrapped
Function fields. Independent compilation executes 36 generic cases. Lean proves
block length/descent, subsequence order, map commutation and retention of old
observer identities. These finite laws do not certify arbitrary callbacks or a
runtime-wide cost model.

[Rackcheck's list shrinking](https://docs.racket-lang.org/rackcheck/index.html)
informs the removal-before-coordinate policy. The implementation reuses the
existing modules, iterators, sample records, domain gates and check runner.

## Finite-key HashTable and typed Map generation

The next finite collection capability is a HashTable with an explicit finite key
domain. Racket provides hash generation, while our supported container algebra
previously required applications to hand-build unique entries and reconnect their
shrinks. This unit extends that finite algebra; unrestricted key inference,
recursive hash-key synthesis and arbitrary mutation remain outside it.

`generator-hash keys values` uses standard HashTable equality to reject duplicate
keys once at preparation (`domain-limit:` defaults to 256). The key-list spine is
copied. A nonzero-size root considers every key and keeps at most size selected
keys; zero size draws no keys or values. Only retained values are drawn, using the
existing sequence/sample protocol. `sample-sequence` provides structural deletion
before value coordinates, retaining original samples and all observed sources.
Keys never shrink or normalize. `list->hash-table` materializes a fresh table per
node with an explicit seed; no second hash implementation or collision retry loop
is introduced. Mutable value payloads remain caller-owned. Hash iteration order is
not the generation, shrink or portable-corpus order; declared key order is.

`map-generator descriptor keys value-sampler` in the existing Type module requires
an existing Map descriptor and exactly its declared value sampler descriptor. Key
validators must leave supplied representations unchanged. Their own source boundary
refuses a revision before another key validator runs. Constructor errors (including
duplicate keys and limit/mismatched Types) are not hidden by resampling. The existing
Map validator alone owns recursive value validation and nested Function wrapping.
The measure combines cardinality with child value weights, so both deletion and
strictly smaller value coordinates can advance falsification. Dependencies and the
existing currentness hook capture prepared Map/Key/Value/sampler/application epochs;
stale preparation is never silently refreshed. Derived Record/FUN samplers forward
that child hook through their existing protocol.

Acceptance includes equal-but-distinct duplicate strings, false values versus
absence, detached key spines, size bounds/zero draws, fresh tables, deletion without
redrawing, value coordinates, retained-source refusal and exact callback causes.
Typed tests cover key normalization refusal, descriptor mismatch, collision refusal before key validation and value drawing, source revision during key preparation, raw Function wrapping
and a Record of Maps of linked Records/Functions. That workflow shrinks an aggregate
fault to one key/value, exercises bounded empty-map inspection, both replay forms,
explicit fresh preparation and data-only corpus handoff. Independent generic
compilation executes 45 cases without POO.

Lean's `selectedHashKeys`/`hashEntries` prove subset/order, size/domain bounds,
uniqueness, finite lookup including false-like values, deletion commutation and
value transformation preserving keys. The standard hash protocol's equality/hash
compatibility, stable key payloads, pure stable validators, accurate observers and
terminating value callbacks remain explicit premises. No global uniform sampling,
arbitrary codec law, hash iteration ordering, constant hash lookup cost, host GC
bound or compiler verification is claimed. Accepted preparation traverses the finite domain and performs two hash operations
per key, excluding Type/validator costs. Nonzero roots test all domain keys and
draw at most min(size, domain length) values. Fresh packing inserts one entry per
retained key. Hashing, source checks, seed preparation and validation retain their
own costs; these counts are not constant-time or wall-clock bounds.

[Rackcheck hash generators](https://docs.racket-lang.org/rackcheck/index.html)
provide the comparison point. This implementation intentionally declares unique,
stable key identities rather than silently collapsing generated duplicate keys;
existing value-generation and shrinking protocols remain the only runner algebra.

## Declared finite enumeration simplification

Finite Enum values previously had no shrink candidates and zero measure. A
nested collection could reduce its shape but could not simplify an Enum field.
`generator-elements choices` now maps the existing integer shrink tree through a
captured vector of declared values. It requires a nonempty proper list, draws one
index regardless of size, and never redraws while shrinking. Equal payloads retain
their distinct position preimages. Mutable payloads remain caller-owned; only the
list spine is detached. Existing observer ownership and exact error causes apply.

The POO scalar bridge reuses Enum's existing `.uint<-` and `.<-uint` metadata.
The first equal declaration position is the natural measure. Value-only shrinking
maps smaller indices through the same descriptor; generic tree shrinking retains
its original index preimages. A duplicate proposal with equal canonical rank is
charged and refused by the existing strict-descent gate. Empty Enum remains an
uninhabited leaf and does not invalidate an otherwise inhabited Union. Declaration
order is an explicit simplification policy, not an inferred semantic ordering.

Regression acceptance covers false payloads, equal duplicates, detached spines,
no redraws, stale retained descendants, original callback causes, minimum failing
ranks, concrete/seed replay and a nested List/Tuple/Enum FUN workflow. Changes to
the role descriptor reject old reports. Independent generic acceptance now runs
48 cases. No equality implementation, RNG, shrink runner or namespace is added.

Lean proves selected values belong to the finite domain, out-of-range selection
refuses, first-occurrence rank is no larger than the selected index, and earlier
positions strictly lower canonical rank even with duplicates. Host equality/hash
agreement, stable payloads, truthful observers and terminating callbacks remain
premises. Index generation does not prove PRNG distribution or wall-clock costs.
Preparation copies N positions; each draw selects one index; shrink work and
source checks retain the existing lazy tree and budget costs.

[Rackcheck's finite-choice generator](https://docs.racket-lang.org/rackcheck/index.html)
also supplies shrinking. Its removal-of-previous-choices policy differs from our
explicit declaration-order policy; byte-for-byte tree parity is not claimed.

## Retained independent product shrinking

The concentrated audit reproduced a distinction missing from the composition
implementation: `generator-sequence` used dependent bind for both drawing and
shrinking. Shrinking the first coordinate of `(2 1)` produced `(0 2)` when the
second producer counted its draws. Even with pure callbacks, the suffix was
constructed again, discarding its original sample identity and doing unnecessary
work. This is a defect in independent product retention, not a demand to freeze
arbitrary mutable values or eliminate dependent regeneration.

`sampled-sequence` now captures original nodes through the same bind/map draw
schedule. Public `generator-sequence` hands these nodes to the existing
`sample-sequence` at their fixed width. Lists and finite-key hashes share the
same root capture directly, with their existing structural policies; finite
Function tables inherit fixed-product retention. No second shrink traversal,
cache, iterator, namespace or retry policy is introduced. Explicit `generator-bind`
and named dependent bindings still regenerate selected children when the parent
changes. A collection's structural shrink never becomes product field deletion.

Acceptance checks stateful sibling draw counts, repeated child traversal, the
original split-seed schedule and outer random checkpoint for twelve seeds, empty
products, untouched finite Function rows, original sibling source rejection and
absence of a redraw exception. A downstream Record example composes independent
fields, Function contract wrapping, FUN execution, shrinking, concrete replay and
seed replay: shrinking/concrete replay draw nothing; seed replay draws once per
field again. The ordinary workflow and typed suites now have 34 and 21 cases;
the independent generic-library fixture remains 55 cases.

Eight finite Lean laws establish width, chosen-coordinate replacement, exact
sibling-preimage retention, carrier mapping, commuting distinct updates, unchanged
external draw state, empty products and strict descent of the existing sum measure.
The host correspondence assumes faithful retained sample nodes and the declared
measure; callback purity, termination, mutable payload ownership, PRNG quality,
allocation and GC are not inferred. Root capture still costs linear work in the
product width, and a coordinate proposal still packs a full product. This removes
suffix drawing, not all preparation or source-observer costs.

[Rackcheck's tuple examples](https://docs.racket-lang.org/rackcheck/index.html)
show fixed heterogeneous products shrinking one coordinate while keeping the
others; its bind documentation separately prioritizes dependent parent shrinking.
We preserve that distinction with Gerbil's existing tree algebra and the project's
additional revision protocol. Random bitstreams need not match Racket.

## Shared typed-product observation and directory ownership

The audit reproduced a typed/generic mismatch in the explicit `product-generator`
factory: a first typed field measure
changed a later field's source, yet that later measure still ran before the whole
report finally became stale. The generic product specification already stopped
between field callbacks ([Source-consistent policy and product admission](replay.md#source-consistent-policy-and-product-admission)), but `product-generator` duplicated its measure
with a plain map/sum. Value-only coordinate shrinking similarly could continue
to packing and later child callbacks. A caller could also mutate the supplied
child-list spine after construction, making draw use the old children while
measure/shrink used a different directory.

Typed products now copy the child spine once and reuse the existing generic
product specification for natural field measures and joint source checks.
`specification-weight` is the checked operation on that opaque domain: it shares
the existing natural-measure helper, checks sources, and never exposes raw record
fields or redraws values. It expects a domain-appropriate value; recognition
remains the runner's existing admission stage rather than being repeated by
measurement. `make-product-specification` accepts an explicit `current?:` common
owner, following the existing source-observer convention. It protects empty
products and parent metadata as well as each child domain.

One typed checked-action function brackets unpack, each value-only shrink and
pack, using the same product-domain currentness. `map-in-order` preserves field
and packing order. Ordinary retained-tree drawing/packing uses `generator-map`'s
existing `current?:` boundary. The sampler retains that same `.current?` hook, so
opening another core view cannot refresh an obsolete product. No new namespace,
record hierarchy, value cache, property runner or compatibility path is added.
Children and payloads retain their identities; only the caller-owned directory
spine is captured, not arbitrary mutable heap contents.

Regressions cover parent and child revisions during measures, unchanged charged
attempts and last witness, refusal before packing/later shrink callbacks, explicit
fresh retry, directory mutation across draw/measure/shrink and empty-product
owner refusal. Generic controls cover common-owner and Boolean/natural admission
and exact callback causes. The Record/FUN example retains nested Function wrapping,
refuses the stale run before a later handler measure, prepares fresh ownership,
shrinks a real failure, replays it and rejects later stale replay. Generic and typed
layers share the same implementation rather than separate product cost folds.

Eight laws in `PropertyProducts.lean`, under the existing PropertyTesting namespace,
reuse guardedStages/guardedGeneration: common preflight, early field refusal,
original field/packing causes, empty ownership, packing revision refusal, stable
field order and unchanged natural sum. Faithful captured topology and pack/unpack
representation laws, truthful epochs, sequential callbacks and termination are
premises. Host list copying is tested, not claimed as a universal Lean heap theorem;
GC, alias discovery, concurrent mutation and wall-time bounds are not inferred.

The existing generic product checks all field owners around each callback; its
observer work can be quadratic in product width. The common owner adds one guard
per check and the factory captures field domains/stamps once. This is a coherence
fix, not a constant-time or universal speedup claim. All checks and existing
heap/time/proposal limits remain required.
[Rackcheck's product/tree composition](https://docs.racket-lang.org/rackcheck/index.html)
informs keeping generation algebra separate from domain observation. Common
revision owners and typed sampler evidence are this project's explicit extension.

## Fixed-product source admission before drawing

The next audit reproduced a producer-level gap distinct from [Shared typed-product observation and directory ownership](data-generation.md#shared-typed-product-observation-and-directory-ownership)'s typed domain
measures. `generator-sequence` already knows every fixed field, but the bind/map
implementation exposed none of their source leaves at the product boundary. If a
later field was obsolete before generation, `generator-current?` still returned
true and an earlier field drew once before the eventual stale refusal. An earlier
draw could also revise that later source and still enter its own mapping callback.
Finite Function result products inherited the producer-currentness mismatch.

`sampled-sequence` now assembles the declared fixed-field leaves once with Gerbil's
`append-map` and the existing identity-deduplicating observer boundary. It shares
the existing bind/map run procedure unchanged. `generator-sequence` and finite
Function generation forward those leaves through their existing constructors.
The existing `generate`/`with-sources` boundary therefore rejects before the first
random split or draw, and between field callbacks. There is no new guard closure
tree, source registry, generator representation or special typed execution path.
Retained child ownership, draw order, seed splitting and coordinate shrinking stay
with the same implementation. Typed `from-generator`/Record/FUN observes the
generic admission directly rather than duplicating it.

This rule applies to fields that are statically part of a fixed product. Dynamic
bind selectors, weighted choice, zero-result-row Functions and absent Map keys do
not acquire sources from unselected producers. An explicit function/domain owner
still protects empty domains. Captured lists describe topology; mutable payload
ownership and hidden callback dependencies remain the existing application laws.

Four independent-library cases cover nested stale preflight without randomness or
draws, immediate mapper suppression after revision, exact observer causes/strict
Boolean refusal, shared Function sources, equal-seed replay, empty domains and
zero-weight branch independence. The Record/Function/FUN example rejects a stale
generic field before drawing, explicitly reprepares, retains wrapping through
shrinking and concrete/seed replay, and refuses both old samplers and later stale
reports. The standalone library check now executes all 59 cases without POO.
Product cases live in `examples/property-products.ss` and register with the
existing standard suite; the aggregate kernel stays below 1000 lines. The empty
independent package copies and builds both ordinary modules, with no new namespace
or test runner.

Six additional laws in `PropertyProducts.lean` prove flattened field conjunction,
stale leaf refusal before all draws/packing, nested/shared source equivalence and
empty-result independence. They reuse `guardedProduct` and stable source identity;
Boolean observers, truthful epochs, faithful directories, sequential callbacks and
termination are premises. Runtime observer exceptions are regression-tested, not
represented as pure Boolean functions in the model. PRNG implementation, arbitrary
heap aliases, concurrency and GC remain outside these laws.

Preparation adds a linear pass over the field directory and its declared leaves,
including a copy and an expected-linear identity hash pass over those leaves. Complete known-source checks now occur before and
after field callbacks, including nested products; repeated observation is not
claimed constant-time. No wall-clock speedup is claimed. The full checks, paired
generator/collection workflows and all existing process/resource bounds remain
required. Rackcheck's pinned `gen:bind` composes retained trees and a captured child
random source; we retain that algebra. Epoch-based fixed-product admission is our
explicit extension, not a missing feature attributed to Racket.

## Exact bounded model draw configuration

The generic trace draw accepted non-natural steps and size directly as iterator
bounds. Before repair, steps `-1` and `1/2` each generated a command and invoked
initialization instead of refusing. Gerbil's standard range iterator intentionally
supports reverse and fractional ranges; it cannot supply this protocol's natural
step contract. Infinite bounds could also bypass the promised finite quota. This
is an implementation admission gap, not unrestricted callback termination.

`draw-trace` now uses Gerbil's existing parameter contracts for model identity,
draw/random procedures and exact natural limits. A shared private `trace-limit?`
serves both dimensions. Invalid configuration refuses before model initialization
or command callbacks. The same for/fold owns state and command order, the original
size is passed unchanged, and at most `min(steps,size)` draws may succeed. No
coercion, fallback limit, new framework, namespace, scheduler or PRNG owner is added.
A valid zero cap retains initialization once, including its original exceptions,
then performs no draw; this preserves the existing model initialization semantics.
Explicit stop still omits its unused payload. Disabled/invalid commands and
non-Boolean continuation judgments remain errors, never silently dropped inputs.

Four generic cases cover negative, fractional, inexact, NaN/infinite and malformed
limits in both dimensions; callable/model admission before effects; exact caps,
large natural limits capped by a small size, original callback size/state order,
false command payloads, early stop and exact initializer/draw causes. The independent
standard-library suite now executes 83 cases. A typed Record command with a wrapped
Function exercises state-dependent open/use generation, invalid size-policy refusal
before initialization, zero command cap, FUN differential fixture cleanup,
dependency-preserving minimization and both replay forms. The same action can retry
with a valid configuration; generation and concrete replay keep their distinct costs.

Nine laws in `PropertyTraces.lean` stage validated limits and initialization over
the existing `drawTrace` engine: invalid admission, original initializer cause,
zero steps/size, unchanged-size delegation, explicit stop, disabled command refusal,
valid prefixes bounded by both limits, and exact enabled payload delivery. The
existing remaining-fuel argument remains a finite observation index, allowing
different random choices at an unchanged logical state while size stays fixed. An
absent validated configuration models refusal; accepted limits are Nat values.
Runtime contract fidelity, normalized/faithful choices and callback termination
remain premises. These laws do not prove Gerbil contracts/compiler/iterators,
PRNG quality, arbitrary callback termination, host GC or wall-clock speedups.
The typed steps ceiling and all process, heap and search limits remain unchanged.

Rackcheck's pinned [generator contract](https://github.com/Bogdanp/rackcheck/blob/ffbddb7a9edef6ce1d9e0930adae1bd7033f1db7/rackcheck-lib/gen/core.rkt)
requires an exact nonnegative generation size. We retain that contract discipline
using Gerbil mechanisms; this project's finite model-trace API is an extension,
not a claim that Rackcheck implements the same state-machine protocol.


## Finite sequence preparation without prefix salvage

The audit reproduced two silent truncations. `valid-trace?` rejected a dotted
command spine while `repair-trace` initialized the model and returned its apparent
proper prefix. A parameter shrinker returning `(0 . bad)` likewise contributed a
candidate instead of refusing. A third control revised a declared source in the
first parameter callback: preparation still invoked the second callback before
the enclosing action eventually returned stale. These are observable preparation
defects, not inference of hidden dependencies or arbitrary callback termination.

The existing finite sequence policy now owns one spine boundary. `list-deletions`
uses Gerbil's standard `using`/`list?` contract before length/copy/traversal.
`data-list-shrinks` obtains structural proposals through that boundary once, then
uses the existing `with-sources` around each parameter callback and admits its
returned proper list with `using`. Model shrinking delegates to the same policy;
it adds no second input-spine check. Independent repair validates its own finite
input before folding. Model identity and callback procedure contracts stay with
Gerbil. Valid structural/coordinate ordering and callback invocation counts stay.
No partial candidate batch is delivered when preparation fails; already performed
host effects are not rolled back.

Only finite outer spines are constrained. Invalid trace predicates still return
false, and complete checking refuses before fixture entry. Proper inputs still
retire invalid/disabled commands according to the existing model policy, preserving
false command payloads and dependencies. Cyclic payload graphs are not deep-
traversed by a spine check. General lazy sample shrinkers still accept Iterators,
including infinite neighborhoods consumed under the unchanged proposal budget.
A cyclic cdr chain is malformed list data, not such an Iterator. No global eager
list conversion, compatibility layer, namespace or new shrinking engine is added.

Four generic cases cover improper, cyclic and non-list spines; no initialization
or prefix effects on refusal; malformed callback outputs; exact causes and charges;
source revision before the next coordinate; unchanged finite proposal order; and
bounded lazy Iterator admission. The independent package runs 87 standard cases.
`examples/generated-traces.ss` keeps new typed evidence separate from the large
batch module: Record commands with Function fields reject malformed parameter
batches before candidate repair, retain diagnostic witnesses with zero delivered
attempts, and replay/retry explicitly. A single codec-parametric Record/FUN fixture
covers String/Symbol/Bytes, rejects improper/cyclic outputs, interrupts shared-source
revision before the next parameter, preserves wrapping, and retries/replays valid
shrinking. Typed packing starts only after the complete finite policy returns.

Nine laws in `PropertySequences.lean` reuse the existing source-checked callback,
Except bind and dependency retirement: malformed input refusal, exact proper-input
forwarding, stale preflight, normal revision, original callback cause, malformed
result refusal, ordered proper-result delivery, suppression of later stages, and
valid order-preserving dependency repair. The host shape conversion represents
malformed spines by none; proper empty/false-containing lists remain present data.
Accurate source observers, faithful normalization and terminating callbacks remain
premises. This does not prove Gerbil contracts/list?, arbitrary payload graphs,
callback termination, host GC or wall-clock behavior. All guards and checks stay.
Shape checks add finite spine walks, and each parameter action walks its active
source ledger; no zero-cost or timing improvement is claimed. Existing identity
sharing avoids introducing a separate source wrapper per data carrier.

Rackcheck's pinned [shrink-tree contract](https://github.com/Bogdanp/rackcheck/blob/ffbddb7a9edef6ce1d9e0930adae1bd7033f1db7/rackcheck-lib/gen/shrink-tree.rkt)
requires stream-shaped general shrink results. We preserve that lazy-protocol
separation using Gerbil Iterators while enforcing the narrower proper-list
contract of this project's finite value policy. Revision checks remain our extension.

## Finite fixed-product preparation and retained trees

Two bounded reproductions selected this unit. Passing a cyclic constructor spine
to `generator-sequence` consumed the diagnostic process deadline instead of
refusing configuration. Separately, a typed product's first factory revised a
later known child; that child's factory still ran and the constructor returned a
retired product. These are admission/preparation defects, not unrestricted
recursive-generator or concurrent-snapshot requirements.

The shared private sequence constructor now uses Gerbil's list contract and
checks generator membership before copying its finite topology. Typed products
use ordinary list/procedure contracts before any custom factory and capture all
known child identities before metadata/factory reads. One transient existing
checked-action scope refuses a revision before subsequent preparation. No wrapper
is stored on each resulting field; original callback exceptions remain exact.

The shared sequence constructor retains the established bind/map draw and its
invocation-local checkpoint ownership. It snapshots the admitted topology once;
packing and coordinate shrinking still use `sample-sequence`. Lists, hashes,
finite functions and typed products share the same implementation. Width zero
consumes no random split. No runtime strategy selector or compatibility layer is
introduced.

An iterative retained-root candidate matched values, seeds and replay receipts,
but 64-field paired workflows showed unacceptable GC cost. Removing its extra
checkpoint cache did not establish a reliable improvement either. It is rejected
from production rather than justified by its smaller allocation count. The
remaining benchmark contrasts the checked production constructor with an
independent public retained-tree composition; it is not a historical-binary A/B.

Rackcheck's pinned [gen:tuple](https://github.com/Bogdanp/rackcheck/blob/ffbddb7a9edef6ce1d9e0930adae1bd7033f1db7/rackcheck-lib/gen/base.rkt#L229)
uses a standard loop to retain individual trees, then maps their values;
[shrink-trees](https://github.com/Bogdanp/rackcheck/blob/ffbddb7a9edef6ce1d9e0930adae1bd7033f1db7/rackcheck-lib/gen/shrink-tree.rkt#L82)
retains untouched coordinates. We reuse that separation, while preserving POO's
established split/checkpoint schedule rather than adopting Rackcheck's shared RNG.
There is no new namespace, framework or compatibility path.

Six independent generic controls cover malformed topology, captured spines, exact
seed/root-remainder parity, coordinate shrinking and both replay receipts,
new-branch retirement, and a 512-field product. The isolated stdlib-only package
now requires 115 cases. Typed controls cover invalid representation procedures,
known-child factory retirement, exact causes and scope restoration. A service
Record/Function example composes rejected preparation, old-Reader refusal, fresh
construction, shrinking and both replays through the existing FUN action.

The standard generation paired entry adds prepare/draw/full-workflow comparisons
at widths 16 and 64, natural/post-GC regimes, reversed pairs and A/A controls.
Full workflows include construction and both replay forms; receipt equality is
checked inside the measured action. The public retained-tree algebra is an
explicit immutable-field strategy control, not an exact historical-binary A/B.
The entry reports wall, CPU, GC and allocation; complete data remains outside Git.

Five Lean laws in PropertyProducts specify the existing split schedule and
prove accumulator/reference equivalence, field order/length and exact continuation
seeds. These are equivalent finite specifications, not admission of the
rejected Scheme optimization. Existing guarded-product laws
cover source refusal and skipping later factories. Finite lists, faithful source
observers, serial terminating callbacks and faithful seed
splitting remain premises. No Scheme runtime, PRNG-quality or arbitrary callback
correctness proof is claimed.

## Portable vector copy preparation and shared resource credits

The original [Type Descriptors / I/O Validation discussion](https://github.com/metareflection/poof/blob/9affa8fbbb4f12cbd98cb97f8b8b84474fc39429/poof.scrbl#L1359)
places encoding/decoding and random generation/compression in the descriptor
protocol. This unit strengthens that future-work extension; it does not attribute
our replay format or budget algorithm to the original Racket implementation.

The old bounded copier first converted an entire vector to a list, then visited
children until its node/depth allowance failed. A wide vector therefore allocated
an unbounded-by-that-allowance temporary list before rejection. A constructor
control with a 64-slot vector, eight-node budget and nonportable first element
reported the element error: impossible width was not checked before inspection.
This is a copy-stage admission defect. Reader and application-encoder allocation
were already explicitly outside the copier's guarantee and remain so.

The existing replay module now charges roots, string characters and octets through
one local allowance operation. A vector's width must fit the remaining credits
after charging its root; each child necessarily spends at least one node. A
nonempty vector also requires positive child depth. These necessary checks precede
destination allocation and child access. Empty vectors remain valid at depth zero.
No child or container resets the shared allowance. Oversized shape now takes
resource-refusal priority over contents which cannot possibly be admitted.

The admitted copy uses the official `:std/vector/vector` forward
`vector-fold/index`, writing directly into one destination vector. No complete
source list or mapped result list is materialized. Its documented ascending fold
keeps shared-budget traversal and first-error order explicit; `vector-map/index`
has unspecified application order and currently traverses backward, so it is not
used for this stateful budget. Ordinary node/depth failures retain the established
error category/message; feasible child errors and source/codec exception identity
remain intact. Encoding and complete envelope admission still precede port writes;
no I/O rollback is claimed.

The pinned [Rackcheck vector/byte generators](https://github.com/Bogdanp/rackcheck/blob/ffbddb7a9edef6ce1d9e0930adae1bd7033f1db7/rackcheck-lib/gen/base.rkt#L304)
map the existing finite list generator into standard carriers. We retain that
generator algebra. Copying externally supplied replay data has a different
admission responsibility: its shape must fit before a carrier-sized allocation.
This does not add a parser, resource framework, namespace or POO dependency to the
generic replay library.

Five generic cases cover width checks using remaining rather than original fuel,
exact node/depth boundaries, empty/cyclic vectors, forward error precedence,
whole-envelope accounting, detached mutable payloads, and skipped decoding/property
effects followed by retry under unchanged limits. Independent acceptance requires
132 cases. A contracted Record/List/Tuple/Function service shrinks through FUN,
rejects a fault-injected oversized corpus before output, rejects its retired codec,
then prepares a fresh codec at the same 16-node cap and replays without new draws.

PropertyReplay reuses the existing property namespace and finite sequence model.
Its eight laws prove exact shared cost accounting, minimum child cost, necessity
of width preflight, wide/depth refusal before allocation, empty admission,
preservation of the admitted action/error and the destination-width bound.
Top-level controls cover exact-fit/one-short profiles and preserved first errors.
Costs are logical root/character/octet units; profiles must faithfully describe
finite copies. This proves neither host allocation bytes nor reader/encoder
behavior, GC latency, wall-clock speedup or arbitrary I/O correctness. Existing
heap/time/source/check limits and the unchanged complete paired entry remain.

## Automatic exact integer carrier profiles

The concentrated audit reproduced a missing derivation path for existing
`IntegerRange`, `UIntN`, `IntN` and `Z/` descriptors. They required handwritten
`.generator` fields despite exposing exact interval metadata. They now share one
POO-free `generator-integer-range` combinator and one typed preparation path;
custom overrides and Exactly/Enum retain precedence. No additional framework,
namespace, validator chain or upstream change is involved.

The nearest-to-zero admitted integer is the anchor. Size bounds the draw's
distance from that anchor; finite endpoints clip the inclusive window. A primitive
draw has at most `2*size+1` choices, even for a 256-bit carrier. Size zero produces
the anchor, including positive-only and negative-only intervals. Shrinking maps
existing natural-distance candidates back along the original closed segment;
every candidate remains admitted and strictly decreases distance. No rejection
sampling, modulo coercion or Any fallback is used. This follows the compositional
integer/shrink-tree approach of [Rackcheck](https://docs.racket-lang.org/rackcheck/index.html),
while retaining this project's explicit size and source-ownership protocols.

IntegerRange admits omitted endpoints; fixed-width/modular descriptors require
exact finite endpoints. Malformed metadata is a preparation error. Empty finite
intervals, including `Z/ 0`, reuse Enum's uninhabited-leaf exhaustion protocol.
The recursive graph's original source scope checks each bound getter before the
next one; retained samples, diagnostics and reports reject retired ownership.
Only fresh preparation sees changed endpoints. Custom predicates must faithfully
admit their interval or supply an explicit generator. Float/Real/Number remain
outside this exact profile; their absence is not silently repaired.

`examples/property-numbers.ss` exercises the generic combinator, bounded windows,
strict shrinking, seed/concrete/corpus replay and stale ownership. The independent
POO-free package now requires 145 cases. `examples/generated-products.ss` combines
a five-bit balance, signed delta, modular mode and revised port range in a Record
with a wrapped Function and FUN action. It detects wrapping arithmetic versus a
saturating reference, replays the failure through a data-only codec, refuses a
retired port descriptor, and accepts a freshly prepared corrected service.
Regressions cover unbounded/one-sided intervals, large bit widths, empty domains,
malformed endpoints, override precedence and getter ordering after invalidation.

`PropertyNumbers.lean` proves anchor admission, window admission/nonemptiness,
size-zero uniqueness, width bounds, sign/distance reconstruction, strict candidate
descent, interval preservation and terminal anchors. Top-level examples fix both
positive and negative boundaries. The interpretation requires exact arithmetic,
faithful interval metadata, truthful revision clocks, terminating callbacks and
the existing random-source contract. These are finite source/model laws advancing
the paper's future work, not proofs of Scheme execution, PRNG distribution or
wall-clock performance. The width bound is not a constant-time bignum arithmetic
claim. All existing checks and resource limits remain unchanged.

## One spelling protocol for text carriers and keyword call values

The concentrated audit found that the existing Keyword Type had validation and
standard string conversion but no automatic PBT derivation. FunctionArguments
therefore could not derive ordinary Keyword arguments or Keyword-valued declared
parameters. This closes an existing finite data path; it does not infer arbitrary
predicates or synthesize unrestricted callbacks.

The generic module adds `generator-keyword` by mapping the existing string tree
through Gerbil's `string->keyword`. It shares size, alphabet/length bounds, seed
splits, lazy children and source ownership with String/Symbol generation. The
POO data profile selects one representation pair using standard `defvalues` and
`compose`, then uses one character/byte-list generator and shrink policy for
String, Symbol, Keyword, Bytes and fixed BytesN. It allocates no conversion lookup
table and installs no extra validation chain. Representation conversion occurs
once per materialized node; the original list tree retains child provenance.

Empty spellings, whitespace, colons, NUL and Unicode scalars remain data. A Keyword
value does not become an omitted argument or a keyword declaration. Existing
FunctionArguments owns escaping and optional/keyword/rest interpretation; this
unit supplies the missing value generator instead of duplicating its parser.
Shrinking retains the carrier and the existing content rank; equal-length character
shrinks can decrease content, while empty spellings are terminal. Wrong carriers
fail the existing Type/Function boundary. Source checks, callback errors and
stale report refusal retain their existing semantics. Fresh preparation after
revision is explicit. Opaque/refined Types still require explicit generators;
this does not add JSON inference, arbitrary interning policy or an eval mechanism.

Generic controls compare seeded string/keyword spellings, test constrained
alphabets and lengths, sensitive Unicode and empty data, and replay an empty
minimal failure. Independent admission now requires 148 cases. Typed regressions
exercise strict spelling shrink rank and shared Keyword leaves in Tuple/List/Pair/
OrFalse/Sum. `examples/generated-products.ss` exports `keyword-routing-action`:
a Record with Keyword fields and wrapped Function flows through a declared
keyword parameter and FUN. The fault confuses an empty spelling with omission;
the test detects it, preserves wrappers, replays seed/concrete/corpus witnesses,
rejects a retired descriptor and admits a fresh corrected action. A separate
FunctionArguments control composes ordinary/optional/keyword/rest Keyword values.

`PropertySequences.lean` proves six representation laws: spelling recovery in
order, neighborhood cardinality, proposal origin, strict rank descent, declared
domain preservation and terminal neighborhoods. Top-level examples use a distinct
carrier with empty and reader-sensitive spellings. Faithful standard conversion,
terminating callbacks, accurate source clocks and the existing character/list
neighborhood laws remain interpretation premises. These finite model laws do not
prove Gerbil intern tables, the compiler, PRNG distribution or physical memory and
latency. This advances the paper's future-work direction. No upstream code,
module framework, namespace, runner, resource limit or acceptance check changes.

## Owned finite sequence preparation

The audit reproduced a split preparation boundary in the existing finite value
policy. With input (4 6), a first parameter callback changing the caller's second
pair caused the next callback to receive 99 and emitted (0 99), although the
structural phase had already captured (4 6). A model initializer could likewise
change the commands that repair/preflight subsequently processed. Truncating or
cycling the caller's spine could make a previously admitted finite input cease
to be the input actually traversed. This is framework-owned spine preparation,
not automatic discovery of mutable payload dependencies or arbitrary termination.

Both finite value policies now use one private deletion algorithm over an owned
spine. list-deletions and data-list-shrinks each admit and copy their input once
with Gerbil using/list? and list-copy. The latter's structural and parameter phases
read that same copy; no additional candidate validation wrappers or strategy
selector is introduced. The common model fold similarly copies before initial,
accept, normalize, enabled or advance callbacks. repair-trace, valid-trace? and
check-trace share that fold, so the actual fixture sees the preflighted commands.
Malformed initial spines still refuse before effects, and malformed parameter
spines still refuse the entire finite neighborhood without salvaging prefixes.

Rackcheck's pinned make-shrink-tree / gen:with-shrink composition retains the
value whose neighborhood is being described; its ordinary immutable Racket list
spines do not have Scheme's pair-edit window. Our existing mutable Scheme input
boundary therefore owns its spine explicitly, while keeping the same generator,
source checks and runner. This follows the project's FUN/IO separation: preparation
owns finite data and composition; the actual fixture owns effectful cleanup.
No new framework, namespace, upstream compiler change or deep-copy mechanism is
needed. Returned candidates may share private snapshot tails, as before; neither
exclusive ownership between candidates nor arbitrary host-heap immutability is
claimed. Command payload identities and declared source obligations are unchanged.

Six independent cases cover value edits, truncation, improper/cyclic caller tails,
paused deletion iterators, all five model preparation hooks, differential checking,
shallow payload identity and source/exception precedence. All 168 earlier generic
cases remain, raising the independently compiled library to 174. A complex typed
example combines Record commands containing checked Function fields, preparation,
finite shrinking, scoped differential fixtures and the existing FUN debug action.
It shrinks to the faulty command, retains Function wrappers, replays seeded and
concrete witnesses, refuses old evidence after owner revision and explicitly
prepares a corrected passing run with balanced cleanup.

PropertySequences.lean adds finiteSequenceParameters using the existing guarded
finiteShrinkStage. Eight laws prove empty behavior, head/tail refusal without
partial publication, exact causes, retirement precedence, malformed refusal,
one batch per captured coordinate and fixed coordinate order despite state
replacement. Top-level examples include ambient list replacement, malformed later
batches, false values/causes and retirement. Accurate standard spine copying,
sequential terminating callbacks, faithful source observers and immutable/shared
payload discipline remain premises. This advances the paper's future work, not
host allocation, concurrent mutation or compiler/runtime verification. The added
model snapshot costs a linear shallow copy per preparation; no wall-time or
allocation improvement is inferred from these correctness controls. Existing
complete checks, watchdogs and heap limits remain unchanged.

## Fixed product row and finite expansion ownership

The audit reproduced three defects in the value-level product path. An improper
child neighborhood invoked the packer once before refusing its tail. A two-field
product whose unpacker returned one value measured only that prefix, invoking
one child and returning four instead of refusing the decomposition. A packer
editing its temporary row changed a subsequent child argument from six to 99.
The retained product tree already owned its rows; the finite view did not share
that preparation discipline. These are concrete protocol gaps, not inference of
arbitrary representation inverses or automatic proofs of user callbacks.

The generic product specification now captures one proper row of exactly its
fixed width before admission or measurement callbacks. Gerbil list? establishes
properness before std/list/list's length=n? checks width; that standard helper
alone also treats an improper terminal atom as an end, so it is not a replacement
for list?. Invalid membership remains false, and invalid explicit measurement is
an error before field effects. Empty rows remain valid data at width zero; a
false row is invalid, while a row containing a permitted false payload is valid.

Typed product measurement delegates to that same generic owner. Finite shrinking
admits and copies its unpacked row before child or packer calls. A single private
finite-shrink-children boundary validates/copies every finite POO child spine;
products invoke it after their existing checked child action, and ordinary raw
sampler lifting uses it after the inherited source action. Source refusal and
original causes therefore retain their existing priority. Generic user shrinkers
still accept Iterators; their explicitly budgeted infinite neighborhoods remain
supported. No generic iterator is eagerly converted into a finite list.

Every product packer receives a private complete outer row. The existing reversed
prefix is reconstructed with standard foldl/cons and a copied suffix, avoiding
another reversed-prefix list. Thus consuming a pack argument cannot change the
remaining coordinates. Constructor identity, field order, per-coordinate callback
order, interleaved packing and source gates stay with their original owners.
Malformed child lists cannot publish prefixes; a later error still discards the
returned batch, without rolling back already performed callback effects. A producer
retaining an alias to its returned candidate spine cannot change an already
prepared typed iterator's next candidate. Payloads themselves are not deep-copied;
mutable semantic data and callback dependencies retain their source obligations.

This follows the pinned Rackcheck retained-product/shrink-tree direction and the
author's compositional representation discipline. It reuses the project product,
Type, Record and FUN protocols plus standard Gerbil list operations. No second
product engine, public adapter, runner, namespace or upstream change is introduced.
The pure fixed-width checks occur once at the operation's owning boundary rather
than validating every packed field through another wrapper. Snapshot copying has
linear spine cost; these correctness controls make no wall-time speedup claim.

Four generic cases cover malformed/short/long rows, zero fields, false payloads,
measurement snapshots and exact source/cause refusal. All earlier 181 cases remain,
raising the independent stdlib-only compiled acceptance to 185. Eight typed cases
cover invalid finite child batches before packing, decomposition failure before
any field work, staging-cache and consuming-packer edits, paused producer aliases,
exact causes and source retirement. The complex consuming-product-sampler example
composes UInt, Integer and Bool fields with a Record/Function carrier. Its standard
reverse! packer is valid on private rows. The ordinary finite and retained views
agree on the minimal witness, attempt count and shrink steps through FUN/corpus
export, seeded/concrete/portable replay, old-source refusal and fresh corrected
preparation. Function argument contracts remain checked on each witness.

PropertyProducts.lean reuses PropertySequences.finiteShrinkStage and the existing
guardedStages. Eleven laws establish exact-width row capture, empty/invalid
separation, refusal before consumers, original-row forwarding, coordinate width,
prefix/suffix order and no finite batch after child or packing refusal. Examples
cover unequal widths, false payloads, malformed children and source retirement.
Faithful standard shallow copying, sequential source binding, terminating callbacks
and the application's Type/pack/unpack laws remain premises. These are not host
heap alias proofs, automatic isomorphism discovery, concurrency verification or
compiler/runtime validation. Existing complete checks and resource limits remain.


