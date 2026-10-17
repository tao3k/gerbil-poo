# Focused recursive component closure

This advances the generalized-prototype **future work**. The original Racket
`$lens-gen` discussion permits narrowing a wider raw computation through a lens,
then cooking a consumable representation. This module composes existing local
closure with that wider computation; it does not add unrestricted recursive knots.

## Audit and implemented gaps

| Gap after single-component closure | Current construction | Remaining boundary |
| --- | --- | --- |
| Close a child and replace it in a larger carrier | `closure-focus`, `focus-closure-action` | Immutable/pure raw callbacks and explicit sources |
| Actual result absent from user lens samples | Old/new child values automatically join runtime law checks | Finite controls cannot establish universal laws |
| Two lawful lenses can overlap | Recheck EVERY equation on the final wider raw state | No inference of independence from names/paths |
| A later stage could edit an earlier/future source | Guard all preparations and lens dependencies before any stage, through cooking | Sequential supported source APIs only |
| Publish a partial component chain on later failure | Single final publication; exact old cooked value on any refusal | No rollback of external effects |
| Formal custom lens composition inside wider storage | Universal `LensIndependent`, paired lens laws, focused fixed/frame and validation laws | Frame/independence laws remain explicit premises |

## API and FUN composition

`closure-focus prepared check base budget checks: []` describes one stage.
`check` is an existing captured `lens-check` selecting the raw component from a
wider carrier. `base` is the immutable LOCAL base; the local seed is always the
actual view of the current wider seed. `checks` are existing local raw lens checks.
Mutable components hidden in composed callbacks require explicit `sources` when
constructing the captured check, exactly as for single-component closure.

`focus-closure-action stage` is an ordinary FUN Reader from wider raw to updated
wider raw. It checks the outer lens on actual old/new child values, calls existing
`close-fragments`, then persistently replaces the child. A refusal raises before
downstream Reader `.map`/`.bind` work. No custom I/O interpreter is introduced.

`focused-closures-action stages cook` composes ordered stage Readers with standard
`foldr` and the existing `Observation.` `.map`. All preparation and check sources
stay guarded for the complete operation, not merely their own stage. After the
last update it checks every outer/local lens domain and actual equation
`step(prepared, get(final), local-base) = get(final)`. Only then does it call the
whole-family `cook`. Conflicting overlapping foci refuse even when BOTH lenses
are individually lawful and BOTH local searches succeeded. Agreeing overlap is
allowed. An empty stage list simply cooks the original seed.
Final admission certifies every projected equation; it does not require a later
compatible overlap to retain an earlier stage's exact chosen fixed-point value.

`publish-focused-closures old stages seed cook` returns `(values cooked #f)` on
success, `(values old original-exception)` otherwise. The old publication is the
exact same object. Budget/source failures retain existing `closure-failure`
inspectors; lens failures retain `lens-law-failure-law`; final inconsistency and
cooking errors retain their original exception. No partial raw prefix escapes.

Local budgets count the same search transitions as `close-fragments`. Final
family admission adds ONE real raw step per stage; it is additional work, not
hidden inside the local budget. Neither bound limits callback time, equality or
law-checking work, allocation or host GC. No performance result is claimed.

## Complex example and proof scope

`examples/focused-services.ss` stores two recursively dependent services and one
shared tenant/audit frame in a wider vector. Each service has a three-component
rate → fee → reserve chain, closed using existing generalized declarations and
four raw steps including verification. Different rates (10,20) retain existing
standard primary/around method policy; complete-family cooking gives callable
charges 96/176 and total 272 at units=2. Later calls with units=3 give 116/216
and total 332. Sibling and audit storage survive persistent updates.
A paired service/scalar example also composes different child raw/cooked types
under the same wider vector, without a common representation tag.

Lean `Prototype.FocusedClosure` proves successful focused closure exposes its
actual local fixed equation under universal custom lens laws. Frame preservation
needs an explicit frame law. `closeFocused_reached` proves the chosen replacement
comes from the actual viewed seed's unfolding within its budget.
`LensIndependent` states both cross-view laws and
commuting writes; `LensLaws.pair` derives lawful paired replacement. Independent
later updates preserve earlier fixed equations. `validateFocused_sound` proves
final admission, including overlapping foci, certifies the actual projected
equation. `Examples/ClosedPrototypes.lean` proves the concrete family results,
custom outer lens laws/independence and conflicting-overlap refusal.

The native suite executes these paths plus actual-result counterexamples, stale
sources, source writes during later stages/final cooking, budget refusal, final
cooking failure and FUN suffix suppression. Native success is not a universal
law certificate or proof of the Scheme compiler/runtime. The module needs no
Lean checkout. Raw mutation, unregistered/concurrent dependencies and external
effects remain outside the pure correspondence. Arbitrary mutual feedback across
components, global convergence and unrestricted function equality remain open.
