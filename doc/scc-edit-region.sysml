package SccEditRegion {
    requirement def ExactEditRoots {
        doc /* Old and successor rows have the same supported vertex domain.
               Outside the edited roots every directed edge agrees. Borrow
               the old forward and reverse indices and overlay added edges;
               this is the old/new union in both directions. */
    }
    requirement def ComponentBoundary {
        doc /* Intersect the union walks from and to the edited roots. An old
               or successor SCC that meets this region lies wholly in it.
               Keep old SCC membership outside; compute inside on the new
               induced graph. The combined relation equals cold successor
               SCC membership. The two walks may witness different roots. */
    }
    requirement def RefinementBoundary {
        doc /* The relation proof assumes exact rows and exact walk results.
               Row admission, source-order representatives, publication,
               and downstream consumer invalidation are separate checks. */
    }
    requirement def SingleRowRemoval {
        doc /* With one changed row and no additions, the old SCC of its
               owner is exactly the repair region. For a certified whole
               functional cycle with one removed edge, the cut becomes a
               sink; every successor group is a singleton. An internal
               chord retires the functional shape even if membership survives. */
    }
    requirement def AllRepresentativesChanged {
        doc /* After a certified cut of a nontrivial whole cycle, every group
               changes membership, including the old representative's group.
               Signal the complete support handoff; enumerate only on demand. */
    }
    requirement def InvalidationHandoff {
        doc /* For fixed quotient support, seeding all edited rows makes
               predecessor and successor reverse closures equal. When a
               provider changes representative, follow its successor vertex
               inverse to seed every affected reader group, including groups
               outside the SCC repair region. Retain the support-change
               fallback and separate ticket validation. */
    }
}
