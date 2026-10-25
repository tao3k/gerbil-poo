# Typed table key focuses

This is a concrete collection-library future-work unit. It reuses the existing
Gerbil POO Lens, `using`, table deltas, persistent backends and FUN/IO. The standard
include `table/focus.scm` stays inside `clan/poo/table`; it is not a public module.

## Complete key protocol

`methods.table` now constructs both `.lens key` and `.lens/opt key` with the
existing `lens-of-get-set`. Both setters take **value before state**, matching
`Lens.set`, `Lens.modify` and `Lens.compose`. The required getter preserves the
backend's missing-key refusal. The optional getter distinguishes `#f` (absent)
from `(some #f)` (stored false); its setter also supports insertion and deletion.
Keys and optional payloads are recognized without normalization. Invalid keys,
invalid Option shells and incompatible values refuse; raw procedures must be
admitted explicitly at the normal Function boundary. Existing checked Functions
retain their exact identity.

The retained raw-root focus captures the table, child Type and declared origin
revisions. Both accessors refuse after supported metadata changes, even on an
empty table. Update discovery, callback and installation share the existing
construction guard. `.update/opt` now reuses `.delta/opt` plus `.apply-delta`, then
recognizes the complete result; `.update` retains its existing default thunk
convention. No-op raw updates return the original root. Callback and custom
whole-table recognition failures expose no partial root and preserve exact causes.
Delta Option shells are copied by the existing protocol. Mutable leaf stability,
valid persistent backend laws and terminating callbacks remain caller premises.

All five style protocols expose `.ref/opt`, `.update/opt`, `.update`, `.delta/opt`,
`.acons/opt`, `.lens` and `.lens/opt`. Receivers expose the corresponding Gerbil methods. The
captured FUN protocol authenticates owners; foreign, consumed and stale metadata
refuse. Discovery captures a delta without consuming its owner. Installation uses
one existing `step`: pure/posh keep the predecessor, mutable/classy retain identity,
and linear consumes it once, including observational no-ops. A focus can operate
on multiple live compatible owners; it is not authority to revive a retired one.
Set membership still has its separate Boolean lens; table key focuses on a set
style observe its backing Unit-valued map.

## Atomic modification and composition

A generic get/transform/set sequence is unsafe for an owned focus: the transform
can reenter and publish a winner before set captures its generation. Table focuses
therefore supply `.modify`; `Lens.modify` delegates to that declared capability,
otherwise deriving modification from the ordinary getter/setter protocol.
`Lens.compose` retains modification delegation at every composition level. The
whole focused modifier consequently runs inside one captured generation; a later
head comparison rejects an older result rather than overwriting a winner.

This guarantees one table owner installation. It does not make two different
mutable owners atomic, roll back callback side effects, or roll back an already
completed nested update if an external outer setter later refuses. Ordinary pure
composition laws require lawful pure outer setters. `revise-focused-ledger`
composes the existing immutable service-slot lens with a linear key focus and
Reader/FUN map: successful complete admission precedes IO; refusal suppresses IO;
explicit retry starts from the retained persistent base, without replaying effects.

## Laws, costs and acceptance

`TableFocus.lean` reuses optional replacement's three lens laws and `styleStep`.
It proves the focused observation, unrelated-key frame, refusal/consumption,
required-absence failure, observational no-op with linear retirement, service frame
and stale-generation rejection. It is a semantic model of the protected protocol,
not a proof of the Gerbil compiler or mutex implementation. Raw persistent lens
laws use extensional views; mutable and linear laws concern the returned successor
observation, not identity of retired/updated references. Whole-table refinements
may reject a well-typed replacement; unrestricted total lens laws are not asserted
for such a partial focus.

Regressions cover both RationalDict and Trie, all five styles, stored false,
value-before-state order, invalid input, metadata invalidation, foreign owners,
late refinement failure and retry, exact Function identity, nonconsuming delta
capture, and a composed reentrant winner. Ninety finite style/key/replacement
combinations exercise get-put, put-get and put-put as observation laws.

No new tree, lock, scheduler or cache is introduced. The checked update path pays
for full recognition at discovery and postcondition, one old-value lookup and at
most one persistent write (no write for a no-op delta). A focus is prepared once
and may be reused. No constant-time admission, destructive storage or host GC
latency claim follows from these laws.

## Optional association through the same update boundary

`.<-list` and `.singleton` are constructors, while `.acons/opt key request root`
is a checked update to an existing admitted root. Its two request meanings are
intentionally distinct from `.update/opt` and the optional lens setter:

| Request | `.acons/opt` | Optional replacement |
| --- | --- | --- |
| `#f` | retain the original binding, including absence | remove the binding |
| `(some value)` | insert or replace with exactly `value` | insert or replace |
| `(some #f)` | store false, if Value admits false | store false |

The old direct match skipped source/key admission on `#f` and bypassed the shared
delta/final-root boundary for a present request. Now a single optional-association
modifier copies the caller's Option shell before any metadata/root/child callbacks,
recognizes that captured request after source and key admission, and selects it or
the old binding. Both branches run the ordinary `.update/opt` protocol. The redundant Trie public
zipper-update override has been removed: it shadowed that protocol, skipped typed
admission and rebuilt even unchanged roots. Trie now inherits the common delta
path and retains its original persistent `.acons`/`.remove` algorithms. Invalid
input, stale ownership and complete-root/index constraints cannot be bypassed by
an absent request. Admitted Function leaves retain identity; this does not infer
closure serialization or normalize new raw input. Caller mutation of shared leaves
and raw backend writes remain outside the stable-input contract.

All five Table styles and standard Gerbil receivers delegate the same modifier to
their existing generation-capturing installer. Refusal leaves the owner available
for retry; a successful linear no-op still consumes its predecessor. No-op requests
retain the existing empty-delta semantics: they are not assertions against a later
base's old value. Existing stale changed-key checks and inverse recovery apply to
nonempty requests unchanged. Raw Table calls use current metadata on each call;
retained style factories continue rejecting changed origin revisions.

`associate-ledger-action` composes Reader/FUN map with one optional write and IO.
Integrated controls cover failed Function requests, absent rollout, checked callback
replacement, inverse recovery, unique-index collision, final-size refusal, retry,
mutable Option shells, stale factories and a reentrant winner. `TableFocus.lean`
reuses `pointChanges` and `focusModify` to prove exact optional observations,
refusal, inverse/stale-key behavior, the one-edit bound and linear retirement.
Source/key/final-root admission and supported metadata writes remain Scheme
protocol premises; pure finite proofs do not verify callback termination, runtime
memory ownership or physical locks. This advances the collection future work.

Design reflection: the fix removes the special-case path rather than introducing
an Option validator, ownership engine or namespace. One small captured modifier is
shared by raw and style updates; existing recognition, differences and installation
remain authoritative. Full admission and backend costs still apply even on no-ops.
