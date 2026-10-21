# Slot observations and cache replay

The MOP exports `call-with-slot-read-observer` and `replay-slot-reads!`.
`object.ss` owns read delivery across `.ref`, `.ref/cached`, `.ref/inline`,
presence queries and name enumeration. There is one value evaluator and one
cycle guard. No consumer needs to patch an object engine or inventory fields.

```scheme
(def records (make-hash-table-eq))
(def result
  (call-with-slot-read-observer
    (cut hash-put! records <> #t)
    (lambda () (.ref/inline configuration site))
    before: (lambda (receiver key) (check-selected-source receiver key))))
(replay-slot-reads! (hash-keys records) check-selected-source)
```

`check-selected-source` in this example is an application callback, not a POO
export. It may inspect source specifications without recursively observing its
own metadata accesses. Nested observers receive the same actual read tokens.
The `before:` callback runs before the selected getter; replay runs when the
consumer requests it, including immediately before admission returns. An
observer does not itself prove source identity or approve a configuration.

## Record and cache ownership

Each receiver owns its read table, cleared together with its normal cache and
layout. There is no global strong receiver registry. Cold computation captures
actual dependencies even outside an observer, so a value warmed before admission
can later replay them. Failed computations install neither a value nor a record.
A live token retains its receiver intentionally; releasing the receiver and all
consumer tokens leaves ordinary collectible cycles, not a registry root.

Value tokens bind the receiver, mutation revision, instance table, current cell
identity and dependency tokens. Supported edits invalidate them. Bootstrap
anchors bind their explicit constant value and revision without requiring an
instance table during self-hosted construction. Structure tokens retain their
first preparation dependencies, including reads made by MOP preparation hooks.
They enumerate names without demanding unselected field values.

Inline cache hits use the same delivery boundary as ordinary warm reads when a
computation or observer needs dependencies. An inactive hot inline read still
reads its guarded vector cell; it does not redirect through `.ref` or allocate a
new record. The access-site guard retains receiver, revision and layout identity.

A `.ref/cached` miss invokes the native default thunk without computing the slot.
It records **cache absence**, not field absence. Later cache population can make
that observation stale without changing the revision. Defaults have independent
observations because different invocations can depend on different inputs.
False values remain distinguishable from missing cache entries.

## Refusal and scope

Replay refuses a stale token with `stale slot dependency` and its key. It does
not rerun potentially effectful getters. Native prototype invalidation remains
unchanged; arbitrary dynamic cross-object reads are validated on replay rather
than silently recomputed. Caller synchronization of mutation/evaluation remains
a prerequisite. Raw struct/cache writes and mutation inside an already cached
container do not become supported revision events.

Source files, JSON origins, domain Contracts, selected contributions and final
plan identity remain application concerns. POO records accesses to their values;
it does not authenticate files, rewrite source provenance, or implement a Loader.
Eager `def-slots` extraction and closures over already-extracted scalars remain
ordinary lexical captures. They are not retroactively receiver-aware references.

## Issuance and selected metadata routes

`object.ss` owns both native issuance and replay; `mop.ss` reexports replay.
`slot-observation.ss` only maintains dynamic observation frames and delivery.
`object-read-issued?` answers whether a record has the native issuer's identity
association and unchanged original payload. It is not a currentness check.

Persistent value/query records and transient cache-miss records use one private
mint. The public seven-argument `make-slot-read` constructs a raw record and
never authenticates it. Minting helpers are not module exports. A private weak
identity map associates a record with its original frozen-payload closure. The
record retains that closure; both map keys and values are weak, so the issuer
does not become a global root. A live transient record remains verifiable after
GC without adding it to the receiver's read/value cache.

Before calling a closure, verification compares its exact identity with the
private association. Borrowing another record's closure, changing a signed
field, or replacing the closure with a true-returning function is refused.
Replay authenticates the complete selected graph before its first observer,
then checks and observes in DFS preorder and repeats native checks in that same
order. A forged child can therefore be refused before a stale authentic root;
this is an entry policy, not diagnostic equivalence for malformed inputs.

The fixed native checker validates actual metadata dispatch: exact table/backend
classes, `ref`, backend hash/equality procedure identities and no backend lock.
It does not call those target methods to authenticate them, rebuild cleared
caches, or force unselected getters. Custom table routes need separate auditing.
The internal native key vocabulary remains closed and bounded.

An observer remains an arbitrary application callback. Persistent replacement
of a checker or metadata route is refused before subsequent dispatch, including
in the final sweep. This is not proof that a callback never changed and restored
external state. Unsafe closure inspection, private issuer mutation, replacement
of trusted runtime primitives and unsynchronized concurrent writes are outside
the supported serial boundary. Source-observer restrictions and external atomic
commit protocols remain consumer responsibilities.

`t/issued-read-test.ss` exercises export privacy, actual persistent/miss issuance,
forgery and payload rejection, complete dependency preflight, metadata-route
replacement before/inside observation, and live/dead transient GC lifetimes.

## Inspecting issuance without granting it

`object-read-issuance` returns five values: the currently presented birth,
registered original birth, originally bound read identity, a fresh seven-field
metadata vector and a copy of the frozen key shape (or false for a symbol key).
A read with no private registry entry has no original/signed snapshot. The
inspector calls only the registry's original closure in its zero-argument copy
branch; it never calls a supplied replacement. The existing one-argument branch
still verifies the same lexical captures. No getter, observer or mutable class
constructor is invoked by the copy branch.

The metadata vector follows the existing read fields: receiver, key, revision,
instance, value, dependency list, checker. Its container and list spines are
copies; referenced object identities are intentionally shared. Reconstructing a
raw read from these fields grants no issuance. Inspection does not register a
miss or warm any selected value. It is a low-level diagnostic/proof interface,
not a new configuration surface or signing API.

A consumer may project these actual registry/environment observations into a
formal model instead of assuming a private Birth. That projection must preserve
live eq? identities, dependency order and revision, and keep cache membership
separate from authority. Endpoint agreement does not certify a callback's
history: a callback can execute an effect and restore metadata before return.
Supported receiver edits still advance revision even when values are restored.

## Receiver ownership while replaying

Replay authenticates the complete selected read graph, then privately collects
its receiver identities. The existing invalidation preflight rejects a supported
edit affecting any receiver in an active replay with `object mutation during
read replay`, before clearing caches or advancing revisions. Nested replay keeps
outer receiver sets; normal and exceptional returns restore the caller's frame.
The frame is private, thread-local and constructed by replay, not by a caller's
purity flag. Replay's public arguments and diagnostic traversal order are unchanged.

An ancestor edit is also rejected if its affected dependency closure reaches a
protected child. Independent unselected receivers are not frozen. Transient
miss records protect their receiver without being inserted into the read cache.
Outside replay, the existing mutation/revision protocol is unchanged.

This guards supported POO edits in a serial callback, not arbitrary SDK stores.
`runtime.slot-set!`, generated raw setters, FFI and concurrent writes do not
acquire this frame. In particular, raw metadata modification/restoration still
can execute an effect and leave matching endpoints. This is neither a metadata
write-history certificate nor a rollback mechanism.

## Type catalogs use the same authenticated replay

`reobserve-slot-reads!` is owned by `object.ss`, alongside `replay-slot-reads!`.
`slot-observation.ss` transports observations; it cannot authenticate arbitrary
caller-provided checkers. `optional-validation.ss` imports both replay operations
from the object engine. The public MOP reexports those same bindings.

Both operations enter one private `call-with-issued-reads` scope. It authenticates
the full selected dependency graph before any work/observer callback, derives
the protected receiver set from those records, and checks currentness before
return. Reobservation first checks all records, then delivers the original token
identities to its caller's recording frame. Its work and delivery callbacks stay
inside the same selected receiver frame. A supported write is rejected before
changing a selected receiver; payload/route replacement is rejected on the final
authentication/currentness sweep. No getter is rerun and a transient miss need
not be inserted into its receiver's read cache.

This preserves the new Type catalog's warm-path dependency observations without
giving it a second issuer or a purity annotation. Raw reflective writes, foreign
code and concurrent external changes retain the limitations above. In particular,
these APIs do not authenticate an effect that was changed and restored outside
the supported mutation boundary.
