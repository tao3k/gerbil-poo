# Component support changes and SCC publication

This advances Appendix B generalized-prototype future work. The Racket lens
getter/setter/wrapper construction still supplies the complete component equation;
current graph support chooses which equations exist before SCC closure/admission.

## Final support revision

`generalized-graph.reconfigure source keys codes bases` stages final finite
support and dependent edits together. Final keys must be distinct symbols. It
reuses `revise` validation for duplicate writes, target membership and base option
shape. Surviving keys retain their exact code/base identities until edited. Keys
outside final support lose BOTH namespaces. A newly supported key inherits no
latent binding from outside old support; it needs an explicit definition to become
an available component. `#f` remains actual absence, including an explicit edit.

This is an erasing support change. The older `support` API remains a support view
that can retain latent bindings; `remove` retains the key while clearing a provider.
The new source API distinguishes these operations instead of changing historical
semantics. Old snapshots remain immutable; erasure governs new source/lookup.

The existing `feedback-graph-revision-action` composes support changes using FUN
bind on the same old publication. Only the FINAL source is partitioned. Dangling
reads fail complete SCC footprint validation before any builder or approval.
Existing whole-group closure, all residual checks, lens/source guards, cache
invalidation and current joint approval remain the publication chain. Newly added
or regrouped nodes build; current independent groups retain exact receipts and
skip their builders across changed group support. Removed groups disappear.
Any preparation/construction/admission refusal returns the exact old publication;
newly constructed speculative groups never become retry caches.

## Scenario and controls

`examples/component-membership.ss` reuses the existing twelve-position lens
universe, `service-revisions` Computation recipes and complete component builder.
Initially E/F are unsupported, with SCCs `(shared a b)` and `(c d)`. Insertion of
two bridge components plus rewiring merges `(shared a b c d e f)` and moves shared
from quota to spare. Monitor keeps its own code but must reconstruct. Independent
inputs/stable loop skip builders. Removing E/F while restoring surviving reads
splits the SCC again. A quota edit may participate in that same removal batch.
Joint approval checks current component presence, all active endpoint commitments,
monitor and final settlement. A half deployment cannot approve.

Tests cover exact groups and actual constructed values, identity-preserving skip,
shared downstream invalidation, dangling deletion failing before builders,
code/base erasure, re-addition requiring fresh definitions, no latent resurrection,
refused insertion/retry, deletion of an SCC representative and a surviving member
receiving a new cache key, isolated input insertion, invalid final support/targets,
partial deployment and approval-only revocation after complete reuse.

## Lean mapping and proven scope

`Functional.GeneralizedGraph.SupportRevision` restricts old bindings to the
intersection of old/final support, then reuses typed `Revision`. Proofs establish
final keys, removal erasing BOTH code/base and resolver results, fresh defaults
independent of unsupported old bindings, and exact resolver equality for unedited
survivors. Existing typed batch write laws apply to its edits.

`Functional.StrongComponents.Supported` separates active support from a fixed
finite key/lens universe. It validates ALL declared active edges before masking;
no dangling edge is silently dropped. Proved lifting/forgetting of paths identifies
accepted active groups exactly with SCCs of the ORIGINAL declared graph. Inactive
nodes have no group, rather than an isolated singleton. Support-aware revision
seeds therefore invalidate even isolated new components that full-universe SCC
membership would miss. Active readers propagate dirtiness; deleted slots are not
materialized. Existing group equations, conditional cache reference equality and
current final-approval theorems remain separate obligations.

`Examples/ComponentMembership` discovers compact/expanded supports, executes the
same actual lens closure and every residual, and checks insertion/removal dirty
sets, isolated insertion, dangling refusal, source erasure, explicit re-addition
and current admission. Its representative order is dependency-first for these
fixtures; Scheme uses the existing checked condensation scheduler. Vector lens
laws are universal; concrete runs/physical skipping remain operational evidence.

Proofs concern accepted finite source/graph certificates and declared dependencies,
with pure locally total callbacks, lawful immutable lenses and faithful builders.
The example's key/lens universe is explicit; adding a key outside a builder's lens
family requires another suitable builder. No automatic lens discovery or unlimited
universe evolution theorem is claimed. There is no new arbitrary convergence,
least-fixed-point, cycle-interior rebuilding or performance result. Raw budgets
exclude partition analysis, residual checks, cooking and approval. Native Scheme
requires no Lean checkout, serialized proof, versioned JSON or committed run data.

The companion Lean reference checker materializes its finite relation once in
immutable vectors, with exact lookup correspondence to the original search. This
lets the expanded scenario pass the same 30-second check bound; the initial
unshared run remains a timeout diagnostic. Scheme already shares visited
reachability sets, and no Scheme performance claim follows from this model change.

See [component-migration.md](component-migration.md) for checked multi-service
contributions that replace endpoints in several SCCs and migrate shared inputs
within one final-source publication.
