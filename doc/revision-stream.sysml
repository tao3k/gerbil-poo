package RevisionStream {
    requirement def FixedPureRead {
        doc /* Sources and captured revisions are private proper lists.
               Sources are valid POO objects. The only reader is the fixed,
               total object-revision field accessor: no slot lookup, author
               callback or source observer runs inside this interval. */
    }
    requirement def ExactComparison {
        doc /* Compare both list lengths and every demanded revision. The
               streamed Boolean equals structural comparison with the mapped
               current revisions. An unrelated owner change is irrelevant.
               No second revision snapshot or cache is created. */
    }
    requirement def FieldReadWork {
        doc /* Read each source once for a fully current list. If k fields
               agree before the first mismatch, read k+1 fields and stop.
               This bounds field reads, not execution time. */
    }
    requirement def EffectsRemainSeparate {
        doc /* Keep all original source/lens admission boundaries and error
               messages. Never share an earlier verdict across expansion,
               compilation or an author callback. Stream only pure reads;
               effects, errors or unknown getters require the original path. */
    }
}
