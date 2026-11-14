package ShapeAdmission {
    item def SlotNameRequest;
    item def CanonicalShape;
    action def SelectShape {
        in names : SlotNameRequest;
        out canonical : CanonicalShape;
        doc /* Reuse the existing weak shape index. No new index or value cache. */
    }
    requirement def ExactScalarAdmission {
        doc /* Empty and singleton requests preserve identity and first bad key.
               Larger requests follow the unchanged full admission path. */
    }
    requirement def ClosedScratchEffects {
        doc /* Scratch work may be omitted only when existing runtime routes
               establish that it cannot dispatch authors or change semantic state.
               A canonical shape hit is not evidence for this requirement. */
    }
    requirement def ExactFallback {
        doc /* Unknown routes retain allocation, admission, error order and effects. */
    }
    requirement def PreserveSeedEffect {
        doc /* Preserve the native seed draw exactly once before admission.
               Reuse that seed on a miss; a fallback cannot draw it twice.
               A guard may span the native RNG only under its route/spine frame
               law. Arbitrary author effects require independent admission. */
    }
    requirement def ReceiverOwnership {
        doc /* Own canonical key spines; every receiver still gets independent cells.
               Metadata sharing never grants currentness or computes a business scope. */
    }
    requirement def CurrentAdapter {
        doc /* Inspect Gerbil's existing descriptor/prototype entry and physical
               routes on every scalar request. Cold or changed routes fall back.
               Do not create another adapter/cache or retain an obsolete backend. */
    }
    requirement def StaticDependencyClosure {
        doc /* Gambit macro definitions belong to the module's generated static
               source as well as its dynamic compile command. Linked entry and
               fresh-process replay gates must pass independently of SSI tests. */
    }
}
