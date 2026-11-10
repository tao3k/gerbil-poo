# Live read-key access

The authenticated internal read path now uses Gerbil's class slot accessor
for two `key` reads. The accessor pins the final record class and field,
not a record, key value, or successful currentness verdict. Public structural
key access still returns an owned copy. Issuance, route checks, receiver
freshness, and the independent check after callbacks retain their order.

The existing Lean `SourceClosureWork` laws
`route_pinned_field_preserves_validation` and
`route_foreign_class_refuses_before_field` describe the replacement under
the exact-class and same-field premises. They were rechecked with Lean
4.34.0. Producer tests check the actual Gerbil mapping and a live key
mutation; the model alone does not establish a runtime speedup.

## Same-process field-only comparison

Compile `benchmarks/read-field-test.ss` with the same ordinary optimized
Gerbil compiler used for the producer, then use `just test-file` on its
compiled interface. Both lookup wrappers belong to the same compiled
module. Every side receives the same four issued records and warmup;
the fixed sequence is ABBA twice. No sample is discarded or forced GC used.

Local arm64 macOS result, 400,000 field reads per sample:

| Access | Samples | User CPU per sample | GC count |
| --- | ---: | ---: | ---: |
| Named field | 4 | 12.69–12.98 ms | 0 |
| Fixed field | 4 | 2.97–2.99 ms | 0 |

The study prints user/system CPU, wall and GC times for every sample. It
isolates field access, including equal wrapper and loop overhead. It does
not measure whole replay, Graph repair, Module admission or business EVAL,
and makes no allocation or retained-memory claim. Source-interpreted
diagnostic timings are not substituted for this compiled comparison.

The producer cohort passed 30 issued-read cases, 20 order-repair cases and
the complete joint-publication suites through the existing Just entrypoint.
Those controls retain callback mutation, refusal order, snapshot isolation
and registration checks. Exact-head remote CI and downstream admission are
separate gates.
