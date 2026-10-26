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
