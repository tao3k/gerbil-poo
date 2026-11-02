# Simultaneous service graph revisions

This advances the generalized-prototype future work of Appendix B. Racket's
`$lens-gen` still supplies the component getter/setter/wrapper semantics; the
additional protocol here stages graph edits, discovers final SCCs and publishes
their existing whole-equation closure under one joint approval.

## Reusable native chain

`generalized-graph.revise source codes bases` validates an immutable batch on
existing node support. Duplicate writes within either list and unsupported keys
are rejected before returning a new source. A node may have both a code and a
base edit. `#f` means explicit equation/input absence, rather than a skipped edit.
Only the two edit namespaces are changed; unedited code/base identities remain
available for the existing condensation/cache checks. Equation shape, declared
reads and resolver outcomes are checked by the subsequent existing graph/closure
path, not inferred by batch validation.

`feedback-graph-revision-action` uses native FUN bind: read the current published
source, apply a pure revision callback once, then run existing whole-graph closure
and admission with the SAME old publication. Supplied source guards span revision
preparation through admission. The publication wrapper retains exact old state on
preparation, partition, builder, closure, residual or approval failure. Intermediate
sources are never scheduled or published. Side effects outside supported guarded
source writes are not transactional and must not occur in these pure callbacks.

`component-closure.component-group-builder` factors the complete-equation builder
out of the earlier vector example. It accepts an explicit key/lens family, raw
base/seed, budget and optional cooking/self projection. Lens identities are
selected once. All equation-read lenses and extra projection sources are protected
by existing preparation guards. Each program's provider rejects undeclared reads,
including reads hidden inside its own SCC. Internal inputs use the SAME cooked
self; external inputs project actual closed predecessor receipts. Existing bounded
feedback search checks whole raw equality and EVERY component residual. Custom
cooking must provide a matching `self-ref`; identity cooking uses lens projection.
The base/seed and callbacks retain the usual immutable/pure/local-total premises.

## Complex scenario

`examples/service-revisions.ss` has twelve positions: primary/backup quota,
shared dependency, six service endpoints, unchanged monitor, joint settlement and
an independent feedback loop. Initially SCCs include `(shared a b)` and `(c d)`;
`e` and `f` are separate readers. One final batch splits the first group, moves
shared into `(shared c d)`, merges `(e f)`, and migrates its quota dependency from
primary to backup. It may change backup quota in that SAME batch. Shared keeps its
representative name, and the monitor's own source/resolver is unchanged, yet both
must reconstruct. Even equal-valued migrations invalidate these groups. Reverse
revision restores original grouping. The independent group physically retains its
exact receipt and a refusing builder confirms it was skipped.

Changing the obsolete primary quota afterwards rebuilds only that input. Changing
the new backup quota rebuilds the migrated groups and all readers. A partial edit
fails joint service consistency; the complete batch succeeds. One final candidate
is approved exactly once, and overcommit/refusal retains old publication. Retry
rebuilds all previously speculative work. Duplicate batches, unsupported targets,
mid-construction failure, preparation exceptions and guarded writes are negative
controls. Native test logs and complete benchmark data are not repository assets.

## Lean correspondence and proof scope

`Functional.GeneralizedGraph.Revision` carries typed dependent code/base edits.
Admission certifies distinct/supported targets and preserves exact submitted edits.
Application proves each actual write, explicit absence, unchanged node support
and resolver equality on unedited components. `StrongComponents` revision laws
prove dirty-union composition, unchanged-reader invalidation after shared-member
migration, simultaneous propagation from any number of changed groups, and the
new-graph no-seed condition for detached inputs. Existing cache equality/builder
skipping and current-approval theorems remain the corresponding reuse obligations.

`Prototype.Generalized.componentParts` compiles the same lens-based member family.
`componentGroup_equation` proves every selected component equation of any returned
group from its actual residual proofs. `Examples/ServiceRevisions` discovers both
finite graphs, runs actual closure/residual checks on all groups, exercises both
revision directions/equal-value migration/input changes, and compares the final
batch's ACTUAL graph resolvers with its constructed values. Its fixture visits
representatives in a dependency-first source order; native uses the checked DAG
scheduler. Universal vector lens laws and generic revision laws are proofs;
concrete runs and physical builder/receipt controls are separate evidence.

These are semantic/conditional reuse results, not verified extraction or a proof
of Scheme's runtime/compiler. Accepted finite graph certificates are exact; no
new universal discovery-acceptance/convergence/least-fixed-point theorem is claimed.
Raw search budgets exclude partition analysis, residual work, cooking and approval.
This increment completes these functional scenarios without claiming performance
improvements. The native package does not read a Lean checkout or serialized proof.

Erasing component insertion/deletion extends these batches through
[component-membership.md](component-membership.md), with support-aware SCC laws.
