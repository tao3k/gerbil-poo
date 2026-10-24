# Binding existing invocation results

`clan/poo/declarative-metadata` exports `bind-evidence`:

```scheme
(metadata.bind-evidence invocation subject descriptor context evidence-view)
```

This ordinary function specializes an existing invocation Contract. Its input,
output and formula remain effective. An additional relationship requires the
invocation request to be the exact subject and the projected result to contain
the exact subject, descriptor and context references. `evidence-view` is a pure
function returning a POO view with those three slots. No receipt type, admission
policy, schema compiler, Core dependency or evidence store is introduced.

```scheme
(def Bound
  (metadata.bind-evidence Call FinalObject ActualContract CurrentContext
    (lambda (result)
      (.o subject: (.get result candidate)
          descriptor: (.get result admission-contract)
          context: (.get result context)))))

(defvalues (result next refusal)
  (metadata.publish Bound PreviousObject execute FinalObject))
```

The consumer owns `Call`'s input/output predicates and the controlled result
producer. If the output is an admission receipt, that producer must record the
descriptor actually used. A symbolic contract name cannot substitute for its
object reference. Binding does not authenticate freely constructed POO fields.
This example assumes consumer-defined names, not additional public APIs.

The helper uses existing `with-meaning`, `Formula.`, `decision`, `invoke` and
`publish`. A single Formula closes over the original decision and the fresh atom,
instead of constructing an intermediate atom Formula followed by `both`.
A fresh private atom avoids collisions with the caller's formula. Existing rule
refusal short-circuits the projection. Binding does not eagerly prepare invariant
checks, including when the parent has already prepared them. Existing source
identity guards invalidate changed input/output/rule preparation. Mismatches
refuse in the logic phase; projection exceptions retain their cause there.
`publish` retains the exact old state on metadata refusal. External effects are
not rolled back.

References and their contents must remain immutable. Equal-looking but distinct
subjects, descriptors or contexts are conservatively rechecked. In-place changes
are not detected by `eq?`; external revisions need consumer-owned context policy.
Rebind for a new effective subject, descriptor or context; reusing preparation
does not reuse a previous approval. No cross-process certificate or automatic
freshness, source authentication, graph policy or result cache is provided.

`t/evidence-binding-test.ss` tests the public helper without Core imports, with
exact references, mismatch refusal, original formulas, cold binding after parent
preparation and malformed projections. Consumer tests own admission semantics.

Nested binding preserves the earlier formula as well as the fresh association.
Consequently binding a different context onto an already bound contract does not
discard the old context requirement. Retry starts from the original invocation
template with the current immutable references. This has paired Scheme and Lean
controls, including a matching record that still fails the original permission.

Lean `Functional.EvidenceBinding` makes freshness of the extra atom explicit with
`Option Atom`, proves all formula connectives survive relabeling, and retains the
original input/output policies. Accepted invocations imply the original rule and
exact identity associations. Under admitted input/output, mismatched associations
refuse publication with exactly the old state. Identity-carrier interpretation,
immutable references and a total pure view are assumptions; this does not prove
authentication, arbitrary projection termination or external effect rollback.
