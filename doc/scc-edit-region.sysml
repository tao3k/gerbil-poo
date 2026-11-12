package SccEditRegion {
    requirement def ExactEditRoots {
        doc /* Old and successor rows have the same supported vertex domain.
               Outside the edited roots every directed edge agrees. Borrow
               the old forward and reverse indices and overlay added edges;
               this is the old/new union in both directions. */
    }
    requirement def MembershipEditSupport {
        doc /* For a roster edit keep the old ordinals and isolate retired
               vertices in the repair domain. Validate new rows and visit the
               old inverse buckets of retired providers. Any active reader
               in those buckets must have an edited row. Project only active
               vertices into the successor graph. */
    }
    requirement def RetiredGroupValueReuse {
        doc /* Reuse requires authenticated builder locality and unchanged
               member inputs. An opaque builder may inspect the complete
               successor roster and refuse. Such builders retain the
               original full support-change path. */
    }
    requirement def PrivatePreparationSeedScope {
        doc /* Private graph seeds apply only inside authenticated native
               preparation. Ordinary shape admission and application
               callbacks use the application seed policy. Restore the
               outer seed policy after return or refusal while retaining
               the application's actual effects. */
    }
    requirement def PreparedMemberFragments {
        doc /* Isolate native fragment assembly only for the issued member
               builder, matching member and provider lenses, warm method
               values and original preparation descriptors. Cold or opaque
               preparation keeps ordinary seeds. Closure, lens methods and
               cooking retain the ordinary policy. */
    }
    requirement def LensReadiness {
        doc /* Eligibility inspects existing native instance cells without
               issuing a slot observation or preparing the object. Cold,
               missing and changed routes use ordinary preparation. */
    }
    requirement def ProgramReadTraversalLifetime {
        doc /* An admitted program owns the existing read traversal for its
               issued roots. The traversal is structural evidence. Before
               and after the evaluator, validate the live receiver revisions
               and routes. The owner cannot authorize a stale or forged read.
               No additional receiver is needed to hold that traversal. */
    }
    requirement def OwnedProgramDispatch {
        doc /* For an admitted quotient under the closed stock Builder,
               consume the already captured row's guarded action. Keep the
               ordinary wrapper for open observation and unknown Builder
               behavior. Both paths invoke the same program checkpoint and
               require its independently validated outcome. */
    }
    requirement def ClosureApplicationEffects {
        doc /* A private closure step may change only private seed state.
               Initial lens domain, visited-state lens laws, residual
               equations and cooking use the application seed policy.
               Preserve callback order, first refusal and preceding effects. */
    }
    requirement def ComponentBoundary {
        doc /* Intersect the union walks from and to the edited roots. An old
               or successor SCC that meets this region lies wholly in it.
               Keep old SCC membership outside; compute inside on the new
               induced graph. The combined relation equals cold successor
               SCC membership. The two walks may witness different roots. */
    }
    requirement def RefinementBoundary {
        doc /* The relation proof assumes exact rows and exact walk results.
               Row admission, source-order representatives, publication,
               and downstream consumer invalidation are separate checks. */
    }
    requirement def SingleRowRemoval {
        doc /* With one changed row and no additions, the old SCC of its
               owner is exactly the repair region. For a certified whole
               functional cycle with one removed edge, the cut becomes a
               sink; every successor group is a singleton. An internal
               chord retires the functional shape even if membership survives. */
    }
    requirement def AllRepresentativesChanged {
        doc /* After a certified cut of a nontrivial whole cycle, every group
               changes membership, including the old representative's group.
               Signal the complete support handoff; enumerate only on demand. */
    }
    requirement def InvalidationHandoff {
        doc /* For fixed quotient support, seeding all edited rows makes
               predecessor and successor reverse closures equal. When a
               provider changes representative, follow its successor vertex
               inverse to seed every affected reader group, including groups
               outside the SCC repair region. Retain the support-change
               fallback and separate ticket validation. */
    }
}
