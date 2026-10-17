# Controlled recursive validation

This module advances the paper's generalized MOP **future work**. Section 2 gives
parent and child the same final self; section 5 supplies Type descriptors and
recursive recognition. The paper's Racket code does not already implement this
whole cyclic validation/publication lifecycle.

## Finite catalog API

`close-validation` accepts a builder and a positive node-count limit (default
256). The builder receives an owner-scoped Reference-Type constructor and returns
a nonempty list of `(name descriptor source)` triples. Names are distinct symbols;
every Reference target must be declared. Sources are ordinary POO objects;
descriptors implement the Class/ObjectContract `.validation-fields` protocol.
Reference Types can occur inside existing List/Tuple/optional/variant Types.
Source checking recognizes the exact named source; final membership requires
the canonical target, including values supplied by custom Slot normalizers.
Explicit validation of a known source can resolve its already admitted target.

```scheme
(close-validation
  (lambda (reference)
    (def Left (Record peer: [(reference 'right)]))
    (def Right (Record peer: [(reference 'left)]))
    (def left (.o peer: right))
    (def right (.o peer: left))
    (list (list 'left Left left) (list 'right Right right))))
```

This is explicit finite cataloging, not automatic discovery or a universal
coinductive Type checker. Each name denotes one canonical receiver. Repeated
references to that named target retain sharing. No graph unrolling is required.

## Closure and failure discipline

1. Check the complete catalog and every source's structure, before normalization.
2. Allocate all canonical receiver identities using `prepare-rebinding`.
3. Force every selected field using `force-rebinding`. References resolve through
   this attempt's private directory; they never mark active targets as validated.
4. Run deferred nested Class/ObjectContract whole-value obligations, then every
   named node's final admission against the complete graph.
5. Seal canonical receivers and Reference Types through supported APIs; return a
   private `closed?` value only after complete success.

`closed-ref graph name` reads a canonical node; `closed-type graph name` supplies
its Reference Type. Later explicit Reference validation rechecks graph admission
and returns the same canonical identity. Normal construction hooks are not invoked
implicitly; this protocol validates the supplied sources. Ordinary Class and
ObjectContract validation still performs final checks immediately outside closure.

Each closure attempt owns its deferred queue and Reference directory. Nested
attempts have separate owners. A descriptor from another graph cannot cut
recursion in a new attempt. Build fresh descriptors with the supplied constructor
after failure/revision; do not transplant old Reference descriptors into a new graph.

Whole-catalog shape failure suppresses all normalizers. A normalization exception
discards queued obligations and unwinds the dynamic scope. Remote final refusal
returns no closed graph. Original callback exceptions and `CyclicSlot` propagate;
structured validation failures distinguish catalog, duplicate, missing-reference,
protocol, reference, owner, shape, admission and stale phases.

Registered source/descriptor/Reference/canonical revision stamps guard access and
Reference validation, including supported transitive ancestor invalidation.
Canonical nodes and Reference Types reject supported direct writes. These checks
do not globally revoke arbitrary retained Functions, cover raw setters, discover
external callback dependencies, or provide concurrent mutation isolation. Child
Types/nested metadata not registered through inheritance must remain immutable;
the directory does not automatically discover those object-valued dependencies. Keep
sources/metadata immutable while using admitted values and close/publish a fresh
version after revision. A callback may retain a private receiver or perform effects;
those effects are not rolled back.

## Computed cycles and safe recursive work

Productive computed Function fields can capture checked peer Functions across
object backedges. `examples/recursive-validation.ss` combines this with:

- A genuine positive Boolean cycle solved by existing `closure` least closure:
  `left = true OR right`, `right = left`. It does not choose an arbitrary warm seed.
- The existing explicit recursive Interaction, owner-bound memo and current Type
  admission. Requests decrease their count and carry a finite machine budget.
- Two calls sharing the right/3 request: results 10 and 8, total 18.
- Reader/FUN decoding, complete graph closure, root `refine` and exact
  `bind-evidence`, including raw/stale evidence refusal and current retry.

Active unannotated structural Type/value pairs return a `recursive-structure`
diagnostic rather than receiving coinductive acceptance. Repeated shared pairs
after return remain legal. Immediate cyclic getter demands still raise `CyclicSlot`; arbitrary eager
fixed-point equations are not solved. Machine cycle/budget diagnostics are not
values or successful admission. The graph node-count limit does not bound host
getter/validator execution time. Unregistered recursive Type paths, cyclic raw
containers, arbitrary lexical snapshots and callback termination remain outside
this controlled protocol. Constants keep strict equality; canonical Function
wrapper deduplication is separate work.

## Lean correspondence

`Functional.RecursiveValidation` proves eleven finite catalog/graph laws:
preflight completeness, all-position collection and finite completion, separate
shape/normalization/admission refusal, all-node successful requirements,
canonical reference preservation/sharing/distinctness, and bound root publication.
Named-catalog lowering, receiver allocation, host pointer identity, deferred
callbacks, sealing and revision-stamp correspondence are supplied boundaries.

`Examples/RecursiveContracts.lean` proves the concrete two-hop backedge law and
executes matching positive least closure, productive handlers, shared certified
memo, guarded arguments, budget/eager-cycle refusal, remote/shape refusal and
fresh-owner evidence controls. Existing final-self, recursive cache, positive
closure, refinement and binding proofs are reused. This does not certify Scheme
compiler/runtime/GC behavior or end-to-end performance. Scheme requires no Lean
checkout at build or runtime.

## Selective invalidation and reclosure

`validation-node name dependencies watches build` declares an immutable recipe.
`dependencies` lists **all** named links, computed reads/captures and obligations;
`watches` lists external POO inputs whose supported revisions affect this node.
`build` receives `(reference source)` and returns `(descriptor raw-source)`.
Both accessors reject undeclared targets. Delay cyclic raw-source reads in ordinary
POO slot formulas until every builder has returned. For a retained target, `source`
returns its already canonical receiver, so a new reader never installs its raw
predecessor. Lists/recipes and untracked nested metadata must remain immutable.

`revise-validation #f recipes` starts a revision family. Subsequent calls use its
current `closed?` snapshot as the first argument. The protocol:

1. Preflight distinct support and declared dependency targets before builders.
2. Seed changes from new/replaced recipe identity, registered source/descriptor/
   canonical/Reference revisions, and watched-input revisions.
3. Propagate invalidation to every reader in the **new** dependency graph. A
   changed footprint requires a new recipe, seeding its reader directly; a
   dangling dependency refuses. Sharing and cycles participate in this closure.
4. Reuse clean canonical receivers, Reference Types and computed caches without
   builder invocation, shape replay, normalization or wrapper reconstruction.
   Allocate/normalize all dirty receivers through the same closure engine as
   `close-validation`; computed fields see their new final self and checked peers.
5. Recheck **every** final node obligation, including clean nodes. A cache hit is
   never final approval. On failure no candidate snapshot is returned or installed.
   Retention preserves the original stamps: if a builder edits a clean source,
   the candidate refuses rather than silently re-stamping its old cached value.
6. After complete success, retire the previous graph-access capability and revoke
   old Reference Types for dirty/removed nodes. A clean Reference survives unrelated
   revisions; its own declared reachable stamps/final checks remain current.

`closed-evaluated` and `closed-reused` report construction decisions (reuse order
is unspecified). `revision-action recipes` is a FUN Reader-compatible action from
the current graph to the completely admitted next graph. Ordinary `close-validation`
still has its original all-node fresh-owner semantics. Revisions must start with
`revise-validation`; an ordinary closed graph is not silently upgraded.

A revision family shares ownership, but normalization/admission also checks the
exact Reference Type selected for each name **in this attempt**. Reusing an old
dirty descriptor cannot smuggle old canonical edges into the new graph. Revocation
cells follow retained References across several rounds, so later replacement also
rejects capabilities originating before an intervening clean round.

`examples/recursive-revision.ss` combines a shared checked Function provider, two
mutually recursive services, computed peer-method captures, a computed report and
an independent node. A watched provider edit rebuilds four nodes (report 13→23),
while a peer replacement rebuilds its SCC/report and retains provider/idle. Its
FUN action composes root `refine` with existing exact `bind-evidence` publication.
Controls include current/stale subject/context, failure/retry, removed targets,
source/descriptor edits, old-Type injection, and a reentrant competing commit.

The commit guard rejects an old snapshot already retired by a reentrant callback.
This is a **sequential in-process protocol**, not thread synchronization. Complete
read declarations, immutable untracked metadata, terminating callbacks, and no
concurrent mutation are premises. External callback effects are not rolled back;
if a callback edits an old source, failure cannot restore that mutation. Arbitrary
previously retained Functions are not globally revoked. Graph revision completes
before a separately requested FUN effect publication, with no cross-effect atomicity
claim. Scoped checks revalidate reachable nodes, not unrelated global obligations;
whole-graph obligations belong in the publication envelope and its dependency set.

`Functional.RecursiveRevision` reuses `StrongComponents.Checked` reachability and
`RecursiveValidation.close`: clean consumers cannot reach dirty dependencies,
shared inputs invalidate all readers, clean construction is skipped, dirty
construction uses its actual callback, node generations are monotone, old target
references refuse (including across intervening clean rounds), every successful
reclosure passes all final obligations, failure retains pure prior state, and
current canonical-root evidence is exact. `Examples/RecursiveRevisions.lean`
executes both invalidation cones, checked Function refusal, current refinement,
old-reference/context refusal and retry. The proofs concern a finite consistently
indexed catalog with supplied source/dependency/host-identity correspondence;
Scheme membership edits are tested controls, not a proof of arbitrary index
relowering. No Scheme runtime/compiler, GC or performance theorem is asserted.

## Multi-round membership and dependency migration

`reconfigure-validation current added removed replacements` checks one complete
catalog edit before calling `revise-validation`; `reconfiguration-action` supplies
the same operation as a FUN Reader action. Added/replacement entries are ordinary
`validation-node` recipes; removals are names. Survivors preserve recipe identity
and order, and additions are appended. All write names must be distinct: additions
must be new, removals must exist, replacements must survive. Removing/readding
one name in a single batch refuses; resubmission after a later round is supported.
The final nonempty/size/dependency checks run before any builder. This is catalog
membership publication, not a cross-effect or concurrent transaction.

`examples/recursive-migration.ss` exposes reusable provider, peer and summary recipe
constructors, plus stable report/meter/idle recipes. The matching Lean and Scheme
workflow is:

| Round | Edit | Construction decision | Report |
| --- | --- | --- | --- |
| 0 | Start provider a, cyclic peers, left summary, report and idle | Close all | 19 |
| 1 | Add b; migrate both shared links; summary chooses right | Rebuild peers/summary/report/b; retain a/idle | 35 |
| 2 | Remove unread a; add downstream meter | Build meter only, despite shifted directory positions | 35 |
| 3 | Remove b; re-add the exact original a recipe; migrate back | Rebuild readers/a/meter; retain idle | 19 |
| 4 | Change left weight and summary; late refusal, then retry | Failed candidate leaves current graph; retry retains a/idle | 27 |
| 5 | Switch only computed summary reader | Rebuild summary/report/meter; retain provider/peer SCC/idle | 33 |

Old a references never become valid again after resubmitting that same name and
recipe. A separate equal-output control switches summary from left to right when
both return 6: summary/report still rebuild, old summary references refuse, and
peer receivers remain shared. Root refinement checks the actual chosen reader,
shared aliases and checked method capture; existing FUN publication binds exact
current subject/descriptor/context and rejects stale-context evidence.

`Functional.RecursiveMigration` extends the earlier fixed-index proof with checked
**named** catalogs. Ordered lowering preserves repeated reference aliases; names
resolve to actual current rows, and injectivity prevents accidental row merging.
Clean named identities survive index shifts. A logical per-name generation ledger
retains tombstones across removal/readdition, proving cross-gap refusal. Gerbil
implements this boundary with fresh canonical/Type identities and permanently
revoked old capabilities; it does not serialize Lean numeric generations.

Named body/new-node/footprint seeds feed the existing positive Boolean least fixed
point. Its equations, leastness, finite height bound and reader/clean-dependency
laws cover shared nodes and SCCs. Removing edges starts from the least solution,
without keeping unsupported old dirty bits. Named reclosure refuses dangling
lowering before callbacks, never reuses an outside-support fallback for additions,
and composes every final obligation with exact bound-root evidence.

These are finite explicit-dependency constructions advancing generalized MOP future
work. Mathematical named/index lowering is now proved; correspondence to actual
Scheme object identity, complete callback reads, immutable metadata, custom Type
laws and sequential mutation remains required. Positive invalidation equations do
not solve arbitrary eager computed getters. Graph commit and FUN effect admission
remain separate boundaries; no cross-effect rollback, arbitrary retained-Function
revocation, concurrent isolation or runtime/compiler/GC certification is claimed.

## Interleaved SCC merges and splits

`closed-reads graph name` returns a copied declared footprint after the normal
current-graph check. `recursive-topology.partition` adapts these reads to the
existing checked `strong-components.partition`; it never runs node builders,
normalizers, computed getters or computation evaluators. Analysis is on demand,
with freshness checked before/after. Ordinary reclosure performs no SCC discovery.
An ordinary `close-validation` graph cannot invent this metadata: it must originate
from the explicit revision-catalog protocol.

`recursive-topology.changed-members before after` compares immutable historical
partition receipts by membership sets, including added/removed keys. Reordering
rows or changing a representative alone does not report changed membership. A
receipt is structural information, not permission to reuse a cached node or skip
current approval. Obtaining a new receipt from a retired snapshot refuses.

`examples/recursive-topology.ss` reuses the provider/peer/summary/meter recipes,
Tuple reference normalization and FUN publication. Eight services form four pairs;
both pairs of SCCs merge simultaneously into quartets, split into different pairs,
and merge across the original quartet boundary. Shared dependencies migrate to a
new provider; the unused provider is removed. A late final refusal keeps the old
partitions/capabilities, and retry completes the crossed merge. Restoring the
original grouping never revives old References. A computed-only switch rebuilds
summary/report/meter; a later single-member body edit rebuilds only its pair and
downstream report/meter, retaining the other three SCCs, provider and computed
reader. Root refinement checks actual canonical peers/providers/reader and checked
Function captures before bound evidence. Totals are 82→108→128→132→127→134→135.

`Functional.RecursiveTopology` proves fourteen laws over a common finite name
embedding. A removed edge itself seeds its consumer, so every old path still
propagates invalidation: surviving edges propagate to an already dirty target,
and deleted edges dirty the consumer directly. Consequently both old split groups
and new merged groups are atomic with respect to current dirtiness. A clean node
has unchanged reads, preserves paths in both directions and retains exactly its
checked SCC membership. Every merge/split participant is therefore dirty using
body/footprint seeds alone. Existing positive least invalidation still supplies
minimality and finite closure; no extra partition pass is required for correctness.

`Examples/RecursiveTopologies.lean` executes matching rounds, exact checked SCC
receipts, refusal/retry, named epoch guards, refinement and stale subject/context
binding. Its common comparison universe reserves inactive provider vertices;
current membership guards hide them. It is not an allocation/cost model. Actual
support changes and index lowering use the preceding named-catalog laws. Complete
reads, immutable metadata, host source/identity correspondence, custom Type laws
and sequential mutation remain premises. These constructions advance generalized
MOP future work, without solving arbitrary eager computed fixed points, callback
termination, concurrent installation or atomic graph/effect publication.


## Deferred recursive revision requests

`recursive-staging.stage-reconfiguration` captures edit list spines, the exact
current graph and the versions of proposed recipe watches. It returns a FUN Reader
action. Staging runs no builders, normalizers, computed getters or admission
callbacks, and allocates no candidate graph. Graph identity and complete input
versions are checked before the action invokes existing `reconfigure-validation`.
A sibling commit invalidates all requests from the old snapshot even if every
node Reference remains valid. A proposed watched input can invalidate a request
without any intervening graph commit. Stage again from the actual current graph
and input versions; closure refusal leaves that graph and its References current.
The request can be retried after refusal only while its exact checkpoint remains
current; it grants no reservation or reusable approval of later states.

`examples/recursive-staging.ss` composes guarded revision, whole-value `refine` and
existing `bind-evidence` through `Observation.` bind. Tests interleave multiple
requests across seven actual graph states: simultaneous SCC merges/splits, shared
provider addition/removal/migration, crossed merge refusal/re-staging, restored
SCCs, computed-only edits and local-pair reclosure. Obsolete requests refuse across
all later rounds; dirty old References do not revive when groups return. Extra
controls cover proposed-watch drift before any builder, copied edit list spines,
and a no-rebuild commit that retains all nodes but still expires sibling requests.
The combined publication action returns the installed graph separately from effect
success/refusal. A later effect-policy refusal preserves the old effect context;
it does not undo the completed graph revision. Fresh evidence can then retry on
that installed graph.

Lean `Functional.RecursiveStaging` proves eight laws: revision/stamp refusal,
closure failure preservation, fresh re-staging success, exact revision advance,
all-refusal preservation, sibling invalidation and permanent old-round rejection.
`Examples/RecursiveStaging.lean` uses actual selective reclosure, epochs, checked
Functions, SCC inspection and the existing refinement/evidence models. A logical
monotone revision corresponds to exact Scheme graph identity, and logical stamps
to complete watched input versions; those correspondences are explicit premises.
This advances the original text's generalized-prototype future work. Complete
reads/watches, immutable metadata, trusted terminating callbacks and sequential
mutation remain required. No automatic read discovery, concurrent CAS, side-effect
rollback or atomic graph-plus-effect transaction is claimed.
