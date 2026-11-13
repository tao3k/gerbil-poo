package ModuleCatalog {
    requirement def MetadataOnly {
        doc /* A qualified name resolves to ordered version/source rows.
               Enumeration has no module imports, loads or dependency reads. */
    }
    requirement def ExactDemand {
        doc /* An exact missing or ambiguous identity refuses before demand.
               Successful selection reads the selected source only on demand.
               A wide bucket can index exact version identities while keeping
               its original row order for enumeration. An index entry is either
               one row or a conflict, including a repeated identical source. */
    }
    requirement def LocalPublication {
        doc /* Prepare the explicit changed-name buckets against an immutable
               predecessor. A proposal binds the preparing publication and
               predecessor. Commit checks both under the publication lock.
               Two publications may share an initial snapshot without sharing
               their proposals. The staged edit owns its new bucket spines
               and row fields. Version and source identities are preserved.
               Later writes to the submitted rows cannot alter the staged
               view or either published snapshot. An exact source replacement
               checks the unique predecessor version, shares the ordered
               version spine and forks only the version index path. */
    }
    requirement def GerbilOwnsInstallation {
        doc /* Catalog rows contain opaque source identities. Only Gerbil
               owns source installation and package dependency entry points. */
    }
}
