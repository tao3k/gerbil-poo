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
