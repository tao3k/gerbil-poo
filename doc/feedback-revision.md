# Shared feedback and cross-service revision

This advances generalized-prototype **future work**. Racket's `$lens-gen`
raw/cooked split, component lenses and shared cooked final self remain the
construction. The new path composes existing controlled feedback closure with
current joint approval; it is not a general incremental solver or automatic cache.

## Functional gap and API

A shared source revision can invalidate several services in a feedback ring.
The old comparable raw value is useful as a seed, but neither its previous fixed
equation nor its previous approval certifies the revised publication. Mapping an
approval outside an existing Reader can also release source guards too early.

`feedback-revision-action prepared base budget admit checks: []` is a native FUN
Reader from an old `closed-fragments` receipt (or `#f` initially) to the NEW
receipt. Initial construction uses `base`; revision uses `closed-raw(old)` only
as a seed. Existing `feedback-closure-action` recomputes whole fixedness, every
component equation and finite lens controls under the revised preparation.
`admit(old,candidate)` then observes that EXACT completed candidate and must
return literal `#t`. False and non-Boolean results produce distinct
`feedback-approval-failure-kind` values, `refused` and `non-boolean`.

Preparation and supplied lens-check sources stay guarded through BOTH closure
and joint approval. Register approval dependencies in descriptor `sources`, the
declaration context, or explicit lens-check `sources`; closure cannot infer
arbitrary dependencies hidden in callbacks. Source changes require fresh
preparation and fresh checks. Supported writes during approval refuse before
mutation. Reader `.map`/`.bind` suffixes run only after success.

`publish-feedback-revision old prepared base budget admit checks: []` returns
`(values new-receipt #f)` on success; ANY closure, residual, source, callback or
approval failure returns `(values old original-exception)` with the EXACT same
old receipt. No candidate is stored in approval-refusal metadata. The helper
expects an already prepared source; the complex example's `revise` additionally
stages source preparation inside its refusal boundary so malformed new metadata
also retains the old family.

## Complex shared-dependency workflow

`examples/shared-feedback.ss` / `Examples/SharedFeedback.lean` align:

1. One shared quota node, computed from current policy metadata.
2. Two nested service pairs with cyclic edges A←B←C←D←A. Every allocation reads
   that same preceding quota node and global self.
3. Joint readiness after all four allocations agree with the shared quota.
4. Existing primary/around methods for both service branches, with factors 2/3.
5. Current permission, quota coherence and a total cross-service commitment limit.
6. Atomic revision from old raw, fresh approval and old-publication retention.

At quota3/limit12, cold closure takes six whole raw calls including verification;
units2 produces left24/right36/total60. Warm quota3→4 with limit16 closes in four
calls and produces32/48/80. Decreasing4→1 with limit4 also takes four and produces
8/12/20. Raising quota to4 while retaining limit12 closes but fails joint approval;
increasing the limit then succeeds from the retained old family. The original
audit and old cooked service snapshot remain usable. Example policy metadata
uses native standard-library `uint?` for the natural quota/limit domain.

Unchanged raw still gets a real raw equality check, every component residual and
current approval. There is NO approval reuse. Removing permission refuses even
when every allocation is unchanged. Old receipt data stays immutable; attempts
to mutate it or unregistered dependencies remain outside the correspondence.
Permission gates new publication; this protocol does not revoke previously
returned cooked snapshots or their callable methods.

## Proofs and native controls

Lean `Generalized.reviseFeedback` models pure raw-based Boolean joint approval
after actual revised feedback closure. Proofs establish the new component
equations, previous-seed unfolding provenance, raw-transition bound and approval
of the exact returned raw. The paired `admitted_joint` theorem proves ANY accepted
example revision has current permission, readiness, coherent quota and a total
commitment within the current joint limit. Universal custom lens laws derive
from reusable product laws and composition; explicit frame laws preserve audit.
Concrete cold/grow/shrink/refusal/warm-budget examples execute the actual model.

Native tests separately execute source revisions, stale preparation, no-op
reapproval, strict Boolean refusal, shared/check/approval-source write protection,
malformed metadata, approval exceptions, old snapshot retention and FUN suffix
suppression. The formal raw-predicate model does not prove arbitrary native
receipt-inspecting callbacks, runtime equality or Scheme compiler correctness.
Typed immutable carriers, pure local callbacks and registered sequential sources
remain premises. Standard Lean `propext`/`Quot.sound` occur in proofs; no new axioms,
serialized Lean constants or Lean checkout dependency are introduced.

Search counts whole raw transitions; existing residual checks and lens controls
add work beyond that count, and approval runs once per accepted search. No host
time/allocation/GC bound or speedup is claimed. External effects cannot roll back.
Generic convergence/leastness, selective cyclic recomputation, automatic
dependency/law discovery and arbitrary higher-order recursive knots remain open.
Functional closure here precedes performance tuning.
