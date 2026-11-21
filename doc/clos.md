# CLOS-like classes and methods

Application code imports CLOS operations, descriptors, declaration syntax and
prototype ancestry queries from `:clan/poo/mop`. Import ordinary value
types and type declaration and validation operations from `:clan/poo/type`.

```scheme
(import (only-in :clan/poo/mop prototype-instance?)
        (only-in :clan/poo/type Type. Fun Object Exactly Record))
```

`prototype-instance?` also accepts plain POO objects; it tests ancestry without
reading business Slots. The `clos/*` files are implementation factors, not
separate application entrypoints. Parsers, carrier guards, field validators and
publication helpers remain internal. Factor implementations import their lower
level dependencies directly rather than importing the MOP facade and creating
a dependency cycle. Internal factor tests may import the factor they exercise.

```scheme
(import :clan/poo/mop)

(.defgeneric render (value))
(.defmethod (render value) 'default)
(.defmethod (render (value (eql 'summary)))
  (list 'summary (call-next-method)))

(render 'summary)         ; => (summary default)
(.generic-object render)  ; the generic object for inspection or composition
```

Use `(value Class)`, `(value (prototype Prototype.))` or
`(value (eql expression))` to specialize an argument. Several required
arguments may be specialized in the same method. Use
`(qualifier before)` after the method head for a before method.
`.generic-object` uses the lexical generic binding and also accepts
`(setf name)`. To share a generic object across modules, bind and export
the result alongside the callable procedure.

The MOP also accepts receiver-slot declarations such as
`(.defgeneric (label widget) slot: .label)`. A generic with a separate
lambda list uses CLOS method selection and combination.

Gerbil's `:gerbil/runtime/c3` provides `c4-linearize*`. Both method systems
can dispatch on that prototype order. CLOS-like rank and depth queries
use it immediately. The Appendix B
prototype helper maps symbolic keys over a snapshot. Appendix B also accepts
caller-defined precedence.
[C4 query proof](https://github.com/tao3k/lean-poo/blob/41a1b58371cfa8b749457a0ad4e75ef17b4a4c33/LeanPoo/Object/ClosAdmission/PrototypePrecedence.lean#L45-L54).

| Stage | Appendix B | CLOS-like |
| --- | --- | --- |
| Applicability and order | Sparse symbolic paths and live predicate guards | Class, prototype and `eql` specializers with argument precedence and MOP hooks |
| Standard combination | Qualifier bodies and fixed-argument next thunks | Invocation frames, checked replacement arguments and CLOS missing-method hooks |

Appendix B forwarding can replace a payload while retaining the selected
methods. CLOS replacement arguments must preserve the applicable method
sequence.

Declare slot keywords with `initarg` in `.defclass`. The slots and methods
applicable to the current lifecycle operation determine which keywords it
accepts. The default initialization, reinitialization, and class-update
methods call the same `shared-initialize` generic. It receives all slots,
no slots, or only newly added slots as the mask for evaluating initforms.
Explicit initargs can fill their slots regardless of the mask. The
[pane example](../t/methods/duim-pane.ss) and its
[extension](../t/methods/duim-pane-test.ss) show a method bundle adding
initialization behavior from a separate module.
The [lifecycle model](https://github.com/tao3k/lean-poo/blob/994f314b2c02491ae6cdca17152e86c9ceeb2444/LeanPoo/Object/ClosLifecycle.lean)
checks operation-specific keyword admission, slot masks and method order.
[HyperSpec initialization](https://www.lispworks.com/documentation/HyperSpec/Body/07_.htm) ·
[Gerbil #1372](https://github.com/mighty-gerbils/gerbil/issues/1372)

Common slot readers accept direct declarations and effective class slots.
`clos-slot-defining-classes` and `clos-slot-storage-class` require effective
slots. List-valued readers return detached lists. The shared metadata follows
[SBCL's slot-definition hierarchy](https://github.com/sbcl/sbcl/blob/e7684366f8b450d3d94f47001f3bbcc7f7e947b2/src/pcl/defs.lisp#L376).

Function-name metadata owns `(setf name)` lists at construction and returns
detached names through reflection and read observation. Generic, binding, method
and slot accessor metadata use the existing POO Slot ownership policy.

Argument precedence is a finite permutation of the required positions. Creation
and reconfiguration share admission; a rejected order leaves the current generic
generation and its read evidence intact.

Lifecycle classes implement the existing POO `Type` and `Class` contracts.
Slot declarations accept existing POO Type objects directly. A single declaration
retains that object; inherited declarations use the common `And` Type in C4
precedence order. Slot validation runs each Type normalizer and checks the final
intersection. An omitted type adds no value-type restriction and does not
synthesize `Any`. All inherited constraints remain conjunctive; an untyped
override cannot erase them. Pure models use the same Slot checker. `(type integer?)` and `type-predicate:` are not accepted;
use an existing Type or define one through the ordinary `define-type` API.

`(And A B)` from `:clan/poo/type` applies Type validators in declaration order,
then checks every Type against the final value. It preserves original errors
and rechecks native read evidence after callbacks. `(And A)` returns `A` itself.
Direct declarations, schema maps and generation projections are read-only.
Registering subclasses retains the same prototype and C4 index; redefinition
publishes them through the existing generation and dependency index.

```scheme
(import (only-in :clan/poo/number Integer))
(.defclass Pane () ((width (initarg width:) (initform 80) (type Integer))))
(def pane (clos-make-instance Pane width: 100))
(element? Class Pane)     ; => #t
(element? Pane pane)      ; => #t
(.get pane width)         ; => 100, from the lifecycle cell
```

Allocation leaves cells unbound and does not execute initforms. A class name
or alias re-enters the same `make-instance` generic after resolution.
The complete initializer method combination precedes the final Class check
and POO read-currentness validation. Failed Slot validation preserves that
cell; effects already performed by author methods are not rolled back.
Validated mutable instances retain their identity and canonical cells; Type
validation does not wrap their FUN fields again. Pure functional receivers
retain ordinary Class rebinding.
`clos-instance?` identifies lifecycle storage, while class membership alone
does not imply completed initialization. Native `.get` reads require a current
layout and reject `instance-update-required` before any migration effects.
Lifecycle operations such as `clos-slot-value` perform lazy class updates;
subsequent `.get` reads use those same cells. Ordinary `.new` retains lazy Slots.
[Construction contracts](https://github.com/tao3k/lean-poo/blob/4062d57/LeanPoo/Object/ClosConstruction.lean) · [Class publication](https://github.com/tao3k/lean-poo/blob/4062d57/LeanPoo/Object/ClosClassPublication.lean).

`just test-source-file benchmarks/mop-lifecycle-test.ss` runs the lifecycle study.
The benchmark saves the lifecycle and C4 measurements in `$GERBIL_PATH/benchs`.

POOF Appendix A.2.2 explains effective methods as compositions of labeled
fragments selected by applicability and ordered by specificity. Gerbil-POO
uses CLOS qualifiers and lexical `call-next-method` for that composition.
Class precedence follows POO's C4 order. Prototype specializers use existing
POO ancestry. [POOF](https://namin.seas.harvard.edu/pubs/scheme-poof.pdf) ·
[HyperSpec method combination](https://www.lispworks.com/documentation/HyperSpec/Body/07_ffb.htm) ·
[HyperSpec class precedence](https://www.lispworks.com/documentation/HyperSpec/Body/04_ce.htm)

POOF Appendix A.1.2 describes how the generic, its arguments' types and the
specialized methods can come from separate libraries. A
`.defmethod-bundle` defines methods for explicit installation with
`clos-compose-method-bundle`. Installation checks protocol identity,
method signatures and writable receivers before publishing. In the supported
serial mutation model, refusal leaves the method table, method ownership and
generation unchanged. Successful installation applies the normal replacement
order and advances generation once per method. [LeanPoo admission model](https://github.com/tao3k/lean-poo/blob/39dcf42fdc7800d25cdafe0ab474116b49c7845e/LeanPoo/Object/ClosAdmission.lean)

Method qualifiers accept symbols as shorthand or finite lists. `primary`
and `()` denote an unqualified primary method; `around` and `(around)`
denote the same auxiliary qualifier. Default admission, grouping and method
replacement agree on these meanings. `(primary)` stays distinct from `()`.
POO Slot reads retain the stored spelling; `method-qualifiers` returns its list meaning.
[LeanPoo qualifier proof](https://github.com/tao3k/lean-poo/blob/a825417663af730aa4b562fe0015478644d770c9/LeanPoo/Object/ClosQualifiers.lean) ·
[HyperSpec standard method combination](https://www.lispworks.com/documentation/HyperSpec/Body/07_ffb.htm)

A `compute-applicable-methods` hook may filter or reorder eligible methods.
Each method may appear only once. An invalid result is rejected before method
combination or invocation. [Selection contract](https://github.com/tao3k/lean-poo/blob/c1d8057d5023b7029d67738da19b415d76b3ab53/LeanPoo/Object/ClosAdmission.lean).

A bare `&key` enables keyword checks with an empty list of declared keys.
Applicable methods may contribute keys, and `&allow-other-keys` permits
additional ones. A supplied `allow-other-keys` or `allow-other-keys:` uses
the first occurrence across both spellings. [HyperSpec keyword admission](https://www.lispworks.com/documentation/HyperSpec/Body/07_fe.htm)

A method parameter and its supplied-p flag share one keyword lookup.
The [admission benchmark](../benchmarks/clos-admission-test.ss) exercises
keyword binding and atomic method-bundle installation.
Run it with `just test-source-file benchmarks/clos-admission-test.ss`.

Fixed field checks in CLOS and the default POO Slot checker share the
prepared Slot method table. A live standard HashTable lookup establishes
local presence. During observation it runs after the read precheck and
delivers the original signed record. Cold and delegated queries use ordinary
reflection. Demand still uses ordinary `.ref`. [LeanPoo Slot contract](https://github.com/tao3k/lean-poo/blob/20b4d8136b5158d5341af22e5e8fc7bbe391ce69/LeanPoo/Object/SlotContracts.lean)

The [dispatch benchmark](../benchmarks/clos-dispatch-test.ss) separates
applicability, keyword admission, effective-method and frame construction,
observed calls and read replay. Run it with
`just test-source-file benchmarks/clos-dispatch-test.ss`.

Descriptor contracts pair each required slot with its value check in
`required-slots?`. The expansion shares ordinary presence and demand with
the default Slot checker. It preserves check order, lazy demand, receiver
protocols and read observation. The Lens probe inspects stored values after
route admission and issues no reads. [Lean model](https://github.com/tao3k/lean-poo/blob/8b5eb49faf3598efa6eb71d8f60dd7a165b60a74/LeanPoo/Object/SlotContracts.lean)

A call with no applicable method passes its original generic and arguments
to the extensible `no-applicable-method` generic before keyword admission.
The default method delegates to the generic's protocol hook when supplied
and otherwise signals a typed CLOS failure. See the
[HyperSpec on method selection](https://www.lispworks.com/documentation/HyperSpec/Body/07_ff.htm)
and [the distinction from prototype slot fallback](inheritance-hooks.md#slot-lookup-and-generic-dispatch).

CLOS calls and consumer code share the same [read projection](../read-projection.ss).
The [LeanPoo direct primary model](https://github.com/tao3k/lean-poo/blob/9c689fe4bcd3839bf4012c44f0dd674a91f44301/LeanPoo/Object/ClosAdmission.lean#L294-L407) states the conditions
for removing the two invocation carriers. External admission still runs in
the same order. The removed operations must be total under that admission,
have no effects on the live state, and deliver only reads of unexposed
carriers. An observer that can receive those reads or a callback that can
change the carrier policy takes the ordinary path. Public carrier calls and
calls with replacement arguments also retain their independent admission.

The [LeanPoo indexed rank model](https://github.com/tao3k/lean-poo/blob/3ea0ed9/LeanPoo/Object/ClosAdmission.lean#L495)
proves which misses an applicability scan can omit while preserving its first
refusal and ordered reads. CLOS publishes an identity-to-position index with
the method roster. When an applicability hook returns a dense list, its method
identities are checked against positions filled from the live ranked rows.
Edits during the hook can retire positions while the earlier rank remains the
authority for that hook's return. CLOS falls back to that rank when a position
is missing. The applicability scan still demands live specializers.

Generic publication owns the method-list spine. A constructed Method owns
its specializer-list spine. Slot reads and read-record inspection give
callers detached lists with the original descriptor identities. Class
precedence inspection also returns a detached list, and class position
lookups share the read-only method index implementation. A class redefinition
publishes effective slots, their lookup, history and generation together with
the affected subclass updates. Effective slot descriptors are sealed and their
list fields are detached on read. Class slot initializers run after publication.

Class declaration Slots own direct-slot list cells and default-initarg association
cells. Public reflection and read projections return detached cells, retaining
metaobject and thunk identities. Slot assignment and class redefinition preserve
this ownership. [LeanPoo ownership proof](https://github.com/tao3k/lean-poo/blob/748c111d9c2f30f7d2d830e3ec33bb852af81f82/LeanPoo/Object/ClosAdmission.lean#L882)

Instance migration publishes class, generation and storage in one POO Slot batch.
In the supported serial callback model, read prechecks see a complete layout.
A refused publication preserves the layout and revision. Update methods run
after commit; an error from an update method retains the published layout.
[LeanPoo instance publication](https://github.com/tao3k/lean-poo/blob/994f314b2c02491ae6cdca17152e86c9ceeb2444/LeanPoo/Object/ClosInstancePublication.lean)
To change a published method family, use method installation or removal. Updating the
specializer slot on a constructed Method copies the new spine at the POO
write boundary. The [LeanPoo ownership model](https://github.com/tao3k/lean-poo/blob/1d8e7bbae90301e467b69c2ebb4a5326e422942e/LeanPoo/Object/ClosAdmission.lean#L586)
specifies reflection and the conditions for locally revoking applicability rows.
The `object-instance` and `hash<-object` projections have detached cells
and their own HashTable adapters. Editing either snapshot leaves dispatch
unchanged. Public layout and issued-read inspection also return snapshots.
Raw runtime field access and changes to the shared Gerbil HashTable interface
are separate effect boundaries. The
[published-route proof](https://github.com/tao3k/lean-poo/blob/20459a2514ab702bb629c6d5e135a4c8b0eaf0c6/LeanPoo/Object/ClosAdmission.lean#L737)
states the write-ownership condition required for revision-only selection.

It forwards the original signed reads to the enclosing observation frame and
checks the boundary before dispatching an open hook. Issuance and replay stay
with the existing Slot implementation. Replay with the exact runtime `void`
uses the existing fixed checkpoint. A replay callback still gets immediate
validation of each record and a fresh return sweep.
[LeanPoo replay proof](https://github.com/tao3k/lean-poo/blob/55387de58a13ea89bf4143852687f463c94a2c79/LeanPoo/Object/ReadRouteRuns.lean)

[LeanPoo call-local validation model](https://github.com/tao3k/lean-poo/blob/25871efd66df0bee63ea7d6fe0d9d89c4d9ff5b3/LeanPoo/Object/ClosAdmission.lean#L136-L292)
defines the conditions for reusing a checked descriptor within one call.

Run the [method suites](../t/methods/) with `just test-group methods`. The
[clause ledger](../t/methods/clause-ledger.ss) maps the 41 CLHS §7.7 entries
to their conformance suites. The migrated sources retain their Apache-2.0
and LGPL-2.1-or-later notices. [LGPL text](../clos/COPYING.LESSER)
