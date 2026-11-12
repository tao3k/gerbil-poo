package GraphColdIndex {
    requirement def CapturedBeforeSpecialization {
        doc /* Capture every row and retain independent source/effect checks.
               Only an owned, unique admitted roster with all captured rows
               empty may bypass DFS. Copy the resulting private order spine. */
    }
    requirement def SparseInverse {
        doc /* For owned snapshots with zero or one distinct provider, do not
               write one empty inverse bucket per owner. Multi-provider graphs
               retain dense initialization. Preserve edge order; reads use [].
               Domain membership stays in support/ranks, never inverse keys. */
    }
    requirement def MissingIsNotEmptyEverywhere {
        doc /* Forward adjacency and general structural-index missing/default
               semantics are unchanged. Only private inverse consumers use the
               empty default. Keep the native symbolic invalidation fast path. */
    }
    requirement def UncontrolledSources {
        doc /* Unknown sources keep the original full traversal and dense
               initialization. No key validation or first refusal is removed.
               Native table constructors and author callback ordering remain. */
    }
    requirement def CardinalityIsOnlyCapacity {
        doc /* A known owner count may reserve native table capacity. It must
               not replace membership/admission or infer rank bounds. Native
               constructor seed effects, point reads and snapshot forks stay. */
    }
}
