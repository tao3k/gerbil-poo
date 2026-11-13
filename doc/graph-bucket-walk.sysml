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
    requirement def InsertedReaderRetirement {
        doc /* Even the first insertion is separate from the admitted
               row. An insertion remembers whether it masks a borrowed
               reader. On removal discard the insertion and retain a
               mask only if the borrowed reader would reappear. When
               no edits remain, return the original row. */
    }
    requirement def DeletionOnlyComponentRepair {
        doc /* A batch without insertions repairs only predecessor components
               with an internal non-self edge deletion. Induce the successor
               edges inside each such component. Preserve cross-component
               edges for quotient maintenance and retain untouched snapshots. */
    }
    requirement def SuccessorQuotientReaders {
        doc /* Remapped providers enumerate their surviving readers through
               the successor inverse. An unchanged consumer row whose providers
               all retain their representatives has the same ordered projection.
               An authored row edit contributes its own invalidation seed. */
    }
    requirement def WholeComponentInverse {
        doc /* After certifying one nontrivial component, the private
               internal inverse covers every edge in the admitted graph.
               Transfer it in source-order reader representation to owned
               state. For other partitions, construct the full inverse. */
    }
    requirement def CertificateRefusalOrder {
        doc /* Save the first invalid quotient edge in source owner order.
               At each owner, check spanning before reporting that owner's
               saved quotient error. A later owner cannot mask an earlier
               failure. Complete both checks before transferring ownership. */
    }
    requirement def CompleteReverseSearch {
        doc /* When the admitted rank frontier covers the reverse search
               interval, include every live reader in bucket order.
               Skip masked owners and count every live edge. */
    }
    requirement def EditedSearchFrontier {
        doc /* Charge every live edge in the edited bucket, including edges
               outside the rank interval. Only accepted owners contribute fresh
               frontier cells. The pending tail and borrowed rows retain identity. */
    }
}
