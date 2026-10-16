# Selective reconstruction of feedback groups

This advances generalized-prototype **future work**. Racket's `$lens-gen` raw/
cooked construction closes each feedback group through existing component lenses.
Existing `ConstructionCache` handles the acyclic dependency graph BETWEEN those
groups; this module does not introduce a second scheduler or fixed-point evaluator.

## Unit of reconstruction

A mutually dependent component group is atomic. `close-feedback-group prepared
base seed budget checks: []` executes existing bounded feedback closure and every
component equation before returning a private group containing its exact prepared
owner, closed receipt and law checks. Dirty groups are rebuilt in full. There is
no per-node skipping inside a feedback cycle. This explicit-group API requires
callers to merge inter-group cycles into one wider raw closure; the companion
[automatic SCC adapter](strong-components.md) now performs that grouping from
declared node reads before invoking the existing DAG scheduler.

Group constructors can be ordinary `dependency-analysis.ss` `need`/`both`/`map`
computations. Inputs and dependency footprints remain explicit and inspectable.
Shared input edits invalidate ALL transitive readers. A code-body edit invalidates
that group and its downstream groups. Independent nodes retain exact cached group
objects and never invoke their builders, closure search or cooking.

As in the existing construction cache, graph/code metadata and captured inputs
must be immutable/extensional; edit them with persistent `graph.set-base`,
`graph.define`, `graph.remove` and support operations. Object identity authorizes
native reuse only under these premises. Undeclared mutable callback dependencies
and in-place graph/code mutation are not automatically discovered or certified.

## Publication and source admission

`feedback-cache-ref cache key` requires an actual successful feedback-group value.
Missing, error or non-group outcomes refuse. `feedback-cache-action source keys
admit guards: [] builder: default` is an existing FUN Reader from old cache (or
`#f`) to the candidate cache. It uses `ConstructionCache.start/refresh`, checks
EVERY explicit required group key, then guards both retained and rebuilt group
sources through joint approval. Required keys are explicit; optional non-group
graph inputs remain ordinary values.

A stale retained preparation refuses before application approval. To rebuild it,
explicitly revise the corresponding graph code/input. A cache hit does not renew
source validity. All candidate groups must be valid under the same final source
admission. This is source-version admission, not re-executing clean group equations.

Optional `guards` are existing captured lens-check descriptors used here to hold
approval dependency versions for the whole operation; they do not apply lens
domain tests to a cache object. Actual component lens controls execute during
`close-feedback-group`. Refresh guards after supported approval metadata edits.

`admit(old,candidate)` always observes the exact final cache and must return literal
`#t`, even if EVERY slot was reused. `publish-feedback-cache` returns `(candidate,
#f)` on success or `(exact-old, original-exception)` on any construction, required
group, source or approval refusal. Failed candidates are not promoted for later
reuse. An arbitrary external callback effect cannot be rolled back. Approval gates
new publication; old cooked snapshots are not globally revoked.

## Complex native and Lean examples

`examples/cached-feedback.ss` uses one quota node, two capped feedback groups with
a shared quota dependency, a further left→right dependency and one independent
feedback group. Each group reuses the existing three-service ring and method
combination; `CappedFeedback.lean` extracts that same construction for Lean reuse.
The independent group stays at quota2. At shared quota3, units2 charges36/48/24 and
allocation commitment totals27. Changing quota to4 reconstructs quota/left/right,
retains stable, and gives48/60/24 with commitment33. A joint limit27 refuses this
closed candidate; raising the limit permits a fresh retry from the old cache.
Decreasing shared quota also reconstructs both readers and preserves stable.

Tests use builders that REFUSE independent nodes, proving the source path really
skips those builders, plus native `eq?` on retained group objects. A left-body edit
invalidates right while quota/stable are reused. Approval-only edits skip ALL
builders but still enforce current permission. Removed inputs, inter-group cycles,
retained stale metadata, explicit stale-group rebuild, approval-source writes,
non-Boolean approval and Reader suffix suppression are negative controls.

Lean `Functional.FeedbackCache.Group` packages actual bounded closure and all
component residuals for an input-indexed family. `retained_slot` reuses the existing
ranked unaffected proof: actual resolver equality and declared dependency
invalidation are required, not equal samples. `shared_invalidates` proves both
readers invalidate. Existing `Partial.step_reused_builder_independent` proves a
retained slot cannot depend on ANY builder implementation. `admitCache_approved`
ensures the exact returned cache satisfies current approval. Group raw bounds
reuse the original feedback theorem. `Examples/CachedFeedback.lean` executes the
real selective materializer with a refusing builder, compares observations with
a full fresh reconstruction, and tests joint rejection/current permission.

These proofs assume pure typed inputs and the existing graph locality/correct
builder/reuse hypotheses. Native shape/source guards and physical identity checks
are separate executable evidence, not Scheme runtime/compiler verification.
Standard `propext`/`Quot.sound` occur; no new axioms or serialized witnesses exist.
Native code needs no Lean checkout. Source-level builder skipping is not a
measured wall-time, allocation or GC improvement. Scheduling, guard and approval
costs remain; dirty group budgets count raw transitions plus separate residual
and lens work. Hidden callback dependency discovery, selective cycle-interior
reconstruction and general convergence/leastness remain open. Functionality comes
before performance tuning.

Automatic member grouping and topology revision now compose through
[strong-components.md](strong-components.md); the existing explicit group API
remains useful when the caller already supplies certified atomic boundaries.
