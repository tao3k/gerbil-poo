package GraphColdHandoff {
    item def PackedCapture;
    item def OwnershipView;
    action def ProjectOwnership {
        in capture : PackedCapture;
        out ownership : OwnershipView;
        doc /* Project only the existing owner position index and direction bits. */
    }
    requirement def PreserveComputation {
        doc /* Discovery, independent certification and ownership have the same
               result, error order and observable state as the retained-capture path. */
    }
    requirement def PreserveEffects {
        doc /* Capture and author callbacks precede projection. No callback,
               source admission or currentness check is omitted or moved. */
    }
    requirement def BoundRetention {
        doc /* The ownership continuation does not retain packed edge payloads.
               Native liveness and performance require separate measurements. */
    }
}
