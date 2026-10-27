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

## Coherent Set source capture

Two executable controls established the next omission. An old membership lens
still returned true after an independent Elt revision. A Set Table getter could
also replace the caller's origin-list cell before lens creation copied it; the
retained lens then ignored a revision of the originally declared policy. Equal
revision numbers on the replacement do not establish identity. This is a missing
source-ownership/invalidation boundary, not automatic dependency discovery.

The author's dictionary example delegates through declared operations
(`poof.scrbl`, lines 744-773); its inheritance discussion explains the importance
of propagating dependencies without repeated manual bookkeeping (lines 1144-1189).
The concrete collection protocol remains future work. The repair consolidates
existing source assembly into `with-set-sources`, using standard `using`, ordered
`map` capture and the established metadata protection. Lens, cursor, image,
combination and style construction consume the same captured family. Their
backend algorithms, point-method bodies, validation and ownership engines stay
in place. No namespace, compatibility layer or per-method wrapper is added.

Six regressions cover independent Elt/EOF invalidation, Table/Elt getter buffer
reuse across five retained families, original-policy protection during eager
callbacks and metadata preparation, malformed-declaration failure priority and
Function image publication with fresh retry/inverse installation in five styles.
The examples reuse existing service publication rather than add an executor or
a second delta language. The full suite also retains the existing Set-style
non-Unit refusal classification; the shared boundary accepts that entry's original
error directly rather than catching or replacing arbitrary callback failures.
Lean's SetStyle extends the existing capture/stamp/style
models with mandatory identity coverage, original-origin retention, unrelated
replacement stability, deduplication equivalence and refusal before continuations
or owner consumption. Dynamic-scope fidelity and supported host revision checks
remain premises; no claim extends to arbitrary callbacks, compiler/runtime/GC
verification or automatic inference of undeclared dependencies.

Design reflection: ownership belongs where a declaration is first read. Capturing
later in each consumer both duplicates assembly and permits borrowed-buffer reuse
to erase a dependency. One captured family replaces those repeated expressions;
recognition/normalization remain separate and all existing costs/checks remain.

Final-source local acceptance: the unchanged eight-batch build, existing Set
style suite and all 14 origin-suite cases passed. The complete
`just _check-linked-collections 2 1 4` entry exited zero with 148 modules,
1,752 passing cases, no error markers, `OK` and `COLLECTION-PAIRED-OK`.
The single-process harness took 45.96 seconds and the complete entry took
66.66 seconds. These are acceptance observations, not controlled speedup claims.
The original 1 GiB heap, compiler/runtime deadlines and complete check inventory
were retained. The full Lean 20-phase gate passed with zero failures in 106.89
seconds; remote CI is checked independently at each resulting PR head. Failed
intermediate controls are not counted as acceptance, and lossless output remains
outside Git.

## Boolean membership focus presentation

A complete five-style counterexample exposed a remaining declared-protocol gap:
present membership returned `void`, absent membership refused and writing true
refused in every derived Set style. Plain Set membership lenses already behaved
correctly. The derived presentation was inheriting the required Table field lens
rather than the Set Boolean interface. This is not a request to infer arbitrary
lenses or to change required Table focus semantics.

The author's generalized-prototype discussion (`poof.scrbl`, lines 2101-2133)
expresses focused computation using getter/setter lenses and their composition.
The collection implementation is future work. The repair follows that abstraction:
compose the existing optional Table focus with Unit presence using project
`Lens.compose` and Gerbil's Boolean contract. The existing custom `.modify` hook
therefore carries ownership capture through nested service composition. No second
transaction engine, callback scheduler, namespace or per-method validation layer
is added. Existing Table focus and generation guards are retained.

The service example `revise-focused-access` uses the existing Observation/FUN/IO
chain after one focused update. Six regressions exercise all five styles, false
keys, Boolean/no-op laws, refinement and exact-cause refusal, reentrant winners,
source/capability refusal, fresh retry and inverse deltas over checked Function
keys. Finite Lean models factor the Boolean operation through TableFocus and
prove the two-way Unit-presence representation, membership lens/frame laws,
linear retirement, retained failure and generation-winner preservation. Stable
leaves, lawful backends and faithful host ownership/invalidation remain premises.

Design reflection: this is a presentation isomorphism over an existing operation,
so it belongs at style focus derivation. Reimplementing a Boolean point updater
would duplicate admission and optimistic installation; generic get/set wrapping
would lose the atomic modifier. Composing the existing lenses keeps both semantics
and the original failure/ownership machinery visible. Construction and admission
costs remain charged; this correctness unit claims no measured speedup.

Final-source acceptance used standard `gerbil clean`/build after an edit-time
interface mismatch; no load-path or cache override was introduced. The complete
cold construction and all eight compiler batches passed with the original
resource limits (the shared/test-program stage took 177.28 seconds). All 22 Set
style cases passed, including six new membership-focus cases. The unchanged
`just _check-linked-collections 2 1 4` entry exited zero with 148 modules,
1,758 passing cases, no error markers, `OK` and `COLLECTION-PAIRED-OK`.
The harness took 149.12 seconds and the complete entry took 171.69 seconds.
These are local acceptance receipts, not controlled performance comparisons.
The full Lean 20-phase gate passed with zero failures in 177.41 seconds. Remote
checks are verified separately at the resulting PR heads; complete transcripts
and benchmark output remain outside Git.

## Owned multi-result root groups

The next concrete counterexample starts with a LAWFUL original two-part result.
Its recognizer recycles the producer's root-list cells without changing either
persistent root. Direct Set division validated the original first root, then
returned an unvalidated replacement stored into that list. A styled Table could
instead visit a replacement second part and publish a different grouping. The
input and original partition were correct; validation itself exposed a borrowed
container. This is a result-ownership gap, not a claim to repair unlawful backend
partition algorithms or mutable root contents.

The author's dictionary construction (`poof.scrbl`, lines 744-774) delegates
persistent root algorithms, while the generalized-prototype discussion (lines
2101-2133) distinguishes construction/focused representation and consumption.
The collection protocol remains future work. The repair follows that separation:
retain the existing root algorithms, capture their finite handle list with Gerbil
standard mechanisms, then run the unchanged complete checks and one installer.
One helper is shared by Set division and the common partition/split/division
style stage. It neither adds per-method validation wrappers nor clones nodes,
creates another backend/namespace, or normalizes admitted Function values.

Six integrated regressions cover direct Set output, all five Table/Set styles
and receiver paths, original admission order, exact late refusal and fresh retry,
reentrant winners and Function-bearing access division through FUN/IO. The service
example shares its division action between Table and Set, with reconstruction and
inverse recovery. Existing zero/one/two-part, refinement, indexed and source/owner
negative controls remain in the complete suite.

TableCapture proves root-group identity and original refusal through existing
ordered Validation and owned-spine capture. TableSelection reuses styleDivision
for all-or-nothing delivery and the original first-root installation. Examples
include recycled cells, a late refusal that cannot be repaired by cell replacement,
linear retry, opaque functions and a competing generation. Host capture fidelity,
recorded admission outcomes, persistent leaves and lawful backend decomposition
remain premises. Arbitrary callback purity/termination, concurrent raw writes and
compiler/runtime/GC behavior are outside these finite laws.

Design reflection: the defect belongs at the existing result boundary. Capturing
before admission replaces dependence on a mutable producer spine with an owned
finite group; it does not replay validation, clone roots or introduce another
transaction framework. Each crossed boundary charges its shallow pass explicitly;
no timing improvement is inferred from the semantic repair.

Final-source local acceptance: the standard complete build passed all eight
compiler batches, and all 39 decomposition-suite cases passed, including the
six new root-group controls. The unchanged
`just _check-linked-collections 2 1 4` entry exited zero with 148 modules,
1,764 passing cases, no error markers, `OK` and `COLLECTION-PAIRED-OK`.
The single-process harness took 57.03 seconds and the complete entry took
77.82 seconds. These are acceptance observations, not a controlled speedup claim.
The original 1 GiB heap, stage deadlines and complete check inventory remain.
Lean's full 20-phase gate passed with zero failures in 130.16 seconds; remote
results are verified separately at each resulting PR head. Intermediate fixture
failures are not accepted as closure, and lossless output remains outside Git.


### Owned encoder observations

Collection IO now resolves the existing encoder after root admission and before
backend enumeration, then captures the complete observed element spine (Set) or
binding spine and Pair shells (Table) before invoking any child codec. The
existing `capture-table-bindings` and Gerbil `map` supply this boundary; List,
Pair, JSON, byte and port codecs remain the implementation. No per-method style
wrappers or second serialization engine are introduced.

A faithful persistent-tree observation can be recycled by a key encoder without
changing the root: formerly `((1 . 10) (2 . 20))` could encode as `((1 99) (3 20))`,
and Set `(1 2)` as `(1 99)`. The captured observation now retains the original
rows across all five presentations. Present false elements and checked Function
handles remain intact. The FUN/IO service example composes encoding refusal and
retry with unique-index decoding, publication and inverse-delta recovery.

Admission, method-lookup priority and exact failure causes are preserved. A late
port failure retains its emitted prefix; external codec effects are not rolled
back. A retry enumerates and captures a fresh observation. Encoding consumes no
linear owner. Decoder and constructor policies are unchanged.

The finite Lean model reuses encodeCollection, marshalCollection and
captureOrigins to establish ordered delivery, admission/lookup refusal and
stability against later producer-buffer replacement, including opaque functions
and retained port prefixes. Faithful backend enumeration, stable payload leaves,
recorded child-codec outcomes and lawful codec output formats are premises. This
is shallow ownership of observation shells, not deep cloning, parser verification
or a proof of arbitrary callback termination. Set capture allocates one list cell
per element; Table capture also copies each binding Pair. Admission, enumeration,
metadata preparation and the existing child codecs remain charged; no wall-clock
speedup is claimed.

The author's Type Descriptors / I/O Validation and Beyond section motivates
sharing codec methods through descriptors. Ownership of these extended collection
observations advances that future-work protocol rather than claiming a missing
concrete paper algorithm. Gerbil rbtree->list already supplies fresh binding
shells; the regression deliberately recycles only those shells, not tree nodes.


## Final-state grouped bucket construction

Grouped indexes now share one cold/warm staging path. A valid nonempty primary
formerly failed when first-bucket insertion evaluated its forbidden business
`.empty`. Using checked singleton insertion would also wrongly admit/reject
intermediate one-row groups when only the final two-row cohort is valid.

Each grouped recipe prepares existing value-parametric key spaces for bucket
rows and touched groups. These scratch carriers need not equal the source
carrier. During revision, only touched old buckets are copied, all old memberships
are retracted before new memberships are inserted, and every final nonempty
bucket is constructed through source `.<-list` once. Empty groups remove their
cache entry without constructing an empty business value. Unique-index conflict
handling, complete cache admission, revision stamps and one final publication
remain the surrounding protocol. No scratch root escapes; unaffected bucket
objects and checked Function payloads retain identity.

Finite construction is an explicit grouped-bucket capability. Its original
failure is preserved even for a well-typed final group; unsupported empty or
singleton business constructors are not substitutes. A failed constructor or
whole-cache refinement publishes nothing and leaves every existing owner
available for explicit retry. Supported pure projections retain removal-before-
insertion order; arbitrary callback effects are not rolled back.

The existing cohort service example optionally forbids empty primary construction.
Regressions cover even final cohorts, cold construction, group deletion/merge and
inverse splitting, all five styles, FUN/IO suppression/retry, represented carriers,
exact constructor causes, duplicate rational memberships and unaffected buckets.
Lean TableIndex formalizes optional finite materialization, deletion without an
empty constructor, unchanged handles, final admission and original refusal. The
existing ordered heterogeneous cache staging establishes no partial family return;
existing index-view laws remain conditional on faithful backend staging/enumeration.

This advances the collection-library future work using the author's descriptor
and dictionary delegation design (`poof.scrbl` Type Descriptors and lines 744-773).
Raw backend folds remain extension points, not missing checked operations.
Value-parametric registries, lawful key equality, stable payloads, pure finite
projections and finite constructor laws are premises. No automatic algorithm
selection or proof of arbitrary host termination is claimed.

Cost boundary: projections remain restricted to changed primary keys during
revision, and untouched buckets require no reconstruction. Affected old buckets
are enumerated/copied and all final rows are delivered to the constructor;
registry preparation, validation, allocation and backend work remain charged.
This closes partial-constructor semantics, not a changed-key-only cost theorem
or a wall-clock speedup. Raw benchmark data and generated products remain outside Git.

The grouped seed captures the cache provider's Option shell once before scratch
constructor lookup. A getter may recycle that shell without changing the old
persistent bucket; the existing borrowing-table fixture verifies that members
remain the original ones. The finite seedIndexBucket law models that ownership
boundary under faithful capture, not arbitrary mutable-payload cloning.


## Captured projection retraction

The next concrete omission was cached-output eviction in table-projection. The
ledger's `.ref/opt` response stayed borrowed across `.remove`; a lawful provider
could recycle that Option without changing any persistent root or stored row
list. The update then forgot original target keys, retained obsolete outputs,
or rejected a valid two-owner swap. Six regressions failed against the original
implementation while all 1,776 existing cases passed.

The shared retraction boundary now uses the existing `map/option identity` before
any backend eviction. Initial projection admission already owns cached row lists
and Pair shells; they need no second copy or validation layer. Every original
output is released before new claims and delivered as an ordinary target deletion.
Single/multivalued projections, composed middle deltas and five-style publication
reuse this same code. Function leaves, false keys/values, unchanged entries,
original callback failures and explicit retries retain their existing semantics.

The reroute-service-action example captures one finite caller route list, retains
the existing checked service callback, captures one source point delta and delegates
exact target delivery to the existing Reader/FUN/IO publisher. Collisions and
whole-target refusal expose neither a successor cache nor an installed target;
IO after a successful commit retains its existing nonrollback semantics.

TableCapture's finite retireCachedRows model separates completed backend eviction
from the provider's later response buffer. Laws establish original ordered row
delivery, absence, buffer independence and original refusal. cachedRetractions
retains keys, present old values and exact row count; existing inverse installation
recovers a successfully deleted target view. CollectionStyles covers the prior
empty-buffer counterexample, two old routes, false values, opaque Functions and
backend refusal. Backend fidelity, stable cached rows, lawful installers and
registered/pure projection dependencies remain premises. These laws do not verify
heap copying, arbitrary callbacks or the Scheme compiler/runtime.

This advances the proposed collection library using the author's dictionary and
Type Descriptor delegation (`poof.scrbl`, lines 744-773 and 1409-1444); it does not
reinterpret raw backend folds as missing public validation. One present cached
entry requires one new Option shell; the existing list and Function objects are
shared. Retirement still visits every old output and all ordinary admission,
registry, construction, allocator and GC costs remain charged. No new wall-clock
speedup or automatic dependency discovery is claimed.


## Captured sparse translation expectations

A source audit found the same endpoint obligation in two existing protocols:
represented table installation retained a borrowed source `.ref/opt` response,
and sparse fold transport retained a borrowed target response, across replacement
conversion. A conversion doing an ordinary read-only query can recycle that
Option while all persistent roots and converted values remain unchanged. A
correct atomic installer then rejects the damaged expectation as a conflict.

The regression backend exposes borrowed reads but delegates the unchanged atomic
installer to its original backend. This distinction matters: if installation
rereads into the same shell, it can accidentally repair an already corrupted
expectation and hide the defect. Six regressions fail on the original installers
with conflict keys in their declared public/source coordinates; all 1,782 prior
cases remain passing.

Both existing read sites now capture the Option with `map/option identity` before
old-value admission or replacement conversion. Private prefix-overlay Options
already belong to emitted edits and are reused directly. No translator, delta
installer, validator or ownership engine is duplicated. Original stale refusal
priority, callback errors, final refinements and private pairing commit order
remain. Typed integer/false controls, repeated/cancelling batches, all five
represented styles, exact inverse recovery and checked Function identity are
covered. The capacity-ledger example accepts a higher-order refinement of its
existing value Wrapper, matching its source/target refinements; core endpoint
and encountered inverse checks still apply. FUN/IO refusal reaches no consumer,
and a successful retry preserves the aggregate and original callable handles.

TableCapture's captureTranslatedEdit models original admission before conversion,
records the later provider buffer separately and retains only captured old values.
Laws cover readiness, absence/presence, provider independence, exact check/convert
refusal and inverse installation. CollectionStyles includes the false-conflict
counterexample, ordered repeated edits, false and opaque Function values. Faithful
backend reads/installers, stable endpoint leaves and lawful registered inverse
maps remain premises. This advances collection-library future work using the
author's descriptor/dictionary delegation and explicit typeclass/class style
correspondence (poof.scrbl, lines 744-773 and 1433-1444); no compiler, heap or
arbitrary callback termination proof is claimed.

Cost boundary: only a first borrowed present endpoint read allocates an additional
Option shell. Repeated-key prefix values incur no extra copy, and old payloads
are never deep-cloned or rewrapped. Existing key ownership, conversion, recognition,
construction, allocator and GC costs remain charged. No full target scan, trial
point write, fold reinitialization or new wall-clock speedup is asserted.
