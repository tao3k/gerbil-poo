# CLOS

```scheme
(import :clan/poo/clos)
```

The CLOS extension provides multiple dispatch, class, prototype and `eql`
specializers, method combination, next-method continuations and class
lifecycle. It uses POO objects, Slot reads and C4 precedence.

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
It forwards the original signed reads to the enclosing observation frame and
checks the boundary before dispatching an open hook. Issuance and replay stay
with the existing Slot implementation.

The [method suites](../t/methods/) run through the standard test build. The
[clause ledger](../t/methods/clause-ledger.ss) maps the 41 CLHS §7.7 entries
to their conformance suites. The migrated sources retain their Apache-2.0
and LGPL-2.1-or-later notices. [LGPL text](../clos/COPYING.LESSER)
