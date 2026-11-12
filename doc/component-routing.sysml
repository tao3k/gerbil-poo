package ComponentRouting {
    requirement def LogicalMemberDomain {
        doc /* Route against the owned selected component identities.
               Expanded/finalized fragment labels and whole-family keys are
               different domains unless their equality is established. */
    }
    requirement def DeclaredBeforeRoute {
        doc /* Retain every original program-reads/currentness callback before
               route lookup or index forcing. First refusal belongs to that
               check; pure membership evidence does not cross author effects. */
    }
    requirement def PrivateImmutableIndex {
        doc /* A candidate derived index owns a copied symbol spine and lives
               only with that group. Use existing runtime primitives, no global
               registry or value evaluator. No shared mutable family markers. */
    }
    requirement def NativeEffectsFrame {
        doc /* Native raw-table allocation has no adapter callback or RNG draw.
               Ordinary interface construction is not granted this frame.
               Allocation/GC and native promise concurrency need separate gates. */
    }
    requirement def SparseColdControl {
        doc /* Charge construction for cold zero/single/dense requests and keep
               warm lookup separate. A warm benefit cannot license a sparse
               cold regression. No production adoption on these proofs alone. */
    }
}
