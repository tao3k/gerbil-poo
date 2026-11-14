# Component publication snapshots and request families

The existing coordinator now publishes a graph and associated POO metadata as
one private snapshot, and distinguishes independent stages from explicit
restaging within one request family. This remains finite generalized-prototype work. Original Racket Appendix B
`$lens-gen` (source pin `9affa8fbbb4f12cbd98cb97f8b8b84474fc39429`, lines
2108–2133) supplies the lens/wrapper construction, not a concurrent transaction
algorithm. This increment composes the existing source revision, FUN Reader,
whole-SCC closure, registered lens guards and joint service approval.

## Authoritative publication boundary

The previous snapshot-bound action checked the snapshot supplied by its caller.
`component-publication` adds a private coordinator holding the actual current
approved graph and a standard native mutex. `stage` captures that graph and the
existing component revision action without constructing candidates. `submit!`
reads the authoritative head, rejects a stale request before work, executes the
existing construction/approval chain outside the lock, then checks expected/head
identity again under the short installation lock. Only that boundary installs a
candidate. Native `with-lock` is reused rather than introducing synchronization
primitives. The locked installer runs no user callback. Explicit registered guards
are rechecked inside the final installation lock. Coordinated concurrent approval
writes use `revise-approval!` under that SAME lock; see [approval-revision.md](approval-revision.md).

A sibling may advance the head while a request builds or approves. The old
candidate then refuses installation even if its own construction and approval
succeeded. Refusal and exceptions return the CURRENT coordinator head plus a
failure; they must not restore the request's old predecessor over a successful
rival. A request belongs to exactly one coordinator. Even a successful no-op
publication makes old siblings stale, since identity and approval lifecycle matter.

This is optimistic head arbitration, not automatic merging/rebasing. A failed
request can be retried only while its expected publication remains current and
its metadata guards remain valid. Policy revisions require fresh preparation;
a rival publication requires a new request against current topology. Refused
candidates never become a publication or retry cache. No arbitrary callback
side-effect rollback is promised.

## Atomic graph and metadata

`publication initial metadata: value` associates a POO object (or `#f`) with an
already-approved graph. `snapshot` captures one immutable observation;
`snapshot-graph` and `snapshot-metadata` project that same object. `current`
continues to return its graph. Metadata follows the existing immutable-source
and registered-guard discipline; snapshot identity does not authenticate it.

`stage ... metadata: value` binds the proposed metadata to that request.
Omitting it inherits the **captured published** metadata, not a later head.
`submit-snapshot!` returns the complete accepted or refused snapshot and failure;
`submit!` projects the graph from this same operation. A caller must not pair a
graph return with a second lookup of current metadata. Even equal-valued commits
create a fresh snapshot identity and retire earlier expected-snapshot tickets.

`call-with-snapshot owner action guards: guards` checks the captured head before
and after the callback, outside the installation lock, and preserves multiple
return values. Head identity and captured lens-source revisions are checked
under the same domain lock at entry and return. A policy-only write can leave
the head unchanged and still refuse the read. A rival commit
causes refusal before values are released; historical snapshot inspection itself
is not a live-source claim. Callback effects are never rolled back.

## Explicit request families

Each `stage` creates an independent family. Sharing an expected head does not
merge callbacks, fragments or family tickets; the existing first-winner rule
remains. `restage owner previous complete-fragments build admit ...` explicitly
replaces one family's complete proposal. It requires the same owner, live expected
snapshot and current family ticket. It issues a new ticket before preparing the
replacement action; a later admission refusal cannot rearm its predecessor.
Invalid command metadata is rejected before a ticket is issued. The replacement
supplies its own callbacks and guards; nothing silently combines author programs.

Restaging during an older admission makes that return obsolete even though the
published head has not moved. Final installation checks both snapshot and family
version under the same domain lock. These are prerequisites for binding future
reverse-index continuation to the correct request. This cut does **not** implement
that traversal or wire Yuanxu `.refresh`; it adds no loader or approval cache.

## Practical examples and controls

`examples/component-requests.ss` composes the existing multi-round service recipes,
lens family, whole-group builder and both current service policies. Its small
higher-order staging adapter adds an optional admission continuation for controlled
interleaving. Production constructors/approval predicates remain pure and locally
total; nested submission is used explicitly as test scheduling, not as a new
implicit component dependency.

Native controls include:

- Two requests staged from the same compact source; first acceptance makes its
  sibling stale before any builder or approval is called.
- A rival publishes spare=5/settlement=30 while an older settlement=24 candidate
  is in approval; the older candidate cannot overwrite the rival.
- A real worker thread paused at approval using standard bounded channels. Its
  sibling publishes before it resumes, so the late installation refuses. Waiting
  and joining retain fixed five-second bounds inside the existing 90-second test.
- An approval exception after a rival succeeds returns the rival as current.
- One service refuses joint approval, retaining exact old head; policy revision
  invalidates old guards and a freshly staged request rebuilds and can succeed.
- A rival wins after refusal; retry must use its current merged topology, then
  split and restore in later rounds. Old requests still refuse after values return.
- Wrong-coordinator refusal and no-op sibling invalidation.

The thread control schedules a bounded supported interleaving; it is not exhaustive
SMP verification. Metadata shared between candidate computations stays immutable;
existing parameterized object guards protect supported writes in the operation,
not arbitrary foreign-thread mutation or hidden callback state. The coordinator
lock protects the authoritative head. It does not make all POO objects thread-safe.

## Lean correspondence and proof scope

`Functional.ComponentPublication.install` models the serialized installation
choice over abstract decidable snapshot identities. Generic proofs establish:
accepted installation selects exactly the candidate and implies current=expected
and approval=true; stale candidates preserve current; approval refusal preserves
current; a first fresh acceptance defeats its predecessor's sibling; refusal permits
retry if the head remains unchanged and fresh current approval is supplied.
Fresh native object identity, truthful approval and faithful locking remain
implementation premises; the Lean model is not a proof of the runtime mutex.

`Examples/ComponentRounds.requestsCheck` constructs both actual typed source
revisions, discovers groups and closes their real equations with the shared
`ComponentExecution` runner. It checks settlement=24 and 30 candidates, rejected
late install, cross-service refusal, current-policy retry and a freshly staged
split of the winner yielding settlement=20. Local snapshot numbers are fixture
identities only; Scheme does not read them or depend on a Lean checkout.

Finite declared graph/lens families, correct declared reads, accepted certificates,
immutable/extensional metadata, pure locally total callbacks and faithful builders
remain premises. General convergence/leastness, hidden dependencies, interior-SCC
skipping and unrestricted knots remain open. Formal head-selection laws, native
pointer/thread controls, full local gates and exact-head CI are separate evidence.
No compiler/runtime correctness or performance improvement is claimed. No new
versioned JSON, full benchmark corpus or archives are committed.

[approval-revision.md](approval-revision.md) extends this workflow with several
paused requests, policy change-back invalidation and explicit fresh restaging.

The [shared-approvals.md](shared-approvals.md) extension permits several endpoints
to share an explicit approval domain, retaining independent heads and dependency-
selective guard invalidation. Foreign-domain/raw writes remain outside the protocol.

The additional native controls cover atomic metadata inheritance/replacement,
restage-before-submit and restage-during-admission, refusal/retry without old-ticket
reactivation, independent shared-domain metadata, a paused snapshot reader, and
source guards with multiple return values. An unused metadata slot traps eager
forcing. `Functional.ComponentPublication` adds family noninterference,
continuation rejection, no-op retirement, paired projections and guarded-read laws.
Core's existing `GraphSnapshot` model adds metadata-head and family-isolation
invariants with matched faults; neither model is a native compiler/mutex proof.

A denied replacement preserves the installed snapshot and retires the older
ticket in that request family. The final check under the publication lock
therefore checks both snapshot identity and request lineage after approval.
The two-thread test pauses an old submitter in approval, restages and denies
its replacement, then checks that the old submitter cannot publish.
[LeanPoo proof](https://github.com/tao3k/lean-poo/blob/31b550d15e81b095795078efb8344442d8ba6edd/LeanPoo/Functional/ComponentPublication.lean#L106-L132) · [SysML](component-publication.sysml)
