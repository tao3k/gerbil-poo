# Controlled component feedback closure

This advances the paper's generalized-prototype **future work**. Racket's
`$lens-gen` gives each wrapper the cooked final self and a delayed inherited raw
focus, then assembles fragments with the existing prototype composition. Feedback
here reuses that construction over ONE comparable wider raw state. It does not
turn arbitrary incremental method contributions into independent equations.

## Complete component equations

Each named fragment in a feedback preparation denotes a COMPLETE component.
Every component reads the same preceding whole self through the existing delayed
cooking boundary, even when raw updates are assembled in an ordered stream.
Components may contain their own method combination; callable consumption can
also be assembled in cooking, outside comparable raw data.

The existing generalized declaration expands/finalizes its whole source once.
`fragment-descriptors` inspects this admitted stream under its version guard;
feedback checks never re-elaborate singleton subsets with a different finalizer.
Supported descriptor/lens/source changes require fresh preparation.

For component i, let `compile_i` be the existing lens compiler, `get_i`/`put_i`
its captured lens, b the original whole base and r the proposed fixed raw state.
Feedback admission requires BOTH:

1. `step(prepared, r, b) = r` for the complete assembled program;
2. `compile_i(delay(cook(r)), delay(b)) = put_i(get_i(r), b)` for EVERY component.

The second equation normalizes unrelated fields using the same original base.
With put-get, applying `get_i` proves the produced focus equals the final focus.
Two overlapping +1/-1 contributions can cancel in the assembled program while
violating their separate equations. They refuse in feedback mode; intentional
incremental same-focus contributions still use the existing ordered protocol or
are grouped into one complete component. This is explicit conservative admission.

## Native API and failure discipline

`feedback-closure-action prepared base budget checks: []` is a native FUN Reader
from the original wider seed to an existing `closed-fragments` receipt. It reuses
`closure-action` and `Observation.` `.map`; there is no new knot evaluator.
It automatically checks each declared lens on visited whole states using the
base focus value, then extends final checks with actual base/final/produced values.
Optional existing `lens-check` descriptors add finite domains and dependencies.
These checks remain finite controls, not universal law certificates.

All declaration and supplied-check sources remain guarded through search,
staged cooking and component equation checking. Native raw/closure data must
remain immutable and callbacks pure; unregistered/concurrent dependencies and
raw mutation are outside the correspondence.

`publish-feedback old prepared base seed budget checks: []` returns
`(values receipt #f)` after all admission, otherwise `(values old failure)` with
the EXACT old publication and original error. Search failures keep existing
budget/lens/source `closure-failure` inspectors. Direct admission failures retain
their lens/host exception; `feedback-equation-failure-name` identifies the declared
component residual. Downstream FUN maps do not run after refusal.

The search budget counts whole raw transitions INCLUDING equality verification.
After search, residual validation executes one component compiler per descriptor,
plus finite lens checks. This additional work is explicit and outside that budget.
Existing search cooks its staged receipt before residual validation; validation
reuses that same cooked interface. A failed residual never publishes it, but
arbitrary callback effects are not rolled back. No callback-time, allocation or
GC bound, performance improvement or Scheme runtime proof is claimed.

## Complex ring and proofs

`examples/feedback-services.ss` and `Examples/FeedbackServices.lean` align a
three-service capped allocation ring A ← B ← C ← A, joint approval and shared
audit data. With cap=3, every allocation becomes 3 after three rounds, approval
becomes true after the fourth, and a fifth whole raw transition verifies stability.
Existing primary/around methods refuse consumption before approval, then charge
36 at units=2 and 54 at units=3. A fresh cap=4 revision charges 48 at units=2.

Lean proves all four custom lens laws, exact simultaneous step semantics, audit
preservation and convergence/bounded acceptance for cap=3 from EVERY typed
natural-allocation/Boolean seed. The generic model proves fixedness, every component
equation, original-seed provenance, later stability and search budget bounds.
`closeWithin_complete` proves conditional completeness after finite convergence;
`closeFeedback_complete` additionally requires all component equations. Standard
Lean logical axioms `propext`/`Quot.sound` occur in generic/list/arithmetic proofs;
there are no new axioms, `sorry`, serialized witnesses or native-decide admission.

Native controls separately cover alternate seeds, cap revision, nonlocal finalizer
reuse, cancellation, a Boolean oscillator, zero/insufficient budgets, false raw
values, stale sources, source writes during residual checking, lens/cooking refusal
and FUN suffix suppression. Native seed values corresponding to the Lean theorem
must have the stated typed immutable shape. No Lean checkout is required.

Remaining open: automatic convergence or leastness for arbitrary equations,
unrestricted function equality, higher-order/mutating recursive knots, automatic
dependency/law discovery and global callback termination. Exhaustion proves
neither divergence nor absence of a fixed point; this functionality precedes tuning.
