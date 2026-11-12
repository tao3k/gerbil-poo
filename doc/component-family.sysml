package ComponentFamily {
    requirement def OwnBeforeAuthor {
        doc /* Validate the original finite distinct symbol family, then own
               its list spine before the first focus callback. Call each focus
               exactly once in that captured order. Failed capture publishes
               no builder. Caller/focus edits cannot redefine the family. */
    }
    requirement def OneFamilyIndex {
        doc /* The existing private lenses table is also the family membership
               index. Use presence, not value truthiness. No second index or
               per-request linear family scan. Native table laws remain trusted
               runtime obligations, exercised by native controls. */
    }
    requirement def RefusalAndEffects {
        doc /* Preserve ordered member checks and refuse before source/program
               callbacks. Successful entry keeps existing equations, independent
               effect/currentness checks and complete closure/residual checks.
               No builder results or approvals are shared across owners. */
    }
}
