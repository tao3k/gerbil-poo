package SccEditRegion {
    requirement def ExactEditRoots {
        doc /* Old and successor rows have the same supported vertex domain.
               Outside the edited roots every directed edge agrees. Borrow
               the old forward and reverse indices and overlay added edges;
               this is the old/new union in both directions. */
    }
    requirement def MembershipEditSupport {
        doc /* For a roster edit keep the old ordinals and isolate retired
               vertices in the repair domain. Check the predecessor inverse
               before capturing author rows. Every surviving reader of a
               retired provider must supply an edit. Admit edited rows over
               the final active roster. Remove isolated retired vertices
               after repair and retire only actual old representatives. */
    }
    requirement def RetiredGroupValueReuse {
        doc /* Reuse requires authenticated builder locality and unchanged
               member inputs. An opaque builder may inspect the complete
               successor roster and refuse. Such builders retain the
               original full support-change path. */
    }
    requirement def AppendedOwnerAdmission {
        doc /* Reserve new source ordinals after the previous high-water mark.
               Before applying any row edit, the new owners are isolated
               singletons. Borrow the predecessor rows and order, add empty
               rows and singleton entries, then apply exact edited rows in the
               enlarged domain. A whole-cycle certificate expires on append.
               Append order and representative changes use source ordinals. */
    }
    requirement def ActiveRosterEnumeration {
        doc /* Share the cold roster. Enumerate only live appended ordinals
               after the cold entries. Retire a fresh name from both sparse
               indexes; mask a cold name to prevent fallback. Keep the
               ordinal high-water mark and all predecessor views.
               Program, base, membership and adjacency indexes remove
               retired overrides absent from their cold bases. Mask
               borrowed cold entries with the index's absence value.
               Apply the same rule to quotient ranks, rows and constructed
               values. A retired schedule row is unsupported. */
    }
    requirement def QuotientRosterDemand {
        doc /* Explicit quotient keys enumerate the admitted successor
               representatives in source order. Publication and rank order
               do not force this enumeration or any predecessor roster. */
    }
    requirement def AppendedWitnessSpan {
        doc /* When positions exceed the witness span, double the existing span
               and put its root under the new left child. Link the new ancestor
               through existing POO dependency registration. Observe child
               currentness after linking and refuse if it was already stale.
               Shared old addresses and predecessor roots remain intact. */
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
               owner is exactly the repair region. In a certified whole
               functional cycle, removing at least one edge without additions
               makes every successor group a singleton. An internal chord
               retires the functional shape even if membership survives. */
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
