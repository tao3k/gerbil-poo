# Ordered table revision batches

`methods.table` now exposes `.compose-deltas`, taking a finite proper list of
existing deltas. It returns one ordinary opaque delta for `.apply-delta`,
`invert-table-delta`, `table-isomorphism`'s `Delta`, `table-fold`, and derived fold
transports. No parallel collection hierarchy or new carrier is introduced.

```scheme
(def batch (.call table .compose-deltas (list first second third)))
(def next (.call table .apply-delta admitted-base batch))
(def restored (.call table .apply-delta next (invert-table-delta batch)))
```

## Admission and failure semantics

Composition checks the receiver's current Key/Value descriptor identities and
**every** input's captured origin revisions. Empty deltas retain their origins.
The output retains the receiver and the union of those origins under the existing
supported-mutation protection. A stale or incompatible input refuses before an
output is returned; arbitrary callback errors retain their original cause.

Composition does not need a base snapshot and does not scan or validate one. It
therefore cannot promise that independently constructed requests are sequentially
compatible. Installation checks every expected old value in input order, using the
existing persistent private staging. The first conflict raises `table-conflict`
with its key and exposes no partially installed table. Unrelated bindings can be
rebased as before. This is changed-binding conflict checking, not a global revision
or ABA fence, and does not synchronize effects performed by arbitrary callbacks.

Repeated keys, deletion followed by reinsertion, and temporary keys are retained.
In particular, a write followed by its inverse is not an empty revision: both
old-value checks remain observable. Grouping batches is associative in edit order;
undo reverses batch order and each batch's internal order. The zero-input batch
has zero edits but still captures receiver metadata.

## Conversion, aggregation and FUN

The existing typed key/value Wrapper isomorphism translates each intermediate
optional payload, preserving missing versus stored false and admitted Function
leaves. Endpoint-only lookup would incorrectly turn both edits of `10 → 20 → 30`
into `10 → 30`; it is no longer used. The same target-backend collision registry
covers both endpoints and temporary keys. Universal inverse laws, stable callbacks
and supported carrier laws remain explicit premises; encountered counterexamples
are rejected rather than inferred away.

Fold updates finish all conflict checks before any contribution projection. A
failed late batch therefore invokes neither projections nor the FUN consumer.
`examples/service-collection.ss` exports `batch-ledger-action`, composing batch
admission with the existing fold/FUN continuation. Retain the old state, rediscover
against the winning state after failure, and submit the complete new batch.
Paired fold transport also retains live ownership for keys deleted and reinserted
inside one batch; failed conversion preserves the previously accepted pair.

## Laws, costs and acceptance

`LeanPoo/Functional/TableBatch.lean` proves sequential/flattened equivalence
including first errors, grouping, reverse-order undo, isomorphic composition,
ordered fold composition, failure suppression, complete origin guards, exact edit
count and the existing two-contributions-per-edit work bound. Root
`Examples/TableRevision.lean` combines temporary services, shared opaque callback
handles, late conflicts, retry, aggregation, migration and stale origins.

Scheme regressions use both RationalDict and Trie, repeated/cancelling edits,
empty stale origins, a backend that refuses snapshot scanning, nested Function
identity, full transport/undo, late conflict without projections or consumer IO,
and retained collision ownership with retry.

Composition visits input origins and edit spines, never snapshot bindings. It
copies the edit spine without revalidating or rewrapping admitted payloads.
Installation still performs each backend lookup/write; this API deliberately does
not coalesce edits or claim a universal time/GC speedup. The proofs concern finite
observations and explicit algebra/representation laws, not Gerbil compiler or
runtime correctness. The broader general collection library remains open.

`pruneDeletedOwners_live` proves that a live final key keeps its collision owner,
regardless of earlier deletions. The ordered grouping regression also guards the
standard concatenation boundary: use order-preserving `map` and `append`.

Local complete acceptance ran all 124 modules / 1,194 cases in the existing
single-process harness, with normal exit 0 and the unchanged 1 GiB / 300 s bounds.
An earlier complete run caught the nested-grouping ordering defect; the corrected
standard `map` / `append` implementation passed the full rerun. Both runs remain
local diagnostics, rather than compressed or versioned benchmark artifacts.

## Finite Iterable import

`(.call table .<-iter input)` constructs a complete root from a finite Gerbil
Iterable; `(.call table .<-iter input seed)` imports into an admitted seed.
Both forms use the existing explicit `.key-table` capability. Unsupported or
incompatible key registries refuse instead of guessing equality or constructor
polymorphism. Keys and values must already be admitted; raw normalization remains
separate. Every yielded Pair shell is captured before child recognition, including
entries later overwritten. Invalid rows therefore cannot be hidden by duplicates.
Repeated logical keys retain the **last** yielded value. This does not change the
backend's independent `.<-list` duplicate convention.

One private backend-owned registry coalesces entries using the declared key
semantics. Seedless import delegates unique final bindings to the existing bulk
constructor, without fabricating a business-valid empty seed. Seeded import reads
old values only for the distinct touched keys and builds one ordinary delta;
`.apply-delta` stages correlated indexes and admits the complete final root. Unique
value swaps can succeed even if point-by-point intermediate roots would fail.
No seed `.list<-`, snapshot `.diff`, repeated owner installation or new index engine
is used. Full source/result recognition may still traverse the seed and is charged.

Set import maps elements to Unit entries through the existing iterator mapper,
retains complete Set refinements and delegates to the same table kernel. All five
styles expose seedless construction and seeded import; receiver `owner.<-iter`
uses the same captured-generation step. Mutable/Classy retain identity; Linear
consumes only on successful publication. Empty/no-op seeded imports are normal
successful steps, not hidden read operations. A reentrant successful publication
wins and the losing attempt exposes no successor.

Seed admission precedes every input pull. Descriptor/registry origins stay
protected across iteration, including EOF. Iterator, child, backend and final
refinement failures expose no partial business root and preserve the original
owner. Original unexpected exceptions retain their cause. Iterator progress and
external callback effects are **not rolled back**; retry requires a fresh stream
(or another iteration of a repeatable input). Infinite input termination is not
claimed. `import-ledger-action` stages a linear service import through Reader/FUN
before IO; failure suppresses the consumer and admitted Functions keep identity.

The finite Lean `TableBatch` model proves ordered last-write semantics, untouched
keys, one-delta reconstruction and inverse recovery through the existing installer,
per-entry refusal and cardinality, admission precedence and style failure retention.
Each event stands for host pull/capture/child admission; actual Iterator scheduling,
EOF and persistence laws remain premises. Registry writes cost one per yielded row;
seeded old-value reads and delta entries are bounded by distinct touched keys.
Registry construction/validation, complete admission, backend/index preparation,
allocation and GC remain costs. No constant-space, logarithmic total-time, physical
ownership or compiler/GC proof is asserted. This advances the proposed collection
library's finite future-work protocol.

Design reflection: replace incremental business-root construction and Set seed
rescanning with one declared key registry and the existing final installer. Use
standard Iterable/FUN/IO and the shared ownership step; do not duplicate caching,
index algorithms or public validation wrappers, and introduce no namespace.

## Owned change capture from borrowed Option providers

A provider may reuse an Option shell after a synchronous lookup/emission has been
consumed. `.diff` now snapshots both old/new shells before key or value recognition,
then checks the key and both Option payloads before retaining a private change.
Malformed tails return the original refusal rather than a partially built delta.
A present false remains distinct from absence. Producer exceptions still escape;
external provider or recognizer effects are not rolled back.

Point capture snapshots its lookup result before invoking the transform and its
response before invoking child recognition. Reading another key inside a transform,
or mutating the returned provider shell during recognition, therefore cannot
rewrite the old expectation or replacement. The callback argument is a separate
shell. Function handles and other admitted leaves keep their identity; mutable
leaves/keys must remain stable. This is shell ownership, not recursive cloning or
an atomic snapshot of unsynchronized concurrent provider writes.

The same borrowed-result audit covers seeded Iterable old values, binary merge
arguments before recognizers and retained Set-image target deltas. Each producer
captures at its first borrowing boundary with the existing `map/option identity`.
Internal change construction, composition, inverse and transport continue to reuse
the already private payloads; no global memo, constructor-wide copying hook or
public method wrapper layer is added.

`table-capture-test.ss` combines reusable lookup/event shells, stored false,
recognizer interference, malformed late events, retry, indexed Boolean swaps,
Tuple/Pair Function rows, aggregate updates, seeded imports, Set-image inversion
and five-style FUN/IO publication. It reuses the existing service workflows and
standard backends. The `collection-deltas` test group keeps capture/batch/transport
compiler responsibilities bounded; no check, heap limit or deadline is removed.

`TableCapture.lean` models typed borrowed cells and emission-time snapshots in the
existing ordered dictionary namespace. Laws preserve key order, event count,
composition, exact observed leaves, replay and inverse after shell writes, and
pre-recognition values with exact admission refusal. Recognizer heap effects are
retained separately from the returned event. Physical heap primitives, deep leaf
stability and provider synchronization remain premises; this is not a runtime
memory proof. Copies and key/value predicate costs remain charged per event, and
complete source admission still has its original costs. No latency claim follows.

Design reflection: ownership is established once where a provider/callback hands
over a borrowed shell. Copying at every internal change constructor would add
redundant allocations and still be too late for callbacks that reuse a lookup.
The existing Option function and private change records provide the needed layer.
