package QuotientRoutes {
    requirement def CapturedPartitionOnly {
        doc /* Owner and row queries belong to one immutable captured SCC
               partition. Do not fuse author callbacks or source admission. */
    }
    requirement def ExactRoutes {
        doc /* Preserve ordered external provider observations and node
               identities. Reuse the same rightmost deduplicator for providers.
               Distinct nodes in one provider SCC remain individually allowed. */
    }
    requirement def EffectOrder {
        doc /* Keep native deduplication construction before allowed-table
               construction/insertion. Retain seed effects and first refusal.
               Closure evaluation, independent checks and publication stay. */
    }
    requirement def AdoptionEvidence {
        doc /* Verify conditional Lean refinement, native paired costs, source
               and provider identity, refusal controls, and complete feedback
               gates before adopting. A phase gain is not full Module EVAL. */
    }
}
