package GraphRoster {
    requirement def ValidatedSymbolIdentity {
        doc /* Keep Gerbil proper-list and symbol validation before admission.
               Preserve its first refusal and payload; the proof domain begins
               only after validation. No arbitrary Scheme equality is assumed. */
    }
    requirement def OrderedMembershipEquivalence {
        doc /* One-pass admission must return exactly the two-pass first-
               occurrence order and support domain, including duplicates and
               an initially populated domain. It must not evaluate providers. */
    }
    requirement def ConstructorEffectsGate {
        doc /* Pure data equivalence does not authorize removing a native
               table constructor. Preserve observable constructor/random-source
               effects before callbacks. Trace equality is an adoption gate,
               not an assumption established by this mathematical model. */
    }
    requirement def IndependentBoundaries {
        doc /* Gerbil expansion and author callbacks retain independent checks
               on both sides. Reusing normalized data grants no permission to
               reuse evidence across either effect boundary. */
    }
    requirement def PrivateSnapshotOwnership {
        doc /* Functional membership in Lean does not prove mutable-table
               ownership in Scheme. Any shared support table must remain
               private; old snapshots and returned order copies stay isolated. */
    }
}
