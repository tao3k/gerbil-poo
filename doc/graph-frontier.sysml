package GraphFrontier {
    requirement def OrderedSelection {
        doc /* Edge count is charged before selection. Evaluate each rank bound
               once in original bucket order; retain first refusal and its state.
               Prepend exactly the selected owners before the old pending tail. */
    }
    requirement def PrivatePrefix {
        doc /* Every reversed-prefix cons cell is freshly allocated by this
               selection. append-reverse! may mutate only these private cells.
               Neither the borrowed bucket nor pending tail may be mutated.
               No author-visible callback may observe the private accumulator. */
    }
    requirement def AdmissionBoundary {
        doc /* Do not fuse source capture, effect checks or full edge accounting
               into selection. Unknown source still requires full authentication.
               Full order output remains explicit; no new cache or loader. */
    }
    requirement def UncertifiedSource {
        doc /* Retain the admitted ordinary roster. An unknown successor captures
               its roster and reads once. Compare captured rows with the admitted
               predecessor rows and validate changed rows before repair.
               A different roster receives cold admission. Never call the old
               program getter to decide whether its captured row is current. */
    }
}
