# Method fragments in the declaration protocol

## Prepared whole-form expansion

`batch-expander` and `batch-action` in `examples/declared-methods.ss` prepare one
FUN traversal of static and spliced declarations, then derive a family above the
existing shared C3 diamond. A form may contribute a complete before/primary/after
group. The current context supplies tenant, surcharge and final approval; only a
complete approved stream reaches construction, public reflection and combined
dispatch. A rejected context can be retried with the same action. Revising the
expander requires fresh preparation. Private fields remain unforced.

The expansion driver uses standard ordered mapping and right-fold collection.
It checks each fragment before the suffix, captures the original form bindings,
and preserves deferred copying of returned chunks. Finalization also runs for
empty input. Callback side effects preceding refusal are retained. These controls
and the companion Lean traversal laws advance the article's future MOP work.

Racket's “Combining Method Fragments” specifies standard qualifier order; the
following “Generalized Prototype Combination” proposes fragments beyond records
as future work. This module advances that proposal by connecting existing native
declarations, Slot inheritance and method interpreters to `.defgeneric`. It does
not claim a literal Racket declaration API or completion of arbitrary carriers.

## One declaration stream

`method-declaration.ss` exports `MethodDeclaration.` and `method-fragment`.
`MethodDeclaration.` inherits `Declaration.`; both expansion and finalization
use inherited continuations. The normal `.declare` macro already supports the
new `method` form alongside record `public` / `private` forms.

```scheme
(.defgeneric (cost self units) slot: .cost combination: standard-combination)
(def service (.declare MethodDeclaration. (.o)
  (public label (.o (constant 'billing)))
  (method .cost (.o (contributions
    [(combination.primary (lambda (_ units) (* 10 units)))])))
  (method .cost (.o (contributions
    [(combination.after (lambda (units) (displayln units)))])))))
(cost service 2) ; returns 20, after prints 2
```

The `combination.` prefix above denotes the existing `method-combination.ss`.
Runtime/computed names use `(method-fragment name contributions [admit hidden?])`.
The metadata fields are `contributions`, optional `admit` (default standard
contribution admission) and optional `hidden` (default false). Slot descriptors
and method contributions remain ordinary extensible POO objects.

Finalization merges compatible same-name local method fragments in source order,
placing each name at its first local occurrence. Mixed record/method names,
ordinary duplicate records, unequal admission callbacks or visibility conflicts
refuse before a receiver is returned. Two distinct but extensionally equivalent
admission functions need a common callback identity to combine. Arbitrary custom
finalizers must still return valid distinct named Slot descriptors.

The generated Slot computation appends local contributions to its delayed parent
group. Existing C3 supplies most-specific owner order and includes shared ancestors
once; it is not a second graph traversal. Within each qualifier the source order
is retained. Both original fragment metadata and merged descriptors have registered
dependency edges. Editing supported `contributions`, `admit` or `hidden` fields
invalidates compiled groups/catalogs; revised local policy/visibility conflicts
raise again. New declaration membership requires fresh elaboration. Source lists
and contribution bodies follow existing immutable/pure compilation premises.

`RecursiveDeclaration.` can be mixed with `MethodDeclaration.`: safe recursive
roots expand first, then the same finalizer coalesces their method contributions.
Ordinary recursive record collisions still refuse. No special evaluator, memo
ownership rule or global registry is introduced by this bridge.

## Generic invocation

`.defgeneric` accepts `combination: combine`, where `combine` is a native function
`(contributions arguments) -> result`. Its slot resolves through ordinary `.ref`;
the complete argument list then goes to the supplied interpreter. `from: type`
resolves on `.type` and prepends the original instance exactly once. `slot:`,
`default:` and `compute-default:` keep their existing lookup meanings. A default
with a combiner supplies raw fragments, e.g. `default: []` for a simple sum.

The native adapters are:

- `standard-combination`: standard qualified contributions, error on no primary.
- `(simple-combination policy)`: existing simple item/around interpreter.
- `(forwarding-combination payload-type)`: existing forwarding interpreter, with
  current replacement payload admission through the given native Type.
- `(inner-combination terminal)`: procedure bodies, with the existing inner chain.
- `simula-combination`: existing Simula prefix/inner/suffix interpreter.

Each adapter admits its complete group before executing a body; selecting an
incompatible combination cannot silently discard qualifiers. Custom combiners
retain their own semantic obligations. This receiver-selected generic bridge
does not add argument-based multiple dispatch or automatic signature inference.

A zero-argument generic WITH a combiner calls the effective method; the historical
zero-argument property getter WITHOUT a combiner still returns its slot value.
Fixed and rest argument forwarding are covered. Optional/keyword formal grammar
is not expanded here. Hidden metadata is reflected under the existing trusted
raw-slot access boundary; `.defgeneric` does not add capability security.

Only an actual queried receiver/slot absence activates a generic default or an
empty inherited fragment group. Nested missing-slot errors propagate. Around may
skip its inner computation; primary failure suppresses after methods as before.
External effects are sequenced, never rolled back. The adapter caches neither
results nor approvals. Preparation/invocation performance tuning is deferred.

## Proof and executable controls

Lean `Object.MethodCombination.collectFragments_append/coalesce` proves exact
source-order preservation for every selected method name. `fragmentSpecification_append`
connects local fragment blocks to the existing inherited SlotSpec semantics;
`declaredGeneric_standard/fragments` connects assembly to generic invocation with
the same complete receiver and established qualifier interpreter.

`Examples/DeclaredMethods.lean` proves the two-branch service's full standard trace,
current receiver result, around omission, primary refusal and missing-primary
behavior. It assumes a supplied correct C3 owner order; existing C3 proofs handle
linearization separately. It does not prove Gerbil macro expansion or all custom
policy callbacks. Native `examples/declared-methods.ss` and
`t/method-declaration-test.ss` separately execute shared C3, descriptor invalidation,
actual `.defgeneric` syntax, recursive roots, every adapter, and negative admission.
No Lean checkout, serialized proof constant or compiler/runtime verification is
part of native execution. No benchmark data or performance claim accompanies
this functional integration.
