# Checked binary combination

This finite unit advances the proposed collection library's future work. It
closes the existing `.merge`, `.union`, `.join` and `.join/list` protocol across
persistent backends, explicit representation Wrappers and five ownership styles.
Automatic backend/law discovery and physical exclusive ownership are separate
research boundaries.

## One typed protocol

`(.call table .merge choose left right)` visits the union of the two original
key domains. The resolver receives `Key`, `Option Value`, `Option Value` and must
return `Option Value`: `#f` removes the key; `(some #f)` stores false. Both input
roots pass complete recognition before resolution. Result payloads must already
be admitted; existing Function wrappers are retained, not normalized again.

Generic traversal visits left bindings in backend order, then right-only bindings
in right order. Trie retains its existing paired traversal through the declared
`.merge/key/opt` backend capability, including its ascending union order. No
cross-backend effect-order equivalence is asserted. Neither identical inputs nor
an identity result suppresses resolver calls. Callback Option shells are copied
on entry and return; reusing or mutating a shell cannot rewrite another decision
or a delta's old-value expectation. Leaves and persistent roots remain immutable
caller obligations.

The generic path collects changed decisions before one `.apply-delta`. Thus
correlated unique/grouped indexes see the final state, including valid unique
value swaps. Wrapper derivation conjugates both snapshots and optional callback
values through the source merge, then encodes once. It does not replay a merge
as individual indexed target writes. The same result-admission helper serves
unary maps and binary merging.

## Union, joining and observation

`.union` calls its resolver only on overlaps, with raw admitted payloads; one-sided
bindings pass through. The resolver must still be a procedure on empty inputs.
`.join` is left-biased by presence, retaining a stored false over a right value.
`.join/list` validates its finite input list and retains its existing `foldl` operand order:
the current item is on the left, so later sources win. A nonempty batch starts at its first root,
so it does not manufacture a forbidden empty seed. An empty batch must admit the
backend's empty root or refuse.

Each intermediate join remains a checked operation. Associativity of the
mathematical left-biased optional view does not waive a custom root refinement
that rejects an intermediate result. Successful batches retain this declared source
priority; failed batches expose no new owned state.

Public `.=?` observes both admitted domains and matching child values without
building a throwaway empty merge result, which may violate a nonempty refinement.
The common boundary now also covers the RationalDict and Trie implementations;
backend and payload-equality laws remain explicit premises. See the complete
nonconsuming equality protocol below.

## Ownership and FUN/IO

All five styles reuse the existing single-owner step. Only the left owner is
installed or retired; distinct right owners are read as persistent snapshots.
If the same handle is supplied on both sides, both reads use the captured left
generation. Batch joining captures all right snapshots before the persistent
fold. Receiver calls are `left.merge choose right`, `left.union choose right`,
`left.join right` and `left.join/list rights`. Set receivers retain their existing
`left.union right` signature through Gerbil's `case-lambda` dispatch.

A right owner is not jointly committed or required to remain current after
capture. Explicit callback effects can change other owners; they are not undone.
A reentrant left winner rejects the stale outer commit. Foreign, consumed or
metadata-stale handles refuse through the existing guards. Resolver, translation,
child-type, index or root refusal exposes no staged result and preserves the
original left owner for retry unless the callback itself already published a
winner.

`merge-ledger-action` in `examples/service-collection.ss` composes Reader/FUN,
linear ownership and IO. Tests combine callback-bearing services, correlated
indexes, approval refusal, fresh retry and inverse-delta recovery before IO.

## Costs and proof boundary

Generic resolution performs one callback per union key, plus traversal and point
lookup/membership preparation. Only changed decisions enter the one final delta;
no-op generic merges may retain the left root. Trie may still allocate temporary
nodes even for an identity resolver. Full input/output admission, metadata,
equality, index preparation, conversions and allocation/GC are separate costs;
this is not a constant-time merge or an end-to-end speedup claim.

`TableMapping.lean` reuses a generalized effectful binding map for paired requests
and output values, retaining existing unary laws. It proves domain/size bounds,
explicit representation transport, overlap-only union, left-biased join
associativity, callback/root refusal and linear consumption. Its observation
model also proves generic equality reflexive and sound under finite enumeration
and child-equality laws. `Examples/CollectionStyles.lean` checks opaque callbacks,
shared-budget refusal/retry, final unique swaps/collisions and stored false.
Finite complete distinct-key union enumeration, persistent lookup/installation,
representation laws and pure successful observations are backend premises. These
are semantic proofs, not verification of Gerbil compilation, locks or GC.

## Complete equality observations

The previous RationalDict and Trie public overrides bypassed the common root
admission; Trie could return true for the identical reference before observing any
invalid child or refinement. Their existing algorithms now live behind the explicit
`.=?/key` structural capability. RationalDict reuses its standard Iterator traversal
over the RBTree; Trie retains its same-root/shared-subtree shortcut. Public `.=?`
admits both complete roots before resolving/calling that capability. Without it,
the existing two-sided domain/lookup algorithm remains the fallback. There is no
new equality engine, normalization, namespace, empty constructor or trial write.

One supplied value-decision function checks every encountered result with Gerbil
`using` and `boolean?`; the complete backend result is also checked. A truthy
non-Boolean at an earlier leaf cannot be hidden by a later false decision.
Unexpected backend/value failures retain their original cause, not a false answer.
Metadata writes to protected origins refuse during admission and comparisons.
Mutable hidden leaves, arbitrary callback effects and termination remain caller
obligations. A lawful backend may skip equal shared structure: payload equality
must therefore be reflexive and agree with the declared observation relation.
Runtime membership does not supply a missing value `.=?` method, establish its
laws or infer extensional equality of
Function closures. Explicit Function identity equality compares admitted handles,
never invokes the stored functions and never creates replacement wrappers.

All five Table styles now expose `.=?` through the existing Set/Table relation
reader and standard Gerbil receiver method. Both reads are nonconsuming, including
linear references. Owned/receiver provenance, consumed handles and stale factories
refuse normally. Pure raw snapshots remain duplicable and are accepted by compatible
pure factories; they do not acquire a fabricated owner identity. Reads capture
sequential persistent observations, not a joint atomic read of two mutable owners.
Set styles retain membership equality through the same relation delegation.

`equal-ledger-action` composes Reader/FUN map with equality before IO. Regressions
cover invalid identical roots, a right-side refusal before backend work, whole-root
refinements, all backend Boolean decisions, stored false versus absence, 108 finite
snapshot pairs, all five styles and receivers, represented/indexed roots, protected
metadata, failure retry and Function identity after inverse recovery. No index or
business snapshot is rebuilt just to compare it.

`TableOrder.lean` reuses the existing left/right admission combinator, generalized
to the comparison result type so equality needs no duplicate preparation function.
The finite reference proves optional-presence soundness, first false/error behavior,
lookup soundness, completeness under reflexive value equality, full observation
equality under a finite domain cover, and a visited-key bound. Backend correspondence,
stable payload observations, persistent carrier laws and supported metadata writes
are premises. Recognition, backend traversal/lookup, callback, preparation, allocation
and GC costs remain charged; this does not prove runtime/compiler correctness or
an unconditional complexity/latency improvement. This is collection future work.

Design reflection: retain mature structural algorithms, move their public contract
to one shared boundary and lift an existing relation reader. The new mechanism
names the private backend capability instead of adding a public compatibility path.
