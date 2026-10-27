# Recursive metalevel components and nonlocal declarations

This advances the generalized MOP **future work**. Racket's “A prototype is more
than a function” supplies ordinary metadata objects and a terminating constant
base. TODO's “Design and implementation of the MOP” proposes another metalevel
fixed point; its nonlocal-declaration section proposes contributions to the rest
of an object. The APIs here make specific bounded constructions executable.
They do not claim that the original Racket code already has these APIs.

## Two distinct recursive protocols

`meta-prototype.ss` exports `close-protocol`. Its ordinary source supplies:

- `equations`: finite vector using existing `literal`, `fact`, `both`, `either`.
- `cook`: a function from the resulting closure to an ordinary protocol source.

The existing solver starts from false, computes the least fixed point and gives
that exact result to `cook`. `bootstrap-protocol` then constructs/seals the
self-hosted root; its reflected `facts` slot retains the solution. Native compile
checks reject malformed/negative descriptors and out-of-range references. Each
new source revision closes from bottom; an old solution is never used as a seed.
The example has two mutually dependent metalevel components grounded by one seed.
They control a slot compiler and whether recursive expansion is available.
Removing the seed clears both. Source/cook reads are protected against registered
edits during construction, as with the existing MOP protocol.

This solves finite positive Boolean metadata recursion. It does not construct
arbitrary cyclic Scheme procedures, admit negative/nonmonotone equations or
prove termination/equivalence of custom cook callbacks. The solver's finite
height is a bound on strict state advances, not callback time or native allocation.
Sources with a changed kernel need a fresh root; captured roots remain versions.

## Safe forward and shared declaration requests

`recursive-declaration.ss` exports `RecursiveDeclaration.`,
`recursive-declaration-action` and `object<-recursive-declarations`.
`RecursiveDeclaration.` is an ordinary inherited `Declaration.` object. Its
`expand-recursive-declaration(context, form)` operation returns an existing
`Recursive.Interaction` whose result is a finite list of named Slot descriptors.
The default lifts inherited `expand-declaration`. Extensions use existing
`.ap`, `.bind`, `.map`, and `recursive.request` with stable symbolic fragment keys.

```scheme
(def forms (list (cons 'amount
  (declaration-form 'public 'amount (.o (default 10))))))
(def value (object<-recursive-declarations
  RecursiveDeclaration. (.o) forms '(amount) 50))
(read-slot value 'amount) ; 10
```

Fragments are a finite, distinct named source list; roots are traversed in order.
Requests may refer forward. Completed shared requests reuse one program's memo.
Only requested contributions appear in the result: returning a child descriptor
does not automatically publish that child's catalog entry. Two roots contributing
the same slot still fail the existing duplicate-name admission. The finalizer
sees the whole ordered root expansion and may add cross-fragment declarations.
Mandatory public/private catalogs and complete descriptor/name checks follow it.

Memo is local to ONE action invocation and never exported or reused across current
contexts. Compiled actions capture expander, form and descriptor source revisions;
edits require a fresh action. Registered edits during expansion/finalization and
receiver construction refuse. Frozen captured roots/form lists/keys and pure,
locally terminating callbacks/continuations are caller premises. External mutable
callback dependencies need registration; concurrent access requires serialization.
Raw struct writes and arbitrary I/O remain outside these guarantees.

Repeated active expansion requests produce cycle diagnostics; insufficient machine
depth produces budget diagnostics. Explicit source errors remain source errors.
These are not positive equations: no Boolean bottom is substituted for a missing
declaration. A later root failure skips its suffix and the finalizer. No tentative
memo/prefix receiver escapes failure; arbitrary external I/O is not rolled back.
Budget counts recursive machine depth, not total work or host callback execution.

## Three-way evidence

| Construction | Lean | Gerbil |
| --- | --- | --- |
| Positive metalevel feedback then base self-description | `MetaPrototype.closePositive_fixed/least/cooked/reflect/bound` | `close-protocol` → existing least solver → `cook` → `bootstrap-protocol` |
| Source-owned recursive fragments | `collectRecursive`, `Resolved.sources` | typed request generator and existing `recursive-cache.ss` receipts |
| Whole-source nonlocal publication | `elaborateRecursive_source`, `finishRecursive_source`, `publishRecursive_refused` | Reader/FUN roots → finalizer → existing descriptor/catalog constructor |
| Mutual components and shared service fragments | `Examples/RecursiveMetaprotocol.lean` | `examples/recursive-metaprotocol.ss`, `t/declarations/recursive-declaration-test.ss` |

Every accepted Lean chunk has a finite source evaluation for its exact program
and root. The integrated source theorem connects ALL chunks to finalization at
the current context. Existing catalog validity rules still apply. These pure
laws do not establish Gerbil compiler/runtime correctness or universal native
getter behavior. Native controls execute shared calls, total values, private
access, revisions, refusal/recovery and mutation guards separately. There are
no serialized Lean proof constants or Lean checkout runtime dependencies.

No performance optimization or benchmark result is claimed by this functional
completion step. Unrestricted recursive metalevel fixed points, alternative
inheritance orders, arbitrary lexical rewriting and global access security remain
explicit future work.
