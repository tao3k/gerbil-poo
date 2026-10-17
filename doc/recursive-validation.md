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
