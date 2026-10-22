# Deriving table operations through explicit isomorphisms

The TODO's general collection proposal includes sharing **algorithms**, not only
converting existing snapshots. `table-wrapper` now derives a complete persistent
table descriptor from one existing backend and explicit typed carrier, key and
value Wrappers. No target lookup, insertion, balancing or traversal implementation
is required. This closes the explicit representation-derivation unit, not automatic
isomorphism discovery or the whole proposed general library.

## Construction and laws

```scheme
(def derived (table-wrapper source carrier keys values))
```

`carrier.Domain` is exactly `source`. Its Codomain is a shape descriptor with Key,
Value and a carrier recognizer, with no table methods required. `keys` and `values`
connect the corresponding child descriptors in both directions. The factory checks
these identities and captures all participating POO descriptors and revisions.

The target recognizer establishes **carrier shape only**; the returned table's
standard recursive recognition/validation checks its children. The original
backend must preserve persistent table laws. Converters must map admitted values,
be stable, respect `equal?`, and satisfy both inverse laws. Actual encountered
inverse counterexamples raise the existing `table-isomorphism-failure`. A direct
converted-output type refusal is TypeError; an invalid reconstructed inverse keeps
the inverse-failure classification. User/backend exceptions retain their cause.

Carrier roundtrips use `equal?`. Transparent Gerbil records over an unchanged
persistent root work directly; equality of freshly allocated opaque records is not
silently inferred. Hidden mutable callback state is not a certified dependency.

## One protocol, whole workflows

The existing `methods.table` and FUN `Wrap` supply recursive normalization,
optional lenses, collection algorithms, IO and wrap/bind/map. Generated backend
primitives delegate read/write/remove/emptiness and both fold orders to the source,
converting only keys, values and raw carrier boundaries. Empty recognition uses
the source's operation: allocating a fresh wrapper around an empty root must not
turn an empty collection into a nonempty one.

Traversals preserve the backend's order. Key negation alone does not sort the
result: an ascending source enumeration becomes descending numerical target keys.
First/minimum and last/maximum observations follow this **transported backend
order**, not a newly claimed numerical comparator. No automatic comparator
certification or rebalancing strategy is introduced.

Supported metadata mutation during generated operations and their fold/FUN
callbacks is refused. Later captured descriptor revisions invalidate old derived
operations, states and deltas; construct a fresh descriptor to retry. Already
returned immutable data is not revoked. Existing serialization/iteration semantics
remain those of the public table protocol; arbitrary external IO is not rolled back.

`examples/service-collection.ss` supplies `make-mirrored-ledger`: a transparent
Gerbil record reuses RationalDict, negates keys and swaps a Tuple's checked Function
and capacity into Pair fields. The resulting descriptor directly supports ordered
revision batches, inverse, `table-isomorphism` data/delta transport, incremental
fold state and the existing FUN consumer. No new namespace, tree or checkout
integration is required.

## Proofs and costs

`LeanPoo/Functional/TableRepresentation.lean` constructs `TableCarrier.conjugate`
from an existing lawful backend and three `DictionaryBridge` isomorphisms. It proves
lookup and persistent write correspondence, whole delta/batch installation including
the first mapped conflict key, inverse recovery, inverse derivation, composition of
multiple derivations, both fold orders, exact enumeration size and complete source
metadata admission. `Examples/TableRevision.lean` retains shared opaque callback
handles, host metadata, temporary keys, repeated edits, late conflict and reverse
representation.

A point operation delegates to one original point operation and a bounded number
of explicit conversions/inverse checks. It does not enumerate or rebuild the
snapshot. Conversion, recognition and structural equality have their own costs;
no unconditional O(1), backend complexity, GC or wall-time improvement is claimed.
Traversals map every visited binding once in the original order. The finite laws
are not proofs of the Gerbil compiler, host runtime or arbitrary user callbacks.

Nested generated protocols publish complete `.sources` metadata. Existing delta,
fold and isomorphism construction closes over those origins, so changing an inner
converter invalidates outer aggregate reads and even empty deltas. The nested
source-guard law includes every origin. The Rational Pair decoder now accepts one
Pair, matching ordinary `compose`, and JSON encoding first converts the Rational
to its Pair. Regression controls cover signed exact fractional byte/JSON roundtrips;
the generic codec theorem assumes the underlying codec law and does not prove a
JSON parser or arbitrary numeric normalization.

## Remaining collection-library acceptance

| Unit | Current boundary / next concrete acceptance |
| --- | --- |
| Explicit representation derivation | Closed for the shared persistent `methods.table` protocol; source-specific seek/range extensions are not inferred. |
| Pure/mutable/linear style generation | Closed for an admitted persistent table: full transfer matrix, atomic delta/batch installation, observation and explicit retry; see [table-styles.md](table-styles.md). Destructive backend reuse remains separate. |
| Declarative correlated indexes | Closed for stable single-key declarations over persistent backends: synchronized unique/grouped caches, atomic delta/batch installation, inverse observations and styles; see [table-indexes.md](table-indexes.md). |
| Order-aware extension | Closed for explicit lawful comparator transport, ordered finite folds and range queries via `table-order`; see [table-order.md](table-order.md). Source-specific seek is not inferred. |
| Backend cost qualification | Open: measure the generated complete workflow against the source under matched controls and retain conversion/equality costs. |
| Arbitrary symmetry / optimization discovery | Research boundary; not treated as a defect in the explicit constructor. |

Local full acceptance ran all 125 modules / 1,204 cases in one process and exited
normally with status 0, retaining the existing 1 GiB / 300 s limits. No checks were
removed. Targeted failures found during development (codec arity and classification
of stale delta/inverse failures) remain local diagnostic logs, not Git artifacts.

Pair JSON decoding delegates to both child descriptors, including the existing
integer-string and nested-container codecs. Exact rationals with 80/100-bit
components and nested Pair/List controls cover that boundary; `pair_codec_roundtrip`
retains the separate child-codec premises. Raw JSON children are not returned as
though they were already decoded values.

Pair child decoders run explicitly left to right; a left failure preserves its
original cause and suppresses the right decoder, as checked by an effect trace
and the corresponding ordered Except example.

Serialization requires existing child codecs. Opaque Function closures remain
unsupported on the wire; no closure serialization is inferred from membership.

Final integrated acceptance, including child-codec regressions and the current
object-read changes, passed all 125 modules / 1,209 cases in the standard linked
single-process test program: status 0, wall 148.244 s, CPU 20.318 s and GC CPU
3.675 s, under the unchanged 1 GiB / 300 s limits. This is an acceptance receipt,
not a paired performance claim.
