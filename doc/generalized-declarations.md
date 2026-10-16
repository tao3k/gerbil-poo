# Generalized declarations on arbitrary explicit carriers

This advances the paper's generalized-prototype **future work**. Racket Appendix B
supplies `$lens-gen`: a getter, setter, wrapper and method compile into a delayed
prototype; cooking supplies a separate consumed self interface. The native
implementation reuses `generalized-prototype.ss`'s existing lens compiler and
assembler, adding a common declaration front end and extensible descriptors.

## Protocol and macro

`generalized-declaration.ss` exports `Fragment`, `Fragment.`, `lens-fragment`,
`GeneralizedDeclaration.`, `prepare-fragments`, `.prototype`,
`prepared-fragments?`, `fragment-names`, `observe-fragments` and `bind-fragments`.

A fragment is an ordinary POO object with:

- `focus`: existing native Lens interface (`.get`, `.set`).
- `wrapper`: `(method delayed-cooked-self delayed-focused-parent) -> focused-value`.
- `method`: arbitrary source data; different fragments may have different types.
- `sources`: explicit additional POO sources captured by callbacks or payload data.
- `.compile`: derived by the existing focus compiler; extensions can override it
  with another delayed prototype compiler, subject to their own semantic laws.

`lens-fragment` supplies the standard descriptor. Admission checks executable
shape, not mathematical lens laws, callback termination or universal type safety.
The raw carrier can be a vector, procedure, scalar, record or another user type;
the protocol has no fixed list of cases. Every focus in one preparation must
operate on that SAME raw type and agree with the same cooked interface.

```scheme
(def focus (lens-of-get-set identity (lambda (value _) value)))
(def prepared (.prototype GeneralizedDeclaration. (.o) identity
  (fragment add (lens-fragment focus
    (lambda (amount self inherited) (+ amount (inherited))) 5))))
(observe-fragments prepared 2 99 1) ; 7
```

`.prototype` reuses exported `declaration-forms`, also used by `.declare`.
Static names, source-order expression evaluation and computed unquote-splicing
have one implementation. Inherited expanders may emit several named fragments
and finalizers may add nonlocal contributions. The existing native Reader/FUN
chain expands/finalizes the WHOLE source before generalized descriptor/label
admission and compilation. Duplicate labels or malformed descriptors refuse.
Labels identify contributions rather than storage positions: distinct labels may
update the same lens focus in the specified source order.

This consumer expects generalized fragments. Public/private record forms still
expand through the inherited declaration protocol, but their Slot descriptors
must be adapted explicitly rather than silently interpreted as generalized
fragments. Use the existing record/method consumer for those declarations.

## Construction, observation and source discipline

Preparation captures compiled callbacks and cook without constructing raw values
or executing wrappers/method bodies. A generated fragment first obtains inherited
raw storage, delays the focused getter, applies its wrapper and writes the result
through the setter. A wrapper that ignores its focused parent does not force that
getter; obtaining the inherited RAW carrier is still necessary for the setter.

`observe-fragments prepared base seed depth` reuses existing finite self unfolding
and then cooks. Zero depth cooks the seed; an empty positive-depth source yields
the base. Finite depth is not an automatic fixed-point witness. `bind-fragments`
returns the existing native FUN Reader action, checking sources on each new seed.
No result or approval is reused across calls.

Captured sources include expander/context/form metadata, complete finalized
descriptors, their immediate lenses and explicit `sources`. Supported source
revisions refuse stale observation, including at zero depth and cooking. Sources
are protected against supported writes through expansion/compilation and
observation. Changed declarations require fresh preparation. Already returned
cooked values remain versioned snapshots, not globally revoked capabilities.

Source lists, raw inputs and payloads must be immutable during the operation;
callbacks must be pure and locally terminating for the pure correspondence.
Closures are opaque: register their external metadata dependencies explicitly.
In particular, composed Lens callbacks may capture component lenses; include
those components in `sources` if they can change. Mutating native vectors/lists
or raw struct fields bypasses this source discipline; concurrent use requires
caller serialization. No arbitrary I/O rollback is claimed.

## Complex carriers and proofs

`examples/generalized-declarations.ss` composes nested vector lenses with three
different focus types: rate, dependent fee and qualified method groups. A callable
cooked interface shares demanded fields and prepares the existing standard around
and primary methods. An outer audit field is preserved. After three stages, the
triangular service's charge no longer depends on its initial seed. The SAME macro
also assembles a function as both raw and cooked carrier. An inherited multi-output
form/nonlocal finalizer control additionally exercises overlapping scalar foci.

Lean `Prototype.Generalized.Fragment` existentially packages focus/method types
without a closed sum. `Fragment.compile_eq` proves exact `$lens-gen` semantics;
`compile_frame` / `fragments_frame` prove frame preservation under explicit lens
frame hypotheses for the actual descriptors. The existing Reader expansion is
generalized once, preserving record clients. `elaborateFragments_source` binds
accepted entries to complete expansion and finalization at the same context.

`Examples/DeclaredPrototypes.lean` uses product tuples for the native vector
layout, existing typed method groups for native qualified lists, and functions
for the procedure carrier. It proves actual finite observations and universal
seed independence of the triangular charge at depth three. These are observation
laws, not equality of raw function identities or an unrestricted closure theorem.
Native tests separately execute macro expansion, vector persistence, metadata
revisions, laziness, callback guards and refusal. Neither side validates arbitrary
custom lens/wrapper/compiler laws automatically or proves the Scheme runtime.

Performance tuning is deferred until this functional path is closed. No new
benchmark format, versioned JSON, full benchmark data, archive or Lean checkout
dependency is introduced.
