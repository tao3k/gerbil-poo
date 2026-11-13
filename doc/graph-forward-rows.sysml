package GraphForwardRows {
    requirement def CaptureAndSupport {
        doc /* Keep admission, constructor effects and callback checks in their
               original order. Capture every authored row once. Only when
               the captured binding map is empty may the owned entry derive
               implicit empty rows from the already admitted support. */
    }
    requirement def ExactOrderedRead {
        doc /* Existing admitted support distinguishes a present empty row
               from an unsupported owner. Preserve exact row order, defaults,
               refusal and the public copy boundary. */
    }
    requirement def SealedComponentRows {
        doc /* Within the existing component source admission and recheck,
               the pure SCC body may borrow stored rows with the same owner
               and dependency order as the sealed public view. Preserve the
               public defensive copy, and keep mutable row spines private.
               Unrestricted sources still use their authored read boundary. */
    }
    requirement def PersistentPatch {
        doc /* Absent patch falls through; a present empty patch or a retirement
               tombstone masks the cold base. A fork cannot change its predecessor. */
    }
    requirement def ProductionQualification {
        doc /* Lean equivalence precedes Scheme adoption. Qualify native
               representation and effect trace separately, with matched empty,
               chain and hub cases, unchanged budgets and a semantic fault. */
    }
}
