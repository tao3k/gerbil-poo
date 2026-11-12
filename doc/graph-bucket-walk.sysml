package GraphBucketWalk {
    requirement def OrderedIncidentWalk {
        doc /* Enumerate added owners in ascending ordinal order, then retained
               base owners in their original order. Mask every edited base owner.
               A first refusal retains the same owner and counter/trace prefix. */
    }
    requirement def PureMembershipBoundary {
        doc /* Bucket membership and mask are immutable during the walk. Retain
               admission and independent effect checks outside this interval.
               The visitor here checks admitted ranks; it is not an author hook. */
    }
    requirement def SnapshotOwnership {
        doc /* Borrow the old base spine; do not alter it or expose private trees.
               Stream incident checks through the existing POO inverse index.
               Public order and bucket enumeration remain explicit operations. */
    }
    requirement def EditedSearchFrontier {
        doc /* Charge every live edge in the edited bucket, including edges
               outside the rank interval. Only accepted owners contribute fresh
               frontier cells. The pending tail and borrowed rows retain identity. */
    }
}
