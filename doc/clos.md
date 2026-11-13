# CLOS

```scheme
(import :clan/poo/clos)

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
`poo-clos-compose-method-bundle`. Installation checks protocol identity,
method signatures and writable receivers before publishing. In the supported
serial mutation model, refusal leaves the method table, method ownership and
generation unchanged. Successful installation applies the normal replacement
order and advances generation once per method. [LeanPoo admission model](https://github.com/tao3k/lean-poo/blob/39dcf42fdc7800d25cdafe0ab474116b49c7845e/LeanPoo/Object/ClosAdmission.lean)

A bare `&key` enables keyword checks with an empty list of declared keys.
Applicable methods may contribute keys, and `&allow-other-keys` permits
additional ones. [HyperSpec keyword admission](https://www.lispworks.com/documentation/HyperSpec/Body/07_fe.htm)

A method parameter and its supplied-p flag share one keyword lookup. The
[benchmark](../benchmarks/clos-admission-test.ss) interleaves the former
binding with the current one, measures the method body and full call
separately, and compares bundle installation with sequential registration.
On macOS arm64, four interleaved AOT samples per path gave these CPU medians.

| Work per sample | Reference (ms) | Current (ms) |
| --- | ---: | ---: |
| 1,024 positional calls, same path on both sides | 314.80 | 300.54 |
| 1,024 full keyword calls with the key present | 319.38 | 302.86 |
| 1,024 full keyword calls with the key absent | 305.27 | 310.54 |
| 16,384 method body calls with the key present | 2.85 | 1.71 |
| 16,384 method body calls with the key absent | 2.60 | 1.87 |
| Install 32 bundles of eight methods each | 55.59 | 8.42 |
| Install those bundles and call each generic once | 69.68 | 29.96 |

Full keyword call differences were comparable to the positional control.
With the key present, method body allocation fell from 10.00 to 7.25 MiB.
Bundle installation plus first calls fell from 62.12 to 31.54 MiB.
After `just build-development`, run the source fixture with
`just test-file benchmarks/clos-admission-test.ss`. For an AOT run,
compile that fixture with `gxc -O -s` and give its installed `.ssi` to
the same Just test entry point.

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
