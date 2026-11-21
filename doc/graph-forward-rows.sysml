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
    requirement def DeclaredRowAcquisition {
        doc /* A sealed data declaration owns one row per source ordinal.
               Its current receiver and unobserved stock route may lend that
               row to SCC validation. Public reads and refusals own their
               spines. Other receivers and observed reads use .code. */
    }
    requirement def PackedDeclarationAdmission {
        doc /* Own the roster and CSR at admission. Admit the roster before
               checking offsets and targets in owner order. Only the issuing
               current declaration under the stock unobserved route may
               lend the arrays to discovery and independent certification. */
    }
    requirement def WholeComponentOrdinalCertificate {
        doc /* Check both directions from the first owner on the captured
               edges and their transpose. A single certified group borrows
               the roster for owner queries and source-ordered membership.
               Strict misses preserve the symbolic table error contract. */
    }
    requirement def OrdinalComponentCertificate {
        doc /* Check every cross-group edge against decreasing discovery
               ranks and cover every group in both directions. Closed tours
               may certify both directions. Queries resolve the first source
               representative from that same ordinal roster and rank array. */
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
