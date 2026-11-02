# Inherited hooks, source revision and declared reflection

This is concrete progress on the generalized MOP **future work** described in the
paper. It reuses the object engine, C3, Slot / Class descriptors and Reader/FUN;
it does not introduce another evaluator or depend on a Lean checkout.

## Inherited operations

`mop.ss` exports `with-inheritance-hooks`. A protocol is an ordinary
POO object, so its methods compose using the existing `.o` inheritance syntax:

```scheme
(def protocol
  (.o
    (compute-precedence-list (lambda (self next) (next)))
    (compute-slot (lambda (self next slot)
      (def inherited (next))
      (lambda () (inherited))))))
(def receiver (with-inheritance-hooks protocol (.o (amount 10))))
```

`compute-precedence-list(receiver, next)` receives the current C3 computation.
It may inspect, wrap or refuse. Acceptance requires the exact canonical receiver
identities in canonical C3 order; reordering is rejected. An invalid source graph
fails before selecting its custom order hook. This is not certification of an
arbitrary replacement linearization algorithm.

`compute-slot(receiver, next, slot)` compiles an effective zero-argument thunk.
`next()` supplies the original composed thunk. The default compiler supplies a thunk without running its body. A custom hook
must preserve that laziness when required. It can wrap or replace the thunk, including implementing another
combination policy; such a transformation has its own semantics. There is no
universal claim that arbitrary hooks preserve the original result or effects.

An explicit protocol on the first object in checked precedence wins. Protocol
objects themselves use ordinary C3 to combine inherited hook definitions. This
makes protocol selection deterministic; protocols on unrelated parents are not
automatically merged into a new protocol. Hook failure clears partial construction
state. Reading a receiver during its own construction refuses instead of exposing
an incomplete instance. Hook/source edits while checking C3 are also rejected.

## Source mutation and cache validity

`object-state.ss` owns revisions and weak reverse dependency edges. Constructors
register super dependencies; protocol and declaration compilation register their
sources. `depend-on-object!` registers additional explicit callback dependencies.
A change preflights the entire affected closure for active computation, then
advances each affected revision once and clears cached order, effective methods,
values and slot-name views. Shared diamonds therefore do not retain stale joins.
Weak keys do not keep abandoned instances alive. Old edges after a source switch
are retained conservatively; they can cause extra invalidation, never stale reuse.

Supported specification writes are `.putslot!`, `.putdefault!`,
`object-slots-set!`, `object-defaults-set!`, `object-protocol-set!` and
`replace-object-supers!`. Topology replacement checks C3 and cycles before editing
the source. `.put!` remains an explicit INSTANCE assignment, held separately from
derived values; descendants inherit specifications, not those assignments, as in
the original tests. Instance assignments survive derived-cache clearing.
`object-revision` is available to external source-bound caches, which must check
all their registered sources rather than treating a hit as approval.

`seal-object!` rejects subsequent supported writes on that object. It does not
freeze unsealed ancestors. Parent mutation remains supported through invalidation;
this is the explicit invalidating alternative to freezing all used supers.
Low-level generated struct setters and exposed hash mutation are trusted internal
escape hatches, outside this protocol. Concurrent mutation/evaluation requires
caller serialization; the implementation does not claim a concurrent transaction.

## Declarations and reflection

`reflection.ss` exports `object<-declarations`, `make-declared-instance`,
`reflect-slots`, `read-slot` and `write-slot!`.

```scheme
(def amount (instance Slot type: Integer default: 10))
(def private (instance Slot hidden: #t constant: 'secret))
(def source (object<-declarations
  (list (cons 'amount amount) (cons 'token private))))
(read-slot source 'amount) ; 10
(write-slot! source 'amount 20) ; checked specification edit
```

Names can be computed using ordinary Scheme list construction. Duplicate names
and invalid Slot descriptors refuse before publishing a receiver. Most-specific
declaration metadata wins, including a private child overriding a public parent.
The compiler calls the descriptor type's existing `.slot.define` method on a
private scratch object, then uses those ordinary slot/default specifications.
Direct merge (`.+`), cloning (`.cc`) and lens updates preserve direct protocol
and declaration metadata, registering those sources independently when compiled.
Descriptor/type edits invalidate and recompile this work; clearing a value cache
alone would not update a changed constant/default/compute definition.

Reflection demands metadata, not instance slot values. Optional absent declarations
can be inspected but are excluded from `.all-slots`. Public reads reject hidden
or undeclared slots and validate the demanded value against CURRENT metadata.
This also covers cached instance assignments, defaults and hook-produced values;
raw values may be cached, but previous approval is never reused. Reads and writes
use the existing `.slot.check`; writes validate before editing, so an
invalid value leaves revisions and derived caches intact. Direct raw `.ref` is
trusted and can read private slots; this API is not a language security sandbox.
The explicit `include-hidden?: #t` view is for trusted inspection.

`make-declared-instance` bridges the Class `effective-slots` catalog and the
existing checked constructor. Catalog membership is captured at construction;
metadata contents remain registered sources. Changed membership needs a fresh
instance. Whole-class cross-field constraints still require explicit `instantiate`
after edits; a single slot checker cannot infer them.

## Complete functional controls

`examples/inherited-services.ss` composes a shared declaration source, inherited
audit hooks, two service branches, a diamond join and a Reader/FUN revision action.
Tests cover invalid writes, shared revision, hidden-metadata refusal/recovery,
private non-demand, sealed-source refusal, protocol replacement and retry after a
failed compilation. Existing object behavior controls remain unchanged.

Lean counterparts are `Functional.InheritedMOP` hook composition / checked-order
laws, `Object.invalidateCaches` using the existing reverse-reachability model,
and `Prototype.DescriptorReflection` public admission laws. They assume explicit
source edges and pure models; native tests separately exercise actual weak tables,
callback selection, exception unwind and metadata compilation. No proof of the
Scheme compiler/runtime or new elapsed-time result is supplied. Historical
performance receipts retain their own source identities and do not qualify this
new core implementation.

Public `object-supers` owns the returned list spine. Parent objects themselves stay
shared, and supported writes to those objects still propagate normally. Use
`object-supers-set!` or `(set! (object-supers receiver) parents)` to replace topology;
both are the existing `replace-object-supers!` protocol. Internal `%supers` access
is reserved for engine code and deliberate negative controls.
