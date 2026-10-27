# Collection composition audit

Audit date: 2026-10-26. This review follows the existing collection call chain
from source construction to backend methods, derived views and style publication.
The original findings below record the pre-repair behavior. Constructor delegation
has since been repaired as described in the acceptance section; repeated
recognition remains a separate, measured optimization question.

## Source and implementation identities

| Basis | Identity and role |
| --- | --- |
| Original paper | `metareflection/poof`, commit `9affa8fbbb4f12cbd98cb97f8b8b84474fc39429`, `poof.scrbl`: *Prototypes: Object-Orientation, Functionally*, Scheme Workshop 2021 |
| Original source hash | SHA-256 `ede30f1d6c5d0809aae1dcd8556b32e5ef913e5c48d2fd0c40acb2e2ad03ba17` |
| Supplementary author code | Same source commit, `pommette/pommette.scm`; SHA-256 `979f11341235cf0e1bbe290ae50e417aa29572fd22b153810706d6ea46590083` |
| Gerbil implementation | `tao3k/gerbil-poo`, `3793685c8475a0672f40e9e39b8b9bb617c453a5` |
| Lean correspondence inspected | `tao3k/lean-poo`, `e229504ef2219463a237812335bb545b1f8419b9` |

The current main checkout's `.cache` is empty. The clean, pinned source checkout
used here is `.data/poof`; it matches the committed audit receipt. No additional
copy or download was created. Supplementary author code and the separate
[collection-library proposal](https://github.com/fare/projects/issues/10) are
labelled separately from requirements of the original paper.

## What the author's construction actually requires

1. Composition shares final `self` and supplies the parent's contribution as
   `super`: original `poof.scrbl` lines 488–491 and 563–564. A fold is sufficient
   for composing a finite prototype list; a second composition framework is not
   needed. Lean `Prototype/Compose.lean:28` has the corresponding typed equation.
2. Derived algorithms call existing extension points. The dictionary insertion
   in `poof.scrbl:744–773` calls `self.empty?`, `self.singleton`, `self.node`,
   `self.Key.compare` and `self.acons`. Supplementary `pommette.scm:732–817`
   illustrates adding balancing by overriding node construction instead of
   copying insertion and lookup.
3. Appendix B's `$lens-gen` (`poof.scrbl:2130–2133`) separates getter, setter and
   method wrapper while delaying inherited method access. Existing
   `generalized-prototype.ss:18–25` reuses this construction and the existing
   Lens protocol; Lean `Prototype/Lens.lean:15` and
   `Prototype/GeneralizedPrototype.lean:15` expose the corresponding ingredients.
4. The separate collection proposal asks for incremental definitions and useful
   style translations, and explicitly identifies opaque wrapping and large
   constant factors as problems. It is not a specification of the current delta,
   index or publication APIs, nor proof that every repeated check can be removed.

Keep the existing standard RBTree/Trie backends. Reimplementing the illustrative
AVL tree would duplicate a mature backend rather than improve this composition.

## P1: derived singleton construction substitutes the bulk constructor

The existing singleton boundary already distinguishes the operations:
`table/mapping.scm:11–21` selects `.singleton/key` for a singleton request and
`.<-list/key` for a bulk request. However:

- `table/sets.scm:188–196` implements Set singleton through `Table.<-list`.
- `table/order.scm` declares a bulk delegate but no singleton delegate.
- `table/indexes.scm` declares bulk primary construction plus index initialization,
  but no singleton delegate.
- `table.ss`'s `table-wrapper` declares bulk translation/construction but no
  singleton delegate.
- `table/styles.scm:532–534` correctly delegates its selected descriptor's
  singleton operation. Consequently all five Set presentations inherit the
  upstream substitution; another style wrapper would not repair it.

Two bounded executable witnesses use `RationalDict Unit` with independently
partial singleton/bulk capabilities. An accepted result always remains a valid
singleton; a rejected constructor raises its own sentinel error. Thus the
witness does not require an invalid carrier or an invalid successful backend.

| Declared source policy | Source Table singleton | Set singleton | Ordered singleton | Indexed singleton | Represented singleton |
| --- | --- | --- | --- | --- | --- |
| Singleton refuses; bulk accepts | `single denied` | accepts | accepts | accepts | accepts |
| Singleton accepts; bulk refuses | accepts | `bulk denied` | `bulk denied` | `bulk denied` | `bulk denied` |

A separate witness confirms that Pure, Mutable, Linear, Posh and Classy Set
factories all accept without invoking the refused singleton capability.
The ordered/indexed/represented results above used existing `table-order`,
`table-indexes` and `table-wrapper`; the boxed representation was the existing
`box-table` test fixture, not another implementation.

The core counterexample is reproducible in the normal built package environment:

```scheme
(import :clan/poo/object :clan/poo/mop :clan/poo/type
        :clan/poo/table :clan/poo/rationaldict :std/error)

;; Observe only this known refusal; unexpected exceptions must remain failures.
(let* ((refusal (list 'singleton-refused))
       (raw (RationalDict Unit))
       (backend (.cc raw .singleton/key: (lambda _ (raise refusal))))
       (sets (.cc Set<-Table. Table: backend)))
  (for-each
    (lambda (entry)
      (displayln (car entry) " "
        (with-catch
          (lambda (cause) (if (eq? cause refusal) 'refused (raise cause)))
          (lambda () ((cdr entry)) 'accepted))))
    (list
      (cons 'Table (lambda () (.call backend .singleton 3 (void))))
      (cons 'Set (lambda () (.call sets .singleton 3))))))
;; Actual: Table refused; Set accepted.
```

This is an operation-selection/refusal mismatch, not just an allocation concern.
Recognizing the completed root cannot recover a skipped constructor's refusal.
The previous broad singleton-capability closure claim is therefore incomplete.

### Lean scope and the missing connection

`SetAlgebra.lean:211–241` preserves input, construction and final-root failures
for an explicitly supplied `construct`. `TableCapture.lean:218–242` similarly
preserves the supplied backend's failure. These laws remain valid. They do not
establish which Scheme method was selected. Applying the theorem with the bulk
constructor does not prove preservation of the singleton constructor's refusal.

The next complete acceptance unit should therefore be **constructor delegation
through derived collections**, rather than another isolated application example:

- Preserve distinct empty, singleton and bulk requests through Set, order,
  representation and index derivation. Reuse existing capabilities and guards.
- Keep empty construction lazy and independently partial; do not turn singleton
  into an insertion into an eagerly constructed empty root.
- Retain key/value recognition, complete result refinement, source invalidation,
  Function identity, representation conversion and index initialization.
- Cover both refusal directions above, explicit successful overrides, nested
  views, all five styles and consumer suppression/retry through existing FUN/IO.
- Connect the selected operation to the existing finite constructor/refusal laws;
  add representation/index commutation premises explicitly instead of assuming
  that singleton and bulk have identical failure domains.

No new framework, namespace, general law inference or compatibility path is
needed to implement this unit. The repair below uses these existing boundaries.

## Measured structural cost: repeated recognition, not a proven safe deletion

A second bounded probe overrides only the backing `.element?` to count calls,
while preserving its Boolean result. Metadata/method discovery and owner creation
are completed before resetting each counter.

| Operation | Backing recognizer calls |
| --- | ---: |
| Table singleton | 1 |
| Set singleton | 3 |
| Singleton through each of the five Set styles | 5 |
| Set insertion through Pure / Posh | 8 |
| Set insertion through Mutable / Linear / Classy | 6 |

The relevant chain is `require-set` (`table/sets.scm:22–24`), the point-method
Wrapper boundary (`:59–80`), and style `admitted` / `step`
(`table/styles.scm:310–313`, `:413–425`). This identifies repeated recognizer
invocations, not a measured wall-time ratio or allocation/GC bound.

A custom Set refinement is independent of the backing Table predicate. Recognition
can also have observable effects or depend on declared state. Do not remove guards
or introduce an optimistic cache just because these counts are large. Any later
reuse must specify stable/pure admission evidence and retain the general path for
independent refinements. Correct constructor selection takes priority.

## Existing abstraction to retain

- `derive-table-styles` already has one ownership/publication engine. Posh and
  Classy add receiver presentation; the five styles do not need five algorithms.
- `fun.ss:49–53` already expresses Wrapper bind/map using the existing unwrap,
  transform and wrap operations. Point admission can remain at that boundary.
- `RationalDict` delegates storage, bulk construction, equality and iteration to
  the existing standard RBTree support. The paper's examples justify layering,
  not replacing this backend with another tree implementation.
- The Appendix B lens bridge is already present; introducing a second fragment
  evaluator would duplicate a construction that both implementations possess.

Automatic symmetry discovery, universal adapter-law inference, arbitrary
nonmonotone recursion and a richer general linear type system remain research
boundaries. This report does not relabel them as missing concrete paper APIs.

## Evidence limits

The witnesses ran against the qualified local Gerbil implementation above with
`-:max-heap=1G,debug=q` and a 30-second watchdog. They did not change the standard
148-module inventory, resource limits or test runner. Existing green CI and the
previous complete acceptance do not cover these newly demonstrated constructor
policies. The snippets are diagnostic witnesses. Convert them into passing regressions
together with the constructor repair before closing this acceptance target.
The review establishes neither whole-language nor implementation-platform correctness.


## Constructor delegation acceptance

Set's singleton is again the direct `Table.singleton` delegate inside its
existing shared Wrapper boundary. Its lazy empty operation uses the same boundary
and the source empty capability. Ordered, indexed and represented descriptors
supply singleton delegates under their existing guards; indexed construction
prepares the complete cache family only after source construction succeeds.
One-entry bulk requests still select bulk. No successful constructor is assumed
to imply that another constructor accepts the same request.

`t/table-construction-test.ss` exercises both independent refusal directions
through direct, ordered, indexed, boxed and nested views, all five Set styles,
invalid-key rejection, and exact Function-leaf retention. The
`singleton-ledger-action` example composes the selected capability with existing
Reader/FUN and IO, suppressing the consumer after refusal and accepting a fresh
retry. Existing final-refinement, stale-factory, index-conflict and ownership
regressions remain in the same complete suite.

Lean `Functional/TableCapture.lean` models explicit empty/singleton/bulk requests.
The finite laws preserve source, decoder and preparation errors across nested
translations and suppress final admission after constructor refusal. Concrete
service examples show singleton success despite refused empty/bulk policies,
one-entry bulk refusal and consumer suppression. Faithful host dispatch,
representation/index laws and external callback behavior remain premises;
these proofs do not validate the Scheme compiler, runtime or arbitrary effects.

The earlier witness table and recognition counts remain historical diagnostics,
not post-repair timing measurements. This correctness repair does not claim a
wall-clock speedup or authorize removing independent business refinements.

Local acceptance after the repair: the unchanged complete build succeeded;
`just _check-linked-collections 2 1 4` exited zero with 148 modules, 1,719
passing cases and no error markers. The single-process harness took 79.86 seconds;
the linked workload build took 11.04 seconds and every original study phase ran.
No timeout, heap cap or test inventory was reduced. Lean's complete gate passed
and commit `9524c38` passed all 17 CI checks. Remote Scheme CI is checked against
the resulting commit separately; these local timings are not a paired speedup claim.


## Direct Set observation admission and deferred invalidation

The next audited unit found a concrete inconsistency after constructor repair:
a plain `Set<-Table.` with a refusing whole-root predicate rejected `.list<-`,
but `.iter<-` still yielded its elements. RationalSet's direct
`rationaldict-keys` override bypassed even list admission. A cursor created from
a valid Set also continued pulling after an explicit Set policy was revised.
These witnesses used matching Elt/backing Key identities; they do not rely on
loosening the intentional `set-styles` descriptor-identity requirement.

`iterate-set` now admits the complete root before backend issuance and reuses
`iterator-map` with its existing guard argument. It captures Set, Elt, backing
and explicit policy versions; each pull checks those versions before backend
`next!`, including repeated EOF. No metadata protection is held while the caller
is suspended. Persistent snapshots require one full issuance admission, not a
full scan per element. RationalSet inherits the existing checked list method
instead of maintaining an unchecked public fast path. The backing RBTree and
standard Iterator implementation are unchanged.

The existing set-algebra suite covers complete refusal before backend issuance,
policy invalidation of pending/exhausted cursors, repeated current EOF, fresh
retry and boxed Function grants delivered through Reader/FUN/IO. The finite Lean
`issueSetCursor`/`pullSetElement` laws reuse the existing cursor model, proving
complete admission refusal, exact accepted enumeration and stale refusal with
zero backend pulls. These are conditional persistent-model laws, not host runtime
or compiler verification. General purity-based recognition reuse remains separate.

Local acceptance: the complete standard build and
`just _check-linked-collections 2 1 4` both exited zero with all 148 modules,
1,722 passing cases and no error markers. The single-process harness took
70.55 seconds; linked workload construction took 9.96 seconds and the original
paired-study stages completed. Limits and test inventory were retained. These
are acceptance timings, not a controlled claim of speedup. Lean's complete gate
passed for `ccc42e9`; the existing SetStyle pull/EOF model was reused rather than
duplicated. Remote CI is verified separately at the resulting PR heads.


## Ordered producer delivery discipline

A bounded witness after direct Set observation repair supplied a valid persistent
root and a producer-owned Pair `(1 . 10)`. Its lawful numeric comparer rewrote the
producer buffer while comparing against lower bound zero. The checked cursor
returned `(1 . 20)`: it filtered before capturing/recognizing the producer row.
The same ordering could hide invalid rows below the bound. The repair uses the
existing `require-table-entry` before bound comparison inside the original
coroutine. See [table-order.md](table-order.md#producer-row-capture-before-selection)
for the complete acceptance unit, explicit costs and finite Lean proof premises.
This extends the concrete checked cursor, not the paper's illustrative tree
algorithm, and introduces no new namespace or alternate backend.

Local acceptance for this unit: complete standard build and
`just _check-linked-collections 2 1 4` exited zero, with 148 modules, 1,725 passing
cases and no error markers. The single-process harness took 98.60 seconds;
linked workload construction took 15.31 seconds and every original paired-study
phase completed. No check or resource limit changed. These are acceptance
measurements, not a paired wall-clock improvement claim. Lean's complete gate
passed at `f9332dc`; remote CI is verified separately against the current heads.


## Representation callback capture

A separate post-repair witness found key translation rewriting a producer-owned
Pair before value extraction: source `(1 . 10)` became represented `(-1 . 20)`.
The ordered-source repair cannot protect a raw producer at the downstream Wrapper
boundary. Represented seek also copied its bound after carrier/inverse callbacks.
The repair shares one existing Wrapper entry translator across iteration, seek and
bulk construction, receiving both children before converters, and captures seek's
Option shell before carrier preparation. See
[the representation acceptance scope](table-representations.md#capture-across-representation-callbacks)
for examples, regressions, finite Lean correspondence and explicit premises.
This is a concrete composition repair, not automatic law or symmetry inference.

Local acceptance for representation callback capture: the complete standard build
and `just _check-linked-collections 2 1 4` exited zero with 148 modules, 1,728
passing cases and no error markers. The single-process harness took 113.06 seconds;
linked workload construction took 26.45 seconds and the existing paired-study
phases completed. No checks or resource limits changed. These are full acceptance
observations, not a controlled speedup claim. Lean's complete gate and all 17 CI
checks passed at `e885b86`; remote Scheme CI is checked against the resulting head.


## Complete default Table observation

After fixing Set observation and callback capture, a separate witness showed
RationalDict/Trie public list and iterator observations bypassing a refused
whole-root receiver, and direct cursor pulls ignoring a revised policy. The
repair separates existing backend traversal capabilities from the shared checked
public observation boundary, retaining original guards on derived views. See
[the complete observation scope](table-representations.md#complete-default-table-observation)
for the implementation, complex workflow, regressions, finite Lean model and
explicit backend/cost premises. This is a concrete missing protocol, not a
request for automatic predicate or optimization discovery.


The original local build evidence did not close this unit: cold qualification and library
attempts reached the unchanged 300-second deadline, including a four-worker
control. One hard termination also produced an EPERM cleanup refusal; the owned
group was subsequently verified absent. Later deadline failures completed standard
cleanup normally. No failure was treated as successful qualification. A Gambit
optimized-module-limit experiment was withdrawn after GCC reported expensive
optimizations disabled at the actual -O1 level. The build options and CI/default
worker selection remain unchanged. Existing complete CI is the next independent
acceptance gate; that original cold-build result remained open. The subsequent joint-graph
acceptance below records the repair with the original limits.


The first CI candidate exposed an overreach: eager receiver recognition on derived
cursors forced conversion before pull, duplicated backend starts and invalidated
the existing narrow-seek work bound. Those assertions were retained unchanged.
The derived-cursor eager checks were removed: these cursors deliberately operate
on admitted snapshots with guarded, lazy row conversion. Trie positioning now
uses the backend iterator capability under its original caller's admission;
backend instrumentation moved to that same capability. Default raw-table
iteration and eager materialization retain their new complete admission.
A deliberately mutating child-recognizer diagnostic now inspects `.list/key`
without replaying that recognizer, and additionally checks that public `.list<-`
refuses it. This is a scope correction, not weaker validation or relaxed bounds.

## Shared construction protection and carrier checks

The author implementation's `$lens-gen` composes the getter, wrapper and setter
rather than inventing another representation. The existing FUN `Wrapper.` remains
the conversion authority here. Repeated captured-revision guards now use the
existing `with-table-sources` boundary directly: instantiate every protected
participant, enter the same dynamic protection scope, compare the same watched
revision family, then call the operation. The change removes an extra guard thunk
from each affected factory; it neither skips instantiation nor caches admission.
Complex guards with additional comparer or origin checks retain their own logic.

The two carrier directions share one inverse-check kernel. Forward conversion,
output admission, backward conversion, left-inverse comparison and replay remain
ordered. Admission does not substitute a normalized carrier. Both inverse failures
retain their original phase and value; a failed callback retains its cause.
The wrapper regression observes callback order, early refusal, exact cause and a
fresh successful retry. Existing nested wrappers, indexes, styles, narrow seeks
and mutation controls remain part of the complete suite.

The finite Lean model proves admission failure, left-inverse refusal, stable
roundtrip identity, preparation failure, stale refusal and exact current-action
outcome. It does not prove arbitrary Scheme callback termination, dynamic-wind
continuations, compiler correctness, GC behavior or wall-clock improvement.

At this implementation stage, local cold acceptance remained open. With identical standard optimized settings,
the table translation unit decreased from 258,065 to 249,196 C lines (3.4%), with
the largest host procedure decreasing from 13,963 to 13,101 lines. An earlier
unoptimized diagnostic is excluded from this comparison. The unchanged 12-worker,
1 GiB, 300-second library stage still timed out; complete entry wall time was
323.56 seconds, followed by successful standard cleanup. A late compiler snapshot
showed 9.63 CPU seconds over 82 wall seconds, while sampling showed GCC range
analysis rather than GC or an import deadlock. These observations do not establish
a controlled speedup. Generated files and diagnostic samples remain outside Git.


The subsequent build-graph audit found repeated library machine-code compilation
across qualification and executable construction. A single Darwin `std/make` graph
now enables the released SDK's shared/static object reuse and removes the final
redundant construction phase. All eight test batches and the complete harness
remain. Final-source construction after standard clean passed in 270.91 seconds with the
original 300-second stages; 148 modules / 1,734 cases and the paired collection
study passed. See [joint graph acceptance](ci-checks.md#joint-darwin-object-construction)
for matched controls and scope. The earlier failed runs above remain negative
history; smaller generated code alone was not the completed fix.
The later SDK migration audit in that same document qualifies standard-clean
receipts: retained numbered dynamic bodies were not necessarily absent.

## Shared recursive Set admission

The next source audit distinguishes an intentional primitive from a real protocol
omission. Raw Table `.foldl`/`.foldr` are declared backend extension points, as in
the author's dictionary fold; requiring whole receiver recognition inside them
would reenter recognition and change their domain. They are not missing checked
Set observers. The concrete defect was instead in `require-set`: its refinement
could call a checked Set observer and repeat the same admission without Table's
existing active receiver/snapshot guard.

The existing guard now accepts the backing/refinement continuation. One change to
the shared Set admission boundary covers reads, construction, algebra, iterators
and five-style publication. No alternate traversal, namespace or ownership layer
is introduced. See [recursive Set admission](collections.md#recursive-set-admission)
for the bounded counterexample, composed Function-grant workflow, conditional Lean
laws, failure/retry semantics and charged costs. General termination remains a
research boundary, not a newly claimed implementation feature.

Final-source local acceptance: the standard complete build and all 14 Set
observation cases passed. `just _check-linked-collections 2 1 4` exited zero with
148 modules, 1,738 passing cases, no error markers and the existing paired-study
success marker. The single-process harness took 161.54 seconds; the complete
check/study entry took 182.99 seconds. These are acceptance observations, not a
controlled speedup claim. The original heap, deadlines, compiler batches and check
inventory were retained. Lean's complete 20-phase gate passed, and its resulting
PR head passed all 17 CI checks. Scheme remote CI is verified separately at the
resulting commit; the SDK migration limitation remains explicit in ci-checks.md.

## Independent Set element admission and normalization

The next complete unit is a real contract gap rather than a missing backend
primitive. Before this repair, an independent UInt8 Elt over a Rational dictionary
recognized a root containing 256, accepted it through bulk construction and a
membership lens, and returned false for an invalid empty membership request.
An independent Function Elt was never recursively cooked by backing validation.
The author's dictionary construction (`poof.scrbl`, lines 744-773) composes declared
operations over an existing backend; its raw fold remains a backend primitive.
This repair preserves that division instead of moving receiver admission into
raw folds or inventing another collection representation.

The shared Set boundary now enforces Elt, backing Key and custom refinement.
The existing recursive binding validator is factored into child normalization
and collision-aware reconstruction, reused by Map, Table and Set. Independent
Elt normalization uses the existing key registry and complete bulk constructor;
unchanged children require neither. Backing cooking precedes Elt cooking, and
final admission performs recognition only. Existing simple point methods,
FUN/IO publication, styles and raw backends remain in place.

Eight regressions cover original occurrences before alias coalescing, empty
queries, lenses/bounds, nested Function/Tuple wrappers, one complete constructor,
collision/refusal/retry, non-idempotent normalization order and approved exact
publication across five styles. The example shares the existing service approval
contract rather than adding another executor or evidence wrapper. Lean reuses
VariantValidation, Validation and the established SetStyle namespace for finite
member-admission, ordered normalization and failure/ownership laws. Backend
faithfulness and callback termination remain explicit premises; automatic subtype
admission for styles and arbitrary validator commutation remain design boundaries.

Design reflection: one complete admission boundary and one shared normalization
pipeline replace asymmetric checks. Independent contracts necessarily cost an
additional member pass; aligned Elt/Key descriptors skip the added normalization
and member scan. No new scheduler, namespace, compatibility layer or per-method
wrapper is introduced, and no wall-clock speedup is inferred from these laws.

Local acceptance for this unit: the unchanged complete build passed its eight
compiler batches and all 22 Set observation cases passed. The complete
`just _check-linked-collections 2 1 4` entry exited zero with 148 modules,
1,746 passing cases, no error markers, `OK` and `COLLECTION-PAIRED-OK`.
Its single-process harness took 132.82 seconds and the complete entry took
161.66 seconds. The original 1 GiB heap and all stage deadlines were retained.
The full Lean 20-phase gate passed with zero failures in 151.90 seconds.
These are local acceptance receipts, not controlled performance comparisons or
remote CI claims; the resulting PR heads are checked separately. Lossless test
and benchmark output stays outside the repository.
