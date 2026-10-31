# Ordered decomposition

This is a finite, explicit extension of the proposed collection library's future
work. It completes the existing table/set `.split` operation across the five
collection styles; it does not infer order or discover a new tree algorithm.

## Protocol and laws

`(.call table .split pivot root)` returns **three values**: a left root, an
`Option Value` at the pivot, and a right root. The sides retain precisely the
original bindings whose declared comparison with the pivot is negative or
positive. Equal comparison must agree with key equality. Comparer totality,
transitivity, purity and persistent backend laws are caller obligations; the
existing comparer checks encountered signs and equality disagreements.

Use `table-order` and an explicit `table-comparer` for a backend that does not
declare `Comparer`. Trie already declares one. No host order is guessed for an
unordered descriptor, and invalid pivots are rejected even on an empty root.
A transported comparer controls visible order, including key-negating Wrappers.

Missing pivot is `#f`; stored false is `(some #f)`. Existing Function wrappers
remain exact admitted leaves. This operation does not normalize children or
attempt to serialize closures. Sets return a Boolean presence observation in
place of the optional Unit payload and retain their own root refinements.

## Atomic ownership and failure

Both sides are prepared from the original snapshot via the existing checked
optional-map protocol. Correlated unique/grouped indexes are reconstructed by
the existing final-state delta installer. Both results must pass complete root
recognition before either escapes. No intermediate remainder must satisfy a
custom refinement, but each final root must satisfy it; some refinements therefore
legitimately reject a split.

Style factories retain declared Comparer identity and dependencies even on raw
backends that omit them from `.sources`. Their union is deduplicated once at
factory construction; retained owners reject revisions, and fresh factories can
explicitly retry against the current declarations.

`table-styles` / `set-styles` lift the operation through their existing multi-result
stage. Pure/Posh retain the predecessor. Mutable/Classy retain its identity as the
left result and allocate a distinct right owner. Linear retires the predecessor
once and supplies two fresh live successors. Receiver calls use `receiver.split`.
The pivot is a non-owning snapshot observation, not a third update capability.

Comparator, metadata, carrier, index or final-root refusal returns no result and
preserves the original owner for explicit retry. A reentrant/competing successful
installation remains visible and rejects the stale outer attempt. Callback side
effects are not rolled back. Persistent leaves are assumed immutable; physical
exclusive ownership is not claimed.

`examples/service-collection.ss` provides `split-ledger-action`: Reader/FUN
prepares both linear successors and the pivot before IO. The regression suite
combines Function invocation, unique-index observations, inverse-delta recovery
and fresh retry with that same action.

## Costs and proof boundary

The reference split makes two checked mapping traversals, plus pivot lookup,
metadata protection and complete input/output recognition. The backend determines
node allocation, delta preparation, index updates, representation conversions and
any ordering/sorting costs. This is **not** a logarithmic split or an allocation
improvement claim. RationalDict now also supplies the existing `number-comparer` to the standard
RBTree bulk and point constructors. Subtraction was invalid there: a large
integer difference or a rational difference need not be a fixnum comparison
result. Bignum and fractional-key controls exercise both construction paths.
The invalid Trie recursion, which confused pivot and traversal
prefix, is removed in favor of the shared checked protocol.

`LeanPoo.Functional.OrderedDictionary` in `TableSelection.lean` proves exact stable
side filters, sign-region coverage and disjointness, late root refusal, preserved
pivot observation, unchanged owner on failure, linear retirement and consumed
input rejection. Backend lookup consistency and lawful comparison are separate
premises: the model's pivot observation is an already admitted lookup in the same
snapshot. `Examples/CollectionStyles.lean` checks opaque callback payloads, stored
false, a transported order and refusal/retry. These finite semantic laws do not
verify Gerbil compilation, locks, arbitrary callback termination, physical memory
ownership or GC behavior.

## Checked single-entry decomposition

The concrete `decons` item previously named only in `table.ss` is now implemented
through `methods.table`, `Set<-Table.`, all five styles and Gerbil receiver methods.
This advances the collection proposal's future work.

* `.decons/opt input` returns two values: `Option (Key . Value)` and the complete
  remainder; Set returns `Option Elt` and its remainder. Stored false is present.
* `.decons input` returns a required binding (or Set element) and remainder.
  Empty input raises the existing `option-ref` "no value" error before installation.
* Choice follows the declared backend `.choose/opt`; no numeric minimum, sort or
  comparison policy is invented. Faithful choice/traversal is a backend premise.
  The copied Option/pair shells retain admitted child and Function identities.
* Source admission precedes choice. A present choice becomes one ordinary removal
  delta with its exact expected old value. A missing/changed chosen binding raises
  the existing `table-conflict`. Complete remainder recognition and correlated
  index installation precede either returned value. Empty optional extraction
  returns the original admitted root and makes no backend write.

Styles reuse their existing single-root `step`, including snapshot capture,
receiver preparation and one generation comparison/installation. Pure/Posh keep
the predecessor, Mutable/Classy update their existing identity, Linear retires it
and returns a fresh owner. Successful optional-empty extraction follows the same
one-step policy, while required-empty failure leaves every owner usable. A
reentrant winner cannot be overwritten or expose a losing extracted observation.
Set refinements are admitted through the common Set boundary rather than wrapping
each low-level insertion/deletion again. Declared origin changes reject retained
factories before choosing. External callback effects and postcommit IO are not
rolled back; this is not a physical destructive pop or static linearity proof.

`decons-ledger-action` composes a local Linear owner with the existing Reader/FUN
observation and IO boundary. The service fixture retains one checked Function,
updates unique correlated indexes, and restores the source with the existing
inverse delta. Regressions cover both required/optional variants, all five styles,
empty/false, whole-root refusal/retry, inconsistent choices, reentrant publication,
metadata invalidation and caller-owned choice shells. The finite Lean laws in
`TableSelection.lean` prove traversal reconstruction, cardinality, absence,
selected-key removal/frame/inverse, admission ordering and stale-generation refusal.
Payload equality is not required for traversal preservation; guarded deltas use
their existing equality premise. Persistent carriers, immutable leaves and faithful
backend operations remain explicit premises.

Cost is backend choice plus one guarded deletion and complete admission/index
preparation. No `.diff`, full snapshot sort or new ownership engine is introduced.
This does not imply constant/logarithmic total cost for arbitrary backends or
whole-root refinements. Other `drop` APIs and automatic algorithm discovery are
separate items, not silently claimed complete.

## Finite traversal prefixes

`(.call table .take count root)` and `.drop` select the first `count` bindings
or their complement in the backend's existing `.filter` visitation order. Counts
are exact nonnegative integers, checked by Gerbil's standard `uint?` contract;
inexact numbers, fractions, negative values and nonnumbers refuse even on empty
input. Oversize counts clamp to the finite traversal. This does not infer a sort
order: an explicit representation's declared traversal determines its prefix.

A single counter predicate delegates to `.filter`. Consequently the existing
Trie structural selection, generic optimistic removals, correlated-index
maintenance and whole-root admission are reused. There is no repeated `decons`,
new snapshot diff or second traversal algorithm. Only complete results must satisfy
custom refinements: a four-entry even-sized family can drop two directly although
the intermediate three-entry root would refuse. Function leaves retain identity.
Set delegates through its existing common `build-set` boundary, keeping Unit private.
Set/style entry points authenticate their input before delegating; no common error
priority is asserted when both the count and the input/owner are invalid.

All five styles reuse the one-root installer; receiver methods are `take`/`drop`.
Mutable/Classy preserve identity, Pure/Posh preserve the predecessor, and Linear
retires it only on success. A successful no-op is still a normal style step.
Invalid counts, rejected final roots and stale metadata publish nothing of their
own; an intervening successful publication wins and the stale outer attempt refuses.
Callback effects and concurrent successful operations are not rolled back.

`drop-ledger-action` composes linear draining with the existing Reader/FUN/IO
observation. Regression controls include both persistent backends, transported
representation order, all ownership presentations, false Set elements, forbidden
intermediate roots, correlated indexes, exact Function identities, inverse deltas,
metadata revisions and reentrant publication. Raw snapshots remain retry inputs.

The counter logic needs constant auxiliary state, but `.filter` may visit the
**entire** source, even for count zero. Full recognition, backend deletion/index
work, preparation and allocation remain charged. No O(count) seek or physical
storage-reuse claim is made. Lean's `prefixBindings` proves take/drop correspondence,
exact reconstruction and cumulative-drop observations without payload equality;
`preparePrefix` proves negative-count, final-refusal and readiness laws. Existing
style installation laws supply consumption and stale-generation semantics. These
finite laws assume faithful persistent traversal and do not verify the compiler,
GC, effectful recognizers or elapsed time. Host noninteger rejection is a Gerbil
contract regression; the Lean count model covers signed integers only.

### Checked finite collection division

`.divide root` returns two optional nonempty parts; `.divide/list root` returns
the same zero, one or two parts as a list. Empty input returns no carriers.
A singleton returns the original admitted root, with no manufactured empty
remainder. Missing parts use false independently of the backend's empty-root
representation. The protocol requires no key order or comparator.

The shared table boundary admits the original root before invoking a backend.
Trie exposes its existing structural algorithm as `.divide/key`; public calls
now pass through ordinary complete admission. Other tables reuse the existing
partition in visitation order, selecting a ceiling-half prefix. Every complete
part must satisfy the same table refinement, be nonempty and strictly smaller
for a nontrivial input; part counts must sum to the original count. Invalid
structural progress and recognition failures return no part. Count fidelity,
disjointness and lookup-preserving reconstruction remain backend laws, rather
than being inferred from method names or counts alone.

Set division delegates that table boundary and checks its existing Set refinement.
All five styles and Posh/Classy receivers reuse the original multi-result staging
and one generation installation. For nonempty output, mutable/classy retains the
input identity as the first part; additional owners are fresh. Linear retires its
input once, including successful empty division with no successors. Pure/posh
retains the predecessor. Empty mutable division keeps the original empty head.
No part or new capability escapes until the whole request and owner installation
accepts. Refusal preserves the owner for explicit corrected-input retry; external
callback effects are not rolled back.

The service example composes checked Function ledgers with linear division and
Reader/FUN/IO consumption. Regressions cover RationalDict/Trie/boxed carriers,
empty/singleton/multirow inputs, reconstruction, correlated unique/shared indexes,
Function identity, every style/receiver, late branch refinement, corrected retry,
invalid backend progress, original exceptions and suppressed IO on refusal.
Lean's TableSelection reuses finite take/drop and branch admission: exact ordered
reconstruction, uniqueness, strictly smaller nonempty parts, unchanged output
observations, original refusal and zero-result ownership. Top-level service
examples include late second-part refusal and corrected retry.

Design reflection: the old first-element split and raw-empty assumptions were
replaced at the public boundary; no parallel tree algorithm, namespace or owner
installer was added. The existing stage now admits an empty result list with the
same commit rule. Structural backends retain their division strategy; only the
generic path promises ceiling-half sizes. Complete source/part admission, count
queries, partition/index preparation and style construction remain costs.
Strictly decreasing finite sizes justify explicit recursion under faithful backend
laws, not arbitrary callback termination, physical disjoint ownership, automatic
parallelism, compiler/GC correctness or wall-clock speedups. This advances the
proposed collection library's future work without declaring the project complete.

### Owned result groups before admission

The complete list of root handles is now captured before the first result
recognizer runs. The shared `capture-table-roots` boundary uses Gerbil `using`
and ordinary `map identity` to own only that finite outer spine. Set division
uses it before checking its Set refinement; the existing multi-result style
installer uses it before admitting and preparing any output capability. This
also covers the installer shared by partition and split. Backend algorithms,
root identities, contained Function wrappers and the single generation commit
remain unchanged.

A producer may reuse its returned list during a recognizer callback. Such writes
remain externally visible, but cannot replace an already captured first part or
a not-yet-checked later part. Initial lawful grouping therefore survives admission;
this does not infer disjointness or reconstruction for an incorrect backend.
Malformed outer lists refuse through the standard contract before result checks.
No successor escapes until every original captured part accepts and installation
succeeds. The first original refusal retains its cause; failed mutable/linear
preparation keeps the old capability, while a competing installed winner remains
visible and cannot be overwritten. Retrying explicitly obtains a new producer
result. Effects of recognizers and postcommit IO are not rolled back.

Six regressions exercise direct Set division, all five Table/Set styles and
receiver methods, exact original admission order, late refusal/retry, competing
installation and checked Function access. `divide-access-action` and
`divide-ledger-action` share one existing linear Reader/FUN/IO implementation.
The access example checks no IO on branch refusal, fresh successful delivery,
reconstruction and inverse deltas without recooking Function keys.

Finite TableCapture laws reuse original-spine capture and ordered Validation;
TableSelection connects them to the existing styleDivision installer. They prove
exact root/order/cardinality retention, original refusal, preserved capability
and original-first-root publication. The model parametrizes recorded admission
outcomes; it does not prove arbitrary callback purity or identical decisions
under hidden mutable state. Capturing n handles costs one finite spine pass and
n shallow positions per crossed ownership boundary; root recognition, capability
preparation and backend work remain separately charged. The division protocol's
zero/one/two bound survives capture. This is no byte-allocation, compiler/runtime,
GC, raw-concurrency or wall-clock performance proof. Root contents must remain
persistent opaque leaves, as in the existing collection protocol.
