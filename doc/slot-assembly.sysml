package SlotAssembly {
    item def OwnerCatalog;
    item def FrozenThunks;
    action def CompileCatalog {
        in owner : OwnerCatalog;
        out snapshot : FrozenThunks;
        doc /* Existing SlotSpec compilation and original hook/publication path.
               No new evaluator, cache, loader or public selection API. */
    }
    requirement def ClosedNativeInterval {
        doc /* Admit native interface conversion, writer, enumerator, hash/test
               and lock routes BEFORE capture. Compilation captures payloads;
               it invokes no author bodies in the successful closed interval. */
    }
    requirement def StableEnumeration {
        doc /* First enumeration has unique keys. Every write replaces one of
               those keys, and free >= vector-width/4 prevents pre-write rehash.
               Native writes alone do not imply unchanged enumeration order. */
    }
    requirement def PrivateSnapshot {
        doc /* Reuse only newly allocated hash->list entry pairs. Never mutate
               source maps, SlotSpecs, payloads or caller-owned list spines. */
    }
    requirement def RefusalAndFreeze {
        doc /* Preserve first refused key/cause and prior private writes. Freeze
               all surviving thunks before the first compute-slot hook. */
    }
    requirement def ExactFallback {
        doc /* Unsupported metadata retains both original enumerations and all
               author boundaries. No admitted verdict crosses an author hook. */
    }
    requirement def PerformanceAdmission {
        doc /* Prove semantic preconditions, then measure native oracle, matched
               mirror/fused ABBA, A/A, B/B and total first demand separately.
               Phase allocation reduction does not qualify complete EVAL. */
    }
}
