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
               Admit the selected route after the effect, not from an old verdict. */
    }
    requirement def ReceiverOwnership {
        doc /* Own canonical key spines; every receiver still gets independent cells.
               Metadata sharing never grants currentness or computes a business scope. */
    }
}
