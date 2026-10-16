# Controlled non-record closure and custom lens laws

This advances the generalized-prototype future work. Racket's raw/cooked split
and `$lens-gen` remain the construction principle; the new bounded search reuses
the existing generalized fragment program. It is not a new unrestricted knot or
proof of arbitrary Scheme callback termination.

## Actual raw closure

`generalized-closure.ss` exports `close-fragments`, `publish-closure`,
`closure-action`, closed receipt inspectors and failure inspectors.

```scheme
(def prepared (service.prepare-service))
(defvalues (closed failure)
  (close-fragments prepared service.base service.base 4 checks: (service.checks)))
(service.report closed 2) ; (10 13 15 96 audit), failure is #f
```

The example prefix denotes `examples/closed-declarations.ss`. Each iteration
checks admitted lens domains, performs one actual `step-fragments`, checks its
result, then compares FULL adjacent raw values with native `equal?`. Only equality
allows cooking and receipt creation. The receipt retains its prepared owner,
base, raw value, cooked interface and completed raw transition count. The final
equality verification counts as a transition. Zero budget executes no raw step.

There is no custom comparison callback or sampled-call admission. Fresh closures
in raw data may compare unequal even when extensionally equal; in that case a
budget failure is conservative. Neither termination nor divergence follows from
exhaustion. The budget bounds raw transition calls, not work inside locally
terminating callbacks, finite lens domain checks, allocation or host wall time.
Source failures report the count of completed transitions before refusal.

Success is `(values receipt #f)`; refusal is `(values #f failure)`. Failure kind
is `budget`, `lens` for an actual finite law counterexample, or `source` for
input/source/callback/cooking exceptions. `publish-closure` returns the EXACT old
publication on any refusal. It never publishes an exhausted raw prefix.
`closure-action` introduces the same operation as a native FUN Reader: a typed
refusal raises before bind/map selects downstream observation.

The prepared declaration sources and ALL lens-check sources stay guarded through
raw evaluation and final cooking. Stale lens checks refuse. This uses supported
sequential writes and version discipline; raw vector/list/struct mutation,
unregistered external dependencies and concurrent mutation remain outside it.
Callbacks/raw inputs/returned raw values must be immutable and pure for the
semantic correspondence. Already returned cooked interfaces remain snapshots;
there is no implicit global capability revocation or external-I/O rollback.

## Custom lens laws

`lens-laws.ss` provides:

- `check-lens-laws lens states values`: finite get-put, put-get and put-put checks.
- `lens-check lens values sources: [...]`: capture a nonempty value domain, the
  lens revision and explicit dependency revisions for repeated checks.
- `run-lens-check check states`: reject stale sources and check actual states.

The equations are `put(get(s),s)=s`, `get(put(a,s))=a`, and
`put(b,put(a,s))=put(b,s)`. Failed checks retain the precise law name.
An empty state domain in a direct check is vacuous; closure checks each actually
visited state. Checking selected values does not prove laws for other values or
for arbitrary callbacks. A provided absolute-value setter passes positive checks
but fails put-get on a negative value. There is no native universal proof seal.

Lens dependency sources must include mutable component lenses hidden in composed
callbacks and other external metadata. Lens callbacks must themselves be pure;
an in-place mutating setter is outside the immutable input premise, not validated
by pointer comparison. Runtime checks use the actual getter/setter interface;
shape admission and finite success cannot discover universal laws automatically.

Lean `Prototype.LensLaws` states all three laws universally for custom get/set
functions. Its composition theorem matches native `Lens.compose`, and the
`MonoLens.ofGetSet` bridge retains the view/no-op laws. Examples prove the nested
rate/fee/reserve laws for EVERY typed source/replacement, not sampled values.
Independent audit preservation still uses the explicit custom frame property.

## Non-record workflow and proof boundary

The complex example stores only comparable rate/fee/reserve data plus an audit
frame in nested vector raw state. Rate feeds fee, then reserve. The raw chain
settles after three advances; a fourth raw step verifies equality. Cooking binds
existing standard around/primary policy to current units/rate/fee/reserve. Raw
data and callable interface deliberately have different representations.
This is a concrete closure construction, not an optimization/equivalence claim
for the older representation's earlier finite observations.

Lean `Generalized.closeWithin` uses actual `DecidableEq Raw` and returns an existing
`Generalized.Closed` witness. It proves fixedness, budget bound, original-seed
unfolding provenance and stability of all later original-seed unfoldings.
`Examples/ClosedPrototypes.lean` proves the actual four-step result, callable
output, insufficient-budget refusal, universal seed-independent settled state,
custom lens laws and a lossy-lens counterexample.

Native tests separately execute actual vectors, source guards, old publication
retention, failure classification, function-sampling refusal and FUN composition.
The pure bounded core does not model opaque native callback exceptions or prove
native `equal?`, compiler/runtime correctness, arbitrary callback termination or
unrestricted function equality. Its first-order comparable example aligns with
native structural comparison under the explicit purity/immutability premises.
No new axioms, serialized Lean constants or Lean checkout runtime dependencies
are introduced. No performance study or benchmark data is published in this step.
