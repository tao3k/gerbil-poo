# Persistent table revisions

This is a concrete part of the proposed collection library in TODO.md, advancing
future work. It reuses `methods.table`, RationalDict's Gerbil `std/struct/rbtree`
backend, the existing Patricia trie, optional bindings and the ordinary Lens and
Reader/FUN protocols. It introduces no collection implementation or execution
engine. The original Racket construction's dictionary interfaces and Appendix B
getter/setter composition motivate the protocol; the delta API is an extension,
not a claim that the paper specifies this algorithm. The
[original proposal](https://github.com/fare/projects/issues/10) uses incremental
primarily for layered definitions of typeclasses/data structures and calls for
further automatic translations and symmetry-derived algorithms. This unit adds
one shared algorithm layer to existing table methods; finite data revisions do
not replace that broader goal.

## Complete supported unit

For finite, persistent tables with the **same Key and Value descriptors**:

* `.diff before after` produces an opaque finite delta. Updates and removals
  follow source traversal order, followed by target-only insertions in target
  order. No sorting or branch reordering is introduced.
* `.apply-delta current delta` compares each expected optional old value using
  the existing `.update/opt` structural `equal?` rule, then uses the backend's existing `.acons` or `.remove`. The first
  conflict raises `table-conflict`, whose key is available through
  `table-conflict-key`. No intermediate table is returned.
* `invert-table-delta` reverses edit order and swaps old/new bindings. With stable
  persistent values, applying it after success restores the old
  observations. Empty deltas return the original carrier by identity.
* Deltas move between RationalDict and SimpleTrie without converting their
  internal representation or enumerating bindings through `.for-each`. Matching logical key/value
  types and backend lookup/write laws are required. Physical shapes need not be
  isomorphic: preservation is stated in terms of every key's lookup result.
* `.lens/opt key` implements the existing Lens `.get`/`.set` convention. `#f`
  means missing, while `(some #f)` stores false. Compose it with `.lens ledger`
  using `Lens.compose` to update a ledger inside a service.

Snapshots passed to discovery and installation must already be admitted through
`validate` or `checked-action`. Discovery recognizes both tables without wrapping
again; application only admits the carrier shape and accesses changed bindings.
Deltas retain exact admitted values, including nested Function wrappers. Creating
one from raw, unwrapped procedures is not a substitute for recursive admission.
Children and callback state must remain stable while snapshots are retained.

`prepare-ledger-revision` in `examples/service-collection.ss` admits a new proposal
with `checked-action` before discovering changes. Full admission may create new
Function identities even in previously present entries. For identity-preserving
incremental use, validate new payloads individually, build the persistent proposal
from the admitted source, and call `.diff` directly. `apply-ledger-revision`
composes installation with an IO consumer through the existing Observation FUN
map; a conflict suppresses that consumer, and rediscovery permits retry.

## Failure and invalidation

A delta captures its original table descriptor, Key and Value revisions. Supported
writes to these descriptors invalidate it; applying to another carrier also
requires identical Key/Value descriptor identities. These descriptors and the
current carrier descriptor are protected by the existing construction guard during
recognition and installation. Callback exceptions preserve their original identity;
external side effects are not rolled back.

This is optimistic conflict detection at **changed keys**, not a global snapshot
or ABA fence. Unrelated concurrent edits can be rebased. A changed old binding
refuses; a binding changed away and back compares equal. Cross-thread atomic
publication remains the responsibility of the existing publication protocols.
The protocol neither caches approval nor grants authority to a retained delta.

## Cost and verification

Discovery scans both finite snapshots and retains only differing bindings.
Temporary Option wrappers and traversal objects still allocate.
It performs source lookups in target and target lookups in source. Application
performs one old-value lookup and one persistent write per accepted edit; the
empty case returns its source. Trie shape admission still recursively visits its
structure, whereas RationalDict carrier recognition is a record check. Thus total
installation is not claimed to be sublinear for every carrier. Carrier shape admission, descriptor preparation, metadata observation and
structural equality retain their own costs. No wall-clock or allocation improvement is
claimed. The regression backend that refuses enumeration/normalization during
application checks this sparse operational boundary.

`table-validation-test.ss` covers false versus missing, ordered insert/update/
delete, inverse installation, original persistence, different carriers, 48 rounds
against an independent alist oracle, late conflict, unrelated rebase, retry, nested
List/Tuple/Function wrappers, descriptor changes and composed service lenses.

The companion Lean `Functional/TableRevision.lean` proves finite discovery
completeness, sequence composition, first conflict refusal, inverse restoration,
frame preservation, all three optional lens laws and carrier transport preserving
both observations and error keys. Its `TableCarrier.read_write` premise exposes
the backend boundary. Equality is mathematical decidable equality, requiring the supplied
Scheme structural values to refine that observation model; Scheme
procedure identity can be represented by opaque handles, not extensional function
equality. The model does not prove Scheme structural equality, mutable leaves,
termination of supplied callbacks, the Gerbil tree implementation, concurrency,
allocation, GC or compiler correctness. The Lean example is top-level
`Examples/TableRevision.lean`; Scheme does not load or locate a Lean checkout.

## Explicit key/value isomorphisms

`table-isomorphism source target key value` lifts two existing `Wrapper.` objects
into a collection Wrapper. Each supplied Wrapper declares `Domain`, `Codomain`,
`.ap` and `.unap`; the descriptors must be identical to the corresponding table
Key/Value descriptors. No new conversion namespace or automatic inference is used.
The resulting `.ap` converts source to target, and `.unap` converts back. Sets use
their existing `Table` with the Unit value identity Wrapper.

`(.@ mapping Delta)` is another Wrapper. Its input and output are ordinary
`(base . delta)` pairs. It first installs the original delta against the supplied
admitted base. It then converts both snapshots through one typed key registry,
and translates edits in their original order, reading their expected/replacement
values from those converted snapshots. The paired base keeps Function wrappers
coherent with delta expectations; there is no global wrapper memo.
`transport-ledger-action` composes this operation, target installation and an IO
consumer through existing Observation/FUN maps. Every refusal suppresses the
consumer; rediscovering from the winning base permits a fresh attempt.

The contract is a pure, stable bijection **on admitted values**, respecting the
backend key equality and structural payload equality. Both inverses are supplied,
not inferred. Runtime checks recognize outputs and check encountered roundtrips;
they never recursively normalize admitted callbacks again. A converter must retain
admitted Function leaves (for example, Tuple-to-Pair reordering). Recognition of a
procedure alone cannot prove wrapping, and finite roundtrips cannot prove arbitrary
stateful or malicious callbacks safe. These are explicit premises in Lean.

A registry using the target backend rejects distinct source keys that alias under
its lookup equality. The registry spans **both** snapshots, including unchanged
keys and deleted/inserted aliases. A lawful key bijection is injective; a failing
runtime map raises `table-isomorphism-failure` with `collision`, `left-inverse` or
`right-inverse` and the offending key/value. Invalid result membership raises the
existing TypeError. Domain mismatch, stale conversion or stale delta metadata
raises the existing Gerbil Error. Source conflicts precede converter callbacks;
callback exceptions retain their identity. No partial carrier/delta is returned.
External callback side effects cannot be rolled back.

Converted deltas retain deduplicated origin and converter descriptor revisions;
inversion retains that lineage. Supported metadata changes invalidate both the
retained conversion and its produced deltas. Guards prevent supported metadata
writes during conversion. Mutable hidden state is outside that revision discipline.

Conversion scans the complete admitted snapshots and builds a private target
carrier plus key registry. Delta transport also performs the original installation;
it is not an O(edits)-only transformation and no speedup or GC claim is made.
Existing backends supply their own fold, equality, allocation and shape costs.

The companion Lean proofs add key/optional-value injectivity, view/edit roundtrips,
undo commutation, finite discovery commutation, write commutation and installation
commutation including the **first mapped conflict key**. The existing optional lens
laws continue to apply to the target view. Regressions cover canonical UInt/String
keys, Tuple/Pair values with shared checked Functions, forward/inverse deltas,
conflict/retry, consumer suppression, cross-history collision and metadata refusal.
The top-level Lean example models callback identities as opaque handles.

Automatically inferred isomorphisms, incrementally maintained folds and asymptotic
backend optimization remain outside this unit. The general library remains open
in TODO.md; explicit conversions advance the original proposal's future work.
