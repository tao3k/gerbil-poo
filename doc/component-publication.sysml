package ComponentPublication {
    requirement def IndependentTicketAxes {
        doc /* Final installation checks coordinator, installed snapshot and
               lineage version. Restage advances only its own lineage and
               denial cannot reactivate the previous version. */
    }
    requirement def WholeSnapshotInstall {
        doc /* Construction and approval callbacks run outside the lock.
               Under the lock recheck currentness and evidence, then install
               the immutable graph and metadata as one head. */
    }
    requirement def LiveReadRelease {
        doc /* Release callback results only after checking the same head
               and independent guard evidence. Historical snapshots retain
               their original graph and metadata. */
    }
}
