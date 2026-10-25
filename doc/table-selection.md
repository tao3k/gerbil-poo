# Checked table selection across persistent backends

This closes a concrete omission in the collection proposal's future work.
Trie previously implemented public `.filter` and `.partition` directly and treated
any non-false predicate result as true. The common implementation admitted Bool
but rebuilt from `.empty`, unnecessarily requiring transient roots and pointwise
index updates. Neither behavior is the shared checked selection protocol.

## Shared boundary and existing algorithms

`methods.table` owns both public operations. `select-table` stays in the existing
`clan/poo/table` module, alongside the other bulk algorithms in `table/mapping.scm`.
It checks the predicate procedure even for an empty input, admits the original
root before callbacks, requires each decision to be Bool, and recognizes every
complete returned branch before exposing a result. Recognition does not normalize
or rewrap child Functions. Callback/type/refinement failures retain their causes;
callback effects are observable and are not rolled back.

Declared `.filter/key` and `.partition/key` capabilities retain Trie's existing
structural algorithms and unchanged-subtree sharing. They receive a checked
classifier. Public `.filter`/`.partition` are inherited, so specialized traversal
cannot accidentally bypass the common admission boundary. Direct capability use
is an internal backend obligation, not an additional checked entry point.

A generic table folds the original root once, records ordered removals, and calls
the existing `.apply-delta` once per changed branch. All classifier decisions
precede either install; no predicate is replayed. A no-op branch returns the
original root and makes no persistent writes. No empty seed or admitted
intermediate deletion root is required. Final roots must still satisfy the full
descriptor; an inadmissible empty result is a real refusal.

Explicit `table-wrapper` representations transfer the complete source selection
operation and encode its outputs. They do not replay point removals through an
indexed receiver. Source and target refinements and encountered inverse checks
remain in force. Traversal remains the source fold order, including a representation
whose key mapping reverses numeric order; it is not silently resorted.

Correlated indexes prepare deletions against each final primary through their
existing delta installer. The complete source primary is recognized before any
index cache preparation; carrier-only delta shape admission cannot substitute
for the source descriptor's whole-root refinement. Unique/grouped cache entries and all declared origins
remain synchronized. Source/backend shape, persistent-write fidelity, finite
distinct-key traversal and declaration stability remain protocol obligations.

## Ownership, composition and failure retry

The five existing styles use the same single-result step or multi-result stage.
Both partition branches are private until admission and one owner commit finish.
Mutable/classy retains the first owner identity and creates a separate second
owner; linear retires its predecessor only on success. Refusal leaves the original
owner live; reentrant/competing winners and stale metadata retain their existing
rejection semantics. No extra transaction, scheduler or namespace is introduced.

`partition-ledger-action` and the existing set `partition-access-action` share one
higher-order Reader/FUN operation. Complete branches are observed before the IO
consumer runs. The service example routes indexed callback-bearing rows, refuses
an incomplete cohort without invoking IO, then explicitly restages a fresh
classifier and preserves every checked Function leaf.

## Formal and executable acceptance

`t/table-selection-test.ss` retains its independent finite oracle and adds strict
Trie/generic callback controls, original-root-before-callback refusal, final-root
refinements, no-insertion/no-op write counts, indexed representation transfer,
all five styles, late second-root refusal and the complete FUN/IO service retry.

`TableSelection.lean` proves input/classifier/second-output refusal order, owner
retention on late failure, deletion lookup/frame and no-op laws without Function
equality, the combined deletion count and representation transfer preserving
branch order and exact errors. Top-level `Examples/CollectionStyles.lean` checks
four opaque callback-bearing services, incomplete-cohort refusal, successful
restaging and approval refusal after preparing the first branch.

The Lean view laws assume faithful backend observations and lawful representation
translation. The deletion count is at most one edit per original binding across
both partition branches; it is not an allocation or wall-time bound. Admission,
backend lookup/write, index projection, conversion and GC costs remain explicit.
Arbitrary callback termination, destructive backends, automatic symmetry discovery
and compiler/runtime verification remain outside this finite unit.

## Checked predicate observations

The existing `.find-first/opt`, `.find-last/opt`, `.find-first`, `.find-last`,
`.any` and `.every` now share one short-circuit observation protocol. Table
predicates receive `(key, value)`; Set predicates receive the element. Every
visited decision must be a Boolean. Invalid predicate procedures use Gerbil's
standard contract refusal; non-Boolean decisions use the existing POO TypeError.
Original callback/backend exceptions propagate unchanged. Required searches use
the existing Option absence error. `(some #f)` is a present false Set element.

Complete carrier/child/refinement admission precedes every user predicate, even
if the first entry would decide the result. Recognition calls the internal raw
traversal kernel, **not** the public admitted query; otherwise admission would
recursively invoke itself. The same kernel supplies forward/reverse first match,
existential success and universal counterexample. No snapshot list, new cache,
normalization or Function wrapper is constructed. Scoped metadata protection
covers recognition, predicate callbacks and short-circuit escape.

Traversal follows the backend's declared forward/reverse order. An unordered
carrier does not acquire a numerical sort order. The former Trie overrides
silently called predicates with only the key and assumed monotonicity while
advertising the general two-argument interface. They are removed: arbitrary
predicates use the shared traversal, and ordered positioning retains its explicit
`.seek` capability. No implicit binary-search promise or compatibility alias is
added.

All five Table/Set styles and the standard Gerbil receivers expose the same
queries without consuming ownership or allocating successor owners. A query
captures one immutable snapshot; reentrant successful publication remains visible
on the owner but does not change the observed source. Consumed/foreign owners and
stale declared policies refuse through the existing guard. External callback
side effects and successful reentrant publications are not rolled back.

`find-ledger-action` composes optional service lookup with Reader/FUN/IO. A failed
admission or predicate suppresses the consumer; a completed observation retains
exact admitted Function identities. Regression coverage includes all finite masks
of a four-entry nonmonotone predicate, forward/reverse callback prefixes, Trie,
RationalDict, explicit boxed carriers, all styles/receivers, invalid tails, false
Set elements, original exceptions, policy-write refusal and corrected retry.

Lean's existing `TableSelection` proves matching-source identity, satisfaction,
absence/all-false and universal/all-true interpretation, decided-prefix shielding,
reverse membership, original refusal, full-admission precedence and unchanged or
consumed ownership. `queryVisits` bounds predicate invocations by source length.
Full carrier/refinement admission, backend traversal/positioning, guards,
conversions, allocation and GC remain separate costs. Short-circuit predicates do
not imply a sublinear total operation. Backend persistence/traversal fidelity and
stable admitted leaves are premises; arbitrary callback termination, physical
ownership and compiler/GC correctness are not established. This finite protocol
advances the proposed collection library's future work.

Design reflection: six public observations reuse one traversal and the existing
Set/style boundaries; the unsound specialization is removed rather than surrounded
with more wrappers. Recognition and public admission remain deliberately separate
to prevent verification recursion. No module namespace or parallel search engine
is introduced.


## Endpoint observations through the same query kernel

Table `.min-binding[/opt]`, `.max-binding[/opt]` and `.choose[/opt]` now reuse the
complete first-match observation boundary with a constant-true decision. Set
`.min-elt[/opt]`, `.max-elt[/opt]` and `.choose[/opt]` project elements through the
existing Set query boundary. The separate RationalSet public min/max overrides
are removed: their direct backend call skipped refinements and could return false
for a required empty query. Existing RBTree/Trie folds remain the algorithms.

Both directions admit the complete source before returning an endpoint, so an
invalid later child cannot be hidden by the first binding. Required empty queries
raise the existing `option-ref` absence error; optional ones return `#f`. A selected
false element is `(some #f)` and a required selected false is a valid value. Selected
Pair/Option shells are fresh, and admitted Function leaves retain their identity.
Set optional choice uses the existing naming convention `.choose/opt`; the old
inconsistent `.choose-opt` field is removed without a compatibility alias.

The names retain their original declared traversal semantics: min/choose observes
the forward endpoint, max observes the reverse endpoint. A lawful ordered backend
therefore provides extrema in that order; an unordered backend provides traversal
endpoints. No numeric order, sorting policy or arbitrary comparer is inferred.
All five Table/Set styles and standard Gerbil receivers delegate to their current
snapshot observer. Reads authenticate owned/receiver provenance, reject consumed
or stale handles and never install/retire an owner. Sequential persistent snapshot
observation is not a joint atomic read of several mutable owners.

`choose-ledger-action` composes Reader/FUN with nonconsuming optional choice before
IO. The integrated represented/indexed service retains a whole-root constraint,
checked Functions, refusal/retry and the original linear owner. Regressions also
cover complete tail admission, one query visit after admission, empty required
queries, false elements, all five styles/receivers, protected metadata, original
backend causes and mutable returned shells that cannot rewrite the source.

`TableSelection.lean` specializes the existing query reference, extends original
source admission with a reverse traversal parameter, and proves first/reverse
payloads, membership, exact empty absence, pointwise representation translation,
post-admission visit bound and ownership preservation. Stable leaves, backend
traversal laws and supported metadata edits are premises. Complete recognition,
backend traversal paths, lookup, metadata preparation, allocation and GC remain
charged; no constant-time or runtime/compiler correctness claim follows. This is
finite collection future work. Design reflection: derive endpoints from the
query/observer chain and remove the bypass; add no cache, traversal engine or
namespace and do not manufacture a valid empty business root.


## Logical emptiness and structural emptiness

Public Table `.empty?` now observes an admitted root's contents rather than comparing
its identity with `.empty`. It never constructs a separate empty value. Existing
RBTree and Trie predicates remain private `.empty/key?` capabilities; derived
representation/order/index views retain structural delegation, and the generic
fallback uses the existing early-exit traversal. Each capability result must be
Boolean; unexpected backend failures preserve their original cause. Complete
source membership and metadata protection precede all shortcuts.

Set `.empty?` retains both backing admission and the Set's own refinement. A
forbidden empty business root is an admission failure, not a successful empty
observation. All five Table/Set styles and standard Gerbil receivers delegate to
the existing nonconsuming snapshot observer. A live empty collection is distinct
from a consumed linear reference, which still refuses before observation. Stored
false values and checked Functions remain ordinary nonempty bindings; no leaf is
normalized or rewrapped.

Structural emptiness is also required for temporary Trie nodes and for removing
a grouped index bucket after its last owner is retracted. Those internal callers
retain their existing shape/origin responsibilities and use the structural helper,
not recursive public business admission. Partial bucket refinements are checked
on the complete final cache. The index factory's `.empty` is now an ordinary MOP
computed slot, evaluated only when explicitly requested; preparing a nonempty
family does not manufacture an invalid empty primary. Primitive count remains
available for defining refinements and is not recursively wrapped in admission.

`empty-ledger-action` composes nonconsuming Reader/FUN observation with IO. Controls
cover distinct empty carriers, a computed empty constructor that must not run,
invalid later children, strict Boolean/unchanged-cause backend results, all styles
and receivers, metadata refusal, temporary partial Trie roots, grouped bucket
migration/undo, and represented indexed Function ledgers with late refusal/retry.
No second counter, cache, storage engine or public namespace is introduced.

`TableSelection.lean` reuses endpoint queries and `observeQuery`. It proves logical
emptiness equivalent to zero finite cardinality, explicit source refusal/ready
results, agreement with a lawful primitive, structural emptiness despite forbidden
business emptiness, owner preservation and consumed-owner refusal. Backend shape/
cardinality laws, finite traversal, stable leaves and terminating refinements remain
premises. Full source recognition, metadata preparation, backend paths/lookup and
allocation/GC remain charged; no constant-time, physical ownership or host runtime/
compiler claim follows. This is finite collection future work. Design reflection:
keep the existing structural predicate and query/observer chain, separate internal
construction from public admission, and delay rather than duplicate empty creation.
