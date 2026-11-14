package ComponentFamily {
    requirement def OwnBeforeAuthor {
        doc /* Validate the original finite distinct symbol family, then own
               its list spine before the first focus callback. Call each focus
               exactly once in that captured order. Failed capture publishes
               no builder. Caller/focus edits cannot redefine the family. */
    }
    requirement def OneFamilyIndex {
        doc /* The existing private lenses table is also the family membership
               index only while live wrapper layout, methods and GC backend
               authenticate callback-free identity operations. Use presence,
               not value truthiness. Unknown routes use the owned key list;
               no second index is created. */
    }
    requirement def RouteLifetime {
        doc /* Authenticate after every focus callback and before original
               table writes/reads. Losing eligibility retires the shortcut
               permanently for that family. Recheck once per callback-free
               member batch. Preserve original table operations, their errors
               and callbacks even when eligibility is lost. No verdict spans
               an author effect boundary. */
    }
    requirement def ConstructionDomain {
        doc /* Start with the private empty index. For each captured key,
               trusted insertion extends its exact domain by that key.
               An unknown write may produce arbitrary contents but must
               retire trust. Induction over the complete successful writes
               proves a trusted final index has exactly the captured domain.
               Later known writes cannot restore trust. Author callbacks do
               not own the private table. A failed write publishes no builder.
               The native insertion law is a runtime refinement premise. */
    }
    requirement def RefusalAndEffects {
        doc /* Preserve ordered member checks and refuse before source/program
               callbacks. Successful entry keeps existing equations, independent
               effect/currentness checks and complete closure/residual checks.
               No builder results or approvals are shared across owners. */
    }
}
