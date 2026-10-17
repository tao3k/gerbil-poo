# Constant-base MOP bootstrapping and nonlocal declarations

This advances the paper's generalized MOP **future work**. The Racket section
“A prototype is more than a function” makes prototype metadata into objects and
uses an explicit constant base to stop infinite meta recursion. It supplies the
construction principle; the hook/elaboration APIs here are new concrete work.

## A self-describing protocol root

`meta-prototype.ss` exports `bootstrap-protocol` and `bootstrap-protocol?`.
The input is an ordinary POO object supplying `compute-precedence-list` and
`compute-slot`. The constructor reads inherited hook values, validates they are
procedures and pins them as constant slots on a fresh root. That root's protocol
is **itself**, and it is sealed only after complete checked construction.

The two hook names form the explicit constant base. Ordinary `.ref` / `.slot?`
can read those anchors while the root is constructing, without recursively
constructing the same root. The slot compiler still governs every non-anchor
metadata field, including its own `expand-declaration` implementation. Thus the
base does not disable MOP interpretation for the rest of the object.

This is a small terminating base, not permission to ignore arbitrary cycles.
Ordinary self-protocol cycles and premature recursive reads of non-anchor
metadata still refuse. Accepted precedence remains canonical checked C3.
Callbacks must delay non-anchor self reads until their bodies are demanded.
No partial instance table is published on construction failure.

Anchors are a captured version: editing the input's future hook definitions does
not replace an existing root's pinned callbacks. Use fresh bootstrap for a new
kernel version. Other inherited metadata follows ordinary invalidation. The root
can govern derived protocols, whose callbacks then govern service objects, with
ordinary C3 inheritance at every level. Cloning a root produces an ordinary derived
object governed by the original root; it does not copy self-hosting provenance.
Raw struct/table mutation remains trusted, outside supported sealing/invalidation.

## Nonlocal declaration protocol

`declaration.ss` exports `Declaration.`, `declaration-form`, `declaration-action`,
`expand-declarations`, `object<-declaration-forms` and `.declare`.

`Declaration.` is an ordinary inherited object with two operations:

- `expand-declaration(context, form)` returns a finite list of existing named Slot
  descriptors. One form can emit several slots and annotations.
- `finalize-declarations(context, entries)` receives the WHOLE ordered expansion
  and can add nonlocal declarations or refuse. It cannot bypass final name and
  descriptor checks or remove the mandatory visibility catalogs.

The default expander implements `public` / `private`. Extensions use `.o` and
inherited continuations; the library does not keep a separate extension registry.
A form is ordinary POO metadata with `kind`, `name` and `descriptor` slots.

```scheme
(def context (.o (revision 1)))
(def dynamic (list (declaration-form 'public 'computed (.o (constant #f)))))
(def value (.declare Declaration. context
  (public amount (.o (type Integer) (default 10)))
  (private token (.o (constant 'secret)))
  ,@dynamic))
(read-slot value 'amount)
(.@ value .public-slots) ; (amount computed)
(.@ value .private-slots) ; (token)
```

Static names are quoted by `.declare`; computed names use `declaration-form` and
ordinary Scheme unquote-splicing. Metadata expressions run once in source order
when building the form list, before expansion. They are source formulas as with
`.cc`, not implicit snapshots of instance-only `.put!` overrides.

Expansion is compiled as a Reader/FUN chain. Bind sequences fragments, map joins
their contributions and all callbacks/finalization receive the SAME current
context. The first expansion failure skips later callbacks. Form-list construction
precedes this phase; external I/O is never claimed to roll back. A reused action
can receive a different context each time and does not cache approvals/catalogs.
It captures one expander revision; source changes make it refuse until recompiled.
Expander/context dependencies are protected against supported mutation during
execution and final receiver construction. Additional external dependencies need
explicit registration; concurrent mutation requires caller serialization.

After finalization, `.public-slots` and `.private-slots` are added as hidden
computed metadata slots. They reflect effective inherited visibility without
forcing instance values. Their reserved names, duplicate names and malformed Slot
descriptors refuse before a receiver is returned. Descriptor visibility edits
invalidate the catalogs through the existing source graph. This is metadata and
checked public access, not a raw-access security sandbox or arbitrary lexical
macro system. Captured catalog membership changes require fresh elaboration.

## Complete workflow and proof boundary

`examples/metaprotocol-services.ss` bootstraps a declaration expander that governs
its OWN expansion metadata. An inherited `property` form emits a public field,
public getter and private revision annotation; another form checks current
approval. A shared source feeds billing/risk branches and a diamond join through
ordinary inheritance. Reader/FUN actions demonstrate refusal, recovery, distinct
published revisions, getter calls and shared source updates.

`t/meta-prototype-test.ss` checks anchor reflection, root sealing, captured kernel
versions, a derived meta level, ordinary cycle refusal, private non-demand,
computed names, ordered effects, stale-action refusal, final name collisions,
context-mutation rejection and complete service publication.

Lean `Prototype.MetaPrototype` proves constant anchor reflection and exact
non-anchor dispatch for any source/receiver. `Functional.DeclarativeMetadata`
proves ordered expansion composition, first-error propagation, exact full-source
finalization, catalog name validity and retention of the old publication on
refusal. `Examples/MetaBootstrap.lean` exercises the combined metadata boundaries.
These are pure models; native getter execution and callback effects are tested
separately. No unrestricted recursive knot, callback termination, Scheme runtime
or compiler correctness, or new performance result is inferred.
