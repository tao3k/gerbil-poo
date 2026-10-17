# Controlled recursive validation

This module advances the paper's generalized MOP **future work**. Section 2 gives
parent and child the same final self; section 5 supplies Type descriptors and
recursive recognition. The paper's Racket code does not already implement this
whole cyclic validation/publication lifecycle.

## Finite catalog API

`close-validation` accepts a builder and a positive node-count limit (default
256). The builder receives an owner-scoped Reference-Type constructor and returns
a nonempty list of `(name descriptor source)` triples. Names are distinct symbols;
every Reference target must be declared. Sources are ordinary POO objects;
descriptors implement the Class/ObjectContract `.validation-fields` protocol.
Reference Types can occur inside existing List/Tuple/optional/variant Types.
Source checking recognizes the exact named source; final membership requires
the canonical target, including values supplied by custom Slot normalizers.
Explicit validation of a known source can resolve its already admitted target.

```scheme
(close-validation
  (lambda (reference)
    (def Left (Record peer: [(reference 'right)]))
    (def Right (Record peer: [(reference 'left)]))
    (def left (.o peer: right))
    (def right (.o peer: left))
    (list (list 'left Left left) (list 'right Right right))))
```

This is explicit finite cataloging, not automatic discovery or a universal
coinductive Type checker. Each name denotes one canonical receiver. Repeated
references to that named target retain sharing. No graph unrolling is required.

## Closure and failure discipline

1. Check the complete catalog and every source's structure, before normalization.
2. Allocate all canonical receiver identities using `prepare-rebinding`.
3. Force every selected field using `force-rebinding`. References resolve through
   this attempt's private directory; they never mark active targets as validated.
4. Run deferred nested Class/ObjectContract whole-value obligations, then every
   named node's final admission against the complete graph.
5. Seal canonical receivers and Reference Types through supported APIs; return a
   private `closed?` value only after complete success.

`closed-ref graph name` reads a canonical node; `closed-type graph name` supplies
its Reference Type. Later explicit Reference validation rechecks graph admission
and returns the same canonical identity. Normal construction hooks are not invoked
implicitly; this protocol validates the supplied sources. Ordinary Class and
ObjectContract validation still performs final checks immediately outside closure.

Each closure attempt owns its deferred queue and Reference directory. Nested
attempts have separate owners. A descriptor from another graph cannot cut
recursion in a new attempt. Build fresh descriptors with the supplied constructor
after failure/revision; do not transplant old Reference descriptors into a new graph.

Whole-catalog shape failure suppresses all normalizers. A normalization exception
discards queued obligations and unwinds the dynamic scope. Remote final refusal
returns no closed graph. Original callback exceptions and `CyclicSlot` propagate;
structured validation failures distinguish catalog, duplicate, missing-reference,
protocol, reference, owner, shape, admission and stale phases.

Registered source/descriptor/Reference/canonical revision stamps guard access and
Reference validation, including supported transitive ancestor invalidation.
Canonical nodes and Reference Types reject supported direct writes. These checks
do not globally revoke arbitrary retained Functions, cover raw setters, discover
external callback dependencies, or provide concurrent mutation isolation. Child
Types/nested metadata not registered through inheritance must remain immutable;
the directory does not automatically discover those object-valued dependencies. Keep
sources/metadata immutable while using admitted values and close/publish a fresh
version after revision. A callback may retain a private receiver or perform effects;
those effects are not rolled back.

## Computed cycles and safe recursive work

Productive computed Function fields can capture checked peer Functions across
object backedges. `examples/recursive-validation.ss` combines this with:

- A genuine positive Boolean cycle solved by existing `closure` least closure:
  `left = true OR right`, `right = left`. It does not choose an arbitrary warm seed.
- The existing explicit recursive Interaction, owner-bound memo and current Type
  admission. Requests decrease their count and carry a finite machine budget.
- Two calls sharing the right/3 request: results 10 and 8, total 18.
- Reader/FUN decoding, complete graph closure, root `refine` and exact
  `bind-evidence`, including raw/stale evidence refusal and current retry.

Active unannotated structural Type/value pairs return a `recursive-structure`
diagnostic rather than receiving coinductive acceptance. Repeated shared pairs
after return remain legal. Immediate cyclic getter demands still raise `CyclicSlot`; arbitrary eager
fixed-point equations are not solved. Machine cycle/budget diagnostics are not
values or successful admission. The graph node-count limit does not bound host
getter/validator execution time. Unregistered recursive Type paths, cyclic raw
containers, arbitrary lexical snapshots and callback termination remain outside
this controlled protocol. Constants keep strict equality; canonical Function
wrapper deduplication is separate work.

## Lean correspondence

`Functional.RecursiveValidation` proves eleven finite catalog/graph laws:
preflight completeness, all-position collection and finite completion, separate
shape/normalization/admission refusal, all-node successful requirements,
canonical reference preservation/sharing/distinctness, and bound root publication.
Named-catalog lowering, receiver allocation, host pointer identity, deferred
callbacks, sealing and revision-stamp correspondence are supplied boundaries.

`Examples/RecursiveContracts.lean` proves the concrete two-hop backedge law and
executes matching positive least closure, productive handlers, shared certified
memo, guarded arguments, budget/eager-cycle refusal, remote/shape refusal and
fresh-owner evidence controls. Existing final-self, recursive cache, positive
closure, refinement and binding proofs are reused. This does not certify Scheme
compiler/runtime/GC behavior or end-to-end performance. Scheme requires no Lean
checkout at build or runtime.
