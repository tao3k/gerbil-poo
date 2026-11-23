package GraphRankBounds {
    requirement def AdmittedDAG {
        doc /* Before each search, every active consumer/provider edge has
               provider rank < consumer rank. Ranks are nonnegative and below
               the monotone frontier. Missing owners are refused before search. */
    }
    requirement def DirectionalSelection {
        doc /* Forward owners have rank <= high, hence their providers need
               only the low test. Reverse owners have rank >= low, hence their
               readers need only the high test. These facts certify complete
               range shortcuts; partial intervals retain the former predicate.
               Selection order is unchanged. */
    }
    requirement def CompleteRange {
        doc /* Forward low=0 admits the whole bucket. Reverse high>=frontier-1
               admits the whole bucket. Only these certificates permit omitting
               per-edge rank queries. Still charge all edges and output work. */
    }
    requirement def RepairLabelMerge {
        doc /* Capture old labels before any rank assignment. Merging the
               sorted provider and consumer labels yields the same labels
               as sorting the combined frontier. Assignment and incident
               check order remain provider first, then consumer. */
    }
    requirement def DenseRepairRankScan {
        doc /* Enumerate only reached marks in ascending admitted rank order.
               Resolve owner identity using the pre-assignment position
               mapping. Unmarked gaps and retired ranks are skipped. */
    }
    requirement def EffectsAndSnapshots {
        doc /* A rank query here is an internal immutable index read, not an
               author callback. Preserve source admission, callback checks,
               cycle refusal, predecessor snapshots and publication checks.
               Retirements leave holes; never assume active labels are dense. */
    }
}
